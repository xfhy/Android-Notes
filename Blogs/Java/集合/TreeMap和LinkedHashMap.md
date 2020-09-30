
### 1. 排序基本使用

在学习TreeMap原理之前,咱们先简单回顾一下集合排序的日常使用方式:

```java
static class DTO implements Comparable<DTO> {

    private Integer id;

    public DTO(Integer id) {
        this.id = id;
    }

    public Integer getId() {
        return id;
    }

    @Override
    public int compareTo(DTO o) {
        return id - o.getId();
    }

    @Override
    public String toString() {
        return "DTO{" +
                "id=" + id +
                '}';
    }
}

public static void main(String[] args) {
    List<DTO> list = new ArrayList<>();
    for (int i = 5; i > 0; i--) {
        list.add(new DTO(i));
    }
    //第一种方式,实现Comparable的compareTo方法进行排序
    Collections.sort(list);
    System.out.println(list);

    Comparator comparator = (Comparator<DTO>) (o1, o2) -> o2.getId() - o1.getId();
    List<DTO> list2 = new ArrayList<>();
    for (int i = 5; i > 0; i--) {
        list2.add(new DTO(i));
    }
    //第二种方式,利用外部排序器Comparator进行排序
    Collections.sort(list2, comparator);
    System.out.println(list2);
}
```

TreeMap也是利用上面两种方式进行排序,分别是Comparable(内部)和Comparator(外部).

### 2. TreeMap整体结构

TreeMap底层的数据结构是红黑树,和HashMap的红黑树结构是一样的.

TreeMap利用红黑树左节点小,右节点大的性质,根据key进行排序,使每个元素能够插入到红黑树中大小适当的位置,维护了key的大小关系,适用于key需要排序的场景.

因为底层使用的是平衡二叉树的结构,所以containsKey,get,put,put,remove等方法的时间复杂度都是log(n).

#### 2.1 基本属性

```java
/**
 * The comparator used to maintain order in this tree map, or
 * null if it uses the natural ordering of its keys.
 *
 * @serial
 外部比较器,如果没有传,则不用它,而是使用key自己内部实现的Comparable#compareTo方法
 */
private final Comparator<? super K> comparator;

//根节点
private transient Entry<K,V> root;

/**
 * The number of entries in the tree
 红黑树已有元素大小
 */
private transient int size = 0;

/**
 * The number of structural modifications to the tree.
 树结构变化的版本号,用于迭代过程中的快速失败场景
 */
private transient int modCount = 0;

//红黑树节点 key value 左节点  右节点  父节点
static final class Entry<K,V> implements Map.Entry<K,V> {
    K key;
    V value;
    Entry<K,V> left;
    Entry<K,V> right;
    Entry<K,V> parent;
}
```

#### 2.2 put

```java
public V put(K key, V value) {
    Entry<K,V> t = root;
    //树的根节点都是空的,直接创建一个根节点就好了
    if (t == null) {
        //这里会调用key进行比较,简单check一下key是否为null,如果是null,则会抛出空指针异常
        compare(key, key); // type (and possibly null) check

        root = new Entry<>(key, value, null);
        size = 1;
        modCount++;
        return null;
    }
    int cmp;
    Entry<K,V> parent;
    // split comparator and comparable paths
    Comparator<? super K> cpr = comparator;
    //外部比较器 非空
    if (cpr != null) {
        //自旋 找到key应该插入的位置
        do {
            parent = t;
            //比父节点小 则找左边  否则找右边   如果相等则直接替换
            cmp = cpr.compare(key, t.key);
            if (cmp < 0)
                t = t.left;
            else if (cmp > 0)
                t = t.right;
            else
                //在树中找到了key的compare相等的节点,直接替换原值,返回即可.
                return t.setValue(value);
        } while (t != null);   //t为空,则是已经遍历到了叶子节点
    }
    else {
        //使用内部比较器  key肯定非空才行
        if (key == null)
            throw new NullPointerException();
        @SuppressWarnings("unchecked")
            Comparable<? super K> k = (Comparable<? super K>) key;
        do {
            parent = t;
            cmp = k.compareTo(t.key);
            if (cmp < 0)
                t = t.left;
            else if (cmp > 0)
                t = t.right;
            else
                return t.setValue(value);
        } while (t != null);
    }
    
    //到了这里,说明树中没有与该key相等的节点,需要新增
    //比父节点大了放右边,小了放左边
    Entry<K,V> e = new Entry<>(key, value, parent);
    if (cmp < 0)
        parent.left = e;
    else
        parent.right = e;
    
    //着色 旋转,达到红黑树的平衡
    fixAfterInsertion(e);
    size++;
    modCount++;
    return null;
}
```

