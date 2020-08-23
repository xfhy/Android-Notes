
建议阅读本文之前先阅读[死磕Android_Service启动流程分析(一)](https://juejin.im/post/5d026bd8e51d4556dc29361c),因为有些内容是一致的,方便融合.

早期的时候,广播的特性被各种流氓APP利用.好多好多流氓APP监听比如打电话,收发短信,有些流氓APP甚至直接拦截短信,,当然那个年代早已是过去式了,应该是4.4以前吧,反正以前那会儿挺乱的.现在好多了,想要读取短信内容,难上加难,更不能拦截短信.除非是将APP设置成了默认应用,可以收到短信通知,而且也不能拦截这条广播.以前那会儿即使进程被杀了,只要注册了静态广播,都是能收到的.某些APP收到广播后,就自启,自启后就干些流氓的事情....

特别是Android 8.0之后,大部分的静态广播差不多都失效了.所以我们还是尽量用动态广播比较好,需要的时候注册,不需要的时候解注册.如果只是应用内自己和自己通信,那是么可以使用LocalBroadcastManager的,通信安全.

## 1. 简单回顾使用方式

定义一个简单的广播

```java
class StaticReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.e("xfhy", "我收到消息了")
    }
}
```

下面是**静态注册**

需要到清单文件中进行注册
```xml
<receiver
        android:name=".StaticReceiver"
        android:enabled="true"
        android:exported="true">
    <intent-filter>
        <action android:name="com.xfhy.staticreceiver"/>
    </intent-filter>
</receiver>
```

如果是动态注册,那么需要注册和解注册.

```java
//注册
val intentFilter = IntentFilter()
registerReceiver(myBroadcast, intentFilter)

//解注册
unregisterReceiver(myBroadcast)
```

注册之后,就可以发广播了
```java
val intent = Intent(applicationContext, StaticReceiver::class.java)
intent.action = "com.xfhy.staticreceiver"
sendBroadcast(intent)
```

## 2. 广播注册原理

> 由于现在基本都用动态广播了(不知道是不是....因为Android 8.0的限制),所以直接讲解动态广播的注册方式.静态注册的方式是通过PMS在应用安装的时候就注册好了,其他3个组件也是.

事不宜迟,我们从registerReceiver方法开始深入,来到ContextWrapper的registerReceiver方法.我们知道Activity是继承了ContextWrapper的.

```java
@Override
public Intent registerReceiver(
    BroadcastReceiver receiver, IntentFilter filter) {
    return mBase.registerReceiver(receiver, filter);
}
```
ContextWrapper几乎是不干实事的,全是交给mBase去做.而mBase是ContextImpl,在Service启动那篇文章中已讲解.

```java
@Override
public Intent registerReceiver(BroadcastReceiver receiver, IntentFilter filter) {
    return registerReceiver(receiver, filter, null, null);
}
@Override
public Intent registerReceiver(BroadcastReceiver receiver, IntentFilter filter,
        String broadcastPermission, Handler scheduler) {
    return registerReceiverInternal(receiver, getUserId(),
            filter, broadcastPermission, scheduler, getOuterContext(), 0);
}
private Intent registerReceiverInternal(BroadcastReceiver receiver, int userId,
        IntentFilter filter, String broadcastPermission,
        Handler scheduler, Context context, int flags) {
    IIntentReceiver rd = null;
    if (receiver != null) {
        if (mPackageInfo != null && context != null) {
            if (scheduler == null) {
                scheduler = mMainThread.getHandler();
            }
            rd = mPackageInfo.getReceiverDispatcher(
                receiver, context, scheduler,
                mMainThread.getInstrumentation(), true);
        } else {
            if (scheduler == null) {
                scheduler = mMainThread.getHandler();
            }
            rd = new LoadedApk.ReceiverDispatcher(
                    receiver, context, scheduler, null, true).getIIntentReceiver();
        }
    }
    try {
        final Intent intent = ActivityManager.getService().registerReceiver(
                mMainThread.getApplicationThread(), mBasePackageName, rd, filter,
                broadcastPermission, userId, flags);
        if (intent != null) {
            intent.setExtrasClassLoader(getClassLoader());
            intent.prepareToEnterProcess();
        }
        return intent;
    } catch (RemoteException e) {
        throw e.rethrowFromSystemServer();
    }
}
```
最终会调用registerReceiverInternal方法.而这里有一个IIntentReceiver对象,需要注意.由于在注册的时候是向AMS发起请求需要注册,而BroadcastReceiver是不能进行跨进程传输的,所以需要一个介质.而IIntentReceiver就是专门拿来与AMS通信的,它是一个Binder对象.这里的ReceiverDispatcher和[Service绑定流程](https://juejin.im/post/5d050c106fb9a07ecb0ba66f)那里的ServiceDispatcher简直一模一样.ReceiverDispatcher里面有BroadcastReceiver和IIntentReceiver对象,都是在ReceiverDispatcher的构造方法就初始化好了,当收到广播的时候直接调用BroadcastReceiver对象的onReceive方法,简单方便.

来来来,我们看下LoadedApk的getReceiverDispatcher方法
```java

//缓存  
private final ArrayMap<Context, ArrayMap<BroadcastReceiver, ReceiverDispatcher>> mReceivers
        = new ArrayMap<>();

public IIntentReceiver getReceiverDispatcher(BroadcastReceiver r,
    Context context, Handler handler,
    Instrumentation instrumentation, boolean registered) {
    synchronized (mReceivers) {
        LoadedApk.ReceiverDispatcher rd = null;
        ArrayMap<BroadcastReceiver, LoadedApk.ReceiverDispatcher> map = null;
        
        //如果是已经注册  有缓存则用缓存
        if (registered) {
            map = mReceivers.get(context);
            if (map != null) {
                rd = map.get(r);
            }
        }
        
        //第一次
        if (rd == null) {
            //ReceiverDispatcher初始化,这里会将BroadcastReceiver放进去,然后构造方法会将InnerReceiver(用来跨进程通信的)初始化
            rd = new ReceiverDispatcher(r, context, handler,
                    instrumentation, registered);
            if (registered) {
                if (map == null) {
                    map = new ArrayMap<BroadcastReceiver, LoadedApk.ReceiverDispatcher>();
                    mReceivers.put(context, map);
                }
                map.put(r, rd);
            }
        } else {
            rd.validate(context, handler);
        }
        rd.mForgotten = false;
        return rd.getIIntentReceiver();
    }
}
```

谷歌工程师写的代码就是牛批,原理几乎一毛一样.

![image](24F8393F450D4DA19186A095A738A345)  

好了,当IIntentReceiver创建好了之后,就可以和AMS进行通信了.上面的ActivityManager.getService()就是AMS哈,在之前的文章经常提到.来到AMS的registerReceiver方法

```java

final HashMap<IBinder, ReceiverList> mRegisteredReceivers = new HashMap<>();

public Intent registerReceiver(IApplicationThread caller, String callerPackage,
IIntentReceiver receiver, IntentFilter filter, String permission, int userId,
int flags) {
    ...... 
    mRegisteredReceivers.put(receiver.asBinder(), rl);
    BroadcastFilter bf = new BroadcastFilter(filter, rl, callerPackage,
                    permission, callingUid, userId, instantApp, visibleToInstantApps);
    mReceiverResolver.addFilter(bf);
}
```
上面这个过程会把InnerReceiver(待会儿需要拿来跨进程通信的)和IntentFilter存起来,其实广播的注册就完成了.

## 3. 广播发送和接收原理

通过sendBroadcast方法发送广播,其实就是在调用的父类ContextWrapper的sendBroadcast方法,之前我们分析过,ContextWrapper本身是不干啥实事的,它其实是调用的ContextImpl的sendBroadcast方法.

```java
@Override
public void sendBroadcast(Intent intent) {
    warnIfCallingFromSystemProcess();
    String resolvedType = intent.resolveTypeIfNeeded(getContentResolver());
    intent.prepareToLeaveProcess(this);
    ActivityManager.getService().broadcastIntent(
            mMainThread.getApplicationThread(), intent, resolvedType, null,
            Activity.RESULT_OK, null, null, null, AppOpsManager.OP_NONE, null, false, false,
            getUserId());
}
```

ActivityManager.getService()是AMS哈,分析过很多次了.这里调用了AMS的broadcastIntent方法

```java
public final int broadcastIntent(IApplicationThread caller,
        Intent intent, String resolvedType, IIntentReceiver resultTo,
        int resultCode, String resultData, Bundle resultExtras,
        String[] requiredPermissions, int appOp, Bundle bOptions,
        boolean serialized, boolean sticky, int userId) {
    enforceNotIsolatedCaller("broadcastIntent");
    synchronized(this) {
        intent = verifyBroadcastLocked(intent);

        final ProcessRecord callerApp = getRecordForAppLocked(caller);
        final int callingPid = Binder.getCallingPid();
        final int callingUid = Binder.getCallingUid();
        final long origId = Binder.clearCallingIdentity();
        int res = broadcastIntentLocked(callerApp,
                callerApp != null ? callerApp.info.packageName : null,
                intent, resolvedType, resultTo, resultCode, resultData, resultExtras,
                requiredPermissions, appOp, bOptions, serialized, sticky,
                callingPid, callingUid, userId);
        Binder.restoreCallingIdentity(origId);
        return res;
    }
}
```

上面最核心的就是broadcastIntentLocked方法了,当我看到这个方法的行数时,我傻眼了,,,大家感受一下.600多行的代码,,,,


![image](07F381AC60394EBE92A27F1EBDD2E6D6)

我们挑选核心的代码来分析

```java
@GuardedBy("this")
final int broadcastIntentLocked(ProcessRecord callerApp,
    String callerPackage, Intent intent, String resolvedType,
    IIntentReceiver resultTo, int resultCode, String resultData,
    Bundle resultExtras, String[] requiredPermissions, int appOp, Bundle bOptions,
    boolean ordered, boolean sticky, int callingPid, int callingUid, int userId) {
        
    // By default broadcasts do not go to stopped apps.
    //已经停止的APP 无法收到广播
    intent.addFlags(Intent.FLAG_EXCLUDE_STOPPED_PACKAGES);   
    
    final BroadcastQueue queue = broadcastQueueForIntent(intent);
    BroadcastRecord r = new BroadcastRecord(queue, intent, callerApp,
            callerPackage, callingPid, callingUid, callerInstantApp, resolvedType,
            requiredPermissions, appOp, brOptions, registeredReceivers, resultTo,
            resultCode, resultData, resultExtras, ordered, sticky, false, userId);
    if (DEBUG_BROADCAST) Slog.v(TAG_BROADCAST, "Enqueueing parallel broadcast " + r);
    final boolean replaced = replacePending
            && (queue.replaceParallelBroadcastLocked(r) != null);
    // Note: We assume resultTo is null for non-ordered broadcasts.
    if (!replaced) {
        //将符合条件的广播,添加到BroadcastQueue中,然后进行发送
        queue.enqueueParallelBroadcastLocked(r);
        queue.scheduleBroadcastsLocked();
    }
    
}

```

我们在源码中可以看到,已经停止了的APP是收不到广播的.然后就是经过一系列的复杂的筛选过程,将符合条件的广播添加到
BroadcastQueue中,然后进行发送广播.

```java
public void scheduleBroadcastsLocked() {    
    ......
    //发送了一个消息
    mHandler.sendMessage(mHandler.obtainMessage(BROADCAST_INTENT_MSG, this));
}

private final class BroadcastHandler extends Handler {
    @Override
    public void handleMessage(Message msg) {
        switch (msg.what) {
            case BROADCAST_INTENT_MSG: {
                if (DEBUG_BROADCAST) Slog.v(
                        TAG_BROADCAST, "Received BROADCAST_INTENT_MSG");
                processNextBroadcast(true);
            } break;
        }
    }
}

final void processNextBroadcast(boolean fromMsg) {
    synchronized (mService) {
        processNextBroadcastLocked(fromMsg, false);
    }
}


 final ArrayList<BroadcastRecord> mParallelBroadcasts = new ArrayList<>();
final void processNextBroadcastLocked(boolean fromMsg, boolean skipOomAdj) {
    ......
    while (mParallelBroadcasts.size() > 0) {
        r = mParallelBroadcasts.remove(0);
        r.dispatchTime = SystemClock.uptimeMillis();
        r.dispatchClockTime = System.currentTimeMillis();

        final int N = r.receivers.size();

        for (int i=0; i<N; i++) {
            Object target = r.receivers.get(i);
            //发送广播这里的r是BroadcastRecord,这个方法里面会调用performReceiveLocked方法
            deliverToRegisteredReceiverLocked(r, (BroadcastFilter)target, false, i);
        }
        addBroadcastToHistoryLocked(r);
    }
}

//具体的发送过程
void performReceiveLocked(ProcessRecord app, IIntentReceiver receiver,
        Intent intent, int resultCode, String data, Bundle extras,
        boolean ordered, boolean sticky, int sendingUser) throws RemoteException {
    // Send the intent to the receiver asynchronously using one-way binder calls.
    if (app != null) {
        if (app.thread != null) {
            try {
                //调用ApplicationThread中的scheduleRegisteredReceiver方法
                app.thread.scheduleRegisteredReceiver(receiver, intent, resultCode,
                        data, extras, ordered, sticky, sendingUser, app.repProcState);
            } catch (RemoteException ex) {
                synchronized (mService) {
                    Slog.w(TAG, "Can't deliver broadcast to " + app.processName
                            + " (pid " + app.pid + "). Crashing it.");
                    app.scheduleCrash("can't deliver broadcast");
                }
                throw ex;
            }
        } else {
            // Application has died. Receiver doesn't exist.
            throw new RemoteException("app.thread must not be null");
        }
    } else {
        receiver.performReceive(intent, resultCode, data, extras, ordered,
                sticky, sendingUser);
    }
}

```

辗转反侧,会去调用ApplicationThread的scheduleRegisteredReceiver方法,

```java
public void scheduleRegisteredReceiver(IIntentReceiver receiver, Intent intent,
        int resultCode, String dataStr, Bundle extras, boolean ordered,
        boolean sticky, int sendingUser, int processState) throws RemoteException {
    updateProcessState(processState, false);
    receiver.performReceive(intent, resultCode, dataStr, extras, ordered,
            sticky, sendingUser);
}
```

注意,上面的IIntentReceiver是ReceiverDispatcher中的InnerReceiver对象,这个对象是拿来跨进程通信的.直接调用了InnerReceiver的performReceive方法,来看一下

```java
@Override
public void performReceive(Intent intent, int resultCode, String data,
        Bundle extras, boolean ordered, boolean sticky, int sendingUser) {
    final LoadedApk.ReceiverDispatcher rd;
    if (intent == null) {
        Log.wtf(TAG, "Null intent received");
        rd = null;
    } else {
        rd = mDispatcher.get();
    }


    rd.performReceive(intent, resultCode, data, extras,
        ordered, sticky, sendingUser);

}
```
其实performReceive就是调用ReceiverDispatcher的performReceive,ReceiverDispatcher是InnerReceiver和BroadcastReceiver的桥梁,因为它里面有两者的引用,可以和方便地进行调用其方法.下面是ReceiverDispatcher的实现

```java
public void performReceive(Intent intent, int resultCode, String data,
        Bundle extras, boolean ordered, boolean sticky, int sendingUser) {
    final Args args = new Args(intent, resultCode, data, extras, ordered,
            sticky, sendingUser);
    if (intent == null) {
        Log.wtf(TAG, "Null intent received");
    } else {
        if (ActivityThread.DEBUG_BROADCAST) {
            int seq = intent.getIntExtra("seq", -1);
            Slog.i(ActivityThread.TAG, "Enqueueing broadcast " + intent.getAction()
                    + " seq=" + seq + " to " + mReceiver);
        }
    }
    
    //注意这句代码  mActivityThread是一个Handler,主线程的Handler,
    if (intent == null || !mActivityThread.post(args.getRunnable())) {
        if (mRegistered && ordered) {
            IActivityManager mgr = ActivityManager.getService();
            if (ActivityThread.DEBUG_BROADCAST) Slog.i(ActivityThread.TAG,
                    "Finishing sync broadcast to " + mReceiver);
            args.sendFinished(mgr);
        }
    }
}
```

performReceice里面就是利用主线程中的Handler运行一个Runnable.内容如下:

```javas
public final Runnable getRunnable() {
    return () -> {
        final BroadcastReceiver receiver = mReceiver;
        final boolean ordered = mOrdered;

        final IActivityManager mgr = ActivityManager.getService();
        final Intent intent = mCurIntent;

        mCurIntent = null;
        mDispatched = true;
        mPreviousRunStacktrace = new Throwable("Previous stacktrace");
        if (receiver == null || intent == null || mForgotten) {
            if (mRegistered && ordered) {
                if (ActivityThread.DEBUG_BROADCAST) Slog.i(ActivityThread.TAG,
                        "Finishing null broadcast to " + mReceiver);
                sendFinished(mgr);
            }
            return;
        }

        Trace.traceBegin(Trace.TRACE_TAG_ACTIVITY_MANAGER, "broadcastReceiveReg");
        try {
            //注意了,BroadcastReceiver是在这个时候进行构建的,构建之后立刻调用它的onReceive方法,注意这是在主线程中调用的
            ClassLoader cl = mReceiver.getClass().getClassLoader();
            intent.setExtrasClassLoader(cl);
            intent.prepareToEnterProcess();
            setExtrasClassLoader(cl);
            receiver.setPendingResult(this);
            receiver.onReceive(mContext, intent);
        } catch (Exception e) {
            if (mRegistered && ordered) {
                if (ActivityThread.DEBUG_BROADCAST) Slog.i(ActivityThread.TAG,
                        "Finishing failed broadcast to " + mReceiver);
                sendFinished(mgr);
            }
            if (mInstrumentation == null ||
                    !mInstrumentation.onException(mReceiver, e)) {
                Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);
                throw new RuntimeException(
                        "Error receiving broadcast " + intent
                                + " in " + mReceiver, e);
            }
        }

        if (receiver.getPendingResult() != null) {
            finish();
        }
        Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);
    };
}
```
可以看到,BroadcastReceiver也是通过反射构建出来的,构建出来之后调用它的onReceive方法,并且是在主线程中调用的.

到这里,广播的发送和接收都已讲解完毕.
