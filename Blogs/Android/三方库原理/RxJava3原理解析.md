RxJava3原理解析
---
#### 目录
- [背景](#head1)
- [基础使用](#head2)
- [just : 最简单的订阅关系](#head3)
- [map 操作符](#head4)
	- [框架结构](#head5)
	- [操作符Operator（map等）的本质](#head6)
- [dispose工作原理](#head7)
	- [Single.just 无后续，无延迟](#head8)
	- [Observable.interval 有后续，有延迟](#head9)
	- [Single.map 无后续，无延迟，有上下游](#head10)
	- [Single.delay 无后续，有延迟](#head11)
	- [Observable.map 有后续，无延迟](#head12)
	- [Observable.delay 无后续，有延迟](#head13)
- [线程切换](#head14)
	- [subscribeOn](#head15)
	- [observeOn](#head16)
	- [Scheduler的原理](#head17)
	- [小案例图解](#head18)
- [小结](#head19)

---

### <span id="head1">背景</span>

RxJava是一个基于事件流、实现异步操作的库。

官方介绍： RxJava：a library for composing asynchronous and event-based programs using observable sequences for the Java VM
（RxJava 是一个在 Java VM 上使用可观测的序列来组成异步的、基于事件的程序的库）

> 文中用到的RxJava源码版本为3.0.13，文中的demo源码 https://github.com/xfhy/AllInOne/tree/master/app/src/main/java/com/xfhy/allinone/opensource/rxjava

### <span id="head2">基础使用</span>

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

### <span id="head3">just : 最简单的订阅关系</span>

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


### <span id="head4">map 操作符</span>

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

#### <span id="head5">框架结构</span>

RxJava的整体结构是一条链，其中：

1. 链的最上游：生产者Observable
2. 链的最下游：观察者Observer
3. 链的中间：各个中介节点，既是下游的Observable，又是上游的Observer

#### <span id="head6">操作符Operator（map等）的本质</span>

1. 基于原Observable创建一个新的Observable
2. Observable内部创建一个Observer
3. 通过定制Observable的subscribeActual()方法和Observer的onXxx()方法，来实现自己的中介角色（例如数据转换、线程切换等）

### <span id="head7">dispose工作原理</span>

可以通过dispose()方法来让上游或内部调度器（或两者都有）停止工作，达到「丢弃」的效果。

下面分别讲一下这几种情况：

- Single.just 无后续，无延迟
- Observable.interval 有后续，有延迟
- Single.map 无后续，无延迟，有上下游
- Single.delay 无后续，有延迟
- Observable.map 有后续，无延迟
- Observable.delay 无后续，有延迟

这几种情况已经足够把所有dispose的情况都说明完整了。

#### <span id="head8">Single.just 无后续，无延迟</span>

对于Single.just，情况比较简单，在SingleJust的subscribeActual中，给观察者一个全局共享的Disposable对象。下游不能对其进行取消，因为间隔太短了，马上就调用onSuccess了。

```java
@Override
protected void subscribeActual(SingleObserver<? super T> observer) {
    observer.onSubscribe(Disposable.disposed());
    observer.onSuccess(value);
}
```

#### <span id="head9">Observable.interval 有后续，有延迟</span>

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

#### <span id="head10">Single.map 无后续，无延迟，有上下游</span>

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
        //t是下游
        //订阅
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

一开场就直接调用上游source订阅MapSingleObserver这个观察者。在MapSingleObserver的逻辑也比较简单,就是实现了onSubscribe、onSuccess、onError这些方法。然后在上游调用onSubscribe时调用下游的onSubscribe；在上游调用onSuccess时自己做了一下`mapper.apply(value)`转换操作，将数据转换成下游所需要的，然后再调用下游的onSuccess传递给下游；onError同onSubscribe原理是一样的。

#### <span id="head11">Single.delay 无后续，有延迟</span>

来段示例代码:

```kotlin
val singleInt: Single<Int> = Single.just(1)
val singleDelay: Single<Int> = singleInt.delay(1, TimeUnit.SECONDS)
val observer = object : SingleObserver<Int> {
    override fun onSubscribe(d: Disposable?) {
        log("onSubscribe")
    }

    override fun onSuccess(t: Int?) {
        log("onSuccess")
    }

    override fun onError(e: Throwable?) {
        log("onError")
    }
}
singleDelay.subscribe(observer)
```

直捣黄龙，Single.delay背后的对象是SingleDelay。现在有经验了，直接看它的subscribeActual

```java
@Override
protected void subscribeActual(final SingleObserver<? super T> observer) {
    //可以确定的是这是一个Disposable
    final SequentialDisposable sd = new SequentialDisposable();
    //将这个Disposable通过onSubscribe传递给下游
    observer.onSubscribe(sd);
    //让上游订阅Delay这个观察者
    source.subscribe(new Delay(sd, observer));
}
```

看下SequentialDisposable是什么玩意儿

```java
public final class SequentialDisposable
extends AtomicReference<Disposable>
implements Disposable {
    public SequentialDisposable() {
        // nothing to do
    }
    public SequentialDisposable(Disposable initial) {
        lazySet(initial);
    }
    public boolean update(Disposable next) {
        return DisposableHelper.set(this, next);
    }
    public boolean replace(Disposable next) {
        return DisposableHelper.replace(this, next);
    }

    @Override
    public void dispose() {
        DisposableHelper.dispose(this);
    }

    @Override
    public boolean isDisposed() {
        return DisposableHelper.isDisposed(get());
    }
}
```

似曾相识，上面的IntervalObserver也是这种思想。只不过这里多了2个update和replace方法，可以随时更换AtomicReference里面的Disposable对象。这就体现出了这种设计的好处，不管里面的Disposable怎么更换，传递给下游的是这个SequentialDisposable，下游只需要调SequentialDisposable的dispose就将其里面的Disposable给取消掉了，而不用管里面的Disposable究竟是谁。

下面咱们来看SingleDelay里面的内部类Delay（观察者）

```java
final class Delay implements SingleObserver<T> {
    //传递给下游的Disposable
    private final SequentialDisposable sd;
    //下游的观察者
    final SingleObserver<? super T> downstream;

    Delay(SequentialDisposable sd, SingleObserver<? super T> observer) {
        this.sd = sd;
        this.downstream = observer;
    }

    @Override
    public void onSubscribe(Disposable d) {
        //开始订阅的时候，sd内部的Disposable是上游给过来的
        sd.replace(d);
    }

    @Override
    public void onSuccess(final T value) {
        //上游把数据给过来之后，就不用管上游了，直接把sd里面Disposable 设置成线程调度器给回来那个
        //因为此时下游调用dispose的话，直接取消调度器里面的任务就行了
        //巧妙地将sd里面的Disposable掉包了
        sd.replace(scheduler.scheduleDirect(new OnSuccess(value), time, unit));
    }

    @Override
    public void onError(final Throwable e) {
        sd.replace(scheduler.scheduleDirect(new OnError(e), delayError ? time : 0, unit));
    }

    final class OnSuccess implements Runnable {
        private final T value;

        OnSuccess(T value) {
            this.value = value;
        }

        @Override
        public void run() {
            //调度器执行到该任务时，将数据传递给下游
            downstream.onSuccess(value);
        }
    }

    final class OnError implements Runnable {
        private final Throwable e;

        OnError(Throwable e) {
            this.e = e;
        }

        @Override
        public void run() {
            downstream.onError(e);
        }
    }
}
```

这段代码比较精彩，首先在上游订阅Delay的时候，触发onSubscribe，Delay内部随即将该Disposable存入SequentialDisposable对象（需要注意的是下游拿到的Disposable始终是这个SequentialDisposable）中。此时如果下游调用dispose，也就是调用SequentialDisposable的dispose，也就是上游的dispose，dispose流程在这个节点上就完成了，向上传递。

上游有数据了，通过onSuccess传递给观察者Delay的时候，SequentialDisposable就可以不用管上游的那个Disposable了，此时要关心的是传递给线程调度器里面的任务的取消事件了。所以直接将调度器返回的Disposable替换到SequentialDisposable内部，此时下游进行取消时，就直接把任务给取消掉了。

当调度器执行到任务OnSuccess时，就把数据传递给下游，这个节点的任务就完成了。

#### <span id="head12">Observable.map 有后续，无延迟</span>

Observable.map所对应的是ObservableMap，直接上代码：

```java
public final class ObservableMap<T, U> extends AbstractObservableWithUpstream<T, U> {
    final Function<? super T, ? extends U> function;

    public ObservableMap(ObservableSource<T> source, Function<? super T, ? extends U> function) {
        super(source);
        this.function = function;
    }

    @Override
    public void subscribeActual(Observer<? super U> t) {
        //t是下游的观察者
        //source是上游
        source.subscribe(new MapObserver<T, U>(t, function));
    }

    static final class MapObserver<T, U> extends BasicFuseableObserver<T, U> {
        final Function<? super T, ? extends U> mapper;

        MapObserver(Observer<? super U> actual, Function<? super T, ? extends U> mapper) {
            super(actual);
            this.mapper = mapper;
        }

        @Override
        public void onNext(T t) {
            if (done) {
                return;
            }

            if (sourceMode != NONE) {
                downstream.onNext(null);
                return;
            }

            U v;

            try {
                v = Objects.requireNonNull(mapper.apply(t), "The mapper function returned a null value.");
            } catch (Throwable ex) {
                fail(ex);
                return;
            }
            downstream.onNext(v);
        }

        @Override
        public int requestFusion(int mode) {
            return transitiveBoundaryFusion(mode);
        }

        @Nullable
        @Override
        public U poll() throws Throwable {
            T t = qd.poll();
            return t != null ? Objects.requireNonNull(mapper.apply(t), "The mapper function returned a null value.") : null;
        }
    }
}
```

在subscribeActual中并没有直接调用onSubscribe,而MapObserver中又没有这个方法，那onSubscribe肯定是在其父类中完成的。在看onSubscribe之前咱干脆先把onNext理一下，这里通过mapper.apply转一下之后马上就交给下游的onNext去了。

```java
//BasicFuseableObserver.java
public abstract class BasicFuseableObserver<T, R> implements Observer<T>, QueueDisposable<R> {
    public BasicFuseableObserver(Observer<? super R> downstream) {
        this.downstream = downstream;
    }
    @Override
    public final void onSubscribe(Disposable d) {
        //验证上游   d是上游的Disposable   upstream是当前类的字段，还没有被赋值
        if (DisposableHelper.validate(this.upstream, d)) {
            this.upstream = d;
            if (d instanceof QueueDisposable) {
                this.qd = (QueueDisposable<T>)d;
            }
            //onSubscribe之前想做点什么事情的话，在beforeDownstream里面做
            if (beforeDownstream()) {
                //调用下游的onSubscribe
                downstream.onSubscribe(this);
                //onSubscribe之后想做点什么事情的话，在afterDownstream里面做
                afterDownstream();
            }

        }
    }
    protected boolean beforeDownstream() {
        return true;
    }
    protected void afterDownstream() {
    }
    @Override
    public void dispose() {
        upstream.dispose();
    }
}

//DisposableHelper.java
public static boolean validate(Disposable current, Disposable next) {
    if (next == null) {
        RxJavaPlugins.onError(new NullPointerException("next is null"));
        return false;
    }
    if (current != null) {
        next.dispose();
        reportDisposableSet();
        return false;
    }
    return true;
}
```

还是先调用下游的onSubscribe，不过，并没有将上游的Disposable直接传给下游，而是将中间节点BasicFuseableObserver自己传给了下游，同时将上游的Disposable存储起来，方便待会儿dispose。

#### <span id="head13">Observable.delay 无后续，有延迟</span>

Observable.delay 对应的是ObservableDelay

```java
public final class ObservableDelay<T> extends AbstractObservableWithUpstream<T, T> {
    @Override
    @SuppressWarnings("unchecked")
    public void subscribeActual(Observer<? super T> t) {
        Observer<T> observer;
        if (delayError) {
            observer = (Observer<T>)t;
        } else {
            observer = new SerializedObserver<>(t);
        }
        Scheduler.Worker w = scheduler.createWorker();
        source.subscribe(new DelayObserver<>(observer, delay, unit, w, delayError));
    }
}
```

在subscribeActual没有调用下游的onSubscribe，那说明是在DelayObserver中完成的

```java
static final class DelayObserver<T> implements Observer<T>, Disposable {
    final Scheduler.Worker w;
    Disposable upstream;

    DelayObserver(Observer<? super T> actual, long delay, TimeUnit unit, Worker w, boolean delayError) {
        super();
        this.downstream = actual;
        this.w = w;
        ...
    }

    @Override
    public void onSubscribe(Disposable d) {
        //1. 先验证一下上游  然后将上游的Disposable赋值给upstream
        //2. 调用下游的onSubscribe，把自己传给下游
        if (DisposableHelper.validate(this.upstream, d)) {
            this.upstream = d;
            downstream.onSubscribe(this);
        }
    }

    @Override
    public void onNext(final T t) {
        //OnNext任务提交给调度器执行->在执行任务时调用下游的onNext方法
        w.schedule(new OnNext(t), delay, unit);
    }

    @Override
    public void onError(final Throwable t) {
        w.schedule(new OnError(t), delayError ? delay : 0, unit);
    }

    @Override
    public void onComplete() {
        w.schedule(new OnComplete(), delay, unit);
    }

    @Override
    public void dispose() {
        //同时取消上游的Disposable和自己执行的调度器任务
        upstream.dispose();
        w.dispose();
    }

    final class OnNext implements Runnable {
        private final T t;

        OnNext(T t) {
            this.t = t;
        }

        @Override
        public void run() {
            downstream.onNext(t);
        }
    }
    ...
}
```

onXxx的所有操作都放到了DelayObserver里面来完成，在上游调用到这节的onSubscribe时，先验证一下上游  然后将上游的Disposable赋值给upstream，调用下游的onSubscribe，把自己传给下游。

当下游调用dispose时，在DelayObserver的dispose方法中将上游的Disposable给取消掉，然后把自己的调度器任务也给取消掉。

事件的传递：当上游调用到这一节的onNext时，OnNext任务（Runnable）提交给调度器执行->在执行任务时调用下游的onNext方法。

### <span id="head14">线程切换</span>

线程切换是RxJava的另一个重要功能。

#### <span id="head15">subscribeOn</span>

subscribeOn在Single场景下对应的是SingleSubscribeOn这个类

```java
public final class SingleSubscribeOn<T> extends Single<T> {
    final Scheduler scheduler;

    public SingleSubscribeOn(SingleSource<? extends T> source, Scheduler scheduler) {
        this.source = source;
        this.scheduler = scheduler;
    }
    @Override
    protected void subscribeActual(final SingleObserver<? super T> observer) {
        final SubscribeOnObserver<T> parent = new SubscribeOnObserver<>(observer, source);
        observer.onSubscribe(parent);
        
        //切线程
        Disposable f = scheduler.scheduleDirect(parent);

        parent.task.replace(f);

    }
}
```

直接看subscribeActual方法，很明显是将parent这个任务交给了线程调度器去执行。那我们直接看SubscribeOnObserver的run方法即可

```java
static final class SubscribeOnObserver<T>
extends AtomicReference<Disposable>
implements SingleObserver<T>, Disposable, Runnable {
    @Override
    public void run() {
        source.subscribe(this);
    }
}
```

在scheduleDirect那里切线程，然后在另一个线程中去执行`source.subscribe(this)`，也就是**在Scheduler指定的线程里启动subscribe（订阅）。**

- 切换起源Observable的线程
- 当多次调用subscribeOn()的时候，只有最上面的会对起源Observable起作用

#### <span id="head16">observeOn</span>

observeOn在Single场景下的类是SingleObserveOn。它的subscribeActual方法如下：

```java
@Override
protected void subscribeActual(final SingleObserver<? super T> observer) {
    source.subscribe(new ObserveOnSingleObserver<>(observer, scheduler));
}
```

上游订阅了ObserveOnSingleObserver这个观察者，核心就在这个观察者里面。

```java
static final class ObserveOnSingleObserver<T> extends AtomicReference<Disposable>
    implements SingleObserver<T>, Disposable, Runnable {
    private static final long serialVersionUID = 3528003840217436037L;

    final SingleObserver<? super T> downstream;

    final Scheduler scheduler;

    T value;
    Throwable error;

    ObserveOnSingleObserver(SingleObserver<? super T> actual, Scheduler scheduler) {
        this.downstream = actual;
        this.scheduler = scheduler;
    }

    @Override
    public void onSubscribe(Disposable d) {
        if (DisposableHelper.setOnce(this, d)) {
            downstream.onSubscribe(this);
        }
    }

    @Override
    public void onSuccess(T value) {
        this.value = value;
        Disposable d = scheduler.scheduleDirect(this);
        DisposableHelper.replace(this, d);
    }

    @Override
    public void onError(Throwable e) {
        this.error = e;
        Disposable d = scheduler.scheduleDirect(this);
        DisposableHelper.replace(this, d);
    }

    @Override
    public void run() {
        Throwable ex = error;
        if (ex != null) {
            downstream.onError(ex);
        } else {
            downstream.onSuccess(value);
        }
    }
    ...
}
```

我们重点关注一下onSuccess和onError方法，核心就是将当前这个Runnable任务交给scheduler进行执行，而这里的scheduler是由使用者传入的，比如说是AndroidSchedulers.mainThread()。那么在run方法执行时，就会在主线程中，那么在主线程中执行下游的onError和onSuccess。  这里通过Scheduler指定的线程来调用下级Observer的对应回调方法。

- 切换observeOn下面的Observer的回调所在的线程
- 当多次调用observerOn()的时候，每个都好进行一次线程切换，影响范围是它下面的每个Observer（除非又遇到新的obServeOn()）

#### <span id="head17">Scheduler的原理</span>

上面我们多次提到Scheduler，但是一直不知道它具体是什么。其实它就是用来控制控制线程的，用于将指定的逻辑在指定的线程中执行。这里就不带着大家读源码了，篇幅过于长了，这块源码也比较简单，感兴趣的读者可以去翻阅一下。下面是几个核心点。

其中Schedulers.newThread()里面是创建了一个线程池`Executors.newScheduledThreadPool(1, factory)`来执行任务，但是这个线程池里面的线程不会得到重用，每次都是新建的线程池。当 scheduleDirect() 被调用的时候，会创建一个 Worker，Worker 的内部 会有一个 Executor，由 Executor 来完成实际的线程切换;scheduleDirect() 还会创建出一个 Disposable 对象，交给外层的 Observer，让它能执行 dispose() 操作，取消订阅链;

Schedulers.io()和Schedulers.newThread()差别不大，但是io()这儿线程可能会被重用，所以一般io()用得多一些。

AndroidSchedulers.mainThread()就更简单了，直接使用Handler进行线程切换，将任务放到主线程去做，不管再怎么花里胡哨的库，最后要切到主线程还得靠Handler。


#### <span id="head18">小案例图解</span>

下图中详细解释了RxJava在线程切换时的情况

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/RxJava%E7%BA%BF%E7%A8%8B%E5%88%87%E6%8D%A2%E5%9B%BE%E8%A7%A3.png)

### <span id="head19">小结</span>

Rxjava由于其**基于事件流的链式调用、逻辑简洁 & 使用简单**的特点，深受各大 Android开发者的欢迎。平时在项目中也使用得比较多，所以本文对RxJava3中的订阅流程、取消流程、线程切换进行了核心源码分析，希望能帮助到各位。
