
kotlin的协程封装了线程的API，这个线程框架可以让我们很方便得编写异步代码。

虽然协程已经很方便了，但是如果再配合Google提供的架构组件的KTX扩展一起使用，那就更方便了。

### 添加KTX依赖

```groovy
//将 Kotlin 协程与架构组件一起使用

//ViewModelScope
implementation 'androidx.lifecycle:lifecycle-viewmodel-ktx:2.3.1'
//LifecycleScope
implementation 'androidx.lifecycle:lifecycle-runtime-ktx:2.2.0'
//liveData
implementation 'androidx.lifecycle:lifecycle-livedata-ktx:2.2.0'
```

### ViewModelScope

#### 用老方式在ViewModel中使用协程

在使用ViewModelScope之前，先来回顾一下以前在ViewModel中使用协程的方式。自己管理CoroutineScope，在不需要的时候（一般是在onCleared()）进行取消。否则，可能造成资源浪费、内存泄露等问题。

```kotlin
class JetpackCoroutineViewModel : ViewModel() {
    //在这个ViewModel中使用协程时,需要使用这个job来方便控制取消
    private val viewModelJob = SupervisorJob()
    
    //指定协程在哪里执行,并且可以由viewModelJob很方便地取消uiScope
    private val uiScope = CoroutineScope(Dispatchers.Main + viewModelJob)
    
    fun launchDataByOldWay() {
        uiScope.launch {
            //在后台执行
            val result = getNetData()
            //修改UI
            log(result)
        }
    }
    
    override fun onCleared() {
        super.onCleared()
        viewModelJob.cancel()
    }
    
    //将耗时任务切到IO线程去执行
    private suspend fun getNetData() = withContext(Dispatchers.IO) {
        //模拟网络耗时
        delay(1000)
        //模拟返回结果
        "{}"
    }
}
```

看起来有很多的样板代码，而且在不需要的时候取消协程很容易忘。

#### 新方式在ViewModel中使用协程

正是在这种情况下，Google为我们创造了ViewModelScope，它通过向ViewModel类添加扩展属性来方便我们使用协程，而且在ViewModel被销毁时会自动取消其子协程。

```kotlin
class JetpackCoroutineViewModel : ViewModel() {
    fun launchData() {
        viewModelScope.launch {
            //在后台执行
            val result = getNetData()
            //修改UI
            log(result)
        }
    }

    //将耗时任务切到IO线程去执行
    private suspend fun getNetData() = withContext(Dispatchers.IO) {
        //模拟网络耗时
        delay(1000)
        //模拟返回结果
        "{}"
    }

}
```

所有CoroutineScope的初始化和取消都已经为我们完成了，只需要在代码里面使用`viewModelScope`即可开启一个新协程，而且还不用担心忘记取消的问题。

下面我们来看看Google是怎么实现的。

#### 深入研究viewModelScope

点进去看看源码，知根知底，万一后面遇到什么奇怪的bug，在知道原理的情况下，才能更快的想到解决办法。

```kotlin
private const val JOB_KEY = "androidx.lifecycle.ViewModelCoroutineScope.JOB_KEY"

/**
 * [CoroutineScope] tied to this [ViewModel].
 * This scope will be canceled when ViewModel will be cleared, i.e [ViewModel.onCleared] is called
 *
 * This scope is bound to
 * [Dispatchers.Main.immediate][kotlinx.coroutines.MainCoroutineDispatcher.immediate]
 */
public val ViewModel.viewModelScope: CoroutineScope
    get() {
        //先从缓存中取值，有就直接返回
        val scope: CoroutineScope? = this.getTag(JOB_KEY)
        if (scope != null) {
            return scope
        }
        //没有缓存就新建一个CloseableCoroutineScope
        return setTagIfAbsent(
            JOB_KEY,
            CloseableCoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        )
    }

internal class CloseableCoroutineScope(context: CoroutineContext) : Closeable, CoroutineScope {
    override val coroutineContext: CoroutineContext = context

    override fun close() {
        coroutineContext.cancel()
    }
}
```

源码中首先是介绍了viewModelScope是什么，它其实是一个ViewModel的扩展属性，它的实际类型是CloseableCoroutineScope。这名字看起来就是一个可以取消的协程，果不其然，它实现了Closeable并在close方法中进行了取消。

