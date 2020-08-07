

我这里将启动Service流程分为两章来写,startService和bindService分别分析.


这篇文章是分析startService过程的源码分析过程.其实startService和Activity的启动很类似,好多地方都差不多.如果之前还没有看过或者不太理解Activity的启动的同学可以看下我的这篇文章: [死磕Android_App 启动过程（含 Activity 启动过程）](https://blog.csdn.net/xfhy_/article/details/90679525).因为本篇文章和Activity 启动过程有很多相似之处,建议可以先看一看Activity启动流程,食用更佳.


Service主要是有2种方式进行启动,这里先讲startService方式,使用方式如下:

```java
Intent intent = new Intent(this,MyService.class);
startService(intent);
```

上面的这段代码写在Activity里面的,让我们从startService方法进入吧

进入startService,发现来到了ContextWrapper的内部.
```java
@Override
public ComponentName startService(Intent service) {
    return mBase.startService(service);
}
```

主要是因为Activity继承自ContextThemeWrapper,而ContextThemeWrapper又继承自ContextWrapper.这里的ContextWrapper其实是一个Context.可以看到方法中只有一句代码....mBase是ContextWrapper里面的一个Context类型的属性.所以就来到了Context的startService方法.

```java
public abstract ComponentName startService(Intent service);
```
而Context的startService是一个抽象方法.我擦,,那么这个mBase的实体到底是什么呢?startService的具体实现可全得看这个实体是什么才行.为了搞清楚这个实体到底是什么,所以我们需要来到mBase赋值的地方.

```java
public class ContextWrapper extends Context {
    Context mBase;

    protected void attachBaseContext(Context base) {
        if (mBase != null) {
            throw new IllegalStateException("Base context already set");
        }
        mBase = base;
    }
}
```

嘿嘿,这是一个protected方法,我们只需要找到其调用的地方即可.
这里其实是在Activity的attach方法里面进行的调用

```java
final void attach(Context context, ActivityThread aThread,
        Instrumentation instr, IBinder token, int ident,
        Application application, Intent intent, ActivityInfo info,
        CharSequence title, Activity parent, String id,
        NonConfigurationInstances lastNonConfigurationInstances,
        Configuration config, String referrer, IVoiceInteractor voiceInteractor,
        Window window, ActivityConfigCallback activityConfigCallback) {
        
    attachBaseContext(context);       
    ......
}
```

然后就把mBase赋值了.但是我们看这个方法的入参context也是用Context代替的,我们还是不知道这个context具体是什么....

所以我们需要知道这个attach方法是在哪里调用的,上次分析Activity启动流程的时候分析过这里.其实是在ActivityThread里面的performLaunchActivity方法里面调用的.performLaunchActivity方法是启动Activity的核心逻辑.

```java
private Activity performLaunchActivity(ActivityClientRecord r, Intent customIntent) {
    
    //构建ContextImpl
    ContextImpl appContext = createBaseContextForActivity(r);

    //实例化Activity
    Activity activity = null;
    java.lang.ClassLoader cl = appContext.getClassLoader();
    activity = mInstrumentation.newActivity(
            cl, component.getClassName(), r.intent);
    
    //调用Activity的attach方法,实例化一些东西
    activity.attach(appContext, this, getInstrumentation(), r.token,
            r.ident, app, r.intent, r.activityInfo, title, r.parent,
            r.embeddedID, r.lastNonConfigurationInstances, config,
            r.referrer, r.voiceInteractor, window, r.configCallback);
    return activity;
}
```

可以看到attach方法传入的context为ContextImpl,可算找到你了.

那么我们继续startService方法的探索,mBase就是ContextImpl,其内部的startService实现如下:

```java
@Override
public ComponentName startService(Intent service) {
    warnIfCallingFromSystemProcess();
    return startServiceCommon(service, false, mUser);
}

private ComponentName startServiceCommon(Intent service, boolean requireForeground,
        UserHandle user) {
        
    //ActivityManager.getService()是AMS
    ComponentName cn = ActivityManager.getService().startService(
        mMainThread.getApplicationThread(), service, service.resolveTypeIfNeeded(
                    getContentResolver()), requireForeground,
                    getOpPackageName(), user.getIdentifier());
    return cn;
}

```

ActivityManager.getService()其实就是AMS,这里在Activity启动流程分析中已分析过这里,这里不再赘述.那我们来看看AMS的startService方法.

```java
@Override
public ComponentName startService(IApplicationThread caller, Intent service,
        String resolvedType, boolean requireForeground, String callingPackage, int userId) throws TransactionTooLargeException {
    .....
    res = mServices.startServiceLocked(caller, service,
            resolvedType, callingPid, callingUid,
            requireForeground, callingPackage, userId);
    return res;
}
```

这里的mServices是一个ActiveServices对象,是AMS里面的一个属性.ActiveServices类是辅助AMS管理Service的,包括Service的启动、绑定和停止等.在ActiveServices类里面的startServiceLocked方法会调用startServiceInnerLocked方法

```java
ComponentName startServiceLocked(IApplicationThread caller, Intent service, String resolvedType,
        int callingPid, int callingUid, boolean fgRequired, String callingPackage, final int userId)
        throws TransactionTooLargeException {
    .....
    ComponentName cmp = startServiceInnerLocked(smap, service, r, callerFg, addToStarting);
    return cmp;
}

ComponentName startServiceInnerLocked(ServiceMap smap, Intent service, ServiceRecord r,
        boolean callerFg, boolean addToStarting) throws TransactionTooLargeException {
    ......
    String error = bringUpServiceLocked(r, service.getFlags(), callerFg, false, false);
    ......
    return r.name;
}
```

在startServiceInnerLocked方法里面又会去调用bringUpServiceLocked方法

```java
private String bringUpServiceLocked(ServiceRecord r, int intentFlags, boolean execInFg,
        boolean whileRestarting, boolean permissionsReviewRequired)
        throws TransactionTooLargeException {
    ......
    realStartServiceLocked(r, app, execInFg);
    return null;
}
```

终于,我们在bringUpServiceLocked方法里面看到了一个realStartServiceLocked方法.从这个方法名就可以看出,真的要开始真实的调用开启Service了,前面的都只是铺垫.

```java
private final void realStartServiceLocked(ServiceRecord r,
        ProcessRecord app, boolean execInFg) throws RemoteException {
    r.app = app;
    r.restartTime = r.lastActivity = SystemClock.uptimeMillis();

    final boolean newService = app.services.add(r);
    boolean created = false;
    ......
    app.thread.scheduleCreateService(r, r.serviceInfo,
            mAm.compatibilityInfoForPackageLocked(r.serviceInfo.applicationInfo),
            app.repProcState);
    created = true;
    ......
}
```
app.thread是IApplicationThread,其实就是ApplicationThread(ActivityThread的内部类)的远程调用,aidl. 下面是ApplicationThread的scheduleCreateService方法.

```java
public final void scheduleCreateService(IBinder token,
            ServiceInfo info, CompatibilityInfo compatInfo, int processState) {
    updateProcessState(processState, false);
    CreateServiceData s = new CreateServiceData();
    s.token = token;
    s.info = info;
    s.compatInfo = compatInfo;

    sendMessage(H.CREATE_SERVICE, s);
}
```

又到了我们熟悉的环节,这里和Activity启动时一模一样,也是给H这个Handler类发送消息.
然后执行Service的启动,看来源码的道理都是一通百通呢..

在该Handler的handleMessage方法中CREATE_SERVICE消息就去调用handleCreateService()方法.这个方法是ActivityThread里面的.


```java
private void handleCreateService(CreateServiceData data) {
    //构建Service 利用反射取构建实例
    Service service = null;
    java.lang.ClassLoader cl = packageInfo.getClassLoader();
    service = packageInfo.getAppFactory()
            .instantiateService(cl, data.info.name, data.intent);
    
    //初始化ContextImpl
    ContextImpl context = ContextImpl.createAppContext(this, packageInfo);

    Application app = packageInfo.makeApplication(false, mInstrumentation);
    //原来Service也需要这个ContextImpl
    service.attach(context, this, data.info.name, data.token, app,
            ActivityManager.getService());
    //接下来马上就会调用Service的onCreate方法
    service.onCreate();
    
    //mServices是用来存储已经启动的Service的
    mServices.put(data.token, service);
    ....
}
```

handleCreateService方法就是Service启动的核心代码了,这个是在ActivityThread里面发生的哦.这个方法首先是把Service实例给构建出来,然后调用Service的attach方法,初始化一些东西,然后就开始了Service的onCreate方法的调用.这里需要注意的是Service的onCreate方法,还有其他生命周期的方法都是运行在主线程的.

到此,Service的启动流程就分析完了.