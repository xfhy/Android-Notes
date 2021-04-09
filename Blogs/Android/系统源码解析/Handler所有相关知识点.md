
### 1.Handler被设计出来的原因？有什么用？

一种东西被设计出来肯定就有它存在的意义，Handler的意义就是切换线程。

作为Android消息机制的主要成员，它管理着所有与界面有关的消息事件，常见的使用场景：

- 不管在什么线程中往Handler发消息，最终处理消息的代码都会在你创建Handler实例的线程中运行；一般是拿来子线程做耗时操作，然后发消息到主线程去更新UI；
- 延迟执行 or 定时执行

### 2.为什么建议子线程不访问（更新）UI？

Android中的UI空间不是线程安全的，如果多线程访问UI控件就乱套了。

那为什么不加锁呢?

- **会降低UI访问的效率**。本身UI控件就是离用户比较近的一个组件，加锁之后自然会发生阻塞，那么UI访问的效率会降低，最终反应到用户端就是这个手机有点卡
- **太复杂了**。本身UI访问是一个比较简单的操作逻辑，直接创建UI，修改UI即可。如果加锁之后就让这个UI访问的逻辑变得很复杂，没必要

所以Android设计出了**单线程模型**来处理UI操作，再搭配上Handler，是一个比较合适的解决方案。

### 3.子线程访问Ui的崩溃原因和解决办法？

崩溃发生在ViewRootImpl的checkThread方法中：

```java
//ViewRootImpl.java
public ViewRootImpl(Context context, Display display) {
    ...
    mThread = Thread.currentThread();
}
@Override
public void requestLayout() {
    if (!mHandlingLayoutInLayoutRequest) {
        checkThread();
        mLayoutRequested = true;
        scheduleTraversals();
    }
}
void checkThread() {
    //mThread是在构造方法里面初始化的
    if (mThread != Thread.currentThread()) {
        throw new CalledFromWrongThreadException(
                "Only the original thread that created a view hierarchy can touch its views.");
    }
}
```

就是简单判断了下当前线程是否是ViewRootImpl创建时候的线程，如果不是，就抛个异常。

ViewRootImpl创建流程：`ActivityThread#handleResumeActivity()->WindowManagerImpl#addView()->WindowManagerGlobal#addView()`里面进行创建。所以如果在子线程进行UI更新，就会发现当前线程（子线程）和View创建的线程（主线程）不是同一个线程，发生崩溃。

解决办法：

1. 在新建视图的线程进行这个视图的UI更新，比如在主线程创建View，那么就在主线程更新View
2. 在ViewRootImpl创建之前进行子线程的UI更新，比如onCreate方法中子线程更新UI
3. 子线程切换到主线程进行UI更新，比如Handler、View.post方法

### 4. MessageQueue是干什么的？用的什么数据结构来存储数据？

看名字应该是个队列结构，队列的特点是先进先出，一般在队尾增加数据，在队首进行取数据或者删除数据。Handler中的消息比较特殊，可能有一种特殊情况，比如延时消息，消息屏幕，所以不一定是从队首开始取数据。所以Android中采用了链表的形式来实现这个队列，方便数据的插入。

消息的发送过程中，无论是哪种方法发送消息，都会走到sendMessageAtTime方法

```java
public final boolean sendMessageDelayed(@NonNull Message msg, long delayMillis) {
    if (delayMillis < 0) {
        delayMillis = 0;
    }
    return sendMessageAtTime(msg, SystemClock.uptimeMillis() + delayMillis);
}
public boolean sendMessageAtTime(@NonNull Message msg, long uptimeMillis) {
    MessageQueue queue = mQueue;
    return enqueueMessage(queue, msg, uptimeMillis);
}
```

sendMessageDelayed方法主要计算了消息需要被处理的时间，如果delayMillis为0，那么消息的处理时间就是当前时间。然后就是关键方法enqueueMessage()。