每次在使用viewModelScope的时候，会先从缓存中取，如果没有才去新建一个CloseableCoroutineScope。需要注意的是，CloseableCoroutineScope的执行是在主线程中执行的。

我们现在需要知道的是缓存是怎么存储和取出的。

```java
//ViewModel.java

// Can't use ConcurrentHashMap, because it can lose values on old apis (see b/37042460)
@Nullable
private final Map<String, Object> mBagOfTags = new HashMap<>();
/**
 * Returns the tag associated with this viewmodel and the specified key.
 */
@SuppressWarnings({"TypeParameterUnusedInFormals", "unchecked"})
<T> T getTag(String key) {
    if (mBagOfTags == null) {
        return null;
    }
    synchronized (mBagOfTags) {
        return (T) mBagOfTags.get(key);
    }
}

/**
 * Sets a tag associated with this viewmodel and a key.
 * If the given {@code newValue} is {@link Closeable},
 * it will be closed once {@link #clear()}.
 * <p>
 * If a value was already set for the given key, this calls do nothing and
 * returns currently associated value, the given {@code newValue} would be ignored
 * <p>
 * If the ViewModel was already cleared then close() would be called on the returned object if
 * it implements {@link Closeable}. The same object may receive multiple close calls, so method
 * should be idempotent.
 */
@SuppressWarnings("unchecked")
<T> T setTagIfAbsent(String key, T newValue) {
    T previous;
    synchronized (mBagOfTags) {
        previous = (T) mBagOfTags.get(key);
        if (previous == null) {
            mBagOfTags.put(key, newValue);
        }
    }
    T result = previous == null ? newValue : previous;
    if (mCleared) {
        // It is possible that we'll call close() multiple times on the same object, but
        // Closeable interface requires close method to be idempotent:
        // "if the stream is already closed then invoking this method has no effect." (c)
        closeWithRuntimeException(result);
    }
    return result;
}

```

现在我们知道了，原来是存在了ViewModel的mBagOfTags中，它是一个HashMap。

知道了怎么存的，那么它是在什么时候用的呢？

```java
@MainThread
final void clear() {
    mCleared = true;
    // Since clear() is final, this method is still called on mock objects
    // and in those cases, mBagOfTags is null. It'll always be empty though
    // because setTagIfAbsent and getTag are not final so we can skip
    // clearing it
    if (mBagOfTags != null) {
        synchronized (mBagOfTags) {
            for (Object value : mBagOfTags.values()) {
                // see comment for the similar call in setTagIfAbsent
                closeWithRuntimeException(value);
            }
        }
    }
    onCleared();
}

private static void closeWithRuntimeException(Object obj) {
    if (obj instanceof Closeable) {
        try {
            ((Closeable) obj).close();
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
}
```

我在ViewModel中搜索了一下mBagOfTags，发现有一个clear方法，在里面将mBagOfTags遍历一遍，然后将所有value是Closeable的全部close。在上面的源码中，第一次使用viewModelScope的时候，会创建一个CloseableCoroutineScope，它实现了Closeable接口，并实现了close方法，刚好用来做取消操作。

看到这里，我们知道了：viewModelScope构建的协程是在ViewModel的clear方法回调时取消协程的。

而且，clear方法里面居然还有我们熟悉的onCleared方法调用。而onCleared我们知道是干什么的，当这个ViewModel不再使用时会回调这个方法，一般我们需要在此方法中做一些收尾工作，如取消观察者订阅、关闭资源之类的。

那么，大胆猜测一下，这个clear()方法应该也是在ViewModel要结束生命的时候调用的。

搜索了一下，发现clear方法是在ViewModelStore里面调用的。

```java
public class ViewModelStore {

    private final HashMap<String, ViewModel> mMap = new HashMap<>();

    final void put(String key, ViewModel viewModel) {
        ViewModel oldViewModel = mMap.put(key, viewModel);
        if (oldViewModel != null) {
            oldViewModel.onCleared();
        }
    }

    final ViewModel get(String key) {
        return mMap.get(key);
    }

    Set<String> keys() {
        return new HashSet<>(mMap.keySet());
    }

    /**
     *  Clears internal storage and notifies ViewModels that they are no longer used.
     */
    public final void clear() {
        for (ViewModel vm : mMap.values()) {
            vm.clear();
        }
        mMap.clear();
    }
}
```

