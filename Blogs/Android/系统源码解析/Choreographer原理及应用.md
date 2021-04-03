
Choreographer对于一些同学来说可能比较陌生，但是，它其实出场率是极高的。View的三大流程就是靠着Choreographer来实现的，翻译过来这个单词的意思是“编舞者”。下面我们来详细介绍，它的具体作用是什么。

> [demo地址](https://github.com/xfhy/AllInOne)

### 1. 前置知识

在讲Choreographer之前，必须得提一些前置知识来辅助学习。

#### 刷新率

刷新率代表屏幕在一秒内刷新屏幕的次数，这个值用赫兹来表示，取决于硬件的固定参数。这个值一般是60Hz，即每16.66ms刷新一次屏幕。

#### 帧速率

帧速率代表了GPU在一秒内绘制操作的帧数，比如30FPS/60FPS。在这种情况下，高点的帧速率总是好的。

#### VSYNC

刷新率和帧速率需要协同工作，才能让应用程序的内容显示到屏幕上，GPU会获取图像数据进行绘制，然后硬件负责把内容呈现到屏幕上，这将在应用程序的生命周期中周而复始地发生。

<img src="https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/%E5%88%B7%E6%96%B0%E7%8E%87%E5%92%8C%E5%B8%A7%E9%80%9F%E7%8E%87%E5%8D%8F%E5%90%8C%E5%B7%A5%E4%BD%9C.webp" width="550"/>

刷新率和帧速率并不是总能够保持相同的节奏：

- **如果帧速率实际上比刷新率快**

那么就会出现一些视觉上的问题，下面的图中可以看到，当帧速率在100fps而刷新率只有75Hz的时候，GPU所渲染的图像并非全部都被显示出来。

<img src="https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/%E5%B8%A7%E9%80%9F%E7%8E%87%E6%AF%94%E5%88%B7%E6%96%B0%E7%8E%87%E5%BF%AB%E7%9A%84%E6%83%85%E5%86%B5.webp" width="550"/>

刷新率和帧速率不一致会导致屏幕撕裂效果。当GPU正在写入帧数据，从顶部开始，新的一帧覆盖前一帧，并立刻输出一行内容。屏幕开始刷新的时候，实际上并不知道缓冲区是什么状态（不知道缓冲区中的一帧是否绘制完毕，绘制未完的话，就是某些部分是这一帧的，某些部分是上一帧的），因此它从GPU中抓住的帧可能并不是完全完整的。

<img src="https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/%E5%B1%8F%E5%B9%95%E6%92%95%E8%A3%82%E7%8E%B0%E8%B1%A1.webp" width="550"/>

目前Android的双缓冲（或者三缓冲、四缓冲）是非常有效的，当GPU将一帧写入一个后缓冲的存储器，而存储器中的次级区域被称为帧缓冲，当写入下一帧时，它会开始填充后缓冲，而帧缓冲保持不变。此时刷新屏幕，它将使用帧缓冲（事先已经绘制好了的），而不是使用正在处于绘制状态的后缓冲，这就是VSYNC的作用。

<img src="https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/VSYNC%E7%9A%84%E4%BD%9C%E7%94%A8.webp" width="550"/>

- **屏幕刷新率比帧速率快的情况**

如果屏幕刷新率比帧速率快，屏幕会在两帧中显示同一个画面。此时用户会很明显地察觉到动画卡住了或者掉帧，然后又恢复了流畅，这通常被称为闪屏，跳帧，延迟。

<img src="https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/%E5%B1%8F%E5%B9%95%E5%88%B7%E6%96%B0%E7%8E%87%E6%AF%94%E5%B8%A7%E9%80%9F%E7%8E%87%E5%BF%AB.webp" width="550"/>

**VSYNC是为了解决屏幕刷新率和GPU帧率不一致导致的“屏幕撕裂”问题**。

#### FPS

FPS：Frame Per Second，即每秒显示的帧数，也叫帧率。Android设备的FPS一般是60FPS，即每秒刷新60次，也就是60帧，每一帧的时间最多只有`1000/60=16.67ms`。一旦某一帧的绘制时间超过了限制，就会发生掉帧，用户在连续两帧会看到同样的画面。也就是上面说的屏幕刷新率比帧速率快的情况。

### 2. ViewRootImpl.setView()

之前写过一篇文章[Window,Activity,View三者关系](https://github.com/xfhy/Android-Notes)，里面提到了ViewRootImpl.setView()是在什么时候被调用的：`ActivityThread.handleResumeActivity()->WindowManagerImpl.addView()->WindowManagerGlobal.addView()->ViewRootImpl.setView()`

```java
/**
* We have one child
*/
public void setView(View view, WindowManager.LayoutParams attrs, View panelParentView) {
    synchronized (this) {
        if (mView == null) {
            mView = view;
            ...

            //注释1 开始三大流程（测量、布局、绘制）
            requestLayout();
            ...
            //注释2 添加View到WindowManagerService,这里是利用Binder跨进程通信，调用Session.addToDisplay()
            //将Window添加到屏幕
            res = mWindowSession.addToDisplay(mWindow, mSeq, mWindowAttributes,
                    getHostVisibility(), mDisplay.getDisplayId(), mWinFrame,
                    mAttachInfo.mContentInsets, mAttachInfo.mStableInsets,
                    mAttachInfo.mOutsets, mAttachInfo.mDisplayCutout, mInputChannel);
            ...
        }
    }
}
```

从ViewRootImpl.requestLayout()开始，既是View的首次绘制流程

```java
@Override
public void requestLayout() {
    if (!mHandlingLayoutInLayoutRequest) {
        checkThread();
        mLayoutRequested = true;
        scheduleTraversals();
    }
}
```

requestLayout()会走到scheduleTraversals()方法，这个方法非常重要，下面单独展开来讲。

### 3. Choreographer 编舞者

> 终于要到Choreographer上场了

```java
//ViewRootImpl.java
final class TraversalRunnable implements Runnable {
    @Override
    public void run() {
        doTraversal();
    }
}
final TraversalRunnable mTraversalRunnable = new TraversalRunnable();

void scheduleTraversals() {
    //注释1 标记是否已经开始了，开始了则不再进入
    if (!mTraversalScheduled) {
        mTraversalScheduled = true;
        //注释2 同步屏障，保证绘制消息（是异步的消息）的优先级
        mTraversalBarrier = mHandler.getLooper().getQueue().postSyncBarrier();
        //注释3 监听VSYNC信号，下一次VSYNC信号到来时，执行给进去的mTraversalRunnable
        mChoreographer.postCallback(
                Choreographer.CALLBACK_TRAVERSAL, mTraversalRunnable, null);
        ...
    }
}

void doTraversal() {
    if (mTraversalScheduled) {
        //标记已经完成
        mTraversalScheduled = false;
        //移除同步屏障
        mHandler.getLooper().getQueue().removeSyncBarrier(mTraversalBarrier);
        //开始三大流程 measure layout draw
        performTraversals();
        ...
    }
}
```

1. 在一次VSYNC信号期间多次调用scheduleTraversals是没有意义的，所以用了个标志位标记一下
2. 发送了一个屏障消息，让同步的消息不能执行，只能执行异步消息，而绘制的消息是异步的，保证了绘制的消息的优先级。绘制任务肯定高于其他的同步任务的。关于Handler同步屏障的具体详情可以阅读一下我之前写的一篇文章[Handler同步屏障](https://github.com/xfhy/Android-Notes)
3. 利用Choreographer，调用了它的postCallback方法，暂时不知道拿来干嘛的，后面详细介绍

#### Choreographer 初始化

首先我们需要知道mChoreographer是什么，在什么地方进行的初始化。在ViewRootImpl的构造方法里面，我看到了它的初始化。

```java
public ViewRootImpl(Context context, Display display) {
    mContext = context;
    //Binder代理IWindowSession，与WMS通信
    mWindowSession = WindowManagerGlobal.getWindowSession();
    mDisplay = display;
    //初始化当前线程  一般就是主线程，一般是在WindowManagerGlobal.addView()里面调用的
    mThread = Thread.currentThread();
    mWidth = -1;
    mHeight = -1;
    //Binder代理 IWindow
    mWindow = new W(this);
    //当前是不可见的
    mViewVisibility = View.GONE;
    mFirst = true; // true for the first time the view is added
    mAdded = false;
    ...
    //初始化Choreographer，从getInstance()方法名，看起来像是单例
    mChoreographer = Choreographer.getInstance();
    ...
}
```

在ViewRootImpl的构造方法中初始化Choreographer，利用Choreographer的getInstance方法，看起来像是单例。

```java
//Choreographer.java
/**
 * Gets the choreographer for the calling thread.  Must be called from
 * a thread that already has a {@link android.os.Looper} associated with it.
 * 获取当前线程中的单例Choreographer，在获取之前必须保证该线程已初始化好Looper
 * @return The choreographer for this thread.
 * @throws IllegalStateException if the thread does not have a looper.
 */
public static Choreographer getInstance() {
    return sThreadInstance.get();
}

// Thread local storage for the choreographer.
//线程私有
private static final ThreadLocal<Choreographer> sThreadInstance =
        new ThreadLocal<Choreographer>() {
    @Override
    protected Choreographer initialValue() {
        //从当前线程的ThreadLocalMap中取出Looper
        Looper looper = Looper.myLooper();
        if (looper == null) {
            throw new IllegalStateException("The current thread must have a looper!");
        }
        //初始化
        Choreographer choreographer = new Choreographer(looper, VSYNC_SOURCE_APP);
        if (looper == Looper.getMainLooper()) {
            mMainInstance = choreographer;
        }
        return choreographer;
    }
};

```

从上面的代码可以看出，其实getInstance()的实现并不是真正意义上的单例，而是线程内的单例。其实现原理是利用ThreadLocal来实现数据线程私有化，不了解的同学可以看一下[Handler机制你需要知道的一切](https://github.com/xfhy/Android-Notes)。

在ThreadLocal的initialValue()中，先是取出已经在当前线程初始化好的私有数据Looper，如果当前线程没有初始化Looper，那么对不起了，先抛个IllegalStateException表示一下。

这里的初始化一般是在主线程中，主线程中的Looper早就初始化好了，所以这里不会抛异常。by the way,主线程Looper是在什么时候初始化好的？先看一下应用进程的创建流程：

1. AMS通过调用Process.start()来创建应用进程
2. 在Process.start()里面通过ZygoteProcess的zygoteSendArgsAndGetResult与Zygote进程（Zygote是谁？它是进程孵化大师,创建之初就使用zygoteServer.registerServerSocketFromEnv创建zygote通信的服务端；然后还通过调用forkSystemServer启动`system_server`;然后是zygoteServer.runSelectLoop进入循环模式）建立Socket连接，并将创建进程所需要的参数发送给Zygote的Socket服务端
3. Zygote进程的Socket服务端（ZygoteServer）收到参数后调用ZygoteConnection.processOneCommand() 处理参数，并 fork 进程
4. 然后通过RuntimeInit的findStaticMain()找到ActivityThread类的main方法并执行

想必分析到这里，大家已经很熟悉了吧

```java
//ActivityThread.java
public static void main(String[] args) {
    ...
    //初始化主线程的Looper
    Looper.prepareMainLooper();
    
    //创建好ActivityThread 并调用attach
    ActivityThread thread = new ActivityThread();
    thread.attach(false, startSeq);

    if (sMainThreadHandler == null) {
        sMainThreadHandler = thread.getHandler();
    }
    
    //主线程处于loop循环中
    Looper.loop();
    
    //主线程的loop循环是不能退出的
    throw new RuntimeException("Main thread loop unexpectedly exited");
}
```

应用进程一启动，主线程的Looper就首当其冲的初始化好了，说明它在Android中的地位重要性非常大。它的初始化，就是将Looper存于ThreadLocal中，然后再将该ThreadLocal存于当前线程的ThreadLocalMap中，以达到线程私有化的目的。

回到Choreographer的构造方法

```java
//Choreographer.java
private Choreographer(Looper looper, int vsyncSource) {
    //把Looper传进来放起
    mLooper = looper;
    //FrameHandler初始化  传入Looper
    mHandler = new FrameHandler(looper);
    // USE_VSYNC 在 Android 4.1 之后默认为 true，
    // FrameDisplayEventReceiver是用来接收VSYNC信号的
    mDisplayEventReceiver = USE_VSYNC
            ? new FrameDisplayEventReceiver(looper, vsyncSource)
            : null;
    mLastFrameTimeNanos = Long.MIN_VALUE;
    
    //一帧的时间，60FPS就是16.66ms
    mFrameIntervalNanos = (long)(1000000000 / getRefreshRate());
    
    // 回调队列
    mCallbackQueues = new CallbackQueue[CALLBACK_LAST + 1];
    for (int i = 0; i <= CALLBACK_LAST; i++) {
        mCallbackQueues[i] = new CallbackQueue();
    }
    // b/68769804: For low FPS experiments.
    setFPSDivisor(SystemProperties.getInt(ThreadedRenderer.DEBUG_FPS_DIVISOR, 1));
}
```

构造Choreographer基本上是完了，构造方法里面有些新东西，后面详细说。

#### Choreographer 流程原理

现在我们来说一下Choreographer的postCallback()，也就是ViewRootImpl使用的地方

```java
//Choreographer.java
//ViewRootImpl是使用的这个
public void postCallback(int callbackType, Runnable action, Object token) {
    postCallbackDelayed(callbackType, action, token, 0);
}
public void postCallbackDelayed(int callbackType,
        Runnable action, Object token, long delayMillis) {
    ...
    postCallbackDelayedInternal(callbackType, action, token, delayMillis);
}
private final CallbackQueue[] mCallbackQueues;
private void postCallbackDelayedInternal(int callbackType,
        Object action, Object token, long delayMillis) {
    synchronized (mLock) {
        final long now = SystemClock.uptimeMillis();
        final long dueTime = now + delayMillis;
        //将mTraversalRunnable存入mCallbackQueues数组callbackType处的队列中
        mCallbackQueues[callbackType].addCallbackLocked(dueTime, action, token);
        
        //传入的delayMillis是0，这里dueTime是等于now的
        if (dueTime <= now) {
            scheduleFrameLocked(now);
        } else {
            Message msg = mHandler.obtainMessage(MSG_DO_SCHEDULE_CALLBACK, action);
            msg.arg1 = callbackType;
            msg.setAsynchronous(true);
            mHandler.sendMessageAtTime(msg, dueTime);
        }
    }
}
```

有2个关键地方，第一个是将mTraversalRunnable存起来方便待会儿调用，第二个是执行scheduleFrameLocked方法

```java
//Choreographer.java
private void scheduleFrameLocked(long now) {
    if (!mFrameScheduled) {
        mFrameScheduled = true;
        if (USE_VSYNC) {
            //走这里

            // 如果当前线程是初始化Choreographer时的线程，直接申请VSYNC，否则立刻发送一个异步消息到初始化Choreographer时的线程中申请VSYNC
            if (isRunningOnLooperThreadLocked()) {
                scheduleVsyncLocked();
            } else {
                Message msg = mHandler.obtainMessage(MSG_DO_SCHEDULE_VSYNC);
                msg.setAsynchronous(true);
                mHandler.sendMessageAtFrontOfQueue(msg);
            }
        } else {
            //这里是未开启VSYNC的情况，Android 4.1之后默认开启
            final long nextFrameTime = Math.max(
                    mLastFrameTimeNanos / TimeUtils.NANOS_PER_MS + sFrameDelay, now);
            if (DEBUG_FRAMES) {
                Log.d(TAG, "Scheduling next frame in " + (nextFrameTime - now) + " ms.");
            }
            Message msg = mHandler.obtainMessage(MSG_DO_FRAME);
            msg.setAsynchronous(true);
            mHandler.sendMessageAtTime(msg, nextFrameTime);
        }
    }
}
```

通过调用scheduleVsyncLocked()来监听VSYNC信号，这个信号是由硬件发出来的，信号来了的时候才开始绘制工作。

```java
//Choreographer.java
private final FrameDisplayEventReceiver mDisplayEventReceiver;

private void scheduleVsyncLocked() {
    mDisplayEventReceiver.scheduleVsync();
}

private final class FrameDisplayEventReceiver extends DisplayEventReceiver implements Runnable {
    ...
}

//DisplayEventReceiver.java
public void scheduleVsync() {
    if (mReceiverPtr == 0) {
        Log.w(TAG, "Attempted to schedule a vertical sync pulse but the display event "
                + "receiver has already been disposed.");
    } else {
        //注册监听VSYNC信号，会回调dispatchVsync()方法
        nativeScheduleVsync(mReceiverPtr);
    }
}

```

mDisplayEventReceiver是一个FrameDisplayEventReceiver，FrameDisplayEventReceiver继承自DisplayEventReceiver。在DisplayEventReceiver里面有一个方法scheduleVsync()，这个方法是用来注册监听VSYNC信号的，它是一个native方法，水平有限，暂不继续深入了。

当有VSYNC信号来临时，native层会回调DisplayEventReceiver的dispatchVsync方法

```java
//DisplayEventReceiver.java
// Called from native code.
@SuppressWarnings("unused")
private void dispatchVsync(long timestampNanos, int builtInDisplayId, int frame) {
    onVsync(timestampNanos, builtInDisplayId, frame);
}
public void onVsync(long timestampNanos, int builtInDisplayId, int frame) {
}
```

当收到VSYNC信号时，回调dispatchVsync方法，走到了onVsync方法，这个方法被子类FrameDisplayEventReceiver覆写了的

```java
//FrameDisplayEventReceiver.java  
//它是Choreographer的内部类
private final class FrameDisplayEventReceiver extends DisplayEventReceiver
        implements Runnable {
    @Override
    public void onVsync(long timestampNanos, int builtInDisplayId, int frame) {
        if (builtInDisplayId != SurfaceControl.BUILT_IN_DISPLAY_ID_MAIN) {
            Log.d(TAG, "Received vsync from secondary display, but we don't support "
                    + "this case yet.  Choreographer needs a way to explicitly request "
                    + "vsync for a specific display to ensure it doesn't lose track "
                    + "of its scheduled vsync.");
            scheduleVsync();
            return;
        }
        
        //timestampNanos是VSYNC回调的时间戳  以纳秒为单位
        long now = System.nanoTime();
        if (timestampNanos > now) {
            timestampNanos = now;
        }

        if (mHavePendingVsync) {
            Log.w(TAG, "Already have a pending vsync event.  There should only be "
                    + "one at a time.");
        } else {
            mHavePendingVsync = true;
        }

        mTimestampNanos = timestampNanos;
        mFrame = frame;
        //自己是一个Runnable，把自己传了进去
        Message msg = Message.obtain(mHandler, this);
        //异步消息，保证优先级
        msg.setAsynchronous(true);
        mHandler.sendMessageAtTime(msg, timestampNanos / TimeUtils.NANOS_PER_MS);
    }
    
    @Override
    public void run() {
        ...
        doFrame(mTimestampNanos, mFrame);
    }
}
```

在onVsync()方法中，其实主要内容就是发个消息（应该是为了切换线程），然后执行run方法。而在run方法中，调用了Choreographer的doFrame方法。这个方法有点长，我们来理一下。

```java
//Choreographer.java

//frameTimeNanos是VSYNC信号回调时的时间
void doFrame(long frameTimeNanos, int frame) {
    final long startNanos;
    synchronized (mLock) {
        if (!mFrameScheduled) {
            return; // no work to do
        }
        ...
        long intendedFrameTimeNanos = frameTimeNanos;
        startNanos = System.nanoTime();
        //jitterNanos为当前时间与VSYNC信号来时的时间的差值，如果Looper有很多异步消息等待处理（或者是前一个异步消息处理特别耗时，当前消息发送了很久才得以执行），那么处理当来到这里时可能会出现很大的时间间隔
        final long jitterNanos = startNanos - frameTimeNanos;
        
        //mFrameIntervalNanos是帧间时长，一般手机上为16.67ms
        if (jitterNanos >= mFrameIntervalNanos) {
            final long skippedFrames = jitterNanos / mFrameIntervalNanos;
            //想必这个日志大家都见过吧，主线程做了太多的耗时操作或者绘制起来特别慢就会有这个
            //这里的逻辑是当掉帧个数超过30，则输出相应日志
            if (skippedFrames >= SKIPPED_FRAME_WARNING_LIMIT) {
                Log.i(TAG, "Skipped " + skippedFrames + " frames!  "
                        + "The application may be doing too much work on its main thread.");
            }
            final long lastFrameOffset = jitterNanos % mFrameIntervalNanos;
            frameTimeNanos = startNanos - lastFrameOffset;
        }
        ...
    }

    try {
        AnimationUtils.lockAnimationClock(frameTimeNanos / TimeUtils.NANOS_PER_MS);

        mFrameInfo.markInputHandlingStart();
        doCallbacks(Choreographer.CALLBACK_INPUT, frameTimeNanos);

        mFrameInfo.markAnimationsStart();
        doCallbacks(Choreographer.CALLBACK_ANIMATION, frameTimeNanos);
        
        //执行回调
        mFrameInfo.markPerformTraversalsStart();
        doCallbacks(Choreographer.CALLBACK_TRAVERSAL, frameTimeNanos);

        doCallbacks(Choreographer.CALLBACK_COMMIT, frameTimeNanos);
    } finally {
        AnimationUtils.unlockAnimationClock();
    }
}
```

doFrame大体做了2件事，一个是可能会给开发者打个日志提醒下卡顿，另一个是执行回调。

当VSYNC信号来临时，记录了此时的时间点，也就是这里的frameTimeNanos。而执行doFrame()时，是通过Looper的消息循环来的，这意味着前面有消息没执行完，那么当前这个消息的执行就会被阻塞在那里。时间太长了，而这个是处理界面绘制的，如果时间长了没有即时进行绘制，就会出现掉帧。源码中也打了log，在掉帧30的时候。

下面来看一下执行回调的过程

```java
//Choreographer.java
void doCallbacks(int callbackType, long frameTimeNanos) {
    CallbackRecord callbacks;
    synchronized (mLock) {
        final long now = System.nanoTime();
        //根据callbackType取出相应的CallbackRecord
        callbacks = mCallbackQueues[callbackType].extractDueCallbacksLocked(
                now / TimeUtils.NANOS_PER_MS);
        if (callbacks == null) {
            return;
        }
        mCallbacksRunning = true;
        ...
    }
    try {
        Trace.traceBegin(Trace.TRACE_TAG_VIEW, CALLBACK_TRACE_TITLES[callbackType]);
        for (CallbackRecord c = callbacks; c != null; c = c.next) {
            //
            c.run(frameTimeNanos);
        }
    } finally {
        ...
    }
}
private static final class CallbackRecord {
    public CallbackRecord next;
    public long dueTime;
    public Object action; // Runnable or FrameCallback
    public Object token;

    public void run(long frameTimeNanos) {
        if (token == FRAME_CALLBACK_TOKEN) {
            ((FrameCallback)action).doFrame(frameTimeNanos);
        } else {
            //会走到这里来，因为ViewRootImpl的scheduleTraversals时，postCallback传过来的token是null。
            ((Runnable)action).run();
        }
    }
}
```

从mCallbackQueues数组中找到callbackType对应的CallbackRecord，然后执行队列里面的所有元素（CallbackRecord）的run方法。然后也就是执行到了ViewRootImpl的scheduleTraversals时，postCallback传过来的mTraversalRunnable（是一个Runnable）。回顾一下:

```java
//ViewRootImpl.java
final class TraversalRunnable implements Runnable {
    @Override
    public void run() {
        doTraversal();
    }
}
```

也是，我们整个流程也就完成了，从doTraversal()开始就是View的三大流程（measure、layout、draw）了。Choreographer的使命也基本完成了。

上面就是Choreographer的工作流程。简单总结一下：

1. 从ActivityThread.handleResumeActivity开始，`ActivityThread.handleResumeActivity()->WindowManagerImpl.addView()->WindowManagerGlobal.addView()->初始化ViewRootImpl->初始化Choreographer->ViewRootImpl.setView()`
2. 在ViewRootImpl的setView中会调用`requestLayout()->scheduleTraversals()`,然后是建立同步屏障
3. 通过Choreographer线程单例的postCallback()提交一个任务mTraversalRunnable，这个任务是用来做View的三大流程的（measure、layout、draw）
4. Choreographer.postCallback()内部通过DisplayEventReceiver.nativeScheduleVsync()向系统底层注册VSYNC信号监听，当VSYNC信号来临时，会回调DisplayEventReceiver的dispatchVsync()，最终会通知FrameDisplayEventReceiver.onVsync()方法。
5. 在onVsync()中取出之前传入的任务mTraversalRunnable，执行run方法，开始绘制流程。

### 应用

在了解了Choreographer的工作原理之后，我们来点实际的，将Choreographer这块的知识利用起来。它可以帮助我们检测应用的fps。

#### 检测FPS

有了上面的分析，我们知道Choreographer内部去监听了VSYNC信号，并且当VSYNC信号来临时会发个异步消息给Looper，在执行到这个消息时会通知外部观察者（上面的观察者就是ViewRootImpl），通知ViewRootImpl可以开始绘制了。Choreographer的每次回调都是在通知ViewRootImpl绘制，我们只需要统计出1秒内这个回调次数有多少次，即可知道是多少fps。

反正Choreographer是线程单例，我在主线程调用获取它的实例，然后模仿ViewRootImpl调用postCallback注册一个观察者。于是我将该思路写成代码，然后发现，postCallback是居然是hide方法。/无语

但是，有个意外收获，Choreographer提供了另外一个postFrameCallback方法。我看了下源码，与postCallback差异不大，只不过注册的观察者类型是`CALLBACK_ANIMATION`，但这不影响它回调

```java
//Choreographer.java
public void postFrameCallback(FrameCallback callback) {
    postFrameCallbackDelayed(callback, 0);
}
public void postFrameCallbackDelayed(FrameCallback callback, long delayMillis) {
    postCallbackDelayedInternal(CALLBACK_ANIMATION,
            callback, FRAME_CALLBACK_TOKEN, delayMillis);
}
```

直接上代码吧，show me the code

```java
object FpsMonitor {

    private const val FPS_INTERVAL_TIME = 1000L

    /**
     * 1秒内执行回调的次数  即fps
     */
    private var count = 0
    private val mMonitorListeners = mutableListOf<(Int) -> Unit>()

    @Volatile
    private var isStartMonitor = false
    private val monitorFrameCallback by lazy { MonitorFrameCallback() }
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    fun startMonitor(listener: (Int) -> Unit) {
        mMonitorListeners.add(listener)
        if (isStartMonitor) {
            return
        }
        isStartMonitor = true
        Choreographer.getInstance().postFrameCallback(monitorFrameCallback)
        //1秒后结算 count次数
        mainHandler.postDelayed(monitorFrameCallback, FPS_INTERVAL_TIME)
    }

    fun stopMonitor() {
        isStartMonitor = false
        count = 0
        Choreographer.getInstance().removeFrameCallback(monitorFrameCallback)
        mainHandler.removeCallbacks(monitorFrameCallback)
    }

    class MonitorFrameCallback : Choreographer.FrameCallback, Runnable {

        //VSYNC信号到了，且处理到当前异步消息了，才会回调这里
        override fun doFrame(frameTimeNanos: Long) {
            //次数+1  1秒内
            count++
            //继续下一次 监听VSYNC信号
            Choreographer.getInstance().postFrameCallback(this)
        }

        override fun run() {
            //将count次数传递给外面
            mMonitorListeners.forEach {
                it.invoke(count)
            }
            count = 0
            //继续发延迟消息  等到1秒后统计count次数
            mainHandler.postDelayed(this, FPS_INTERVAL_TIME)
        }
    }

}
```

通过记录每秒内Choreographer回调的次数，即可得到FPS。

#### 监测卡顿

Choreographer除了可以用来监测FPS以外还可以拿来进行卡顿检测。

##### Choreographer 帧率检测

##### Looper字符串匹配 卡顿检测

这里介绍另一种方式来进行卡顿检测（这里指主线程，子线程一般不关心卡顿问题）--Looper。先来看一段loop代码：

```java
//Looper.java
private Printer mLogging;
public void setMessageLogging(@Nullable Printer printer) {
    mLogging = printer;
}

public static void loop() {
    final Looper me = myLooper();
    for (;;) {
        final Printer logging = me.mLogging;
        if (logging != null) {
            logging.println(">>>>> Dispatching to " + msg.target + " " +
                    msg.callback + ": " + msg.what);
        }
        ...
        msg.target.dispatchMessage(msg);
        ...
        if (logging != null) {
            logging.println("<<<<< Finished to " + msg.target + " " + msg.callback);
        }
    }
}
```

从这段代码可以看出，如果我们设置了Printer，那么在每个消息分发的前后都会打印一句日志来标识事件分发的开始和结束。这个点可以利用一下，我们可以通过Looper打印日志的时间间隔来判断是否发生卡顿，如果发生卡顿，则将此时线程的堆栈信息给保存下来，进而分析哪里卡顿了。这种匹配字符串方案能够准确地在发生卡顿时拿到堆栈信息。

原理搞清楚了，咱直接撸一个工具出来

```java
const val TAG = "looper_monitor"

/**
 * 默认卡顿阈值
 */
const val DEFAULT_BLOCK_THRESHOLD_MILLIS = 3000L
const val BEGIN_TAG = ">>>>> Dispatching"
const val END_TAG = "<<<<< Finished"

class LooperPrinter : Printer {

    private var mBeginTime = 0L

    @Volatile
    var mHasEnd = false
    private val collectRunnable by lazy { CollectRunnable() }
    private val handlerThreadWrapper by lazy { HandlerThreadWrapper() }

    override fun println(msg: String?) {
        if (msg.isNullOrEmpty()) {
            return
        }
        log(TAG, "$msg")
        if (msg.startsWith(BEGIN_TAG)) {
            mBeginTime = System.currentTimeMillis()
            mHasEnd = false

            //需要单独搞个线程来获取堆栈
            handlerThreadWrapper.handler.postDelayed(
                collectRunnable,
                DEFAULT_BLOCK_THRESHOLD_MILLIS
            )
        } else {
            mHasEnd = true
            if (System.currentTimeMillis() - mBeginTime < DEFAULT_BLOCK_THRESHOLD_MILLIS) {
                handlerThreadWrapper.handler.removeCallbacks(collectRunnable)
            }
        }
    }

    fun getMainThreadStackTrace(): String {
        val stackTrace = Looper.getMainLooper().thread.stackTrace
        return StringBuilder().apply {
            for (stackTraceElement in stackTrace) {
                append(stackTraceElement.toString())
                append("\n")
            }
        }.toString()
    }

    inner class CollectRunnable : Runnable {
        override fun run() {
            if (!mHasEnd) {
                //主线程堆栈给拿出来，打印一下
                log(TAG, getMainThreadStackTrace())
            }
        }
    }

    class HandlerThreadWrapper {
        var handler: Handler
        init {
            val handlerThread = HandlerThread("LooperHandlerThread")
            handlerThread.start()
            handler = Handler(handlerThread.looper)
        }
    }

}
```

代码比较少，主要思路就是在println()回调时判断回调的文本信息是开始还是结束。如果是开始则搞个定时器，3秒后就认为是卡顿，就开始取主线程堆栈信息输出日志，如果在这3秒内消息已经分发完成，那么就不是卡顿，就把这个定时器取消掉。

我在demo中搞了个点击事件，sleep了4秒

```java
17987-17987/com.xfhy.allinone D/looper_monitor: >>>>> Dispatching to Handler (android.view.ViewRootImpl$ViewRootHandler) {63ca49} android.view.View$PerformClick@13f525a: 0
17987-18042/com.xfhy.allinone D/looper_monitor: java.lang.Thread.sleep(Native Method)
    java.lang.Thread.sleep(Thread.java:373)
    java.lang.Thread.sleep(Thread.java:314)
    com.xfhy.allinone.performance.caton.CatonDetectionActivity.manufacturingCaton(CatonDetectionActivity.kt:39)
    com.xfhy.allinone.performance.caton.CatonDetectionActivity.access$manufacturingCaton(CatonDetectionActivity.kt:14)
    com.xfhy.allinone.performance.caton.CatonDetectionActivity$onCreate$3.onClick(CatonDetectionActivity.kt:34)
    android.view.View.performClick(View.java:6597)
    android.view.View.performClickInternal(View.java:6574)
    android.view.View.access$3100(View.java:778)
    android.view.View$PerformClick.run(View.java:25885)
    android.os.Handler.handleCallback(Handler.java:873)
    android.os.Handler.dispatchMessage(Handler.java:99)
    android.os.Looper.loop(Looper.java:193)
    android.app.ActivityThread.main(ActivityThread.java:6669)
    java.lang.reflect.Method.invoke(Native Method)
    com.android.internal.os.RuntimeInit$MethodAndArgsCaller.run(RuntimeInit.java:493)
    com.android.internal.os.ZygoteInit.main(ZygoteInit.java:858)
17987-17987/com.xfhy.allinone D/looper_monitor: <<<<< Finished to Handler (android.view.ViewRootImpl$ViewRootHandler) {63ca49} android.view.View$PerformClick@13f525a
```

可以看到，我们已经获取到了卡顿时的堆栈信息，从这些信息已经足以分析出在哪里发生了什么事情。这里是在CatonDetectionActivity的manufacturingCaton处sleep()了。

### 参考资料

- https://www.youtube.com/watch?v=1iaHxmfZGGc&list=UU_x5XG1OV2P6uZZ5FSM9Ttw&index=1964
- https://juejin.cn/post/6890407553457963022
- http://gityuan.com/2017/02/25/choreographer/
- https://github.com/markzhai/AndroidPerformanceMonitor
- https://zhuanlan.zhihu.com/p/108022695