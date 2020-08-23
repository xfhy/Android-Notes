
## 1. 前言

Activity是日常开发中最常用的组件,系统给我们做了很多很多的封装,让我们平时用起来特别简单,很顺畅.但是你有没有想过,系统内部是如何启动一个Activity的呢?Activity对象是如何创建的,又是如何回调生命周期方法的?通过对底层工作原理的学习,是通往高级工程师的必经之路,我们必须对Activity的启动原理知己知彼,才能在平时的开发中应对各种疑难杂症.本文主要是对Activity启动流程的主要流程讲解,目的是给我们一个感性的认识,不用深扣代码细节,即可对上层开发有指导意义.除非是ROM开发,那底层细节还是需要注意.

> 插播:ActivityManagerService(以下简称AMS)管理着四大组件的启动、切换、调度及应用进程的管理和调度等工作，是Android中非常非常核心的服务.和AMS进行通信是需要跨进程的.

> ps: 本文是以API 28为例

![image](EC42F116139D4A549BD17F0BF51CB97F)
![](https://user-gold-cdn.xitu.io/2017/4/18/855fc1aa910f6f7c4a01a991e5274690?imageslim)

### 1.1 简单介绍一下主要的类

- Instrumentation

Instrumentation会在应用程序的任何代码运行之前被实例化,它能够允许你监视应用程序和系统的所有交互.它还会构造Application,构建Activity,以及生命周期都会经过这个对象去执行.

- ActivityManagerService

Android核心服务,简称AMS,负责调度各应用进程,管理四大组件.实现了IActivityManager接口,应用进程能通过Binder机制调用系统服务.

- LaunchActivityItem

相当于是一个消息对象,当ActivityThread接收到这个消息则去启动Activity.收到消息后执行execute方法启动activity.

- ActivityThread

应用的主线程.程序的入口.在main方法中开启loop循环,不断地接收消息,处理任务.

## 2. 应用的启动过程

### 2.1 Launcher简介

Launcher,也就是我们熟悉的安卓桌面,它其实是一个APP.只不过这个APP有点特殊,特殊在于它是系统开机后第一个启动的APP,并且该APP常驻在系统中,不会被杀死,用户一按home键就会回到桌面(回到该APP).桌面上面放了很多很多我们自己安装的或者是系统自带的APP,我们通过点击这个应用的快捷方法可以打开该应用.目前Android原生的Launcher版本是Launcher3.而下面提到的`Launcher.java`是Launcher3中的一个Activity.该Activity中摆放着各应用的快捷方式图标.

### 2.2 启动应用源码分析

我们通过点击快捷方式,Launcher这个Activity的onClick方法会被调用

```java
public void onClick(View v) {
    ......
    Object tag = v.getTag();
    if (tag instanceof ShortcutInfo) {
        //点击的是快捷方式->onClickAppShortcut
        onClickAppShortcut(v);
    }
    .....
}

protected void onClickAppShortcut(final View v) {
    ....
    // Start activities
    startAppShortcutOrInfoActivity(v);
}

private void startAppShortcutOrInfoActivity(View v) {
    //将启动信息放在了点击View的tag里面
    ItemInfo item = (ItemInfo) v.getTag();
    // 应用程序安装的时候根据 AndroidManifest.xml 由 PackageManagerService 解析并保存的
    Intent intent;
    if (item instanceof PromiseAppInfo) {
        PromiseAppInfo promiseAppInfo = (PromiseAppInfo) item;
        intent = promiseAppInfo.getMarketIntent();
    } else {
        intent = item.getIntent();
    }
    
    boolean success = startActivitySafely(v, intent, item);
    ....
}

public boolean startActivitySafely(View v, Intent intent, ItemInfo item) {
    ......
    // Prepare intent
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    ......
    // Could be launching some bookkeeping activity
    startActivity(intent, optsBundle);
    ......
}

```

在处理点击事件时,经过onClickAppShortcut方法调用startAppShortcutOrInfoActivity方法,获取Intent信息,然后调用startActivitySafely方法,在里面调用了我们经常使用的startActivity方法.因为Launcher类是一个Activity,所以调startActivity方法是理所当然的.这里调用startActivity方法就会启动APP的第一个Activity.

## 3. 启动Activity

> 以API 28的源码为例

### 3.1 启动进程

来到Activity的startActivity方法,这个方法最终会调用startActivityForResult()

```java
public void startActivityForResult(@RequiresPermission Intent intent, int requestCode,
        @Nullable Bundle options) {
    //mMainThread是ActivityThread,mMainThread.getApplicationThread()是获取ApplicationThread
    Instrumentation.ActivityResult ar =
        mInstrumentation.execStartActivity(
            this, mMainThread.getApplicationThread(), mToken, this,
            intent, requestCode, options);
}
```

startActivityForResult里面调用了Instrumentation的execStartActivity方法,其中mMainThread是ActivityThread(就是从这里开始启动一个应用的),mMainThread.getApplicationThread()是获取ApplicationThread.ApplicationThread是ActivityThread的内部类,待会儿会介绍到.

```java
public ActivityResult execStartActivity(
        Context who, IBinder contextThread, IBinder token, Activity target,
        Intent intent, int requestCode, Bundle options) {
    //1. 将ApplicationThread转为IApplicationThread
    IApplicationThread whoThread = (IApplicationThread) contextThread;
    
    //2. 获取AMS实例,调用startActivity方法
    int result = ActivityManager.getService()
        .startActivity(whoThread, who.getBasePackageName(), intent,
                intent.resolveTypeIfNeeded(who.getContentResolver()),
                token, target != null ? target.mEmbeddedID : null,
                requestCode, 0, null, options);
    checkStartActivityResult(result, intent);

    return null;
}
```

IApplicationThread是一个Binder接口,它继承自IInterface.ApplicationThread是继承了IApplicationThread.Stub,实现了IApplicationThread的,所以可以转成IApplicationThread.

然后就是获取AMS实例,调用AMS的startActivity方法.

```java
public static IActivityManager getService() {
    return IActivityManagerSingleton.get();
}

private static final Singleton<IActivityManager> IActivityManagerSingleton =
        new Singleton<IActivityManager>() {
            @Override
            protected IActivityManager create() {
                //1. 获取服务的Binder对象
                final IBinder b = ServiceManager.getService(Context.ACTIVITY_SERVICE);
                //2. aidl 获取AMS
                final IActivityManager am = IActivityManager.Stub.asInterface(b);
                return am;
            }
        };
```

ServiceManager是安卓中一个重要的类，用于管理所有的系统服务，维护着系统服务和客户端的binder通信。返回的是Binder对象,用来进行应用与系统服务之间的通信的.

下面我们继续进入AMS的startActivity方法
```java
@Override
public final int startActivity(IApplicationThread caller, String callingPackage,
        Intent intent, String resolvedType, IBinder resultTo, String resultWho, int requestCode,
        int startFlags, ProfilerInfo profilerInfo, Bundle bOptions) {
    return startActivityAsUser(caller, callingPackage, intent, resolvedType, resultTo,
            resultWho, requestCode, startFlags, profilerInfo, bOptions,
            UserHandle.getCallingUserId());
}
@Override
public final int startActivityAsUser(IApplicationThread caller, String callingPackage,
        Intent intent, String resolvedType, IBinder resultTo, String resultWho, int requestCode,
        int startFlags, ProfilerInfo profilerInfo, Bundle bOptions, int userId) {
    return startActivityAsUser(caller, callingPackage, intent, resolvedType, resultTo,
            resultWho, requestCode, startFlags, profilerInfo, bOptions, userId,
            true /*validateIncomingUser*/);
}

public final int startActivityAsUser(IApplicationThread caller, String callingPackage,
        Intent intent, String resolvedType, IBinder resultTo, String resultWho, int requestCode,
        int startFlags, ProfilerInfo profilerInfo, Bundle bOptions, int userId,
        boolean validateIncomingUser) {

    // TODO: Switch to user app stacks here.
    return mActivityStartController.obtainStarter(intent, "startActivityAsUser")
            .setCaller(caller)
            .setCallingPackage(callingPackage)
            .setResolvedType(resolvedType)
            .setResultTo(resultTo)
            .setResultWho(resultWho)
            .setRequestCode(requestCode)
            .setStartFlags(startFlags)
            .setProfilerInfo(profilerInfo)
            .setActivityOptions(bOptions)
            .setMayWait(userId)
            .execute();

}
```

AMS的startActivity方法会调用AMS的startActivityAsUser方法,然后又调用另一个startActivityAsUser方法.最后来了一串链式调用,最后会来到ActivityStarter的execute方法.

```java
int execute() {
    return startActivityMayWait(mRequest.caller, mRequest.callingUid,
            mRequest.callingPackage, mRequest.intent, mRequest.resolvedType,
            mRequest.voiceSession, mRequest.voiceInteractor, mRequest.resultTo,
            mRequest.resultWho, mRequest.requestCode, mRequest.startFlags,
            mRequest.profilerInfo, mRequest.waitResult, mRequest.globalConfig,
            mRequest.activityOptions, mRequest.ignoreTargetSecurity, mRequest.userId,
            mRequest.inTask, mRequest.reason,
            mRequest.allowPendingRemoteAnimationRegistryLookup);
}
private int startActivityMayWait(IApplicationThread caller, int callingUid,
        String callingPackage, Intent intent, String resolvedType,
        IVoiceInteractionSession voiceSession, IVoiceInteractor voiceInteractor,
        IBinder resultTo, String resultWho, int requestCode, int startFlags,
        ProfilerInfo profilerInfo, WaitResult outResult,
        Configuration globalConfig, SafeActivityOptions options, boolean ignoreTargetSecurity,
        int userId, TaskRecord inTask, String reason,
        boolean allowPendingRemoteAnimationRegistryLookup) {
    ......
    int res = startActivity(caller, intent, ephemeralIntent, resolvedType, aInfo, rInfo,
            voiceSession, voiceInteractor, resultTo, resultWho, requestCode, callingPid,
            callingUid, callingPackage, realCallingPid, realCallingUid, startFlags, options,
            ignoreTargetSecurity, componentSpecified, outRecord, inTask, reason,
            allowPendingRemoteAnimationRegistryLookup);
    ......
}

private int startActivity(IApplicationThread caller, Intent intent, Intent ephemeralIntent,
        String resolvedType, ActivityInfo aInfo, ResolveInfo rInfo,
        IVoiceInteractionSession voiceSession, IVoiceInteractor voiceInteractor,
        IBinder resultTo, String resultWho, int requestCode, int callingPid, int callingUid,
        String callingPackage, int realCallingPid, int realCallingUid, int startFlags,
        SafeActivityOptions options, boolean ignoreTargetSecurity, boolean componentSpecified,
        ActivityRecord[] outActivity, TaskRecord inTask, String reason,
        boolean allowPendingRemoteAnimationRegistryLookup) {
    ......
    mLastStartActivityResult = startActivity(caller, intent, ephemeralIntent, resolvedType,
            aInfo, rInfo, voiceSession, voiceInteractor, resultTo, resultWho, requestCode,
            callingPid, callingUid, callingPackage, realCallingPid, realCallingUid, startFlags,
            options, ignoreTargetSecurity, componentSpecified, mLastStartActivityRecord,
            inTask, allowPendingRemoteAnimationRegistryLookup);
    ......
}

private int startActivity(IApplicationThread caller, Intent intent, Intent ephemeralIntent,
        String resolvedType, ActivityInfo aInfo, ResolveInfo rInfo,
        IVoiceInteractionSession voiceSession, IVoiceInteractor voiceInteractor,
        IBinder resultTo, String resultWho, int requestCode, int callingPid, int callingUid,
        String callingPackage, int realCallingPid, int realCallingUid, int startFlags,
        SafeActivityOptions options,
        boolean ignoreTargetSecurity, boolean componentSpecified, ActivityRecord[] outActivity,
        TaskRecord inTask, boolean allowPendingRemoteAnimationRegistryLookup) {
    ......
    return startActivity(r, sourceRecord, voiceSession, voiceInteractor, startFlags,
            true /* doResume */, checkedOptions, inTask, outActivity);
}

```

ActivityStarter的execute方法会继续调用startActivityMayWait方法.startActivityMayWait会去调用startActivity方法,然后调用另一个startActivity方法.然后又是调用另一个startActivity方法,

不得不说,这些方法的参数可真是长啊,,,,可能是由于历史原因吧.


```java
private int startActivity(final ActivityRecord r, ActivityRecord sourceRecord,
            IVoiceInteractionSession voiceSession, IVoiceInteractor voiceInteractor,
            int startFlags, boolean doResume, ActivityOptions options, TaskRecord inTask,
            ActivityRecord[] outActivity) {
    ......
    result = startActivityUnchecked(r, sourceRecord, voiceSession, voiceInteractor,
                startFlags, doResume, options, inTask, outActivity);
    ......
}

private int startActivityUnchecked(final ActivityRecord r, ActivityRecord sourceRecord,
        IVoiceInteractionSession voiceSession, IVoiceInteractor voiceInteractor,
        int startFlags, boolean doResume, ActivityOptions options, TaskRecord inTask,
        ActivityRecord[] outActivity) {
    .......
    mSupervisor.resumeFocusedStackTopActivityLocked(mTargetStack, mStartActivity, mOptions);

    return START_SUCCESS;
}

```
终于不用调用startActivity方法了,调用startActivityUnchecked方法,在里面调用了ActivityStackSupervisor的resumeFocusedStackTopActivityLocked方法

```java
 boolean resumeFocusedStackTopActivityLocked(
        ActivityStack targetStack, ActivityRecord target, ActivityOptions targetOptions) {
    ......
    return targetStack.resumeTopActivityUncheckedLocked(target, targetOptions);
    ......
}
```

targetStack是ActivityStack,会调用ActivityStack的resumeTopActivityUncheckedLocked方法,然后调用resumeTopActivityInnerLocked方法.

```java
boolean resumeTopActivityUncheckedLocked(ActivityRecord prev, ActivityOptions options) {
    ......
    result = resumeTopActivityInnerLocked(prev, options);
    .....
    return result;
}


private boolean resumeTopActivityInnerLocked(ActivityRecord prev, ActivityOptions options) {
	......
    mStackSupervisor.startSpecificActivityLocked(next, true, false);
	......
    return true;
}

```
然后又会回到ActivityStackSupervisor的startSpecificActivityLocked方法

```java

void startSpecificActivityLocked(ActivityRecord r,
            boolean andResume, boolean checkConfig) {
    ....
    //进程存在则启动
    if (app != null && app.thread != null) {
        realStartActivityLocked(r, app, andResume, checkConfig);
        return;
    }
    
    //进程不存在则创建
    mService.startProcessLocked(r.processName, r.info.applicationInfo, true, 0,
            "activity", r.intent.getComponent(), false, false, true);
}

```

这里会判断一下进程是否存在,如果不存在则创建一下.这里的mService是AMS,会调用AMS的startProcessLocked方法.

```java
final ProcessRecord startProcessLocked(String processName,
            ApplicationInfo info, boolean knownToBeDead, int intentFlags,
        String hostingType, ComponentName hostingName, boolean allowWhileBooting,
        boolean isolated, boolean keepIfLarge) {
    return startProcessLocked(processName, info, knownToBeDead, intentFlags, hostingType,
            hostingName, allowWhileBooting, isolated, 0 /* isolatedUid */, keepIfLarge,
            null /* ABI override */, null /* entryPoint */, null /* entryPointArgs */,
            null /* crashHandler */);
}

final ProcessRecord startProcessLocked(String processName, ApplicationInfo info,
        boolean knownToBeDead, int intentFlags, String hostingType, ComponentName hostingName,
        boolean allowWhileBooting, boolean isolated, int isolatedUid, boolean keepIfLarge,
        String abiOverride, String entryPoint, String[] entryPointArgs, Runnable crashHandler) {
    ......
    final boolean success = startProcessLocked(app, hostingType, hostingNameStr, abiOverride);
    ......
}

private final boolean startProcessLocked(ProcessRecord app,
        String hostingType, String hostingNameStr, String abiOverride) {
    return startProcessLocked(app, hostingType, hostingNameStr,
            false /* disableHiddenApiChecks */, abiOverride);
}

private final boolean startProcessLocked(ProcessRecord app, String hostingType,
            String hostingNameStr, boolean disableHiddenApiChecks, String abiOverride) {
    ......
    return startProcessLocked(hostingType, hostingNameStr, entryPoint, app, uid, gids,
            runtimeFlags, mountExternal, seInfo, requiredAbi, instructionSet, invokeWith,
            startTime);
    ......
}

private boolean startProcessLocked(String hostingType, String hostingNameStr, String entryPoint,
            ProcessRecord app, int uid, int[] gids, int runtimeFlags, int mountExternal,
            String seInfo, String requiredAbi, String instructionSet, String invokeWith,
            long startTime) {
    ......
    final ProcessStartResult startResult = startProcess(app.hostingType, entryPoint,
            app, app.startUid, gids, runtimeFlags, mountExternal, app.seInfo,
            requiredAbi, instructionSet, invokeWith, app.startTime);
    ......
}

private ProcessStartResult startProcess(String hostingType, String entryPoint,
        ProcessRecord app, int uid, int[] gids, int runtimeFlags, int mountExternal,
        String seInfo, String requiredAbi, String instructionSet, String invokeWith,
        long startTime) {
    ......
    startResult = Process.start(entryPoint,
            app.processName, uid, uid, gids, runtimeFlags, mountExternal,
            app.info.targetSdkVersion, seInfo, requiredAbi, instructionSet,
            app.info.dataDir, invokeWith,
            new String[] {PROC_START_SEQ_IDENT + app.startSeq});
    ......
}

```
这里AMS调用了很多层startProcessLocked,最终都会调用startProcess方法,然后通过Process调用start方法.

```java
public static final ProcessStartResult start(final String processClass,
                              final String niceName,
                              int uid, int gid, int[] gids,
                              int debugFlags, int mountExternal,
                              int targetSdkVersion,
                              String seInfo,
                              String abi,
                              String instructionSet,
                              String appDataDir,
                              String[] zygoteArgs) {
    return startViaZygote(processClass, niceName, uid, gid, gids,
            debugFlags, mountExternal, targetSdkVersion, seInfo,
            abi, instructionSet, appDataDir, zygoteArgs);
}

private static ProcessStartResult startViaZygote(final String processClass,
                              final String niceName,
                              final int uid, final int gid,
                              final int[] gids,
                              int debugFlags, int mountExternal,
                              int targetSdkVersion,
                              String seInfo,
                              String abi,
                              String instructionSet,
                              String appDataDir,
                              String[] extraArgs)
                              throws ZygoteStartFailedEx {
    ......           
    //如果需要,则打开Socket,用来和zygote通讯
    return zygoteSendArgsAndGetResult(openZygoteSocketIfNeeded(abi), argsForZygote);
}

private static Process.ProcessStartResult zygoteSendArgsAndGetResult(
        ZygoteState zygoteState, ArrayList<String> args)
        throws ZygoteStartFailedEx {
    ......
    final BufferedWriter writer = zygoteState.writer;
    final DataInputStream inputStream = zygoteState.inputStream;

    writer.write(Integer.toString(args.size()));
    writer.newLine();

    for (int i = 0; i < sz; i++) {
        String arg = args.get(i);
        writer.write(arg);
        writer.newLine();
    }

    writer.flush();

    // Should there be a timeout on this?
    Process.ProcessStartResult result = new Process.ProcessStartResult();

    // Always read the entire result from the input stream to avoid leaving
    // bytes in the stream for future process starts to accidentally stumble
    // upon.
    result.pid = inputStream.readInt();
    result.usingWrapper = inputStream.readBoolean();

    if (result.pid < 0) {
        throw new ZygoteStartFailedEx("fork() failed");
    }
    return result;
    ......
}

```

上一步拿到了zygoteState 现在进行通讯，首先通过一个一个参数write方法传输过去给zygote.zygote拿到这些参数就会给你创建好需要的进程.然后返回结果通过read读取出来。这里创建的进程就是APP的进程.zygote通过fork出子进程.

### 3.2 启动主线程

进程的入口,也就是被我们熟知的ActivityThread的main方法,这个方法思路异常清晰,非常简洁.当然,这里也是主线程的入口.

```java
public static void main(String[] args) {
    
    //分析1 主线程Looper安排上
    Looper.prepareMainLooper();

    ......
    //分析2  
    ActivityThread thread = new ActivityThread();
    thread.attach(false, startSeq);
    
    //分析3 死循环,接收主线程上的消息
    Looper.loop();

    throw new RuntimeException("Main thread loop unexpectedly exited");
}
```

其中分析1和分析3在[死磕Android_Handler机制你需要知道的一切](https://blog.csdn.net/xfhy_/article/details/90347636)已进行详细的描述讲解,这里不再赘述.

我们来分析一下第2点:

```java
final ApplicationThread mAppThread = new ApplicationThread();
private void attach(boolean system, long startSeq) {
    ......
    if (!system) {
        //这一步是获取AMS实例,上面已经出现过
        final IActivityManager mgr = ActivityManager.getService();
        //然后跨进程通信
        mgr.attachApplication(mAppThread, startSeq);
    } 
}
```

通过获取AMS,进行跨进程通信,调用AMS的attachApplication方法

```java
public final void attachApplication(IApplicationThread thread, long startSeq) {
    synchronized (this) {
        int callingPid = Binder.getCallingPid();
        final int callingUid = Binder.getCallingUid();
        final long origId = Binder.clearCallingIdentity();
        attachApplicationLocked(thread, callingPid, callingUid, startSeq);
        Binder.restoreCallingIdentity(origId);
    }
}

@GuardedBy("this")
private final boolean attachApplicationLocked(IApplicationThread thread,
        int pid, int callingUid, long startSeq) {

    ......
    //这里的thread就是ActivityThread中的ApplicationThread
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

    // See if the top visible activity is waiting to run in this process...
    //看一下是不是有需要运行的Activity
    if (normalMode) {
        try {
            if (mStackSupervisor.attachApplicationLocked(app)) {
                didSomething = true;
            }
        } catch (Exception e) {
            Slog.wtf(TAG, "Exception thrown launching activities in " + app, e);
            badApp = true;
        }
    }

    ......
    return true;
}

```

这里有2个需要注意的点

- 第一个是通过跨进程调用AMS的attachApplication方法,然后继续调用attachApplicationLocked方法,然而却又跨进程调用ActivityThread中的mAppThread(ApplicationThread)中的bindApplication方法.一看便知道是创建Application
- 第二个是开启第一个Activity,调用ActivityStackSupervisor的attachApplicationLocked方法.

### 3.3 创建Application

我们先来看ApplicationThread的bindApplication方法
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

    AppBindData data = new AppBindData();
    .......
    //主要就是发送一个消息
    sendMessage(H.BIND_APPLICATION, data);
}

void sendMessage(int what, Object obj) {
    sendMessage(what, obj, 0, 0, false);
}

private void sendMessage(int what, Object obj, int arg1, int arg2, boolean async) {
    if (DEBUG_MESSAGES) Slog.v(
        TAG, "SCHEDULE " + what + " " + mH.codeToString(what)
        + ": " + arg1 + " / " + obj);
    Message msg = Message.obtain();
    msg.what = what;
    msg.obj = obj;
    msg.arg1 = arg1;
    msg.arg2 = arg2;
    if (async) {
        msg.setAsynchronous(true);
    }
    //mH是一个Handler,发送了一个消息
    mH.sendMessage(msg);
}


 class H extends Handler {
        //先看看这个Handler的部分消息名称,一看就知道是干嘛的,什么绑定Application,绑定Service,停止Service什么的.这个Handler和这些组件的启动停止什么的,关系非常大.
        //其实这个Handler在API 28之前的时候消息更多,(API 28只是融合了一下,多个消息变成1个消息,还是会走到这个Handler),之前Activity的各种生命周期回调都有对应的消息名称里.现在是融合了.
        public static final int BIND_APPLICATION        = 110;
        public static final int EXIT_APPLICATION        = 111;
        public static final int RECEIVER                = 113;
        public static final int CREATE_SERVICE          = 114;
        public static final int SERVICE_ARGS            = 115;
        public static final int STOP_SERVICE            = 116;
        public static final int CONFIGURATION_CHANGED   = 118;
        public static final int CLEAN_UP_CONTEXT        = 119;
        public static final int GC_WHEN_IDLE            = 120;
        public static final int BIND_SERVICE            = 121;
        public static final int RELAUNCH_ACTIVITY = 160;
}
```
在ApplicationThread的bindApplication中会调用sendMessage(该方法是ActivityThread中的,因为ApplicationThread是内部类,所以可以调用)方法发送一条消息,通过H(这个类是ActivityThread的内部类)这个Handler进行接收消息.因为ApplicationThread是运行在Binder线程池中,所以需要切换到主线程中进行一些UI上的操作,比如开启Activity什么的.最后会来到H的BIND_APPLICATION消息处

```java
public void handleMessage(Message msg) {
    switch (msg.what) {
        case BIND_APPLICATION:
            AppBindData data = (AppBindData)msg.obj;
            handleBindApplication(data);
            break;
        ......
    }
}

private void handleBindApplication(AppBindData data) {

    // Continue loading instrumentation.
    if (ii != null) {
        ApplicationInfo instrApp;
        instrApp = getPackageManager().getApplicationInfo(ii.packageName, 0,
                UserHandle.myUserId());
        //构建ContextImpl
        final ContextImpl instrContext = ContextImpl.createAppContext(this, pi);
        //获取其classLoader
        final ClassLoader cl = instrContext.getClassLoader();
        //构建Instrumentation 
        mInstrumentation = (Instrumentation)
            cl.loadClass(data.instrumentationName.getClassName()).newInstance();
    } else {
        mInstrumentation = new Instrumentation();
        mInstrumentation.basicInit(this);
    }

    Application app;
    // If the app is being launched for full backup or restore, bring it up in
    // a restricted environment with the base application class.
    //构建Application
    app = data.info.makeApplication(data.restrictedBackupMode, null);

    //调用Application的onCreate方法
    mInstrumentation.callApplicationOnCreate(app);
}

//sources/android-28/android/app/LoadedApk.java#makeApplication
public Application makeApplication(boolean forceDefaultAppClass,
        Instrumentation instrumentation) {
    //注意,如果Application已经初始化,那么就不重新初始化了  
    if (mApplication != null) {
        return mApplication;
    }

    Application app = null;

    String appClass = mApplicationInfo.className;
    if (forceDefaultAppClass || (appClass == null)) {
        appClass = "android.app.Application";
    }
    //构建Application
    app = mActivityThread.mInstrumentation.newApplication(
            cl, appClass, appContext);
    appContext.setOuterContext(app);

    return app;
}

//sources/android-28/android/app/Instrumentation.java#newApplication
public Application newApplication(ClassLoader cl, String className, Context context)
        throws InstantiationException, IllegalAccessException, 
        ClassNotFoundException {
    //通过反射构建Application
    Application app = getFactory(context.getPackageName())
            .instantiateApplication(cl, className);
    //赋值Context
    app.attach(context);
    return app;
}
public @NonNull Application instantiateApplication(@NonNull ClassLoader cl,
        @NonNull String className)
        throws InstantiationException, IllegalAccessException, ClassNotFoundException {
    return (Application) cl.loadClass(className).newInstance();
}
```

在H这个Handler中处理BIND_APPLICATION这个消息,首先是通过ClassLoader加载构建Instrumentation对象,然后通过LoadedApk调用Instrumentation的newApplication 方法(这里有点奇怪,为什么不用构建出来的mInstrumentation直接调用newApplication方法..),通过loadClass的方式将Application对象创建出来,然后调用Application的onCreate生命周期方法.

### 3.4 创建Activity

下面我们继续ActivityStackSupervisor的attachApplicationLocked方法

```java
boolean attachApplicationLocked(ProcessRecord app) throws RemoteException {
    ......
    realStartActivityLocked(activity, app,top == activity, true);
    ......
}

final boolean realStartActivityLocked(ActivityRecord r, ProcessRecord app,
            boolean andResume, boolean checkConfig) throws RemoteException {
    ......
    // Create activity launch transaction.
    //创建活动启动事务。
    final ClientTransaction clientTransaction = ClientTransaction.obtain(app.thread,
            r.appToken);
    //构建LaunchActivityItem对象,并传入clientTransaction中,用作callback
    clientTransaction.addCallback(LaunchActivityItem.obtain(new Intent(r.intent),
            System.identityHashCode(r), r.info,
            // TODO: Have this take the merged configuration instead of separate global
            // and override configs.
            mergedConfiguration.getGlobalConfiguration(),
            mergedConfiguration.getOverrideConfiguration(), r.compat,
            r.launchedFromPackage, task.voiceInteractor, app.repProcState, r.icicle,
            r.persistentState, results, newIntents, mService.isNextTransitionForward(),
            profilerInfo));

    // Schedule transaction.
    //执行事务  这里getLifecycleManager获取的是ClientLifecycleManager
    mService.getLifecycleManager().scheduleTransaction(clientTransaction);
    ......
}

//ClientLifecycleManager#scheduleTransaction
void scheduleTransaction(ClientTransaction transaction) throws RemoteException {
    //继续深入
    transaction.schedule();
}

//ClientTransaction#schedule
public void schedule() throws RemoteException {
    //这里的mClient是ApplicationThread
    mClient.scheduleTransaction(this);
}

//ApplicationThread#scheduleTransaction
@Override
public void scheduleTransaction(ClientTransaction transaction) throws RemoteException {
    //ActivityThread是继承自ClientTransactionHandler的,scheduleTransaction方法在ClientTransactionHandler里面
    ActivityThread.this.scheduleTransaction(transaction);
}

//ClientTransactionHandler#scheduleTransaction
void scheduleTransaction(ClientTransaction transaction) {
    transaction.preExecute(this);
    //注意啦,这里向ActivityThread里面的H这个Handler发送了一个EXECUTE_TRANSACTION的消息,并且将ClientTransaction对象也传了进去
    sendMessage(ActivityThread.H.EXECUTE_TRANSACTION, transaction);
}
//ClientTransactionHandler#sendMessage   这个方法是抽象方法,是在ActivityThread里面实现的,当然是给H这个Handler发消息啦
abstract void sendMessage(int what, Object obj);

```

在Android8.0中，是通过ApplicationThread.scheduleLaunchActivity()对相关数据进行封装，然后通过调用ActivityThread类的sendMessage()发送出去。
但是在Android9.0中，引入了ClientLifecycleManager和ClientTransactionHandler来辅助管理Activity生命周期。 相当于将生命周期抽象了出来,一个生命周期取而代之的是一个对象.

通过上面方法调用的辗转反侧,最后来到了ClientTransactionHandler的scheduleTransaction方法,然后向ActivityThread的H发送了一个`EXECUTE_TRANSACTION`消息.
在API 28里面,ActivityThread的H这个Handler里面已经没了之前的那些什么`LAUNCH_ACTIVITY`、`PAUSE_ACTIVITY`、`RESUME_ACTIVITY`这些消息了,取而代之的是`EXECUTE_TRANSACTION`这一个消息.

```java
//ActivityThread里面的H  
private final TransactionExecutor mTransactionExecutor = new TransactionExecutor(this);  //这里传入的是ClientTransactionHandler对象(即ActivityThread),ClientTransactionHandler是ActivityThread的父类
class H extends Handler {
    public void handleMessage(Message msg) {
        switch (msg.what) {
            case EXECUTE_TRANSACTION:
                //首先取出ClientTransaction对象
                final ClientTransaction transaction = (ClientTransaction) msg.obj;
                //将ClientTransaction传入execute方法
                mTransactionExecutor.execute(transaction);
        }
    }
}

//TransactionExecutor#execute
public void execute(ClientTransaction transaction) {
    final IBinder token = transaction.getActivityToken();
    log("Start resolving transaction for client: " + mTransactionHandler + ", token: " + token);

    executeCallbacks(transaction);

    executeLifecycleState(transaction);
    mPendingActions.clear();
    log("End resolving transaction");
}

//TransactionExecutor#executeCallbacks
public void executeCallbacks(ClientTransaction transaction) {
    //取出ClientTransaction对象里面的callback,即上面的LaunchActivityItem
    final List<ClientTransactionItem> callbacks = transaction.getCallbacks();

    final int size = callbacks.size();
    for (int i = 0; i < size; ++i) {
        final ClientTransactionItem item = callbacks.get(i);
        final int postExecutionState = item.getPostExecutionState();
        final int closestPreExecutionState = mHelper.getClosestPreExecutionState(r,
                item.getPostExecutionState());

        item.execute(mTransactionHandler, token, mPendingActions);
        item.postExecute(mTransactionHandler, token, mPendingActions);
    }
}

//LaunchActivityItem#execute
@Override
public void execute(ClientTransactionHandler client, IBinder token,
        PendingTransactionActions pendingActions) {
    //调用ActivityThread的handleLaunchActivity方法
    client.handleLaunchActivity(r, pendingActions, null);
}

```

在ActivityThread中的`EXECUTE_TRANSACTION`消息中,执行了TransactionExecutor对象的execute方法,然后在里面我们执行了executeCallbacks方法.在executeCallbacks方法里面拿出ClientTransaction对象的callback,即上面存进去的LaunchActivityItem.
再执行LaunchActivityItem的execute方法,调用的是ActivityThread的handleLaunchActivity方法,终于来到了我们熟悉的环节.

```java
//ActivityThread#handleLaunchActivity
@Override
public Activity handleLaunchActivity(ActivityClientRecord r,
        PendingTransactionActions pendingActions, Intent customIntent) {
    .....
    //终于要开始调用performLaunchActivity这个熟悉的方法了
    final Activity a = performLaunchActivity(r, customIntent);
    ......
}

//ActivityThread#performLaunchActivity
private Activity performLaunchActivity(ActivityClientRecord r, Intent customIntent) {
    ......
    ContextImpl appContext = createBaseContextForActivity(r);
    Activity activity = null;

    //获取ClassLoader
    java.lang.ClassLoader cl = appContext.getClassLoader();
    
    //通过(Activity) cl.loadClass(className).newInstance()创建
    //重点来啦:Activity是在ActivityThread的performLaunchActivity方法中用ClassLoader类加载器创建出来的。
    activity = mInstrumentation.newActivity(cl, component.getClassName(), r.intent);
    
    //底层也是通过反射构建Application,如果已经构建则不会重复构建,毕竟一个进程只能有一个Application
    Application app = r.packageInfo.makeApplication(false, mInstrumentation);

    if (activity != null) {
        Window window = null;
        appContext.setOuterContext(activity);
        //在这里实例化了PhoneWindow,并将该Activity设置为PhoneWindow的Callback回调,还初始化了WindowManager
        activity.attach(appContext, this, getInstrumentation(), r.token,
                r.ident, app, r.intent, r.activityInfo, title, r.parent,
                r.embeddedID, r.lastNonConfigurationInstances, config,
                r.referrer, r.voiceInteractor, window, r.configCallback);
                
        //间接调用了Activity的performCreate方法,间接调用了Activity的onCreate方法.
        mInstrumentation.callActivityOnCreate(activity, r.state);
        
        //这里和上面onCreate过程差不多,调用Activity的onStart方法
        if (!r.activity.mFinished) {
            activity.performStart();
            r.stopped = false;
        }
        ....
    }

    return activity;
}

```

这个流程就比较熟悉了,重点是:** Activity是在ActivityThread的performLaunchActivity方法中用ClassLoader类加载器创建出来的。** 创建出来之后就会调用Activity的onCreate方法和onStart方法.

关于后面的Activity创建出来之后的View的绘制,请看[这里](https://blog.csdn.net/xfhy_/article/details/90270630)

### 参考

- [Launcher3--初识Launcher3](https://blog.csdn.net/dddxxxx/article/details/78708971 )
- [App 启动过程（含 Activity 启动过程） | 安卓 offer 收割基](https://blankj.com/2018/09/29/the-process-of-app-start/)
- [Android app启动流程：Process.start（3）](https://www.shennongblog.com/process-start/)
- [Android9.0 Activity启动流程分析（二）](https://blog.csdn.net/caiyu_09/article/details/84634599#23_PartIII_702)
- [Android Render(一)Activity窗口构成和绘制解析](http://www.voidcn.com/article/p-uppsxfco-bob.html)