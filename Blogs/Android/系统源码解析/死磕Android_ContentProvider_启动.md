

先给出一个需要注意的点:**ContentProvider的onCreate方法比Application的onCreate方法先执行.** 下面会给出为什么.

ContentProvider相对于其他组件来说,用得稍微少一些.很少有APP需要向其他应用提供数据,保护自己的数据都来不及呢.当然,除了一些大厂的APP,还有就是手机自带的一些应用(通讯录,短信,相册等等).ContentProvider可以向其他组件或者其他应用提供数据,其中是通过Binder来进行通信的.ContentProvider中的数据提供不仅仅只有SQLite 一种方式.当其他应用访问ContentProvider时,如果该ContentProvider的进程没有启动,那么第一次访问该ContentProvider就会触发该ContentProvider的的进程启动.

建议先看一下,之前我写的系列文章,才能更好的理解本文

- [死磕Android_App 启动过程（含 Activity 启动过程）](https://juejin.im/post/5cee950ef265da1bc8540be6)
- [死磕Android_Service启动流程分析(一)](https://juejin.im/post/5d026bd8e51d4556dc29361c)
- [死磕Android_Service绑定流程分析(二)](https://juejin.im/post/5d050c106fb9a07ecb0ba66f)
- [死磕Android_BroadcastReceiver 工作过程](https://juejin.im/post/5d0a4f706fb9a07eb15d5b20)

> ps: 本文基于API 28的源码分析的

## 1. 进程的启动

APP启动时会启动一个新的进程,该进程的入口在ActivityThread的main方法中.

```java
public static void main(String[] args) {
    
    //准备主线程的Looper
    Looper.prepareMainLooper();
    
    //创建ActivityThread实例,调用attach方法
    ActivityThread thread = new ActivityThread();
    thread.attach(false, startSeq);

    if (sMainThreadHandler == null) {
        sMainThreadHandler = thread.getHandler();
    }

    //主线程的消息循环啊,开始
    Looper.loop();

    throw new RuntimeException("Main thread loop unexpectedly exited");
}
```

main方法就那么几句代码,我们很方便得看出它的逻辑.Looper的那个逻辑在[死磕Android_Handler机制你需要知道的一切](https://blog.csdn.net/xfhy_/article/details/90347636)中已做详细讲解,这里不再赘述.然后就是会在main方法里面创建ActivityThread的实例, 这个时候我们只要跟着attach方法进入看看干了什么骚操作

```java
private void attach(boolean system, long startSeq) {
    ......
    final IActivityManager mgr = ActivityManager.getService();
    mgr.attachApplication(mAppThread, startSeq);
}
```
attach方法对我们来说,需要关注的点就是上面的两句代码,其他的非主流程的代码我都略去了... 又又又又遇到了ActivityManager.getService(),前面的文章提到过特别多次,它就是AMS,IActivityManager是用来与AMS进行跨进程通信的,这里调用了AMS的attachApplication方法.

## 2. 路过AMS

下面是attachApplication方法的源码

```java
@Override
public final void attachApplication(IApplicationThread thread, long startSeq) {
    attachApplicationLocked(thread, callingPid, callingUid, startSeq);
}
@GuardedBy("this")
private final boolean attachApplicationLocked(IApplicationThread thread,
        int pid, int callingUid, long startSeq) {

    thread.bindApplication(processName, appInfo, providers,
            app.instr.mClass,
            profilerInfo, app.instr.mArguments,
            app.instr.mWatcher,
            app.instr.mUiAutomationConnection, testMode,
            mBinderTransactionTrackingEnabled, enableTrackAllocation,
            isRestrictedBackupMode || !normalMode, app.persistent,
            new Configuration(getGlobalConfiguration()), app.compat,
            getCommonServicesLocked(app.isolated),
            mCoreSettingsObserver.getCoreSettingsLocked(),
            buildSerial, isAutofillCompatEnabled);

    return true;
}
```

这里的thread是ApplicationThread,它继承了IApplicationThread.Stub,跨进程通信,是一个Binder对象.所以上面的bindApplication方法是在ApplicationThread中的

## 3. 又回ActivityThread

下面是ActivityThread中的内部类ApplicationThread中的bindApplication方法

```java
public final void bindApplication(String processName, ApplicationInfo appInfo,
        List<ProviderInfo> providers, ComponentName instrumentationName,
        ProfilerInfo profilerInfo, Bundle instrumentationArgs,
        IInstrumentationWatcher instrumentationWatcher,
        IUiAutomationConnection instrumentationUiConnection, int debugMode,
        boolean enableBinderTracking, boolean trackAllocation,
        boolean isRestrictedBackupMode, boolean persistent, Configuration config,
        CompatibilityInfo compatInfo, Map services, Bundle coreSettings,
        String buildSerial, boolean autofillCompatibilityEnabled) {

    setCoreSettings(coreSettings);

    AppBindData data = new AppBindData();
    data.processName = processName;
    data.appInfo = appInfo;
    data.providers = providers;
    data.instrumentationName = instrumentationName;
    data.instrumentationArgs = instrumentationArgs;
    data.instrumentationWatcher = instrumentationWatcher;
    data.instrumentationUiAutomationConnection = instrumentationUiConnection;
    data.debugMode = debugMode;
    data.enableBinderTracking = enableBinderTracking;
    data.trackAllocation = trackAllocation;
    data.restrictedBackupMode = isRestrictedBackupMode;
    data.persistent = persistent;
    data.config = config;
    data.compatInfo = compatInfo;
    data.initProfilerInfo = profilerInfo;
    data.buildSerial = buildSerial;
    data.autofillCompatibilityEnabled = autofillCompatibilityEnabled;
    sendMessage(H.BIND_APPLICATION, data);
}
```

这个方法没啥说的,就是赋值一些属性,然后发送一个消息到大名鼎鼎的H这个Handler,之前的文章也分析过这个Handler.这个消息在处理时就只是调用了ActivityThread的handleBindApplication方法

```java
 private void handleBindApplication(AppBindData data) {

    //创建ContextImpl 
    final ContextImpl appContext = ContextImpl.createAppContext(this, data.info);

    //创建Instrumentation
    final ClassLoader cl = instrContext.getClassLoader();
    mInstrumentation = (Instrumentation)
        cl.loadClass(data.instrumentationName.getClassName()).newInstance();

    final ComponentName component = new ComponentName(ii.packageName, ii.name);
    mInstrumentation.init(this, instrContext, appContext, component,
            data.instrumentationWatcher, data.instrumentationUiAutomationConnection);

    //创建Application    
    Application app;
    app = data.info.makeApplication(data.restrictedBackupMode, null);

    //注意,这里是install ContentProvider
    installContentProviders(app, data.providers);
    
    //调用Application的onCreate方法
    mInstrumentation.callApplicationOnCreate(app);
}
```

handleBindApplication方法干了很多事情

1. 创建ContextImpl
2. 创建Instrumentation
3. 创建Application    
4. 创建ContentProvider,并调用其onCreate方法
5. 调用Application的onCreate方法

下面我们继续深入installContentProviders方法

```java
private void installContentProviders(
            Context context, List<ProviderInfo> providers) {
    final ArrayList<ContentProviderHolder> results = new ArrayList<>();

    for (ProviderInfo cpi : providers) {
        //构建ContentProvider
        ContentProviderHolder cph = installProvider(context, null, cpi,
                false /*noisy*/, true /*noReleaseNeeded*/, true /*stable*/);
        if (cph != null) {
            cph.noReleaseNeeded = true;
            results.add(cph);
        }
    }

    try {
        ActivityManager.getService().publishContentProviders(
            getApplicationThread(), results);
    } catch (RemoteException ex) {
        throw ex.rethrowFromSystemServer();
    }
}

private ContentProviderHolder installProvider(Context context,
        ContentProviderHolder holder, ProviderInfo info,
        boolean noisy, boolean noReleaseNeeded, boolean stable) {
    ContentProvider localProvider = null;

    //通过ClassLoader 反射构建ContentProvider
    final java.lang.ClassLoader cl = c.getClassLoader();
    localProvider = packageInfo.getAppFactory()
            .instantiateProvider(cl, info.name);
    
    //attachInfo方法里面就会调用ContentProvider的onCreate方法
    localProvider.attachInfo(c, info);

    return retHolder;
}

```

分析上面的代码,installContentProviders方法会遍历所有的Provider, 然后分别构建,最后将这些构建好的Provider都publish到AMS中.当然在installProvider构建ContentProvider方法里面,它是调用了ContentProvider的onCreate方法的,下面请看详情

```java
ContentProvider.java => attachInfo
public void attachInfo(Context context, ProviderInfo info) {
    attachInfo(context, info, false);
}

private void attachInfo(Context context, ProviderInfo info, boolean testing) {
    ContentProvider.this.onCreate();
}
```

当然,到了这里,一个ContentProvider就此启动.我们也看到了,ContentProvider的onCreate方法确实是比Application的onCreate方法先调用.