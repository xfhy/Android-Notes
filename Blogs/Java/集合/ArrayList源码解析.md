
*本篇文章已授权微信公众号 guolin_blog （郭霖）独家发布

> 欣赏我们常用集合ArrayList的源码,学习API背后的故事.

**引言**

学Java很久了,一直处于使用API+查API的状态,不了解原理,久而久之总是觉得很虚,作为一名合格的程序员这是不允许的,不能一直当API Player,我们要去了解分析底层实现,下次在使用时才能知己知彼.知道在什么时候该用什么方法和什么类比较合适.

之前写的第一篇Java源码阅读文章[从源码角度彻底搞懂String、StringBuffer、StringBuilder](https://blog.csdn.net/xfhy_/article/details/80019618),感兴趣的可以去看看.

## 一、ArrayList的基本特点

1. 快速随机访问
2. 允许存放多个null元素
3. 底层是Object数组
4. 增加元素个数可能很慢(可能需要扩容),删除元素可能很慢(可能需要移动很多元素),改对应索引元素比较快


## 二、ArrayList的继承关系

![](http://olg7c0d2n.bkt.clouddn.com/18-4-24/67873829.jpg)

来看下源码中的定义

```java
public class ArrayList<E> extends AbstractList<E> 
    implements List<E>, RandomAccess, Cloneable, java.io.Serializable
```

- 可以看到继承了AbstractList,此类提供 List 接口的骨干实现，以最大限度地减少实现"随机访问"数据存储（如数组）支持的该接口所需的工作.对于连续的访问数据（如链表），应优先使用 AbstractSequentialList，而不是此类.

- 实现了List接口,意味着ArrayList元素是有序的,可以重复的,可以有null元素的集合.

- 实现了RandomAccess接口标识着其支持随机快速访问,实际上,我们查看RandomAccess源码可以看到,其实里面什么都没有定义.因为ArrayList底层是数组,那么随机快速访问是理所当然的,访问速度O(1).

- 实现了Cloneable接口,标识着可以它可以被复制.注意,ArrayList里面的clone()复制其实是浅复制(不知道此概念的赶快去查资料,这知识点非常重要).

- 实现了Serializable 标识着集合可被序列化。

## 三、ArrayList 的构造方法

在说构造方法之前我们要先看下与构造参数有关的几个全局变量：

```java
/**
 * ArrayList 默认的数组容量
 */
 private static final int DEFAULT_CAPACITY = 10;

/**
 * 用于空实例的共享空数组实例
 */
 private static final Object[] EMPTY_ELEMENTDATA = {};

/**
 * 另一个共享空数组实例，用的不多,用于区别上面的EMPTY_ELEMENTDATA
 */
 private static final Object[] DEFAULTCAPACITY_EMPTY_ELEMENTDATA = {};

/**
 * ArrayList底层的容器  
 */
transient Object[] elementData; // non-private to simplify nested class access

//当前存放了多少个元素   并非数组大小
private int size;
```

注意到,底层容器数组的前面有一个transient关键字,啥意思??

查阅[资料](https://blog.csdn.net/zero__007/article/details/52166306)后,大概知道:transient标识之后是不被序列化的

但是ArrayList实际容器就是这个数组为什么标记为不序列化??那岂不是反序列化时会丢失原来的数据?

![](https://ss1.bdstatic.com/70cFvXSh_Q1YnxGkpoWK1HF6hhy/it/u=3388479372,1706122097&fm=27&gp=0.jpg)

其实是ArrayList在序列化的时候会调用writeObject()，直接将size和element写入ObjectOutputStream；反序列化时调用readObject()，从ObjectInputStream获取size和element，再恢复到elementData。

原因在于elementData是一个缓存数组，它通常会预留一些容量，等容量不足时再扩充容量，那么有些空间可能就没有实际存储元素，采用上诉的方式来实现序列化时，就可以保证只序列化实际存储的那些元素，而不是整个数组，从而节省空间和时间。

### 无参构造方法

```java
/**
 * 构造一个初始容量为10的空列表。
 */
public ArrayList() {
    this.elementData = DEFAULTCAPACITY_EMPTY_ELEMENTDATA;
}
```

命名里面讲elementData指向了一个空数组，为什么注释却说初始容量为10。这里先卖个关子，稍后分析。

### 指定初始容量的构造方法

```java
public ArrayList(int initialCapacity) {
        //容量>0 -> 构建数组
        if (initialCapacity > 0) {
            this.elementData = new Object[initialCapacity];
        } else if (initialCapacity == 0) {
          //容量==0  指向空数组
            this.elementData = EMPTY_ELEMENTDATA;
        } else {
          //容量<0  报错呗
            throw new IllegalArgumentException("Illegal Capacity: "+ initialCapacity);
        }
    }
```

如果我们预先知道一个集合元素的容纳的个数的时候推荐使用这个构造方法，避免使用ArrayList默认的扩容机制而带来额外的开销.

### 使用另一个集合 Collection 的构造方法

```java
/**
 * 构造一个包含指定集合元素的列表，元素的顺序由集合的迭代器返回。
 */
 public ArrayList(Collection<? extends E> c) {
    elementData = c.toArray();
    if ((size = elementData.length) != 0) {
        // c.toArray 可能(错误地)不返回 Object[]类型的数组 参见 jdk 的 bug 列表(6260652)
        if (elementData.getClass() != Object[].class)
            elementData = Arrays.copyOf(elementData, size, Object[].class);
    } else {
        // 如果集合大小为空将赋值为 EMPTY_ELEMENTDATA    空数组
        this.elementData = EMPTY_ELEMENTDATA;
    }
}
```

## 四、增加元素+扩容机制

### 1. 添加单个元素 

 add(E e)方法作用: 添加指定元素到末尾

```java
/**
* 添加指定元素到末尾
*/
public boolean add(E e) {
    ensureCapacityInternal(size + 1);  // Increments modCount!!
    elementData[size++] = e;
    return true;
}

private void ensureCapacityInternal(int minCapacity) {
    //如果是以ArrayList()构造方法初始化,那么数组指向的是DEFAULTCAPACITY_EMPTY_ELEMENTDATA.第一次add()元素会进入if内部,
    //且minCapacity为1,那么最后minCapacity肯定是10,所以ArrayList()构造方法上面有那句很奇怪的注释.
    if (elementData == DEFAULTCAPACITY_EMPTY_ELEMENTDATA) {
        minCapacity = Math.max(DEFAULT_CAPACITY, minCapacity);
    }

    ensureExplicitCapacity(minCapacity);
}

private void ensureExplicitCapacity(int minCapacity) {
    //列表结构被修改的次数,用于保证线程安全,如果在迭代的时候该值意外被修改,那么会报ConcurrentModificationException错
    modCount++;

    // 溢出?
    if (minCapacity - elementData.length > 0)
        grow(minCapacity);
}

//扩容
private void grow(int minCapacity) {
    // overflow-conscious code
    //1. 记录之前的数组长度
    int oldCapacity = elementData.length;
    //2. 新数组的大小=老数组大小+老数组大小的一半
    int newCapacity = oldCapacity + (oldCapacity >> 1);
    //3. 判断上面的扩容之后的大小newCapacity是否够装minCapacity个元素
    if (newCapacity - minCapacity < 0)
        newCapacity = minCapacity;

    //4.判断新数组容量是否大于最大值
    //如果新数组容量比最大值(Integer.MAX_VALUE - 8)还大,那么交给hugeCapacity()去处理,该抛异常则抛异常
    if (newCapacity - MAX_ARRAY_SIZE > 0)
        newCapacity = hugeCapacity(minCapacity);
    // minCapacity is usually close to size, so this is a win:
    //5. 复制数组,注意,这里是浅复制
    elementData = Arrays.copyOf(elementData, newCapacity);
}

//巨大容量,,,666,这个名字取得好
private static int hugeCapacity(int minCapacity) {
    //溢出啦,扔出一个小错误
    if (minCapacity < 0) // overflow
        throw new OutOfMemoryError();
    return (minCapacity > MAX_ARRAY_SIZE) ?
        Integer.MAX_VALUE :
        MAX_ARRAY_SIZE;
}

```
大体思路:

1. 首先判断如果新添加一个元素是否会导致数组溢出
    
    判断是否溢出:如果原数组是空的,那么第一次添加元素时会给数组一个默认大小10.接着是判断是否溢出,如果溢出则去扩容,扩容规则: **新数组大小是原来数组大小的1.5倍**,最后通过Arrays.copyOf()去浅复制.

2. 添加元素到末尾

### 2. 添加元素到指定位置  

add(int index, E element)方法作用:添加元素到指定位置

```java
/**
* 添加元素在index处,对应索引处元素(如果有)和后面的元素往后移一位,腾出坑
*/
public void add(int index, E element) {
    //1. 入参合法性检查
    rangeCheckForAdd(index);

    //2. 是否需要扩容
    ensureCapacityInternal(size + 1);  // Increments modCount!!
    //3. 将elementData从index开始的size - index个元素复制到elementData的`index + 1`处
    //相当于index处以及后面的往后移动了一位
    System.arraycopy(elementData, index, elementData, index + 1,
                        size - index);
    //4. 将元素放到index处   填坑
    elementData[index] = element;
    //5. 记录当前真实数据个数
    size++;
}

//index不合法时,抛IndexOutOfBoundsException
private void rangeCheckForAdd(int index) {
    if (index > size || index < 0)
        throw new IndexOutOfBoundsException(outOfBoundsMsg(index));
}
```

大体思路:这里理解了上面的扩容之后,这里是比较简单的.其实就是在数组的某一个位置插入元素,那么我们将该索引处往后移动一位,腾出一个坑,最后将该元素放到此索引处(填坑)就行啦.

### 3. 添加集合到末尾  

addAll(Collection<? extends E> c)方法作用:添加集合到末尾,如果集合是null,那么会抛出NullPointerException.

```java
public boolean addAll(Collection<? extends E> c) {
    //1. 生成一个包含集合c所有元素的数组a
    Object[] a = c.toArray();
    //2. 记录需要插入的数组长度
    int numNew = a.length;
    //3. 判断一下是否需要扩容
    ensureCapacityInternal(size + numNew);  // Increments modCount
    //4. 将a数组全部复制到elementData末尾处
    System.arraycopy(a, 0, elementData, size, numNew);
    //5. 标记当前elementData已有元素的个数
    size += numNew;
    //6. 是否插入成功:c集合不为空就行
    return numNew != 0;
}
```

大体思路:代码思路是非常清晰的,很简单,就是将需要插入的集合转成数组a,再将a数组插入到当前elementData的末尾(其中还判断了一下是否需要扩容).

### 4. 添加集合到指定位置 

addAll(int index, Collection<? extends E> c)方法作用:添加集合到指定位置,可能会抛出IndexOutOfBoundsException(index不合法)或者NullPointerException(集合为null)

```java
public boolean addAll(int index, Collection<? extends E> c) {
    //1. 首先检查一下下标是否越界
    rangeCheckForAdd(index);

    //2. 生成一个包含集合c所有元素的数组a
    Object[] a = c.toArray();
    //3. 记录需要插入的数组长度
    int numNew = a.length;
    //4. 判断是否需要扩容
    ensureCapacityInternal(size + numNew);  // Increments modCount

    //5. 需要往后移的元素个数
    int numMoved = size - index;
    if (numMoved > 0) //后面有元素才需要复制哈,否则相当于插入到末尾
        //6. 将elementData的从index开始的numMoved个元素复制到index + numNew处
        System.arraycopy(elementData, index, elementData, index + numNew,
                            numMoved);
    //7. 将a复制到elementData的index处  
    System.arraycopy(a, 0, elementData, index, numNew);
    //8. 标记当前elementData已有元素的个数
    size += numNew;
    //9. 是否插入成功:c集合不为空就行
    return numNew != 0;
}
private void rangeCheckForAdd(int index) {
    if (index > size || index < 0)
        throw new IndexOutOfBoundsException(outOfBoundsMsg(index));
}
```

大体思路:其实就是一个先挖坑,再填坑的故事.首先判断一下添加了集合之后是否需要扩容,因为需要将集合插入到index处,所以需要将index后面的元素往后挪动,需要挪动的元素个数为:size - index,挪动的间隔是index + numNew(因为需要留出一个坑,用来存放需要插入的集合).
有了上面的步骤后就可以安全的将集合复制到elementData的index,也就完成了集合的插入.

其实我们可以看到,源码中对于细节的处理很细致,值得学习.

## 五、删除元素

### 1. 移除指定位置元素 

remove(int index)方法作用:移除指定位置元素,可能会抛出IndexOutOfBoundsException或ArrayIndexOutOfBoundsException

```java
public E remove(int index) {
    //1. 检查参数是否合法
    rangeCheck(index);

    modCount++;
    //2. 记录下需要移除的元素
    E oldValue = elementData(index);

    //3. 需要往前面挪动1个单位的元素个数
    int numMoved = size - index - 1;
    if (numMoved > 0) //后面有元素才挪动
        //4. 将index后面的元素(不包含index)往前"挪动"(复制)一位
        System.arraycopy(elementData, index+1, elementData, index,
                            numMoved);
    //5. 这里处理得很巧妙,首先将size-1,然后将elementData原来的最后那个元素赋值为null(方便GC回收)
    elementData[--size] = null; // clear to let GC do its work

    //6. 将旧值返回
    return oldValue;
}

//检查参数是否合法   参数>size抛出IndexOutOfBoundsException   参数小于0则抛出ArrayIndexOutOfBoundsException
private void rangeCheck(int index) {
    if (index >= size)
        throw new IndexOutOfBoundsException(outOfBoundsMsg(index));
}
```

大体思路:

1. 首先将旧值取出来,保存起来
2. 然后将数组的index后面的元素往前挪动一位
3. 将数组的末尾元素赋值为null,方便GC回收.因为已经将index后面的元素往前挪动了一位,所以最后一位是多余的,及时清理掉.

### 2. 移除指定元素 

remove(Object o)方法作用:移除指定元素,只移除第一个集合中与指定元素相同(通过equals()判断)的元素.移除成功了则返回true,未移除任何元素则返回false

- 如果传入的是null,则移除第一个null元素
- 如果传入的是非null元素,则移除第一个相同的元素,通过equals()进行比较.所以,如果是自己写的类,则需要重写equals()方法.一般需要用到元素比较的,都需要实现equals()方法,有时候还需要重写hashCode()方法.

```java
public boolean remove(Object o) {
    //1. 是否为null
    if (o == null) {
        //2. 循环遍历第一个为null的元素
        for (int index = 0; index < size; index++)
            if (elementData[index] == null) {
                //3. 移除   移除之后就返回true
                fastRemove(index);
                return true;
            }
    } else {
        //4. 循环遍历第一个与o equals()的元素
        for (int index = 0; index < size; index++)
            if (o.equals(elementData[index])) {
                //5. 移除指定位置元素
                fastRemove(index);
                return true;
            }
    }
    return false;
}
/*
私有的方法,移除指定位置元素,其实和remove(int index)是一样的.不同的是没有返回值
*/
private void fastRemove(int index) {
    modCount++;
    int numMoved = size - index - 1;
    if (numMoved > 0)
        System.arraycopy(elementData, index+1, elementData, index,
                            numMoved);
    elementData[--size] = null; // clear to let GC do its work
}
```

大体思路:   
1. 首先判断需要移除的元素是否为null
2. 如果为null,则循环遍历数组,移除第一个为null的元素  
3. 如果非null,则循环遍历数组,移除第一个与指定元素相同(equals() 返回true)的元素

可以看到最后都是移除指定位置的元素,源码中为了追求最佳的性能,加了一个fastRemove(int index)方法,次方法的实现与remove(int index)是几乎是一样的,就是少了返回index索引处元素的值.

### 3. 从此列表中删除所有包含在给定集合中的元素

removeAll(Collection<?> c)方法作用:从此列表中删除所有包含在c中的元素.

```java
public boolean removeAll(Collection<?> c) {
    //判空
    Objects.requireNonNull(c);
    return batchRemove(c, false);
}

//complement是true 则移除elementData中除了c以外的其他元素
//complement是false 则移除c和elementData(当前列表的数组)都含有的元素
private boolean batchRemove(Collection<?> c, boolean complement) {
    //1. 引用不可变
    final Object[] elementData = this.elementData;
    //r 是记录整个数组下标的, w是记录有效元素索引的
    int r = 0, w = 0;
    boolean modified = false;
    try {
        //2. 循环遍历数组
        for (; r < size; r++)
            //3. 如果complement为false  相当于是取c在elementData中的补集,c包含则不记录,c不包含则记录
            //如果complement为true  相当于是取c和elementData的交集,c包含则记录,c不包含则不记录
            if (c.contains(elementData[r]) == complement)
                elementData[w++] = elementData[r];   //r是正在遍历的位置  w是用于记录有效元素的   在w之前的全是有效元素,w之后的会被"删除"
    } finally {
        // Preserve behavioral compatibility with AbstractCollection,
        // even if c.contains() throws.
        //4. 如果上面在遍历的过程中出错了,那么r肯定不等于size,于是源码就将出错位置r后面的元素全部放到w后面
        if (r != size) {
            System.arraycopy(elementData, r,
                                elementData, w,
                                size - r);
            w += size - r;
        }
        //5. 如果w是不等于size,那么说明是需要删除元素的    否则不需要删除任何元素
        if (w != size) {
            // clear to let GC do its work
            //6. 将w之后的元素全部置空  因为这些已经没用了,置空方便GC回收
            for (int i = w; i < size; i++)
                elementData[i] = null;
            modCount += size - w;
            //7. 记录当前有效元素
            size = w;
            //8. 标记已修改
            modified = true;
        }
    }
    return modified;
}
```

大体思路:

1. 首先我们进行c集合检查,判断是否为null
2. 然后我们调用batchRemove()方法去移除 c集合与当前列表的交集
3. 循环遍历当前数组,记录c集合中没有的元素,放在前面(记录下标为w),w前面的是留下来的元素,w后面的是需要删除的数据
4. 第3步可能会出错,出错的情况下,则将出错位置的后面的全部保留下来,不删除
5. 然后就是将w之后的元素全部置空(方便GC回收),然后将size(标记当前数组有效元素)的值赋值为w,即完成了删除工作

再笼统一点说吧,其实就是将当前数组(elementData)中未包含在c中的元素,全部放在elementData数组的最前面,假设为w个,最后再统一置空后面的元素,并且记录当前数组有效元素个数为w.即完成了删除工作.

### 4. 清空列表

clear() 方法作用:清空当前集合的所有元素

这个方法非常简单,就是将数组所有元素都置为null,然后GC就有机会去把它回收了

```java
public void clear() {
    modCount++;

    // clear to let GC do its work
    for (int i = 0; i < size; i++)
        elementData[i] = null;

    size = 0;
}
```

### 5. 移除相应区间内的所有元素(protected)

removeRange(int fromIndex, int toIndex)方法作用:移除指定区间内的所有元素,注意这是protected方法,既然是移除元素,那么就拿出来欣赏欣赏.

```java
//这是protected方法    移除相应区间内的所有元素
protected void removeRange(int fromIndex, int toIndex) {
    modCount++;
    //1. toIndex后面的元素需要保留下来,记录一下toIndex后面的元素个数
    int numMoved = size - toIndex;
    //2. 将toIndex后面的元素复制到fromIndex处
    System.arraycopy(elementData, toIndex, elementData, fromIndex,
                        numMoved);

    // clear to let GC do its work
    //3. 将有效元素后面的元素置空
    int newSize = size - (toIndex-fromIndex);
    for (int i = newSize; i < size; i++) {
        elementData[i] = null;
    }
    //4. 记录当前有效元素个数为size - (toIndex-fromIndex)  ,即减去那个区间内的元素个数
    size = newSize;
}
```

大体思路:

1. 假设需要移除(fromIndex,toIndex)区间内的元素,那么将toIndex后面的元素复制到fromIndex处
2. 将有效元素后面的元素置空

## 六、改动元素

### 1. 替换指定下标的元素内容

set(int index, E element):替换index索引处的元素为element,可能会抛出IndexOutOfBoundsException

这里比较简单,就是将index处的元素替换成element

```java
public E set(int index, E element) {
    //1. 入参检测
    rangeCheck(index);

    //2. 记录原来该index处的值
    E oldValue = elementData(index);
    //3. 替换
    elementData[index] = element;
    return oldValue;
}
```

## 七、查询元素

### 1. 返回指定位置处元素

这个非常简单,就是将index索引处的数组的值返回

```java
E elementData(int index) {
    return (E) elementData[index];
}

/**
* 返回指定位置处元素
*/
public E get(int index) {
    rangeCheck(index);

    return elementData(index);
}
```

### 2.通过iterator()遍历

> 这也是查询的一种,哈哈

首先我们了解一下**fail-fast**,fail-fast 机制是java集合(Collection)中的一种错误机制。
当多个线程对同一个集合的内容进行操作时，就可能会产生fail-fast事件。例如：当某一个线程A通过iterator去遍历某集合的过程中，
若该集合的内容被其他线程所改变了；那么线程A访问集合时，就会抛出ConcurrentModificationException异常，产生fail-fast事件。

要了解fail-fast机制，我们首先要对ConcurrentModificationException 异常有所了解。当方法检测到对象的并发修改，但不允许这种修改时就抛出该异常。同时需要注意的是，该异常不会始终指出对象已经由不同线程并发修改，如果单线程违反了规则，同样也有可能会抛出该异常。


我们先来看看iterator()方法,它new了一个Itr(ArrayList的内部类)进行返回.

```java
/**
* Returns an iterator over the elements in this list in proper sequence.
* <p>The returned iterator is <a href="#fail-fast"><i>fail-fast</i></a>.
* @return an iterator over the elements in this list in proper sequence

以适当的顺序返回此列表中元素的迭代器。  fail-fast:快速失败?
*/
public Iterator<E> iterator() {
    return new Itr();
}
```

接下来我们来看看这个内部类

```java
private class Itr implements Iterator<E> {
    int cursor;       // index of next element to return    下一个元素的索引
    int lastRet = -1; // index of last element returned; -1 if no such    当前访问的最后一个元素的索引
    int expectedModCount = modCount;

    //是否有下一个元素
    public boolean hasNext() {
        //就是比一下cursor与size的大小   但是为什么是!=,而不是cursor<=size,这里有点蒙
        return cursor != size;
    }

    @SuppressWarnings("unchecked")
    public E next() {
        //判断一下该列表是否被其他线程改过(在迭代过程中)   修改过则抛异常
        checkForComodification();
        //第一次的时候是等于0   从0开始往后取数据
        int i = cursor;
        //如果越界 则抛异常
        if (i >= size)
            throw new NoSuchElementException();
        Object[] elementData = ArrayList.this.elementData;
        //不能访问超出elementData.length的索引    可能是被其他线程改动了
        if (i >= elementData.length)
            throw new ConcurrentModificationException();
        //往后挪一位  下一次就能访问下一位元素
        cursor = i + 1;
        //将需要访问的元素返回
        return (E) elementData[lastRet = i];
    }

    //移除当前访问到的最后一位元素
    public void remove() {
        //入参检测
        if (lastRet < 0)
            throw new IllegalStateException();
        //判断一下该列表是否被其他线程改过(在迭代过程中)   修改过则抛异常
        checkForComodification();

        try {
            //移除当前访问到的最后一位元素
            ArrayList.this.remove(lastRet);
            cursor = lastRet;
            lastRet = -1;
            expectedModCount = modCount;
        } catch (IndexOutOfBoundsException ex) {
            throw new ConcurrentModificationException();
        }
    }

    //快速遍历列表
    @Override
    @SuppressWarnings("unchecked")
    public void forEachRemaining(Consumer<? super E> consumer) {
        //入参检测
        Objects.requireNonNull(consumer);
        final int size = ArrayList.this.size;
        int i = cursor;
        //遍历完成 不用继续了
        if (i >= size) {
            return;
        }
        final Object[] elementData = ArrayList.this.elementData;
        //可能是被其他线程改动了
        if (i >= elementData.length) {
            throw new ConcurrentModificationException();
        }

        //循环遍历 不断回调consumer.accept()  将elementData每个元素都回调一次
        while (i != size && modCount == expectedModCount) {
            consumer.accept((E) elementData[i++]);
        }
        // update once at end of iteration to reduce heap write traffic
        cursor = i;
        lastRet = i - 1;
        checkForComodification();
    }

    //判断一下该列表是否被其他线程改过(在迭代过程中)   修改过则抛异常
    final void checkForComodification() {
        if (modCount != expectedModCount)
            throw new ConcurrentModificationException();
    }
}
``` 

## 八、总结

这是我第二次看源码,分析,鉴赏,学到了不少东西,相信各位认真看完的同学也多多少少有些感触.源码对于细节方面想的很周到,很谨慎.

下面我们来总结一下ArrayList的关键点

**ArrayList关键点**

- 底层是Object数组存储数据
- 扩容机制:默认大小是10,扩容是扩容到之前的1.5倍的大小,每次扩容都是将原数组的数据复制进新数组中.  我的领悟:如果是已经知道了需要创建多少个元素,那么尽量用`new ArrayList<>(13)`这种明确容量的方式创建ArrayList.避免不必要的浪费.
- 添加:如果是添加到数组的指定位置,那么可能会挪动大量的数组元素,并且可能会触发扩容机制;如果是添加到末尾的话,那么只可能触发扩容机制.  
- 删除:如果是删除数组指定位置的元素,那么可能会挪动大量的数组元素;如果是删除末尾元素的话,那么代价是最小的.    ArrayList里面的删除元素,其实是将该元素置为null.
- 查询和改某个位置的元素是非常快的( O(1) ).