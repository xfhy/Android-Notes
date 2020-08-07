
## 1. 前言

安卓在子线程中不能更新UI,所以大部分情况下,我们需要借助Handler切换到主线程中去更新消息.而消息机制(即Handler那一坨)在安卓中的地位非常非常重要,我们需要详细了解其原理.这一块,学过很多次,但是,我觉得还是再学亿次,写成博客输出.希望对大家有所帮助,有一些新的感悟.

## 2. ThreadLocal工作原理

ThreadLocal主要是可以在不同的线程中存储不同的数据,它是将数据存储在线程内部的,其他线程无法访问.对于同一个ThreadLocal对象,不同的线程有不同的数据,这些数据互不干扰.比如Handler机制中的Looper,Looper的作用域是线程,ThreadLocal可以将Looper存储在线程中,然后其他线程是无法访问到这个线程中的Looper的,只供当前线程自己内部使用.

### 2.1 ThreadLocal demo

下面简单举个例子:

```java
public class MainActivity extends AppCompatActivity {

    private static final String TAG = "MainActivity";
    private static final ThreadLocal<Integer> INTEGER_THREAD_LOCAL = new ThreadLocal<>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        
        //设置ThreadLocal里面的数据为1
        INTEGER_THREAD_LOCAL.set(1);
        //获取ThreadLocal里面的数据
        Log.w(TAG, "主线程" + INTEGER_THREAD_LOCAL.get());

        new Thread(new Runnable() {
            @Override
            public void run() {
                //获取ThreadLocal里面的数据,但是需要注意的是,这里获取的数据是子线程中数据,因为没有进行初始化,这里获取到的数据是null
                Log.w(TAG, "线程1 " + INTEGER_THREAD_LOCAL.get());
            }
        }, "线程1").start();

    }
}
```

我先在主线程中将`INTEGER_THREAD_LOCAL`的值设置为1(相当于主线程中的`INTEGER_THREAD_LOCAL`值为1),然后再开启子线程并在子线程中获取`INTEGER_THREAD_LOCAL`的值.因为子线程中没有给`INTEGER_THREAD_LOCAL`附值,所以是null.

```
2019-05-19 11:12:54.353 12364-12364/com.xfhy.handlerdemo W/MainActivity: 主线程1
2019-05-19 11:12:54.353 12364-12383/com.xfhy.handlerdemo W/MainActivity: 线程1 null
```

需要注意到的是`INTEGER_THREAD_LOCAL`是`final static`的,这里的ThreadLocal是同一个对象,但是在主线程中获取到的数据和在子线程中获取到的数据却不一样. 这里的demo也就证明了: ThreadLocal在不同的线程中存储的数据,互不干扰,相互独立.

### 2.2 ThreadLocal源码理解

我们从ThreadLocal的set方法开始深入下去(一般读源码是从使用处的API开始,这样会更轻松地理清思路)

```java
public void set(T value) {
    //1. 获取当前线程
    Thread t = Thread.currentThread();
    //2. 获取当前线程的threadLocals属性,threadLocals是Thread类里面的一个属性,是ThreadLocalMap类型的,专门用来存当前线程的私有数据,这些数据由ThreadLocal维护
    ThreadLocalMap map = getMap(t);
    
    //3. 第一次设置值的时候map肯定是为null的,初始化了之后map才不为null
    //第一次会去createMap()
    if (map != null)
        //4. 将当前ThreadLocal对象和value的值存入map中
        map.set(this, value);
    else
        //4. 这里将初始化map,并且将value值放到map中.
        createMap(t, value);
}

ThreadLocalMap getMap(Thread t) {
    return t.threadLocals;
}

```

ThreadLocal在设置数据的时候,首先是获取当前线程的threadLocals属性,threadLocals是Thread类里面的一个属性,是ThreadLocalMap类型的,专门用来存当前线程的私有数据,这些数据由ThreadLocal来维护的. 当第一次设置值的时候,需要初始化map,并将value值放入map中.下面来看一下这部分代码

