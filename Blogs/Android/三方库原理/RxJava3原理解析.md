
### 背景

RxJava是一个基于事件流、实现异步操作的库。

官方介绍： RxJava：a library for composing asynchronous and event-based programs using observable sequences for the Java VM
（RxJava 是一个在 Java VM 上使用可观测的序列来组成异步的、基于事件的程序的库）

> 文中用到的RxJava源码版本为3.0.13，文中的demo源码 https://github.com/xfhy/AllInOne/tree/master/app/src/main/java/com/xfhy/allinone/opensource/rxjava

### 基础使用

简单介绍一下如何与Retrofit结合使用。引入：

```groovy
implementation "io.reactivex.rxjava3:rxjava:3.0.13"
implementation 'io.reactivex.rxjava3:rxandroid:3.0.0'
implementation "com.github.akarnokd:rxjava3-retrofit-adapter:3.0.0"

//Retrofit
implementation "com.squareup.retrofit2:retrofit:2.9.0"
//可选
implementation "com.squareup.retrofit2:converter-gson:2.9.0"
```

构建Retrofit实例

```kotlin
private val retrofit by lazy {
        Retrofit.Builder()
            .baseUrl("https://www.wanandroid.com")
            //使用Gson解析
            .addConverterFactory(GsonConverterFactory.create())
            //转换器   RxJava3   每次执行的时候在IO线程
            .addCallAdapterFactory(RxJava3CallAdapterFactory.createWithScheduler(Schedulers.io()))
            .build()
    }
```

定义Retrofit的API：

```kotlin
interface WanAndroidService {

    @GET("wxarticle/chapters/json")
     fun listReposByRxJava(): Single<WxList?>

}

class WxList {
    var errorMsg = ""
    var errorCode = -1
    var data = mutableListOf<Wx>()

    class Wx {
        var id: Int = 0
        var name: String = ""
    }
}
```

请求网络：

```kotlin
fun reqNet() {
    val request = retrofit.create(WanAndroidService::class.java)
    val call = request.listReposByRxJava()
    call.observeOn(AndroidSchedulers.mainThread()).subscribe(object : SingleObserver<WxList?> {
        override fun onSubscribe(d: Disposable?) {
            tvContent.text = "开始请求网络"
        }

        override fun onSuccess(t: WxList?) {
            t?.let {
                tvContent.text = it.data[0].name
            }
        }

        override fun onError(e: Throwable?) {
            tvContent.text = "网络出错"
        }
    })
}
```

这样，一个简单的Retrofit与OKHttp的结合案例就完成了。现在请求网络的时候就可以使用RxJava那些链式操作了。

### just : 最简单的订阅关系

先从最简单的just开始，看一下RxJava的订阅关系是怎么样的。

```kotlin
val just: Single<Int> = Single.just(1)
just.subscribe(object : SingleObserver<Int> {
    override fun onSubscribe(d: Disposable?) {
    }

    override fun onSuccess(t: Int) {
    }

    override fun onError(e: Throwable?) {
    }
})
```

Single.just(1)会构建一个SingleJust实例出来，

```java
//Single.java
public static <@NonNull T> Single<T> just(T item) {
    Objects.requireNonNull(item, "item is null");
    return RxJavaPlugins.onAssembly(new SingleJust<>(item));
}
```

其中RxJavaPlugins.onAssembly是一个钩子，不用在意，这段代码就是返回一个SingleJust对象。

点进去看一下subscribe是怎么走的

```java
//Single.java
@Override
public final void subscribe(@NonNull SingleObserver<? super T> observer) {
    ...
    subscribeActual(observer);
    ...
}
```

核心代码就一句，调用subscribeActual方法，从名字看是进行实际地订阅。那么我们将目光聚焦到subscribeActual里面，它是一个抽象方法，就上面的demo而言其实际实现是刚才创建出来的SingleJust。