新增节点主要是利用了红黑树左边小右边大的性质,从根节点不断往下找,找到合适的位置进行替换或者新增.

知道了插入的原理,其实查询的原理也就掌握了,它们原理都是一样的,都是利用红黑树左小右大的性质来进行查找.

ps: 需要注意的是,TreeMap的key不能为null,在源码中也提现出来了.

### 3. LinkedHashMap基本使用

> 还是先来回顾一下LinkedHashMap的使用

HashMap是无序的,TreeMap可以根据key进行排序,LinkedHashMap可以维护插入的顺序.LinkedHashMap是HashMap的子类,它内部有一个双向链表维护着键值对的顺序.每个键值对即是位于哈希表中,也是位于双向链表中.LinkedHashMap支持两种顺序: 

- 插入顺序: 先添加的在前面,后添加的在后面.修改操作是不影响顺序的
- 访问顺序: 在get/put操作之后,其对应的键值对会移动到链表末尾,表示最近使用到的.而链表的头部就是最久没有被访问到的.

#### 3.1 插入顺序

默认情况下,就是插入顺序的,访问和修改不会造成顺序的改变

```java
LinkedHashMap<String,String> stringStringLinkedHashMap = new LinkedHashMap<>();
stringStringLinkedHashMap.put("1","1");
stringStringLinkedHashMap.put("2","2");
stringStringLinkedHashMap.put("3","3");
stringStringLinkedHashMap.put("4","4");
stringStringLinkedHashMap.put("2","1");
stringStringLinkedHashMap.get("2");

System.out.println(stringStringLinkedHashMap);

//输出
{1=1, 2=1, 3=3, 4=4}

```

#### 3.2 访问顺序

当把accessOrder指定成true的时候,即为按照访问顺序排列.

```java
//public LinkedHashMap(int initialCapacity,float loadFactor,boolean accessOrder)
LinkedHashMap<String, String> stringStringLinkedHashMap = new LinkedHashMap<>(16, 0.75f, true);
stringStringLinkedHashMap.put("1", "1");
stringStringLinkedHashMap.put("2", "2");
stringStringLinkedHashMap.put("3", "3");
stringStringLinkedHashMap.put("4", "4");
stringStringLinkedHashMap.put("2", "1");
stringStringLinkedHashMap.get("2");

System.out.println(stringStringLinkedHashMap);

//输出
{1=1, 3=3, 4=4, 2=1}
```

明显看到,当我们访问了某个元素之后,该元素跑到最后面去了,表示这是最近访问到的元素.还可以利用这个特性实现简单的LRUCache.

```java
 LinkedHashMap<String, String> stringStringLinkedHashMap = new LinkedHashMap<String,String>(16, 0.75f, true) {
    @Override
    protected boolean removeEldestEntry(Map.Entry eldest) {
        return size() > 3;
    }
};
stringStringLinkedHashMap.put("1", "1");
stringStringLinkedHashMap.put("2", "2");
stringStringLinkedHashMap.put("3", "3");
stringStringLinkedHashMap.get("1");
stringStringLinkedHashMap.put("4", "4");

System.out.println(stringStringLinkedHashMap);

//输出
{3=3, 1=1, 4=4}
```

复现removeEldestEntry方法,当添加完元素之后,会调用这个方法检查一下,是否需要移除最近最久未使用的元素.这里的demo是超过3个则移除最久未使用的.最开始是`1,2,3`,然后get了一下`1`,就会变成`2,3,1`,然后put了`4`,这时会变成`2,3,1,4`,但是超过了3个,此时会移除掉`2`.

### 4. LinkedHashMap整体架构

#### 4.1 LinkedHashMap 基本属性

