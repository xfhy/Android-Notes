
## 1. 存储结构

数组+链表+红黑树

## 2. ConcurrentHashMap存在的意义?

有了HashMap和Hashtable为啥还需要ConcurrentHashMap? 

**HashMap本身不是线程安全的,不应该在多线程情况下使用!!!**.

Hashtable是使用synchronized保证线程安全,当一个线程访问其中一个同步方法时,另外的线程是不能访问其同步方法的(竞争的是同一把锁).这样就会导致在put数据的时候,其他线程也不能get数据之类的操作.在线程竞争激烈的条件下,并发效率非常低.

既要多线程环境下使用,也要效率高? 选ConcurrentHashMap没错了.ConcurrentHashMap使用的是分段锁(Segment)技术,将数组分成很多段,每个分段锁维护着几个桶(HashEntry),然后修改数据的时候将这一段锁起来,其他线程这个时候要操作其他分段的数据也互不干扰.如果操作的不是同一分段,则线程间不存在竞争关系,大大提高了并发效率. 当然,有的朋友可能也想到了,有些时候可能需要跨段,比如调用size()方法,这个时候可能会锁整个表.

而在JDK1.8中抛弃了Segment分段锁机制,利用CAS+synchronized来保证并发更新的安全.

## 3. 与HashMap的区别

相同之处:

- 数组、链表结构几乎相同，所以底层对数据结构的操作思路是相同的
- 都实现了 Map 接口，大多数方法也都是相同的

不同之处:

- 红黑树的结构略有不同,HashMap的红黑树中的节点叫做TreeNode,TreeNode不仅有属性还维护着红黑树的结构,比如查找、新增等等;ConcurrentHashMap中红黑树被拆分成两块,TreeNode仅仅维护属性和查找功能,新增了TreeBin来维护红黑树的结构,并负责根节点的加锁和解锁
- 新增ForwardingNode转移节点,扩容时会用到,通过该节点来保证扩容时的线程安全

因在实现上大多数方法是相同的,我们只需要关注不同的地方即可,下面我们来简单看看不同的地方.

> ps: 以下源码分析为JDK 1.8

## 4. 数组初始化

在看数组初始化之前,我们先了解一下CAS乐观锁技术.乐观锁是一种思想,CAS是这种思想的其中一种实现方式.当多个线程尝试使用CAS同时更新同一个变量时,只有其中一个线程能更新变量的值,而其他线程都失败,失败的线程并不会挂起,而是被告知这次竞争失败,并可以再次尝试.  CAS操作中包含3个操作数: 需要读写的位置(V)、进行比较的预期原值(A)和拟写入的新值(B).如果内存位置V的值与预期原值A相匹配,那么处理器会自动将该位置值更新为新值B.否则处理器不做任何操作.

下面我们来看源码,和HashMap一样,数组的初始化会延迟到第一次put行为(put部分源码分析放后面).不一样的是ConcurrentHashMap的put是可以并发执行的,那么它是如何实现数组只初始化一次的?

```java
/**
 * Initializes table, using the size recorded in sizeCtl.
 */
private final Node<K,V>[] initTable() {
    Node<K,V>[] tab; int sc;
    //1. 通过死循环来保证一定能初始化成功,通过对sizeCtl变量的赋值来保证只被初始化一次
    while ((tab = table) == null || tab.length == 0) {
        //2. sizeCtl小于0,表示有其他线程正在初始化,释放当前CPU的调度权,重新发起锁的竞争,自旋
        if ((sc = sizeCtl) < 0)
            Thread.yield(); // lost initialization race; just spin
        //3. CAS 赋值,保证当前只有一个线程正在初始化,如果第一次初始化这里会将sizeCtl的值赋值为-1,
        //保证了数组的初始化安全性
        else if (U.compareAndSwapInt(this, SIZECTL, sc, -1)) {
            try {
                //4. 可能执行到这里的时候,table已经不为空了,双重check
                if ((tab = table) == null || tab.length == 0) {
                    //5. 初始化数组
                    int n = (sc > 0) ? sc : DEFAULT_CAPACITY;
                    @SuppressWarnings("unchecked")
                    Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n];
                    table = tab = nt;
                    //>>>：无符号右移,无论是正数还是负数,高位通通补0
                    sc = n - (n >>> 2);
                }
            } finally {
                sizeCtl = sc;
            }
            break;
        }
    }
    return tab;
}
```

一句话总结: **自旋+CAS+双重check**等手段来保证了数组初始化时的线程安全.

## 5. put操作

整体上是和HashMap差不多的,但是在线程安全方面写了很多保障的代码.