```java
void createMap(Thread t, T firstValue) {
    t.threadLocals = new ThreadLocalMap(this, firstValue);
}
```

```java
//下面是ThreadLocalMap的代码

/**
 * The table, resized as necessary.
 * table.length MUST always be a power of two.
 * table是ThreadLocalMap里面存储数据的地方,如果在数组长度不够用的时候,会扩容.
 存储的方式是靠hash值为数组的索引,将value放到该索引处.
 */
private Entry[] table;

ThreadLocalMap(ThreadLocal<?> firstKey, Object firstValue) {
    //初始化table数据数组
    table = new Entry[INITIAL_CAPACITY];
    //计算hash值->存储数据的索引
    int i = firstKey.threadLocalHashCode & (INITIAL_CAPACITY - 1);
    table[i] = new Entry(firstKey, firstValue);
    size = 1;
    setThreshold(INITIAL_CAPACITY);
}

//将value值存入map中,key为ThreadLocal
private void set(ThreadLocal<?> key, Object value) {
    // We don't use a fast path as with get() because it is at
    // least as common to use set() to create new entries as
    // it is to replace existing ones, in which case, a fast
    // path would fail more often than not.

    Entry[] tab = table;
    int len = tab.length;
    int i = key.threadLocalHashCode & (len-1);

    for (Entry e = tab[i];
         e != null;
         e = tab[i = nextIndex(i, len)]) {
        ThreadLocal<?> k = e.get();

        if (k == key) {
            e.value = value;
            return;
        }

        if (k == null) {
            replaceStaleEntry(key, value, i);
            return;
        }
    }

    tab[i] = new Entry(key, value);
    int sz = ++size;
    if (!cleanSomeSlots(i, sz) && sz >= threshold)
        rehash();
}
```

可以看到createMap方法中就是初始化ThreadLocalMap,而ThreadLocalMap的底部其实是一个数组,它是利用hash值来计算索引,然后存储数据到该索引处的方式.

此处需要注意的是,我们可以看到ThreadLocal是将数据存储到Thread的一个threadLocals属性上面,这个threadLocals每个线程独有的,那么存储数据肯定互不干扰啊,完美.

## 3. MessageQueue 消息队列

Handler中的消息队列,也就是MessageQueue.从名字可以看出这是一个队列,但是它的底层却是单链表结构.因为链表结构比较适合插入和删除操作.这个MessageQueue的查询就是next()方法,它的查询伴随着删除.

### 3.1 消息队列插入

消息队列的插入,对应着的是enqueueMessage方法

```java
boolean enqueueMessage(Message msg, long when) {
    if (msg.target == null) {
        throw new IllegalArgumentException("Message must have a target.");
    }
    if (msg.isInUse()) {
        throw new IllegalStateException(msg + " This message is already in use.");
    }

    synchronized (this) {
        ....

        msg.markInUse();
        msg.when = when;
        Message p = mMessages;
        boolean needWake;
        
        //如果  1. 链表为空 || 2. when是0,表示立即需要处理的消息 || 3. 当前需要插入的消息比之前的第一个消息更紧急,在更短的时间内就需要处理
        //满足上面这3个条件中的其中一个,那么就是插入在链表的头部
        if (p == null || when == 0 || when < p.when) {
            // New head, wake up the event queue if blocked.
            msg.next = p;
            mMessages = msg;
            needWake = mBlocked;
        } else {
            // Inserted within the middle of the queue.  Usually we don't have to wake
            // up the event queue unless there is a barrier at the head of the queue
            // and the message is the earliest asynchronous message in the queue.
            needWake = mBlocked && p.target == null && msg.isAsynchronous();
            Message prev;
            //从头部开始,直到找出列表的最后一个元素,方便链表插入
            for (;;) {
                prev = p;
                p = p.next;
                //找到合适的时间点,插入到这里
                if (p == null || when < p.when) {
                    break;
                }
                if (needWake && p.isAsynchronous()) {
                    needWake = false;
                }
            }
            //把新的消息插入在链表尾部
            msg.next = p; // invariant: p == prev.next
            prev.next = msg;
        }

        // We can assume mPtr != 0 because mQuitting is false.
        if (needWake) {
            // 激活消息队列去获取下一个消息  这里是一个native方法
            nativeWake(mPtr);
        }
    }
    return true;
}
```

