

Lifecycle是Android Architecture Components的一员,这玩意儿挺方便的,它是能感知Activity和Fragment的生命周期的.

## 一、使用Lifecycle

#### 1. 引入Lifecycle

我们来看一下如何引入:

1. 非androidX项目引入:

```
//运行时
implementation "android.arch.lifecycle:runtime:1.1.1"
// 编译期
annotationProcessor "android.arch.lifecycle:compiler:1.1.1"
```

2. androidX项目引入:

> androidX是support库的新时代,Google正在将support迁移到androidx中.

```
implementation "androidx.lifecycle:lifecycle-runtime:2.0.0"
implementation "androidx.lifecycle:lifecycle-extensions:2.0.0"
implementation "androidx.lifecycle:lifecycle-common-java8:2.0.0"
annotationProcessor  "androidx.lifecycle:lifecycle-compiler:2.0.0"
```

#### 2. 创建生命周期观察者

```java
public class MyObserver implements LifecycleObserver {

    private static final String TAG = "MyObserver";

    @OnLifecycleEvent(Lifecycle.Event.ON_CREATE)  
    public void onCreate() {
        Log.w(TAG, "onCreate: ");
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_START)
    public void onStart() {
        Log.w(TAG, "onStart: ");
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_RESUME)
    public void onResume() {
        Log.w(TAG, "onResume: ");
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    public void onPause() {
        Log.w(TAG, "onPause: ");
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_STOP)
    public void onStop() {
        Log.w(TAG, "onStop: ");
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_DESTROY)
    public void onDestroy() {
        Log.w(TAG, "onDestroy: ");
    }

}

```

我们首先创建了一个类,它实现了`LifecycleObserver`接口,并且我写了几个模拟生命周期的方法,并在每个方法上加上了注解.

#### 3. 观察生命周期

然后我在Activity中这样写:

```java
public class MainActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        //添加一个生命周期观察者    getLifecycle()是FragmentActivity中的方法
        MyObserver observer = new MyObserver();
        getLifecycle().addObserver(observer);
    }
}
```

我们将项目运行起来,观察结果:
```
2019-03-12 22:14:26.672 15790-15790/? W/MyObserver: onCreate: 
2019-03-12 22:14:26.676 15790-15790/? W/MyObserver: onStart: 
2019-03-12 22:14:26.679 15790-15790/? W/MyObserver: onResume: 
2019-03-12 22:15:13.054 15790-15790/? W/MyObserver: onPause: 
2019-03-12 22:15:13.234 15790-15790/? W/MyObserver: onStop: 
2019-03-12 22:15:13.241 15790-15790/? W/MyObserver: onDestroy: 
```

我们发现,不管Activity的生命周期如何变化,我创建的观察者总是能够监听到响应的生命周期变化,并且变化时还会回调我写的生命周期方法(比如:`public void onDestroy()`).

方不方便?   你可能会问,这有啥用?  用处大了,比如我现在Presenter中就可以很方便的监听Activity中的生命周期,从而进行一些相应的操作和处理.

## 二、Lifecycle原理解析

#### 1. 从使用处入手

我们从使用的地方入手

```java
MyObserver observer = new MyObserver();
getLifecycle().addObserver(observer);
```

`getLifecycle()`方法点进去是FragmentActivity,看注释意思是返回生命周期提供者的Lifecycle

```java
/**
 * Returns the Lifecycle of the provider.
 */
@Override
public Lifecycle getLifecycle() {
    return super.getLifecycle();
}
```

再跟着`super.getLifecycle();`进入,来到了`androidx.core.app.ComponentActivity`,可以看到,ComponentActivity是继承自Activity并实现了LifecycleOwner(该接口的作用是标记类有Android的生命周期的,比如Activity和Fragment)接口.
```java
public class ComponentActivity extends Activity
        implements LifecycleOwner, KeyEventDispatcher.Component {
    private LifecycleRegistry mLifecycleRegistry = new LifecycleRegistry(this);
    @Override
    public Lifecycle getLifecycle() {
        return mLifecycleRegistry;
    }   
}

/**
* A class that has an Android lifecycle
*/
public interface LifecycleOwner {
    @NonNull
    Lifecycle getLifecycle();
}

```

那么其实最终是返回的LifecycleRegistry,它是Lifecycle的子类

