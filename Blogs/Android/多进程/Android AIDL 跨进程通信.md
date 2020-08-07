#### 前言

跨进程通信是Android系统必不可少的基础.众所周知,Android是基于Linux的,而Linux已经有注入命名管道、共享内存、信号量等进程间通信方式，但是Android自己搞了一个叫Binder的进程间通信方式，它使用简单、安全、快速（只需拷贝一次）。Android中的进程间方式有：Bundle、共享文件、Messenger、AIDL、ContentProvider、Socket。AIDL是最常用的，也是使用起来比较方便的一个。那么本文的重点就是它了。本文中的案例参考自 刚哥的Android开发艺术探索。案例实现的效果：实现客户端进程与服务端进程通信，客户端可以请求服务端进行添加书籍和获取服务端的所有书籍。

## 一、AIDL使用

### 1. AIDL定义

#### a. 新建bean对象

首先新建一个书籍Book对象，待会儿需要跨进程传输。该对象需要实现Parcelable接口然后进行序列化，跨进程传输必备。

```java
package com.xfhy.processdemo;

import android.os.Parcel;
import android.os.Parcelable;

public class Book implements Parcelable {
    public int bookId;
    public String bookName;

    public Book() {
    }

    public Book(int bookId, String bookName) {
        this.bookId = bookId;
        this.bookName = bookName;
    }

    protected Book(Parcel in) {
        bookId = in.readInt();
        bookName = in.readString();
    }

    public static final Creator<Book> CREATOR = new Creator<Book>() {
        @Override
        public Book createFromParcel(Parcel in) {
            return new Book(in);
        }

        @Override
        public Book[] newArray(int size) {
            return new Book[size];
        }
    };

    @Override
    public int describeContents() {
        return 0;
    }

    @Override
    public void writeToParcel(Parcel parcel, int i) {
        parcel.writeInt(bookId);
        parcel.writeString(bookName);
    }

    @Override
    public String toString() {
        return "Book{" +
                "bookId=" + bookId +
                ", bookName='" + bookName + '\'' +
                '}';
    }
}
```

#### b. 定义aidl文件

首先是需要定义刚刚Book对象的aidl，在`src/main`下面新建文件夹aidl，新建包名`com.xfhy.processdemo`(这里的包名需要与上面的Book对象的包名一样)，然后创建文件Book.aidl

```aidl
package com.xfhy.processdemo;

//这个是Book在aidl中的声明
parcelable Book;
```

然后新建一个接口，这个接口是用来客户端与服务端通信的。

```aidl
// IBookManager.aidl
package com.xfhy.processdemo;

//虽然位于相同包,但还是需要导包
import com.xfhy.processdemo.Book;

// Declare any non-default types here with import statements

interface IBookManager {
    List<Book> getBookList();
    void addBook(in Book book);
}

```

就定义了2个方法，获取书籍列表和添加书籍。定义好了之后，这个时候rebuild一下。为什么要rebuild，稍后会讲到。

### 2. 服务端

#### a. 新建一个Service

新建一个Service命名为`BookManagerService`，然后在清单文件中为其配置process属性，让其运行在另一个进程。

```xml
<service
    android:name=".aidl.BookManagerService"
    android:process=":remote"/>
```

然后我们需要在Service中实现AIDL接口，然后在里面实现对书籍列表的获取和添加。

```java
public class BookManagerService extends Service {

    private static final String TAG = "BookManagerService";
    //支持并发的
    private AtomicBoolean mIsServiceDestoryed = new AtomicBoolean(false);
    //支持并发读写
    private CopyOnWriteArrayList<Book> mBookList = new CopyOnWriteArrayList<>();

    private Binder mBinder = new IBookManager.Stub() {
        @Override
        public List<Book> getBookList() throws RemoteException {
            return mBookList;
        }

        @Override
        public void addBook(Book book) throws RemoteException {
            //添加
            mBookList.add(book);
        }

    };

    @Override
    public void onCreate() {
        super.onCreate();

        //搞点初始数据嘛
        mBookList.add(new Book(1, "Android"));
        mBookList.add(new Book(2, "Ios"));
    }

    @Override
    public void onDestroy() {
        mIsServiceDestoryed.set(true);
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return mBinder;
    }

}
```

实现IBookManager.Stub，它是一个Binder，然后通过onBind（）方法返回，这样客户端才能拿到这个Binder对象，进行通信。

### 3. 客户端