核心内容为消息列表的插入,也就是链表的插入,插入数据的时候是有一定规则的,当满足下面这3个条件中的其中一个,那么就是插入在链表的头部

 1. 链表为空
 2. when是0,表示立即需要处理的消息
 3. 当前需要插入的消息比之前的第一个消息更紧急,在更短的时间内就需要处理

其他情况则是插入在链表中的合适的位置,找到一个合适的时间点.

### 3.2 消息队列查询(next)

MessageQueue的next方法,也就是获取下一个消息,这个方法可能会阻塞,当消息队列没有消息的时候.直到有消息,然后就会被唤醒,然后继续取消息.

但是这里的阻塞是不会ANR的,真正导致ANR的是因为在handleMessage方法中处理消息时阻塞了主线程太久的时间.这里的原因,后面再解释.

```java
Message next() {
    // Return here if the message loop has already quit and been disposed.
    // This can happen if the application tries to restart a looper after quit
    // which is not supported.
    final long ptr = mPtr;
    if (ptr == 0) {
        return null;
    }

    int pendingIdleHandlerCount = -1; // -1 only during first iteration
    int nextPollTimeoutMillis = 0;
    for (;;) {
        if (nextPollTimeoutMillis != 0) {
            Binder.flushPendingCommands();
        }

        //当消息队列为空时,这里会导致阻塞,直到有消息加入消息队列,才会恢复
        //这里是native方法,利用的是linux的epoll机制阻塞
        nativePollOnce(ptr, nextPollTimeoutMillis);

        synchronized (this) {
            // Try to retrieve the next message.  Return if found.
            final long now = SystemClock.uptimeMillis();
            Message prevMsg = null;
            Message msg = mMessages;
            if (msg != null && msg.target == null) {
                // Stalled by a barrier.  Find the next asynchronous message in the queue.
                do {
                    prevMsg = msg;
                    msg = msg.next;
                } while (msg != null && !msg.isAsynchronous());
            }
            if (msg != null) {
                if (now < msg.when) {
                    // Next message is not ready.  Set a timeout to wake up when it is ready.
                    nextPollTimeoutMillis = (int) Math.min(msg.when - now, Integer.MAX_VALUE);
                } else {
                    //这里比较关键  取链表头部,获取这个消息
                    // Got a message.
                    mBlocked = false;
                    if (prevMsg != null) {
                        prevMsg.next = msg.next;
                    } else {
                        mMessages = msg.next;
                    }
                    msg.next = null;
                    if (DEBUG) Log.v(TAG, "Returning message: " + msg);
                    msg.markInUse();
                    return msg;
                }
            } else {
                // No more messages.
                nextPollTimeoutMillis = -1;
            }

            .....
        }

       ......
    }
}
```

核心内容就是取消息队列的第一个元素(即链表的第一个元素),然后将该Message取出来之后,将它从消息队列中删除.

## 4. Looper

Looper在消息机制中主要扮演着消息循环的角色,有消息来了,Looper就取出来,分发.没有消息,Looper就阻塞在那里,直到有消息为止.

### 4.1 Looper初始化

先来看一下,Looper的构造方法

```java
private Looper(boolean quitAllowed) {
    mQueue = new MessageQueue(quitAllowed);
    mThread = Thread.currentThread();
}
```

这个构造方法是私有化的,只能在内部调用,直接在里面初始化了MessageQueue和获取当前线程.构造方法只会在prepare方法中被调用.