```java
//MessageQueue.java
boolean enqueueMessage(Message msg, long when) {
    synchronized (this) {
        msg.markInUse();
        msg.when = when;
        Message p = mMessages;
        boolean needWake;
        if (p == null || when == 0 || when < p.when) {
            msg.next = p;
            mMessages = msg;
            needWake = mBlocked;
        } else {
            needWake = mBlocked && p.target == null && msg.isAsynchronous();
            Message prev;
            for (;;) {
                prev = p;
                p = p.next;
                if (p == null || when < p.when) {
                    break;
                }
                if (needWake && p.isAsynchronous()) {
                    needWake = false;
                }
            }
            msg.next = p; 
            prev.next = msg;
        }

        if (needWake) {
            nativeWake(mPtr);
        }
    }
    return true;
}
```

不懂的地方先不看，只看我们想看的：

- 首先设置了Message的when字段，也就是代表了这个消息的处理时间
- 然后判断当前队列是不是为空，是不是即时消息，是不是执行时间when大于表头的消息时间，满足任意一个，就把当前消息msg插入到表头
- 否则，就需要遍历这个队列，也就是链表,找出when小于某个节点的when，找到后插入

其他内容暂且不看，总之，插入消息就是通过消息的执行时间，也就是when字段，来找到合适的位置插入链表。具体方法就是通过死循环，使用快慢指针p和prev，每次向后移动一格，直到找到某个节点p的when大于我们要插入消息的when字段，则插入到p和prev之间。或者遍历结束，插入到链表结尾。

所以，MessageQueue是一个用于存储消息、用链表实现的特殊队列结构。

### 5. 延迟消息是怎么实现的？

在第4节我们提到，MessageQueue是按照Message触发时间的先后顺序排列的，队头的消息是将要最早触发的消息。排在越前面的越早触发，这个所谓的延时呢，不是延时发送消息，而是延时去处理消息，我们在发消息时都是马上插入到消息队列当中。

我们这里插入完消息之后，怎么保证在预期的时间里处理消息呢？

```java
//MessageQueue.java
Message next() {
    ...
    for (;;) {
        if (nextPollTimeoutMillis != 0) {
            Binder.flushPendingCommands();
        }
        
        //阻塞操作，等打完nextPollTimeoutMillis时长时会返回，消息队列被唤醒时会返回
        nativePollOnce(ptr, nextPollTimeoutMillis);

        //如果阻塞操作结束，则去获取消息
        synchronized (this) {
            // Try to retrieve the next message.  Return if found.
            //尝试取下一条消息
            final long now = SystemClock.uptimeMillis();
            Message prevMsg = null;
            Message msg = mMessages;
            //target为空，即Handler为空，说明这个msg是消息屏障
            if (msg != null && msg.target == null) {
                // Stalled by a barrier.  Find the next asynchronous message in the queue.
                //此时只在意异步消息，查找队列中的下一个异步消息
                do {
                    prevMsg = msg;
                    msg = msg.next;
                } while (msg != null && !msg.isAsynchronous());
            }
            if (msg != null) {
                //当第一个消息或异步消息触发时间大于当前时间，则设置下一次阻塞时长
                if (now < msg.when) {
                    // Next message is not ready.  Set a timeout to wake up when it is ready.
                    nextPollTimeoutMillis = (int) Math.min(msg.when - now, Integer.MAX_VALUE);
                } else {
                    //获取一条消息，并返回
                    // Got a message.
                    mBlocked = false;
                    if (prevMsg != null) {
                        prevMsg.next = msg.next;
                    } else {
                        mMessages = msg.next;
                    }
                    msg.next = null;
                    //设置消息的使用状态，即flags |= FLAG_IN_USE
                    msg.markInUse();
                    //成功地获取MessageQueue中的下一条即将要执行的消息
                    return msg;
                }
            } else {
                //没有消息
                nextPollTimeoutMillis = -1;
            }
            ...
        }
        ...
    }
}
```



### 参考资料

- https://juejin.cn/post/6943048240291905549?utm_source=gold_browser_extension
- https://blog.csdn.net/qq_38366777/article/details/108942036