Lifecycle是一个抽象类,里面有3个方法(添加观察者和移除观察者,获取当前的状态),还有一些状态的枚举定义.

```java
public abstract class Lifecycle {

    @MainThread
    public abstract void addObserver(@NonNull LifecycleObserver observer);


    @MainThread
    public abstract void removeObserver(@NonNull LifecycleObserver observer);


    @MainThread
    @NonNull
    public abstract State getCurrentState();

    @SuppressWarnings("WeakerAccess")
    public enum Event {
        /**
         * Constant for onCreate event of the {@link LifecycleOwner}.
         */
        ON_CREATE,
        /**
         * Constant for onStart event of the {@link LifecycleOwner}.
         */
        ON_START,
        /**
         * Constant for onResume event of the {@link LifecycleOwner}.
         */
        ON_RESUME,
        /**
         * Constant for onPause event of the {@link LifecycleOwner}.
         */
        ON_PAUSE,
        /**
         * Constant for onStop event of the {@link LifecycleOwner}.
         */
        ON_STOP,
        /**
         * Constant for onDestroy event of the {@link LifecycleOwner}.
         */
        ON_DESTROY,
        /**
         * An {@link Event Event} constant that can be used to match all events.
         */
        ON_ANY
    }


    @SuppressWarnings("WeakerAccess")
    public enum State {

        DESTROYED,


        INITIALIZED,


        CREATED,


        STARTED,


        RESUMED;


        public boolean isAtLeast(@NonNull State state) {
            return compareTo(state) >= 0;
        }
    }
}

```

LifecycleRegistry是Lifecycle的一个实现,它是用在Fragment和Activity上的,它可以处理多个生命周期观察者.  具体它有什么作用,后面再讲.

#### 2. ReportFragment的由来

下面是ComponentActivity的onCreate()方法.

```java
protected void onCreate(@Nullable Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    ReportFragment.injectIfNeededIn(this);
}

```

可以看到,在上面搞了一句,注入一个ReportFragment(报告Fragment? 纪检委员? 打小报告的? 当然,我只是猜测).

有一点眉目了,其实就是在Activity中搞了一个Fragment,Fragment的生命周期我们知道了,当然就知道了Activity的生命周期,接着通知相关的观察者即可.当然,这个Fragment是没有界面的. 我们来看看,这个注入的方法干了啥.

```java
public class ReportFragment extends Fragment {
    private static final String REPORT_FRAGMENT_TAG = "androidx.lifecycle"
            + ".LifecycleDispatcher.report_fragment_tag";

    public static void injectIfNeededIn(Activity activity) {
        // ProcessLifecycleOwner should always correctly work and some activities may not extend
        // FragmentActivity from support lib, so we use framework fragments for activities
        android.app.FragmentManager manager = activity.getFragmentManager();
        if (manager.findFragmentByTag(REPORT_FRAGMENT_TAG) == null) {
            manager.beginTransaction().add(new ReportFragment(), REPORT_FRAGMENT_TAG).commit();
            // Hopefully, we are the first to make a transaction.
            manager.executePendingTransactions();
        }
}
```

其实这个injectIfNeededIn()看起来像是注入的方法干的就是将Fragment添加到Activity中,

来看看这个ReportFragment的生命周期方法都干了些啥,

```java
@Override
public void onActivityCreated(Bundle savedInstanceState) {
    super.onActivityCreated(savedInstanceState);
    dispatchCreate(mProcessListener);
    dispatch(Lifecycle.Event.ON_CREATE);
}

@Override
public void onStart() {
    super.onStart();
    dispatchStart(mProcessListener);
    dispatch(Lifecycle.Event.ON_START);
}

private void dispatchCreate(ActivityInitializationListener listener) {
    if (listener != null) {
        listener.onCreate();
    }
}

```

1. 通过调用dispatchCreate(mProcessListener)方法,感觉从命名上(是不是有点像`dispatchTouchEvent()`)看就知道是在干啥了: 分发当前的生命周期事件.
2. dispatch(Lifecycle.Event.ON_START); 感觉这个方法也像是在分发事件.

我们跟着这个mProcessListener来看看是在哪里设置的