```java
//Single.java
protected abstract void subscribeActual(@NonNull SingleObserver<? super T> observer);

//SingleJust.java
public final class SingleJust<T> extends Single<T> {

    final T value;

    public SingleJust(T value) {
        this.value = value;
    }

    @Override
    protected void subscribeActual(SingleObserver<? super T> observer) {
        observer.onSubscribe(Disposable.disposed());
        observer.onSuccess(value);
    }

}

```

SingleJust里面的代码非常简洁，在实际订阅（调用subscribeActual）时，直接将传进来的观察者（也就是上面传入的SingleObserver）回调onSubscribe和onSuccess就完事了。此处没有onError，因为不会失败。


### map 操作符

我们知道，RxJava中map可以转换数据，看一下它是怎么做到的

```kotlin
val singleInt = Single.just(1)
val singleString = singleInt.map(object : Function<Int, String> {
    override fun apply(t: Int): String {
        return t.toString()
    }
})
singleString.subscribe(object : SingleObserver<String> {
    override fun onSubscribe(d: Disposable?) {
    }

    override fun onSuccess(t: String) {
    }

    override fun onError(e: Throwable?) {
    }
})
```

点进去map看一下：

```java
//Single.java
public final <@NonNull R> Single<R> map(@NonNull Function<? super T, ? extends R> mapper) {
    Objects.requireNonNull(mapper, "mapper is null");
    return RxJavaPlugins.onAssembly(new SingleMap<>(this, mapper));
}
```

构建了一个SingleMap，有了上面just的经验，订阅的时候是走的SingleMap的subscribeActual方法。直接去看：

```java
public final class SingleMap<T, R> extends Single<R> {
    final SingleSource<? extends T> source;

    final Function<? super T, ? extends R> mapper;

    public SingleMap(SingleSource<? extends T> source, Function<? super T, ? extends R> mapper) {
        this.source = source;
        this.mapper = mapper;
    }

    @Override
    protected void subscribeActual(final SingleObserver<? super R> t) {
        source.subscribe(new MapSingleObserver<T, R>(t, mapper));
    }
}
```

注意一下这个source，它是啥？在构造方法里面传入的，也就是在Single.java的map方法那里传入的this，这个this也就是Single.just(1)所构建出来的SingleJust对象。这个SingleJust也就是此处map的上游，上游把事件给下游。

此处订阅时，就是调一下上游的subscribe与自己绑定起来，完成订阅关系。现在生产者是上游，而此处的SingleMap就是下游的观察者。

MapSingleObserver，也就是map的观察者，来看一下它是怎么实现的

```java
public final class SingleMap<T, R> extends Single<R> {
    static final class MapSingleObserver<T, R> implements SingleObserver<T> {

        final SingleObserver<? super R> t;

        final Function<? super T, ? extends R> mapper;

        MapSingleObserver(SingleObserver<? super R> t, Function<? super T, ? extends R> mapper) {
            this.t = t;
            this.mapper = mapper;
        }

        @Override
        public void onSubscribe(Disposable d) {
            t.onSubscribe(d);
        }

        @Override
        public void onSuccess(T value) {
            R v;
            try {
                //mapper是demo中传入的object : Function<Int, String>
                v = Objects.requireNonNull(mapper.apply(value), "The mapper function returned a null value.");
            } catch (Throwable e) {
                Exceptions.throwIfFatal(e);
                onError(e);
                return;
            }

            t.onSuccess(v);
        }

        @Override
        public void onError(Throwable e) {
            t.onError(e);
        }
    }
}
```

其实t是下游的观察者，通过subscribeActual传入。在上游调用map的onSubscribe同时，map也向下传递这个事件，调用下游观察者的onSubscribe。在上游调用map的onSuccess时，map自己进行转换一下，再交给下游的onSuccess。同理，onError也是一样的路线。

到这里就理清楚了。

#### 框架结构

RxJava的整体结构是一条链，其中：

1. 链的最上游：生产者Observable
2. 链的最下游：观察者Observer
3. 链的中间：各个中介节点，既是下游的Observable，又是上游的Observer

#### 操作符Operator（map等）的本质

1. 基于原Observable创建一个新的Observable
2. Observable内部创建一个Observer
3. 通过定制Observable的subscribeActual()方法和Observer的onXxx()方法，来实现自己的中介角色（例如数据转换、线程切换等）

