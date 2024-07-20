
## 1. 前言

在现代Android中，异步处理数据和响应式编程已经成为了不可或缺的一部分。app的代码越来越复杂，我们需要一种简单的、高效的方式来处理数据流和状态变化。Kotlin Flow是协程的一部分，提供了强大且灵活的API来应对这些挑战。

Kotlin Flow可以简化异步编程的复杂性，它可以与协程配合，并提供了丰富的操作符，使用它我们可以轻松实现数据流的转换、组合和过滤等。

接下来，我们将简单探讨Kotlin Flow的基础知识，包括概念、使用方式。


## 2. Kotlin Flow基本概念

在开始学习之前，我们需要先简单了解一下Kotlin Flow的基本概念。

### 2.1 什么是数据流？

数据流是一种数据处理方式，数据被异步地、连续地传输和处理。就像水从高处经水管流到低处，在流的这个过程中可以对水进行一些处理，比如过滤、加糖、加果汁、加热等等，下游拿到的水是已经经过处理的水，直接拿去消费（喝掉）就行。

### 2.2 Kotlin Flow是什么？

在Kotlin中，对数据流的建模合适的类型就是Flow。从概念上讲，可以异步计算的数据流称之为Flow。Flow是Kotlin协程的一部分，提供了对数据流的产生、变换、组合和消费的强大支持。通过Flow，开发者可以轻松地处理异步数据流，编写高效、响应式的app。

Flow可以连续地**发出多个值**，而不像传统的函数，调一次只返回一个值。还有点区别在于，Flow是使用**挂起函数**以**异步的方式**进行消费和生产。

Kotlin Flow并不是唯一的数据流，但它是协程的一部分，所以和协程配合得很好。比如大家熟悉的RxJava也是数据流的一种建模。

数据流包含3个重要概念：

- 生产者：生成数据，添加到数据流中
- 加工者：处于数据流中间，可以对数据流中的数据进行各种变换、加工等操作
- 消费者：处于数据流的末尾，对数据流中的数据进行最终的消费

### 2.3 有了LiveData和协程，为啥还需要Kotlin Flow？

LiveData是Android架构组件的一部分，它能保存数据、能感知生命周期、利用观察者模式在可用的生命周期范围内将最新的数据通知给观察者。它的设计初衷是为了简化开发，上手相对比较容易。然而，LiveData在处理复杂的数据流时存在一些限制，比如只能在主线程操作数据、操作符不够强大、而且不支持切换线程。正如前面所说，它是为了简化开发才被造出来的，搞的太复杂反而违背了设计初衷。

Kotlin的协程是Kotlin语言引入的一种并发编程工具，一套方便的API，它允许开发者以同步的方式写出异步的代码，简化异步逻辑的代码编写。协程通过提供结构化的并发模式，使得编写异步代码变得更加直观和易于理解。协程可以恢复和暂停，比如可以挂起直到某些条件满足才继续执行。这些特性使得协程可以非常方便地处理复杂的异步逻辑。

虽然说Kotlin协程已经提供了强大的异步编程能力，但Kotlin Flow提供了额外的抽象层次，专门用于处理异步数据流的，它是作为协程的补充，使得开发者可以更方便地构建复杂的异步数据处理逻辑。

另外，LiveData是想一次处理一个数据，而Flow是连续的数据流。LiveData的数据处理是在主线程，而Flow可以切到各种线程去处理，还有异常处理、各种操作符、与协程紧密配合等。看起来Flow只是对LiveData的补充，而不是替代，当需要处理复杂的数据流时，可能用Flow更加适合，弥补了一些LiveData的局限性。

在Flow之前呢，有RxJava可以非常方便地处理数据流，但是呢，RxJava上手难度比较大，而且不能与Kotlin协程进行很好的配合，Flow就相对更容易上手，而且与Kotlin配合紧密，方便操作，具体更详细的对比后面会提到。

来个LiveData和Flow的对比：

| LiveData | Flow |
| --- | --- |
| 支持Java和Kotlin，使用简单 | 仅支持在Kotlin中使用，Java中使用起来比较困难 |
| 不需要协程环境来执行 | 需要协程环境来执行 |
| 主要在主线程上运行 | 在协程上运行，不阻塞主线程 |
| 转换运算符在主线程上执行 | 运算符是挂起函数，可以很方便地在不同线程上执行 |
| 默认情况下，能感知生命周期 | 默认情况下，不能感知生命周期 |

如果是Java项目就需要注意了，**Livedata能和Java配合，Kotlin Flow想要和Java配合就难咯。**

### 2.4 相比RxJava，Kotlin Flow有什么优势?

可能很多人都用过RxJava，前几年，在纯Java的Android项目中，RxJava对于响应式编程非常友好。但是上手难度还是比较大的，要学很久才知道怎么用，以及怎么才能用好。而后面，大家开始用Kotlin，然后用Kotlin协程，又有了Kotlin Flow，上手难度比RxJava轻松了不少。那么，相比RxJava，Kotlin Flow有哪些优势呢？

1. 更自然的协程支持：Kotlin Flow是集成在Kotlin协程里面的，能更好地利用协程的特性，而且不需要额外引入其他的库。
2. 更简单的语法和易用性：Kotlin Flow的API设计更加简洁，避免了RxJava中复杂的操作符，它利用了扩展函数和lambda表达式，使代码更直观易读。
3. 内存安全与上下文一致性：Kotlin Flow中，数据流的上下文和生命周期是由协程管理的，这意味着可以更容易地处理内存泄漏和取消操作。相比之下，RxJava 需要手动处理订阅的管理和内存泄漏问题。
4. 冷流与热流：Kotlin Flow默认是冷流，即只有在有收集器时才开始执行。这与 RxJava 的 Observable 类似，但更符合大多数使用场景。RxJava 中则需要使用不同的类型（如 Observable 和 Flowable）来区分冷流和热流。
5. 背压处理：Kotlin Flow的冷流特性天然支持背压处理，因为生产者只有在有收集器请求数据时才会产生数据。RxJava 的 Flowable 虽然也支持背压，但需要额外配置和处理，增加了复杂性。
6. 更好的错误处理：Kotlin Flow依赖于 Kotlin 协程的异常处理机制，使得错误处理更加直观。RxJava 中则需要使用 onErrorReturn、onErrorResumeNext 等操作符来处理错误，语法相对复杂。
7. 轻量级和性能：Kotlin Flow相对 RxJava 更轻量，因为它不需要包含 RxJava 的所有操作符和特性。对于大多数常见的异步数据流处理场景，Kotlin Flow 提供了足够的功能，且性能通常更好。
8. 更好的与Kotlin标准库集成：Kotlin Flow是 Kotlin 标准库的一部分，因此与其他 Kotlin 标准库功能（如集合操作、标准函数）无缝集成。这使得开发者可以更自然地使用 Kotlin 语言特性，减少了学习曲线。

## 3. 基本使用

说了这么一大堆抽象的东西，下面我们来看看具体怎么使用。

### 3.1 Flow的创建和消费 