```java
final V putVal(K key, V value, boolean onlyIfAbsent) {
    //不能插入null
    if (key == null || value == null) throw new NullPointerException();
    //1. 计算hash值
    int hash = spread(key.hashCode());
    int binCount = 0;
    //2. 死循环 自旋
    for (Node<K,V>[] tab = table;;) {
        Node<K,V> f; int n, i, fh;
        //2.1 初始化数组
        if (tab == null || (n = tab.length) == 0)
            tab = initTable();
        //2.2 如果该索引处值为空,则通过CAS创建,创建成功则退出for循环,创建失败则自旋
        else if ((f = tabAt(tab, i = (n - 1) & hash)) == null) {
            if (casTabAt(tab, i, null,
                         new Node<K,V>(hash, key, value, null)))
                break;                   // no lock when adding to empty bin
        }
        //2.3 转移节点的hash值都是MOVED(详情见ForwardingNode构造方法)
        //如果当前节点是转移节点,则该索引处正在扩容,就会一直自旋等待扩容完成
        else if ((fh = f.hash) == MOVED)
            tab = helpTransfer(tab, f);
        //2.4 该索引处是有值的
        else {
            V oldVal = null;
            //2.4.1 锁定当前节点,其他线程不能操作,保证安全
            synchronized (f) {
                //2.4.1.1 再次判断i索引处的数据没有被修改
                if (tabAt(tab, i) == f) {
                    //链表
                    if (fh >= 0) {
                        //binCount被赋值,表示正在修改表
                        binCount = 1;
                        //遍历链表
                        for (Node<K,V> e = f;; ++binCount) {
                            K ek;
                            //替换之前的值,退出自旋
                            if (e.hash == hash &&
                                ((ek = e.key) == key ||
                                 (ek != null && key.equals(ek)))) {
                                oldVal = e.val;
                                if (!onlyIfAbsent)
                                    e.val = value;
                                break;
                            }
                            Node<K,V> pred = e;
                            //需要新增元素,则插入到最后,退出自旋
                            if ((e = e.next) == null) {
                                pred.next = new Node<K,V>(hash, key,
                                                          value, null);
                                break;
                            }
                        }
                    }
                    //2.4.1.2 红黑树,这里没有使用TreeNode,而是使用TreeBin,TreeNode指数红黑树的一个节点
                    //TreeBin持有红黑树的引用,且会对其加锁,保证其操作的线程安全
                    else if (f instanceof TreeBin) {
                        Node<K,V> p;
                        //binCount标记为2,表示正在修改表
                        binCount = 2;
                        //如果能put到树中,则替换原来的旧值
                        //在putTreeVal方法中,在给红黑树重新着色旋转的时候,会锁住红黑树的根节点
                        if ((p = ((TreeBin<K,V>)f).putTreeVal(hash, key,
                                                       value)) != null) {
                            oldVal = p.val;
                            if (!onlyIfAbsent)
                                p.val = value;
                        }
                    }
                }
            }
            //2.4.2 binCount不是0,说明已经修改过了
            if (binCount != 0) {
                //2.4.2.1 索引处链表长度超过8,树化
                if (binCount >= TREEIFY_THRESHOLD)
                    treeifyBin(tab, i);
                //替换旧值
                if (oldVal != null)
                    return oldVal;
                //2.4.2.2 结束自旋
                break;
            }
        }
    }
    //3. check容器是否需要扩容,如果需要扩容则调用transfer方法去扩容
    //如果已经在扩容中,则check有没有完成
    addCount(1L, binCount);
    return null;
}
```

大致流程是这样的:

1. 开启死循环
2. 如果数组为空,则先初始化数组
3. 如果需要放入的槽点处值为空,,则通过CAS创建,创建成功则退出死循环,创建失败则自旋(继续死循环)
4. 如果需要放入的槽点是转移节点,则该索引处正在扩容,就会一直自旋等待扩容完成
5. 如果需要放入的槽点是有值的,此处如果是链表,则更新链表中的节点或者插入到最后;如果此处是红黑树,则更新或者插入其中.结束自旋.
6. 判断第5步有没有执行,执行了的话,则判断需不需要树化,需要的话则树化一下.然后结束自旋.
7. 新增之后,最后check一下容器是否需要扩容,需要扩容则去扩容.

这里为了保证线程安全,做了以下优化:

1. 通过自旋保证一定可以新增成功

在新增之前,通过for死循环来保证新增一定可以成功,一旦新增成功,就可以退出死循环,新增失败的话,则重复新增的步骤,直到新增成功为止.

