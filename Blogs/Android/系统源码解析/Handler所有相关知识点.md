
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

当`msg!=null`，如果当前时间小于头部Message的时间（消息队列是按时间顺序排列的），那么就更新等待时间nextPollTimeoutMillis，等下次再做比较。如果时间到了，就取这个消息返回。如果没有消息，nextPollTimeoutMillis被赋值为-1，这个循环又执行到nativePollOnce继续阻塞。

nativePollOnce是一个native方法，它最终会执行到pollInner方法

```cpp
//Looper.cpp
int Looper::pollInner(int timeoutMillis) {
    ...
    // Poll.
    int result = POLL_WAKE;
    mResponses.clear();
    mResponseIndex = 0;
    //即将处于idle状态
    mPolling = true;

    struct epoll_event eventItems[EPOLL_MAX_EVENTS];
    //等待事件发生或者超时，在nativeWake()方法，向管道写端写入字符，则该方法会返回；
    int eventCount = epoll_wait(mEpollFd.get(), eventItems, EPOLL_MAX_EVENTS, timeoutMillis);
    ...
    return result;
}
```

从native层可以看到是利用linux的epoll机制，调用了`epoll_wait`函数来实现的阻塞，**设置`epoll_wait`的超时时间，使其在特定时间唤醒**。这里我们先计算当前时间和触发时间的差值，这个差值作为`epoll_wait`的超时时间，`epoll_wait`超时的时候就是消息触发的时候了，就不会继续阻塞，继续往下执行，这个线程就会被唤醒，去执行消息处理。

### 6. MessageQueue的消息怎么被取出来的？

消息的取出，即MessageQueue的next方法，第5节中已经分析next方法了。但有个问题，为什么取消息也是用的死循环？其实死循环就是为了保证一定要返回一条消息，如果没有可用消息，那么就阻塞在这里，一直到有新消息的到来。

其中，nativePollOnce方法就是阻塞方法，nextPollTimeoutMillis参数就是阻塞的时间。什么时候会阻塞？两种情况：

1. 有消息，但是当前时间小于消息执行时间，也就是代码中的这一句

```java
if (now < msg.when) {
    nextPollTimeoutMillis = (int) Math.min(msg.when - now, Integer.MAX_VALUE);
}
```
这时候阻塞时间就是消息时间减去当前时间，然后进入下一次循环，阻塞。

2. 没有消息的时候

```java
if (msg != null) {
    ...
} else {
    // No more messages.
    nextPollTimeoutMillis = -1;
}

```

-1就代表一直阻塞。

### MessageQueue没有消息时会怎样？阻塞之后怎么唤醒？说说pipe/epoll机制？

接着上文的逻辑，当消息不可用或者没有消息的时候就会阻塞在next方法，而**阻塞的方法是通过pipe（管道）和epoll机制**（有了这个机制，Looper的死循环就不会导致CPU使用率过高）。

pipe: 管道，使用I/O流操作，实现跨进程通信，管道的一端的读，另一端写，标准的生产者消费者模式。


**epoll机制**是一种多路复用的机制，具体逻辑就是一个线程可以监视多个描述符，当某个描述符就绪（一般是读就绪或者写就绪），能够通知程序进行相应的读写操作，这个读写操作是阻塞的。在Android中，会创建一个Linux管道（Pipe）来处理阻塞和唤醒。

- 当消息队列为空，管道的读端等待管道中有无新的内容可读，就会通过epoll机制进入阻塞状态
- 当有消息要处理，就会通过管道的写端写入内容，唤醒主线程

那什么时候会怎么唤醒消息队列线程呢？

上面的enqueueMessage方法中有个needWake字段，很明显，这个就是表示是否唤醒的字段。其中还有个字段是mBlocked，字面意思是阻塞的意思，在代码中看看

```java
//MessageQueue.java
Message next() {
    for (;;) {
        synchronized (this) {
            if (msg != null) {
                if (now < msg.when) {
                    nextPollTimeoutMillis = (int) Math.min(msg.when - now, Integer.MAX_VALUE);
                } else {
                    // Got a message.
                    mBlocked = false;
                    return msg;
                }
            } 
            if (pendingIdleHandlerCount <= 0) {
                // No idle handlers to run.  Loop and wait some more.
                mBlocked = true;
                continue;
            }
        }
    }
}
```

在获取消息的方法next中，有两个地方对mBlocked赋值：

- 当获取到消息的时候，mBlocked赋值为false，表示不阻塞
- 当没有消息要处理，也没有idleHandler要处理的时候，mBlocked赋值为true，表示阻塞

再看看enqueueMessage方法，唤醒机制：

```java
boolean enqueueMessage(Message msg, long when) {
    synchronized (this) {
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

1. 当链表为空或者时间小于表头消息时间，那么就插入表头，并且根据mBlocked的值来设置是否需要唤醒。再结合上述的例子，也就是当有新消息要插入表头了，这时候如果之前是阻塞状态（mBlocked为true），那么就要唤醒线程；
2. 否则，就需要去链表中找到某个节点并插入消息，在这之前需要赋值为`needWake = mBlocked && p.target == null && msg.isAsynchronous()`。也就是在插入消息之前，需要判断是否阻塞，并且表头是不是屏障消息，并且当前消息是不是异步消息。也就是如果现在是同步屏障模式下，那么要插入的消息又刚好是异步消息，那就不用管插入消息问题了，直接唤醒线程，因为异步消息需要先执行。
3. 最后一点，是在循环里，如果发现之前就存在异步消息，那就不唤醒，把needWake置为false。之前有异步消息了的话，肯定之前已经唤醒过了，这时候就不需要再次唤醒了。

最后根据needWake的值，决定是否调用nativeWake方法唤醒next()方法。

### 同步屏障和异步消息是怎么实现的？

在Handler机制中，有3种消息类型：

1. **同步消息**。也就是普通的消息
2. **异步消息**，通过setAsynchronous(true)设置的消息
3. **同步屏障消息**。通过postSyncBarrier方法添加的消息，特点是target为空，也就是没有对应的Handler

这三者的关系如何？

- 正常情况下，同步消息和异步消息都是正常被处理，也就是根据时间来取消息，处理消息
- 当遇到同步屏障消息的时候，就开始从消息队列中去找异步消息，找到了再根据时间决定阻塞还是返回消息

```java
//MessageQueue.java
Message msg = mMessages;
if (msg != null && msg.target == null) {
      do {
      prevMsg = msg;
      msg = msg.next;
      } while (msg != null && !msg.isAsynchronous());
}
```

也就是说同步屏障消息不会被返回，它只是一个标志，一个工具，遇到它就代表要先行处理异步消息了。所以同步屏障和异步消息的存在意义就是让有些消息可以被“**加急处理**”。比如屏幕绘制。

### 同步屏障和异步消息有具体的使用场景吗？

**一个经典的场景是保证VSync信号到来后立即执行绘制，而不是要等前面的同步消息**。

### 如果MessageQueue里面没有Message，那么Looper会阻塞，相当于主线程阻塞，那么点击事件是怎么传入到主线程的呢？

### 如果MessageQueue里面没有Message，那么Looper会阻塞，相当于主线程阻塞，那么广播事件怎么传入主线程？

### 参考资料

- https://juejin.cn/post/6943048240291905549?utm_source=gold_browser_extension
- https://blog.csdn.net/qq_38366777/article/details/108942036
- Android 消息处理以及epoll机制 https://www.jianshu.com/p/97e6e6c981b6
- TODO  我读过的最好的epoll讲解--转自”知乎“  https://blog.51cto.com/yaocoder/888374