- 创建Flow：也就是将各种数据转为数据流Flow
- 消费数据流：也就是将数据流里面的数据进行一个个地消费掉，处理掉。

先举一个简单例子：

```kotlin
fun main(): Unit = runBlocking {
    // 创建3个Flow,生产数据
    val firstFlow = flowOf(1, 2)
    val secondFlow = flow {
        emit(3)
        emit(4)
    }
    val thirdFlow = listOf(5, 6).asFlow()

    // 挨个收集,消费者
    firstFlow.collect {
        println(it)
    }
    secondFlow.collect {
        println(it)
    }
    thirdFlow.collect {
        println(it)
    }
}
```
从这段代码中我们可以发现，Flow 的创建方式多样，如使用flowOf、flow、asFlow等。上面的例子中，每个 Flow 都通过 collect 终止操作来收集其发射的值，并对每个值执行相应的操作，而collect是需要在协程环境中执行的。

### 3.2 操作符

正如我前面所说的，除了生产者和消费者之外，中间还有一个可选的加工者，人如其名，是对数据进行转换加工等操作的，下面我们来简单看一下。

```kotlin
val firstFlow = flowOf(1, 2)

// 将数据做 +2 处理
firstFlow.map {
    it + 2
}.collect {
    println(it)
}
```

利用map操作符对数据进行了 +2 处理，这样最后输出就是3,4了。这里的map和我们平时使用的集合操作符map是一个含义，用法也是一样的，所以用到Flow上会看起来非常自然，没有陌生感。除了map以外，还有其他的操作符。

#### 3.2.1 转换操作符

- **map**：对每个元素应用一个函数，并返回一个新的 Flow。（和集合的map一样）
  ```kotlin
  flowOf(1, 2, 3).map { it * 2 }
  ```
- **filter**：过滤出符合条件的元素。（和集合的filter一样）
  ```kotlin
  flowOf(1, 2, 3).filter { it % 2 == 0 }
  ```
- **transform**：对每个元素应用一个自定义的转换，**可以发射多个值（这是它和map的区别）**。
  ```kotlin
  flowOf(1, 2, 3).transform { value ->
      emit(value * 2)
      emit(value * 3)
  }
  ```
- **take**：只取前 n 个元素。（和集合的take一样）
  ```kotlin
  flowOf(1, 2, 3, 4).take(2)
  ```

#### 3.2.2 组合操作符

- **zip**：合并两个 Flow 的元素，形成一个新的 Flow。(和集合的zip差不多)
  ```kotlin
  flowOf(1, 2).zip(flowOf("A", "B")) { a, b -> "$a -> $b" }
  ```
- **combine**：合并两个 Flow 的最新值。组合最新的值是什么意思呢？两个Flow中任意一个Flow有新的数据来了，那么就需要与另外一个Flow的最新的值进行组合。比如flow2的最新值是A，那么flow1一旦emit发射一个新值1，那么A就会和1结合，flow1再emit发射一个新值2，还是和flow2的最新值A进行结合，这样组合出来的个数就不一定是某个flow数据流的个数。
  ```kotlin
    val flow1 = flow {
        emit(1)
        delay(100)
        emit(2)
        delay(100)
        emit(3)
    }

    val flow2 = flow {
        emit("A")
        delay(500)
        emit("B")
        emit("C")
    }

    val combinedFlow = flow1.combine(flow2) { a, b -> "$a$b" }

    combinedFlow.collect { println(it) }
    
    // 输出
    // 1A
    // 2A
    // 3A
    // 3B
    // 3C
  ```
- flatMapConcat：串行地展开一个 Flow。
- flatMapMerge：并行地展开一个 Flow。
- flatMapLatest：只保留最新展开的 Flow。

#### 3.2.3 末端操作符

- **collect**：收集流的元素并执行给定的动作。
  ```kotlin
  flowOf(1, 2, 3).collect { println(it) }
  ```
- **toList**：将 Flow 转换为 List。
  ```kotlin
  val list = flowOf(1, 2, 3).toList()
  ```
- **first**：获取第一个元素并终止流的收集。
  ```kotlin
  val first = flowOf(1, 2, 3).first()
  ```

#### 3.2.4 上下文操作符

- **flowOn**：改变 Flow 的执行上下文。flowOn能改变上游的数据流的执行上下文，collect内部执行的上下文是collect调用处的上下文。
  ```kotlin
  flow {
      for (i in 1..3) {
          println("flow  ${currentCoroutineContext()}")
          emit(i)
      }
  }.flowOn(Dispatchers.Default)
      .map {
          println("map  ${currentCoroutineContext()}")
          it.toString()
      }
      .flowOn(Dispatchers.IO)
      .collect {
          withContext(Dispatchers.IO) {
              println("collect withContext ${currentCoroutineContext()}")
          }
          println("collect ${currentCoroutineContext()}")
          println(it)
      }
  
  /*
  输出：
  flow  [ProducerCoroutine{Active}@3b6f6746, Dispatchers.Default]
  flow  [ProducerCoroutine{Active}@3b6f6746, Dispatchers.Default]
  flow  [ProducerCoroutine{Active}@3b6f6746, Dispatchers.Default]
  map  [ScopeCoroutine{Active}@4b60f5ce, Dispatchers.IO]
  map  [ScopeCoroutine{Active}@4b60f5ce, Dispatchers.IO]
  map  [ScopeCoroutine{Active}@4b60f5ce, Dispatchers.IO]
  collect withContext [DispatchedCoroutine{Active}@8945c64, Dispatchers.IO]
  collect [ScopeCoroutine{Active}@6fdb1f78, BlockingEventLoop@51016012]
  1
  collect withContext [DispatchedCoroutine{Active}@437a60dc, Dispatchers.IO]
  collect [ScopeCoroutine{Active}@6fdb1f78, BlockingEventLoop@51016012]
  2
  collect withContext [DispatchedCoroutine{Active}@7b238e10, Dispatchers.IO]
  collect [ScopeCoroutine{Active}@6fdb1f78, BlockingEventLoop@51016012]
  3
  */
  ```
