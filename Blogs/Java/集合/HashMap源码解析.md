
我的所有原创[Android知识体系](https://github.com/xfhy/Android-Notes),已打包整理到GitHub.努力打造一系列适合初中高级工程师能够看得懂的优质文章,欢迎star~

## 1. 存储结构

### 1.1 JDK 1.7

内部是以数组的形式存储了Entry对象,而每个Entry对象里面有key和value用来存值.它里面包含了key、value、next、hash四个字段,其中next字段是用来引用下一个Entry的(相同的hash值会被放入同一个链表中).数组中的每个位置都是一条单链表(也可以称之为桶),数组中的元素的表头.解决冲突的方式是拉链法,同一条单链表中的Entry的hash值是相同的.

```java
transient Entry<K,V>[] table;

static class Entry<K,V> implements Map.Entry<K,V> {
        final K key;
        V value;
        Entry<K,V> next;
        int hash;
}
```

### 1.2 JDK 1.8

存储结构也是数组,只不过将Entry换了个名字叫Node.1.7中hash值相同的是放单链表中,1.8也是,当这个单链表的长度超过8时,会转换成红黑树,增加查找效率.

## 2. 基本概念

### 2.1 负载因子和阈值

```java
/**
 * The default initial capacity - MUST be a power of two.
 */
static final int DEFAULT_INITIAL_CAPACITY = 1 << 4; // aka 16

/**
 * The load factor used when none specified in constructor.
 */
static final float DEFAULT_LOAD_FACTOR = 0.75f;
```

HashMap的默认大小是16,默认负载因子是0.75,意思是当存的元素个数超过`16*0.75`时就要对数组扩容,这里的阈值就是`16*0.75=12`.负载因子就是用来控制什么时候进行扩容的.

`阈值 = 当前数组长度*负载因子`

每次扩容之后都得重新计算阈值.默认的数组长度是16,默认的负载因子是0.75这些都是有讲究的.在元素个数达到数组的75%时进行扩容是一个比较折中的临界点,如果定高了的话hash冲突就很严重,桶就会很深,查找起来比较慢,定低了又浪费空间.一般情况下,还是不会去定制这个负载因子.

ps: 到底是**阀值**还是**阈值**,傻傻分不清,,,,知乎上有个关于这个问题的讨论 - [ 「阀值」是否为「阈值」的误笔？](https://www.zhihu.com/question/20642950)

### 2.2 拉链法工作原理

每次新存入一个新的键值对时,首先计算Entry的hashCode,用hashCode%数组长度得到所在桶下标,然后在桶内依次查找是否已存在该元素,存在则更新,不存在则插入到桶的头部.

## 3. 源码分析

### 3.1 JDK 1.7

有了上面的基础概念,下面开始看源码学习

```java
public class HashMap<K,V>
    extends AbstractMap<K,V>
    implements Map<K,V>, Cloneable, Serializable
{
    //默认初始容量,必须是2的幂   这里的值是16
    static final int DEFAULT_INITIAL_CAPACITY = 1 << 4; // aka 16
    //最大容量
    static final int MAXIMUM_CAPACITY = 1 << 30;
    //默认的负载因子
    static final float DEFAULT_LOAD_FACTOR = 0.75f;
    //默认的空数组
    static final Entry<?,?>[] EMPTY_TABLE = {};
    //用来盛放真实数据的数组
    transient Entry<K,V>[] table = (Entry<K,V>[]) EMPTY_TABLE;
    //当前HashMap的真实键值对数量
    transient int size;
    //阈值 = 数组长度*负载因子
    int threshold;
    //负载因子
    final float loadFactor;
    //标识对该HashMap进行结构修改的次数,结构修改是指增删改或其他修改其内部结构(例如rehash)的次数.
    //用于迭代器快速失败.
    transient int modCount;
    
    public HashMap() {
        this(DEFAULT_INITIAL_CAPACITY, DEFAULT_LOAD_FACTOR);
    }
    
    public HashMap(int initialCapacity) {
        this(initialCapacity, DEFAULT_LOAD_FACTOR);
    }
    
    //可以同时制定数组大小和负载因子
    public HashMap(int initialCapacity, float loadFactor) {
        ...//省略部分逻辑判断
        if (initialCapacity > MAXIMUM_CAPACITY)
            initialCapacity = MAXIMUM_CAPACITY;
        ...
        this.loadFactor = loadFactor;
        threshold = initialCapacity;
        ...
    }
    
    static class Entry<K,V> implements Map.Entry<K,V> {
        final K key;
        V value;
        Entry<K,V> next;
        int hash;
    }
    
}
```

#### 3.1.1 put

上面是HashMap的一些基本属性,都是相对比较重要的.接着我们来看一下添加元素put方法的实现,以下是JDK 1.7的put代码
```java
public V put(K key, V value) {
    //1. 数组为空 -> 初始化(创建)数组
    if (table == EMPTY_TABLE) {
        inflateTable(threshold);
    }
    //2. key为null,单独处理
    if (key == null)
        return putForNullKey(value);
    //3. 计算hash值
    int hash = hash(key);
    //4. 计算该hash值该存放在数组的哪个索引处
    int i = indexFor(hash, table.length);
    //5. 遍历链表(数组的每个元素都是单链表的表头)  查找链表中是否已存在相同的key  如果有,则替换掉
    for (Entry<K,V> e = table[i]; e != null; e = e.next) {
        Object k;
        if (e.hash == hash && ((k = e.key) == key || key.equals(k))) {
            V oldValue = e.value;
            e.value = value;
            e.recordAccess(this);
            return oldValue;
        }
    }

    modCount++;
    //6. 添加元素到数组中
    addEntry(hash, key, value, i);
    return null;
}
```

##### 3.1.1.1 inflateTable 数组初始化

简简单单几句代码涉及的东西缺特别多,我们逐个来解读一下.首先是初始化数组inflateTable方法,传入的是阈值.

```java
private void inflateTable(int toSize) {
    // Find a power of 2 >= toSize
    int capacity = roundUpToPowerOf2(toSize);

    threshold = (int) Math.min(capacity * loadFactor, MAXIMUM_CAPACITY + 1);
    table = new Entry[capacity];
    initHashSeedAsNeeded(capacity);
}

private static int roundUpToPowerOf2(int number) {
    // assert number >= 0 : "number must be non-negative";
    return number >= MAXIMUM_CAPACITY
            ? MAXIMUM_CAPACITY
            : (number > 1) ? Integer.highestOneBit((number - 1) << 1) : 1;
}

//Integer.highestOneBit
public static int highestOneBit(int var0) {
    //求掩码
    var0 |= var0 >> 1;
    var0 |= var0 >> 2;
    var0 |= var0 >> 4;
    var0 |= var0 >> 8;
    var0 |= var0 >> 16; 
    
    //>>>：无符号右移。无论是正数还是负数，高位通通补0.  这里减了之后只剩下最高位为1
    return var0 - (var0 >>> 1);
}

```
roundUpToPowerOf2方法是为了求一个比number大一点的2的幂次方的数,这里的代码看起来有点迷.它最后会求出数组应该初始化的长度,它可以自动将传入的容量转换为2的n次方.

Integer.highestOneBit是取传入的这个数的二进制形式最左边的最高一位且高位后面全部补零,最后返回int类型的结果.比如传入的是7(0111),则最后得到的是4(0100).它这里先将number-1,然后再左移一位,比如number是9,则number-1等于8(1000),左移一位等于10000就是16.这样最后它就将传入的容量转换为了2的n次方.

计算好了容量之后,计算阈值,然后初始化数组.

##### 3.1.1.2 putForNullKey 添加null key

用了一个专门的方法用来操作key为null的情况

```java
/**
 * Offloaded version of put for null keys
 */
private V putForNullKey(V value) {
    for (Entry<K,V> e = table[0]; e != null; e = e.next) {
        if (e.key == null) {
            V oldValue = e.value;
            e.value = value;
            e.recordAccess(this);
            return oldValue;
        }
    }
    modCount++;
    addEntry(0, null, value, 0);
    return null;
}
```

将元素存放到了数组的第一个位置.第一个位置也是一个桶,这桶里面只有一个元素的key可以是null,其他元素都是被hash算法分配到这里来的.

##### 3.1.1.3 计算hash值

```java
/**
 * Retrieve object hash code and applies a supplemental hash function to the
 * result hash, which defends against poor quality hash functions.  This is
 * critical because HashMap uses power-of-two length hash tables, that
 * otherwise encounter collisions for hashCodes that do not differ
 * in lower bits. Note: Null keys always map to hash 0, thus index 0.
 */
final int hash(Object k) {
    int h = hashSeed;
    if (0 != h && k instanceof String) {
        return sun.misc.Hashing.stringHash32((String) k);
    }

    h ^= k.hashCode();

    // This function ensures that hashCodes that differ only by
    // constant multiples at each bit position have a bounded
    // number of collisions (approximately 8 at default load factor).
    h ^= (h >>> 20) ^ (h >>> 12);
    return h ^ (h >>> 7) ^ (h >>> 4);
}
```

获取到了key的hashCode之后,又进行了一些骚操作,这里的hash算法设计得很神,这里的hash算法设计得好的话,则会大大减少hash冲突.

##### 3.1.1.4 indexFor 计算元素在数组中的索引

```java
 /**
 * Returns index for hash code h.
 */
static int indexFor(int h, int length) {
    // assert Integer.bitCount(length) == 1 : "length must be a non-zero power of 2";
    return h & (length-1);
}
```
用hash值按位与数组长度-1,相当于 h % length.&运算比%效率高,所以这里是&运算来进行.为什么`h & (length-1) = h % length` ? 这其实与length有关,length上面说过,必须是2的幂.我们简单举个例子,h=2,length=8.

```
h & (length-1)
= 00000010 & 00000111
= 00000010
```

上面的最后结果是2 , `2 % 8` 确实是等于2,验证完毕.

##### 3.1.1.5 addEntry 添加元素到数组中

添加元素的时候可能之前这个位置是空桶,也可能之前这里的桶已经有元素存在了(hash冲突了).

```java
/**
 * Adds a new entry with the specified key, value and hash code to
 * the specified bucket.  It is the responsibility of this
 * method to resize the table if appropriate.
 *
 * Subclass overrides this to alter the behavior of put method.
 */
void addEntry(int hash, K key, V value, int bucketIndex) {
    //1. 键值对数量超过阈值 && 该索引处数组不为空(说明这里之前已经存在元素)
    if ((size >= threshold) && (null != table[bucketIndex])) {
        //扩容->原来的2倍
        resize(2 * table.length);
        hash = (null != key) ? hash(key) : 0;
        bucketIndex = indexFor(hash, table.length);
    }

    //2. 创建Entry节点
    createEntry(hash, key, value, bucketIndex);
}

//创建新的节点  
void createEntry(int hash, K key, V value, int bucketIndex) {
    //table[bucketIndex] 是放到新插入节点的后面,,所以这里是头插法
    Entry<K,V> e = table[bucketIndex];
    table[bucketIndex] = new Entry<>(hash, key, value, e);
    size++;
}

```

键值对超过阈值就会扩容

```java
void resize(int newCapacity) {
    Entry[] oldTable = table;
    int oldCapacity = oldTable.length;
    if (oldCapacity == MAXIMUM_CAPACITY) {
        threshold = Integer.MAX_VALUE;
        return;
    }

    //根据新的容量创建数组
    Entry[] newTable = new Entry[newCapacity];
    //转移数据到新数组
    transfer(newTable, initHashSeedAsNeeded(newCapacity));
    table = newTable;
    //更新阈值
    threshold = (int)Math.min(newCapacity * loadFactor, MAXIMUM_CAPACITY + 1);
}

//转移数据到新数组
void transfer(Entry[] newTable, boolean rehash) {
    int newCapacity = newTable.length;
    for (Entry<K,V> e : table) {
        //元素非空 则转移
        while(null != e) {
            Entry<K,V> next = e.next;
            if (rehash) {
                e.hash = null == e.key ? 0 : hash(e.key);
            }
            //根据该节点hash值计算一下该节点该放到新数组的哪个索引处
            int i = indexFor(e.hash, newCapacity);
            //将桶内元素逐个转移到新的数组的新的索引处
            //注意: 这里桶内顺序会倒过来.
            //比如桶内是1->2->3   转移数据之后就是3->2->1
            e.next = newTable[i];
            newTable[i] = e;
            e = next;
        }
    }
}

```

扩容之后就涉及到数据的迁移,迁移的时候需要重新计算节点在新数组中的位置,迁移完成还得更新一下阈值.

JDK 1.7中的put操作就是这些啦,东西还挺多的. 最核心的也就是put部分的代码,get的话比较简单这里就不做分析了.

### 3.2 JDK 1.8

基本上思路是差不多的,也是用数组+链表(or 红黑树)来装数据.

```java
transient Node<K,V>[] table;

//链表长度超过8且数组长度大于64,则将链表转换成红黑树
static final int TREEIFY_THRESHOLD = 8;

//在1.8中节点改名字了.. 改成了Node
static class Node<K,V> implements Map.Entry<K,V> {
    final int hash;
    final K key;
    V value;
    Node<K,V> next;
}

```

来看看它的put方法是怎么实现的

#### 3.2.1 put

1.8的put方法稍微比1.7的看起来复杂些,但是不用怕,我们一句一句的分析

```java
public V put(K key, V value) {
    return putVal(hash(key), key, value, false, true);
}

/**
 * Implements Map.put and related methods.
 *
 * @param hash hash for key
 * @param key the key
 * @param value the value to put
 * @param onlyIfAbsent if true, don't change existing value
 * @param evict if false, the table is in creation mode.
 * @return previous value, or null if none
 */
final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
               boolean evict) {
    Node<K,V>[] tab; Node<K,V> p; int n, i;

    //1. table为空表时,创建数组 初始化.  resize既是初始化也是扩容
    if ((tab = table) == null || (n = tab.length) == 0)
        n = (tab = resize()).length;
    //2. 根据hash和数组长度求出元素应该在数组中的索引位置,如果此处为空则将节点放到这里
    if ((p = tab[i = (n - 1) & hash]) == null)
        tab[i] = newNode(hash, key, value, null);
    else {
        Node<K,V> e; K k;
        //3. 该索引处已经有节点存在且hash值和key都相等(需要替换value),则记录下该索引处的节点引用
        if (p.hash == hash &&
            ((k = p.key) == key || (key != null && key.equals(k))))
            e = p;
        //4. 如果该索引处是红黑树,则将节点插入到树中
        else if (p instanceof TreeNode)
            e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
        //5. 该索引处是链表
        else {
            //5.1 依次遍历链表
            for (int binCount = 0; ; ++binCount) {
                //5.2 找到链表尾部,将节点插入到尾部
                if ((e = p.next) == null) {
                    p.next = newNode(hash, key, value, null);
                    //如果链表长度超过8,则转换成红黑树
                    if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                        treeifyBin(tab, hash);
                    break;
                }
                //5.3 找到key相等的了,则结束for循环,已在链表中找到需要替换value的节点
                if (e.hash == hash &&
                    ((k = e.key) == key || (key != null && key.equals(k))))
                    break;
                p = e;
            }
        }
        //6. 替换原来的值
        if (e != null) { // existing mapping for key
            V oldValue = e.value;
            if (!onlyIfAbsent || oldValue == null)
                e.value = value;
            afterNodeAccess(e);
            return oldValue;
        }
    }
    ++modCount;
    //7. 超过阈值,则扩容
    if (++size > threshold)
        resize();
    afterNodeInsertion(evict);
    return null;
}
```

注释写得比较详细,这里与1.7的区别还是挺大的.

- **Java7中将节点插入链表是头插法,而Java8是尾插法**
- Java8中链表超过8且数组长度大于64则会将链表树化
- Java7将key为null的单独处理,Java8没有单独处理(虽然它们的hash都是0,都是放数组第0处)

#### 3.2.1.1 resize 扩容

首先来关注核心代码,扩容.

```java
/**
 * Initializes or doubles table size.  If null, allocates in
 * accord with initial capacity target held in field threshold.
 * Otherwise, because we are using power-of-two expansion, the
 * elements from each bin must either stay at same index, or move
 * with a power of two offset in the new table.
 *
 * @return the table
 */
final Node<K,V>[] resize() {
    Node<K,V>[] oldTab = table;
    //老数组长度
    int oldCap = (oldTab == null) ? 0 : oldTab.length;
    int oldThr = threshold;
    //新数组长度  新阈值
    int newCap, newThr = 0;
    if (oldCap > 0) {
        //老数组长度大于MAXIMUM_CAPACITY,则将阈值设置成Integer.MAX_VALUE  不扩容了..
        //一般情况下,不会走到这个逻辑分支里面去
        if (oldCap >= MAXIMUM_CAPACITY) {
            threshold = Integer.MAX_VALUE;
            return oldTab;
        }
        //1. 扩容: 将数组长度*2
        else if ((newCap = oldCap << 1) < MAXIMUM_CAPACITY &&
                 oldCap >= DEFAULT_INITIAL_CAPACITY)
            //阈值也是*2
            newThr = oldThr << 1; // double threshold
    }
    else if (oldThr > 0) // initial capacity was placed in threshold
        newCap = oldThr;
    else {               // zero initial threshold signifies using defaults
        //2. 初始化数组
        newCap = DEFAULT_INITIAL_CAPACITY;
        newThr = (int)(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
    }
    if (newThr == 0) {
        float ft = (float)newCap * loadFactor;
        newThr = (newCap < MAXIMUM_CAPACITY && ft < (float)MAXIMUM_CAPACITY ?
                  (int)ft : Integer.MAX_VALUE);
    }
    threshold = newThr;
    @SuppressWarnings({"rawtypes","unchecked"})
    Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
    table = newTab;
    if (oldTab != null) {
        //3. 遍历旧数组
        for (int j = 0; j < oldCap; ++j) {
            Node<K,V> e;
            if ((e = oldTab[j]) != null) {
                oldTab[j] = null;
                //3.1 该索引处 桶内只有一个元素,根据该节点的hash和新数组长度求出该节点在新数组中的位置,然后放置到新数组中
                if (e.next == null)
                    newTab[e.hash & (newCap - 1)] = e;
                //3.2 该索引处为红黑树  单独处理
                else if (e instanceof TreeNode)
                    ((TreeNode<K,V>)e).split(this, newTab, j, oldCap);
                //3.3 该索引处为单链表(链表长度小于8)
                else { // preserve order
                    //不用挪动位置的链表,hash值&老数组长度为0,loHead为头部,loTail为尾部
                    Node<K,V> loHead = null, loTail = null;
                    //需要挪动位置的链表,hash值&老数组长度为1,hiHead为头部,hiTail为尾部
                    Node<K,V> hiHead = null, hiTail = null;
                    Node<K,V> next;
                    do {
                        next = e.next;
                        //hash值&老数组长度
                        // 其实就是求最高位是0还是1,是0则保持原位置不动;是1则需要移动到 j + oldCap 处
                        //每条链表都被分散成2条,更分散
                        if ((e.hash & oldCap) == 0) {
                            if (loTail == null)
                                loHead = e;
                            else
                                loTail.next = e;
                            loTail = e;
                        }
                        else {
                            if (hiTail == null)
                                hiHead = e;
                            else
                                hiTail.next = e;
                            hiTail = e;
                        }
                    } while ((e = next) != null);
                    //这些元素还是在老索引处
                    if (loTail != null) {
                        loTail.next = null;
                        newTab[j] = loHead;
                    }
                    //这些元素移动到了 老索引位置+oldCap  处
                    if (hiTail != null) {
                        hiTail.next = null;
                        newTab[j + oldCap] = hiHead;
                    }
                }
            }
        }
    }
    return newTab;
}
```

resize的东西比较杂,即包含了初始化数组,也包含了扩容的逻辑.初始化数组比较简单,咱直接看一下扩容部分逻辑.首先是遍历原数组,此时原数组的每个索引处可能存在3种情况

1. 该索引处桶内只有一个元素->根据该节点的hash和新数组长度求出该节点在新数组中的位置,然后放置到新数组中
2. 该索引处为红黑树->单独处理
3. 该索引处链表长度大于1,小于8

第3种情况比较复杂,这里单独分析一下.

分析前我们来看个东西,假设数组长度n=16,那么根据put部分的代码,存入数组时索引是`(16 - 1) & hash`,这里有2个元素key1和key2,它们的hash值分别为5和21.下面是它们的计算过程

```
key1:
00001111 & 00000101 = 5

key2:
00001111 & 00010101 = 5
```

当数组扩容,n=32

```
key1:
00011111 & 00000101 = 00101 = 5

key2:
00011111 & 00010101 = 10101 = 5 + 16 = 21
```
扩容后n-1比以前多了1个1,这样会导致按位与的时候key2的位置变成了原位置+16的位置.因为我们使用的是2次幂的扩展,所以元素的位置要么在原位置,要么在原位置+2次幂的位置.

有了上面的分析之后,再回到我们3.3处的逻辑
```java
if ((e.hash & oldCap) == 0) {
    if (loTail == null)
        loHead = e;
    else
        loTail.next = e;
    loTail = e;
} else {
    if (hiTail == null)
        hiHead = e;
    else
        hiTail.next = e;
    hiTail = e;
}
```

`e.hash & oldCap`: 用元素hash值与上老数组长度,假设之前数组长度是16,那么这里就是按位与`10000`,而平时put的时候算索引是按位与(n-1)也就是`1111`.扩容之后,在put的时候就得按位与`11111`.因此它这里只是想看看hash值新增的那个bit是1还是0.如果是0则保留老位置,是1的话则在老位置的基础上加老数组长度才是新的位置.

为什么要这么干?  主要是计算简单,不需要像JDK 1.7那样还需要重新计算hash.还有就是让元素更分散.本来原来是一条链上的,现在在2条链上(不同的数组索引处)了,查找更快了.

需要注意的一个小点就是,这里是尾插法且还是原来的顺序,而JDK 1.7是头插法且顺序与想来相反.

扩容的内容大概就是这些,稍微有点多.

## 4. 相关知识点

### 4.1 HashMap 1.7和1.8区别

1. JDK1.7用的是头插法,JDK1.8及置换是尾插法. 且1.7插入时候顺序是与原来相反的,而1.8则还是原来的顺序
2. JDK1.7是数组+链表,JDK1.8是数组+链表+红黑树
3. JDK1.7在插入数据之前进行扩容,JDK1.8是插入数据之后才扩容
4. JDK1.7是Entry来表示节点,而JDK1.8是Node
5. JDK1.7扩容和后存储位置是用`hash & (length-1)`计算来的,而JDK1.8只需要判断hash值新增参与运算的位是0还是1就能快速计算出扩容后该放在原位置,还是需要放在 原位置+扩容的大小值 .
6. 计算hash值的时候,JDK1.7用了9次扰动处理,而JDK1.8是2次

ps: 红黑树查找元素,需要O（logn）的开销

### 4.2 Hashtable与HashMap的区别

1. Hashtable不支持null键和值
2. Hashtable使用synchronized来进行同步(有性能开销)
3. Hashtable的迭代器是fail-fast迭代器
4. Hashtable默认容量为11且不要求底层数组的容量一定要是2的整数次幂,而HashMap则是16,必须是2的整数次幂.

> HashMap是绝大部分利用键值对存取场景的首选.多线程环境下,推荐使用ConcurrentHashMap.


## 参考

1. [图解HashMap(一)](https://juejin.im/post/6844903518474600455)
2. [图解HashMap(二)](https://juejin.im/post/6844903518927601671)
3. [Java 容器](https://github.com/CyC2018/CS-Notes/blob/master/notes/Java%20%E5%AE%B9%E5%99%A8.md#hashmap)
4. [openjdk集合源码](http://hg.openjdk.java.net/jdk7u/jdk7u60/jdk/file/33c1eee28403/src/share/classes/java/util)