### dispose工作原理

下面分别讲一下这几种情况：

- Single.just 无后续，无延迟
- Observable.interval 有后续，有延迟
- Single.map 无后续，无延迟，有上下游
- Single.delay 无后续，有延迟
- Observable.map 有后续，无延迟
- Observable.delay 无后续，有延迟

这几种情况已经足够把所有dispose的情况都说明完整了。

#### Single.just 无后续，无延迟

对于Single.just，情况比较简单，在SingleJust的subscribeActual中，给观察者一个全局共享的Disposable对象。下游不能对其进行取消，因为间隔太短了，马上就调用onSuccess了。

```java
@Override
protected void subscribeActual(SingleObserver<? super T> observer) {
    observer.onSubscribe(Disposable.disposed());
    observer.onSuccess(value);
}
```

#### Observable.interval 有后续，有延迟

先来一段示例代码：

```kotlin
val longObservable: Observable<Long> = Observable.interval(0, 1, TimeUnit.SECONDS)
longObservable.subscribe(object : Observer<Long> {
    override fun onSubscribe(d: Disposable?) {
    }

    override fun onNext(t: Long?) {
    }

    override fun onError(e: Throwable?) {
    }

    override fun onComplete() {
    }
})
```

这里Observable.interval构建的是ObservableInterval对象。有了前面的经验，直接进去看ObservableInterval的subscribeActual方法。

```java
//ObservableInterval.java
@Override
public void subscribeActual(Observer<? super Long> observer) {
    //1. 创建观察者（该观察者还实现了Disposable）
    IntervalObserver is = new IntervalObserver(observer);
    observer.onSubscribe(is);

    //线程调度器
    Scheduler sch = scheduler;

    ...
    //将is（它实现了Runnable）这个任务交给线程调度器去执行，同时返回一个Disposable对象
    Disposable d = sch.schedulePeriodicallyDirect(is, initialDelay, period, unit);
    is.setResource(d);
    ...
}

```

首先是创建了一个观察者，该观察者很明显是实现了Disposable接口，因为将该观察者顺着onSubscribe传递给了下游，方便下游取消。随后，将该观察者交给线程调度器去执行，显然它还实现了Runnable接口，紧接着将调度器返回的Disposable对象设置给该观察者。

```java
static final class IntervalObserver
    extends AtomicReference<Disposable>
    implements Disposable, Runnable {

    private static final long serialVersionUID = 346773832286157679L;

    final Observer<? super Long> downstream;

    long count;
    
    //传入的Observer是下游的
    IntervalObserver(Observer<? super Long> downstream) {
        this.downstream = downstream;
    }

    @Override
    public void dispose() {
        //取消自己
        DisposableHelper.dispose(this);
    }

    @Override
    public boolean isDisposed() {
        return get() == DisposableHelper.DISPOSED;
    }

    @Override
    public void run() {
        //通知下游
        if (get() != DisposableHelper.DISPOSED) {
            downstream.onNext(count++);
        }
    }

    public void setResource(Disposable d) {
        //设置Disposable给自己
        DisposableHelper.setOnce(this, d);
    }
}
```

IntervalObserver继承自AtomicReference(AtomicReference类提供了一个可以原子读写的对象引用变量，避免出现线程安全问题)，泛型是Disposable。同时它也实现了Disposable和Runnable。在构造方法里面传入下游的观察者，方便待会儿把事件传给下游。

当事件一开始时，将IntervalObserver传递给下游，因为它实现了Disposable，可以被下游取消。然后将IntervalObserver传递给调度器，调度器会执行里面的run方法，run方法里面是将数据传递给下游。在交给调度器的时候，返回了一个Disposable对象，意味着可以随时取消调度器里面的该任务。然后将该Disposable对象设置给IntervalObserver的内部，通过setResource方法，其实就是设置给IntervalObserver自己的，它本身就是一个`AtomicReference<Disposable>`。当下游调用dispose时，即调用IntervalObserver的dispose，然后IntervalObserver内部随即调用自己的dispose方法，完成了取消。