在客户端中，需要绑定Service，然后将连接时返回的Binder对象通过IBookManager.Stub.asInterface（）方法生成一个IBookManager，通过它然后在客户端调用它的方法，即可访问到服务端的书籍数据。比如下面的添加书籍和查询书籍。

```java
public class BookManagerActivity extends AppCompatActivity {

    private static final String TAG = "BookManagerActivity";
    private static final int MESSAGE_NEW_BOOK_ARRIVED = 1;
    private IBookManager mRemoteBookManager;

    private ServiceConnection mServiceConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
            mRemoteBookManager = IBookManager.Stub.asInterface(iBinder);
            try {
                //这里其实应该放到子线程中去调用,因为这个方法可能很耗时
                List<Book> bookList = mRemoteBookManager.getBookList();
                Log.e(TAG, "query book list,list type:" + bookList.getClass().
                        getCanonicalName());
                Log.e(TAG, "query book list:" + bookList.toString());

                //这里的调用方法运行在服务端binder线程中
                mRemoteBookManager.addBook(new Book(3, "开发艺术探索"));
                Log.e(TAG, "add book: 3");
                List<Book> newList = mRemoteBookManager.getBookList();
                Log.i(TAG, "query book list:" + newList.toString());

            } catch (RemoteException e) {
                e.printStackTrace();
            }
        }

        @Override
        public void onServiceDisconnected(ComponentName componentName) {
            mRemoteBookManager = null;
            Log.e(TAG, "binder died." + Thread.currentThread().getName());
            //可以在这里重新连接Service
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_book_manager);

        Intent intent = new Intent(this, BookManagerService.class);
        bindService(intent, mServiceConnection, Context.BIND_AUTO_CREATE);
    }

    @Override
    protected void onDestroy() {
        unbindService(mServiceConnection);
        super.onDestroy();
    }
}
```

## 二、Binder工作原理

![image](712DCBF8420642A894765F55C0157C1E)