- **buffer**：在不同上下文之间缓冲元素。
  - 在说buffer之前先聊一下**背压**。假设，媒婆将男生A介绍为一位女生，她接受了这个介绍。女生与这个男生约会，需要一些时间相互了解，然后决定是否合适。现在，如果她正在好男生A约会时媒婆又给她介绍了另一位男生B，那么媒婆基本上是用超出她消化能力的信息轰炸她了，根本忙不过来。从技术上说，媒婆是上游生产者，女生是下游消费者。当下游消费者无法以生产者生产或释放信息的速度进行消化时，就会发生背压。就像这位女生会因为媒婆介绍的过多相亲对象而感到不知所措，因此，这位女生感到了背压。让我们从编码的角度来想象这一点，并假设这位女生需要一天才能与每位男生完成一次约会。现在，在背压的情况下，假设媒婆将介绍5位男生，由于女生每位男生花费1天，因此需要5天才能浏览完所有的相亲对象。这将导致内存使用效率低下和性能问题。因此，我们将根据应用目的采用不同的策略来解决这个问题。
  - 而解决这个问题的其中一种方式就是使用buffer，也就是缓冲区。回到上面的故事中，想象一下缓冲区就像一个等待区。当媒婆一次介绍了5位男生，而我们的女生仍在和第一个男生约会时，所有5位男生都在等待区（缓冲区）中等待。每当这位女生完成一次约会时，等待区就会为她提供下一位男生。
  - 它本质上是通过弄两个协程上下文来完成的，buffer之前在一个协程，buffer之后在另一个协程中收集，从而缓解背压
  ```kotlin
  // 先看一下有缓冲区的情况
  flowOf("A","B","C","D","E")
    .onEach { println("Woman matchmaker emits: $it") }
    .buffer()
    .collect {
        println("Girl appointment with: $it")
        delay(1000)
    }

  //输出
  Woman matchmaker emits: A
  Woman matchmaker emits: B
  Woman matchmaker emits: C
  Woman matchmaker emits: D
  Woman matchmaker emits: E
  Girl appointment with: A
  Girl appointment with: B
  Girl appointment with: C
  Girl appointment with: D
  Girl appointment with: E


  // 无缓冲区的情况
  flowOf("A","B","C","D","E")
    .onEach { println("Woman matchmaker emits: $it") }
    .collect {
        println("Girl appointment with: $it")
        delay(1000)
    }

  // 输出
  Woman matchmaker emits: A
  Girl appointment with: A
  Woman matchmaker emits: B
  Girl appointment with: B
  Woman matchmaker emits: C
  Girl appointment with: C
  Woman matchmaker emits: D
  Girl appointment with: D
  Woman matchmaker emits: E
  Girl appointment with: E
  ```
- **conflate**：只处理最新的值，跳过中间值。比如消费速度是500ms一个，在这500ms中间发射了10个，那么只会处理一个最新的，而跳过其他的。
  ```kotlin
  flowOf(1, 2, 3).conflate()
  ```

#### 3.2.5 错误处理操作符

- **catch**：捕获和处理异常。
  ```kotlin
  flow {
      emit(1)
      throw RuntimeException("RuntimeException")
  }.catch { e ->
      emit(-1)
  }.collect {
      println(it)
  }
  ```
- **retry**：重试流的收集，最多重试指定次数。
  ```kotlin
  flow {
      emit(1)
      throw RuntimeException("RuntimeException")
  }.retry(3).collect {
      println(it)
  }

  // 输出
  1
  1
  1
  1
  Exception in thread "main" java.lang.RuntimeException: RuntimeException
  ```

### 3.3 Flow的类型

主要分为冷流和热流两种：

冷流（如Flow）：
- 数据生产者与消费者绑定：冷流是懒惰的，数据只有在有消费者（collect）时才开始生产。这意味着每个新的消费者会触发一个新的数据流。
- 多个消费者独立消费：每个消费者都独立于其他消费者，每个消费者都会从头开始接收数据。这相当于每个消费者拥有自己独立的数据流。
- 适合单播场景：冷流更适合于单播场景，即每个消费者独立消费数据，不受其他消费者的影响。

热流（如StateFlow、SharedFlow）：
- 数据生产者独立于消费者：热流会在创建后立即开始生产数据，而不管是否有消费者。这意味着数据的生产和消费是独立的。
- 多个消费者共享数据流：多个消费者共享同一个数据流。新加入的消费者只能接收到数据流的最新数据，而不是从头开始。
- 适合多播场景：热流更适合于多播场景，即同一个数据流可以被多个消费者同时消费。

### 3.4 StateFlow、SharedFlow、MutableSharedFlow、MutableStateFlow这些东西是什么？有什么差别？

StateFlow 和 SharedFlow 是热流，它们提供了不同的功能和使用场景。生产数据不依赖消费者消费，热流与消费者是一对多的关系，当有多个消费者时，它们之间的数据都是同一份。MutableSharedFlow、MutableStateFlow是它们的可读可写的版本。

StateFlow 与 LiveData 有点类似，这里可以对照着学习，比如相同的地方有：
- 提供「可读可写」和「仅可读」两个版本（StateFlow，MutableStateFlow）
- 它的值是唯一的
- 它允许被多个观察者共用 （因此是共享的数据流）
- 它永远只会把最新的值重现给订阅者，这与活跃观察者的数量是无关的
- 支持 DataBinding

不同的地方：
- 必须配置初始值
- value 空安全
- 防抖(默认是防抖的，在更新数据时，会判断当前值与新值是否相同，如果相同则不更新数据)

SharedFlow和StateFlow一样，SharedFlow 也有两个版本：SharedFlow 与 MutableSharedFlow。那么它与StateFlow哪里不一样呢？
- MutableSharedFlow 没有起始值
- SharedFlow 可以保留历史数据（保留多少个可以自定义），新的订阅者可以获取之前发射过的一些数据
- StateFlow 只保留最新值，即新的订阅者只会获得最新的和之后的数据


它们的使用场景大概可以这么区分：一个是状态（StateFlow），一个是事件（SharedFlow）。

- StateFlow：适用于状态管理场景，例如在ViewModel中表示UI状态。因为它始终持有最新的状态，能确保观察者总能获得最新的状态。将ui的状态公开给View的时候，官方推荐使用StateFlow，因为它是一个安全高效的观察者，旨在保存ui状态。
- SharedFlow：更加灵活和通用，适用于事件处理、事件总线、消息队列等场景。尤其适合需要重播特定数量的历史事件或者处理事件丢弃政策的场景。


### 3.5 stateIn、shareIn 是什么东西？

它们两个是Kotlin Flow里面的扩展函数，用于将冷流转换为热流。

**stateIn 将一个冷流转换为 StateFlow。它会保留最新的值，并且任何新的订阅者都会立即收到当前状态**。怎么使用？

```kotlin
// ViewModel
val stateInFlow = flow {
    emit(1)
    delay(300L)
    emit(2)
    delay(300L)
    emit(3)
}.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000L), null)

// Activity
lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        flowViewModel.stateInFlow.collect {
            log("stateInFlow data $it")
        }
    }
}

// 输出
stateInFlow data null
stateInFlow data 1
stateInFlow data 2
stateInFlow data 3
```

首先我们注意到stateIn需要传入3个参数，意思如下：

```kotlin
 @param scope the coroutine scope in which sharing is started.
 @param started the strategy that controls when sharing is started and stopped.
 @param initialValue the initial value of the state flow.
   This value is also used when the state flow is reset using the [SharingStarted.WhileSubscribed] strategy
   with the `replayExpirationMillis` parameter.
```

