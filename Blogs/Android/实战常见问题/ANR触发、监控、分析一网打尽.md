ANR线上监控学习
---
#### 目录
- [1. ANR是什么](#head1)
- [2. 导致ANR的原因](#head2)
- [3. 线下拿到ANR日志](#head3)
- [4. ANR场景](#head4)
- [5. ANR触发流程](#head5)
	- [5.1 Service、Broadcast、Provider触发ANR](#head6)
	- [5.2 Input触发ANR](#head7)
	- [5.3 哪些路径会引发ANR？](#head8)
	- [5.4 ANR dump主要流程](#head9)
- [6. ANR监控](#head10)
	- [6.1 WatchDog](#head11)
	- [6.2 监控SIGQUIT信号](#head12)
		- [6.2.1 完善的ANR监控方案](#head13)
			- [6.2.1.1 误报](#head14)
			- [6.2.1.2 漏报](#head15)
			- [6.2.1.3 获取ANR Trace](#head16)
- [7. ANR分析](#head17)
	- [7.1 trace文件分析](#head18)
	- [7.2 ANR案例分析](#head19)
		- [7.2.1 主线程无卡顿，处于正常状态堆栈](#head20)
		- [7.2.2 主线程执行耗时操作](#head21)
		- [7.2.3 主线程被锁阻塞](#head22)
		- [7.2.4 CPU被抢占](#head23)
		- [7.2.5 内存紧张导致ANR](#head24)
		- [7.2.6 系统服务超时导致ANR](#head25)
- [8. ANR影响因素](#head26)
- [9. 弥补不足](#head27)
- [10. QA](#head28)
	- [10.1 在Activity#onCreate中sleep会导致ANR吗？](#head29)
- [11. 小结](#head30)

---
> 仅做学习和记录，方案非原创。

## <span id="head1">1. ANR是什么</span>

ANR全称是Applicatipon No Response，Android设计ANR的用意，是系统通过与之交互的组件以及用户交互进行超时监控，用来判断应用进程是否存在卡死或响应过慢的问题，通俗来说就是很多系统中看门狗(watchdog)的设计思想。

## <span id="head2">2. 导致ANR的原因</span>

耗时操作导致ANR，并不一定是app的问题，实际上，有很大的概率是系统原因导致的ANR。下面简单分析一下哪些操作是应用层导致的ANR，哪些是系统导致的ANR。

应用层导致ANR：

- **函数阻塞：如死循环、主线程IO、处理大数据**
- **锁出错：主线程等待子线程的锁**
- **内存紧张：系统分配给一个应用的内存是有上限的，长期处于内存紧张，会导致频繁内存交换，进而导致应用的一些操作超时**

系统导致ANR：

- **CPU被抢占**：一般来说，前台在玩游戏，可能会导致你的后台广播被抢占
- **系统服务无法及时响应**：比如获取系统联系人等，系统的服务都是Binder机制，服务能力也是有限的，有可能系统服务长时间不响应导致ANR
- **其他应用占用大量内存**

## <span id="head3">3. 线下拿到ANR日志</span>

- adb pull /data/anr/
- adb bugreport

缺陷：

- 只能线下，用户反馈时，无法获取ANR日志
- 可能没有堆栈信息


## <span id="head4">4. ANR场景</span>

- Service Timeout:比如前台服务在20s内未执行完成，后台服务Timeout时间是前台服务的10倍，200s；
- BroadcastQueue Timeout：比如前台广播在10s内未执行完成，后台60s
- ContentProvider Timeout：内容提供者,在publish过超时10s;
- InputDispatching Timeout: 输入事件分发超时5s，包括按键和触摸事件。

```java
//ActiveServices.java
// How long we wait for a service to finish executing.
static final int SERVICE_BACKGROUND_TIMEOUT = SERVICE_TIMEOUT * 10;
// How long the startForegroundService() grace period is to get around to
// calling startForeground() before we ANR + stop it.
static final int SERVICE_START_FOREGROUND_TIMEOUT = 10*1000;

//ActivityManagerService.java
// How long we allow a receiver to run before giving up on it.
static final int BROADCAST_FG_TIMEOUT = 10*1000;
static final int BROADCAST_BG_TIMEOUT = 60*1000;
// How long we wait until we timeout on key dispatching.
static final int KEY_DISPATCHING_TIMEOUT = 5*1000;
```

## <span id="head5">5. ANR触发流程</span>

ANR触发流程大致可分为2种，一种是Service、Broadcast、Provider触发ANR，另外一种是Input触发ANR。

### <span id="head6">5.1 Service、Broadcast、Provider触发ANR</span>

大体流程可分为3个步骤：

1. 埋定时炸弹
2. 拆炸弹
3. 引爆炸弹

下面举个startService的例子，详细说说这3个步骤：

**1.埋定时炸弹**

在Activity中调用startService后，调用链：ContextImpl.startService()->ContextImpl.startServiceCommon()->ActivityManagerService.startService()->ActiveServices.startServiceLocked()->ActiveServices.startServiceInnerLocked()->ActiveServices.bringUpServiceLocked()->ActiveServices.realStartServiceLocked()

```java
//com.android.server.am.ActiveServices.java
private final void realStartServiceLocked(ServiceRecord r,
        ProcessRecord app, boolean execInFg) throws RemoteException {
    ......
    //发个延迟消息给AMS的Handler
    bumpServiceExecutingLocked(r, execInFg, "create");

    ......
    try {
        //IPC通知app进程启动Service，执行handleCreateService
        app.thread.scheduleCreateService(r, r.serviceInfo,
                mAm.compatibilityInfoForPackage(r.serviceInfo.applicationInfo),
                app.getReportedProcState());
    } catch (DeadObjectException e) {
    } finally {
    }
}

private final void bumpServiceExecutingLocked(ServiceRecord r, boolean fg, String why) {
    scheduleServiceTimeoutLocked(r.app);
    .....
}

final ActivityManagerService mAm;

// How long we wait for a service to finish executing.
static final int SERVICE_TIMEOUT = 20*1000;

// How long we wait for a service to finish executing.
static final int SERVICE_BACKGROUND_TIMEOUT = SERVICE_TIMEOUT * 10;

void scheduleServiceTimeoutLocked(ProcessRecord proc) {
    //mAm是AMS，mHandler是AMS里面的一个Handler
    Message msg = mAm.mHandler.obtainMessage(
            ActivityManagerService.SERVICE_TIMEOUT_MSG);
    msg.obj = proc;
    //发个延迟消息给AMS里面的一个Handler
    mAm.mHandler.sendMessageDelayed(msg,
            proc.execServicesFg ? SERVICE_TIMEOUT : SERVICE_BACKGROUND_TIMEOUT);
}
```

在startService流程中，在通知app进程启动Service之前，会进行预埋一个炸弹，也就是延迟发送一个消息给AMS的mHandler。当AMS的这个Handler收到`SERVICE_TIMEOUT_MSG`这个消息时，就认为Service超时了，触发ANR。也就是说，特定时间内，没人来拆这个炸弹，这个炸弹就会爆炸。

**2. 拆炸弹**

在AMS校验通过后，app这边可以启动Service，于是来到了ApplicationThread的scheduleCreateService方法，该方法是运行在binder线程里面的，所以得切到主线程去执行，也就是ActivityThread的handleCreateService方法：

```java
//android.app.ActivityThread.java
@UnsupportedAppUsage
private void handleCreateService(CreateServiceData data) {
    ......
    Service service = null;
    try {
        //1. 初始化Service
        ContextImpl context = ContextImpl.createAppContext(this, packageInfo);
        Application app = packageInfo.makeApplication(false, mInstrumentation);
        java.lang.ClassLoader cl = packageInfo.getClassLoader();
        service = packageInfo.getAppFactory()
                .instantiateService(cl, data.info.name, data.intent);
        ......
        service.attach(context, this, data.info.name, data.token, app,
                ActivityManager.getService());
        //2. Service执行onCreate，启动完成
        service.onCreate();
        mServices.put(data.token, service);
        try {
            //3. Service启动完成，需要通知AMS
            ActivityManager.getService().serviceDoneExecuting(
                    data.token, SERVICE_DONE_EXECUTING_ANON, 0, 0);
        } catch (RemoteException e) {
        }
    } catch (Exception e) {
    }
}
```

在app进程这边启动完Service之后，需要IPC通信告知AMS我这边已经启动完成了。AMS.serviceDoneExecuting()->ActiveServices.serviceDoneExecutingLocked()

```java
private void serviceDoneExecutingLocked(ServiceRecord r, boolean inDestroying,
        boolean finishing) {
    ......
    mAm.mHandler.removeMessages(ActivityManagerService.SERVICE_TIMEOUT_MSG, r.app);
    ......
}
```

很清晰，就是把之前延迟发送的`SERVICE_TIMEOUT_MSG`消息给移除掉，也就是拆炸弹。只要在规定的时间内把炸弹拆了，那就没事，要是没拆，炸弹就要爆炸，触发ANR。

**3. 引爆炸弹**

之前延迟给AMS的handler发送了一个消息，`mAm.mHandler.sendMessageDelayed(msg,proc.execServicesFg ? SERVICE_TIMEOUT : SERVICE_BACKGROUND_TIMEOUT);`，下面我们来看一下这条消息的逻辑

```java
//com.android.server.am.ActivityManagerService.java

final MainHandler mHandler;

final class MainHandler extends Handler {
    @Override
    public void handleMessage(Message msg) {
        switch (msg.what) {
        ......
        case SERVICE_TIMEOUT_MSG: {
            //这个mServices是ActiveServices
            mServices.serviceTimeout((ProcessRecord)msg.obj);
        } break;
        }
        ......
    }
    ......
}

//com.android.server.am.ActiveServices.java
void serviceTimeout(ProcessRecord proc) {
    String anrMessage = null;
    synchronized(mAm) {
        //计算是否有service超时
        final long now = SystemClock.uptimeMillis();
        final long maxTime =  now -
                (proc.execServicesFg ? SERVICE_TIMEOUT : SERVICE_BACKGROUND_TIMEOUT);
        ServiceRecord timeout = null;
        for (int i=proc.executingServices.size()-1; i>=0; i--) {
            ServiceRecord sr = proc.executingServices.valueAt(i);
            if (sr.executingStart < maxTime) {
                timeout = sr;
                break;
            }
        }
        if (timeout != null && mAm.mProcessList.mLruProcesses.contains(proc)) {
            anrMessage = "executing service " + timeout.shortInstanceName;
        }
    }

    if (anrMessage != null) {
        //有超时的Service,mAm是AMS，mAnrHelper是AnrHelper
        mAm.mAnrHelper.appNotResponding(proc, anrMessage);
    }
}
```

AMS这边如果收到了`SERVICE_TIMEOUT_MSG`消息，也就是超时了，没人来拆炸弹，那么它会让ActiveServices确认一下是否有Service超时，有的话，再利用AnrHelper来触发ANR。

```java
void appNotResponding(ProcessRecord anrProcess, String activityShortComponentName,
        ApplicationInfo aInfo, String parentShortComponentName,
        WindowProcessController parentProcess, boolean aboveSystem, String annotation) {
    //添加AnrRecord到List里面
    synchronized (mAnrRecords) {
        mAnrRecords.add(new AnrRecord(anrProcess, activityShortComponentName, aInfo,
                parentShortComponentName, parentProcess, aboveSystem, annotation));
    }
    startAnrConsumerIfNeeded();
}
private void startAnrConsumerIfNeeded() {
    if (mRunning.compareAndSet(false, true)) {
        //开个子线程来处理
        new AnrConsumerThread().start();
    }
}

private class AnrConsumerThread extends Thread {
    @Override
    public void run() {
        AnrRecord r;
        while ((r = next()) != null) {
            ......
            //这里的r就是AnrRecord
            r.appNotResponding(onlyDumpSelf);
            ......
        }
    }
}
private static class AnrRecord {
    void appNotResponding(boolean onlyDumpSelf) {
        //mApp是ProcessRecord
        mApp.appNotResponding(mActivityShortComponentName, mAppInfo,
                mParentShortComponentName, mParentProcess, mAboveSystem, mAnnotation,
                onlyDumpSelf);
    }
}
```

开了个子线程，然后调用ProcessRecord的appNotResponding方法来处理ANR的流程（弹出app无响应弹窗、dump堆栈什么的），具体流程下面会细说。到这里，炸弹就完全引爆了，触发了ANR。

### <span id="head7">5.2 Input触发ANR</span>

input的超时检测机制跟Service、Broadcast、Provider截然不同，并非时间到了就一定被爆炸，而是处理后续上报事件的过程才会去检测是否该爆炸，所以更像是扫雷的过程。

input超时机制为什么是扫雷，而非定时爆炸？由于对于input来说即便某次事件执行时间超过Timeout时长，只要用户后续没有再生成输入事件，则不会触发ANR。这里的扫雷是指当前输入系统中正在处理着某个耗时事件的前提下，后续的每一次input事件都会检测前一个正在处理的事件是否超时（进入扫雷状态），检测当前的时间距离上次输入事件分发时间点是否超过timeout时长。如果没有超过，则会重置anr的Timeout，从而不会爆炸。

### <span id="head8">5.3 哪些路径会引发ANR？</span>

从埋下炸弹到拆炸弹之间的任何一个或多个路径执行慢都会导致ANR。这里以Service为例，如：

- Service的生命周期的回调方法执行慢
- 主线程的消息队列存在其他耗时消息让Service回调方法迟迟得不到执行
- sp操作执行慢
- `system_server`进程的binder线程繁忙而导致没有及时收到拆炸弹的指令

### <span id="head9">5.4 ANR dump主要流程</span>

> ANR流程基本是在`system_server`系统进程完成的，系统进程的行为我们很难监控到，想要监控这个事情就得从系统进程与应用进程沟通的边界着手，看边界上有没有可以操作的地方。

不管是怎么发生的ANR，最后都会走到`appNotResponding` ，比如输入超时的路径

1. `ActivityManagerService#inputDispatchingTimedOut`
2. `AnrHelper#appNotResponding`
3. `AnrConsumerThread#run`
4. `AnrRecord#appNotResponding`
5. `ProcessRecord#appNotResponding`

那我们直接分析这个`appNotResponding` 方法：

```java
//com.android.server.am.ProcessRecord.java
void appNotResponding(String activityShortComponentName, ApplicationInfo aInfo,
        String parentShortComponentName, WindowProcessController parentProcess,
        boolean aboveSystem, String annotation, boolean onlyDumpSelf) {
    ArrayList<Integer> firstPids = new ArrayList<>(5);
    SparseArray<Boolean> lastPids = new SparseArray<>(20);

    mWindowProcessController.appEarlyNotResponding(annotation, () -> kill("anr",
                ApplicationExitInfo.REASON_ANR, true));

    long anrTime = SystemClock.uptimeMillis();
    if (isMonitorCpuUsage()) {
        mService.updateCpuStatsNow();
    }

    final boolean isSilentAnr;
    synchronized (mService) {
		//注释1
        // PowerManager.reboot() can block for a long time, so ignore ANRs while shutting down.
		//正在重启
        if (mService.mAtmInternal.isShuttingDown()) {
            Slog.i(TAG, "During shutdown skipping ANR: " + this + " " + annotation);
            return;
        } else if (isNotResponding()) {
			//已经处于ANR流程中
            Slog.i(TAG, "Skipping duplicate ANR: " + this + " " + annotation);
            return;
        } else if (isCrashing()) {
			//正在crash的状态
            Slog.i(TAG, "Crashing app skipping ANR: " + this + " " + annotation);
            return;
        } else if (killedByAm) {
			//app已经被killed
            Slog.i(TAG, "App already killed by AM skipping ANR: " + this + " " + annotation);
            return;
        } else if (killed) {
			//app已经死亡了
            Slog.i(TAG, "Skipping died app ANR: " + this + " " + annotation);
            return;
        }

        // In case we come through here for the same app before completing
        // this one, mark as anring now so we will bail out.
		//做个标记
        setNotResponding(true);

        // Log the ANR to the event log.
        EventLog.writeEvent(EventLogTags.AM_ANR, userId, pid, processName, info.flags,
                annotation);

        // Dump thread traces as quickly as we can, starting with "interesting" processes.
        firstPids.add(pid);

        // Don't dump other PIDs if it's a background ANR or is requested to only dump self.
		//注释2
		//沉默的anr : 这里表示后台anr
        isSilentAnr = isSilentAnr();
        if (!isSilentAnr && !onlyDumpSelf) {
            int parentPid = pid;
            if (parentProcess != null && parentProcess.getPid() > 0) {
                parentPid = parentProcess.getPid();
            }
            if (parentPid != pid) firstPids.add(parentPid);

            if (MY_PID != pid && MY_PID != parentPid) firstPids.add(MY_PID);
						
			//选择需要dump的进程
            for (int i = getLruProcessList().size() - 1; i >= 0; i--) {
                ProcessRecord r = getLruProcessList().get(i);
                if (r != null && r.thread != null) {
                    int myPid = r.pid;
                    if (myPid > 0 && myPid != pid && myPid != parentPid && myPid != MY_PID) {
                        if (r.isPersistent()) {
                            firstPids.add(myPid);
                            if (DEBUG_ANR) Slog.i(TAG, "Adding persistent proc: " + r);
                        } else if (r.treatLikeActivity) {
                            firstPids.add(myPid);
                            if (DEBUG_ANR) Slog.i(TAG, "Adding likely IME: " + r);
                        } else {
                            lastPids.put(myPid, Boolean.TRUE);
                            if (DEBUG_ANR) Slog.i(TAG, "Adding ANR proc: " + r);
                        }
                    }
                }
            }
        }
    }

    ......

    int[] pids = nativeProcs == null ? null : Process.getPidsForCommands(nativeProcs);
    ArrayList<Integer> nativePids = null;

    if (pids != null) {
        nativePids = new ArrayList<>(pids.length);
        for (int i : pids) {
            nativePids.add(i);
        }
    }

    // For background ANRs, don't pass the ProcessCpuTracker to
    // avoid spending 1/2 second collecting stats to rank lastPids.
    StringWriter tracesFileException = new StringWriter();
    // To hold the start and end offset to the ANR trace file respectively.
    final long[] offsets = new long[2];
	//注释4
    File tracesFile = ActivityManagerService.dumpStackTraces(firstPids,
            isSilentAnr ? null : processCpuTracker, isSilentAnr ? null : lastPids,
            nativePids, tracesFileException, offsets);
		......
}
```

代码比较长，我们一步一步来看。

注释1处首先是针对几种特殊情况：正在重启、已经处于ANR流程中、正在crash、app已经被killed和app已经死亡了，不用处理ANR，直接return。

注释2处isSilentAnr是表示当前是否为一个后台ANR，后台ANR跟前台ANR表现不同，前台ANR会弹出无响应的Dialog，后台ANR会直接杀死进程。什么是前台ANR：发生ANR的进程对用户来说有感知，就是前台ANR，否则就是后台ANR。

注释3处，选择需要dump的进程。发生ANR时，为了方便定位问题，会dump很多信息到Trace文件中。而Trace文件里包含着与ANR相关联的进程的Trace信息，因为产生ANR的原因有可能是其他的进程抢占了太多资源，或者IPC到其他进程的时候卡住导致的。需要被dump的进程分为3类：

- firstPids：firstPids是需要首先dump的重要进程，发生ANR的进程无论如何是一定要被dump的，也是首先被dump的，所以第一个被加到firstPids中。如果是SilentAnr（即后台ANR），不用再加入任何其他的进程。如果不是，需要进一步添加其他的进程：如果发生ANR的进程不是system_server进程的话，需要添加system_server进程；接下来轮询AMS维护的一个LRU的进程List，如果最近访问的进程包含了persistent的进程，或者带有 `*BIND_TREAT_LIKE_ACTVITY`* 标签的进程，都添加到firstPids中。
- extraPids：LRU进程List中的其他进程，都会首先添加到lastPids中，然后lastPids会进一步被选出最近CPU使用率高的进程，进一步组成extraPids；
- nativePids：nativePids最为简单，是一些固定的native的系统进程，定义在WatchDog.java中

注释4处，拿到需要dump的所有进程的pid后，AMS开始按照firstPids、nativePids、extraPids的顺序dump这些进程的堆栈。这里比较重要，我们需要跟进去看看具体做了什么。

```java
public static Pair<Long, Long> dumpStackTraces(String tracesFile, ArrayList<Integer> firstPids,
        ArrayList<Integer> nativePids, ArrayList<Integer> extraPids) {

    // 最多dump 20秒
    long remainingTime = 20 * 1000;

    // First collect all of the stacks of the most important pids.
    if (firstPids != null) {
        int num = firstPids.size();
        for (int i = 0; i < num; i++) {
            final int pid = firstPids.get(i);
            final long timeTaken = dumpJavaTracesTombstoned(pid, tracesFile, remainingTime);
            remainingTime -= timeTaken;
            if (remainingTime <= 0) {
                Slog.e(TAG, "Aborting stack trace dump (current firstPid=" + pid
                        + "); deadline exceeded.");
                return firstPidStart >= 0 ? new Pair<>(firstPidStart, firstPidEnd) : null;
            }
        }
    }
    ......
}
```

就是根据顺序取出前面传入的firstPids、`nativePids` 、`extraPids` 的pid，然后逐一去dump这些进程中所有的线程，当然这是一个非常重的操作，一个进程就有那么多线程，更别说这么多进程了。所以，这里规定了个最长dump时间为20秒，超过则及时返回，这样可以确保ANR弹窗可以及时弹出（或者被kill掉）。接下来我们接着跟进`dumpJavaTracesTombstoned`。经过一连串的逻辑：ActivityManagerService#dumpJavaTracesTombstoned() → Debug#dumpJavaBacktraceToFileTimeout() → android_os_Debug#android_os_Debug_dumpJavaBacktraceToFileTimeout() → android_os_Debug#dumpTraces() → debuggerd_client#dump_backtrace_to_file_timeout() → debuggerd_client#debuggerd_trigger_dump()。

```cpp
bool debuggerd_trigger_dump(pid_t tid, DebuggerdDumpType dump_type, unsigned int timeout_ms, unique_fd output_fd) {
    //pid是从AMS那边传过来的，即需要dump堆栈的进程
		pid_t pid = tid;
    //......

    // Send the signal.
		//从android_os_Debug_dumpJavaBacktraceToFileTimeout过来的，dump_type为kDebuggerdJavaBacktrace
    const int signal = (dump_type == kDebuggerdJavaBacktrace) ? SIGQUIT : BIONIC_SIGNAL_DEBUGGER;
    sigval val = {.sival_int = (dump_type == kDebuggerdNativeBacktrace) ? 1 : 0};
		//sigqueue：在队列中向指定进程发送一个信号和数据，成功返回0
    if (sigqueue(pid, signal, val) != 0) {
      log_error(output_fd, errno, "failed to send signal to pid %d", pid);
      return false;
    }
    //......
    LOG(INFO) << TAG "done dumping process " << pid;
    return true;
}
```

注意，这里相当于是AMS进程间接给需要dump堆栈那个进程发送了一个SIGQUIT信号，那个进程收到SIGQUIT信号之后便开始dump。这里也就是前面所说的边界。现在看起来是当一个进程发生ANR时，则会收到SIGQUIT信号。如果，我们能监控到系统发送的SIGQUIT信号，也许就能感知到发生了ANR，达到监控的目的。

关于进程信号的处理，这里简单提一下：除Zygote进程外，每个进程都会创建一个SignalCatcher守护线程，用于捕获SIGQUIT、SIGUSR1信号，并采取相应的行为。

```cpp
//art/runtime/signal_catcher.cc
void* SignalCatcher::Run(void* arg) {
  SignalCatcher* signal_catcher = reinterpret_cast<SignalCatcher*>(arg);
  CHECK(signal_catcher != nullptr);
  Runtime* runtime = Runtime::Current();
  //检查当前线程是否依附到Android Runtime
  CHECK(runtime->AttachCurrentThread("Signal Catcher", true, runtime->GetSystemThreadGroup(), !runtime->IsAotCompiler()));

  Thread* self = Thread::Current();
  DCHECK_NE(self->GetState(), kRunnable);
  {
    MutexLock mu(self, signal_catcher->lock_);
    signal_catcher->thread_ = self;
    signal_catcher->cond_.Broadcast(self);
  }

  SignalSet signals;
  signals.Add(SIGQUIT); //添加对信号SIGQUIT的处理
  signals.Add(SIGUSR1); //添加对信号SIGUSR1的处理
	
	//死循环，不断等待监听2个信号的dao'l
  while (true) {
    //等待信号到来，这是个阻塞操作
    int signal_number = signal_catcher->WaitForSignal(self, signals);
    //当信号捕获需要停止时，则取消当前线程跟Android Runtime的关联。
    if (signal_catcher->ShouldHalt()) {
      runtime->DetachCurrentThread();
      return nullptr;
    }
    switch (signal_number) {
    case SIGQUIT:
      signal_catcher->HandleSigQuit(); //输出线程trace
      break;
    case SIGUSR1:
      signal_catcher->HandleSigUsr1(); //强制GC
      break;
    default:
      LOG(ERROR) << "Unexpected signal %d" << signal_number;
      break;
    }
  }
}
```

在SignalCatcher线程里面，死循环，通过WaitForSignal监听SIGQUIT和SIGUSR1信号的到来，前面系统进程`system_server`进程发送的SIGQUIT信号也就是在这里被监听到，然后开始dump堆栈。

现在，我们整理一下整个ANR的流程：

1. 系统监控到app发生ANR后，收集了一些相关进程pid（包括发生ANR的进程），准备让这些进程dump堆栈，从而生成ANR Trace文件
2. 系统开始向这些进程发送SIGQUIT信号，进程收到SIGQUIT信号之后开始dump堆栈

整个过程的示意图：

![ANR流程示意图](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/ANR流程示意图.png)

> 图片转自微信客户端技术团队

可以看到，一个进程发生ANR之后的整个流程，只有dump堆栈的行为会发生在发生ANR的进程中，其他过程全在系统进程进行处理的，我们无法感知。这个过程从收到SIGQUIT信号开始到使用socket写Trace结束。然后继续回到系统进程完成剩余的ANR流程，这2个边界上我们可以做做文章。后面我们会详细叙述。

## <span id="head10">6. ANR监控</span>

Android M(6.0) 版本之后，应用侧无法直接通过监听 `data/anr/trace` 文件，监控是否发生 ANR。目前了解到的能用的方案主要有下面2种：

### <span id="head11">6.1 WatchDog</span>

开个子线程，不断往主线程发送消息，并设置超时检测，如果超时还没执行相应消息，则判定为可能发生ANR。需要进一步从系统服务获取相关数据（可通过ActivityManagerService.getProcessesInErrorState()方法获取进程的ANR信息），进一步判定是否真的发生了ANR。

这个方案对应的开源库为[ANR-WatchDog](https://github.com/SalomonBrys/ANR-WatchDog/)，源码比较简单，只有2个源文件。简单解析一下核心代码：

```java

private final Handler _uiHandler = new Handler(Looper.getMainLooper());
private final int _timeoutInterval;
private volatile long _tick = 0;
private volatile boolean _reported = false;

private final Runnable _ticker = new Runnable() {
    @Override public void run() {
        _tick = 0;
        _reported = false;
    }
};

@Override
public void run() {
    setName("|ANR-WatchDog|");

    //_timeoutInterval为设定的超时时长
    long interval = _timeoutInterval;
    while (!isInterrupted()) {
        //_tick为标志，主线程执行了下面发送的_ticker这个Runnable, 那么_tick就会被置为0
        boolean needPost = _tick == 0;
        //在子线程里面需要把标志改为非0，待会儿主线程执行了才知道
        _tick += interval;
        if (needPost) {
            //发个消息给主线程
            _uiHandler.post(_ticker);
        }

        //子线程睡一段时间，起来的时候要是标志位_tick没有被改成0，说明主线程太忙了，或者卡顿了，没来得及执行该消息
        try {
            Thread.sleep(interval);
        } catch (InterruptedException e) {
            _interruptionListener.onInterrupted(e);
            return ;
        }

        // If the main thread has not handled _ticker, it is blocked. ANR.
        if (_tick != 0 && !_reported) {
            //noinspection ConstantConditions
            //排除debug的情况
            if (!_ignoreDebugger && (Debug.isDebuggerConnected() || Debug.waitingForDebugger())) {
                Log.w("ANRWatchdog", "An ANR was detected but ignored because the debugger is connected (you can prevent this with setIgnoreDebugger(true))");
                _reported = true;
                continue ;
            }

            //可以自定义一个Interceptor告诉watchDog，当前上下文环境是否可以进行上报
            interval = _anrInterceptor.intercept(_tick);
            if (interval > 0) {
                continue;
            }

            //上报线程堆栈
            final ANRError error;
            if (_namePrefix != null) {
                error = ANRError.New(_tick, _namePrefix, _logThreadsWithoutStackTrace);
            } else {
                error = ANRError.NewMainOnly(_tick);
            }
            //回调
            _anrListener.onAppNotResponding(error);
            interval = _timeoutInterval;
            _reported = true;
        }
    }
}
```

核心代码非常简洁，基本上就是上面方案的实现了。有一点需要补充的是，需要进一步从系统服务获取相关数据（可通过ActivityManagerService.getProcessesInErrorState()方法获取进程的ANR信息，具体实现方式下面会详细说明），进一步判定是否真的发生了ANR。可以自定义一个`_anrInterceptor`，在里面实现这些内容。

### <span id="head12">6.2 监控SIGQUIT信号</span>

这种方案才是真正的监控ANR，matrix、xCrash都在使用这种方案。已经在国民应用微信等app上检验过，稳定性和可靠性都能得到保证。

在文章上面的ANR流程分析中，我们找到了系统与发生ANR进程之间的边界（即下图中的1和2）。我们能否监听到系统发送给我们的SIGQUIT信号呢？答案当然是可行的。

![ANR流程示意图](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/ANR流程示意图.png)

这里需要一点预备知识，首先我们得知道什么是SIGQUIT信号，前面我们提到了除Zygote进程以外的其他进程都有个Signal Catcher线程在不断地通过sigwait监听SIGQUIT信号，当收到SIGQUIT信号时开始dump线程堆栈。我们需要拦截或者监听SIGQUIT信号，首先需要了解信号处理的相关函数，如kill、signal、sigaction、sigwait、`pthread_sigmask`等，本文就不详细展开这些函数的具体使用了，如需详细了解，推荐阅读《UNIX环境高级编程》。

下面是我写的监控SIGQUIT信号demo的核心代码，[完整源码在这里]([https://github.com/xfhy/WatchSignalDemo/blob/master/app/src/main/cpp/native-lib.cpp](https://github.com/xfhy/WatchSignalDemo/blob/master/app/src/main/cpp/native-lib.cpp)):

```cpp
void signalHandler(int sig, siginfo_t *info, void *uc) {
    __android_log_print(ANDROID_LOG_DEBUG, "xfhy_anr", "我监听到SIGQUIT信号了,可能发生anr了");

    //在这里去dump主线程堆栈
}

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_xfhy_watchsignaldemo_MainActivity_startWatch(JNIEnv *env, jobject thiz) {
    sigset_t set, old_set;
    sigemptyset(&set);
    sigaddset(&set, SIGQUIT);
		
	/*
     * 这里需要调用SIG_UNBLOCK，因为目标进程被Zogyte fork出来的时候，主线程继承了
     * Zogyte的主线程的信号屏蔽关系，Zogyte主线程在初始化的时候，通过
     * pthread_sigmask SIG_BLOCK把SIGQUIT的信号给屏蔽了，因此我们需要在自己进程的主线程，
     * 设置pthread_sigmask SIG_UNBLOCK ，这会导致原来的SignalCatcher sigwait将失效，
     * 原因是SignalCatcher 线程会对SIGQUIT 信号处理
     */
    int r = pthread_sigmask(SIG_UNBLOCK, &set, &old_set);
    if (0 != r) {
        return false;
    }

    struct sigaction sa{};
    sa.sa_sigaction = signalHandler;
    sa.sa_flags = SA_ONSTACK | SA_SIGINFO | SA_RESTART;

    return sigaction(SIGQUIT, &sa, nullptr) == 0;
}
```

Android默认把SIGQUIT设置成了BLOCKED，所以只会响应Signal Catcher线程的sigwait监听SIGQUIT信号，我们用sigaction监听的则收不到，所以这里还需要处理一下。我们通过*pthread_sigmask*或者*sigprocmask*把SIGQUIT设置为UNBLOCK，那么再次收到SIGQUIT时，就一定会进入到我们的signalHandler方法中。

除了上面这个之外，还需要注意的是：我们用sigaction抢了Signal Catcher线程的SIGQUIT信号，那Signal Catcher线程就收不到该信号了，那原本的系统dump堆栈的流程就没了，这是不太合适的。所以我们需要将该信号重新发送出去，让Signal Catcher线程接收到该信号。

```cpp
int tid = getSignalCatcherThreadId(); //遍历/proc/[pid]目录，找到SignalCatcher线程的tid
tgkill(getpid(), tid, SIGQUIT);
```

以上，咱们得到了一个不改变系统行为的前提下，比较完善的监控SIGQUIT信号的机制，虽然不是特别完美，但这是监控ANR的基础。接下来我们慢慢完善。

#### <span id="head13">6.2.1 完善的ANR监控方案</span>

监控到SIGQUIT信号并不等于就监控到了ANR。

##### <span id="head14">6.2.1.1 误报</span>

**发生ANR的进程一定会收到SIGQUIT信号；但是收到SIGQUIT信号的进程并不一定发生了ANR。**

可能是下面2种情况：

1. 其他进程的ANR：发生ANR之后，发生ANR的进程并不是唯一需要dump堆栈的进程，系统会收集许多其他的进程进行dump，也就是说当一个应用发生ANR的时候，其他的应用也有可能收到SIGQUIT信号。所以，我们收到SIGQUIT信号，可能是其他进程发生了ANR，这个时候上报的话就属于是误报了。
2. 非ANR发送SIGQUIT：发送SIGQUIT信号非常容易，系统和应用级app都能轻易发送SIGQUIT信号：java层调用android.os.Process.sendSignal方法；Native层调用kill或者tgkill方法。我们收到SIGQUIT信号时，可能并非是ANR流程发送的SIGQUIT信号，也会产生误报。

如何解决上面2个误报的问题？回到ANR流程开始的地方细看

```java
//com.android.server.am.ProcessRecord.java
void appNotResponding(String activityShortComponentName, ApplicationInfo aInfo,
        String parentShortComponentName, WindowProcessController parentProcess,
        boolean aboveSystem, String annotation, boolean onlyDumpSelf) {
    //......
    synchronized (mService) {
        //注意，如果是后台ANR，直接就kill进程然后return了，并不会走到下面的makeAppNotRespondingLocked，当前进程也不会有NOT_RESPONDING这个flag
        if (isSilentAnr() && !isDebugging()) {
            kill("bg anr", ApplicationExitInfo.REASON_ANR, true);
            return;
        }

        // Set the app's notResponding state, and look up the errorReportReceiver
        makeAppNotRespondingLocked(activityShortComponentName,
                annotation != null ? "ANR " + annotation : "ANR", info.toString());

        // show ANR dialog ......
    }
}

private void makeAppNotRespondingLocked(String activity, String shortMsg, String longMsg) {
    setNotResponding(true);
    // mAppErrors can be null if the AMS is constructed with injector only. This will only
    // happen in tests.
    if (mService.mAppErrors != null) {
        notRespondingReport = mService.mAppErrors.generateProcessError(this,
                ActivityManager.ProcessErrorStateInfo.NOT_RESPONDING,
                activity, shortMsg, longMsg, null);
    }
    startAppProblemLocked();
    getWindowProcessController().stopFreezingActivities();
}

void setNotResponding(boolean notResponding) {
    mNotResponding = notResponding;
    mWindowProcessController.setNotResponding(notResponding);
}
```

在ANR弹窗前，会执行makeAppNotRespondingLocked方法，在这里会给发生ANR的进程标记一个`NOT_RESPONDING`的flag，这个flag可以通过ActivityManager来获取：

```java
private static boolean checkErrorState() {
    try {
        Application application = sApplication == null ? Matrix.with().getApplication() : sApplication;
        ActivityManager am = (ActivityManager) application.getSystemService(Context.ACTIVITY_SERVICE);
        List<ActivityManager.ProcessErrorStateInfo> procs = am.getProcessesInErrorState();
        if (procs == null) return false;
        for (ActivityManager.ProcessErrorStateInfo proc : procs) {
            if (proc.pid != android.os.Process.myPid()) continue;
            if (proc.condition != ActivityManager.ProcessErrorStateInfo.NOT_RESPONDING) continue;
            return true;
        }
        return false;
    } catch (Throwable t){
        MatrixLog.e(TAG,"[checkErrorState] error : %s", t.getMessage());
    }
    return false;
}
```

监控到SIGQUIT后，我们在20秒内（20秒是ANR dump的timeout时间）不断轮询自己是否有`NOT_RESPONDING`的flag，一旦发现有这个flag，那么马上就可以认定发生了一次ANR。

> ps: 你可能会想，有这么方便的方法，监控SIGQUIT信号不是多余么？我直接搞个死循环，不断监听该flag，一旦发现不就监控到ANR了么？可以是可以，但不优雅，而且有缺陷（低效、耗电、不环保、无法解决下面提到的漏报问题）。

##### <span id="head15">6.2.1.2 漏报</span>

**进程处于`NOT_RESPONDING`的状态可以确认该进程发生了ANR。但是发生ANR的进程并不一定会被设置为`NOT_RESPONDING`状态**

下面2种是特殊情况：

1. 后台ANR（SilentAnr）：如果ANR被标记为了后台ANR（即SilentAnr），那么杀死进程后就会直接return，不会执行到makeAppNotRespondingLocked，那么该进程就不会有`NOT_RESPONDING`这个flag。这意味着，后台的ANR没办法捕捉到，但后台ANR的量也挺大的，并且后台ANR会直接杀死进程，对用户的体验也是非常负面的，这么大一部分ANR监控不到，当然是无法接受的。
2. 闪退ANR：想当一部分机型（如OPPO、VIVO两家的高Android版本的机型）修改了ANR的流程，即使是发生在前台的ANR，也并不会弹窗，而是直接杀死进程，即闪退。

基于上面2种情况，我们需要一种机制，在收到SIGQUIT信号后，需要非常快速的侦查出自己是否已经处于ANR的状态，进行快速的dump和上报。此时我们可以通过主线程释放处于卡顿状态来判断，怎么快速的知道主线程是否卡住了？可以通过Looper的mMessage对象，该对象的when变量，表示的是当前正在处理的消息入队的时间，我们可以通过when变量减去当前时间，得到的就是等待时间，如果等待时间过长，就说明主线程是处于卡住的状态。这时候收到SIGQUIT信号基本上就可以认为的确发生了一次ANR：

```java
private static boolean isMainThreadStuck(){
    try {
        MessageQueue mainQueue = Looper.getMainLooper().getQueue();
        Field field = mainQueue.getClass().getDeclaredField("mMessages");
        field.setAccessible(true);
        final Message mMessage = (Message) field.get(mainQueue);
        if (mMessage != null) {
            long when = mMessage.getWhen();
            if(when == 0) {
                return false;
            }
            long time = when - SystemClock.uptimeMillis();
            long timeThreshold = BACKGROUND_MSG_THRESHOLD;
            if (foreground) {
                timeThreshold = FOREGROUND_MSG_THRESHOLD;
            }
            return time < timeThreshold;
        }
    } catch (Exception e){
        return false;
    }
    return false;
}
```

通过上面几种机制来综合判断收到SIGQUIT信号后，是否真的发生了一次ANR，最大程度地减少误报和漏报。

##### <span id="head16">6.2.1.3 获取ANR Trace</span>

回到上面的ANR流程示意图，Signal Catcher线程写Trace也是一个边界，它是通过socket的write方法来写trace的。那我们可以直接hook这里的write，就能直接拿到系统dump的ANR Trace内容。这个内容非常全面，包括了所有线程的各种状态、锁和堆栈（包括native堆栈），对于我们排查问题十分有用，尤其是一些native问题和死锁等问题。native hook采用PLT Hook方案，稳得很，这种方案已经在微信上验证了其稳定性。

```c++
int (*original_connect)(int __fd, const struct sockaddr* __addr, socklen_t __addr_length);
int my_connect(int __fd, const struct sockaddr* __addr, socklen_t __addr_length) {
    if (strcmp(__addr->sa_data, "/dev/socket/tombstoned_java_trace") == 0) {
        isTraceWrite = true;
        signalCatcherTid = gettid();
    }
    return original_connect(__fd, __addr, __addr_length);
}

int (*original_open)(const char *pathname, int flags, mode_t mode);
int my_open(const char *pathname, int flags, mode_t mode) {
    if (strcmp(pathname, "/data/anr/traces.txt") == 0) {
        isTraceWrite = true;
        signalCatcherTid = gettid();
    }
    return original_open(pathname, flags, mode);
}

ssize_t (*original_write)(int fd, const void* const __pass_object_size0 buf, size_t count);
ssize_t my_write(int fd, const void* const buf, size_t count) {
    if(isTraceWrite && signalCatcherTid == gettid()) {
        isTraceWrite = false;
        signalCatcherTid = 0;
        char *content = (char *) buf;
        printAnrTrace(content);
    }
    return original_write(fd, buf, count);
}

void hookAnrTraceWrite() {
    int apiLevel = getApiLevel();
    if (apiLevel < 19) {
        return;
    }
    if (apiLevel >= 27) {
        plt_hook("libcutils.so", "connect", (void *) my_connect, (void **) (&original_connect));
    } else {
        plt_hook("libart.so", "open", (void *) my_open, (void **) (&original_open));
    }

    if (apiLevel >= 30 || apiLevel == 25 || apiLevel ==24) {
        plt_hook("libc.so", "write", (void *) my_write, (void **) (&original_write));
    } else if (apiLevel == 29) {
        plt_hook("libbase.so", "write", (void *) my_write, (void **) (&original_write));
    } else {
        plt_hook("libart.so", "write", (void *) my_write, (void **) (&original_write));
    }
}
```

有几点需要注意：

1. 只Hook ANR流程：有些情况下，基础库中的connect/open/write方法可能调用的比较频繁，我们需要把hook的影响降到最低。所以我们只会在接收到SIGQUIT信号后（重新发送SIGQUIT信号给Signal Catcher前）进行hook，ANR流程结束后再unhook。
2. 只处理Signal Catcher线程open/connect后的第一次write：除了Signal Catcher线程中的dump trace的流程，其他地方调用的write方法我们并不关心，并不需要处理。
3. Hook点因API Level而不同：需要hook的write方法在不同的Android版本中，所在so库也不同，需分别处理。

到此，matrix监控SIGQUIT信号从而监控ANR的方案的核心逻辑已全部呈现，更多详细源码请[移步matrix仓库](https://github.com/Tencent/matrix/tree/master/matrix/matrix-android/matrix-trace-canary/src/main)。

**总结一下，该方案通过去监听SIGQUIT信号，从而感知当前进程可能发生了ANR，需配合当前进程是否处于`NOT_RESPONDING`状态以及主线程是否卡顿来进行甄别，以免误判。注册监听SIGQUIT信号之后，系统原来的Signal Catcher线程就监听不到这个信号了，需要把该信号转发出去，让它接收到，以免影响。当前进程的Signal Catcher线程要dump堆栈的时候，会通过socket的write向system server进程进行传输dump好的数据，我们可以hook这个write，从而拿到系统dump好的ANR Trace内容，相当于我们并没有影响系统的任何流程，还拿到了想要拿到的东西。这个方案完全是在系统的正常dump anr trace的过程中获取信息，所以能拿到的东西更加全面，但是系统的dump过程其实是对性能影响比较大的，时间也比较久。**

## <span id="head17">7. ANR分析</span>

监控固然重要，更重要的是分析是什么原因导致的ANR，然后修复好。

### <span id="head18">7.1 trace文件分析</span>

拿到trace文件，详细分析下：

```log
----- pid 7761 at 2022-11-02 07:02:26 -----
Cmd line: com.xfhy.watchsignaldemo
Build fingerprint: 'HUAWEI/LYA-AL00/HWLYA:10/HUAWEILYA-AL00/10.1.0.163C00:user/release-keys'
ABI: 'arm64'
Build type: optimized
Zygote loaded classes=11918 post zygote classes=729
Dumping registered class loaders
#0 dalvik.system.PathClassLoader: [], parent #1
#1 java.lang.BootClassLoader: [], no parent
#2 dalvik.system.PathClassLoader: [/system/app/FeatureFramework/FeatureFramework.apk], no parent
#3 dalvik.system.PathClassLoader: [/data/app/com.xfhy.watchsignaldemo-4tkKMWojrpHAf-Q3iecaHQ==/base.apk:/data/app/com.xfhy.watchsignaldemo-4tkKMWojrpHAf-Q3iecaHQ==/base.apk!classes2.dex:/data/app/com.xfhy.watchsignaldemo-4tkKMWojrpHAf-Q3iecaHQ==/base.apk!classes4.dex:/data/app/com.xfhy.watchsignaldemo-4tkKMWojrpHAf-Q3iecaHQ==/base.apk!classes3.dex], parent #1
Done dumping class loaders
Intern table: 44132 strong; 436 weak
JNI: CheckJNI is off; globals=681 (plus 67 weak)
Libraries: /data/app/com.xfhy.watchsignaldemo-4tkKMWojrpHAf-Q3iecaHQ==/lib/arm64/libwatchsignaldemo.so libandroid.so libcompiler_rt.so libhitrace_jni.so libhiview_jni.so libhwapsimpl_jni.so libiAwareSdk_jni.so libimonitor_jni.so libjavacore.so libjavacrypto.so libjnigraphics.so libmedia_jni.so libopenjdk.so libsoundpool.so libwebviewchromium_loader.so (15)
//已分配堆内存大小26M,其中2442kb医用，总分配74512个对象
Heap: 90% free, 2442KB/26MB; 74512 objects

Total number of allocations 120222 //进程创建到现在一共创建了多少对象
Total bytes allocated 10MB         //进程创建到现在一共申请了多少内存
Total bytes freed 8173KB           //进程创建到现在一共释放了多少内存
Free memory 23MB                   //不扩展堆的情况下可用的内存
Free memory until GC 23MB          //GC前的可用内存
Free memory until OOME 381MB       //OOM之前的可用内存,这个值很小的话，说明已经处于内存紧张状态，app可能是占用了过多的内存
Total memory 26MB                  //当前总内存（已用+可用）
Max memory 384MB                   //进程最多能申请的内存

.....//省略GC相关信息


//当前进程共17个线程
DALVIK THREADS (17):

//Signal Catcher线程调用栈
"Signal Catcher" daemon prio=5 tid=4 Runnable
  | group="system" sCount=0 dsCount=0 flags=0 obj=0x18c84570 self=0x7252417800
  | sysTid=7772 nice=0 cgrp=default sched=0/0 handle=0x725354ad50
  | state=R schedstat=( 16273959 1085938 5 ) utm=0 stm=1 core=4 HZ=100
  | stack=0x7253454000-0x7253456000 stackSize=991KB
  | held mutexes= "mutator lock"(shared held)
  native: #00 pc 000000000042f8e8  /apex/com.android.runtime/lib64/libart.so (art::DumpNativeStack(std::__1::basic_ostream<char, std::__1::char_traits<char>>&, int, BacktraceMap*, char const*, art::ArtMethod*, void*, bool)+140)
  native: #01 pc 0000000000523590  /apex/com.android.runtime/lib64/libart.so (art::Thread::DumpStack(std::__1::basic_ostream<char, std::__1::char_traits<char>>&, bool, BacktraceMap*, bool) const+508)
  native: #02 pc 000000000053e75c  /apex/com.android.runtime/lib64/libart.so (art::DumpCheckpoint::Run(art::Thread*)+844)
  native: #03 pc 000000000053735c  /apex/com.android.runtime/lib64/libart.so (art::ThreadList::RunCheckpoint(art::Closure*, art::Closure*)+504)
  native: #04 pc 0000000000536744  /apex/com.android.runtime/lib64/libart.so (art::ThreadList::Dump(std::__1::basic_ostream<char, std::__1::char_traits<char>>&, bool)+1048)
  native: #05 pc 0000000000536228  /apex/com.android.runtime/lib64/libart.so (art::ThreadList::DumpForSigQuit(std::__1::basic_ostream<char, std::__1::char_traits<char>>&)+884)
  native: #06 pc 00000000004ee4d8  /apex/com.android.runtime/lib64/libart.so (art::Runtime::DumpForSigQuit(std::__1::basic_ostream<char, std::__1::char_traits<char>>&)+196)
  native: #07 pc 000000000050250c  /apex/com.android.runtime/lib64/libart.so (art::SignalCatcher::HandleSigQuit()+1356)
  native: #08 pc 0000000000501558  /apex/com.android.runtime/lib64/libart.so (art::SignalCatcher::Run(void*)+268)
  native: #09 pc 00000000000cf7c0  /apex/com.android.runtime/lib64/bionic/libc.so (__pthread_start(void*)+36)
  native: #10 pc 00000000000721a8  /apex/com.android.runtime/lib64/bionic/libc.so (__start_thread+64)
  (no managed stack frames)

"main" prio=5 tid=1 Sleeping
  | group="main" sCount=1 dsCount=0 flags=1 obj=0x73907540 self=0x725f010800
  | sysTid=7761 nice=-10 cgrp=default sched=1073741825/2 handle=0x72e60080d0
  | state=S schedstat=( 281909898 5919799 311 ) utm=20 stm=7 core=4 HZ=100
  | stack=0x7fca180000-0x7fca182000 stackSize=8192KB
  | held mutexes=
  at java.lang.Thread.sleep(Native method)
  - sleeping on <0x00f895d9> (a java.lang.Object)
  at java.lang.Thread.sleep(Thread.java:443)
  - locked <0x00f895d9> (a java.lang.Object)
  at java.lang.Thread.sleep(Thread.java:359)
  at android.os.SystemClock.sleep(SystemClock.java:131)
  at com.xfhy.watchsignaldemo.MainActivity.makeAnr(MainActivity.kt:35)
  at java.lang.reflect.Method.invoke(Native method)
  at androidx.appcompat.app.AppCompatViewInflater$DeclaredOnClickListener.onClick(AppCompatViewInflater.java:441)
  at android.view.View.performClick(View.java:7317)
  at com.google.android.material.button.MaterialButton.performClick(MaterialButton.java:1219)
  at android.view.View.performClickInternal(View.java:7291)
  at android.view.View.access$3600(View.java:838)
  at android.view.View$PerformClick.run(View.java:28247)
  at android.os.Handler.handleCallback(Handler.java:900)
  at android.os.Handler.dispatchMessage(Handler.java:103)
  at android.os.Looper.loop(Looper.java:219)
  at android.app.ActivityThread.main(ActivityThread.java:8668)
  at java.lang.reflect.Method.invoke(Native method)
  at com.android.internal.os.RuntimeInit$MethodAndArgsCaller.run(RuntimeInit.java:513)
  at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:1109)

  ... //此处省略剩余的N个线程
```

trace参数详细解读：

```log
"Signal Catcher" daemon prio=5 tid=4 Runnable
  | group="system" sCount=0 dsCount=0 flags=0 obj=0x18c84570 self=0x7252417800
  | sysTid=7772 nice=0 cgrp=default sched=0/0 handle=0x725354ad50
  | state=R schedstat=( 16273959 1085938 5 ) utm=0 stm=1 core=4 HZ=100
  | stack=0x7253454000-0x7253456000 stackSize=991KB
  | held mutexes= "mutator lock"(shared held)
```

**第1行：**

`"Signal Catcher" daemon prio=5 tid=4 Runnable`

- "Signal Catcher" daemon ： 线程名，有daemon表示守护线程
- prio：线程优先级
- tid：线程内部id
- 线程状态：Runnable

![ANR线程状态对照表](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/IPe7kX.jpg)

> ps: 一般来说：main线程处于BLOCK、WAITING、TIMEWAITING状态，基本上是函数阻塞导致的ANR，如果main线程无异常，则应该排查CPU负载和内存环境。

**第2行：**

`| group="system" sCount=0 dsCount=0 flags=0 obj=0x18c84570 self=0x7252417800`

- group：线程所属的线程组
- sCount：线程挂起次数
- dsCount：用于调试的线程挂起次数
- obj：当前线程关联的Java线程对象
- self：当前线程地址

**第3行：**

`| sysTid=7772 nice=0 cgrp=default sched=0/0 handle=0x725354ad50`

- sysTid：线程真正意义上的tid
- nice：调度优先级，值越小则优先级越高
- cgrp：进程所属的进程调度组
- sched：调度策略
- handle：函数处理地址

**第4行：**

`| state=R schedstat=( 16273959 1085938 5 ) utm=0 stm=1 core=4 HZ=100`

- state：线程状态
- schedstat：CPU调度时间统计（schedstat括号中的3个数字依次是Running、Runable、Switch，Running时间：CPU运行的时间，单位ns，Runable时间：RQ队列的等待时间，单位ns，Switch次数：CPU调度切换次数）
- utm/stm：用户态/内核态的CPU时间
- core：该线程的最后运行所在核
- HZ：时钟频率

**第5行：**

`| stack=0x7253454000-0x7253456000 stackSize=991KB`

- stack：线程栈的地址区间
- stackSize：栈的大小

**第6行：**

`| held mutexes= "mutator lock"(shared held)`

- mutex：所持有mutex类型，有独占锁exclusive和共享锁shared两类

### <span id="head19">7.2 ANR案例分析</span>

#### <span id="head20">7.2.1 主线程无卡顿，处于正常状态堆栈</span>

```log
"main" prio=5 tid=1 Native
  | group="main" sCount=1 dsCount=0 flags=1 obj=0x74b38080 self=0x7ad9014c00
  | sysTid=23081 nice=0 cgrp=default sched=0/0 handle=0x7b5fdc5548
  | state=S schedstat=( 284838633 166738594 505 ) utm=21 stm=7 core=1 HZ=100
  | stack=0x7fc95da000-0x7fc95dc000 stackSize=8MB
  | held mutexes=
  kernel: __switch_to+0xb0/0xbc
  kernel: SyS_epoll_wait+0x288/0x364
  kernel: SyS_epoll_pwait+0xb0/0x124
  kernel: cpu_switch_to+0x38c/0x2258
  native: #00 pc 000000000007cd8c  /system/lib64/libc.so (__epoll_pwait+8)
  native: #01 pc 0000000000014d48  /system/lib64/libutils.so (android::Looper::pollInner(int)+148)
  native: #02 pc 0000000000014c18  /system/lib64/libutils.so (android::Looper::pollOnce(int, int*, int*, void**)+60)
  native: #03 pc 00000000001275f4  /system/lib64/libandroid_runtime.so (android::android_os_MessageQueue_nativePollOnce(_JNIEnv*, _jobject*, long, int)+44)
  at android.os.MessageQueue.nativePollOnce(Native method)
  at android.os.MessageQueue.next(MessageQueue.java:330)
  at android.os.Looper.loop(Looper.java:169)
  at android.app.ActivityThread.main(ActivityThread.java:7073)
  at java.lang.reflect.Method.invoke(Native method)
  at com.android.internal.os.RuntimeInit$MethodAndArgsCaller.run(RuntimeInit.java:536)
  at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:876)
```

比如这个主线程堆栈，看起来很正常，主线程是空闲的，因为它正处于nativePollOnce，正在等待新消息。处于这个状态，那还发生了ANR，可能有2个原因：

1. dump堆栈时机太晚了，ANR已经发生过了，才去dump堆栈，此时主线程已经恢复正常了
2. CPU抢占或者内存紧张等其他因素引起

遇到这种情况，要先去分析CPU、内存的使用情况。其次可以关注抓取日志的时间和ANR发生的时间是否相隔太久，时间太久这个堆栈就没有分析的意义了。

#### <span id="head21">7.2.2 主线程执行耗时操作</span>

```kotlin
//模拟主线程耗时操作,View点击的时候调用这个函数
fun makeAnr(view: View) {
    var s = 0L
    for (i in 0..99999999999) {
        s += i
    }
    Log.d("xxx", "s=$s")
}
```

当主线程执行到makeAnr时，会因为里面的东西执行太耗时而一直在这里进行计算，假设此时有其他事情要想交给主线程处理，则必须得等到makeAnr函数执行完才行。主线程在执行makeAnr时，输入事件无法被处理，用户多次点击屏幕之后，就会输入超时，触发InputEvent Timeout，导致ANR。而如果主线程在执行上面这段耗时操作的过程中，没有其他事情需要处理，那其实是不会发生ANR的。

```log
suspend all histogram:	Sum: 206us 99% C.I. 0.098us-46us Avg: 7.629us Max: 46us
DALVIK THREADS (16):
"main" prio=5 tid=1 Runnable
  | group="main" sCount=0 dsCount=0 flags=0 obj=0x73907540 self=0x725f010800
  | sysTid=32298 nice=-10 cgrp=default sched=1073741825/2 handle=0x72e60080d0
  | state=R schedstat=( 6746757297 5887495 256 ) utm=670 stm=4 core=6 HZ=100
  | stack=0x7fca180000-0x7fca182000 stackSize=8192KB
  | held mutexes= "mutator lock"(shared held)
  at com.xfhy.watchsignaldemo.MainActivity.makeAnr(MainActivity.kt:58)
  at java.lang.reflect.Method.invoke(Native method)
  at androidx.appcompat.app.AppCompatViewInflater$DeclaredOnClickListener.onClick(AppCompatViewInflater.java:441)
  at android.view.View.performClick(View.java:7317)
  at com.google.android.material.button.MaterialButton.performClick(MaterialButton.java:1219)
  at android.view.View.performClickInternal(View.java:7291)
  at android.view.View.access$3600(View.java:838)
  at android.view.View$PerformClick.run(View.java:28247)
  at android.os.Handler.handleCallback(Handler.java:900)
  at android.os.Handler.dispatchMessage(Handler.java:103)
  at android.os.Looper.loop(Looper.java:219)
  at android.app.ActivityThread.main(ActivityThread.java:8668)
  at java.lang.reflect.Method.invoke(Native method)
  at com.android.internal.os.RuntimeInit$MethodAndArgsCaller.run(RuntimeInit.java:513)
  at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:1109)
```

从日志上看，主线程处于执行状态，不是空闲状态，导致ANR了，说明`com.xfhy.watchsignaldemo.MainActivity.makeAnr`这里有耗时操作。

#### <span id="head22">7.2.3 主线程被锁阻塞</span>

模拟主线程等待子线程的锁：

```kotlin
fun makeAnr(view: View) {

    val obj1 = Any()
    val obj2 = Any()

    //搞个死锁，相互等待

    thread(name = "卧槽") {
        synchronized(obj1) {
            SystemClock.sleep(100)
            synchronized(obj2) {
            }
        }
    }

    synchronized(obj2) {
        SystemClock.sleep(100)
        synchronized(obj1) {
        }
    }
}
```

```log
"main" prio=5 tid=1 Blocked
  | group="main" sCount=1 dsCount=0 flags=1 obj=0x73907540 self=0x725f010800
  | sysTid=19900 nice=-10 cgrp=default sched=0/0 handle=0x72e60080d0
  | state=S schedstat=( 542745832 9516666 182 ) utm=48 stm=5 core=4 HZ=100
  | stack=0x7fca180000-0x7fca182000 stackSize=8192KB
  | held mutexes=
  at com.xfhy.watchsignaldemo.MainActivity.makeAnr(MainActivity.kt:59)
  - waiting to lock <0x0c6f8c52> (a java.lang.Object) held by thread 22   //注释1
  - locked <0x01abeb23> (a java.lang.Object)
  at java.lang.reflect.Method.invoke(Native method)
  at androidx.appcompat.app.AppCompatViewInflater$DeclaredOnClickListener.onClick(AppCompatViewInflater.java:441)
  at android.view.View.performClick(View.java:7317)
  at com.google.android.material.button.MaterialButton.performClick(MaterialButton.java:1219)
  at android.view.View.performClickInternal(View.java:7291)
  at android.view.View.access$3600(View.java:838)
  at android.view.View$PerformClick.run(View.java:28247)
  at android.os.Handler.handleCallback(Handler.java:900)
  at android.os.Handler.dispatchMessage(Handler.java:103)
  at android.os.Looper.loop(Looper.java:219)
  at android.app.ActivityThread.main(ActivityThread.java:8668)
  at java.lang.reflect.Method.invoke(Native method)
  at com.android.internal.os.RuntimeInit$MethodAndArgsCaller.run(RuntimeInit.java:513)
  at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:1109)

"卧槽" prio=5 tid=22 Blocked  //注释2
  | group="main" sCount=1 dsCount=0 flags=1 obj=0x12c8a118 self=0x71d625f800
  | sysTid=20611 nice=0 cgrp=default sched=0/0 handle=0x71d4513d50
  | state=S schedstat=( 486459 0 3 ) utm=0 stm=0 core=4 HZ=100
  | stack=0x71d4411000-0x71d4413000 stackSize=1039KB
  | held mutexes=
  at com.xfhy.watchsignaldemo.MainActivity$makeAnr$1.invoke(MainActivity.kt:52)
  - waiting to lock <0x01abeb23> (a java.lang.Object) held by thread 1
  - locked <0x0c6f8c52> (a java.lang.Object)  
  at com.xfhy.watchsignaldemo.MainActivity$makeAnr$1.invoke(MainActivity.kt:49)
  at kotlin.concurrent.ThreadsKt$thread$thread$1.run(Thread.kt:30)

......
```

注意看，下面几行：

```log
"main" prio=5 tid=1 Blocked
  - waiting to lock <0x0c6f8c52> (a java.lang.Object) held by thread 22
  - locked <0x01abeb23> (a java.lang.Object)

"卧槽" prio=5 tid=22 Blocked
  - waiting to lock <0x01abeb23> (a java.lang.Object) held by thread 1
  - locked <0x0c6f8c52> (a java.lang.Object)  
```

主线程的tid是1，线程状态是Blocked，正在等待`0x0c6f8c52`这个Object，而这个Object被thread 22这个线程所持有，主线程当前持有的是`0x01abeb23`的锁。而`卧槽`的tid是22，也是Blocked状态，它想请求的和已有的锁刚好与主线程相反。这样的话，ANR原因也就找到了：线程22持有了一把锁，并且一直不释放，主线程等待这把锁发生超时。在线上环境，常见因锁而ANR的场景是SharePreference写入。

#### <span id="head23">7.2.4 CPU被抢占</span>

```log
CPU usage from 0ms to 10625ms later (2020-03-09 14:38:31.633 to 2020-03-09 14:38:42.257):
  543% 2045/com.test.demo: 54% user + 89% kernel / faults: 4608 minor 1 major //注意看这里
  99% 674/android.hardware.camera.provider@2.4-service: 81% user + 18% kernel / faults: 403 minor
  24% 32589/com.wang.test: 22% user + 1.4% kernel / faults: 7432 minor 1 major
  ......
```

可以看到，该进程占据CPU高达543%，抢占了大部分CPU资源，因为导致发生ANR，这种ANR与我们的app无关。

#### <span id="head24">7.2.5 内存紧张导致ANR</span>

如果一份ANR日志的CPU和堆栈都很正常，可以考虑是内存紧张。看一下ANR日志里面的内存相关部分。还可以去日志里面搜一下onTrimMemory，如果dump ANR日志的时间附近有相关日志，可能是内存比较紧张了。

```log
10-31 22:37:19.749 20733 20733 E Runtime : onTrimMemory level:80,pid:com.xxx.xxx:Launcher0
10-31 22:37:33.458 20733 20733 E Runtime : onTrimMemory level:80,pid:com.xxx.xxx:Launcher0
10-31 22:38:00.153 20733 20733 E Runtime : onTrimMemory level:80,pid:com.xxx.xxx:Launcher0
10-31 22:38:58.731 20733 20733 E Runtime : onTrimMemory level:80,pid:com.xxx.xxx:Launcher0
10-31 22:39:02.816 20733 20733 E Runtime : onTrimMemory level:80,pid:com.xxx.xxx:Launcher0
```

#### <span id="head25">7.2.6 系统服务超时导致ANR</span>

系统服务超时一般会包含BinderProxy.transactNative关键字，来看一段日志：

```log
"main" prio=5 tid=1 Native
  | group="main" sCount=1 dsCount=0 flags=1 obj=0x727851e8 self=0x78d7060e00
  | sysTid=4894 nice=0 cgrp=default sched=0/0 handle=0x795cc1e9a8
  | state=S schedstat=( 8292806752 1621087524 7167 ) utm=707 stm=122 core=5 HZ=100
  | stack=0x7febb64000-0x7febb66000 stackSize=8MB
  | held mutexes=
  kernel: __switch_to+0x90/0xc4
  kernel: binder_thread_read+0xbd8/0x144c
  kernel: binder_ioctl_write_read.constprop.58+0x20c/0x348
  kernel: binder_ioctl+0x5d4/0x88c
  kernel: do_vfs_ioctl+0xb8/0xb1c
  kernel: SyS_ioctl+0x84/0x98
  kernel: cpu_switch_to+0x34c/0x22c0
  native: #00 pc 000000000007a2ac  /system/lib64/libc.so (__ioctl+4)
  native: #01 pc 00000000000276ec  /system/lib64/libc.so (ioctl+132)
  native: #02 pc 00000000000557d4  /system/lib64/libbinder.so (android::IPCThreadState::talkWithDriver(bool)+252)
  native: #03 pc 0000000000056494  /system/lib64/libbinder.so (android::IPCThreadState::waitForResponse(android::Parcel*, int*)+60)
  native: #04 pc 00000000000562d0  /system/lib64/libbinder.so (android::IPCThreadState::transact(int, unsigned int, android::Parcel const&, android::Parcel*, unsigned int)+216)
  native: #05 pc 000000000004ce1c  /system/lib64/libbinder.so (android::BpBinder::transact(unsigned int, android::Parcel const&, android::Parcel*, unsigned int)+72)
  native: #06 pc 00000000001281c8  /system/lib64/libandroid_runtime.so (???)
  native: #07 pc 0000000000947ed4  /system/framework/arm64/boot-framework.oat (Java_android_os_BinderProxy_transactNative__ILandroid_os_Parcel_2Landroid_os_Parcel_2I+196)
  at android.os.BinderProxy.transactNative(Native method) ————————————————关键行！！！
  at android.os.BinderProxy.transact(Binder.java:804)
  at android.net.IConnectivityManager$Stub$Proxy.getActiveNetworkInfo(IConnectivityManager.java:1204)—关键行！
  at android.net.ConnectivityManager.getActiveNetworkInfo(ConnectivityManager.java:800)
  at com.xiaomi.NetworkUtils.getNetworkInfo(NetworkUtils.java:2)
  at com.xiaomi.frameworkbase.utils.NetworkUtils.getNetWorkType(NetworkUtils.java:1)
  at com.xiaomi.frameworkbase.utils.NetworkUtils.isWifiConnected(NetworkUtils.java:1)
```

从日志堆栈中可以看到是获取网络信息发生了ANR：getActiveNetworkInfo。系统的服务都是Binder机制（16个线程），服务能力也是有限的，有可能系统服务长时间不响应导致ANR。如果其他应用占用了所有Binder线程，那么当前应用只能等待。可进一步搜索：blockUntilThreadAvailable关键字：

`at android.os.Binder.blockUntilThreadAvailable(Native method)`

如果有发现某个线程的堆栈，包含此字样，可进一步看其堆栈，确定是调用了什么系统服务。此类ANR也是属于系统环境的问题，如果某类型手机上频繁发生此问题，应用层可以考虑规避策略。

## <span id="head26">8. ANR影响因素</span>

即使我们利用上面的一系列骚操作，在发生ANR时，我们拿到了Trace堆栈。但实际情况下这些Trace堆栈中，有很多不是导致ANR的根本原因。Trace堆栈提示某个Service或Receiver导致的ANR，但其实很可能并不是这些组件自身的问题导致的ANR，至于为什么，下面一一道来。

**影响ANR的本质要素大体来说分为2个：应用内部环境和系统环境。当系统负载正常，但是应用内部主线程消息过多或耗时验证；另外一类是系统或应用内部其他线程或资源负载过高，主线程调度被严重抢占。**

系统负载高咱们没有办法，但系统负载正常时，主线程的调度问题主要有下面几个：

1. 当前Trace堆栈所在业务耗时严重
2. 当前Trace堆栈所在业务耗时并不严重，但历史调度有一个严重耗时
3. 当前Trace堆栈所在业务耗时并不严重，但历史调度有多个消息耗时
4. 当前Trace堆栈所在业务耗时并不严重，但是历史调度存在巨量重复消息（业务频繁发送消息）
5. 当前Trace堆栈业务逻辑并不耗时，但是其他线程存在严重资源抢占，如IO、Mem、CPU；
6. 当前Trace堆栈业务逻辑并不耗时，但是其他进程存在严重资源抢占，如IO、Mem、CPU。

请注意，这里的6个影响因素中，除了第一个以外，其他的根据ANR Trace有可能无法进行判别。这就会导致很多时候看到的ANR Trace里面主线程堆栈对应的业务其实并不耗时（因为可能是前面的消息导致的耗时，但它已经执行完了），如何解决这个问题？

## <span id="head27">9. 弥补不足</span>

字节跳动内部有一个监控工具：Raster，这个库专门解决上面的问题。有一点可惜的是该工具暂时还没开源，但是我们从字节发出来的Raster原理相关的文章能了解到该库的详细原理。[原文 : 今日头条 ANR 优化实践系列 - 监控工具与分析思路](https://mp.weixin.qq.com/s/_Z6GdGRVWq-_JXf5Fs6fsw)

Raster的大致原理：该工具主要是在主线程消息调度过程进行监控，并按照一定的策略聚合，以保证监控工具本身对应用性能和内存抖动影响降至最低。比较耗时的消息会抓取主线从堆栈，这样可以知道那个耗时的消息具体是在干什么，从而针对性优化。同时对应用四大组件消息执行过程进行监控，便于对这类消息的调度及耗时情况进行跟踪和记录。另外对当前正在调度的消息及消息队列中待调度消息进行统计，从而在发生问题时，可以回放主线程的整体调度情况。此外，该库将系统服务的CheckTime机制迁移到应用侧，应用为线程CheckTime机制，以便于系统信息不足时，从线程调度及时性推测过去一段时间系统负载和调度情况。因此该工具用一句话来概括就是：由点到面，回放过去，现在和将来。 

细说一下线程 Checktime：通过借助其他子线程的周期检测机制，在每次调度前获取当前系统时间，然后减去我们设置延迟的时间，即可得到本次线程调度前的真实间隔时间，如设置线程每隔300ms调度一次，结果发现实际响应时间间隔有时会超过300ms，如果偏差越大则说明线程没有及时调度，进一步反映系统响应能力变差。通过这样的方式，即使线上环境获取不到系统日志，也可以从侧面反映不同时段系统负载对线程调度影响。当连续发生多次严重Delay时，说明线程调度受到了影响。

通过上诉监控能力，我们就可以清晰的知道ANR发生时主线程历史消息调度以及耗时严重消息的采样堆栈，同时可以知道正在执行消息的耗时，以及消息队列中调度消息的状态。同时通过线程CheckTime机制从侧面反映线程调度响应能力，由此完成了应用侧监控信息从点到面的覆盖。

> 有大佬根据该文章的原理实现了一个类似的开源库： MoonlightTreasureBox，[MoonlightTreasureBox 开源地址](https://github.com/xiaolutang/MoonlightTreasureBox)。

## <span id="head28">10. QA</span>

### <span id="head29">10.1 在Activity#onCreate中sleep会导致ANR吗？</span>

不会，ANR的场景只有下面4种：Service Timeout、BroadcastQueue Timeout、ContentProvider Timeout、InputDispatching Timeout。

> 当然，如果在Activity#onCreate中sleep的过程中，用户点击了屏幕，那是有可能触发InputDispatching Timeout的。

## <span id="head30">11. 小结</span>

很荣幸地恭喜你，读完了整篇文章。

ANR是老生常谈的问题了，本文从定义、原因、发生场景、触发流程、监控与分析等多方面入手，尽力补全ANR这块的知识。

ANR的发生场景只有4种：Service Timeout、BroadcastQueue Timeout、ContentProvider Timeout、InputDispatching Timeout，但导致ANR的原因是多种多样的，可能是App这边导致的，也可能是系统那边导致的。触发ANR的过程大致又可以分为2种，一种是Service、Broadcast、Provider触发ANR：埋炸弹、拆炸弹、引爆炸弹，另外一种是Input触发ANR：处理后续时检测之前的。触发ANR之后，会走dump ANR Trace的流程，收集相关进程的堆栈信息写入文件。我们可以监听SIGQUIT信号，感知到系统在走dump ANR Trace的流程，我们可以进一步确认一下当前进程是否处于ANR的状态，然后通过hook系统与App的边界，从而通过socket拿到系统dump好的ANR Trace内容。拿到ANR Trace内容之后，当然就是分析了，详细请看文章。但是有时候，拿到的ANR Trace并不能把真正的ANR原因给分析出来，这时就得上字节内部的大杀器了：Raster，虽然暂时还没开源，但字节已将其原理一五一十的分享出来了。Raster主要是能知道主线程的消息调度在过去、现在、将来的具体情况，配合线程 CheckTime 感知线程调度能力，要比单单分析 ANR Trace要方便很多。


感谢以下所有大佬的精彩文章。

- 卡顿、ANR、死锁，线上如何监控？ https://juejin.cn/post/6973564044351373326#heading-34
- 你管这破玩意叫 IO 多路复用？https://mp.weixin.qq.com/s?__biz=Mzk0MjE3NDE0Ng==&mid=2247494866&idx=1&sn=0ebeb60dbc1fd7f9473943df7ce5fd95&chksm=c2c5967ff5b21f69030636334f6a5a7dc52c0f4de9b668f7bac15b2c1a2660ae533dd9878c7c&mpshare=1&scene=1&srcid=04239yXVUr6ekmLg7ZSKlFpa&sharer_sharetime=1619147468052&sharer_shareid=2498540345d210ebc4198a40ae94e9ec#rd
- epoll或者kqueue的原理是什么? https://www.zhihu.com/question/20122137/answer/14049112
- Gityuan 理解Android ANR的信息收集过程 http://gityuan.com/2016/12/02/app-not-response/
- Gityuan 理解Android ANR的触发原理 http://gityuan.com/2016/07/02/android-anr
- Gityuan Input系统—ANR原理分析 http://gityuan.com/2017/01/01/input-anr/
- Gityuan 彻底理解安卓应用无响应机制 http://gityuan.com/2019/04/06/android-anr/
- Gityuan Input系统—事件处理全过程 http://gityuan.com/2016/12/31/input-ipc/
- 微信Android客户端的卡顿监控方案 https://mp.weixin.qq.com/s/3dubi2GVW_rVFZZztCpsKg
- Touch事件如何传递到Activity https://www.jianshu.com/p/7d442ed0a355
- 浅析 Android 输入事件处理（一） https://zhuanlan.zhihu.com/p/26893970
- 【Android】事件处理系统 https://www.cnblogs.com/lcw/p/3373214.html
- Android 输入系统 & ANR机制的设计与实现 https://mp.weixin.qq.com/s/OyyP_BQqz0gLOfmZffoD1A
- Android PLT hook 概述 https://github.com/iqiyi/xHook/blob/master/docs/overview/android_plt_hook_overview.zh-CN.md
- Android 输入系统 & ANR机制的设计与实现 https://mp.weixin.qq.com/s/OyyP_BQqz0gLOfmZffoD1A
- 今日头条 ANR 优化实践系列 - 设计原理及影响因素 https://mp.weixin.qq.com/s/ApNSEWxQdM19QoCNijagtg
- 今日头条 ANR 优化实践系列 - 监控工具与分析思路 https://mp.weixin.qq.com/s/_Z6GdGRVWq-_JXf5Fs6fsw
- Matrix - ANR 原理解析 https://www.dalvik.work/2021/12/03/matrix-anr/
- 西瓜视频稳定性治理体系建设三：Sliver 原理及实践https://mp.weixin.qq.com/s/LW3eMK9O2tfFtZcu5eqitg （这篇文章提到，looper消息分发和监控Signal信号有可能无法监控到真正的ANR，可能dump堆栈时已经错过真正的时机，需要获取到dump堆栈时的前面的消息堆栈，好像matrix有，到时看一下）
- 西瓜卡顿 & ANR 优化治理及监控体系建设 https://mp.weixin.qq.com/s/2sjG5qkrUNQsI0jEsnh4kQ
- 微信Android客户端的ANR监控方案 监控signal信号 https://blog.csdn.net/stone_cold_cool/article/details/119464855
- 今日头条 ANR 优化实践系列分享 - 实例剖析集锦 https://mp.weixin.qq.com/s/4-_SnG4dfjMnkrb3rhgUag
- 今日头条 ANR 优化实践系列 - Barrier 导致主线程假死 https://mp.weixin.qq.com/s/OBYWrUBkWwV8o6ChSVaCvw
- 今日头条 ANR 优化实践系列 - 告别 SharedPreference 等待 https://mp.weixin.qq.com/s/kfF83UmsGM5w43rDCH544g
- [理解杀进程的实现原理 - Gityuan博客 | 袁辉辉的技术博客](http://gityuan.com/2016/04/16/kill-signal/)
- [理解Android进程创建流程 - Gityuan博客 | 袁辉辉的技术博客](http://gityuan.com/2016/03/26/app-process-create/)
- [「ANR」Android SIGQUIT(3) 信号拦截与处理_阿里巴巴终端技术的博客-CSDN博客](https://blog.csdn.net/qq_32198115/article/details/120720820)
- 干货：ANR日志分析全面解析  https://zhuanlan.zhihu.com/p/378902923
- Android ANR https://www.jianshu.com/p/487771a67d1b