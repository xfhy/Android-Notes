HashSet和TreeSet
---

### HashSet

HashSet里面维护了一个不含重复元素的集合,实现比较简单,就是通过HashMap来实现的.

```java
public class HashSet<E>
    extends AbstractSet<E>
    implements Set<E>, Cloneable, java.io.Serializable
{
    //存放数据的HashMap
    private transient HashMap<E,Object> map;

    // map的每个key对应的value都是该元素
    // Dummy value to associate with an Object in the backing Map
    private static final Object PRESENT = new Object();

    /**
     * Constructs a new, empty set; the backing <tt>HashMap</tt> instance has
     * default initial capacity (16) and load factor (0.75).
     */
    public HashSet() {
        map = new HashMap<>();
    }
    
    /**
     * Adds the specified element to this set if it is not already present.
     * More formally, adds the specified element <tt>e</tt> to this set if
     * this set contains no element <tt>e2</tt> such that
     * <tt>(e==null&nbsp;?&nbsp;e2==null&nbsp;:&nbsp;e.equals(e2))</tt>.
     * If this set already contains the element, the call leaves the set
     * unchanged and returns <tt>false</tt>.
     *
     * @param e element to be added to this set
     * @return <tt>true</tt> if this set did not already contain the specified
     * element
     
        添加一个元素,作为key添加到map里面
     
     */
    public boolean add(E e) {
        return map.put(e, PRESENT)==null;
    }
    
}
```

### TreeSet

TreeSet大致的结构是和HashSet相似,底层的数据结构是TreeMap,所以继承了TreeMap key能够排序的功能,迭代的时候也可以按照key的顺序排序进行迭代.

```java
public class TreeSet<E> extends AbstractSet<E>
    implements NavigableSet<E>, Cloneable, java.io.Serializable
{
    /**
     * The backing map.
     */
    private transient NavigableMap<E,Object> m;

    // Dummy value to associate with an Object in the backing Map
    private static final Object PRESENT = new Object();

    /**
     * Constructs a set backed by the specified navigable map.
     */
    TreeSet(NavigableMap<E,Object> m) {
        this.m = m;
    }

    /**
     * Constructs a new, empty tree set, sorted according to the
     * natural ordering of its elements.  All elements inserted into
     * the set must implement the {@link Comparable} interface.
     * Furthermore, all such elements must be <i>mutually
     * comparable</i>: {@code e1.compareTo(e2)} must not throw a
     * {@code ClassCastException} for any elements {@code e1} and
     * {@code e2} in the set.  If the user attempts to add an element
     * to the set that violates this constraint (for example, the user
     * attempts to add a string element to a set whose elements are
     * integers), the {@code add} call will throw a
     * {@code ClassCastException}.
     */
    public TreeSet() {
        this(new TreeMap<E,Object>());
    }
    
    public boolean add(E e) {
        return m.put(e, PRESENT)==null;
    }
    
}
```

底层是用TreeMap来装数据,每个key的value都是PRESENT.TreeMap中的key是需要实现Comparable的,不然无法比较.

### HashSet和TreeSet的区别

1. HashSet保存的数据是无序的,TreeSet保存的数据是有序的.
2. TreeSet保存自定义类对象的时候,必须实现Comparable接口,不实现就无法区分大小关系,无法排序.HashSet存对象的时候,判断其元素是否重复的依据是hashCode()和equals().