- 首先scope，表示当前flow要作用于的协程作用域，当这个协程取消时，这个flow也会跟着取消，停止发送数据。
- started：这是一个SharingStarted类型的参数，用于定义StateFlow的启动策略。它一共有3种类型：
  - SharingStarted.Lazily ： 第一个订阅者出现的时候，开始运转，当scope取消的时候才停止。
  - SharingStarted.Eagerly ： 立即启动，当scope取消的时候才停止。
  - SharingStarted.WhileSubscribed(stopTimeoutMillis: Long，replayExpirationMillis: Long) ： 当至少有一个订阅者的时候启动，最后一个订阅者停止订阅之后还能继续保持stopTimeoutMillis时间的活跃，之后才停止。replayExpirationMillis直接翻译过来是重播过期时间，默认是Long.MAX_VALUE，当取消协程之后，这个缓存的值需要保留多久，如果是0，表示立马就过期，并把shareIn运算符的缓存值设置为initialValue初始值。
- initialValue ： 非常好理解，就是初始值。

官方建议：对于那些一次性的操作来说，你可以使用Lazily、Eagerly，但是对于需要观察其他的Flow的情况来说，更推荐用WhileSubscribed。WhileSubscribed在最后一个订阅者停止订阅之后还能继续保持stopTimeoutMillis时间的活跃，之后才停止，这有个好处，比如用户将app切换到后台，此时，上游的流就没必要继续产生并发射数据了，app都没在前台了，发射数据有点浪费资源了。但是，当app只是从竖屏切换到横屏状态时(lifecycle.repeatOnLifecycle那里我们传入的是STARTED，所以会被取消，重新STARTED时会重新collect)，这种就没必要取消上游的生产者生成数据了，所以有个stopTimeoutMillis的时间值在那里。官方表示，合适的时间是5000毫秒。

**shareIn 将一个冷流转换为 SharedFlow。它可以配置缓冲区大小和重播值的数量，并且可以在多个订阅者之间共享数据**。共享同一个流的数据，而不是重新执行流的计算。

shareIn和stateIn参数差不多，但是没有初始值，多了一个replay参数，这个参数什么意思呢？假设：之前有订阅者，并且已经有3个流数据了，replay=1，这时再来一个订阅者，那么就会发射最新的那个值给这个新的订阅者，而不会发射给这个新的订阅者早先的第一个和第二个数据。

举个例子：

```kotlin
val shareInFlow = flow {
        emit(1)
        delay(300L)
        emit(2)
        delay(300L)
        emit(3)
    }.shareIn(viewModelScope, SharingStarted.WhileSubscribed(5000L), 1)

fun testShareIn() {
    viewModelScope.launch {
        launch {
            shareInFlow.collect {
                log("订阅者1 shareInFlow data $it")
            }
        }
        delay(1000L)
        launch {
            shareInFlow.collect {
                log("订阅者2 shareInFlow data $it")
            }
        }
    }
}

// 输出：
订阅者1 shareInFlow data 1
订阅者1 shareInFlow data 2
订阅者1 shareInFlow data 3
订阅者2 shareInFlow data 3
```

### 3.6 在回调中拿到的数据怎么转换为Flow？

类似Kotlin协程中的suspendCancellableCoroutine，将callback转换为协程的风格。那么回调callback拿到的数据怎么转换为Flow发射出去呢？

答案是使用callbackFlow。callbackFlow 是一种特殊的 Flow 构建器，它允许你从回调中发射数据。举个栗子：

```kotlin
fun locationFlow(locationManager: LocationManager): Flow<Location> = callbackFlow {
  val listener = object : LocationListener {
    override fun onLocationChanged(location: Location) {
      trySend(location) // Emit the location update to the flow
    }
  }
  locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 0L, 0f, listener)
  awaitClose {
    locationManager.removeUpdates(listener) // Unregister listener on cancellation
  }
}

fun main() {
  runBlocking {
    locationFlow(locationManager)
      .collect { location ->
        println("Received location: ${location.latitude}, ${location.longitude}")
      }
  }
}
```

### 3.7 让Flow具备生命周期感知的能力

默认情况下，Flow是不具备生命周期感知能力的。但我们可以使用下面的方法让其具备生命周期感知的能力。

1. lifecycle-livedata-ktx库中有一个api：“V Flow<T>.asLiveData(): LiveData”，可以将Flow转为LiveData，我都转LiveData了，那妥妥的与生命周期挂钩，但总感觉有点儿作弊的嫌疑。
2. lifecycle-runtime-ktx库中也有好用的api
  - `V Lifecycle.repeatOnLifecycle(state)`    官方推荐：使用repeatOnLifecycle在界面层收集Flow。调用repeatOnLifecycle的协程将不会继续执行后面的代码了，当它恢复的时候，已经是ui DESTROY的时候了，所以不要在repeatOnLifecycle的后面继续repeatOnLifecycle。官方推荐在repeatOnLifecycle里面launch多次，开启多个协程，然后在里面collect，相互不影响。
  - `Flow<T>.flowWithLifecycle(lifecycle, state)`  如果只有一个Flow数据需要收集，那么官方推荐使用flowWithLifecycle。

```kotlin
// Update the uiState
lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        viewModel.uiState
            .onEach { uiState = it }
            .collect()
    }
}
```

那么，你可能会问了？我都在lifecycleScope里面进行collect了，为啥还需要考虑生命周期的问题，不是自带感知吗？   答案是：这种方式会在ui非DESTROY时一直可以collect，即使app在后台，即onStop的状态时，也会进行收集，然后对ui进行更新，除非你确实有这个需求，那么不然就有点浪费资源了。

那么，在lifecycleScope.launchWhenStarted里面收集Flow数据应该没问题了吧？还是有一点问题，在ui层达到onStop状态之后，但并未destroy时，比如按home键，app此时在后台活着，这个时候Flow的管道还继续存在，且Flow的生产方还可以继续生产并emit。

### 3.8 Flow如何处理配置变更问题？

当ViewModel向外部暴露一个冷流时，这个冷流是向网络请求数据，那么每次这个冷流被collect时都会进行一次网络请求。比如配置变更时，再次collect，那么就会再请求一次网络，这明显不太合适。

```kotlin
val result: Flow<Result<UiState>> = flow {
    emit(repository.fetchItem())
}
```

这个时候就需要一个可以临时储存数据的一个东西，假设我们叫它储物箱，它的作用是将上游生产的数据暂时存起来，不管下游collect多少次，都是从这个储物箱中获取最新的那个数据。其实，上面我们已经讲过这么一个东西了，它就是StateFlow。普通的Flow可以通过stateIn转换为StateFlow。官方建议在ViewModel中向外暴露StateFlow，或者用asLiveData转为LiveData。

## 4. 实际应用

看下实际项目中，怎么使用Flow。

### 4.1 请求网络

请求网络在App开发中非常常见，我这里简单写了一个demo，用Retrofit获取数据：