2. 当前槽点为空时,通过CAS新增

这里没有在判断槽点为空的情况下直接赋值，因为在判断槽点为空和赋值的瞬间，很有可能槽点已经被其他线程赋值了，所以我们采用 CAS 算法，能够保证槽点为空的情况下赋值成功，如果恰好槽点已经被其他线程赋值，当前 CAS 操作失败，会再次执行 for 自旋，再走槽点有值的 put 流程，这里就是自旋 + CAS 的结合。

3. 当前槽点有值,锁定当前槽点

put 时，如果当前槽点有值，就是 key 的 hash 冲突的情况，此时槽点上可能是链表或红黑树，我们通过锁住槽点，来保证同一时刻只会有一个线程能对槽点进行修改。

4. 红黑树旋转时,锁住红黑树的根节点,保证同一时刻,当前红黑树只能被一个线程旋转

## 6. 扩容

扩容时机是和HashMap相同的,都是在put方法的最后一步检查一下是否需要扩容.但是实现是不太一样的,下面来看下代码:

```java
/**
 * Moves and/or copies the nodes in each bin to new table. See
 * above for explanation.
 *
 * @param tab     老数组
 * @param nextTab 新数组
 */
private final void transfer(Node<K,V>[] tab, Node<K,V>[] nextTab) {
    //老数组长度
    int n = tab.length, stride;
    if ((stride = (NCPU > 1) ? (n >>> 3) / NCPU : n) < MIN_TRANSFER_STRIDE)
        stride = MIN_TRANSFER_STRIDE; // subdivide range
    //如果新数组为空,初始化,大小为原数组的两倍.  和HashMap一样嘛
    if (nextTab == null) {            // initiating
        try {
            @SuppressWarnings("unchecked")
            Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n << 1];
            nextTab = nt;
        } catch (Throwable ex) {      // try to cope with OOME
            sizeCtl = Integer.MAX_VALUE;
            return;
        }
        nextTable = nextTab;
        transferIndex = n;
    }
    int nextn = nextTab.length;
    //创建转移节点   待会儿会在老数组的相应位置上创建转移节点,表示该节点正在扩容
    ForwardingNode<K,V> fwd = new ForwardingNode<K,V>(nextTab);
    boolean advance = true;
    boolean finishing = false; // to ensure sweep before committing nextTab
    //自旋  死循环
    for (int i = 0, bound = 0;;) {
        Node<K,V> f; int fh;
        while (advance) {
            int nextIndex, nextBound;
            //结束循环
            if (--i >= bound || finishing)
                advance = false;
            //拷贝完成
            else if ((nextIndex = transferIndex) <= 0) {
                i = -1;
                advance = false;
            }
            //减少i的值
            else if (U.compareAndSwapInt
                     (this, TRANSFERINDEX, nextIndex,
                      nextBound = (nextIndex > stride ?
                                   nextIndex - stride : 0))) {
                bound = nextBound;
                i = nextIndex - 1;
                advance = false;
            }
        }
        if (i < 0 || i >= n || i + n >= nextn) {
            int sc;
            //拷贝结束,直接赋值.每次拷贝完一个节点,都会在原数组上放转移节点,所以拷贝完成的节点的数据一定不会再发生变化
            //原数组发现是转移节点,是不会操作的,会一直等待转移节点消失之后再进行操作
            //也就是说数组节点一旦被标记为转移节点,是不会再发生任何变动的,所以不会有任何线程安全问题
            //这里直接赋值,没有任何问题
            if (finishing) {
                nextTable = null;
                table = nextTab;
                sizeCtl = (n << 1) - (n >>> 1);
                return;
            }
            if (U.compareAndSwapInt(this, SIZECTL, sc = sizeCtl, sc - 1)) {
                if ((sc - 2) != resizeStamp(n) << RESIZE_STAMP_SHIFT)
                    return;
                finishing = advance = true;
                i = n; // recheck before commit
            }
        }
        //原数组节点放置转移节点
        else if ((f = tabAt(tab, i)) == null)
            advance = casTabAt(tab, i, null, fwd);
        //已处理好
        else if ((fh = f.hash) == MOVED)
            advance = true; // already processed
        else {
            //节点加锁
            synchronized (f) {
                //再次校验
                if (tabAt(tab, i) == f) {
                    Node<K,V> ln, hn;
                    if (fh >= 0) {
                        int runBit = fh & n;
                        Node<K,V> lastRun = f;
                        for (Node<K,V> p = f.next; p != null; p = p.next) {
                            int b = p.hash & n;
                            if (b != runBit) {
                                runBit = b;
                                lastRun = p;
                            }
                        }
                        if (runBit == 0) {
                            ln = lastRun;
                            hn = null;
                        }
                        else {
                            hn = lastRun;
                            ln = null;
                        }
                        //如果节点只有单个数据，直接拷贝，如果是链表，循环多次组成链表拷贝
                        for (Node<K,V> p = f; p != lastRun; p = p.next) {
                            int ph = p.hash; K pk = p.key; V pv = p.val;
                            if ((ph & n) == 0)
                                ln = new Node<K,V>(ph, pk, pv, ln);
                            else
                                hn = new Node<K,V>(ph, pk, pv, hn);
                        }
                        //在新数组位置上放置拷贝的值
                        setTabAt(nextTab, i, ln);
                        setTabAt(nextTab, i + n, hn);
                        // 在老数组位置上放上 ForwardingNode 节点
                        // put 时，发现是 ForwardingNode 节点，就不会再动这个节点的数据了
                        setTabAt(tab, i, fwd);
                        advance = true;
                    }
                    //红黑树的拷贝
                    else if (f instanceof TreeBin) {
                        TreeBin<K,V> t = (TreeBin<K,V>)f;
                        TreeNode<K,V> lo = null, loTail = null;
                        TreeNode<K,V> hi = null, hiTail = null;
                        int lc = 0, hc = 0;
                        for (Node<K,V> e = t.first; e != null; e = e.next) {
                            int h = e.hash;
                            TreeNode<K,V> p = new TreeNode<K,V>
                                (h, e.key, e.val, null, null);
                            if ((h & n) == 0) {
                                if ((p.prev = loTail) == null)
                                    lo = p;
                                else
                                    loTail.next = p;
                                loTail = p;
                                ++lc;
                            }
                            else {
                                if ((p.prev = hiTail) == null)
                                    hi = p;
                                else
                                    hiTail.next = p;
                                hiTail = p;
                                ++hc;
                            }
                        }
                        ln = (lc <= UNTREEIFY_THRESHOLD) ? untreeify(lo) :
                            (hc != 0) ? new TreeBin<K,V>(lo) : t;
                        hn = (hc <= UNTREEIFY_THRESHOLD) ? untreeify(hi) :
                            (lc != 0) ? new TreeBin<K,V>(hi) : t;
                        setTabAt(nextTab, i, ln);
                        setTabAt(nextTab, i + n, hn);
                        //在老数组位置上放ForwardingNode节点
                        setTabAt(tab, i, fwd);
                        advance = true;
                    }
                }
            }
        }
    }
}
```

