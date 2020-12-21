
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

现在是达到是双向通信的目的.

## 3. 原理
## 资料

- [绑定服务概览](https://developer.android.com/guide/components/bound-services?hl=zh-cn#kotlin)