ViewModelStore是一个容器，用于盛放ViewModel。在ViewModelStore的clear方法中调用了该ViewModelStore中所有ViewModel的clear方法。那么ViewModelStore的clear是在哪里调用的？我跟着追踪，发现是在ComponentActivity的构造方法中。

```java
public ComponentActivity() {
    Lifecycle lifecycle = getLifecycle();
    getLifecycle().addObserver(new LifecycleEventObserver() {
        @Override
        public void onStateChanged(@NonNull LifecycleOwner source,
                @NonNull Lifecycle.Event event) {
            if (event == Lifecycle.Event.ON_DESTROY) {
                if (!isChangingConfigurations()) {
                    getViewModelStore().clear();
                }
            }
        }
    });
}
```

在Activity的生命周期走到onDestroy的时候调用ViewModelStore的clear做收尾工作。但是，注意一下，这个调用有个前提，此次走onDestroy不是因为配置更改才会去调用clear方法。

好的，到此为止，咱们理通了viewModelScope的协程是怎么做到自动取消的（ViewModel的mBagOfTags），以及是在什么时候进行取消的（ViewModel的clear()时）。

### LifecycleScope

对于Lifecycle，Google贴心地提供了LifecycleScope，我们可以直接通过launch来创建Coroutine。

#### 使用

举个简单例子，比如在Activity的onCreate里面,每隔100毫秒更新一下TextView的文字。

```kotlin
lifecycleScope.launch {
    repeat(100000) {
        delay(100)
        tvText.text = "$it"
    }
}
```

因为LifeCycle是可以感知组件的生命周期的，所以Activity一旦onDestroy了，相应的上面这个lifecycleScope。launch闭包的调用也会取消。

另外，lifecycleScope还贴心地提供了launchWhenCreated、launchWhenStarted、launchWhenResumed方法，这些方法的闭包里面有协程的作用域，它们分别是在CREATED、STARTED、RESUMED时被执行。

```kotlin
//方式1
lifecycleScope.launchWhenStarted {
    repeat(100000) {
        delay(100)
        tvText.text = "$it"
    }
}
//方式2
lifecycleScope.launch {
    whenStarted { 
        repeat(100000) {
            delay(100)
            tvText.text = "$it"
        }
    }
}
```

不管是直接调用launchWhenStarted还是在launch中调用whenStarted都能达到同样的效果。

#### LifecycleScope的底层实现

先来看下lifecycleScope.launch是怎么做到的

```kotlin
/**
 * [CoroutineScope] tied to this [LifecycleOwner]'s [Lifecycle].
 *
 * This scope will be cancelled when the [Lifecycle] is destroyed.
 *
 * This scope is bound to
 * [Dispatchers.Main.immediate][kotlinx.coroutines.MainCoroutineDispatcher.immediate].
 */
val LifecycleOwner.lifecycleScope: LifecycleCoroutineScope
    get() = lifecycle.coroutineScope
```

好家伙，又是扩展属性。这次扩展的是LifecycleOwner，返回了一个LifecycleCoroutineScope。每次在get的时候，是返回的lifecycle.coroutineScope，看看这个是啥。

```kotlin
/**
 * [CoroutineScope] tied to this [Lifecycle].
 *
 * This scope will be cancelled when the [Lifecycle] is destroyed.
 *
 * This scope is bound to
 * [Dispatchers.Main.immediate][kotlinx.coroutines.MainCoroutineDispatcher.immediate]
 */
val Lifecycle.coroutineScope: LifecycleCoroutineScope
    get() {
        while (true) {
            val existing = mInternalScopeRef.get() as LifecycleCoroutineScopeImpl?
            if (existing != null) {
                return existing
            }
            val newScope = LifecycleCoroutineScopeImpl(
                this,
                SupervisorJob() + Dispatchers.Main.immediate
            )
            if (mInternalScopeRef.compareAndSet(null, newScope)) {
                newScope.register()
                return newScope
            }
        }
    }
```
Lifecycle的coroutineScope也是扩展属性，它是一个LifecycleCoroutineScope。从注释可以看到，在Lifecycle被销毁之后，这个协程会跟着取消。这里首先会从mInternalScopeRef中取之前存入的缓存，如果没有再生成一个LifecycleCoroutineScopeImpl放进去，并调用LifecycleCoroutineScopeImpl的register函数。这里的mInternalScopeRef是Lifecycle类里面的一个属性： `AtomicReference<Object> mInternalScopeRef = new AtomicReference<>();` （AtomicReference可以让一个对象保证原子性）。这里使用AtomicReference当然是为了线程安全。

