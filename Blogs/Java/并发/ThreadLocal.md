ThreadLocal
---

### 使用场景

1. **保存每个线程独享的对象**.为每个线程都创建一个副本,每个线程都只能修改自己所拥有的副本,不会影响其他线程的副本,这样让原本在并发情况下,线程不安全的情况变成了线程安全的情况.
2. **每个线程内需要独立保存信息**.**供其他方法更方便得获取该信息**,每个线程获取到的信息都可能不一样,前面执行的方法设置了信息后,后续方法可以通过ThreadLocal直接获取到,避免了传参.

#### ThreadLocal是用来解决共享资源的多线程访问的问题?

**明显不是**.ThreadLocal的资源并不是共享的,而是每个线程独享的.

#### ThreadLocal与synchronized的关系

- ThreadLocal是通过让每个线程独享自己的副本,避免了资源的竞争
- synchronized主要用于临界资源的分配,在同一时刻限制最多只有一个线程能访问该资源

### ThreadLocal存储

#### Thread,ThreadLocal,ThreadLocalMap之间的关系

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/Thread%2CThreadLocal%2CThreadLocalMap%E4%B9%8B%E9%97%B4%E7%9A%84%E5%85%B3%E7%B3%BB.png)

每个线程里面只有一个ThreadLocalMap,ThreadLocalMap里面对应着多个ThreadLocal,每个ThreadLocal里面对应着一个value.

#### 源码分析

在了解了宏观上三者之间的关系之后,来看一下它们内部的实现

**Thread属性**
```java
public
class Thread implements Runnable {
    private volatile String name;
    private int            priority;
    private Thread         threadQ;
    private long           eetop;

    /* Whether or not to single_step this thread. */
    private boolean     single_step;

    /* Whether or not the thread is a daemon thread. */
    private boolean     daemon = false;

    /* JVM state */
    private boolean     stillborn = false;

    /* What will be run. */
    private Runnable target;

    /* The group of this thread */
    private ThreadGroup group;

    /* The context ClassLoader for this thread */
    private ClassLoader contextClassLoader;

    /* ThreadLocal values pertaining to this thread. This map is maintained
     * by the ThreadLocal class. */
    ThreadLocal.ThreadLocalMap threadLocals = null;
    
    ......

}
```

在Thread的属性中,我们发现ThreadLocal.ThreadLocalMap的对象.根据注释,这个对象是用来存储与该线程相关的ThreadLocal的,这个对象是ThreadLocal在管理.

**ThreadLocal#get()**

```java
/**
 * Returns the value in the current thread's copy of this
 * thread-local variable.  If the variable has no value for the
 * current thread, it is first initialized to the value returned
 * by an invocation of the {@link #initialValue} method.
 *
 * @return the current thread's value of this thread-local
 */
public T get() {
    //获取当前线程
    Thread t = Thread.currentThread();
    //获取当前线程的ThreadLocalMap对象,每个线程内都是有一个ThreadLocalMap对象的
    ThreadLocalMap map = getMap(t);
    if (map != null) {
        //获取ThreadLocalMap中的Entry对象
        ThreadLocalMap.Entry e = map.getEntry(this);
        if (e != null) {
            //拿到value
            @SuppressWarnings("unchecked")
            T result = (T)e.value;
            return result;
        }
    }
    
    //如果线程之前是没有初始化ThreadLocalMap的,则初始化一下
    return setInitialValue();
}

/**
 * Get the map associated with a ThreadLocal. Overridden in
 * InheritableThreadLocal.
 *
 * @param  t the current thread
 * @return the map
 */
ThreadLocalMap getMap(Thread t) {
    return t.threadLocals;
}

```

get()方法还是比较简单的,从当前线程(Thread)的ThreadLocalMap中取数据,然后返回.如果没有初始化,则初始化一下.

**ThreadLocal#set()**

```java
/**
 * Sets the current thread's copy of this thread-local variable
 * to the specified value.  Most subclasses will have no need to
 * override this method, relying solely on the {@link #initialValue}
 * method to set the values of thread-locals.
 *
 * @param value the value to be stored in the current thread's copy of
 *        this thread-local.
 */
public void set(T value) {
    Thread t = Thread.currentThread();
    //从当前Thread中拿ThreadLocalMap
    ThreadLocalMap map = getMap(t);
    if (map != null)
        //将当前ThreadLocal和value存入map中
        map.set(this, value);
    else
        //初始化,并存入数据
        createMap(t, value);
}
```

set 方法的作用是把我们想要存储的 value 给保存进去.可以看出,首先，它还是需要获取到当前线程的引用，并且利用这个引用来获取到 ThreadLocalMap;然后,如果 map == null 则去创建这个 map,而当 map != null 的时候就利用 map.set 方法,把 value 给 set 进去.

**ThreadLocalMap**

```java
static class ThreadLocalMap {

    /**
     * The entries in this hash map extend WeakReference, using
     * its main ref field as the key (which is always a
     * ThreadLocal object).  Note that null keys (i.e. entry.get()
     * == null) mean that the key is no longer referenced, so the
     * entry can be expunged from table.  Such entries are referred to
     * as "stale entries" in the code that follows.
     */
    static class Entry extends WeakReference<ThreadLocal<?>> {
        /** The value associated with this ThreadLocal. */
        Object value;

        Entry(ThreadLocal<?> k, Object v) {
            super(k);
            value = v;
        }
    }

    /**
     * The initial capacity -- MUST be a power of two.
     */
    private static final int INITIAL_CAPACITY = 16;

    /**
     * The table, resized as necessary.
     * table.length MUST always be a power of two.
     */
    private Entry[] table;

    /**
     * The number of entries in the table.
     */
    private int size = 0;

    /**
     * The next size value at which to resize.
     */
    private int threshold; // Default to 0
}
```

ThreadLocalMap是ThreadLocal的一个静态内部类,ThreadLocalMap有一个Entry的内部类,它是一个键值对,key是ThreadLocal,value是需要存储的业务变量.ThreadLocalMap 类似于 Map,和 HashMap 一样,也会有包括 set、get、rehash、resize 等一系列标准操作.但是,虽然思路和 HashMap 是类似的,但是具体实现会有一些不同.

ThreadLocalMap 解决 hash 冲突的方式是不一样的,它采用的是线性探测法.如果发生冲突,并不会用链表的形式往下链,而是会继续寻找下一个空的格子.这是 ThreadLocalMap 和 HashMap 在处理冲突时不一样的点.