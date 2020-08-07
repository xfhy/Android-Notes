
通过startService只能是把Service给启动起来,但是我们无法与其建立联系.通过bindService方式启动Service的话,不仅能启动Service,还能与其建立连接,相互调用比较方便.今天我们来理一理bindService其中的原理.

建议先看一下如下两篇文章,我按照顺序来写的,循序渐进.可能有些东西前面已经介绍了,后面就不再赘述,感谢理解.

- [死磕Android_App 启动过程（含 Activity 启动过程）](https://blog.csdn.net/xfhy_/article/details/90679525)
- [死磕Android_Service启动流程分析](https://blog.csdn.net/xfhy_/article/details/91907411)

## 1. 使用方式

简单回顾一下使用方式,就是在Activity里面调一下bindService方法,需要传入一个ServiceConnection.

```java
Intent intentService = new Intent(this,MyService.class);
bindService(intentService,mServiceConnection,BIND_AUTO_CREATE);
```

## 2. 源码分析

和startService类似,bindService也是调用的ContextImpl里面的方法.

```java
@Override
public boolean bindService(Intent service, ServiceConnection conn,
        int flags) {
    ...
    return bindServiceCommon(service, conn, flags, mMainThread.getHandler(), getUser());
}

private boolean bindServiceCommon(Intent service, ServiceConnection conn, int flags, Handler
        handler, UserHandle user) {
    
    IServiceConnection sd;
    
    //注意  ServiceConnection不能传入null,否则直接抛个异常给你
    if (conn == null) {
        throw new IllegalArgumentException("connection is null");
    }
    if (mPackageInfo != null) {
        //会走到这里来  生成一个IServiceConnection,它其实是一个ServiceDispatcher.InnerConnection,用来与Service建立连接的,与Service建立连接时可能会需要远程调用,那么ServiceConnection是不得行的.就需要ServiceDispatcher.InnerConnection来远程调用,然后再通知ServiceConnection.
        sd = mPackageInfo.getServiceDispatcher(conn, getOuterContext(), handler, flags);
    } else {
        throw new RuntimeException("Not supported in system context");
    }
    
    validateServiceIntent(service);
    try {
        //获取当前Activity的token
        IBinder token = getActivityToken();
        if (token == null && (flags&BIND_AUTO_CREATE) == 0 && mPackageInfo != null
                && mPackageInfo.getApplicationInfo().targetSdkVersion
                < android.os.Build.VERSION_CODES.ICE_CREAM_SANDWICH) {
            flags |= BIND_WAIVE_PRIORITY;
        }
        service.prepareToLeaveProcess(this);
        
        //好巧  又是我们所熟悉的AMS bindService也需要AMS参与
        int res = ActivityManager.getService().bindService(
            mMainThread.getApplicationThread(), getActivityToken(), service,
            service.resolveTypeIfNeeded(getContentResolver()),
            sd, flags, getOpPackageName(), user.getIdentifier());
        if (res < 0) {
            throw new SecurityException(
                    "Not allowed to bind to service " + service);
        }
        return res != 0;
    } catch (RemoteException e) {
        throw e.rethrowFromSystemServer();
    }
}

```

bindService是ContextImpl里面的方法,最终会调用到bindServiceCommon方法.bindServiceCommon方法首先将ServiceConnection转换成了一个ServiceDispatcher.InnerConnection(也就是上面的IServiceConnection sd).我们知道,绑定Service可能是跨进程的,所以需要跨进程通信,这里使用的是Binder方式.而这里的IServiceConnection其实是一个ServiceDispatcher.InnerConnection,而这里的ServiceDispatcher.InnerConnection是拿来跨进程通信的,因为ServiceConnection不能直接进行跨进程通信,所以需要ServiceDispatcher.InnerConnection来充当Binder的角色.然后ServiceDispatcher是连接InnerConnection和ServiceConnection的,InnerConnection是ServiceDispatcher的一个内部类.

上面的mPackageInfo是LoadedApk,跟进去看看getServiceDispatcher方法

```java
public final IServiceConnection getServiceDispatcher(ServiceConnection c,
        Context context, Handler handler, int flags) {
    synchronized (mServices) {
        //ServiceDispatcher是LoadedApk的内部类
        LoadedApk.ServiceDispatcher sd = null;
        
        //mServices是一个map,定义是private final ArrayMap<Context, ArrayMap<ServiceConnection, LoadedApk.ServiceDispatcher>> mServices
        = new ArrayMap<>();
        //它里面存放的是当前Activity与ServiceConnection和ServiceDispatcher的映射关系
        //如果之前有创建好的ServiceDispatcher,那么直接拿出来用,没有则创建一个
        ArrayMap<ServiceConnection, LoadedApk.ServiceDispatcher> map = mServices.get(context);
        if (map != null) {
            sd = map.get(c);
        }
        if (sd == null) {
            //创建一个ServiceDispatcher
            sd = new ServiceDispatcher(c, context, handler, flags);
            if (map == null) {
                map = new ArrayMap<>();
                //放入mServices进行缓存起来
                mServices.put(context, map);
            }
            map.put(c, sd);
        } else {
            sd.validate(context, handler);
        }
        
        //获取ServiceDispatcher中的InnerConnection对象
        return sd.getIServiceConnection();
    }
}
```

首先ServiceDispatcher是LoadedApk的内部类.系统将当前Activity与ServiceConnection和ServiceDispatcher的映射关系缓存起来了的,有需要的时候直接拿出来.当前第一次绑定的时候,肯定缓存起来没有,所以需要创建一个ServiceDispatcher.创建ServiceDispatcher的时候就会创建InnerConnection. 相当于ServiceDispatcher内部有ServiceConnection和InnerConnection,那么后面需要调用ServiceConnection里面的方法就比较方便了.


接着我们继续看AMS的绑定Service的过程,是调用的是AMS的bindService方法

```java
public int bindService(IApplicationThread caller, IBinder token, Intent service,
        String resolvedType, IServiceConnection connection, int flags, String callingPackage,
        int userId) throws TransactionTooLargeException {
    return mServices.bindServiceLocked(caller, token, service,
            resolvedType, connection, flags, callingPackage, userId);
}
```

mServices是ActiveServices,在startService源码分析中提到过,ActiveServices类是辅助AMS管理Service的,包括Service的启动、绑定和停止等.

上面是调用了ActiveServices的bindServiceLocked方法,bindServiceLocked再调
用bringUpServiceLocked,bringUpServiceLocked又会调用realStartServiceLocked方法，
realStartServiceLocked方法的执行逻辑和["死磕Android_Service启动流程分析"](https://blog.csdn.net/xfhy_/article/details/91907411)中的逻辑类似,最终都是通过
ApplicationThread来完成Service实例的创建并执行其onCreate方法,这里不再重复讲解了.

但是需要注意的是在realStartServiceLocked方法里面,当我们是bindService绑定Service的时候,需要关注一个东西

```java
private final void realStartServiceLocked(ServiceRecord r,
        ProcessRecord app, boolean execInFg) throws RemoteException {

    boolean created = false;
    
    //启动Service
    app.thread.scheduleCreateService(r, r.serviceInfo,
            mAm.compatibilityInfoForPackageLocked(r.serviceInfo.applicationInfo),
            app.repProcState);
    created = true;
    
    //深入
    requestServiceBindingsLocked(r, execInFg);
    ......
}

private final void requestServiceBindingsLocked(ServiceRecord r, boolean execInFg)
        throws TransactionTooLargeException {
    //深入
    requestServiceBindingLocked(r, ibr, execInFg, false);
}

private final boolean requestServiceBindingLocked(ServiceRecord r, IntentBindRecord i,
        boolean execInFg, boolean rebind) throws TransactionTooLargeException {
    
    //远程调用,执行ActivityThread中的scheduleBindService方法
    r.app.thread.scheduleBindService(r, i.intent.getIntent(), rebind,
            r.app.repProcState);
    return true;
}
```

在realStartServiceLocked方法里面调用了requestServiceBindingsLocked方法,requestServiceBindingsLocked方法调用了另一个requestServiceBindingLocked方法,然后远程调用ActivityThread的scheduleBindService方法.scheduleBindService方法从名字看,终于要开始执行绑定了

```java
public final void scheduleBindService(IBinder token, Intent intent,
        boolean rebind, int processState) {
    updateProcessState(processState, false);
    BindServiceData s = new BindServiceData();
    //注意  这里将Activity的token传过来了
    s.token = token;
    s.intent = intent;
    s.rebind = rebind;

    if (DEBUG_SERVICE)
        Slog.v(TAG, "scheduleBindService token=" + token + " intent=" + intent + " uid="
                + Binder.getCallingUid() + " pid=" + Binder.getCallingPid());
    sendMessage(H.BIND_SERVICE, s);
}
```

然后又来到了我们熟悉的H这个Handler,在H中BIND_SERVICE消息调用的是ActivityThread中的handleBindService()这个方法

```java
private void handleBindService(BindServiceData data) {
    //在handleCreateService方法里面将token和Service映射存入了mServices里面
    //mServices定义是final ArrayMap<IBinder, Service> mServices = new ArrayMap<>();
    //所以这里可以根据token取出Service
    Service s = mServices.get(data.token);
    if (s != null) {
        data.intent.setExtrasClassLoader(s.getClassLoader());
        data.intent.prepareToEnterProcess();
        
        if (!data.rebind) {
            //如果不是重新绑定
            
            //注意,这里调用了我们熟悉的Service的onBind方法,,,,就是在这里调用的哦,,,所以这里是UI线程哈,记住了
            IBinder binder = s.onBind(data.intent);
            //调用AMS的publishService方法
            ActivityManager.getService().publishService(
                    data.token, data.intent, binder);
        } else {
            s.onRebind(data.intent);
            ActivityManager.getService().serviceDoneExecuting(
                    data.token, SERVICE_DONE_EXECUTING_ANON, 0, 0);
        }
    }
}
```

在handleCreateService方法里面将token和Service映射存入了mServices里面,mServices定义是`final ArrayMap<IBinder, Service> mServices = new ArrayMap<>();`.所以那里可以根据token取出Service,然后紧接着调用了我们熟悉的Service的onBind方法,这里可以得出onBind方法是在UI线程执行的.还可以得出,重新绑定Service时,onBind方法只会调用一次,除非Service之前被终止了.onBind方法执行之后,说明Service已经成功连接了.

然后又来到了AMS,这次是AMS的publishService方法.

```java
public void publishService(IBinder token, Intent intent, IBinder service) {
    mServices.publishServiceLocked((ServiceRecord)token, intent, service);
}

//ActiveServices.java => publishServiceLocked
void publishServiceLocked(ServiceRecord r, Intent intent, IBinder service) {
    try {
        if (r != null) {
            for (int conni=r.connections.size()-1; conni>=0; conni--) {
                ArrayList<ConnectionRecord> clist = r.connections.valueAt(conni);
                for (int i=0; i<clist.size(); i++) {
                    ConnectionRecord c = clist.get(i);
                    //核心代码
                    c.conn.connected(r.name, service, false);
                }
            }

            serviceDoneExecutingLocked(r, mDestroyingServices.contains(r), false);
        }
    } finally {
        Binder.restoreCallingIdentity(origId);
    }
}

```
c.conn的类型是ServiceDispatcher.InnerConnection,service就是Service
的onBind方法返回的Binder对象.来看一下ServiceDispatcher.InnerConnection的connected方法

```java
private static class InnerConnection extends IServiceConnection.Stub {
    final WeakReference<LoadedApk.ServiceDispatcher> mDispatcher;

    InnerConnection(LoadedApk.ServiceDispatcher sd) {
        mDispatcher = new WeakReference<LoadedApk.ServiceDispatcher>(sd);
    }

    public void connected(ComponentName name, IBinder service, boolean dead)
            throws RemoteException {
        LoadedApk.ServiceDispatcher sd = mDispatcher.get();
        if (sd != null) {
            sd.connected(name, service, dead);
        }
    }
}
```

InnerConnection的构造方法里面就传入了ServiceDispatcher,所以可以很轻松拿到ServiceDispatcher,拿到ServiceDispatcher调用其connected方法

```java
public void connected(ComponentName name, IBinder service, boolean dead) {
    //mActivityThread其实就是ActivityThread中名为H的Handler
    if (mActivityThread != null) {
        //主线程中的Handler调用post  说明RunConnection是运行在主线程中
        mActivityThread.post(new RunConnection(name, service, 0, dead));
    } else {
        doConnected(name, service, dead);
    }
}

private final class RunConnection implements Runnable {
    RunConnection(ComponentName name, IBinder service, int command, boolean dead) {
        mName = name;
        mService = service;
        mCommand = command;
        mDead = dead;
    }

    public void run() {
        if (mCommand == 0) {
            //深入
            doConnected(mName, mService, mDead);
        } else if (mCommand == 1) {
            doDeath(mName, mService);
        }
    }

    final ComponentName mName;
    final IBinder mService;
    final int mCommand;
    final boolean mDead;
}

//ServiceDispatcher => doConnected
public void doConnected(ComponentName name, IBinder service, boolean dead) {
    ...
    //mConnection是ServiceDispatcher中的ServiceConnection,初始化ServiceDispatcher的时候就初始化了ServiceConnection
    mConnection.onServiceConnected(name, service);
    ...
}

```

通过ActivityThread中的Handler#post执行一个doConnected方法,而doConnected方法里面就是通过我们熟悉的ServiceConnection对象进行了onServiceConnected方法的回调.

可以看到ServiceDispatcher做了一个转接.当Service连接上之后,通过InnerConnection去远程调用ServiceDispatcher中的ServiceConnection中的onServiceConnected方法,完成绑定成功消息的通知.让客户端知道Service已绑定.

bindService也就分析完成了,其他比如
Service的停止过程和解除绑定的过程,系统的执行过程是类似的,这里留给大家自己去分析咯.