```java
/**
 * Class that provides lifecycle for the whole application process.
 */
public class ProcessLifecycleOwner implements LifecycleOwner {
    
    //注意,我是一个单例
    private static final ProcessLifecycleOwner sInstance = new ProcessLifecycleOwner();

    static void init(Context context) {
        sInstance.attach(context);
    }

    void attach(Context context) {
        mHandler = new Handler();
        mRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE);
        Application app = (Application) context.getApplicationContext();
        app.registerActivityLifecycleCallbacks(new EmptyActivityLifecycleCallbacks() {
            @Override
            public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
                ReportFragment.get(activity).setProcessListener(mInitializationListener);
            }
    
            @Override
            public void onActivityPaused(Activity activity) {
                activityPaused();
            }
    
            @Override
            public void onActivityStopped(Activity activity) {
                activityStopped();
            }
        });
    }
}

//Activity的监听器
ActivityInitializationListener mInitializationListener =
            new ActivityInitializationListener() {
                @Override
                public void onCreate() {
                }

                @Override
                public void onStart() {
                    activityStarted();
                }

                @Override
                public void onResume() {
                    activityResumed();
                }

private final LifecycleRegistry mRegistry = new LifecycleRegistry(this);

//Activity创建的时候,分发Lifecycle.Event.ON_START事件
void activityStarted() {
    mStartedCounter++;
    if (mStartedCounter == 1 && mStopSent) {
        mRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START);
        mStopSent = false;
    }
}
```

```java
ReportFragment.java
static ReportFragment get(Activity activity) {
    return (ReportFragment) activity.getFragmentManager().findFragmentByTag(
            REPORT_FRAGMENT_TAG);
}
```

ProcessLifecycleOwner看起来就像是老大哥,给整个APP提供lifecycle的,也就是说通过它我们可以观察到整个应用程序的生命周期.  如何做到的? ProcessLifecycleOwner的attach()中registerActivityLifecycleCallbacks()注册了一个监听器,一旦有Activity创建就给它设置一个Listener.这样就保证了每个ReportFragment都有Listener.

既然是一个全局的单例,并且可以监听整个应用程序的生命周期,那么,肯定一开始就需要初始化.
既然没有让我们在Application里面初始化,那么肯定就是在ContentProvider里面初始化的.

#### 3. 初始化

> ps: 这里穿插一个小知识点: ContentProvider的onCreate()方法执行时间比Application的onCreate()执行时间还要早,而且肯定会执行.所以在ContentProvider的onCreate()方法里面初始化几个特殊的小东西是没啥问题的.

我们跟着ProcessLifecycleOwner的init()方法的调用处,来到了ProcessLifecycleOwnerInitializer,果不其然,它是一个ContentProvider.并且,在这里,真的就初始化了2个小东西.

```java
public class ProcessLifecycleOwnerInitializer extends ContentProvider {
    @Override
    public boolean onCreate() {
        LifecycleDispatcher.init(getContext());
        ProcessLifecycleOwner.init(getContext());
        return true;
    }
}
```

1. ProcessLifecycleOwner初始化就不说了,是拿来观察整个应用的生命周期的,其原理就是利用ReportFragment,我们稍后详细到来.
2. LifecycleDispatcher尤其重要.

```java
class LifecycleDispatcher {
    static void init(Context context) {
        ...
        //registerActivityLifecycleCallbacks  注册一个监听器
        ((Application) context.getApplicationContext())
                .registerActivityLifecycleCallbacks(new DispatcherActivityCallback());
    }
}
static class DispatcherActivityCallback extends EmptyActivityLifecycleCallbacks {
    @Override
    public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
        //又来注入咯
        ReportFragment.injectIfNeededIn(activity);
    }
    @Override
    public void onActivityStopped(Activity activity) {
    }
    @Override
    public void onActivitySaveInstanceState(Activity activity, Bundle outState) {
    }
}
```

初始化的时候,就注册了一个监听器,每个创建的时候都给它注入一个ReportFragment.咦?这里又来注入一次,不是每个Activity都注册了一次么,在ComponentActivity中,搞啥玩意儿?

<img src="https://ss1.bdstatic.com/70cFuXSh_Q1YnxGkpoWK1HF6hhy/it/u=3304691937,3517639434&fm=27&gp=0.jpg" width="200" height="130"/>

我猜,,可能是为了兼容吧.2次注入,确保万无一失.而且这个injectIfNeededIn()方法,内部实现是只会成功注入一次的,所以多调用一次,无所谓.

