
## 1. 概念

Messenger,即进程间通信的信使.它是基于Message的进程间通信,我们可以像在线程间利用Handler.send(Message)一样.

Messenger是一种轻量级的IPC方案,它的底层实现其实就是AIDL.跨进程通信使用Messenger时,Messenger会将所有服务调用加入队列,然后服务端那边一次处理一个调用,不会存在同时调用的情况.而AIDL则可能是多个调用同时执行,必须处理多线程问题.

对于大多数应用,跨进程通信无需一对多,也就是无需执行多线程处理,此时使用Messenger更适合.

## 2. 使用

### 2.1 大致流程

1. 服务端实现一个Handler,由其接收来自客户端的每个调用的回调
2. 服务端使用Handler来创建Messenger对象
3. Messenger创建一个IBinder,服务端通过onBind()将其返回给客户端
4. 客户端使用IBinder将Messenger实例化,然后再用起将Message对象发送给服务端
5. 服务端在其Handler#handleMessage()中,接收每个Message

### 2.2 案例

#### 2.2.1 服务端

首先需要在服务端创建一个Handler用于接收消息,然后将此Handler传递给Messenger,并在onBind中将该Messenger的底层binder返回回去.

```kotlin
//这里服务端Service是运行在单独的进程中的 android:process=":other"
class MessengerService : Service() {

    private lateinit var mMessenger: Messenger

    override fun onBind(intent: Intent): IBinder {
        log(TAG, "onBind~")
        //传入Handler实例化Messenger
        mMessenger = Messenger(IncomingHandler(this))
        //将Messenger中的binder返回给客户端,让它可以远程调用
        return mMessenger.binder
    }

    //处理客户端传递过来的消息(Message)  并根据what决定下一步操作
    internal class IncomingHandler(
        context: Context,
        private val applicationContext: Context = context.applicationContext
    ) : Handler(
        Looper.getMainLooper()
    ) {
        override fun handleMessage(msg: Message) {
            when (msg.what) {
                MSG_SAY_HELLO -> {
                    Toast.makeText(applicationContext, "hello!", Toast.LENGTH_SHORT).show()
                    log(TAG, "hello!")
                }
                else -> super.handleMessage(msg)
            }
        }
    }
}
```

#### 2.2.2 客户端

客户端进程中,首先是需要绑定远程Service.绑定完成之后,在`onServiceConnected()`中拿到远程Service返回的IBinder对象,用此IBinder对象实例化客户端这边的Messenger.有了这个Messenger,就可以通过这个Messenger往服务端发送消息了.示例代码如下:

```kotlin
class MessengerActivity : TitleBarActivity() {

    /** 与服务端进行沟通的Messenger */
    private var mService: Messenger? = null

    /** 是否已bindService */
    private var bound: Boolean = false

    private val mServiceConnection = object : ServiceConnection {

        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            mService = Messenger(service)
            bound = true
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            mService = null
            bound = false
        }
    }

    override fun getThisTitle(): CharSequence {
        return "Messenger"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_messenger)

        btnConnect.setOnClickListener {
            connectService()
        }
        btnSayHello.setOnClickListener {
            sayHello()
        }
    }

    private fun sayHello() {
        if (!bound) {
            return
        }
        //创建,并且发送一个message给服务端   Message中what指定为MSG_SAY_HELLO
        val message = Message.obtain(null, MSG_SAY_HELLO, 0, 0)
        try {
            mService?.send(message)
        } catch (e: RemoteException) {
            e.printStackTrace()
        }
    }

    private fun connectService() {
        Intent().apply {
            action = "com.xfhy.messenger.Server.Action"
            setPackage("com.xfhy.allinone")
        }.also { intent ->
            bindService(intent, mServiceConnection, Context.BIND_AUTO_CREATE)
        }
    }

    override fun onStop() {
        super.onStop()
        if (bound) {
            unbindService(mServiceConnection)
            bound = false
        }
    }

}
```

通过示例代码我们知道客户端通过Messenger与服务端进行通信时,必须将数据放入Message中,Messenger和Message都实现了Parcelable接口,因此是可以跨进程传输的.Message只能通过what、arg1、arg2、Bundle以及replyTo来承载需要传递的数据,如果需要传递Serializable或者Parcelable的对象则可以放进Bundle里面进行传递,Bundle还支持其他大量的数据类型.

#### 2.2.3 服务端向客户端发送消息

有时候我们需要客户端能响应服务端发送的消息,此时我们只需要在上面的示例的基础上简单修改即可. 