既然生成的是LifecycleCoroutineScopeImpl，那么就先来看看这个东西是什么

```kotlin
internal class LifecycleCoroutineScopeImpl(
    override val lifecycle: Lifecycle,
    override val coroutineContext: CoroutineContext
) : LifecycleCoroutineScope(), LifecycleEventObserver {
    init {
        // in case we are initialized on a non-main thread, make a best effort check before
        // we return the scope. This is not sync but if developer is launching on a non-main
        // dispatcher, they cannot be 100% sure anyways.
        if (lifecycle.currentState == Lifecycle.State.DESTROYED) {
            coroutineContext.cancel()
        }
    }

    fun register() {
        //启了个协程，当前Lifecycle的state大于等于INITIALIZED，就注册一下Lifecycle的观察者，观察生命周期
        launch(Dispatchers.Main.immediate) {
            if (lifecycle.currentState >= Lifecycle.State.INITIALIZED) {
                lifecycle.addObserver(this@LifecycleCoroutineScopeImpl)
            } else {
                coroutineContext.cancel()
            }
        }
    }

    override fun onStateChanged(source: LifecycleOwner, event: Lifecycle.Event) {
        //观察到当前生命周期小于等于DESTROYED，那么就移除当前这个观察者并且取消协程
        if (lifecycle.currentState <= Lifecycle.State.DESTROYED) {
            lifecycle.removeObserver(this)
            coroutineContext.cancel()
        }
    }
}
```

在上面的代码中，有2个重要的函数：register和onStateChanged。register函数是在初始化LifecycleCoroutineScopeImpl的时候调用的，先在register函数中添加一个观察者用于观察生命周期的变化，然后在onStateChanged函数中判断生命周期到DESTROYED时就移除观察者并且取消协程。

有个小细节，为啥register函数中能直接启协程？是因为LifecycleCoroutineScopeImpl继承了LifecycleCoroutineScope,，而LifecycleCoroutineScope实现了CoroutineScope接口(其实是在LifecycleCoroutineScopeImpl中实现的)。

```kotlin
public abstract class LifecycleCoroutineScope internal constructor() : CoroutineScope {
    internal abstract val lifecycle: Lifecycle
    ......
}
```

现在我们流程理清楚了，**lifecycleScope使用时会构建一个协程，同时会观察组件的生命周期，在适当的时机（DESTROYED）取消协程。**

在上面的实例我们见过一段代码：

```kotlin
//方式1
lifecycleScope.launchWhenStarted {
    repeat(100000) {
        delay(100)
        tvText.text = "$it"
    }
}
//方式2
lifecycleScope.launch {
    whenStarted { 
        repeat(100000) {
            delay(100)
            tvText.text = "$it"
        }
    }
}
```

可以直接通过lifecycleScope提供的launchWhenCreated、launchWhenStarted、launchWhenResumed在相应的生命周期时执行协程。

点进去看一下