```java
public static void prepare() {
    prepare(true);
}

//sThreadLocal是用`static final`修饰的,意味着sThreadLocal只有一个,但是它却可以在不同的线程中存储不同的Looper,妙啊
static final ThreadLocal<Looper> sThreadLocal = new ThreadLocal<Looper>();

private static void prepare(boolean quitAllowed) {
    //如果说当前线程之前初始化过ThreadLocal,里面有Looper,那么就报错
    //意思就是prepare方法只能调用一次
    if (sThreadLocal.get() != null) {
        throw new RuntimeException("Only one Looper may be created per thread");
    }
    //初始化ThreadLocal,将一个Looper存入其中
    sThreadLocal.set(new Looper(quitAllowed));
}

private static Looper sMainLooper;
//这个方法是主线程中调用的,准备主线程的Looper.也是只能调用一次.
public static void prepareMainLooper() {
    //先准备一下
    prepare(false);
    synchronized (Looper.class) {
        if (sMainLooper != null) {
            throw new IllegalStateException("The main Looper has already been prepared.");
        }
        //将初始化之后的Looper赋值给sMainLooper,sMainLooper是static的,可能是为了方便使用吧
        sMainLooper = myLooper();
    }
}

public static @Nullable Looper myLooper() {
    return sThreadLocal.get();
}

```

prepare方法的职责是初始化ThreadLocal,将Looper存储在其中,一个线程只能有一个Looper,不能重复初始化.sThreadLocal是用`static final`修饰的,意味着sThreadLocal只有一个,但是它却可以在不同的线程中存储不同的Looper.而且官方还提供了主线程初始化Looper的专用方法prepareMainLooper.主线程就是主角,还单独把它的Looper存到静态的sMainLooper中.

### 4.2 Looper#loop

下面开始进入Looper的核心方法loop(),我们知道loop方法就是死循环不断得从MessageQueue中去取数据.看看方法中的一些细节.

```java
/**
 * Run the message queue in this thread. Be sure to call
 * {@link #quit()} to end the loop.
 */
public static void loop() {
    //1. 首先是获取当前线程的Looper  稳,不同的线程,互不干扰
    final Looper me = myLooper();
    
    //2. 如果当前线程没有初始化,那肯定是要报错的
    if (me == null) {
        throw new RuntimeException("No Looper; Looper.prepare() wasn't called on this thread.");
    }
    
    //3. 取出当前线程Looper中存放的MessageQueue
    final MessageQueue queue = me.mQueue;

    .....
    for (;;) {
        //4. 从MessageQueue中取消息,当然 这里是可能被阻塞的,如果MessageQueue中没有消息可以取的话
        Message msg = queue.next(); // might block
        
        //5. 如果消息队列想退出,并且MessageQueue中没有消息了,那么这里的msg肯定是null
        if (msg == null) {
            // No message indicates that the message queue is quitting.
            return;
        }

        .....
        //6. 注意啦,这里开始分发当前从消息队列中取出来的消息
        msg.target.dispatchMessage(msg);
        ......
    }
}
```

loop方法非常重要,它首先取到当前线程的Looper,再从Looper中获取MessageQueue,开启一个死循环,从MessageQueue的next方法中获取新的Message.但是在next方法调用的过程中是可能被阻塞的,这里是利用了linux的epoll机制.取到了消息之后分发下去.分发给Handler的handleMessage方法进行处理. 然后又开始了一个新的轮回,继续取新的消息(也可能是阻塞在那里等).

下面来看一下消息的分发

```java
//Message里面的代码

//Message里的target其实就是发送该消息的那个Handler,666
Handler target;
//下一个消息的引用
Message next;
```

```java
//Handler里面的代码
public void dispatchMessage(Message msg) {
    if (msg.callback != null) {
        handleCallback(msg);
    } else {
        if (mCallback != null) {
            if (mCallback.handleMessage(msg)) {
                return;
            }
        }
        handleMessage(msg);
    }
}
```