```java
/**
 * HashMap.Node subclass for normal LinkedHashMap entries.
  一个节点,新增前指针和后指针(Java里面没有指针,这里是引用)
 */
static class Entry<K,V> extends HashMap.Node<K,V> {
    Entry<K,V> before, after;
    Entry(int hash, K key, V value, Node<K,V> next) {
        super(hash, key, value, next);
    }
}

/**
 * The head (eldest) of the doubly linked list.
    链表头部,最久未使用的数据就放这里的
 */
transient LinkedHashMap.Entry<K,V> head;

/**
 * The tail (youngest) of the doubly linked list.
 链表尾部,最近使用的数据就放这里的
 */
transient LinkedHashMap.Entry<K,V> tail;

/**
 * The iteration ordering method for this linked hash map: <tt>true</tt>
 * for access-order, <tt>false</tt> for insertion-order.
 *
 * @serial
    控制访问顺序的字段,默认是false
    false: 插入顺序  怎么插入的,就怎么排列,即使put/get操作排序顺序还是不变
    true: 访问顺序  LRU,最近使用的会放链表尾部去.
 */
final boolean accessOrder;
```

和LinkedHashMap起始有点像,都是双链表.不过这里的节点是Node,而且LinkedHashMap只提供了单向访问.

#### 4.2 LinkedHashMap 原理

翻看LinkedHashMap源码可以发现,它里面的put/get方法都是调用的HashMap的put/get方法,那它是如何实现自己独特的性质的?

```java
// Callbacks to allow LinkedHashMap post-actions
//元素被访问后调用
void afterNodeAccess(Node<K,V> p) { }
//元素被插入后调用
void afterNodeInsertion(boolean evict) { }
//元素被移除后调用
void afterNodeRemoval(Node<K,V> p) { }
```

在HashMap有这样3个空方法,这几个方法是留给LinkedHashMap使用的.方便在get/put/remove之后对链表进行排序操作.

```java
//构建新的节点  覆写HashMap
Node<K,V> newNode(int hash, K key, V value, Node<K,V> e) {
    LinkedHashMap.Entry<K,V> p =
        new LinkedHashMap.Entry<K,V>(hash, key, value, e);
    linkNodeLast(p);
    return p;
}
// link at the end of list
//将元素插入到链表尾部
private void linkNodeLast(LinkedHashMap.Entry<K,V> p) {
    LinkedHashMap.Entry<K,V> last = tail;
    tail = p;
    if (last == null)
        head = p;
    else {
        p.before = last;
        last.after = p;
    }
}

//accessOrder为true时   访问元素之后,会把元素移动到链表末尾
void afterNodeAccess(Node<K,V> e) { // move node to last
    LinkedHashMap.Entry<K,V> last;
    if (accessOrder && (last = tail) != e) {
        LinkedHashMap.Entry<K,V> p =
            (LinkedHashMap.Entry<K,V>)e, b = p.before, a = p.after;
        p.after = null;
        if (b == null)
            head = a;
        else
            b.after = a;
        if (a != null)
            a.before = b;
        else
            last = b;
        if (last == null)
            head = p;
        else {
            p.before = last;
            last.after = p;
        }
        tail = p;
        ++modCount;
    }
}

//元素被插入之后   判断是否满足removeEldestEntry,满足则移除链表头部元素
void afterNodeInsertion(boolean evict) { // possibly remove eldest
    LinkedHashMap.Entry<K,V> first;
    if (evict && (first = head) != null && removeEldestEntry(first)) {
        K key = first.key;
        removeNode(hash(key), key, null, false, true);
    }
}

//从链表中移除该元素
void afterNodeRemoval(Node<K,V> e) { // unlink
    LinkedHashMap.Entry<K,V> p =
        (LinkedHashMap.Entry<K,V>)e, b = p.before, a = p.after;
    p.before = p.after = null;
    if (b == null)
        head = a;
    else
        b.after = a;
    if (a == null)
        tail = b;
    else
        a.before = b;
}

//获取元素时,如果accessOrder为true,则该元素会被移动到链表末尾
public V get(Object key) {
    Node<K,V> e;
    if ((e = getNode(hash(key), key)) == null)
        return null;
    if (accessOrder)
        afterNodeAccess(e);
    return e.value;
}

```

#### 4.3 LinkedHashMap小结

1. 扩展HashMap.Entry 使其拥有链表结构
2. 重写HashMap里面的3个方法进行一些排序操作

参考: https://github.com/Omooo/Android-Notes/blob/master/blogs/%E9%9B%86%E5%90%88/TreeMap%20%E5%92%8C%20LinkedHashMap.md

https://blog.csdn.net/xzh109/article/details/104340573