```kotlin
interface WanAndroidService {

    @GET("wxarticle/chapters/json")
    suspend fun listRepos(): WxList?

}
class KotlinFlowViewModel : ViewModel() {

    val retrofit = Retrofit.Builder()
        .baseUrl(WANANDROID_BASE_URL)
        .addConverterFactory(GsonConverterFactory.create())
        .build()
    val api = retrofit.create(WanAndroidService::class.java)

    // 合适的方式
    val wxData = flow {
        val response = api.listRepos()
        emit(response)
    }.catch {
        log("出错了 $it")
        emit(null)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000L), null)

    // 不太合适的方式
    fun getWxData(): Flow<WxList?> = flow {
        val response = api.listRepos()
        emit(response)
    }.catch {
        log("出错了 $it")
        emit(null)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000L), null)

}

// Activity
lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        flowViewModel.wxData.collect { newData ->
            Log.d("xfhy666", "getWxData ${newData?.data?.getOrNull(0)?.name}")
            tv_data.text = newData?.data?.getOrNull(0)?.name ?: "没获取到数据"
        }
    }
}
```

我在获取网络数据之后使用了stateIn，将上游的Flow转换为StateFlow，将数据暂存到StateFlow中，然后在Activity中进行collect收集数据，进行ui展示。使用方式和LiveData类似。请注意，我这里使用了两种方式来进行网络请求，一种是用方法，一种是定义变量的形式。我更推荐使用变量的形式，因为使用上面那种方法的形式时，每次调用该方法都会重新创建一个新的Flow，重新进行网络请求，有点浪费资源。而定义成属性变量的那种形式，不管collect多少次，都只会请求一次网络。

### 4.2 与Room结合使用

就像协程能结合Room一起使用一样，Flow也能和Room一起配合使用。首先来看一下dao的定义：

```kotlin
@Dao
interface UserDao {

    @Insert
    suspend fun insertUserBySuspend(user: User)

    @Query("SELECT * FROM user")
    fun getAllBySuspendFlow(): Flow<List<User>>

}
```

注意看getAllBySuspendFlow的返回值，是一个Flow<List<User>>。然后再来看使用方式：

```kotlin
// ViewModel
/**
* 插入数据到room
*/
fun insertUserData() {
    val user = User(name = "${random.nextInt()} 罗辑", age = random.nextInt())
    viewModelScope.launch {
        userDao.insertUserBySuspend(user)
    }
}

/**
* collect之后,实时接收数据库中所有的user
*/
val userDataList: Flow<List<User>?> = userDao
    .getAllBySuspendFlow()
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000L), null)

// Activity
lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        launch {
            flowViewModel.userDataList.collect { dataList ->
                log("数据库中的数据总个数为 : ${dataList?.size}")
            }
        }
    }
}
```

一旦我调用insertUserData方法插入数据到数据库中的时候，我的flowViewModel.userDataList.collect就会收到数据，相当于可以一直观察着数据的变化。是不是让你想起了点什么？没错，之前LiveData也是类似的：

```kotlin
@Dao
interface UserDao {
    @Query("SELECT * FROM user WHERE id = :userId")
    fun getUserById(userId: Int): LiveData<User>

    @Query("SELECT * FROM user")
    fun getAllUsers(): LiveData<List<User>>
}
```

### 4.3 之前用LiveData实现的案例，现在用Flow怎么实现

如果你在之前的项目在使用LiveData，那么你刚开始尝试使用Flow时，可能会遇到之前用LiveData解决问题的场景，现在用Flow怎么实现的问题。下面，我将举几个例子，简单说明一下怎么从LiveData转换到Flow。

#### 4.3.1 LiveData基本使用

在ViewModel中请求数据，然后用LiveData暴露出去，在UI层观察。下面的示例中，我会分为两部分，上半部分是LiveData的用法，下半部分是Flow的用法。

```kotlin
// ViewModel
private val _livedata1 = MutableLiveData<String?>()
val livedata1 = _livedata1
fun fetchData1() {
    viewModelScope.launch(Dispatchers.IO) {
        val result = api.listRepos()
        _livedata1.postValue(result?.toString())
    }
}

val flow1 = flow<String?> {
    val result = api.listRepos()
    emit(result.toString())
}.flowOn(Dispatchers.IO)
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000L), null)
```

那么在Activity中的收集代码如下：

```kotlin
flowViewModel.fetchData1()
flowViewModel.livedata1.observe(this) {
    log("livedata1 数据 $it")
}

lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        flowViewModel.flow1.collect {
            log("flow1 数据 $it")
        }
    }
}
```

如上，一个简单的使用场景，使用起来差别不大。

#### 4.3.2 switchMap

在ViewModel中一个LiveData的数据依赖于另一个LiveData，并且需要用SwitchMap转换一下数据。下面的示例中，我会分为两部分，上半部分是LiveData的用法，下半部分是Flow的用法。

```kotlin
private val _liveDataA = MutableLiveData<String>()
val liveDataB: LiveData<String> = _liveDataA.switchMap { value ->
    MutableLiveData("hh $value")
}
fun fetchData2() {
    _liveDataA.value = "param1"
}

private val flowA = MutableStateFlow("")
val flowB: Flow<String> = flowA.flatMapLatest { value ->
    flow {
        emit("hh $value")
    }
}.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000L), "")
fun fetchFlowA() {
    flowA.value = "param1"
}
```

那么在Activity中的收集代码如下：

```kotlin
flowViewModel.fetchData2()
flowViewModel.liveDataB.observe(this) {
    log("liveDataB 数据 $it")
}

flowViewModel.fetchFlowA()
lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        flowViewModel.flowB.collect {
            log("flowB 数据 $it")
        }
    }
}
```

如上，在LiveData中使用SwitchMap，在Flow中可以使用flatMapLatest转一下。

#### 4.3.3 MediatorLiveData

MediatorLiveData的数据，来源于观察另一个或多个LiveData others的数据，在观察到others数据变化时，根据业务需要得出新的值。这样可以用于合并多个LiveData的值、选择某个LiveData最新的值、获取多个LiveData的最新的值。

```kotlin
// ViewModel
private val _liveData31 = MutableLiveData<String>()
private val _liveData32 = MutableLiveData<Int>()
val mediatorLiveData: LiveData<String> = MediatorLiveData<String>().apply {
    addSource(_liveData31) { value ->
        value?.let { postValue("liveData31: $it  LiveData32: ${_liveData32.value}") }
    }
    addSource(_liveData32) { value ->
        value?.let { postValue("LiveData32: $it   liveData31: ${_liveData31.value}") }
    }
}

fun fetchData3() {
    _liveData31.value = "哈哈"
    _liveData32.value = 6
}


private val flow31 = MutableStateFlow("")
private val flow32 = MutableStateFlow(0)
val combinedFlow = flow31.combine(flow32) { valueA, valueB ->
    "flow31: $valueA, flow32: $valueB"
}.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000L), "")

fun fetchData3ByFlow() {
    flow31.value = "哈哈"
    flow32.value = 6
}
```

那么在Activity中的收集代码如下：

```kotlin
flowViewModel.fetchData3()
flowViewModel.mediatorLiveData.observe(this) {
    log("mediatorLiveData 数据 $it")
}

flowViewModel.fetchData3ByFlow()
lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        flowViewModel.combinedFlow.collect {
            log("combinedFlow 数据 $it")
        }
    }
}
```

要观察多个LiveData的值可以使用MediatorLiveData，而在Flow中，可以通过使用**combine**关键词来观察并合并多个 Flow 的最新值。