```kotlin
abstract class LifecycleCoroutineScope internal constructor() : CoroutineScope {
    internal abstract val lifecycle: Lifecycle

    /**
     * Launches and runs the given block when the [Lifecycle] controlling this
     * [LifecycleCoroutineScope] is at least in [Lifecycle.State.CREATED] state.
     *
     * The returned [Job] will be cancelled when the [Lifecycle] is destroyed.
     * @see Lifecycle.whenCreated
     * @see Lifecycle.coroutineScope
     */
    fun launchWhenCreated(block: suspend CoroutineScope.() -> Unit): Job = launch {
        lifecycle.whenCreated(block)
    }

    /**
     * Launches and runs the given block when the [Lifecycle] controlling this
     * [LifecycleCoroutineScope] is at least in [Lifecycle.State.STARTED] state.
     *
     * The returned [Job] will be cancelled when the [Lifecycle] is destroyed.
     * @see Lifecycle.whenStarted
     * @see Lifecycle.coroutineScope
     */

    fun launchWhenStarted(block: suspend CoroutineScope.() -> Unit): Job = launch {
        lifecycle.whenStarted(block)
    }

    /**
     * Launches and runs the given block when the [Lifecycle] controlling this
     * [LifecycleCoroutineScope] is at least in [Lifecycle.State.RESUMED] state.
     *
     * The returned [Job] will be cancelled when the [Lifecycle] is destroyed.
     * @see Lifecycle.whenResumed
     * @see Lifecycle.coroutineScope
     */
    fun launchWhenResumed(block: suspend CoroutineScope.() -> Unit): Job = launch {
        lifecycle.whenResumed(block)
    }
}
```
原来这些函数就是LifecycleOwner的扩展属性lifecycleScope所返回的LifecycleCoroutineScope类里面的函数。这几个函数里面啥也没干，直接调用了lifecycle对应的函数

```kotlin
/**
 * Runs the given block when the [Lifecycle] is at least in [Lifecycle.State.CREATED] state.
 *
 * @see Lifecycle.whenStateAtLeast for details
 */
suspend fun <T> Lifecycle.whenCreated(block: suspend CoroutineScope.() -> T): T {
    return whenStateAtLeast(Lifecycle.State.CREATED, block)
}

/**
 * Runs the given block when the [Lifecycle] is at least in [Lifecycle.State.STARTED] state.
 *
 * @see Lifecycle.whenStateAtLeast for details
 */
suspend fun <T> Lifecycle.whenStarted(block: suspend CoroutineScope.() -> T): T {
    return whenStateAtLeast(Lifecycle.State.STARTED, block)
}

/**
 * Runs the given block when the [Lifecycle] is at least in [Lifecycle.State.RESUMED] state.
 *
 * @see Lifecycle.whenStateAtLeast for details
 */
suspend fun <T> Lifecycle.whenResumed(block: suspend CoroutineScope.() -> T): T {
    return whenStateAtLeast(Lifecycle.State.RESUMED, block)
}
```

这几个函数原来是suspend函数，并且是扩展Lifecycle的函数。它们最终都调用到了whenStateAtLeast函数，并传入了执行协程的最小的生命周期状态标志（minState）。

```kotlin
suspend fun <T> Lifecycle.whenStateAtLeast(
    minState: Lifecycle.State,
    block: suspend CoroutineScope.() -> T
) = withContext(Dispatchers.Main.immediate) {
    val job = coroutineContext[Job] ?: error("when[State] methods should have a parent job")
    val dispatcher = PausingDispatcher()
    val controller =
        LifecycleController(this@whenStateAtLeast, minState, dispatcher.dispatchQueue, job)
    try {
        //执行协程
        withContext(dispatcher, block)
    } finally {
        //收尾工作  移除生命周期观察
        controller.finish()
    }
}

@MainThread
internal class LifecycleController(
    private val lifecycle: Lifecycle,
    private val minState: Lifecycle.State,
    private val dispatchQueue: DispatchQueue,
    parentJob: Job
) {
    private val observer = LifecycleEventObserver { source, _ ->
        if (source.lifecycle.currentState == Lifecycle.State.DESTROYED) {
            //DESTROYED->取消协程
            handleDestroy(parentJob)
        } else if (source.lifecycle.currentState < minState) {
            dispatchQueue.pause()
        } else {
            //执行
            dispatchQueue.resume()
        }
    }

    init {
        // If Lifecycle is already destroyed (e.g. developer leaked the lifecycle), we won't get
        // an event callback so we need to check for it before registering
        // see: b/128749497 for details.
        if (lifecycle.currentState == Lifecycle.State.DESTROYED) {
            handleDestroy(parentJob)
        } else {
            //观察生命周期变化
            lifecycle.addObserver(observer)
        }
    }

    @Suppress("NOTHING_TO_INLINE") // avoid unnecessary method
    private inline fun handleDestroy(parentJob: Job) {
        parentJob.cancel()
        finish()
    }

    /**
     * Removes the observer and also marks the [DispatchQueue] as finished so that any remaining
     * runnables can be executed.
     */
    @MainThread
    fun finish() {
        //移除生命周期观察者
        lifecycle.removeObserver(observer)
        //标记已完成 并执行剩下的可执行的Runnable
        dispatchQueue.finish()
    }
}

```