大致思路如下:

1. 首先需要把老数组的值全部拷贝到扩容之后的新数组上,先从数组的队尾开始拷贝
2. 拷贝数组的槽点时,先把原数组槽点锁住,保证原数组槽点不能操作,成功拷贝到新数组时,把原数组槽点赋值为转移节点
3. 这时如果有新数据正好需要put到此槽点,发现槽点为转移节点,就会一直等待,所以在扩容完成之前,该槽点对应的数据是不会发生变化的
4. 从数组的尾部拷贝到头部,每拷贝成功一次,就把原数组中的节点设置为转移节点
5. 直到所有数组数据都拷贝到新数组时,直接把新数组赋值给数组容器,拷贝完成

## 7. Get

ConcurrentHashMap 读的话，就比较简单了，先获取数组下标，然后通过判断数组下标的 key 是否和我们的 key 相等，相等的话就直接返回，如果下标的槽点是链表或红黑树的话，分别调用相应的查找数据的方法，整体思路和 HashMap 很像。

```java
public V get(Object key) {
    Node<K,V>[] tab; Node<K,V> e, p; int n, eh; K ek;
    //计算hashcode
    int h = spread(key.hashCode());
    //不是空的数组 && 并且当前索引的槽点数据不是空的
    //否则该key对应的值不存在，返回null
    if ((tab = table) != null && (n = tab.length) > 0 &&
        (e = tabAt(tab, (n - 1) & h)) != null) {
        //槽点第一个值和key相等，直接返回
        if ((eh = e.hash) == h) {
            if ((ek = e.key) == key || (ek != null && key.equals(ek)))
                return e.val;
        }
        //如果是红黑树或者转移节点，使用对应的find方法
        else if (eh < 0)
            return (p = e.find(h, key)) != null ? p.val : null;
        //如果是链表，遍历查找
        while ((e = e.next) != null) {
            if (e.hash == h &&
                ((ek = e.key) == key || (ek != null && key.equals(ek))))
                return e.val;
        }
    }
    return null;
}
```