#### 4.3.4 Transformations.map

Transformations.map经常用于观察另一个LiveData的值，观察到变化时，对其map操作进行一些转换，然后生成一个新的LiveData。

```kotlin
// ViewModel
private val liveData4: LiveData<Int> = MutableLiveData()
val mappedLiveData: LiveData<String> = Transformations.map(liveData4) { value ->
    "Mapped livadata value: $value"
}

private val flow4: Flow<Int> = flowOf(1, 2, 3)
val mappedFlow: Flow<String> = flow4.map { value ->
    "Mapped flow value: $value"
}.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000L), "")
```

那么在Activity中的收集代码如下：

```kotlin
flowViewModel.mappedLiveData.observe(this) {
    log("mappedLiveData data : $it")
}
lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        flowViewModel.mappedFlow.collect {
            log("flow4 data $it")
        }
    }
}
```

这种情况的话，LiveData和Flow几乎是一模一样的操作，都是通过map操作符来完成观察另外一个数据，并转换成新的数据。

#### 4.3.5 Transformations.switchMap

Transformations.switchMap主要是将一个LiveData的值，转换为另一个LiveData。来看看Flow中是怎么实现：

```kotlin
// ViewModel
private val _liveData5 = MutableLiveData<String>()
val switchMappedLiveData: LiveData<String> = Transformations.switchMap(_liveData5) { value ->
    liveData {
        val result = "livedata data $value"
        emit(result)
    }
}

fun fetchData5() {
    _liveData5.value = "param1"
}

private val flow5 = MutableStateFlow("")
val switchMappedFlow: Flow<String> = flow5.flatMapLatest { value ->
    flow {
        val result = "flow data $value"
        emit(result)
    }.flowOn(Dispatchers.IO)
}

fun fetchFlow5() {
    flow5.value = "param1"
}
```

那么在Activity中的收集代码如下：

```kotlin
flowViewModel.switchMappedLiveData.observe(this) {
    log("switchMappedLiveData data : $it")
}
flowViewModel.fetchData5()

lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        flowViewModel.switchMappedFlow.collect {
            log("switchMappedFlow data : $it")
        }
    }
}
flowViewModel.fetchFlow5()
```

在Flow中可以使用flatMapLatest来代替Transformations中的switchMap。


## 5. 其他问题

### 5.1 一些小细节

*   null也可以emit,然后收集到

```kotlin
flow<Any?> {
        emit(1)
        emit(null)
        emit("3")
    }.collect {
        println(it)
    }

//输出：
1
null
3
```

*   相同的对象,也可以emit多次,然后collect收集到
```kotlin
    data class Person(val name: String)

    val person = Person("一")

    flowOf(person, person, person, person).collect {
      println(it)
    }

    // 输出：
    Person(name=一)
    Person(name=一)
    Person(name=一)
    Person(name=一)
```

*   zip时,如果2个flow的数据个数不对等,那么谁的个数更少,就仅zip多少个

```kotlin
val flow1 = flowOf(1, 2, 3, 4, 5, 6)
val flow2 = flowOf("a", "b", "c")
flow1.zip(flow2) { value1, value2 ->
"新的数据: `$value1 $`value2"
}.collect {
println(it)
}
// 输出:
//新的数据: 1 a
//新的数据: 2 b
//新的数据: 3 c
```

### 5.2 同一个值StateFlow无法连续emit？怎么解决这个问题？

如果你尝试连续发射相同的值，StateFlow 会忽略后续的发射尝试，因为状态没有变化。

1. 要解决这个问题，最简单的办法就是将数据包一层，比如

```kotlin
data class State(val data: Int, val timestamp: Long = System.currentTimeMillis())

val stateFlow = MutableStateFlow(State(1))

suspend fun updateData(value: Int) {
    stateFlow.emit(State(value))
}

async {
    updateData(1)
    delay(100)
    updateData(1)
}

stateFlow.collect {
    println(it)
}

// 输出
State(data=1, timestamp=1719280640886)
State(data=1, timestamp=1719280640944)
State(data=1, timestamp=1719280641052)
```

2. 方法2：使用SharedFlow

```kotlin
val sharedFlow = MutableSharedFlow<Int>()

async {
    sharedFlow.emit(1)
    sharedFlow.emit(1)
    sharedFlow.emit(1)
    sharedFlow.emit(1)
    sharedFlow.emit(1)
}

sharedFlow.collect {
    println(it)
}

// 输出
1
1
1
1
1
```

### 5.3 多次连续的collect导致的问题？

大家先看一下下面的代码有没有问题：

```kotlin
fun getWxData(): Flow<WxList?> = flow {
    val response = api.listRepos()
    emit(response)
}
fun getListData(): Flow<Int> = flowOf(1, 2, 3)

lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        flowViewModel.getWxData().collect { newData ->
            Log.d("xfhy666", "getWxData ${newData?.data?.getOrNull(0)?.name}")
            tv_data.text = newData?.data?.getOrNull(0)?.name ?: "没获取到数据"
        }
        flowViewModel.getListData().collect { data ->
            Log.d("xfhy666", "getListData 获取到的数据 $data")
        }
    }
}
```

getWxData和getListData都是返回的Flow，那么我在repeatOnLifecycle中连续两次collect，这样有问题吗？先看一下结果：

```log
2024-07-02 07:24:40.520 8652-8652/com.xfhy.allinone D/xfhy666: getWxData 鸿洋
2024-07-02 07:24:40.524 8652-8652/com.xfhy.allinone D/xfhy666: getListData 获取到的数据 1
2024-07-02 07:24:40.524 8652-8652/com.xfhy.allinone D/xfhy666: getListData 获取到的数据 2
2024-07-02 07:24:40.524 8652-8652/com.xfhy.allinone D/xfhy666: getListData 获取到的数据 3
```

看起来是没问题的，我现在做一下改变，将getWxData的Flow转换为热流StateFlow

```kotlin
fun getWxData(): Flow<WxList?> = flow {
    val response = api.listRepos()
    emit(response)
}.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000L), null)
```

其他地方都没动，现在我们看下结果：

```log
2024-07-02 07:30:37.678 9472-9472/com.xfhy.allinone D/xfhy666: getWxData null
2024-07-02 07:30:43.120 9472-9472/com.xfhy.allinone D/xfhy666: getWxData 鸿洋
```

可以看到，getListData的Flow数据没有被消费，第一个collect一直阻塞在那里了，后面的就执行不到了。我们需要简单改一下：

```kotlin
lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        launch {
            flowViewModel.getWxData().collect { newData ->
                Log.d("xfhy666", "getWxData ${newData?.data?.getOrNull(0)?.name}")
                tv_data.text = newData?.data?.getOrNull(0)?.name ?: "没获取到数据"
            }
        }
        launch {
            flowViewModel.getListData().collect { data ->
                Log.d("xfhy666", "getListData 获取到的数据 $data")
            }
        }
    }
}
```

好了，这样就能collect到数据了，并且互不影响，现在的输出数据为：

