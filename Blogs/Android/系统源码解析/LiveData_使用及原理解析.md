
**本文是基于 androidx.lifecycle:lifecycle-extensions:2.0.0 的源码进行分析**

LiveData是一个类,将数据放在它里面我们可以观察数据的变化.但是它是江湖上那些妖艳贱货不一样的是它是`lifecycle-aware`(生命周期感知的).这个特性非常重要,我们可以用它来更新UI的数据,当且仅当activity、fragment或者Service是处于活动状态时。

LiveData一般用在ViewModel中,用于存放一些数据啥的,然后我们可以在Activity或者Fragment中观察其数据的变化(可能是访问数据库或者请求网络)展示数据到相应的UI上.这就是数据驱动视图,是MVVM模式的重要思想.

阅读本文需要读者了解Lifecycle原理,下面的很多东西都和Lifecycle的很多类相关,不清楚的朋友可以看我之前写的博客[Lifecycle 使用及原理解析 ](https://blog.csdn.net/xfhy_/article/details/88543884)

其实谷歌出的Lifecycle和ViewModel,LiveData这些,都特别好用,设计得特别好,特别值得我们**深入**学习.

下面我将带大家走进LiveData的世界.

## 一、使用

#### 1. 引入LiveData

```
//引入AndroidX吧,替换掉support包
implementation 'androidx.appcompat:appcompat:1.0.2'

def lifecycle_version = "2.0.0"
// ViewModel and LiveData
implementation "androidx.lifecycle:lifecycle-extensions:$lifecycle_version"
```

#### 2. 简单使用起来

```java
public class MainActivity extends AppCompatActivity {
    
    //1. 首先定义一个LiveData的实例  
    private MutableLiveData<String> mStringLiveData = new MutableLiveData<>();
    private TextView mContentTv;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        mContentTv = findViewById(R.id.tv_content);
        
        //2. 观察LiveData数据的变化,变化时将数据展示到TextView上
        mStringLiveData.observe(this, new Observer<String>() {
            @Override
            public void onChanged(String content) {
                //数据变化时会回调这个方法
                mContentTv.setText(content);
            }
        });
        
        findViewById(R.id.btn_test).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                //3. 改变LiveData里面的数据 数据变化时,会回调上面的onChanged()方法
                mStringLiveData.postValue("新数据....");
            }
        });
    }
}
```

1. 首先是定义一个LiveData的实例,LiveData是一个抽象类,MutableLiveData是它的一个子类.
2. 然后调用LiveData的observe()方法,进行注册,开始观察数据,当我们的数据变化时,会回调onChanged()方法.
3. LiveData有2个更新数据的方法
    - 一个是setValue(): 在主线程中调用,直接更新数据
    - 一个是postValue(): 在主线程或者子线程中调用都行,它最后其实是利用handler在主线程中调用setValue()方法实现的数据更新.

LiveData的使用非常简单.由于只是示例,所以我没有将LiveData放到ViewModel里面去.之前郭神写过一个MVVM的例子,大家可以看一看(地址是: https://github.com/guolindev/coolweatherjetpack ),里面将Jetpack的各种组件使用得淋漓尽致,让人直呼666.


下面是一小段优雅代码(想看更详细的,请到仓库查看):
```java
viewModel.currentLevel.observe(this, Observer { level ->
    when (level) {
        LEVEL_PROVINCE -> {
            titleText.text = "中国"
            backButton.visibility = View.GONE
        }
        LEVEL_CITY -> {
            titleText.text = viewModel.selectedProvince?.provinceName
            backButton.visibility = View.VISIBLE
        }
        LEVEL_COUNTY -> {
            titleText.text = viewModel.selectedCity?.cityName
            backButton.visibility = View.VISIBLE
        }
    }
})
viewModel.dataChanged.observe(this, Observer {
    adapter.notifyDataSetChanged()
    listView.setSelection(0)
    closeProgressDialog()
})
viewModel.isLoading.observe(this, Observer { isLoading ->
    if (isLoading) showProgressDialog()
    else closeProgressDialog()
})
```

举上面这个例子,主要是让大家感受一下,其实LiveData真的用处很大,不仅可以拿来更新ListView,展示隐藏对话框,按钮展示隐藏等等.这些东西都是数据驱动的,当数据变化时,根本不需要另外多写代码,会回调observe()方法,数据就及时地更新到UI上了.简直天衣无缝啊.

## 二、源码分析

既然我们说了,LiveData这么牛逼,作为一个合格的开发人员.我们不能仅仅是API player,我们要知道其背后用的啥原理,日后深入使用时肯定会很有帮助.

从下面的代码开始入手:

```java
mStringLiveData.observe(this, new Observer<String>() {
    @Override
    public void onChanged(String content) {
        mContentTv.setText(content);
    }
});

//调用上面的方法来到了LiveData的observe()方法
                        //1. 传入的是LifecycleOwner和Observer(观察者)
public void observe(@NonNull LifecycleOwner owner, @NonNull Observer<? super T> observer) {
    //2. 当前必须是在主线程  
    assertMainThread("observe");
    
    //3. 当前的生命周期如果是DESTROYED状态,那么不好意思,不能观察了
    if (owner.getLifecycle().getCurrentState() == DESTROYED) {
        // ignore
        return;
    }
    
    //4. 这里用装饰者模式将owner, observer封装起来
    LifecycleBoundObserver wrapper = new LifecycleBoundObserver(owner, observer);
    
    //5. 将观察者缓存起来
    ObserverWrapper existing = mObservers.putIfAbsent(observer, wrapper);
    .....
    //6. 添加生命周期观察
    owner.getLifecycle().addObserver(wrapper);
}
```

首先第1点,我们传入的是Activity,到里面却看到是LifecycleOwner.翻看AppCompatActivity源码..

```java
public class AppCompatActivity extends FragmentActivity{}

public class FragmentActivity extends ComponentActivit{}

public class ComponentActivity extends Activity
        implements LifecycleOwner{}
```

原来AppCompatActivity的爷爷(ComponentActivity)实现了LifecycleOwner接口,而LifecycleOwner接口是为了标识标记类有Android的生命周期的,比如Activity和Fragment.

第2点,必须是主线程中.

第3点,如果生命周期是DESTROYED,那么不好意思,不能继续往下走了.选择忽略.

第4点,将owner, observer封装了起来,形成一个LifecycleBoundObserver对象.

```java
public interface GenericLifecycleObserver extends LifecycleObserver {
    void onStateChanged(LifecycleOwner source, Lifecycle.Event event);
}

class LifecycleBoundObserver extends ObserverWrapper implements GenericLifecycleObserver {
    @NonNull
    final LifecycleOwner mOwner;

    LifecycleBoundObserver(@NonNull LifecycleOwner owner, Observer<? super T> observer) {
        super(observer);
        mOwner = owner;
    }
}
```
LifecycleBoundObserver实现了GenericLifecycleObserver,而GenericLifecycleObserver是实现了LifecycleObserver(标记一个类是生命周期观察者).

第5点我们看到有一个mObservers,它其实是LiveData里面的一个属性,是用来缓存所有的LiveData的观察者的.

```java
private SafeIterableMap<Observer<? super T>, ObserverWrapper> mObservers =
            new SafeIterableMap<>();
```

再来看第6点,这个在Lifecycle里面讲过,它是用来添加观察者,最终用来观察LifecycleOwner(生命周期拥有者)的生命周期的,比如Activity或者Fragment等.

当Activity的生命周期发生变化时,会回调上面GenericLifecycleObserver(也就是上面的LifecycleBoundObserver)对象的onStateChanged()方法.

```java
@Override
public void onStateChanged(LifecycleOwner source, Lifecycle.Event event) {
    if (mOwner.getLifecycle().getCurrentState() == DESTROYED) {
        removeObserver(mObserver);
        return;
    }
    activeStateChanged(shouldBeActive());
}

public void removeObserver(@NonNull final Observer<? super T> observer) {
    assertMainThread("removeObserver");
    ObserverWrapper removed = mObservers.remove(observer);
    if (removed == null) {
        return;
    }
    removed.detachObserver();
    removed.activeStateChanged(false);
}
```
当生命周期处于DESTROYED时,调用removeObserver()方法,移除观察者,那么在Activity中就不会收到回调了.


### 如何得知数据已经更新

LiveData提供了2种方式,setValue()和postValue()来更新数据.

#### 1. setValue()方式更新数据

来看LiveData的setValue()方法

```java
private volatile Object mData = NOT_SET;
protected void setValue(T value) {
    assertMainThread("setValue");
    mVersion++;
    mData = value;
    dispatchingValue(null);
}
```
首先是当前必须是主线程,然后将值保存到了mData属性中.

```java
void dispatchingValue(@Nullable ObserverWrapper initiator) {
    ......
    //遍历所有的观察者执行considerNotify()方法
    for (Iterator<Map.Entry<Observer<? super T>, ObserverWrapper>> iterator =
            mObservers.iteratorWithAdditions(); iterator.hasNext(); ) {
        considerNotify(iterator.next().getValue());
    }
    ......
}

private void considerNotify(ObserverWrapper observer) {
    ......
    observer.mObserver.onChanged((T) mData);
}

```

然后调用dispatchingValue()方法,遍历所有的观察者,并回调onChanged()方法,数据即得到了更新.

#### 2. postValue()方式更新数据

> 这种方式一般适用于在子线程中更新数据,更新UI的数据

```java
volatile Object mPendingData = NOT_SET;

private final Runnable mPostValueRunnable = new Runnable() {
    @Override
    public void run() {
        Object newValue;
        synchronized (mDataLock) {
            //嘿嘿 原来mPendingData到了这里
            newValue = mPendingData;
            mPendingData = NOT_SET;
        }
        //noinspection unchecked
        //最后还是调用的setValue()嘛
        setValue((T) newValue);
    }
};


protected void postValue(T value) {
    boolean postTask;
    synchronized (mDataLock) {
        postTask = mPendingData == NOT_SET;
        mPendingData = value;
    }
    if (!postTask) {
        return;
    }
    ArchTaskExecutor.getInstance().postToMainThread(mPostValueRunnable);
}
```

将value值赋值给mPendingData,然后通过ArchTaskExecutor的实例将mPostValueRunnable传入postToMainThread()方法.

ArchTaskExecutor是何方神圣

```java
public static ArchTaskExecutor getInstance() {
    if (sInstance != null) {
        return sInstance;
    }
    synchronized (ArchTaskExecutor.class) {
        if (sInstance == null) {
            sInstance = new ArchTaskExecutor();
        }
    }
    return sInstance;
}

private ArchTaskExecutor() {
    mDefaultTaskExecutor = new DefaultTaskExecutor();
    mDelegate = mDefaultTaskExecutor;
}

public class DefaultTaskExecutor extends TaskExecutor {
    @Nullable
    private volatile Handler mMainHandler;
    
    @Override
    public void postToMainThread(Runnable runnable) {
        if (mMainHandler == null) {
            synchronized (mLock) {
                if (mMainHandler == null) {
                    mMainHandler = new Handler(Looper.getMainLooper());
                }
            }
        }
        //noinspection ConstantConditions
        mMainHandler.post(runnable);
    }
}

```

通过ArchTaskExecutor里面的DefaultTaskExecutor里面的postToMainThread()方法,其实将mPostValueRunnable交给了一个mMainHandler,这个mMainHandler有主线程的looper.可以方便的将Runnable搞到主线程. 所以最后mPostValueRunnable会到主线程中执行setValue(),毫无问题.

## 三、小结

LiveData主要是依赖Lifecycle可以感知生命周期,从而避免了内存泄露.然后可以观察里面数据的变化来驱动UI数据展示.