服务端这边每次收到消息,都回复一条消息给客户端,方便测试

```kotlin
internal class IncomingHandler : Handler(Looper.getMainLooper()) {
        override fun handleMessage(msg: Message) {
            when (msg.what) {
                MSG_SAY_HELLO -> {
                    log(TAG, "hello!")
                    //客户端的Messenger就是放在Message的replyTo中的
                    replyToClient(msg, "I have received your message and will reply to you later")
                }
                MSG_TRANSFER_SERIALIZABLE -> log(TAG, "传递过来的对象:  ${msg.data?.get("person")}")
                else -> super.handleMessage(msg)
            }
        }

        private fun replyToClient(msg: Message, replyText: String) {
            val clientMessenger = msg.replyTo
            val replyMessage = Message.obtain(null, MSG_FROM_SERVICE)
            replyMessage.data = Bundle().apply {
                putString("reply", replyText)
            }
            try {
                clientMessenger?.send(replyMessage)
            } catch (e: RemoteException) {
                e.printStackTrace()
            }
        }
    }
```

而客户端这边需要做出响应,则还需在客户端创建一个Messenger,并为其创建一个Handler用于接收服务端传递过来的消息.在客户端发送消息时,需要将`Message#replyTo`设置为客户端的Messenger. 服务端拿到这个Messanger才能回复消息.

```kotlin

/** 客户端这边的Messenger */
private var mClientMessenger = Messenger(IncomingHandler())

class IncomingHandler : Handler(Looper.getMainLooper()) {
    override fun handleMessage(msg: Message) {
        when (msg.what) {
            MSG_FROM_SERVICE -> {
                log(TAG, "Received from service: ${msg.data?.getString("reply")}")
            }
            else -> super.handleMessage(msg)
        }
    }
}

private fun sayHello() {
    if (!bound) {
        return
    }
    //创建,并且发送一个message给服务端   Message中what指定为MSG_SAY_HELLO
    val message = Message.obtain(null, MSG_SAY_HELLO, 0, 0)
    //注意 这里是新增的
    message.replyTo = mClientMessenger
    message.data = Bundle().apply {
        putSerializable("person", SerializablePerson("张三"))
    }
    try {
        mService?.send(message)
    } catch (e: RemoteException) {
        e.printStackTrace()
    }
}
```

服务端调用`sayHello()`之后,输出日志如下:

```
2020-12-31 11:59:40.420 29702-29702/com.xfhy.allinone D/xfhy_messenger: hello!
2020-12-31 11:59:40.421 29649-29649/com.xfhy.allinone D/xfhy_messenger: Received from service: I have received your message and will reply to you later
```

日志里面明显看到是2个进程,所以现在是达到是双向通信的目的.Messenger的使用大概就是这些了,下面是Messenger的大致工作原理图

//todo xfhy 插图 Messenger的工作原理 Android开发艺术探索(P93)

## 3. 原理

### 3.1 客户端->服务端通信

> frameworks/base/core/java/android/os/IMessenger.aidl

```
1. onBind()->mMessenger.getBinder()->MessengerImpl 它的send方法其实就是往外部类Handler发送一个Message. 
2. 客户端再利用服务端的binder对象(IMessenger.Stub.asInterface(target)->MessengerImpl)send发送消息时,发生跨进程通信,最后相当于调用的服务端的MessengerImpl#send,然后调用了服务端的Handler#sendMessage,然后服务端这边定义的Handler就收到消息了.
```

**服务端**

当客户端到服务端单向通信时,我们来看一下大致的原理.首先是服务端这边在onBind方法中返回了Messenger的binder对象

```kotlin
override fun onBind(intent: Intent): IBinder {
    //传入Handler实例化Messenger
    mMessenger = Messenger(IncomingHandler())
    //将Messenger中的binder返回给客户端,让它可以远程调用
    return mMessenger.binder
}
```

我们看下Messenger里面的binder是什么:

```java
private final IMessenger mTarget;

public Messenger(Handler target) {
    mTarget = target.getIMessenger();
}

public Messenger(IBinder target) {
    mTarget = IMessenger.Stub.asInterface(target);
}

public void send(Message message) throws RemoteException {
    mTarget.send(message);
}

public IBinder getBinder() {
    return mTarget.asBinder();
}
```

从Messenger的构造方法(`IMessenger.Stub.asInterface()`)可以看出它底层应该是使用的AIDL搞的.getBinder()其实是将调用了`mTarget.asBinder()`,而mTarget是我们传进来的Handler里面拿出来的,跟进`Handler.getIMessenger()`看一下:

```java
final IMessenger getIMessenger() {
    synchronized (mQueue) {
        if (mMessenger != null) {
            return mMessenger;
        }
        mMessenger = new MessengerImpl();
        return mMessenger;
    }
}

private final class MessengerImpl extends IMessenger.Stub {
    public void send(Message msg) {
        msg.sendingUid = Binder.getCallingUid();
        Handler.this.sendMessage(msg);
    }
}
```

原来IMessenger是Handler的内部类MessengerImpl,它只有一个send方法.结合上面Messenger的源码,我们发现调用Messenger的send方法其实就是调用这里的MessengerImpl的send方法,然后这个send里面将Message转发给`Handler#sendMessage()`,最后也就是去了`Handler#handleMessage()`里面接收到这个Message.

MessengerImpl是继承自`IMessenger.Stub`,这一看就感觉是AIDL文件自动生成的嘛,easy.大胆猜测一下对应的aidl文件应该是`IMessenger.aidl`,我们去源码里面找`IMessenger.aidl`,果然在`frameworks/base/core/java/android/os/IMessenger.aidl`这个位置找到了它.内容如下:

```java
package android.os;

import android.os.Message;

/** @hide */
oneway interface IMessenger {
    void send(in Message msg);
}
```

根据aidl文件,它自动生成的`IMessenger.java`应该长下面这样:

```java
package android.os;

public interface IMessenger extends android.os.IInterface {
    /**
     * Local-side IPC implementation stub class.
     */
    public static abstract class Stub extends android.os.Binder implements IMessenger {
        private static final java.lang.String DESCRIPTOR = "android.os.IMessenger";

        /**
         * Construct the stub at attach it to the interface.
         */
        public Stub() {
            this.attachInterface(this, DESCRIPTOR);
        }

        /**
         * Cast an IBinder object into an android.os.IMessenger interface,
         * generating a proxy if needed.
         */
        public static IMessenger asInterface(android.os.IBinder obj) {
            if ((obj == null)) {
                return null;
            }
            android.os.IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
            if (((iin != null) && (iin instanceof IMessenger))) {
                return ((IMessenger) iin);
            }
            return new IMessenger.Stub.Proxy(obj);
        }

        @Override
        public android.os.IBinder asBinder() {
            return this;
        }

        @Override
        public boolean onTransact(int code, android.os.Parcel data, android.os.Parcel reply, int flags) throws android.os.RemoteException {
            java.lang.String descriptor = DESCRIPTOR;
            switch (code) {
                case INTERFACE_TRANSACTION: {
                    reply.writeString(descriptor);
                    return true;
                }
                case TRANSACTION_send: {
                    data.enforceInterface(descriptor);
                    android.os.Message _arg0;
                    if ((0 != data.readInt())) {
                        _arg0 = android.os.Message.CREATOR.createFromParcel(data);
                    } else {
                        _arg0 = null;
                    }
                    this.send(_arg0);
                    return true;
                }
                default: {
                    return super.onTransact(code, data, reply, flags);
                }
            }
        }

        private static class Proxy implements IMessenger {
            private android.os.IBinder mRemote;

            Proxy(android.os.IBinder remote) {
                mRemote = remote;
            }

            @Override
            public android.os.IBinder asBinder() {
                return mRemote;
            }

            public java.lang.String getInterfaceDescriptor() {
                return DESCRIPTOR;
            }

            @Override
            public void send(android.os.Message msg) throws android.os.RemoteException {
                android.os.Parcel _data = android.os.Parcel.obtain();
                try {
                    _data.writeInterfaceToken(DESCRIPTOR);
                    if ((msg != null)) {
                        _data.writeInt(1);
                        msg.writeToParcel(_data, 0);
                    } else {
                        _data.writeInt(0);
                    }
                    mRemote.transact(Stub.TRANSACTION_send, _data, null, android.os.IBinder.FLAG_ONEWAY);
                } finally {
                    _data.recycle();
                }
            }
        }

        static final int TRANSACTION_send = (android.os.IBinder.FIRST_CALL_TRANSACTION + 0);
    }

    public void send(android.os.Message msg) throws android.os.RemoteException;
}
```

这就好办了,这就明摆着说明Messenger底层是基于AIDL实现的.服务端这边这条线: `Service#onBind()->mMessenger.getBinder()->Handler#getIMessenger()->MessengerImpl(IMessenger.Stub)`,其实就是和我们使用AIDL一样将IXXX.Stub的子类通过onBind返回回去,客户端绑定的时候好拿到binder对象.接收客户端的消息时,是通过MessengerImpl转发给Handler来完成的,服务端这边定义的那个Handler就可以在`handleMessage()`中处理跨进程传递过来的Message,从而理解客户端想要调用什么服务,然后执行相应的逻辑.