```log
2024-07-02 07:33:51.358 9676-9676/com.xfhy.allinone D/xfhy666: getWxData null
2024-07-02 07:33:51.361 9676-9676/com.xfhy.allinone D/xfhy666: getListData 获取到的数据 1
2024-07-02 07:33:51.361 9676-9676/com.xfhy.allinone D/xfhy666: getListData 获取到的数据 2
2024-07-02 07:33:51.361 9676-9676/com.xfhy.allinone D/xfhy666: getListData 获取到的数据 3
2024-07-02 07:33:52.721 9676-9676/com.xfhy.allinone D/xfhy666: getWxData 鸿洋
```

### 5.4 Flow中没有进行异常处理时，抛出的异常最终会去到哪里？

我先写一段会抛出异常的代码：

```kotlin
fun getThrowFlow(): Flow<Int> = flow {
    emit(1)
    emit(2)
    throw RuntimeException("异常")
}

lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        launch {
            flowViewModel.getThrowFlow().collect {
                Log.d("xfhy666", "getThrowFlow 获取到的数据 $it")
            }
        }
    }
}

```

然后在Activity中collect，看下结果：

```log
2024-07-02 07:39:19.803 10024-10024/com.xfhy.allinone D/xfhy666: getThrowFlow 获取到的数据 1
2024-07-02 07:39:19.803 10024-10024/com.xfhy.allinone D/xfhy666: getThrowFlow 获取到的数据 2
    
    --------- beginning of crash
2024-07-02 07:39:19.836 10024-10024/com.xfhy.allinone E/AndroidRuntime: FATAL EXCEPTION: main
    Process: com.xfhy.allinone, PID: 10024
    java.lang.RuntimeException: 异常
        at com.xfhy.allinone.kotlin.coroutine.flow.KotlinFlowViewModel$getThrowFlow$1.invokeSuspend(KotlinFlowViewModel.kt:47)   // 这一行的ViewModel中我抛出异常的地方
        at com.xfhy.allinone.kotlin.coroutine.flow.KotlinFlowViewModel$getThrowFlow$1.invoke(Unknown Source:8)
        at com.xfhy.allinone.kotlin.coroutine.flow.KotlinFlowViewModel$getThrowFlow$1.invoke(Unknown Source:4)
        at kotlinx.coroutines.flow.SafeFlow.collectSafely(Builders.kt:61)
        at kotlinx.coroutines.flow.AbstractFlow.collect(Flow.kt:230)    // 到了collect这里
        at com.xfhy.allinone.kotlin.coroutine.flow.KotlinFlowActivity$initView$1$1$1$1.invokeSuspend(KotlinFlowActivity.kt:55)
        at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
        at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:106)
        at kotlinx.coroutines.EventLoop.processUnconfinedEvent(EventLoop.common.kt:69)
        at kotlinx.coroutines.internal.DispatchedContinuationKt.resumeCancellableWith(DispatchedContinuation.kt:376)
        at kotlinx.coroutines.intrinsics.CancellableKt.startCoroutineCancellable(Cancellable.kt:30)
        at kotlinx.coroutines.intrinsics.CancellableKt.startCoroutineCancellable$default(Cancellable.kt:25)
        at kotlinx.coroutines.CoroutineStart.invoke(CoroutineStart.kt:110)
        at kotlinx.coroutines.AbstractCoroutine.start(AbstractCoroutine.kt:126)
        at kotlinx.coroutines.BuildersKt__Builders_commonKt.launch(Builders.common.kt:56)
        at kotlinx.coroutines.BuildersKt.launch(Unknown Source:1)
        at kotlinx.coroutines.BuildersKt__Builders_commonKt.launch$default(Builders.common.kt:47)
        at kotlinx.coroutines.BuildersKt.launch$default(Unknown Source:1)
        at com.xfhy.allinone.kotlin.coroutine.flow.KotlinFlowActivity.initView$lambda-0(KotlinFlowActivity.kt:39)    // lifecycleScope.launch
        at com.xfhy.allinone.kotlin.coroutine.flow.KotlinFlowActivity.$r8$lambda$l0YhxSN3b9XO48WjJgeEDhKBz1g(Unknown Source:0)
        at com.xfhy.allinone.kotlin.coroutine.flow.KotlinFlowActivity$$ExternalSyntheticLambda0.onClick(Unknown Source:2)
        at android.view.View.performClick(View.java:7448)
        at android.view.View.performClickInternal(View.java:7425)
        at android.view.View.access$3600(View.java:810)
        at android.view.View$PerformClick.run(View.java:28305)
        at android.os.Handler.handleCallback(Handler.java:938)
        at android.os.Handler.dispatchMessage(Handler.java:99)    //  dispatchMessage
        at android.os.Looper.loop(Looper.java:223)
        at android.app.ActivityThread.main(ActivityThread.java:7656)
        at java.lang.reflect.Method.invoke(Native Method)
        at com.android.internal.os.RuntimeInit$MethodAndArgsCaller.run(RuntimeInit.java:592)
        at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:947)
    	Suppressed: kotlinx.coroutines.DiagnosticCoroutineContextException: [StandaloneCoroutine{Cancelling}@b417ad2, Dispatchers.Main.immediate]

```

一直将异常抛出到了ZygoteInit.main方法内，这将导致app崩溃退出。

### 5.5 使用 flow 构建器，生产者无法 emit 来自不同 CoroutineContext 的值

使用 flow 构建器，生产者无法 emit 来自不同 CoroutineContext 的值。因此，不要通过创建新协程或使用 withContext 代码块在不同的 CoroutineContext 中调用 emit 。在这些情况下，可以使用其他流程构建器，例如 callbackFlow 。

下面请看错误示范：

```kotlin
fun errorUseFlow1(): Flow<Int> = flow {
    emit(1)
    // 下面这种是错误的用法
    withContext(Dispatchers.IO) {
        emit(2)
    }
}
```

当我开始collect时，发现崩溃了，日志如下：

```log
java.lang.IllegalStateException: Flow invariant is violated:
        Flow was collected in [StandaloneCoroutine{Active}@f3c5f9, Dispatchers.Main.immediate],
        but emission happened in [DispatchedCoroutine{Active}@5b3593e, Dispatchers.IO].
        Please refer to 'flow' documentation or use 'flowOn' instead
    at kotlinx.coroutines.flow.internal.SafeCollector_commonKt.checkContext(SafeCollector.common.kt:85)
    at kotlinx.coroutines.flow.internal.SafeCollector.checkContext(SafeCollector.kt:106)
    at kotlinx.coroutines.flow.internal.SafeCollector.emit(SafeCollector.kt:83)
    at kotlinx.coroutines.flow.internal.SafeCollector.emit(SafeCollector.kt:66)
    at com.xfhy.allinone.kotlin.coroutine.flow.KotlinFlowViewModel$errorUseFlow1$1$1.invokeSuspend(KotlinFlowViewModel.kt:54)
    at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
    at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:106)
    at kotlinx.coroutines.internal.LimitedDispatcher.run(LimitedDispatcher.kt:42)
    at kotlinx.coroutines.scheduling.TaskImpl.run(Tasks.kt:95)
    at kotlinx.coroutines.scheduling.CoroutineScheduler.runSafely(CoroutineScheduler.kt:570)
    at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.executeTask(CoroutineScheduler.kt:749)
    at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.runWorker(CoroutineScheduler.kt:677)
    at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.run(CoroutineScheduler.kt:664)
    Suppressed: kotlinx.coroutines.DiagnosticCoroutineContextException: [StandaloneCoroutine{Cancelling}@47e4abb, Dispatchers.Main.immediate]
```