兄弟萌,它来啦,还是那个熟悉的handleMessage方法,在Looper的loop方法中由Message自己通过Message里面的target(handler)调用该Handler自己的handleMessage方法.完成了消息的分发.  如果这里有Callback的话,就通过Callback接口分发消息.

## 5. Handler

Handler的作用其实就是发送消息,然后接收消息.Handler中任何的发送消息的方法最后都会调用sendMessageAtTime方法,我们仔细观摩一下

```java
public boolean sendMessageAtTime(Message msg, long uptimeMillis) {
    MessageQueue queue = mQueue;
    if (queue == null) {
        RuntimeException e = new RuntimeException(
                this + " sendMessageAtTime() called with no mQueue");
        Log.w("Looper", e.getMessage(), e);
        return false;
    }
    return enqueueMessage(queue, msg, uptimeMillis);
}
private boolean enqueueMessage(MessageQueue queue, Message msg, long uptimeMillis) {
    msg.target = this;
    if (mAsynchronous) {
        msg.setAsynchronous(true);
    }
    return queue.enqueueMessage(msg, uptimeMillis);
}
```

sendMessageAtTime方法很简单,其实就是将消息插入MessageQueue.而在Message插入MessageQueue的过程之前,先将Handler的引用存入Message中,方便待会儿分发消息事件,机智机智!

## 6. 用一句话总结一下安卓的消息机制

在安卓消息机制中,ThreadLocal拿来存储Looper,而MessageQueue是存储在Looper中的.所以我们可以在子线程中通过主线程的Handler发送消息,而Looper(主线程中的)在主线程中取出消息,分发给主线程的Handler的handleMessage方法.

## 7. 消息机制在主线程中的应用

### 7.1 关于主线程中的死循环

我们知道ActivityThread其实就是我们的主线程,首先我们来看一段代码,ActivityThread的main方法:

```java
public static void main(String[] args) {
    ......
    
    //注意看,在main方法的开始,在主线程中就准备好了主线程中的Looper,存入ThreadLocal中.所以我们平时使用Handler的时候并没有调用prepare方法也不会报错
    Looper.prepareMainLooper();

    ......
    //直接在主线程中调用了loop方法,并且陷入死循环中,不断地取消息,不断地处理消息,无消息时就阻塞.  
    //嘿,你还别说,这里这个方法还必须要死循环下去才好,不然就会执行到下面的throw new RuntimeException语句报出错误
    Looper.loop();

    throw new RuntimeException("Main thread loop unexpectedly exited");
}
```

主线程一直处在一个Looper的loop循环中,有消息就会去处理.无消息,则阻塞.

### 7.2 主线程死循环到底是要接收和处理什么消息?

有什么骚东西非要进行死循环才能处理呢?首先我们想想,既然ActivityThread开启了Looper的loop,那么肯定有Handler来接收和处理消息,我们一探究竟:

```java
private class H extends Handler {
    public static final int LAUNCH_ACTIVITY = 100;
    public static final int PAUSE_ACTIVITY = 101;
    public static final int PAUSE_ACTIVITY_FINISHING = 102;
    public static final int STOP_ACTIVITY_SHOW = 103;
    public static final int STOP_ACTIVITY_HIDE = 104;
    public static final int SHOW_WINDOW = 105;
    public static final int HIDE_WINDOW = 106;
    public static final int RESUME_ACTIVITY = 107;
    public static final int SEND_RESULT = 108;
    public static final int DESTROY_ACTIVITY = 109;
    public static final int BIND_APPLICATION = 110;
    public static final int EXIT_APPLICATION = 111;
    public static final int NEW_INTENT = 112;
    public static final int RECEIVER = 113;
    public static final int CREATE_SERVICE = 114;
    public static final int SERVICE_ARGS = 115;
    public static final int STOP_SERVICE = 116;
    ...
}
```

