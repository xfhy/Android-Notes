- [1. AIDL概念](#head1)
- [2. AIDL使用](#head2)
	- [2.1 大致流程](#head3)
	- [2.2 案例](#head4)
		- [2.2.1 定义aidl接口](#head5)
		- [2.2.2 服务端实现接口](#head6)
		- [2.2.3 客户端与服务端进行通信](#head7)
	- [2.3 in,out,inout关键字](#head8)
	- [2.4 oneway 关键字](#head9)
	- [2.5 线程安全](#head10)
	- [2.6 aidl 监听器(观察者? 双向通信?)](#head11)
	- [2.7 Binder 死亡通知](#head12)
	- [2.8 权限验证](#head13)
- [3. 原理](#head14)
	- [3.1 AIDL是怎么工作的?](#head15)
	- [3.2 详细解读](#head16)
- [ 资料](#head17)

> 文中示例代码均可在[demo](https://github.com/xfhy/AllInOne/blob/master/app/src/main/java/com/xfhy/allinone/ipc/aidl/AidlActivity.kt)中找到

## <span id="head1">1. AIDL概念</span>

Android 接口定义语言 (AIDL) 与您可能使用过的其他接口语言 (IDL) 类似.您可以利用它定义客户端与服务均认可的编程接口,以便二者使用进程间通信 (IPC) 进行相互通信.在 Android 中,一个进程通常无法访问另一个进程的内存.因此,为进行通信,进程需将其对象分解成可供操作系统理解的原语,并将其编组为可供您操作的对象.编写执行该编组操作的代码较为繁琐,因此 Android 会使用 AIDL 为您处理此问题.

跨进程通信(IPC)的方式很多,AIDL是其中一种.还有Bundle、文件共享、Messenger、ContentProvider和Socket等进程间通信的方式. AIDL是接口定义语言,只是一个工具,具体通信还是得用Binder来进行.Binder是Android独有的跨进程通信方式,只需要一次拷贝,更快速和安全.

官方推荐我们用Messenger来进行跨进程通信,但是Messenger是以串行的方式来处理客户端发来的消息,如果大量的消息同时发送到服务端,服务端仍然只能一个个处理,如果有大量的并发请求,那么用Messenger就不太合适了.这种情况就得用AIDL了.其实Messenger的底层也是AIDL,只不过系统做了层封装,简化使用.

## <span id="head2">2. AIDL使用</span>

### <span id="head3">2.1 大致流程</span>

1. 创建 .aidl 文件:此文件定义带有方法签名的编程接口.
2. 实现接口: Android SDK 工具会基于你的 .aidl 文件,使用 Java 编程语言生成接口.此接口拥有一个名为 Stub 的内部抽象类,用于扩展 Binder 类并实现 AIDL 接口中的方法.你必须扩展 Stub 类并实现这些方法.
3. 向客户端公开接口: 实现 Service 并重写 onBind(),从而返回 Stub 类的实现.

### <span id="head4">2.2 案例</span>

#### <span id="head5">2.2.1 定义aidl接口</span>

首先是定义好客户端与服务端通信的AIDL接口,在里面声明方法用于客户端调用,服务端实现.
在`src/main`下面创建aidl目录,然后新建`IPersonManager.aidl`文件

```
package com.xfhy.allinone.ipc.aidl;
import com.xfhy.allinone.ipc.aidl.Person;
interface IPersonManager {
    List<Person> getPersonList();
    //in: 从客户端流向服务端
    boolean addPerson(in Person person);
}
```
这个接口和平常我们定义接口时差别不是很大,需要注意的是即使Person和IPersonManager在同一个包下面,还是得导包,这是AIDL的规则.

**AIDL支持的数据类型**: 

而且在AIDL文件中,不是所有数据类型都是可以使用的,支持的数据类型如下:

- Java 编程语言中的所有原语类型（如 int、long、char、boolean 等）
- String和CharSequence; 
- List:只支持ArrayList,里面每个元素都必须能够被AIDL支持; 
- Map:只支持HashMap,里面的每个元素都必须被AIDL支持,包括key和value; 
- Parcelable:所有实现了Parcelable接口的对象; 
- AIDL:所有的AIDL接口本身也可以在AIDL文件中使用.

注意: 
- 当需要传递对象时,则对象必须实现Parcelable接口
- 所有非原语参数均需要指示数据走向的方向标记.这类标记可以是 in、out 或 inout.
    - in : 客户端流向服务端
    - out : 服务端流向客户端
    - inout : 双向流通
- 原语默认是in,这里应该考虑一下是用什么原语标记,因为如果是inout的话开销其实蛮大的.

**定义传输的对象**:

在kotlin这边需要定义好这个需要传输的对象Person

```kotlin
class Person(var name: String? = "") : Parcelable {
    constructor(parcel: Parcel) : this(parcel.readString())

    override fun toString(): String {
        return "Person(name=$name) hashcode = ${hashCode()}"
    }

    override fun writeToParcel(parcel: Parcel, flags: Int) {
        parcel.writeString(name)
    }

    fun readFromParcel(parcel: Parcel) {
        this.name = parcel.readString()
    }

    override fun describeContents(): Int {
        return 0
    }

    companion object CREATOR : Parcelable.Creator<Person> {
        override fun createFromParcel(parcel: Parcel): Person {
            return Person(parcel)
        }

        override fun newArray(size: Int): Array<Person?> {
            return arrayOfNulls(size)
        }
    }


```
然后得在aidl的相同目录下也需要声明一下这个Person对象.新建一个Person.aidl

```
package com.xfhy.allinone.ipc.aidl;

parcelable Person;
```

都完成了之后,rebuild一下,AS会自动生成如下代码`IPersonManager.java`:

> 小插曲: 不能在aidl里面使用中文注释,否则可能会出现无法自动生成java代码的问题.奇怪的是我在macOS上面能自动生成,Windows上就不行.

```java
package com.xfhy.allinone.ipc.aidl;

public interface IPersonManager extends android.os.IInterface {
    /**
     * Default implementation for IPersonManager.
     */
    public static class Default implements com.xfhy.allinone.ipc.aidl.IPersonManager {
        @Override
        public java.util.List<com.xfhy.allinone.ipc.aidl.Person> getPersonList() throws android.os.RemoteException {
            return null;
        }

        @Override
        public boolean addPerson(com.xfhy.allinone.ipc.aidl.Person person) throws android.os.RemoteException {
            return false;
        }

        @Override
        public android.os.IBinder asBinder() {
            return null;
        }
    }

    /**
     * Local-side IPC implementation stub class.
     */
    public static abstract class Stub extends android.os.Binder implements com.xfhy.allinone.ipc.aidl.IPersonManager {
        private static final java.lang.String DESCRIPTOR = "com.xfhy.allinone.ipc.aidl.IPersonManager";

        /**
         * Construct the stub at attach it to the interface.
         */
        public Stub() {
            this.attachInterface(this, DESCRIPTOR);
        }

        /**
         * Cast an IBinder object into an com.xfhy.allinone.ipc.aidl.IPersonManager interface,
         * generating a proxy if needed.
         */
        public static com.xfhy.allinone.ipc.aidl.IPersonManager asInterface(android.os.IBinder obj) {
            if ((obj == null)) {
                return null;
            }
            android.os.IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
            if (((iin != null) && (iin instanceof com.xfhy.allinone.ipc.aidl.IPersonManager))) {
                return ((com.xfhy.allinone.ipc.aidl.IPersonManager) iin);
            }
            return new com.xfhy.allinone.ipc.aidl.IPersonManager.Stub.Proxy(obj);
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
                case TRANSACTION_getPersonList: {
                    data.enforceInterface(descriptor);
                    java.util.List<com.xfhy.allinone.ipc.aidl.Person> _result = this.getPersonList();
                    reply.writeNoException();
                    reply.writeTypedList(_result);
                    return true;
                }
                case TRANSACTION_addPerson: {
                    data.enforceInterface(descriptor);
                    com.xfhy.allinone.ipc.aidl.Person _arg0;
                    if ((0 != data.readInt())) {
                        _arg0 = com.xfhy.allinone.ipc.aidl.Person.CREATOR.createFromParcel(data);
                    } else {
                        _arg0 = null;
                    }
                    boolean _result = this.addPerson(_arg0);
                    reply.writeNoException();
                    reply.writeInt(((_result) ? (1) : (0)));
                    return true;
                }
                default: {
                    return super.onTransact(code, data, reply, flags);
                }
            }
        }

        private static class Proxy implements com.xfhy.allinone.ipc.aidl.IPersonManager {
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
            public java.util.List<com.xfhy.allinone.ipc.aidl.Person> getPersonList() throws android.os.RemoteException {
                android.os.Parcel _data = android.os.Parcel.obtain();
                android.os.Parcel _reply = android.os.Parcel.obtain();
                java.util.List<com.xfhy.allinone.ipc.aidl.Person> _result;
                try {
                    _data.writeInterfaceToken(DESCRIPTOR);
                    boolean _status = mRemote.transact(Stub.TRANSACTION_getPersonList, _data, _reply, 0);
                    if (!_status && getDefaultImpl() != null) {
                        return getDefaultImpl().getPersonList();
                    }
                    _reply.readException();
                    _result = _reply.createTypedArrayList(com.xfhy.allinone.ipc.aidl.Person.CREATOR);
                } finally {
                    _reply.recycle();
                    _data.recycle();
                }
                return _result;
            }

            @Override
            public boolean addPerson(com.xfhy.allinone.ipc.aidl.Person person) throws android.os.RemoteException {
                android.os.Parcel _data = android.os.Parcel.obtain();
                android.os.Parcel _reply = android.os.Parcel.obtain();
                boolean _result;
                try {
                    _data.writeInterfaceToken(DESCRIPTOR);
                    if ((person != null)) {
                        _data.writeInt(1);
                        person.writeToParcel(_data, 0);
                    } else {
                        _data.writeInt(0);
                    }
                    boolean _status = mRemote.transact(Stub.TRANSACTION_addPerson, _data, _reply, 0);
                    if (!_status && getDefaultImpl() != null) {
                        return getDefaultImpl().addPerson(person);
                    }
                    _reply.readException();
                    _result = (0 != _reply.readInt());
                } finally {
                    _reply.recycle();
                    _data.recycle();
                }
                return _result;
            }

            public static com.xfhy.allinone.ipc.aidl.IPersonManager sDefaultImpl;
        }

        static final int TRANSACTION_getPersonList = (android.os.IBinder.FIRST_CALL_TRANSACTION + 0);
        static final int TRANSACTION_addPerson = (android.os.IBinder.FIRST_CALL_TRANSACTION + 1);

        public static boolean setDefaultImpl(com.xfhy.allinone.ipc.aidl.IPersonManager impl) {
            // Only one user of this interface can use this function
            // at a time. This is a heuristic to detect if two different
            // users in the same process use this function.
            if (Stub.Proxy.sDefaultImpl != null) {
                throw new IllegalStateException("setDefaultImpl() called twice");
            }
            if (impl != null) {
                Stub.Proxy.sDefaultImpl = impl;
                return true;
            }
            return false;
        }

        public static com.xfhy.allinone.ipc.aidl.IPersonManager getDefaultImpl() {
            return Stub.Proxy.sDefaultImpl;
        }
    }

    public java.util.List<com.xfhy.allinone.ipc.aidl.Person> getPersonList() throws android.os.RemoteException;

    public boolean addPerson(com.xfhy.allinone.ipc.aidl.Person person) throws android.os.RemoteException;
}

```

我感觉AIDL的功能其实就在于此,写了AIDL文件之后,AS会自动帮我们生成一些代码,用于与Server通信.其实这些代码完全可以我们自己写,就是稍微麻烦些.有工具咱就用工具.

简单看一下这个文件,IPersonManager是继承了一个android.os.IInterface的interface,然后有一个Default类用于默认实现IPersonManager.然后一个抽象类Stub继承了android.os.Binder且实现了IPersonManager接口,这相当于扩展了Binder.因为它是继承了Binder,那它肯定是用来做IPC通信用的.

- asInterface 方法用于将服务端的Binder对象转换为客户端所需要的接口对象,该过程区分进程,如果进程一样,就返回服务端Stub对象本身,否则呢就返回封装后的Stub.Proxy对象
- onTransact 方法是运行在服务端的Binder线程中的,当客户端发起远程请求后,在底层封装后会交由此方法来处理.通过code来区分客户端请求的方法,注意一点的是,如果该方法返回false的话,客户端的请求就会失败.一般可以用来做权限控制

Proxy中的方法是运行在客户端的,当客户端发起远程请求时,`_data`会写入参数,然后调用transact方法发起RPC(远程过程调用)请求,同时挂起当前线程,然后服务端的onTransact方法就会被 调起,直到RPC过程返回后,当前线程继续执行,并从_reply取出返回值（如果有的话）,并返回结果

#### <span id="head6">2.2.2 服务端实现接口</span>

定义一个Service,然后将其process设置成一个新的进程,与主进程区分开,模拟跨进程访问.它里面需要实现`.aidl`生成的接口

```kotlin
class RemoteService : Service() {

    private val mPersonList = mutableListOf<Person?>()

    private val mBinder: Binder = object : IPersonManager.Stub() {
        override fun getPersonList(): MutableList<Person?> = mPersonList

        override fun addPerson(person: Person?): Boolean {
            return mPersonList.add(person)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return mBinder
    }

    override fun onCreate() {
        super.onCreate()
        mPersonList.add(Person("Garen"))
        mPersonList.add(Person("Darius"))
    }

}
```

实现的IPersonManager.Stub是一个Binder,需要通过onBind()返回,客户端需要通过这个Binder来跨进程调用Service这边的服务.

#### <span id="head7">2.2.3 客户端与服务端进行通信</span>

客户端这边需要通过bindService()来连接此Service,进而实现通信.客户端的 onServiceConnected() 回调会接收服务的 onBind() 方法所返回的 binder 实例.当客户端在 onServiceConnected() 回调中收到 IBinder 时，它必须调用 YourServiceInterface.Stub.asInterface(service)，以将返回的参数转换成 YourServiceInterface 类型.

因为是模仿的跨进程,咱就模仿得彻底一点,模仿跨app的情况.假设客户端那边是不能直接拿到Service的引用,咱需要定义一个action,方便bindService()

```xml
<service
    android:name=".ipc.aidl.RemoteService"
    android:enabled="true"
    android:exported="true"
    android:process=":other">
    <intent-filter>
        <action android:name="com.xfhy.aidl.Server.Action" />
    </intent-filter>
</service>
```

service定义好之后,再来通信

```kotlin
class AidlActivity : TitleBarActivity() {

    companion object {
        const val TAG = "xfhy_aidl"
    }

    private var remoteServer: IPersonManager? = null

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            log(TAG, "onServiceConnected")
            //在onServiceConnected调用IPersonManager.Stub.asInterface获取接口类型的实例
            //通过这个实例调用服务端的服务
            remoteServer = IPersonManager.Stub.asInterface(service)
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            log(TAG, "onServiceDisconnected")
        }
    }

    override fun getThisTitle(): CharSequence {
        return "AIDL"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_aidl)

        btnConnect.setOnClickListener {
            connectService()
        }
        btnGetPerson.setOnClickListener {
            getPerson()
        }
        btnAddPerson.setOnClickListener {
            addPerson()
        }
    }

    private fun connectService() {
        val intent = Intent()
        //action 和 package(app的包名)
        intent.action = "com.xfhy.aidl.Server.Action"
        intent.setPackage("com.xfhy.allinone")
        val bindServiceResult = bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
        log(TAG, "bindService $bindServiceResult")
        
        //如果targetSdk是30,那么需要处理Android 11中的程序包可见性  具体参见: https://developer.android.com/about/versions/11/privacy/package-visibility
    }

    private fun addPerson() {
        //客户端调服务端方法时,需要捕获以下几个异常:
        //RemoteException 异常：
        //DeadObjectException 异常：连接中断时会抛出异常；
        //SecurityException 异常：客户端和服务端中定义的 AIDL 发生冲突时会抛出异常；
        try {
            val addPersonResult = remoteServer?.addPerson(Person("盖伦"))
            log(TAG, "addPerson result = $addPersonResult")
        } catch (e: RemoteException) {
            e.printStackTrace()
        } catch (e: DeadObjectException) {
            e.printStackTrace()
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun getPerson() {
        val personList = remoteServer?.personList
        log(TAG, "person 列表 $personList")
    }

    override fun onDestroy() {
        super.onDestroy()
        //最后记得unbindService
        unbindService(serviceConnection)
    }

}
```

客户端这边首先需要bindService(),然后通过ServiceConnection实例的onServiceConnected()回调拿到IBinder,将这个IBinder转成`aidl`里面定义的接口类型实例,通过该实例就能间距与服务端进行通信了.上面的demo中,我们调用了服务端的addPerson和getPerson方法,测试时我先get再add,再get,然后看输出日志

```
2020-12-24 12:41:00.170 24785-24785/com.xfhy.allinone D/xfhy_aidl: bindService true
2020-12-24 12:41:00.906 24785-24785/com.xfhy.allinone D/xfhy_aidl: onServiceConnected
2020-12-24 12:41:04.253 24785-24785/com.xfhy.allinone D/xfhy_aidl: person 列表 [Person(name=Garen), Person(name=Darius)]
2020-12-24 12:41:05.952 24785-24785/com.xfhy.allinone D/xfhy_aidl: addPerson result = true
2020-12-24 12:41:09.022 24785-24785/com.xfhy.allinone D/xfhy_aidl: person 列表 [Person(name=Garen), Person(name=Darius), Person(name=盖伦)]

```

可以看到,第2次get时,已经将之前添加的数据也取回来了,所以通信是OK的.

需要注意的是在客户端调用这些远程方法时是同步调用,在主线程调用可能会导致ANR,应该在子线程去调用.

调用的时候可能会出现下面几个异常,必须得捕获一下:

- RemoteException 异常：
- DeadObjectException 异常：连接中断时会抛出异常；
- SecurityException 异常：客户端和服务端中定义的 AIDL 发生冲突时会抛出异常；

### <span id="head8">2.3 in,out,inout关键字</span>

在上面定义AIDL接口的时候,咱用到了一个关键字in,这个关键是其实是定向tag,是用来**指出数据流通的方式**.还有2个tag是out和inout.**所有的非基本参数都需要一个定向tag来指出数据的流向,基本参数的定向tag默认并且只能是in**.

写个demo验证一下:

先修改aidl接口,把3种方式都安排上

```aidl
interface IPersonManager {
    void addPersonIn(in Person person);
    void addPersonOut(out Person person);
    void addPersonInout(inout Person person);
}
```

服务端实现:

```kotlin
override fun addPersonIn(person: Person?) {
    log(TAG,"服务端 addPersonIn() person = $person")
    person?.name = "被addPersonIn修改"
}

override fun addPersonOut(person: Person?) {
    log(TAG,"服务端 addPersonOut() person = $person}")
    person?.name = "被addPersonOut修改"
}

override fun addPersonInout(person: Person?) {
    log(TAG,"服务端 addPersonInout() person = $person}")
    person?.name = "被addPersonInout修改"
}
```

客户端实现:

```kotlin
private fun addPersonIn() {
    var person = Person("寒冰")
    log(TAG, "客户端 addPersonIn() 调用之前 person = $person}")
    remoteServer?.addPersonIn(person)
    log(TAG, "客户端 addPersonIn() 调用之后 person = $person}")
}

private fun addPersonOut() {
    var person = Person("蛮王")
    log(TAG, "客户端 addPersonOut() 调用之前 person = $person}")
    remoteServer?.addPersonOut(person)
    log(TAG, "客户端 addPersonOut() 调用之后 person = $person}")
}

private fun addPersonInout() {
    var person = Person("艾克")
    log(TAG, "客户端 addPersonInout() 调用之前 person = $person}")
    remoteServer?.addPersonInout(person)
    log(TAG, "客户端 addPersonInout() 调用之后 person = $person}")
}
```

最后输出的日志如下:

```
//in 方式  服务端那边修改了,但是服务端这边不知道
客户端 addPersonIn() 调用之前 person = Person(name=寒冰) hashcode = 142695478}
服务端 addPersonIn() person = Person(name=寒冰) hashcode = 38642374
客户端 addPersonIn() 调用之后 person = Person(name=寒冰) hashcode = 142695478}

//out方式 客户端能感知服务端的修改,且客户端不能向服务端传数据
//可以看到服务端是没有拿到客户端的数据的!
客户端 addPersonOut() 调用之前 person = Person(name=蛮王) hashcode = 15787831}
服务端 addPersonOut() person = Person(name=) hashcode = 231395975}
客户端 addPersonOut() 调用之后 person = Person(name=被addPersonOut修改) hashcode = 15787831}

//inout方式 客户端能感知服务端的修改
客户端 addPersonInout() 调用之前 person = Person(name=艾克) hashcode = 143615140}
服务端 addPersonInout() person = Person(name=艾克) hashcode = 116061620}
客户端 addPersonInout() 调用之后 person = Person(name=被addPersonInout修改) hashcode = 143615140}
```

由上面的demo可以更容易理解数据流向的含义.而且我们还发现了以下规律:

- in方式是可以从客户端向服务端传数据的,out则不行
- out方式是可以从服务端向客户端传数据的,in则不行
- 不管服务端是否有修改传过去的对象数据,客户端的对象引用是不会变的,变化的只是客户端的数据.合情合理,跨进程是序列化与反序列化的方式操作数据.

### <span id="head9">2.4 oneway 关键字</span>

将aidl接口的方法前加上oneway关键字则这个方法是异步调用,不会阻塞调用线程.当客户端这边调用服务端的方法时,如果不需要知道其返回结果,这时使用异步调用可以提高客户端的执行效率.

验证: 我将aidl接口方法定义成oneway的,在服务端AIDL方法实现中加入Thread.sleep(2000)阻塞一下方法调用,然后客户端调用这个方法,查看方法调用的前后时间

```kotlin
private fun addPersonOneway() {
    log(TAG, "oneway开始时间: ${System.currentTimeMillis()}")
    remoteServer?.addPersonOneway(Person("oneway"))
    log(TAG, "oneway结束时间: ${System.currentTimeMillis()}")
}

//日志输出
//oneway开始时间: 1608858291371
//oneway结束时间: 1608858291372
```

可以看到,客户端调用这个方法时确实是没有被阻塞的.

### <span id="head10">2.5 线程安全</span>

**AIDL的方法是在服务端的Binder线程池中执行的**,所以多个客户端同时进行连接且操作数据时可能存在多个线程同时访问的情形.这样的话,我们就需要在服务端AIDL方法中处理多线程同步问题.

先看下服务端的AIDL方法是在哪个线程中:

```kotlin
override fun addPerson(person: Person?): Boolean {
    log(TAG, "服务端 addPerson() 当前线程 : ${Thread.currentThread().name}")
    return mPersonList.add(person)
}

//日志输出
服务端 addPerson() 当前线程 : Binder:3961_3
```

可以看到,确实是在非主线程中执行的.那确实会存在多线程安全问题,我们需要将mPersonList的类型修改为CopyOnWriteArrayList,以确保线程安全.  需要注意的是即使这里的数据类型是CopyOnWriteArrayList,但是在返回给客户端的时候,还是会被转化成ArrayList.能被转化成功的原因是它们都是实现了List接口,AIDL是支持List的.

验证一下,在客户端看看这个返回来的mPersonList类型是啥:

```kotlin

//服务端
private val mPersonList = CopyOnWriteArrayList<Person?>()

override fun getPersonList(): MutableList<Person?> = mPersonList

//客户端
private fun getPerson() {
    val personList = remoteServer?.personList
    personList?.let {
        log(TAG, "personList ${it::class.java}")
    }
}

//输出日志
personList class java.util.ArrayList
```

这里确实最后被转成了ArrayList,另外还有ConcurrentHashMap也是同样的道理,这里就不验证了.

### <span id="head11">2.6 aidl 监听器(观察者? 双向通信?)</span>

在上面的案例中,我们只能在客户端每次去调服务端的方法然后获得结果,这就很被动.比如这时客户端想观察一下服务端数据的变动,就像LiveData一样,数据变化的时候告诉我一声,我好干点事情.服务端数据有变动就通知一下客户端,这就需要搞个监听器才行了.

因为这个监听器Listener是需要跨进程的,那么这里首先需要为这个Listener创建一个aidl的回调接口`IPersonChangeListener.aidl`.

```aidl
interface IPersonChangeListener {
    void onPersonDataChanged(in Person person);
}
```

需要注意的是这里的数据流通方式是in,其实所谓的"服务端"和"客户端"在Binder通讯中是相对的.我们的客户端不仅可以发送消息充当"Client",同时也能接收服务端推送的消息,从而变成"Server".

有了监听器,还需要在`IPersonManager.aidl`中加上注册/反注册监听的方法

```aidl
interface IPersonManager {
    ......
    void registerListener(IPersonChangeListener listener);
    void unregisterListener(IPersonChangeListener listener);
}
```

现在我们在服务端实现这个注册/反注册的方法.这还不简单吗?搞一个`List<IPersonChangeListener>`来存放Listener集合,当数据变化的时候,遍历这个集合,通知一下这些Listener就行.

仔细想一想,这样真的行吗?这个IPersonChangeListener是需要跨进程的,那么客户端每次传过来的对象是经过序列化与反序列化的,服务端这边接收到的根本不是客户端传过来的那个对象. 虽然传过来的Listener不同,但是用来通信的Binder是同一个,利用这个原理Android给我们提供了一个RemoteCallbackList的东西.专门用于存放监听接口的集合的.RemoteCallbackList内部将数据存储于一个ArrayMap中,key就是我们用来传输的binder,然后value就是监听接口的封装.

```java
//RemoteCallbackList.java  有删减
public class RemoteCallbackList<E extends IInterface> {
    ArrayMap<IBinder, Callback> mCallbacks = new ArrayMap<IBinder, Callback>();

    private final class Callback implements IBinder.DeathRecipient {
        final E mCallback;
        final Object mCookie;
    
        Callback(E callback, Object cookie) {
            mCallback = callback;
            mCookie = cookie;
        }
    }
    
    public boolean register(E callback, Object cookie) {
        synchronized (mCallbacks) {
            IBinder binder = callback.asBinder();
            Callback cb = new Callback(callback, cookie);
            mCallbacks.put(binder, cb);
            return true;
        }
    }
}
```

RemoteCallbackList内部在操作数据的时候已经做了线程同步的操作,所以我们不需要单独做额外的线程同步操作. 现在我们来实现一下这个注册/反注册方法:

```kotlin
private val mListenerList = RemoteCallbackList<IPersonChangeListener?>()

private val mBinder: Binder = object : IPersonManager.Stub() {
    .....
    override fun registerListener(listener: IPersonChangeListener?) {
        mListenerList.register(listener)
    }

    override fun unregisterListener(listener: IPersonChangeListener?) {
        mListenerList.unregister(listener)
    }
}
```

RemoteCallbackList添加与删除数据对应着`register()/unregister()`方法.然后我们模拟一下服务端数据更新的情况,开个线程每隔5秒添加一个Person数据,然后通知一下观察者.

```kotlin
//死循环 每隔5秒添加一次person,通知观察者
private val serviceWorker = Runnable {
    while (!Thread.currentThread().isInterrupted) {
        Thread.sleep(5000)
        val person = Person("name${Random().nextInt(10000)}")
        log(AidlActivity.TAG, "服务端 onDataChange() 生产的 person = $person}")
        mPersonList.add(person)
        onDataChange(person)
    }
}
private val mServiceListenerThread = Thread(serviceWorker)

//数据变化->通知观察者
private fun onDataChange(person: Person?) {
    //1. 使用RemoteCallbackList时,必须首先调用beginBroadcast(),最后调用finishBroadcast().得成对出现
    //这里拿到的是监听器的数量
    val callbackCount = mListenerList.beginBroadcast()
    for (i in 0 until callbackCount) {
        try {
            //这里try一下避免有异常时无法调用finishBroadcast()
            mListenerList.getBroadcastItem(i)?.onPersonDataChanged(person)
        } catch (e: RemoteException) {
            e.printStackTrace()
        }
    }
    //3. 最后调用finishBroadcast()  必不可少
    mListenerList.finishBroadcast()
}

override fun onCreate() {
    .....
    mServiceListenerThread.start()
}

override fun onDestroy() {
    super.onDestroy()
    mServiceListenerThread.interrupt()
}

```

使用RemoteCallbackList时,需要先调用其beginBroadcast()获得监听器个数,然后根据getBroadcastItem()来获取具体的监听器对象,进而进行回调,最后得调用一下finishBroadcast()结束这个过程.`beginBroadcast()`与`finishBroadcast()`必须成对出现,调用了`beginBroadcast()`,未调用`finishBroadcast()`结束的话,下次再调用`beginBroadcast()`会抛异常`beginBroadcast() called while already in a broadcast`.

服务端实现好了,客户端就比较好办了

```kotlin
private val mPersonChangeListener = object : IPersonChangeListener.Stub() {
    override fun onPersonDataChanged(person: Person?) {
        log(TAG, "客户端 onPersonDataChanged() person = $person}")
    }
}

private fun registerListener() {
    remoteServer?.registerListener(mPersonChangeListener)
}

private fun unregisterListener() {
    remoteServer?.asBinder()?.isBinderAlive?.let {
        remoteServer?.unregisterListener(mPersonChangeListener)
    }
}
```

因为是需要跨进程通信的,所以我们需要继承自IPersonChangeListener.Stub从而生成一个监听器对象.

最后输出日志如下:

```
服务端 onDataChange() 生产的 person = Person(name=name9398) hashcode = 130037351}
客户端 onPersonDataChanged() person = Person(name=name9398) hashcode = 217703225}
```

完全ok,符合预期.

### <span id="head12">2.7 Binder 死亡通知</span>

服务端进程可能随时会被杀掉,这时我们需要在客户端能够被感知到binder已经死亡,从而做一些收尾清理工作或者进程重新连接.有如下4种方式能知道服务端是否已经挂掉.

1. 调用binder的pingBinder()检查,返回false则说明远程服务失效
2. 调用binder的linkToDeath()注册监听器,当远程服务失效时,就会收到回调
3. 绑定Service时用到的ServiceConnection有个onServiceDisconnected()回调在服务端断开时也能收到回调
4. 客户端调用远程方法时,抛出DeadObjectException(RemoteException)

写份代码验证一下,在客户端修改为如下:

```kotlin
private val mDeathRecipient = object : IBinder.DeathRecipient {
    override fun binderDied() {
        //监听 binder died
        log(TAG, "binder died")
        //移除死亡通知
        mService?.unlinkToDeath(this, 0)
        mService = null
        //重新连接
        connectService()
    }
}

private val serviceConnection = object : ServiceConnection {
    override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
        this@AidlActivity.mService = service
        log(TAG, "onServiceConnected")

        //给binder设置一个死亡代理
        service?.linkToDeath(mDeathRecipient, 0)

        //在onServiceConnected调用IPersonManager.Stub.asInterface获取接口类型的实例
        //通过这个实例调用服务端的服务
        mRemoteServer = IPersonManager.Stub.asInterface(service)
    }

    override fun onServiceDisconnected(name: ComponentName?) {
        log(TAG, "onServiceDisconnected")
    }
}
```

绑定服务之后,将服务端进程杀掉,输出日志如下:

```
//第一次连接
bindService true
onServiceConnected, thread = main

//杀掉服务端 
binder died, thread = Binder:29391_3
onServiceDisconnected, thread = main

//重连
bindService true
onServiceConnected, thread = main

```

确实是监听到了服务端断开连接的时刻.然后重新连接也是ok的. 这里需要注意的是`binderDied()`方法是运行在子线程的,`onServiceDisconnected()`是运行在主线程的,如果要在这里更新UI,得注意一下.

### <span id="head13">2.8 权限验证</span>

有没有注意到,咱们的Service是完全暴露的,任何app都可以访问这个Service并且远程调用Service的服务,这样不太安全.咱们可以在清单文件中加入自定义权限,然后在Service中校验一下客户端有没有这个权限即可.

定义自定义权限:

```xml
<permission
    android:name="com.xfhy.allinone.ipc.aidl.ACCESS_PERSON_SERVICE"
    android:protectionLevel="normal" />
```

客户端需要在清单文件中声明这个权限:

```xml
<uses-permission android:name="com.xfhy.allinone.ipc.aidl.ACCESS_PERSON_SERVICE"/>
```

服务端Service校验权限:

```kotlin
override fun onBind(intent: Intent?): IBinder? {
    val check = checkCallingOrSelfPermission("com.xfhy.allinone.ipc.aidl.ACCESS_PERSON_SERVICE")
    if (check == PackageManager.PERMISSION_DENIED) {
        log(TAG,"没有权限")
        return null
    }
    log(TAG,"有权限")
    return mBinder
}
```

## <span id="head14">3. 原理</span>

### <span id="head15">3.1 AIDL是怎么工作的?</span>

我们编写了aidl文件之后,啥也没干就自动拥有了跨进程通信的能力.这一切得归功于Android Studio根据aidl文件生成的`IPersonManager.java`文件(生成的这个文件通过双击Shift输入`IPersonManager.java`即可找到),它里面已经帮我们封装好了跨进程通信这块的逻辑(最终是通过Binder来完成的),所以这个`IPersonManager.java`文件最终会打包进apk里面,我们才得以方便地进行跨进程通信.

### <span id="head16">3.2 详细解读</span>

先来简单看下`IPersonManager.java`的大致结构,为了更方便阅读,我将`IPersonManager.aidl`文件中多余的方法全部删除,只剩下`List<Person> getPersonList();`和`void addPersonIn(in Person person);`:

```java
/*
 * This file is auto-generated.  DO NOT MODIFY.
 */
package com.xfhy.allinone.ipc.aidl;

public interface IPersonManager extends android.os.IInterface {
    /**
     * Default implementation for IPersonManager.
     */
    public static class Default implements com.xfhy.allinone.ipc.aidl.IPersonManager {
        @Override
        public java.util.List<com.xfhy.allinone.ipc.aidl.Person> getPersonList() throws android.os.RemoteException {
            return null;
        }

        @Override
        public void addPersonIn(com.xfhy.allinone.ipc.aidl.Person person) throws android.os.RemoteException {
        }

        @Override
        public android.os.IBinder asBinder() {
            return null;
        }
    }

    /**
     * Local-side IPC implementation stub class.
     */
    public static abstract class Stub extends android.os.Binder implements com.xfhy.allinone.ipc.aidl.IPersonManager {
        private static final java.lang.String DESCRIPTOR = "com.xfhy.allinone.ipc.aidl.IPersonManager";

        /**
         * Construct the stub at attach it to the interface.
         */
        public Stub() {
            this.attachInterface(this, DESCRIPTOR);
        }

        /**
         * Cast an IBinder object into an com.xfhy.allinone.ipc.aidl.IPersonManager interface,
         * generating a proxy if needed.
         */
        public static com.xfhy.allinone.ipc.aidl.IPersonManager asInterface(android.os.IBinder obj) {
            if ((obj == null)) {
                return null;
            }
            android.os.IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
            if (((iin != null) && (iin instanceof com.xfhy.allinone.ipc.aidl.IPersonManager))) {
                return ((com.xfhy.allinone.ipc.aidl.IPersonManager) iin);
            }
            return new com.xfhy.allinone.ipc.aidl.IPersonManager.Stub.Proxy(obj);
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
                case TRANSACTION_getPersonList: {
                    data.enforceInterface(descriptor);
                    java.util.List<com.xfhy.allinone.ipc.aidl.Person> _result = this.getPersonList();
                    reply.writeNoException();
                    reply.writeTypedList(_result);
                    return true;
                }
                case TRANSACTION_addPersonIn: {
                    data.enforceInterface(descriptor);
                    com.xfhy.allinone.ipc.aidl.Person _arg0;
                    if ((0 != data.readInt())) {
                        _arg0 = com.xfhy.allinone.ipc.aidl.Person.CREATOR.createFromParcel(data);
                    } else {
                        _arg0 = null;
                    }
                    this.addPersonIn(_arg0);
                    reply.writeNoException();
                    return true;
                }
                default: {
                    return super.onTransact(code, data, reply, flags);
                }
            }
        }

        private static class Proxy implements com.xfhy.allinone.ipc.aidl.IPersonManager {
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
            public java.util.List<com.xfhy.allinone.ipc.aidl.Person> getPersonList() throws android.os.RemoteException {
                android.os.Parcel _data = android.os.Parcel.obtain();
                android.os.Parcel _reply = android.os.Parcel.obtain();
                java.util.List<com.xfhy.allinone.ipc.aidl.Person> _result;
                try {
                    _data.writeInterfaceToken(DESCRIPTOR);
                    boolean _status = mRemote.transact(Stub.TRANSACTION_getPersonList, _data, _reply, 0);
                    if (!_status && getDefaultImpl() != null) {
                        return getDefaultImpl().getPersonList();
                    }
                    _reply.readException();
                    _result = _reply.createTypedArrayList(com.xfhy.allinone.ipc.aidl.Person.CREATOR);
                } finally {
                    _reply.recycle();
                    _data.recycle();
                }
                return _result;
            }

            @Override
            public void addPersonIn(com.xfhy.allinone.ipc.aidl.Person person) throws android.os.RemoteException {
                android.os.Parcel _data = android.os.Parcel.obtain();
                android.os.Parcel _reply = android.os.Parcel.obtain();
                try {
                    _data.writeInterfaceToken(DESCRIPTOR);
                    if ((person != null)) {
                        _data.writeInt(1);
                        person.writeToParcel(_data, 0);
                    } else {
                        _data.writeInt(0);
                    }
                    boolean _status = mRemote.transact(Stub.TRANSACTION_addPersonIn, _data, _reply, 0);
                    if (!_status && getDefaultImpl() != null) {
                        getDefaultImpl().addPersonIn(person);
                        return;
                    }
                    _reply.readException();
                } finally {
                    _reply.recycle();
                    _data.recycle();
                }
            }

            public static com.xfhy.allinone.ipc.aidl.IPersonManager sDefaultImpl;
        }

        static final int TRANSACTION_getPersonList = (android.os.IBinder.FIRST_CALL_TRANSACTION + 0);
        static final int TRANSACTION_addPersonIn = (android.os.IBinder.FIRST_CALL_TRANSACTION + 1);

        public static boolean setDefaultImpl(com.xfhy.allinone.ipc.aidl.IPersonManager impl) {
            // Only one user of this interface can use this function
            // at a time. This is a heuristic to detect if two different
            // users in the same process use this function.
            if (Stub.Proxy.sDefaultImpl != null) {
                throw new IllegalStateException("setDefaultImpl() called twice");
            }
            if (impl != null) {
                Stub.Proxy.sDefaultImpl = impl;
                return true;
            }
            return false;
        }

        public static com.xfhy.allinone.ipc.aidl.IPersonManager getDefaultImpl() {
            return Stub.Proxy.sDefaultImpl;
        }
    }

    public java.util.List<com.xfhy.allinone.ipc.aidl.Person> getPersonList() throws android.os.RemoteException;

    public void addPersonIn(com.xfhy.allinone.ipc.aidl.Person person) throws android.os.RemoteException;
}
```

这块代码看起来很长.咱依次来看,首先IPersonManager是一个接口,然后它继承自IInterface接口.IInterface接口是Binder接口的基类,要通过Binder传输的接口都必须继承自IInterface.它里面的方法就是我们在aidl文件中声明的2个方法.然后用2个整型的id用于标识在transact过程中客户端所请求的是哪个方法.IPersonManager.Stub继承自Binder并实现了IPersonManager接口.当客户端与服务端都位于同一个进程时,方法调用不会走跨进程的transact过程,而当两者位于不同进程时,方法调用需要走transact过程,这个逻辑是由Stub的内部代理Proxy完成的.

Default类就只是IPersonManager的默认实现,可以不用在意.

下面来单独分析一下Stub类

**IPersonManager.Stub**

```java
public static abstract class Stub extends android.os.Binder implements com.xfhy.allinone.ipc.aidl.IPersonManager {
    private static final java.lang.String DESCRIPTOR = "com.xfhy.allinone.ipc.aidl.IPersonManager";

    /**
     * Construct the stub at attach it to the interface.
     */
    public Stub() {
        this.attachInterface(this, DESCRIPTOR);
    }
    
    /**
     * Cast an IBinder object into an com.xfhy.allinone.ipc.aidl.IPersonManager interface,
     * generating a proxy if needed.
     */
    public static com.xfhy.allinone.ipc.aidl.IPersonManager asInterface(android.os.IBinder obj) {
        if ((obj == null)) {
            return null;
        }
        android.os.IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
        if (((iin != null) && (iin instanceof com.xfhy.allinone.ipc.aidl.IPersonManager))) {
            return ((com.xfhy.allinone.ipc.aidl.IPersonManager) iin);
        }
        return new com.xfhy.allinone.ipc.aidl.IPersonManager.Stub.Proxy(obj);
    }
}
```

- DESCRIPTOR是Binder的唯一标识,一般用当前Binder的类名表示.
- attachInterface()是将Binder对象转成客户端需要的AIDL接口类型对象.如果需要跨进程,则还需要封装一个Stub.Proxy对象再返回;如果不需要跨进程,那么直接将Service端的Stub直接返回就行.

接着看Stub剩余的方法:

```java
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
        case TRANSACTION_getPersonList: {
            data.enforceInterface(descriptor);
            java.util.List<com.xfhy.allinone.ipc.aidl.Person> _result = this.getPersonList();
            reply.writeNoException();
            reply.writeTypedList(_result);
            return true;
        }
        case TRANSACTION_addPersonIn: {
            data.enforceInterface(descriptor);
            //从data中序列化一个Person出来,然后调用addPersonIn()去添加这个Person
            com.xfhy.allinone.ipc.aidl.Person _arg0;
            if ((0 != data.readInt())) {
                _arg0 = com.xfhy.allinone.ipc.aidl.Person.CREATOR.createFromParcel(data);
            } else {
                _arg0 = null;
            }
            this.addPersonIn(_arg0);
            reply.writeNoException();
            return true;
        }
        default: {
            return super.onTransact(code, data, reply, flags);
        }
    }
}
```

- asBinder()就是将当前的Binder对象返回
- onTransact()方法是运行在服务端的线程池中的.这里看起来就像是同一个进程里面的调用一样,但其实已经涉及到跨进程通信了.当客户端跨进程请求服务端时,远程请求会通过系统底层封装后交由此方法来处理.服务端通过code来确定客户端请求的目标方法是什么,然后从data中取出目标方法所需的参数,然后执行目标方法.当目标方法执行完毕之后,向reply中写入返回值.

**IPersonManager.Stub.Proxy**

```java
 private static class Proxy implements com.xfhy.allinone.ipc.aidl.IPersonManager {
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
}
```

这里的mRemote是用于远程请求的Binder.如果需要跨进程,那么客户端就是通过这个Proxy代理来进行远程调用的.来看看调用方法具体是怎么实现的

```java
static final int TRANSACTION_getPersonList = (android.os.IBinder.FIRST_CALL_TRANSACTION + 0);
static final int TRANSACTION_addPersonIn = (android.os.IBinder.FIRST_CALL_TRANSACTION + 1);

@Override
public java.util.List<com.xfhy.allinone.ipc.aidl.Person> getPersonList() throws android.os.RemoteException {
    android.os.Parcel _data = android.os.Parcel.obtain();
    android.os.Parcel _reply = android.os.Parcel.obtain();
    java.util.List<com.xfhy.allinone.ipc.aidl.Person> _result;
    try {
        _data.writeInterfaceToken(DESCRIPTOR);
        boolean _status = mRemote.transact(Stub.TRANSACTION_getPersonList, _data, _reply, 0);
        if (!_status && getDefaultImpl() != null) {
            return getDefaultImpl().getPersonList();
        }
        _reply.readException();
        _result = _reply.createTypedArrayList(com.xfhy.allinone.ipc.aidl.Person.CREATOR);
    } finally {
        _reply.recycle();
        _data.recycle();
    }
    return _result;
}

@Override
public void addPersonIn(com.xfhy.allinone.ipc.aidl.Person person) throws android.os.RemoteException {
    android.os.Parcel _data = android.os.Parcel.obtain();
    android.os.Parcel _reply = android.os.Parcel.obtain();
    try {
        _data.writeInterfaceToken(DESCRIPTOR);
        if ((person != null)) {
            _data.writeInt(1);
            person.writeToParcel(_data, 0);
        } else {
            _data.writeInt(0);
        }
        boolean _status = mRemote.transact(Stub.TRANSACTION_addPersonIn, _data, _reply, 0);
        if (!_status && getDefaultImpl() != null) {
            getDefaultImpl().addPersonIn(person);
            return;
        }
        _reply.readException();
    } finally {
        _reply.recycle();
        _data.recycle();
    }
}
```

- 这2个方法都是运行在客户端的,当客户端调用此方法时: 首先创建该方法所需要的输入型Parcel对象`_data`,输出型Parcel对象`_reply`和返回值(如果有).然后将客户端方法的入参写入`_data`里面,通过序列化的方式.接着调用transact方法发起RPC远程调用,当前线程会被挂起,然后服务端的onTransact方法会被调用,直到RPC过程返回后,当前线程才能继续执行.然后将方法的返回值写入到`_reply`中,也是通过序列化的方式,最后返回`_reply`中的数据.
- Parcel对象是用来进行客户端与服务端进行数据传输的,只能传输可序列化的数据

应用层面的原理基本就这些了,如果再往里层探究的话,就会涉及到Binder机制里面比较底层的东西了.这里暂时不做分析.

下面这张图刚好总结上面的流程(来自Android开发艺术探索):

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/Binder%E7%9A%84%E5%B7%A5%E4%BD%9C%E6%9C%BA%E5%88%B6.png)

因为上面的`IPersonManager.java`文件是自动生成的,所以是很有规律的.即使我们不用AIDL也完全可以自定义Binder,从而实现跨进程通信.

## <span id="head17"> 资料</span>

- [文中代码仓库](https://github.com/xfhy/AllInOne/blob/master/app/src/main/java/com/xfhy/allinone/ipc/aidl/AidlActivity.kt)
- [Android 接口定义语言 (AIDL)](https://developer.android.com/guide/components/aidl?hl=zh-cn)
- [Android中AIDL的工作原理](https://www.jianshu.com/p/e0c583ea9289)
- [你真的理解AIDL中的in，out，inout么？](https://www.jianshu.com/p/ddbb40c7a251)
- [Android 深入浅出AIDL（一）](https://blog.csdn.net/qian520ao/article/details/78072250)
- [RemoteCallbackList](https://developer.android.com/reference/android/os/RemoteCallbackList)
- [Android：学习AIDL，这一篇文章就够了(下)](https://www.jianshu.com/p/0cca211df63c)
- Android开发艺术探索