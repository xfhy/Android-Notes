
### 1. 原理

CopyOnWriteArrayList有点像线程安全的ArrayList.

其实它的原理简单概括起来就是读写分离.写操作是在一个复制的数组上进行的,读操作在原始数组中进行,读写是分离的.写操作的时候是加锁了的,写操作完成了之后将原来的数组指向新的数组.

下面我们简单看下add和get方法是如何实现写读操作的.

```java
/**
 * Appends the specified element to the end of this list.
 *
 * @param e element to be appended to this list
 * @return {@code true} (as specified by {@link Collection#add})
 */
public boolean add(E e) {
    final ReentrantLock lock = this.lock;
    lock.lock();
    try {
        Object[] elements = getArray();
        int len = elements.length;
        Object[] newElements = Arrays.copyOf(elements, len + 1);
        newElements[len] = e;
        setArray(newElements);
        return true;
    } finally {
        lock.unlock();
    }
}

@SuppressWarnings("unchecked")
private E get(Object[] a, int index) {
    return (E) a[index];
}

/**
 * {@inheritDoc}
 *
 * @throws IndexOutOfBoundsException {@inheritDoc}
 */
public E get(int index) {
    return get(getArray(), index);
}

```

### 2. 适用场景

因为每次写数据的时候都会开辟一个新的数组,这样就会耗费内存,而且加锁了,写的性能不是很好.而读操作是非常迅速的,并且还支持在写的同时可以读.

所以就非常适合读多写少的场景.

### 3. 缺点

- 内存消耗大: 每次写操作都需要复制一个新的数组,所以内存占用是非常大的
- 数据不一致: 读数据的时候可能读取到的不是最新的数据,因为可能部分写入的数据还未同步到读的数组中.

对内存敏感和实时性要求很高的场景都不适合.

### 4. CopyOnWriteArraySet

在翻阅CopyOnWriteArrayList源码过程中,偶然间发现CopyOnWriteArraySet的内部居然就是用一个CopyOnWriteArrayList实现的.

```java
public class CopyOnWriteArraySet<E> extends AbstractSet<E>
        implements java.io.Serializable {

    private final CopyOnWriteArrayList<E> al;

    /**
     * Adds the specified element to this set if it is not already present.
     * More formally, adds the specified element {@code e} to this set if
     * the set contains no element {@code e2} such that
     * <tt>(e==null&nbsp;?&nbsp;e2==null&nbsp;:&nbsp;e.equals(e2))</tt>.
     * If this set already contains the element, the call leaves the set
     * unchanged and returns {@code false}.
     *
     * @param e element to be added to this set
     * @return {@code true} if this set did not already contain the specified
     *         element
     */
    public boolean add(E e) {
        return al.addIfAbsent(e);
    }

}
```

而CopyOnWriteArrayList的addIfAbsent方法其实和add方法内部实现是差不多的(都是新复制数组且上锁),只不过多了层判断

```java
 /**
 * Appends the element, if not present.
 *
 * @param e element to be added to this list, if absent
 * @return {@code true} if the element was added
 */
public boolean addIfAbsent(E e) {
    Object[] snapshot = getArray();
    return indexOf(e, snapshot, 0, snapshot.length) >= 0 ? false :
        addIfAbsent(e, snapshot);
}

/**
 * A version of addIfAbsent using the strong hint that given
 * recent snapshot does not contain e.
 */
private boolean addIfAbsent(E e, Object[] snapshot) {
    final ReentrantLock lock = this.lock;
    lock.lock();
    try {
        Object[] current = getArray();
        int len = current.length;
        if (snapshot != current) {
            // Optimize for lost race to another addXXX operation
            int common = Math.min(snapshot.length, len);
            for (int i = 0; i < common; i++)
                if (current[i] != snapshot[i] && eq(e, current[i]))
                    return false;
            if (indexOf(e, current, common, len) >= 0)
                    return false;
        }
        Object[] newElements = Arrays.copyOf(current, len + 1);
        newElements[len] = e;
        setArray(newElements);
        return true;
    } finally {
        lock.unlock();
    }
}
```

### 5. 扩展 : CopyOnWriteHashMap

Java没有提供类似CopyOnWriteHashMap的类,可能是已经有ConcurrentHashMap了吧.明白了CopyOnWriteArrayList的思想,咱们其实还可以模仿着写一个简单的CopyOnWriteHashMap

```java
import java.util.Collection;
import java.util.Map;
import java.util.Set;
 
public class CopyOnWriteHashMap<K, V> implements Map<K, V>, Cloneable {
    private volatile Map<K, V> internalMap;
 
    public CopyOnWriteHashMap() {
        internalMap = new HashMap<K, V>();
    }
 
    public V put(K key, V value) {
        synchronized (this) {
            Map<K, V> newMap = new HashMap<K, V>(internalMap);
            V val = newMap.put(key, value);
            internalMap = newMap;
            return val;
        }
    }
 
    public V get(Object key) {
        return internalMap.get(key);
    }
}
```

### 6. CopyOnWriteArrayList为啥比Vector性能好?

在Vector内部,增删改查都进行了synchronized修饰,每个方法都要去锁,性能会大大降低.而CopyOnWriteArrayList只是把增删改加锁了,所以CopyOnWriteArrayList在读方面明显好于Vector.所以CopyOnWriteArrayList最好是在读多写少的场景下使用.