名场面,上面就是API 28以前ActivityThread.H的老样子,为什么是API 28以前?因为在API 28中重构了H类，把100到109这10个用于Activity的消息，都合并为159这个消息，消息名为EXECUTE_TRANSACTION(抽象为ClientTransactionItem,有兴趣了解的看[这里](https://www.cnblogs.com/Jax/p/9521305.html))。

在H类中定义了很多消息类型,包含了安卓四大组件的启动和停止.ActivityThread通过ApplicationThread与AMS进行进程间通信,AMS完成ActivityThread的请求后会回调ApplicationThread中的Binder方法,然后ApplicationThread会向H发送消息,H收到消息就开始在主线程中执行,开始执行诸如Activity的启动停止等动作,以上就是主线程的消息循环模型.

既然我们知道了主线程是这样启动Activity的,那么我们是不是可以搞点骚操作???俗称黑科技的插件化:我们Hook掉H类的mCallback对象,拦截这个对象的handleMessage方法。在此之前，我们把插件中的Activity替换为StubActtivty，那么现在，我们拦截到handleMessage方法，再把StubActivity换回为插件中的Activity.当前这只是API 28之前的操作,更多详情请看[这里](https://www.cnblogs.com/Jax/p/9521305.html)

## 8. 主线程为什么没有被loop阻塞

既然主线程中的main方法内调用了Looper的loop方法不断地死循环取消息,而且当消息队列为空的时候还会被阻塞.那为什么主线程中当没有消息的时候怎么不卡呢?

此处引出一国外网友的回答,短小精湛.[问题回答原地址](https://stackoverflow.com/questions/38818642/android-what-is-message-queue-native-poll-once-in-android)

简短版答案:
nativePollOnce方法是用来等待下一个消息可用时的,下一个消息可用则不会再继续阻塞,如果在这个调用中花费的时间很长，那你的主(UI)线程没有真正的工作要做，并且等待下一个事件处理。没必要担心阻塞问题。

完整版的答案:
因为主线程负责绘制UI和处理各种事件，所以Runnable有一个处理所有这些事件的循环。循环由Looper管理，其工作非常简单：它处理MessageQueue中的所有消息。消息被添加到队列中，例如响应输入事件，帧渲染回调甚至您自己的Handler.post调用。有时主线程没有工作要做（即队列中没有消息），这可能发生在例如刚完成渲染单帧后（线程刚刚绘制了一帧并准备好下一帧，只需等待一段时间）。 MessageQueue类中的两个Java方法对我们来说很有趣：Message next（）和boolean enqueueMessage（Message，long）。消息next（），顾名思义，接收并返回队列中的下一条消息。如果队列为空（并且没有任何内容可以返回），则该方法调用native void nativePollOnce（long，int），该块将阻塞，直到添加新消息。此时你可能会问nativePollOnce如何知道何时醒来。这是一个非常好的问题。将Message添加到队列时，框架会调用enqueueMessage方法，该方法不仅会将消息插入队列，还会调用native static void nativeWake（long），如果需要唤醒队列的话。 nativePollOnce和nativeWake的核心魔力发生在native（实际上是C ++）代码中。 Native MessageQueue使用名为epoll的Linux系统调用，该调用允许监视IO事件的文件描述符。 nativePollOnce在某个文件描述符上调用`epoll_wait`，而nativeWake写入描述符，这是IO操作之一，`epoll_wait`等待。然后内核从等待状态中取出epoll等待线程，并且线程继续处理新消息。如果您熟悉Java的Object.wait（）和Object.notify（）方法，您可以想象nativePollOnce是Object.wait（）和NativeWake for Object.notify（）的粗略等价物，因为它们的实现完全不同：nativePollOnce使用epoll，Object.wait（）使用futex Linux调用。值得注意的是，nativePollOnce和Object.wait（）都不会浪费CPU周期，因为当线程进入任一方法时，它会因线程调度而被禁用。如果这些方法实际上浪费了CPU周期，那么所有空闲应用程序将使用100％的CPU，加热并降低设备的速度。

翻译的不是很好,英语好的同学还是看原版吧,,,,,,,,,