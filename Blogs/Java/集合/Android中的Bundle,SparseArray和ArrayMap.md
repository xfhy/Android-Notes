- [1. Bundle](#head1)
- [2. SparseArray](#head2)
	- [2.1 示例](#head3)
	- [2.2 SparseArray 初始化](#head4)
	- [2.3 put()](#head5)
	- [2.4 get()](#head6)
	- [2.5 delete()](#head7)
	- [2.6 小结](#head8)
- [3. ArrayMap](#head9)

## <span id="head1">1. Bundle</span>

Android为什么要设计Bundle而不是直接使用HashMap来直接进行数据传递?

1. Bundle内部是由ArrayMap实现的,ArrayMap在设计上比传统的HashMap更多考虑的是内存优化
2. Bundle使用的是Parcelable序列化,而HashMap使用Serializable序列化

## <span id="head2">2. SparseArray</span>

SparseArray是用来存储key-value组合的,类似HashMap.但是它只能存储key为int类型的,也就避免了key的装箱操作和分配空间.建议使用`SparseArray<V>`替换`HashMap<Integer,V>`.

还有就是SparseArray是专门设计来节省空间的,所以它里面的数据存储得非常紧凑.key和value都是单独用一个数组来存储的,并且数组是按大小排好序了的,每次增删改查等操作都是用二分查找来进行定位位置的.

### <span id="head3">2.1 示例</span>

先给大家看段代码:

```java
SparseArray<String> sparseArray = new SparseArray<>();
sparseArray.put(39998, "0000");
sparseArray.put(26, "0000");
sparseArray.put(11, "1000");
sparseArray.put(13, "1000");
```

执行完成之后,在内存中的情况如下:

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/SparseArray%E5%AD%98%E5%82%A8%E7%9A%84%E6%95%B0%E6%8D%AE.png)

可以看到

- 有2个数组用来存储数据,mKeys和mValues
- key数组是从前往后存储数据的,且中间没有空隙
- key数组是有序的
- key与value数组一一对应

### <span id="head4">2.2 SparseArray 初始化</span>

```java
public SparseArray() {
    this(10);
}

public SparseArray(int initialCapacity) {
    if (initialCapacity == 0) {
        mKeys = EmptyArray.INT;
        mValues = EmptyArray.OBJECT;
    } else {
        mValues = ArrayUtils.newUnpaddedObjectArray(initialCapacity);
        mKeys = new int[mValues.length];
    }
    mSize = 0;
}
```

初始化比较简单,就是初始化了2个数组.默认初始容量是10.

### <span id="head5">2.3 put()</span>

```java
/**
 * Adds a mapping from the specified key to the specified value,
 * replacing the previous mapping from the specified key if there
 * was one.
 */
public void put(int key, E value) {
    //1. 二分查找  
    int i = ContainerHelpers.binarySearch(mKeys, mSize, key);

    //2. 如果找到了,则说明之前数组里面已经有这个key了,直接替换原数据即可
    if (i >= 0) {
        mValues[i] = value;
    } else {
        //3. 没有找到,则找一个正确位置再插入
        
        //i在ContainerHelpers.binarySearch里面已经进行~操作了,所以这里再~一下,还原数据
        i = ~i;

        //这个位置已经被删除了,直接将key和value放这里就行了
        if (i < mSize && mValues[i] == DELETED) {
            mKeys[i] = key;
            mValues[i] = value;
            return;
        }
        
        //如果需要清理,则gc一下(不是虚拟机的那个gc,而是将标记为DELETE的value置空,然后将有数据的全部置顶).清理之后再查找key的位置
        if (mGarbage && mSize >= mKeys.length) {
            gc();

            // Search again because indices may have changed.
            i = ~ContainerHelpers.binarySearch(mKeys, mSize, key);
        }
        
        //在2个数组中i位置插入key和value
        mKeys = GrowingArrayUtils.insert(mKeys, mSize, i, key);
        mValues = GrowingArrayUtils.insert(mValues, mSize, i, value);
        mSize++;
    }
}
```

上面的代码调了些其他的方法,首先看一下ContainerHelpers#binarySearch()的二分查找算法

```java
//This is Arrays.binarySearch(), but doesn't do any argument validation.
static int binarySearch(int[] array, int size, int value) {
    int lo = 0;
    int hi = size - 1;
    while (lo <= hi) {
        //除以2,位运算提高效率
        final int mid = (lo + hi) >>> 1;
        final int midVal = array[mid];
        if (midVal < value) {
            lo = mid + 1;
        } else if (midVal > value) {
            hi = mid - 1;
        } else {
            return mid;  // value found
        }
    }
    //若没找到，则lo是value应该插入的位置，是一个正数。对这个正数去反，返回负数回去
    return ~lo;  // value not present
}
```

就是常规的二分查找算法.再看一下gc()操作.

```java
private void gc() {
    int n = mSize;
    int o = 0;
    int[] keys = mKeys;
    Object[] values = mValues;
    for (int i = 0; i < n; i++) {
        Object val = values[i];
        if (val != DELETED) {
            if (i != o) {
                keys[o] = keys[i];
                values[o] = val;
                values[i] = null;
            }
            o++;
        }
    }
    mGarbage = false;
    mSize = o;
}
```

其实gc方法的核心就是压缩存储,让元素挨得近一点.最后再来看看GrowingArrayUtils.insert()方法

```java
public static int[] insert(int[] array, int currentSize, int index, int element) {
    //确认 当前集合长度 小于等于 array数组长度
    assert currentSize <= array.length;
    //不需要扩容
    if (currentSize + 1 <= array.length) {
        //将array数组内从 index 移到 index + 1，共移了 currentSize - index 个，即从index开始后移一位，那么就留出 index 的位置来插入新的值。
        System.arraycopy(array, index, array, index + 1, currentSize - index);
        //在index处插入新的值
        array[index] = element;
        return array;
    }
    //需要扩容，构建新的数组，新的数组大小由growSize() 计算得到
    int[] newArray = new int[growSize(currentSize)];
    //这里再分 3 段赋值。首先将原数组中 index 之前的数据复制到新数组中
    System.arraycopy(array, 0, newArray, 0, index);
    //然后在index处插入新的值
    newArray[index] = element;
    //最后将原数组中 index 及其之后的数据赋值到新数组中
    System.arraycopy(array, index, newArray, index + 1, array.length - index);
    return newArray;
}
```

上面的插入算法中,如果不需要扩容则直接进行移位以留出空位来插入新的值.如果需要扩容则先扩容,然后根据需要插入的位置index,分三端数据复制到新的数组中.再看看growSize方法是如何扩容的

```java
public static int growSize(int currentSize) {
    //如果当前size 小于等于4，则返回8， 否则返回当前size的两倍
    return currentSize <= 4 ? 8 : currentSize * 2;
}
```

很简单,就是根据size,size小于4则为8,否则为2倍大小.

### <span id="head6">2.4 get()</span>

```java
public E get(int key) {
    return get(key, null);
}
public E get(int key, E valueIfKeyNotFound) {
    int i = ContainerHelpers.binarySearch(mKeys, mSize, key);
    if (i < 0 || mValues[i] == DELETED) {
        return valueIfKeyNotFound;
    } else {
        return (E) mValues[i];
    }
}
```

通过二分查找,找到key的位置直接返回即可.

### <span id="head7">2.5 delete()</span>

```java
public void delete(int key) {
    int i = ContainerHelpers.binarySearch(mKeys, mSize, key);
    if (i >= 0) {
        if (mValues[i] != DELETED) {
            mValues[i] = DELETED;
            mGarbage = true;
        }
    }
}
```

通过二分查找,找到位置后,只是简单标记一下value为DELETED,将mGarbage置为true.

### <span id="head8">2.6 小结</span>

SparseArray是Android中一种特有的数据结构,用来替代HashMap的.初始化时默认容量为10它里面有两个数组,一个是int[]数组存放key,一个是Object[]数组用来存放value.它的key只能为int.在put时会根据传入的key进行二分查找找到合适的插入位置,如果当前位置有值或者是DELETED节点,就直接覆盖,否则就需要拷贝该位置后面的数据全部后移一位,空出一个位置让其插入.如果数组满了但是还有DELETED节点,就需要调用gc方法,gc方法所做的就是把DELETED节点后面的数前移,压缩存储(把有数据的位置全部置顶).数组满了没有DELETED节点,就需要扩容.

调用remove时,并不会直接把key从int[]数组里面删掉,而是把当前key指向的value设置成DELETED节点,这样做是为了减少int[] 数组的结构调整,结构调整就意味着数据拷贝.但是当我们调用keyAt/valueAt获取索引时,如果有DELETED节点旧必须得调用gc,不然获得的index是不对的.延迟回收的好处适合频繁删除和插入来回执行的场景,性能很好.

get方法很简单,二分查找获取key对应的索引index,返回values[index]即可.

可以看到SparseArray比HashMap少了基本数据的自动装箱操作,而且不需要额外的结构体,单个元素存储成本低,在数据量小的情况下,随机访问的效率很高.但是缺点也显而易见,就是增删的效率比较低,在数据量比较大的时候,调用gc拷贝数组成本巨大.

除了SparseArray,Android还提供了SparseIntArray(int:int),SparseBooleanArray(int:boolean),SparseLongArray(int:long)等,其实就是把对应的value换成基本数据类型.

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/SparseArray%E5%BA%95%E5%B1%82%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84.png)

## <span id="head9">3. ArrayMap</span>

ArrayMap是一种通用的key-value映射的数据结构,和SparseArray类似.但是SparseArray只能存储int类型的key,而ArrayMap可以存储其他类型的key.如果你没有见过它也没关系,你肯定用过它.Bundle底层就是用的这玩意儿存储的数据.它底层不使用SparseArray可能就是因为它的key只能是int类型.

ArrayMap与传统的HashMap不同,它的数据结构是两个数组,一个数组(mHashes)用来存放key的hashcode,一个数组(mArray)用来存放key和value.你没看错,mArray数组里面即存放了key,也存放了value.它底层的数据结构用图展示出来大概是这个样子(图片来源于网络):

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/ArrayMap%E5%BA%95%E5%B1%82%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84.png)

为了减少频繁的创建和回收Map对象,ArrayMap还采用了两个大小为10的缓存队列来分别保存大小为4和8的ArrayMap对象.为了节省内存,还有内存扩张和内存收缩策略.

ArrayMap在put/remove时,和SparseArray基本是一致的,也是通过二分查找求数组索引,然后再执行相应的操作.不同的是ArrayMap的扩容机制和缩容机制.

在put需要扩容时,如果容量小于4就给4,小于8就给8,其次就是扩容1.5倍.之所以给4或8是因为可以利用缓存的ArrayMap对象;在remove时,如果数组长度大于8但是存储的数据不足数据大小的1/3时,就会缩容,mSize小于等于8则设置新大小为8,否就设置为mSize的1.5倍,也就是说在内存使用量不足1/3时,内存数据收紧50%.

这个缓存还是很有必要的，毕竟 ArrayMap 的使用量还是蛮大的，Bundle 的底层就是用 ArrayMap 来存数据的，可想而知了。但是可以思考一下 Bundle 为啥用 ArrayMap 而不用 SparseArray 呢？

除了 put 方法，ArrayMap 和 SparseArray 都有一个 append 方法，它和 put 很相似，append 的差异在于该方法不会去做扩容操作，是一个轻量级的插入方法。在明确知道肯定会插入队尾的情况下使用 append 性更好，因为 put 一上来就做二分查找，时间复杂度 O(logn)，而 append 时间复杂度为 O(1)。

ArraySet 也是 Android 特有的数据结构，用来替代 HashSet 的，和 ArrayMap 几乎一致，包含了缓存机制、扩容机制等。