whenStateAtLeast也是一个Lifecycle的扩展函数，核心逻辑是在LifecycleController中添加了LifecycleObserver来监听生命周期状态，通过状态来决定是暂停执行还是恢复执行，或者是取消执行。当执行完成之后，也就是finally那里，从执行LifecycleController的finish进行收尾工作：移除生命周期监听，开始执行余下的任务。

执行完成一次，就会移除生命周期观察者，相当于我们写到launchWhenResumed之类的函数里面的闭包只会被执行一次。执行完成之后，即使再经过onPause->onResume也不会再次执行。

### liveData

在我们平时使用LiveData的过程中，可能会涉及到这种场景：去请求网络拿结果，然后通过LiveData将数据转出去，在Activity里面收到通知，然后更新UI。非常常见的场景，这种情况下，我们可以通过官方的liveData构造器函数来简化上面的场景代码。

#### 使用

```kotlin
val netData: LiveData<String> = liveData {
    //观察的时候在生命周期内,则会马上执行
    val data = getNetData()
    emit(data)
}

//将耗时任务切到IO线程去执行
private suspend fun getNetData() = withContext(Dispatchers.IO) {
    //模拟网络耗时
    delay(5000)
    //模拟返回结果
    "{}"
}

```

在上面的例子中，getNetData()是一个suspend函数。使用LiveData构造器函数异步调用getNetData()，然后使用emit()提交结果。在Activity那边如果观察了这个netData，并且处于活动状态，那么就会收到结果。我们知道，suspend函数需要在协程作用域中调用，所以liveData的闭包里面也是有协程作用域的。

有个小细节，如果组件在观察此netData时刚好处于活动状态，那么liveData闭包里面的代码会立刻执行。

除了上面这种用法，还可以在liveData里面发出多个值。

```kotlin
val netData2: LiveData<String> = liveData {
    delay(3000)
    val source = MutableLiveData<String>().apply {
        value = "11111"
    }
    val disposableHandle = emitSource(source)

    delay(3000)
    disposableHandle.dispose()
    val source2 = MutableLiveData<String>().apply {
        value = "22222"
    }
    val disposableHandle2 = emitSource(source2)
}
```

需要注意的是，后一个调用emitSource的时候需要把前一个emitSource的返回值调用一下dispose函数，切断。

#### liveData的底层实现

老规矩，Ctrl+鼠标左键 点进去看源码

```kotlin
@UseExperimental(ExperimentalTypeInference::class)
fun <T> liveData(
    context: CoroutineContext = EmptyCoroutineContext,
    timeoutInMs: Long = DEFAULT_TIMEOUT,
    @BuilderInference block: suspend LiveDataScope<T>.() -> Unit
): LiveData<T> = CoroutineLiveData(context, timeoutInMs, block)

//咱们在liveData后面的闭包里面写的代码就是传给了这里的block，它是一个suspend函数，有LiveDataScope的上下文
```

首先，映入眼帘的是liveData函数居然是一个全局函数，这意味着你可以在任何地方使用它，而不局限于Activity或者ViewModel里面。

其次，liveData函数返回的是一个CoroutineLiveData对象？居然返回的是一个对象，没有在这里执行任何代码。那我的代码是在哪里执行的？

这就得看CoroutineLiveData类的代码了