这里为什么设计的这么绕？直接将调度器返回的Disposable对象返回给下游不就可以了么，下游也可以对其进行取消啊？这样设计的好处是上游传递给下游的永远是IntervalObserver对象，下游直接拿着这个实现了Disposable的IntervalObserver对象可以直接调用它的dispose进行取消。而不用管它内部当前是握着哪个Disposable对象，即使IntervalObserver内部的Disposable被更换了也丝毫不影响下游对上游的取消操作。

#### Single.map 无后续，无延迟，有上下游

先来个简单例子

```kotlin
val singleInt = Single.just(1)
val singleString = singleInt.map(object : Function<Int, String> {
    override fun apply(t: Int): String {
        return t.toString()
    }
})
singleString.subscribe(object : SingleObserver<String> {
    override fun onSubscribe(d: Disposable?) {
    }

    override fun onSuccess(t: String) {
    }

    override fun onError(e: Throwable?) {
    }
})
```

singleInt.map点进去

```java
//Single.java
public final <@NonNull R> Single<R> map(@NonNull Function<? super T, ? extends R> mapper) {
    Objects.requireNonNull(mapper, "mapper is null");
    return RxJavaPlugins.onAssembly(new SingleMap<>(this, mapper));
}
```

通过上面的例子我们知道，上游是创建了一个SingleJust对象。在调用map时，将自己（也就是SingleJust）传给下游SingleMap里面去了。

```java
//SingleMap.java
public final class SingleMap<T, R> extends Single<R> {
    final SingleSource<? extends T> source;

    final Function<? super T, ? extends R> mapper;
    
    //source是上游，通过构造方法传入进来
    public SingleMap(SingleSource<? extends T> source, Function<? super T, ? extends R> mapper) {
        this.source = source;
        this.mapper = mapper;
    }

    @Override
    protected void subscribeActual(final SingleObserver<? super R> t) {
        source.subscribe(new MapSingleObserver<T, R>(t, mapper));
    }

    static final class MapSingleObserver<T, R> implements SingleObserver<T> {

        final SingleObserver<? super R> t;

        final Function<? super T, ? extends R> mapper;

        MapSingleObserver(SingleObserver<? super R> t, Function<? super T, ? extends R> mapper) {
            this.t = t;
            this.mapper = mapper;
        }

        @Override
        public void onSubscribe(Disposable d) {
            t.onSubscribe(d);
        }

        @Override
        public void onSuccess(T value) {
            R v;
            try {
                v = Objects.requireNonNull(mapper.apply(value), "The mapper function returned a null value.");
            } catch (Throwable e) {
                Exceptions.throwIfFatal(e);
                onError(e);
                return;
            }

            t.onSuccess(v);
        }

        @Override
        public void onError(Throwable e) {
            t.onError(e);
        }
    }
}
```

#### Single.delay 无后续，有延迟
#### Observable.map 有后续，无延迟
#### Observable.delay 无后续，有延迟

### 线程切换

#### subscribeOn

#### observeOn

### 大纲

- 基础使用
* just 最简单的订阅关系
* map 操作符，内部有个观察者，让上游订阅我内部的观察者，然后在观察者里面做转换，转换之后交给下游。
* dispose是怎么工作的： 没有上游的情况，有上下游的情况。有没有延迟，有没有后续
	* Single.just 即没延迟，也没后续，
	* Observable.interval 有延迟，有后续。取消定时器。把自己Disposeble给下游，当下游调用dispose时取消自己内部的task
	* Single.map 无延迟，也没后续，有上下游。  直接就把上游给过来的Disposeble给下游去了
	* Single.delay  有延迟，无后续。1.收到消息前，取消时我直接调上游的dispose取消就行了。2.但我收到上游消息之后，就和上游无关了，我直接把我内部 延迟那个定时器取消就行了。
	* Observable.map 有后续，无延迟。
	* Observable.delay 无后续，有延迟
* 线程切换

参考资料： https://www.jianshu.com/p/931d855d6b55