```java
/*
 * This file is auto-generated.  DO NOT MODIFY.
 */
package com.xfhy.processdemo;
// Declare any non-default types here with import statements

//Binder接口的基类。定义新接口时，必须从IInterface派生它。
//进程间通信定义的通用接口
// 通过定义接口，然后再服务端实现接口、客户端调用接口，就可实现跨进程通信。
public interface IBookManager extends android.os.IInterface {
	//下面2个方法其实是aidl中定义的2个接口,AS自动帮我们生成了
    public java.util.List<com.xfhy.processdemo.Book> getBookList() throws android.os.RemoteException;

    public void addBook(com.xfhy.processdemo.Book book) throws android.os.RemoteException;

    /**
     * Local-side IPC implementation stub class.
	 // Binder机制在Android中的实现主要依靠的是Binder类，其实现了IBinder接口
    // IBinder接口：定义了远程操作对象的基本接口，代表了一种跨进程传输的能力
    // 系统会为每个实现了IBinder接口的对象提供跨进程传输能力
    // 即Binder类对象具备了跨进程传输的能力
	还实现了IBookManager接口
     */
    public static abstract class Stub extends android.os.Binder implements com.xfhy.processdemo.IBookManager {
		//标识是哪个方法
        static final int TRANSACTION_getBookList = (android.os.IBinder.FIRST_CALL_TRANSACTION + 0);
        static final int TRANSACTION_addBook = (android.os.IBinder.FIRST_CALL_TRANSACTION + 1);
        //Binder的标识  ServiceManager用该标识去查找对应的Binder引用,然后返回给Client
		private static final java.lang.String DESCRIPTOR = "com.xfhy.processdemo.IBookManager";

        /**
         * Construct the stub at attach it to the interface.
         */
        public Stub() {
			//// 1\. 将（descriptor，plus）作为（key,value）对存入到Binder对象中的一个Map<String,IInterface>对象中
          // 2\. 之后，Binder对象 可根据descriptor通过queryLocalIInterface（）获得对应IInterface对象（即plus）的引用，可依靠该引用完成对请求方法的调用
            this.attachInterface(this, DESCRIPTOR);
        }

        /**
         * Cast an IBinder object into an com.xfhy.processdemo.IBookManager interface,
         * generating a proxy if needed.
         */
        public static com.xfhy.processdemo.IBookManager asInterface(android.os.IBinder obj) {
            if ((obj == null)) {
                return null;
            }
			//作用：根据 参数 descriptor 查找相应的IInterface对象（即plus引用）
            android.os.IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
            if (((iin != null) && (iin instanceof com.xfhy.processdemo.IBookManager))) {
                return ((com.xfhy.processdemo.IBookManager) iin);
            }
            return new com.xfhy.processdemo.IBookManager.Stub.Proxy(obj);
        }

        @Override
        public android.os.IBinder asBinder() {
            return this;
        }

		// 定义：继承自IBinder接口的
        // 作用：执行Client进程所请求的目标方法（子类需要复写）
        // 参数说明：
        // code：Client进程请求方法标识符。即Server进程根据该标识确定所请求的目标方法
        // data：目标方法的参数。（Client进程传进来的，此处就是整数a和b）
        // reply：目标方法执行后的结果（返回给Client进程）
         // 注：运行在Server进程的Binder线程池中；当Client进程发起远程请求时，远程请求会要求系统底层执行回调该方法
        @Override
        public boolean onTransact(int code, android.os.Parcel data, android.os.Parcel reply, int flags) throws android.os.RemoteException {
            java.lang.String descriptor = DESCRIPTOR;
			//// code即在transact（）中约定的目标方法的标识符
            switch (code) {
                case INTERFACE_TRANSACTION: {
                    reply.writeString(descriptor);
                    return true;
                }
                case TRANSACTION_getBookList: {
					//// a. 解包Parcel中的数据
                    data.enforceInterface(descriptor);
                    java.util.List<com.xfhy.processdemo.Book> _result = this.getBookList();
                    reply.writeNoException();
                    reply.writeTypedList(_result);
                    return true;
                }
                case TRANSACTION_addBook: {
                    data.enforceInterface(descriptor);
                    com.xfhy.processdemo.Book _arg0;
                    if ((0 != data.readInt())) {
                        _arg0 = com.xfhy.processdemo.Book.CREATOR.createFromParcel(data);
                    } else {
                        _arg0 = null;
                    }
                    this.addBook(_arg0);
                    reply.writeNoException();
                    return true;
                }
                default: {
                    return super.onTransact(code, data, reply, flags);
                }
            }
        }

        private static class Proxy implements com.xfhy.processdemo.IBookManager {
            private android.os.IBinder mRemote;

            Proxy(android.os.IBinder remote) {
                mRemote = remote;
            }

            public java.lang.String getInterfaceDescriptor() {
                return DESCRIPTOR;
            }            @Override
            public android.os.IBinder asBinder() {
                return mRemote;
            }

            @Override
            public java.util.List<com.xfhy.processdemo.Book> getBookList() throws android.os.RemoteException {
				//// 1\. Client进程 将需要传送的数据写入到Parcel对象中
				// data = 数据 = 目标方法的参数（Client进程传进来的，如果有的话） + IInterface接口对象的标识符descriptor
                android.os.Parcel _data = android.os.Parcel.obtain();
				//reply：目标方法执行后的结果
                android.os.Parcel _reply = android.os.Parcel.obtain();
                java.util.List<com.xfhy.processdemo.Book> _result;
                try {
					// 方法对象标识符让Server进程在Binder对象中根据DESCRIPTOR通过queryLocalIInterface（）查找相应的IInterface对象（即Server创建的plus），Client进程需要调用的方法就在该对象中
                    _data.writeInterfaceToken(DESCRIPTOR);
					//通过 调用代理对象的transact（） 将 上述数据发送到Binder驱动
					//参数:方法标识符,入参,返回结果
                    mRemote.transact(Stub.TRANSACTION_getBookList, _data, _reply, 0);
                    _reply.readException();
                    _result = _reply.createTypedArrayList(com.xfhy.processdemo.Book.CREATOR);
                } finally {
                    _reply.recycle();
                    _data.recycle();
                }
                return _result;
            }

            @Override
            public void addBook(com.xfhy.processdemo.Book book) throws android.os.RemoteException {
                android.os.Parcel _data = android.os.Parcel.obtain();
                android.os.Parcel _reply = android.os.Parcel.obtain();
                try {
                    _data.writeInterfaceToken(DESCRIPTOR);
                    if ((book != null)) {
                        _data.writeInt(1);
                        book.writeToParcel(_data, 0);
                    } else {
                        _data.writeInt(0);
                    }
                    mRemote.transact(Stub.TRANSACTION_addBook, _data, _reply, 0);
                    _reply.readException();
                } finally {
                    _reply.recycle();
                    _data.recycle();
                }
            }

        }
    }
}

```