Handler同步屏障
---
#### 目录
- [1. 同步屏障机制是什么](#head1)
- [2. 原理](#head2)
- [3. 发送异步消息](#head3)
- [4. 正确使用](#head4)

---

### <span id="head1">1. 同步屏障机制是什么</span>

Handler发送的消息分为普通消息、屏障消息、异步消息，一旦Looper在处理消息时遇到屏障消息，那么就不再处理普通的消息，而仅仅处理异步的消息。不再使用屏障后，需要撤销屏障，不然就再也执行不到普通消息了。

为什么需要这样？它是设计来为了让某些特殊的消息得以更快被执行的机制。比如绘制界面，这种消息可能会明显的被用户感知到，稍有不慎就会引起卡顿、掉帧之类的，所以需要及时处理（可能消息队列中有大量的消息，如果像平时一样挨个进行处理，那绘制界面这个消息就得等很久，这是不想看到的）。

屏障消息仅仅是起一个屏障的作用，本身一般不附带其他东西，它需要配合其他Handler组件才能发挥作用。

### <span id="head2">2. 原理</span>

Handler组件中包含：Looper、Message、MessageQueue、Handler。

在Message中，有一个变量flag，用于标记这个Message正在被使用、此消息是异步消息等，通过一个方法isAsynchronous()可以获取当前Message是否为异步消息。同时，在Message中有一个变量target，是Handler类型的，表示最终由这个Handler进行处理。

平时我们发送消息时，这个target是不可以为null的。

```java
//MessageQueue.java
boolean enqueueMessage(Message msg, long when) {
    if (msg.target == null) {
        throw new IllegalArgumentException("Message must have a target.");
    }
    if (msg.isInUse()) {
        throw new IllegalStateException(msg + " This message is already in use.");
    }
}
```

但是在发送屏障消息的时候，target是可以为空的，它本身仅仅是起屏蔽普通消息的作用，所以不需要target。MessageQueue中提供了postSyncBarrier()方法用于插入屏障消息。

```java
//MessageQueue.java
/**
 * @hide
 */
public int postSyncBarrier() {
    return postSyncBarrier(SystemClock.uptimeMillis());
}

private int postSyncBarrier(long when) {
    synchronized (this) {
        //这个token在移除屏障时会使用到
        final int token = mNextBarrierToken++;
        final Message msg = Message.obtain();
        msg.markInUse();
        msg.when = when;
        msg.arg1 = token;
        
        //在屏障的时间到来之前的普通消息，不会被屏蔽
        Message prev = null;
        Message p = mMessages;
        if (when != 0) {
            while (p != null && p.when <= when) {
                prev = p;
                p = p.next;
            }
        }
        
         //插入到单链表中
        if (prev != null) { // invariant: p == prev.next
            msg.next = p;
            prev.next = msg;
        } else {
            msg.next = p;
            mMessages = msg;
        }
        return token;
    }
}
```

看起来比较简单，可以获取的信息如下：

- 屏障消息和普通消息区别在于屏幕没有target，普通消息有target是因为它需要将消息分发给对应的target，而屏幕不需要被分发，它就是用来挡住普通消息来保证异步消息优先处理的
- 屏障和普通消息一样可以根据时间来插入到消息队列中的适当位置，并且只会挡住它后面的同步消息的分发
- postSyncBarrier会返回一个token，利用这个token可以撤销屏障
- postSyncBarrier是hide的，使用它得用反射
- 插入普通消息会唤醒消息队列，但插入屏障不会

现在屏障已经插入到消息队列中了，它是如何挡住普通消息而只需要异步消息进行执行的呢？Looper是通过MessageQueue的next方法来获取消息的，来看看

```java
//MessageQueue.java
Message next() {
    ...
    int pendingIdleHandlerCount = -1;
    int nextPollTimeoutMillis = 0;
    for (;;) {
        //如有消息被插入到消息队列或者超时时间到，就被唤醒，否则会阻塞在这里
        nativePollOnce(ptr, nextPollTimeoutMillis);

        synchronized (this) {
            final long now = SystemClock.uptimeMillis();
            Message prevMsg = null;
            Message msg = mMessages;
            //遇到屏障  它的target是空的
            if (msg != null && msg.target == null) {
                //找出屏障后面的异步消息，
                do {
                    prevMsg = msg;
                    msg = msg.next;
                    //isAsynchronous()返回true才是异步消息
                } while (msg != null && !msg.isAsynchronous());
            }
            
            //如果找到了异步消息
            if (msg != null) {
                if (now < msg.when) {
                    //还没到处理时间，再等一会儿
                    nextPollTimeoutMillis = (int) Math.min(msg.when - now, Integer.MAX_VALUE);
                } else {
                    //到处理时间了，就从链表中移除，返回这个消息
                    mBlocked = false;
                    if (prevMsg != null) {
                        prevMsg.next = msg.next;
                    } else {
                        mMessages = msg.next;
                    }
                    msg.next = null;
                    msg.markInUse();
                    return msg;
                }
            } else {
                //如果没有异步消息就一直休眠，等待被唤醒
                nextPollTimeoutMillis = -1;
            }
            ...
        }
        ...
    }
}
```

在MessageQueue中取下一个消息时，如果遇到屏障，就遍历消息队列，取最近的一个异步消息，然后返回出去。如果没有异步消息，则一直休眠在那里，等待着被唤醒。

### <span id="head3">3. 发送异步消息</span>

虽然postSyncBarrier()被标记位hide，但是我们想调还是可以通过反射调用的。而且还可以通过系统调用这个方法添加屏障（在ViewRootImpl中requestLayout时会使用到）之后，我们发送异步消息，悄悄上车。

添加异步消息时有两种办法：

- 使用异步类型的Handler发送的全部Message都是异步的
- 给Message标记异步

给Message标记异步可以通过它的setAsynchronous()进行，非常简单。

Handler有一系列带async的参数构造器，这个参数决定是否是异步Handler。

```java
//Handler.java
/**
 * @hide
 */
public Handler(Looper looper, Callback callback, boolean async) {
    mLooper = looper;
    mQueue = looper.mQueue;
    mCallback = callback;
    mAsynchronous = async;
}
```

遗憾的是这些构造方法全被标记为hide了。从API 28以后提供了2个方法：

```java
public static Handler createAsync(@NonNull Looper looper) {
    if (looper == null) throw new NullPointerException("looper must not be null");
    return new Handler(looper, null, true);
}
public static Handler createAsync(@NonNull Looper looper, @NonNull Callback callback) {
    if (looper == null) throw new NullPointerException("looper must not be null");
    if (callback == null) throw new NullPointerException("callback must not be null");
    return new Handler(looper, callback, true);
}
```

这2个方法可以帮忙创建异步的Handler，但需要API 28以上，那意思就是没用咯。不如反射Handler构造方法来得快。

### <span id="head4">4. 正确使用</span>

系统把插入屏障和构造异步Handler这些东西标记为hide，意思就是这些API是系统自己用的，不想让开发者调用呗。那系统是什么时候用的呢？

异步消息需要同步屏障的辅助，但同步屏障我们无法手动添加，因此了解系统何时添加和删除同步屏障是必要的。只有这样才能更好地运行异步消息这个功能，知道为什么要用和如何用。了解同步屏障需要简单了解一点屏幕刷新机制的内容。

手机屏幕刷新屏幕有不同的类型，60Hz、120Hz等。屏幕会在每次刷新的时候发出一个Vsync信号，通知CPU进行绘制计算。具体到我们代码中，可以认为是执行onMeasure、onLayout、onDraw这些方法。

View绘制的起点是ViewRootImpl的requestLayout()开始的，这个方法会去执行上面的三大绘制任务：测量、布局、绘制。**调用requestLayout()方法之后，并不会马上开始进行绘制任务，而是会给主线程设置一个同步屏幕，并设置Vsync信号监听。当Vsync信号的到来，会发送一个异步消息到主线程Handler，执行我们上一步设置的绘制监听任务，并移除同步屏障。**

```java
//ViewRootImpl.java
@Override
public void requestLayout() {
    if (!mHandlingLayoutInLayoutRequest) {
        checkThread();
        mLayoutRequested = true;
        scheduleTraversals();
    }
}
void scheduleTraversals() {
    if (!mTraversalScheduled) {
        mTraversalScheduled = true;
        //插入屏障
        mTraversalBarrier = mHandler.getLooper().getQueue().postSyncBarrier();
        //监听Vsync信号，然后发送异步消息 -> 执行绘制任务
        mChoreographer.postCallback(
                Choreographer.CALLBACK_TRAVERSAL, mTraversalRunnable, null);
        if (!mUnbufferedInputDispatch) {
            scheduleConsumeBatchedInput();
        }
        notifyRendererOfFramePending();
        pokeDrawLockIfNeeded();
    }
}
```
在等待Vsync信号的时候主线程什么事都没干，这样的好处是保证在Vsync信号到来时，绘制任务可以被及时执行，不会造成界面卡顿。

这样的话，我们发送的普通消息可能会被延迟处理，在Vsync信号到了之后，移除屏障，才得以处理普通消息。改善这个问题的办法是使用异步消息，发送异步消息之后，即时是在等待Vsync期间也可以执行我们的任务，让我们设置的任务可以更快得被执行（如有必要才这样搞，UI绘制高于一切）且减少主线程的Looper压力。

### 参考资料

- https://mp.weixin.qq.com/s/CNpnS6y2IYobzDa7rAjy1Q
- https://blog.csdn.net/start_mao/article/details/98963744