```kotlin
internal class CoroutineLiveData<T>(
    context: CoroutineContext = EmptyCoroutineContext,
    timeoutInMs: Long = DEFAULT_TIMEOUT,
    block: Block<T>
) : MediatorLiveData<T>() {
    private var blockRunner: BlockRunner<T>?
    private var emittedSource: EmittedSource? = null

    init {
        // use an intermediate supervisor job so that if we cancel individual block runs due to losing
        // observers, it won't cancel the given context as we only cancel w/ the intention of possibly
        // relaunching using the same parent context.
        val supervisorJob = SupervisorJob(context[Job])

        // The scope for this LiveData where we launch every block Job.
        // We default to Main dispatcher but developer can override it.
        // The supervisor job is added last to isolate block runs.
        val scope = CoroutineScope(Dispatchers.Main.immediate + context + supervisorJob)
        blockRunner = BlockRunner(
            liveData = this,
            block = block,
            timeoutInMs = timeoutInMs,
            scope = scope
        ) {
            blockRunner = null
        }
    }

    internal suspend fun emitSource(source: LiveData<T>): DisposableHandle {
        clearSource()
        val newSource = addDisposableSource(source)
        emittedSource = newSource
        return newSource
    }

    internal suspend fun clearSource() {
        emittedSource?.disposeNow()
        emittedSource = null
    }

    override fun onActive() {
        super.onActive()
        blockRunner?.maybeRun()
    }

    override fun onInactive() {
        super.onInactive()
        blockRunner?.cancel()
    }
}
```

里面代码比较少，主要就是继承了MediatorLiveData，然后在onActive的时候执行BlockRunner的maybeRun函数。BlockRunner的maybeRun里面执行的实际上就是我们在liveData里面写的代码块，而onActive方法实际上是从LiveData那里继承过来的，当有一个处于活跃状态的观察者监听LiveData时会被调用。

这就解释得通了，我上面的案例中是在Activity的onCreate（处于活跃状态）里面观察了netData，所以liveData里面的代码会被立刻执行。

```kotlin

//typealias 类型别名
//在下面的BlockRunner中会使用到这个，这个东西用于承载我们在liveData后面闭包里面的代码
internal typealias Block<T> = suspend LiveDataScope<T>.() -> Unit

/**
 * Handles running a block at most once to completion.
 */
internal class BlockRunner<T>(
    private val liveData: CoroutineLiveData<T>,
    private val block: Block<T>,
    private val timeoutInMs: Long,
    private val scope: CoroutineScope,
    private val onDone: () -> Unit
) {
    @MainThread
    fun maybeRun() {
       ...
        //这里的scope是CoroutineScope(Dispatchers.Main.immediate + context + supervisorJob)
        runningJob = scope.launch {
            val liveDataScope = LiveDataScopeImpl(liveData, coroutineContext)
            //这里的block执行的是我们在liveData里面写的代码，在执行block时将liveDataScope实例传入，liveDataScope上下文有了
            block(liveDataScope)
            //完成
            onDone()
        }
    }
    ...
}

internal class LiveDataScopeImpl<T>(
    internal var target: CoroutineLiveData<T>,
    context: CoroutineContext
) : LiveDataScope<T> {

    ...
    // use `liveData` provided context + main dispatcher to communicate with the target
    // LiveData. This gives us main thread safety as well as cancellation cooperation
    private val coroutineContext = context + Dispatchers.Main.immediate
    
    //因为在执行liveData闭包的时候有LiveDataScopeImpl上下文，所以可以使用emit函数
    override suspend fun emit(value: T) = withContext(coroutineContext) {
        target.clearSource()
        //给target这个LiveData设置value，而liveData返回的就是这个target，在组件中观察此target，就会收到这里的value数据
        target.value = value
    }
}

```

在BlockRunner的maybeRun函数的里面启了个协程，这个scope是在CoroutineLiveData里面初始化的：`CoroutineScope(Dispatchers.Main.immediate + context + supervisorJob)`，接着就是在这个scope里面执行我们在liveData后面闭包里面写的代码，并且有LiveDataScopeImpl的上下文。有了LiveDataScopeImpl的上下文，那么我们就可以使用LiveDataScopeImpl里面的emit方法，而emit方法其实很简单，就是将一个数据交给一个LiveData对象，而这个LiveData就是`liveData{}`返回的那个。此时因为LiveData的数据发生了变化，如果有组件观察了该LiveData并且该组件处于活动状态，那么该组件就会收到数据发生变化的回调。

整个过程大致流程就是在`liveData{}`里面构建了一个协程，返回了一个LiveData，然后我们写的闭包里面的代码实际上是在一个协程里面执行的，我们调用emit方法时就是在更新这个LiveData里面的value。

### 参考资料

- https://developer.android.com/kotlin/coroutines
- https://developer.android.com/topic/libraries/architecture/coroutines?hl=zh-cn