**客户端**

再看客户端这边,在`onServiceConnected()`时,将服务端返回的IBinder对象放进Messenger里.
```kotlin
//MessengerActivity.kt
private val mServiceConnection = object : ServiceConnection {

    override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
        mService = Messenger(service)
        bound = true
    }

    override fun onServiceDisconnected(name: ComponentName?) {
        mService = null
        bound = false
    }
}

//Messenger.java
public void send(Message message) throws RemoteException {
    mTarget.send(message);
}
public Messenger(IBinder target) {
            //这里asInterface 出来的其实就是 IMessenger.Stub.Proxy对象
    mTarget = IMessenger.Stub.asInterface(target);
}
```

IBinder对象放进Messenger原来就是熟悉的操作`IMessenger.Stub.asInterface()`,简单.然后客户端这边给服务端发消息的时候通过构建出来的Messenger调用send方法发送,而Messenger内部send的实现其实就是调用`IMessenger.Stub.Proxy`(跨进程了)的send方法.调用之后,服务端那边在Handler的handleMessage里收到这条消息(Message),从而实现了跨进程通信.  

### 3.2 服务端->客户端通信

客户端与服务端的通信与我们用AIDL的方式实现几乎一致,完全可以我们自己实现,Messenger只是帮我们封装好了而已.下面来看一下服务端与客户端的通信.

服务端需要与客户端通信的话,需要客户端在send消息的时候将客户端Messenger存放在消息的replyTo中.

```kotlin
private fun sayHello() {
    val message = Message.obtain(null, MSG_SAY_HELLO, 0, 0)
    //将客户方的Messenger放replyTo里
    message.replyTo = mClientMessenger
    mService?.send(message)
}
```

将消息发送到服务端时,因为是跨进程,所以肯定需要用到序列化与反序列化Message.看下Message的反序列化代码:

```java
private void readFromParcel(Parcel source) {
    what = source.readInt();
    arg1 = source.readInt();
    arg2 = source.readInt();
    if (source.readInt() != 0) {
        obj = source.readParcelable(getClass().getClassLoader());
    }
    when = source.readLong();
    data = source.readBundle();
    replyTo = Messenger.readMessengerOrNullFromParcel(source);
    sendingUid = source.readInt();
    workSourceUid = source.readInt();
}
```

主要是看一下replyTo是怎么反序列化的,它调用了Messenger的readMessengerOrNullFromParcel方法:

```java
public static void writeMessengerOrNullToParcel(Messenger messenger,
        Parcel out) {
    out.writeStrongBinder(messenger != null ? messenger.mTarget.asBinder()
            : null);
}

public static Messenger readMessengerOrNullFromParcel(Parcel in) {
    IBinder b = in.readStrongBinder();
    return b != null ? new Messenger(b) : null;
}
```

writeMessengerOrNullToParcel中将客户端的`messenger.mTarget.asBinder()`进行了写入,然后在readMessengerOrNullFromParcel时进行了恢复,而`messenger.mTarget`就是上面分析的MessengerImpl,`asBinder()`是其父类`IMessenger.Stub`里面的一个方法:

```java
@Override
public android.os.IBinder asBinder() {
    return this;
}
```

就是将自身返回出去.也就是说,服务端反序列化出来的replyTo对应Messenger中的IBinder其实就是客户端的MessengerImpl对象.于是服务端拿到这个Messenger就可以发送消息,通过这个IBinder对象跨进程通信,客户端就接收到消息了.

## 4. 小结

跨进程通信时,Messenger比AIDL更常用(满足使用条件的时候),因为用起来比较方便,而且官方也更推荐.在使用Messenger的同时,我们需要了解其原理:

- 客户端与服务端单向通信时,利用的是AIDL接口的原理,和我们平时写的方式一样
- 服务端与客户端通信时,利用客户端发送消息时Message对象需要序列化与反序列化,将客户端的binder对象封装在里面的replyTo字段中,服务端那边反序列化时再将其取出组装成Messenger.有了这个客户端的binder对象,当然也就能够与客户端进行跨进程通信了.

## 资料

- [绑定服务概览](https://developer.android.com/guide/components/bound-services?hl=zh-cn#kotlin)
- [Android 基于Message的进程间通信 Messenger完全解析](https://blog.csdn.net/lmj623565791/article/details/47017485)