大概意思是违反了Flow的不可变性，Flow是在StandaloneCoroutine环境中收集的，但是却在DispatchedCoroutine环境发射，让你用flowOn代替。正确写法是用flowOn来切换协程环境。

### 5.6 Flow和LiveData我到底怎么选？要不要迁移已有的代码到Flow？

LiveData仍然是Java项目、Android初学者、简单场景下的最佳选择。

对于除上面以外的其他情况，官方是建议使用Kotlin Flow。但是学习Kotlin Flow需要一些学习时间，但它是Kotlin语言的一部分，谷歌很挺这个东西。我去简单看了下[NowInAndroid](https://github.com/android/nowinandroid/tree/main)这个项目（该项目是谷歌官方的一个Android demo实战项目，功能齐全、完全使用Kotlin和Compose。遵循 Android 设计和开发最佳实践，旨在为开发人员提供有用的参考），我发现里面已经完全没有在使用LiveData了，全是Flow和各种Hilt依赖注入。理论上LiveData能做的事，Kotlin Flow也能做；LiveData不能做或者做起来比较困难的事，Kotlin Flow也能做。

我们可以打开[LiveData官网](https://developer.android.com/topic/libraries/architecture/livedata?hl=zh-cn)，即使是2024年，谷歌也没有将它标记为过时，它仍然是非常棒的选择。现在和将来很长一段时间理论上都不会被标记为过时，毕竟还有那么多Java项目，而且主要是用起来也非常简单方便。从谷歌2022年的一个采访([Architecture: Live Q&A - MAD Skills](https://www.youtube.com/watch?v=_2BtE1P6MPE))里面可以看出，谷歌意思是你想用LiveData就继续用，当然，更推荐你用Kotlin Flow。

至于要不要迁移，我的理解是，老代码就不动它。新代码，喜欢就可以用Flow，不喜欢就还是可以继续用LiveData。

## 6. Kotlin Flow 小结

好了，文章比较长，咱们再来回忆一下，主要介绍了Kotlin Flow的相关知识，包括基本概念、基本使用、实际应用以及一些需要注意的问题。Kotlin Flow是Kotlin协程的一部分，用于处理异步数据流，它相比LiveData和RxJava具有诸多优势，如更自然的协程支持、简单的语法、内存安全、更好的错误处理等。在基本使用方面，介绍了Flow的创建、消费、操作符、类型以及如何将回调转换为Flow、让Flow具备生命周期感知能力和处理配置变更问题等。在实际应用中，展示了Flow在请求网络、与Room结合使用以及替代LiveData解决问题等场景的用法。接着还有一些细节方面的讨论，如StateFlow无法连续emit的解决办法、多次连续的collect可能导致的问题、Flow中异常的处理、使用flow构建器的注意事项以及Flow和LiveData的选择和迁移问题。

## 7. 学习资料

*   [x] 天工AI Kotlin Flow 入门学习 <https://www.tiangong.cn/result/b016018d-482f-4ec4-a9f6-7638daadc82c>
*   [x] 官网Android 上的 Kotlin 数据流 <https://developer.android.com/kotlin/flow?hl=zh-cn>
*   [x] Introduction to Kotlin Flow <https://medium.com/simform-engineering/introduction-to-kotlin-flow-f425b5a839f>
*   [x] Understanding Backpressure and Buffer in Kotlin Coroutines Flow https://blog.stackademic.com/understanding-backpressure-and-buffer-in-kotlin-coroutines-flow-3f59e41c76f9
*   [x] Kotlin Flow 实际运用  https://www.youtube.com/watch?v=fSB6_KE95bU
*   [x] Lessons learnt using Coroutines Flow in the Android Dev Summit 2019 app https://medium.com/androiddevelopers/lessons-learnt-using-coroutines-flow-4a6b285c0d06
*   [x] A safer way to collect flows from Android UIs https://medium.com/androiddevelopers/a-safer-way-to-collect-flows-from-android-uis-23080b1f8bda
*   [x] Migrating from LiveData to Kotlin’s Flow  https://medium.com/androiddevelopers/migrating-from-livedata-to-kotlins-flow-379292f419fb
*   [x] Kotlin协程之Flow使用(一)  <https://juejin.cn/post/7034381227025465375/>
*   [ ] Kotlin协程之Flow使用(二)  <https://juejin.cn/post/7046155761948295175/>
*   [ ] Kotlin协程之Flow使用(三)  <https://juejin.cn/post/7046156485407014920/>
*   [ ] 20 | Flow：为什么说Flow是“冷”的？ <https://time.geekbang.org/column/article/491632>
*   [ ] 包教包会的Kotlin Flow教程 <https://juejin.cn/post/7336751931375648820>
*   [ ] 【Kotlin Flow】 一眼看全——Flow操作符大全 <https://juejin.cn/post/6989536876096913439>
*   [ ] 10 个有用的 Kotlin flow 操作符 <https://juejin.cn/post/7135013334059122719>
*   [ ] Kotlin 异步 | Flow 应用场景及原理 <https://juejin.cn/post/6989032238079803429>
*   [ ] Kotlin协程：Flow的异常处理 <https://juejin.cn/post/7142685735357775903>
*   [ ] 快速进阶 Kotlin Flow：掌握异步开发技巧 <https://juejin.cn/post/7265210595912319015>
*   [ ] 用错了Flow？每一次订阅都对应一次数据库的查询操作？Flow/StateFlow/SharedFlow 正确使用姿势 <https://juejin.cn/post/7229991597084885048>
*   [ ] 当，Kotlin Flow与Channel相逢 <https://juejin.cn/post/7224145268740325435>
*   [ ] 【Flow】图文详解Kotlin中SharedFlow和StateFlow <https://juejin.cn/post/7272690326401204259>
*   [ ] Kotlin协程之一文看懂StateFlow和SharedFlow  <https://juejin.cn/post/7169843775240405022>
*   [ ] Kotlin协程之Flow工作原理 <https://juejin.cn/post/6966047022814232613>
*   [ ] 协程(23) | Flow原理解析 <https://juejin.cn/post/7173494906319536142>
*   [ ] 不做跟风党，LiveData，StateFlow，SharedFlow 使用场景对比 https://juejin.cn/post/7007602776502960165?searchId=20240624222036FEB345AE9C334767E3F0#heading-17
*   [ ] Architecture: Live Q&A - MAD Skills  https://www.youtube.com/watch?v=_2BtE1P6MPE
