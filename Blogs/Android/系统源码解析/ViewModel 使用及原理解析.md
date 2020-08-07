

**本文是基于 androidx.lifecycle:lifecycle-extensions:2.0.0 的源码进行分析**

ViewModel旨在以生命周期意识的方式存储和管理用户界面相关的数据,它可以用来管理Activity和Fragment中的数据.还可以拿来处理Fragment与Fragment之间的通信等等.

当Activity或者Fragment创建了关联的ViewModel,那么该Activity或Fragment只要处于活动状态,那么该ViewModel就不会被销毁,即使是该Activity屏幕旋转时重建了.所以也可以拿来做数据的暂存.

ViewModel主要是拿来获取或者保留Activity/Fragment所需要的数据的,开发者可以在Activity/Fragment中观察ViewModel中的数据更改(这里需要配合LiveData食用).

> ps: ViewModel只是用来管理UI的数据的,千万不要让它持有View、Activity或者Fragment的引用(小心内存泄露)。

本文以由浅入深的方式学习ViewModel

### 一、ViewModel的使用

#### 1. 引入ViewModel

```
//引入AndroidX吧,替换掉support包
implementation 'androidx.appcompat:appcompat:1.0.2'

def lifecycle_version = "2.0.0"
// ViewModel and LiveData
implementation "androidx.lifecycle:lifecycle-extensions:$lifecycle_version"
```

#### 2. 简单使用起来

1. 定义一个User数据类

```java
class User implements Serializable {

    public int age;
    public String name;

    public User(int age, String name) {
        this.age = age;
        this.name = name;
    }

    @Override
    public String toString() {
        return "User{" +
                "age=" + age +
                ", name='" + name + '\'' +
                '}';
    }
}
```

2. 然后引出我们今天的主角ViewModel

```java
public class UserModel extends ViewModel {

    public final MutableLiveData<User> mUserLiveData = new MutableLiveData<>();

    public UserModel() {
        //模拟从网络加载用户信息
        mUserLiveData.postValue(new User(1, "name1"));
    }
    
    //模拟 进行一些数据骚操作
    public void doSomething() {
        User user = mUserLiveData.getValue();
        if (user != null) {
            user.age = 15;
            user.name = "name15";
            mUserLiveData.setValue(user);
        }
    }

}
```

3. 这时候在Activity中就可以使用ViewModel了. 其实就是一句代码简单实例化,然后就可以使用ViewModel了.

```java
//这些东西我是引入的androidx下面的
import androidx.fragment.app.FragmentActivity;
import androidx.lifecycle.Observer;
import androidx.lifecycle.ViewModelProviders;

public class MainActivity extends FragmentActivity {

    private TextView mContentTv;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        mContentTv = findViewById(R.id.tv_content);

        //构建ViewModel实例
        final UserModel userModel = ViewModelProviders.of(this).get(UserModel.class);

        //让TextView观察ViewModel中数据的变化,并实时展示
        userModel.mUserLiveData.observe(this, new Observer<User>() {
            @Override
            public void onChanged(User user) {
                mContentTv.setText(user.toString());
            }
        });

        findViewById(R.id.btn_test).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                //点击按钮  更新User数据  观察TextView变化
                userModel.doSomething();
            }
        });
    }
}
```

这个时候,我们点击一下按钮(user中的age变为15),我们可以旋转手机屏幕(这个时候其实Activity是重新创建了,也就是onCreate()方法被再次调用,但是ViewModel其实是没有重新创建的,还是之前那个ViewModel),但是当我们旋转之后,发现TextView上显示的age居然还是15,,,,这就是ViewModel的魔性所在.这个就不得不提ViewModel的生命周期了,它只有在Activity销毁之后,它才会自动销毁(所以别让ViewModel持有Activity引用啊,会内存泄露的).  下面引用一下谷歌官方的图片,将ViewModel的生命周期展示的淋漓尽致.