#### 4. 分发事件

相当于,到了这里,应用程序里面的任何一个Activity都会被注入一个ReportFragment.而注入的这个无界面的ReportFragment是可以观察到当然Activity的生命周期的.

下面我们来仔细看一下,这个事件是如何一步步分发下去的.

```java
ReportFragment.java
@Override
public void onActivityCreated(Bundle savedInstanceState) {
    super.onActivityCreated(savedInstanceState);
    dispatchCreate(mProcessListener);
    dispatch(Lifecycle.Event.ON_CREATE);
}

private void dispatch(Lifecycle.Event event) {
    Activity activity = getActivity();
    if (activity instanceof LifecycleRegistryOwner) {
        ((LifecycleRegistryOwner) activity).getLifecycle().handleLifecycleEvent(event);
        return;
    }

    if (activity instanceof LifecycleOwner) {
        //获取Activity中的LifecycleRegistry
        Lifecycle lifecycle = ((LifecycleOwner) activity).getLifecycle();
        if (lifecycle instanceof LifecycleRegistry) {
            ((LifecycleRegistry) lifecycle).handleLifecycleEvent(event);
        }
    }
}
```
不知道小伙伴儿们是否记得ComponentActivity是实现了LifecycleOwner的.

```java
public class ComponentActivity extends Activity
        implements LifecycleOwner
```

下面我们获取到Activity中的LifecycleRegistry,下面的代码做了精简,只保留关键代码
```java
public void handleLifecycleEvent(@NonNull Lifecycle.Event event) {
    State next = getStateAfter(event);
    moveToState(next);
}

private void moveToState(State next) {
    ......
    sync();
    ......
}

private void sync() {
    LifecycleOwner lifecycleOwner = mLifecycleOwner.get();
    
    //循环 遍历所有观察者
    while (...) {
        ....
        //分发事件
        forwardPass(lifecycleOwner);
    }
}


private void forwardPass(LifecycleOwner lifecycleOwner) {
    Iterator<Entry<LifecycleObserver, ObserverWithState>> ascendingIterator =
            mObserverMap.iteratorWithAdditions();
    while (ascendingIterator.hasNext() && !mNewEventOccurred) {
        Entry<LifecycleObserver, ObserverWithState> entry = ascendingIterator.next();
        ObserverWithState observer = entry.getValue();
        while ((observer.mState.compareTo(mState) < 0 && !mNewEventOccurred
                && mObserverMap.contains(entry.getKey()))) {
            pushParentState(observer.mState);
            //分发事件
            observer.dispatchEvent(lifecycleOwner, upEvent(observer.mState));
            popParentState();
        }
    }
}

```

上面的observer其实是一个ObserverWithState对象,

```java
static class ObserverWithState {
    State mState;
    GenericLifecycleObserver mLifecycleObserver;

    ObserverWithState(LifecycleObserver observer, State initialState) {
        mLifecycleObserver = Lifecycling.getCallback(observer);
        mState = initialState;
    }

    void dispatchEvent(LifecycleOwner owner, Event event) {
        State newState = getStateAfter(event);
        mState = min(mState, newState);
        //生命周期变了....  关键代码
        mLifecycleObserver.onStateChanged(owner, event);
        mState = newState;
    }
}
```

在ObserverWithState的构造方法中，通过 Lifecycling.getCallback(observer)根据传进来的 observer ，构造了一个 GenericLifecycleObserver 类型的 mLifecycleObserver ,我们跟进去看一下.

```java
static GenericLifecycleObserver getCallback(Object object) {
    if (object instanceof FullLifecycleObserver) {
        return new FullLifecycleObserverAdapter((FullLifecycleObserver) object);
    }

    if (object instanceof GenericLifecycleObserver) {
        return (GenericLifecycleObserver) object;
    }

    final Class<?> klass = object.getClass();
    int type = getObserverConstructorType(klass);
    if (type == GENERATED_CALLBACK) {
        List<Constructor<? extends GeneratedAdapter>> constructors =
                sClassToAdapters.get(klass);
        if (constructors.size() == 1) {
            GeneratedAdapter generatedAdapter = createGeneratedAdapter(
                    constructors.get(0), object);
            return new SingleGeneratedAdapterObserver(generatedAdapter);
        }
        GeneratedAdapter[] adapters = new GeneratedAdapter[constructors.size()];
        for (int i = 0; i < constructors.size(); i++) {
            adapters[i] = createGeneratedAdapter(constructors.get(i), object);
        }
        return new CompositeGeneratedAdaptersObserver(adapters);
    }
    return new ReflectiveGenericLifecycleObserver(object);
}
```