![](https://developer.android.google.cn/images/topic/libraries/architecture/viewmodel-lifecycle.png)

#### 3. ViewModel妙用1: Activity与Fragment"通信"

有了ViewModel,Activity与Fragment可以共享一个ViewModel,因为Fragment是依附在Activity上的,在实例化ViewModel时将该Activity传入ViewModelProviders,它会给你一个该Activity已创建好了的ViewModel,这个Fragment可以方便的访问该ViewModel中的数据.在Activity中修改userModel数据后,该Fragment就能拿到更新后的数据.

```java
public class MyFragment extends Fragment {
     public void onStart() {
        //这里拿到的ViewModel实例,其实是和Activity中创建的是一个实例
         UserModel userModel = ViewModelProviders.of(getActivity()).get(UserModel.class);
     }
 }
```

#### 4. ViewModel妙用2: Fragment与Fragment"通信"

下面我们来看一个例子(Google官方例子)

```java
public class SharedViewModel extends ViewModel {
    private final MutableLiveData<Item> selected = new MutableLiveData<Item>();

    public void select(Item item) {
        selected.setValue(item);
    }

    public LiveData<Item> getSelected() {
        return selected;
    }
}


public class MasterFragment extends Fragment {
    private SharedViewModel model;
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        model = ViewModelProviders.of(getActivity()).get(SharedViewModel.class);
        itemSelector.setOnClickListener(item -> {
            model.select(item);
        });
    }
}

public class DetailFragment extends Fragment {
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        SharedViewModel model = ViewModelProviders.of(getActivity()).get(SharedViewModel.class);
        model.getSelected().observe(this, { item ->
           // Update the UI.
        });
    }
}
```

1. 首先定义一个ViewModel,在里面放点数据
2. 然后在MasterFragment和DetailFragment都可以拿到该ViewModel,拿到了该ViewModel就可以拿到里面的数据了,相当于间接通过ViewModel通信了. so easy....


### 二、ViewModel源码解析

> 又到了我们熟悉的源码解析环节


我们从下面这句代码start.

```
final UserModel userModel = ViewModelProviders.of(this).get(UserModel.class);
```

我们跟着`ViewModelProviders.of(this)`打开新世界的大门

#### 1. ViewModelProviders.of(this) 方法

```java
/**
 * 用于构建一个ViewModelProvider,当Activity是alive时它会保留所有的该Activity对应的ViewModels.
 */
@MainThread
public static ViewModelProvider of(@NonNull FragmentActivity activity) {
    return of(activity, null);
}

@MainThread
public static ViewModelProvider of(@NonNull FragmentActivity activity,
        @Nullable Factory factory) {
    //检查application是否为空,不为空则接收
    Application application = checkApplication(activity);
    if (factory == null) {
        //构建一个ViewModelProvider.AndroidViewModelFactory
        factory = ViewModelProvider.AndroidViewModelFactory.getInstance(application);
    }
    return new ViewModelProvider(activity.getViewModelStore(), factory);
}

```

ViewModelProviders里面的of()函数其实是为了方便我们构建一个ViewModelProvider.而ViewModelProvider,一看名字就知道干啥的了,就是提供ViewModel的.

**Factory**是ViewModelProvider的一个内部接口,它的实现类是拿来构建ViewModel实例的.它里面只有一个方法,就是创建一个ViewModel.

```java
/**
 * Implementations of {@code Factory} interface are responsible to instantiate ViewModels.
 */
public interface Factory {
    /**
     * Creates a new instance of the given {@code Class}.
     * <p>
     *
     * @param modelClass a {@code Class} whose instance is requested
     * @param <T>        The type parameter for the ViewModel.
     * @return a newly created ViewModel
     */
    @NonNull
    <T extends ViewModel> T create(@NonNull Class<T> modelClass);
}
```

Factory有2个实现类:一个是**NewInstanceFactory**, 一个是**AndroidViewModelFactory** .

- NewInstanceFactory源码
```java
public static class NewInstanceFactory implements Factory {

        @SuppressWarnings("ClassNewInstance")
        @NonNull
        @Override
        public <T extends ViewModel> T create(@NonNull Class<T> modelClass) {
            //noinspection TryWithIdenticalCatches
            try {
                return modelClass.newInstance();
            } catch (InstantiationException e) {
                throw new RuntimeException("Cannot create an instance of " + modelClass, e);
            } catch (IllegalAccessException e) {
                throw new RuntimeException("Cannot create an instance of " + modelClass, e);
            }
        }
    }
```

NewInstanceFactory专门用来实例化那种构造方法里面没有参数的class,并且ViewModel里面是不带Context的,然后它是通过newInstance()去实例化的.

- AndroidViewModelFactory 源码

```
public static class AndroidViewModelFactory extends ViewModelProvider.NewInstanceFactory {

    private static AndroidViewModelFactory sInstance;

    /**
     * Retrieve a singleton instance of AndroidViewModelFactory.
     *
     * @param application an application to pass in {@link AndroidViewModel}
     * @return A valid {@link AndroidViewModelFactory}
     */
    @NonNull
    public static AndroidViewModelFactory getInstance(@NonNull Application application) {
        if (sInstance == null) {
            sInstance = new AndroidViewModelFactory(application);
        }
        return sInstance;
    }

    private Application mApplication;

    /**
     * Creates a {@code AndroidViewModelFactory}
     *
     * @param application an application to pass in {@link AndroidViewModel}
     */
    public AndroidViewModelFactory(@NonNull Application application) {
        mApplication = application;
    }

    @NonNull
    @Override
    public <T extends ViewModel> T create(@NonNull Class<T> modelClass) {
        if (AndroidViewModel.class.isAssignableFrom(modelClass)) {
            //noinspection TryWithIdenticalCatches
            try {
                return modelClass.getConstructor(Application.class).newInstance(mApplication);
            } catch (NoSuchMethodException e) {
                throw new RuntimeException("Cannot create an instance of " + modelClass, e);
            } catch (IllegalAccessException e) {
                throw new RuntimeException("Cannot create an instance of " + modelClass, e);
            } catch (InstantiationException e) {
                throw new RuntimeException("Cannot create an instance of " + modelClass, e);
            } catch (InvocationTargetException e) {
                throw new RuntimeException("Cannot create an instance of " + modelClass, e);
            }
        }
        return super.create(modelClass);
    }
}
```

AndroidViewModelFactory专门用来实例化那种构造方法里面有参数的class,并且ViewModel里面可能是带Context的.

- 它是通过newInstance(application)去实例化的.如果有带application参数则是这样实例化
- 如果没有带application参数的话,则还是会走newInstance()方法去构建实例.

AndroidViewModelFactory通过构造方法给ViewModel带入Application,就可以在ViewModel里面拿到Context,因为Application是APP全局的,那么不存在内存泄露的问题.完美解决了有些ViewModel里面需要Context引用,但是又担心内存泄露的问题.

下面我们继续ViewModelProviders.of(this)方法继续分析吧,注意最后一句`new ViewModelProvider(activity.getViewModelStore(), factory);`第一个参数会调用activity的getViewModelStore()方法(这个方法会返回ViewModelStore,这个类是拿来存储ViewModel的,下面会说到),这里的activity是androidx.fragment.app.FragmentActivity,看一下这个getViewModelStore()方法

```java
/**
 * 获取这个Activity相关联的ViewModelStore
 */
@NonNull
@Override
public ViewModelStore getViewModelStore() {
    if (getApplication() == null) {
        throw new IllegalStateException("Your activity is not yet attached to the "
                + "Application instance. You can't request ViewModel before onCreate call.");
    }
    if (mViewModelStore == null) {
        //获取最近一次横竖屏切换时保存下来的数据
        NonConfigurationInstances nc =
                (NonConfigurationInstances) getLastNonConfigurationInstance();
        if (nc != null) {
            // Restore the ViewModelStore from NonConfigurationInstances
            mViewModelStore = nc.viewModelStore;
        }
        if (mViewModelStore == null) {
            mViewModelStore = new ViewModelStore();
        }
    }
    return mViewModelStore;
}

//没想到吧,Activity在横竖屏切换时悄悄保存了viewModelStore
//注意,这是FragmentActivity中的NonConfigurationInstances(其实Activity中还定义了一个NonConfigurationInstances,内容要比这个多一些,但是由于没有关系到它,这里就不提及了)
static final class NonConfigurationInstances {
    Object custom;
    ViewModelStore viewModelStore;
    FragmentManagerNonConfig fragments;
}

```

Android横竖屏切换时会触发onSaveInstanceState()，而还原时会调用onRestoreInstanceState()，但是Android的Activity类还有2个方法名为onRetainNonConfigurationInstance()和getLastNonConfigurationInstance()这两个方法。 

来具体看看这2个素未谋面的方法
```java
/**
 保留所有fragment的状态。你不能自己覆写它！如果要保留自己的状态，请使用onRetainCustomNonConfigurationInstance（）
 这个方法在FragmentActivity里面
 */
@Override
public final Object onRetainNonConfigurationInstance() {
    Object custom = onRetainCustomNonConfigurationInstance();

    FragmentManagerNonConfig fragments = mFragments.retainNestedNonConfig();

    if (fragments == null && mViewModelStore == null && custom == null) {
        return null;
    }

    NonConfigurationInstances nci = new NonConfigurationInstances();
    nci.custom = custom;
    nci.viewModelStore = mViewModelStore;
    nci.fragments = fragments;
    return nci;
}


//这个方法在Activity里面,而mLastNonConfigurationInstances.activity实际就是就是上面方法中年的nci
public Object getLastNonConfigurationInstance() {
    return mLastNonConfigurationInstances != null
            ? mLastNonConfigurationInstances.activity : null;
}

```

我们来看看getLastNonConfigurationInstance()的调用时机,

```java
protected void onCreate(@Nullable Bundle savedInstanceState) {
    ......
    super.onCreate(savedInstanceState);

    NonConfigurationInstances nc =
            (NonConfigurationInstances) getLastNonConfigurationInstance();
    if (nc != null && nc.viewModelStore != null && mViewModelStore == null) {
        mViewModelStore = nc.viewModelStore;
    }
    ......
}
```

没想到吧,Activity在横竖屏切换时悄悄保存了viewModelStore,放到了NonConfigurationInstances实例里面,横竖屏切换时保存了又恢复了回来,相当于ViewModel实例就还在啊,也就避免了横竖屏切换时的数据丢失.

#### 2. viewModelProvider.get(UserModel.class)

下面我们来到那句构建ViewModel代码的后半段,它是ViewModelProvider的get()方法,看看实现,其实很简单

```java
public <T extends ViewModel> T get(@NonNull Class<T> modelClass) {
    String canonicalName = modelClass.getCanonicalName();
    if (canonicalName == null) {
        throw new IllegalArgumentException("Local and anonymous classes can not be ViewModels");
    }
    return get(DEFAULT_KEY + ":" + canonicalName, modelClass);
}

public <T extends ViewModel> T get(@NonNull String key, @NonNull Class<T> modelClass) {
    //先取缓存  有缓存则用缓存
    ViewModel viewModel = mViewModelStore.get(key);

    if (modelClass.isInstance(viewModel)) {
        //noinspection unchecked
        return (T) viewModel;
    } else {
        //noinspection StatementWithEmptyBody
        if (viewModel != null) {
            // TODO: log a warning.
        }
    }
    
    //无缓存  则重新通过mFactory构建
    viewModel = mFactory.create(modelClass);
    //缓存起来
    mViewModelStore.put(key, viewModel);
    //noinspection unchecked
    return (T) viewModel;
}

```

大体思路是利用一个key来缓存ViewModel,有缓存则用缓存的,没有则重新构建.构建时使用的factory是上面of()方法的那个factory.

#### 3. ViewModelStore 

上面多个地方用到了ViewModelStore,它其实就是一个普普通通的保存ViewModel的类.

```java
public class ViewModelStore {

    private final HashMap<String, ViewModel> mMap = new HashMap<>();

    final void put(String key, ViewModel viewModel) {
        ViewModel oldViewModel = mMap.put(key, viewModel);
        if (oldViewModel != null) {
            oldViewModel.onCleared();
        }
    }

    final ViewModel get(String key) {
        return mMap.get(key);
    }

    /**
     *  Clears internal storage and notifies ViewModels that they are no longer used.
     */
    public final void clear() {
        for (ViewModel vm : mMap.values()) {
            vm.onCleared();
        }
        mMap.clear();
    }
}

```

ViewModelStore有一个HashMap专门用于存储,普通吧.

下面看看何时调用的clear() 

#### 4. ViewModel.onCleared()  资源回收

既然ViewModel是生命周期感知的,那么何时应该清理ViewModel呢?

我们来到FragmentActivity的onDestroy()方法,发现它是在这里清理的.

```java
/**
 * Destroy all fragments.
 */
@Override
protected void onDestroy() {
    super.onDestroy();

    if (mViewModelStore != null && !isChangingConfigurations()) {
        mViewModelStore.clear();
    }

    mFragments.dispatchDestroy();
}
```

#### 5. 再看 ViewModel

很多朋友可能就要问了,ViewModel到底是什么?

```java
public abstract class ViewModel {
    /**
     * 这个方法会在ViewModel即将被销毁时调用,可以在这里清理垃圾
     */
    @SuppressWarnings("WeakerAccess")
    protected void onCleared() {
    }
}
```

其实很简单,就一个抽象类,里面就一个空方法???  我擦,搞了半天,原来ViewModel不是主角....

#### 6. AndroidViewModel

ViewModel有一个子类,是AndroidViewModel.它里面有一个Application的属性,仅此而已,为了方便在ViewModel里面使用Context.

```java
public class AndroidViewModel extends ViewModel {
    @SuppressLint("StaticFieldLeak")
    private Application mApplication;

    public AndroidViewModel(@NonNull Application application) {
        mApplication = application;
    }

    /**
     * Return the application.
     */
    @SuppressWarnings("TypeParameterUnusedInFormals")
    @NonNull
    public <T extends Application> T getApplication() {
        //noinspection unchecked
        return (T) mApplication;
    }
}
```

### 三、小结

ViewModel 的源码其实不多，理解起来比较容易，主要是官方FragmentActivity提供了技术实现，onRetainNonConfigurationInstance（）保存状态，getLastNonConfigurationInstance()恢复。

原来Activity还有这么2个玩意儿，之前我还只是知道onSaveInstanceState()和onRestoreInstanceState()，涨姿势了。