这个方法大概意思就是,根据传进的LifecycleObserver进行判断,构造一个GenericLifecycleObserver(目前是只有4个子类:FullLifecycleObserverAdapter、SingleGeneratedAdapterObserver、CompositeGeneratedAdaptersObserver、ReflectiveGenericLifecycleObserver)的对象.

#### 5. 依赖注入

首先,这里穿插一点.我们在引入lifecycle时添加了语句`annotationProcessor "android.arch.lifecycle:compiler:1.1.1"`,这个其实是注解处理器的依赖.

引入这个之后,会自动生成`xxx_LifecycleAdapter`的文件,上面的demo中生成的是`MyObserver_LifecycleAdapter`文件,其内容如下:

```java
public class MyObserver_LifecycleAdapter implements GeneratedAdapter {
  final MyObserver mReceiver;

  MyObserver_LifecycleAdapter(MyObserver receiver) {
    this.mReceiver = receiver;
  }

  @Override
  public void callMethods(LifecycleOwner owner, Lifecycle.Event event, boolean onAny,
      MethodCallsLogger logger) {
    boolean hasLogger = logger != null;
    if (onAny) {
      return;
    }
    if (event == Lifecycle.Event.ON_CREATE) {
      if (!hasLogger || logger.approveCall("onCreate", 1)) {
        mReceiver.onCreate();
      }
      return;
    }
    if (event == Lifecycle.Event.ON_START) {
      if (!hasLogger || logger.approveCall("onStart", 1)) {
        mReceiver.onStart();
      }
      return;
    }
    if (event == Lifecycle.Event.ON_RESUME) {
      if (!hasLogger || logger.approveCall("onResume", 1)) {
        mReceiver.onResume();
      }
      return;
    }
    if (event == Lifecycle.Event.ON_PAUSE) {
      if (!hasLogger || logger.approveCall("onPause", 1)) {
        mReceiver.onPause();
      }
      return;
    }
    if (event == Lifecycle.Event.ON_STOP) {
      if (!hasLogger || logger.approveCall("onStop", 1)) {
        mReceiver.onStop();
      }
      return;
    }
    if (event == Lifecycle.Event.ON_DESTROY) {
      if (!hasLogger || logger.approveCall("onDestroy", 1)) {
        mReceiver.onDestroy();
      }
      return;
    }
  }
}

```

因为我们的事件是声明在MyObserver的方法注解上面的,每次去反射取这些东西,比较耗性能.那么我们通过该依赖库,把这些标注了的方法进行预处理,然后直接回调这些方法,避免反射,进行提高性能.666,佩服.

有了上面的知识之后,分析getCallback()方法,不难发现,因为MyObserver_LifecycleAdapter只有一个构造方法,那么就会构造出SingleGeneratedAdapterObserver.而SingleGeneratedAdapterObserver内部其实就是调用一下方法而已.

```java
public class SingleGeneratedAdapterObserver implements GenericLifecycleObserver {

    private final GeneratedAdapter mGeneratedAdapter;

    SingleGeneratedAdapterObserver(GeneratedAdapter generatedAdapter) {
        mGeneratedAdapter = generatedAdapter;
    }

    @Override
    public void onStateChanged(LifecycleOwner source, Lifecycle.Event event) {
        mGeneratedAdapter.callMethods(source, event, false, null);
        mGeneratedAdapter.callMethods(source, event, true, null);
    }
}
```

上面的mGeneratedAdapter其实就是我们的MyObserver_LifecycleAdapter.好了,结束了. 生命周期事件从Activity开始,然后到打小报告的ReportFragment那里出来,辗转发侧,终于到了我们定义的观察者,不容易啊.谷歌工程师写的代码就是牛逼.

![](https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1552503196369&di=22d956465159008c3bfce40b4b2fa2e8&imgtype=0&src=http%3A%2F%2Fpic.962.net%2Fup%2F2018-4%2F15248137333417097.jpg)


