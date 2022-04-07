协程的取消和异常Part1-核心概念
---
#### 目录
- [CoroutineScope](#head1)
- [Job](#head2)
- [CoroutineContext](#head3)
- [Job的生命周期](#head4)
- [父级CoroutineContext](#head5)

---

翻译自： https://medium.com/androiddevelopers/coroutines-first-things-first-e6187bf3bb21

标题：Coroutines: first things first

副标题：Cancellation and Exceptions in Coroutines (Part 1)

本系列博文将深入探讨协程中的取消和异常。即时取消对于避免做多余的工作很重要，因为这会浪费内存和电池寿命；正确的异常处理是良好用户体验的关键。作为本系列其他 3 部分的基础，本篇文章定义了一些协程的核心概念（例如 CoroutineScope、Job 和 CoroutineContext），这些东西非常重要。

### <span id="head1">CoroutineScope</span>

CoroutineScope可以对你创建的launch和async（它们是CoroutineScope的扩展函数）进行跟踪。进行中的协程可以在任何时间点通过调用scope.cancel()来取消。在Android上，KTX库已经提供了可感知生命周期的CoroutineScope，如viewModelScope和lifecycleScope，它们会在合适的时候cancel。

创建一个CoroutineScope，它需要一个CoroutineContext作为其构造函数的参数。

```kotlin
//Job和Dispatcher 组合成 CoroutineContext
val scope = CoroutineScope(Job() + Dispatchers.Main)

val job = scope.launch {
    //new coroutine
}
```

### <span id="head2">Job</span>

一个Job是对一个协程的句柄。你创建的每个协程，不管你是通过launch还是async来启动的，它都会返回一个Job实例，唯一标识该协程，并可以通过该Job管理其生命周期。在上面的示例代码中，在CoroutineScope的构造函数中也传入了一个Job，以保持对其生命周期的控制。

### <span id="head3">CoroutineContext</span>

CoroutineContext是一组元素，它定义了一个协程的行为。它由下面几个部分组成：

- Job: 控制协程的生命周期
- CoroutineDispatcher：将工作分发给适当的线程
- CoroutineName：协程的名字，调试时很有用
- CoroutineExceptionHandler：处理未捕获的异常

新创建的一个协程的CoroutineContext是什么？当创建一个协程时，会创建一个新的Job实例，通过它我们可以控制其生命周期。其余的元素将从父级的CoroutineContext中继承下来。

CoroutineScope可以创建协程，在协程内部又可以创建更多的协程，因此创建了一个隐含的任务层次结构。

```kotlin
val scope = CoroutineScope(Job() + Dispatchers.Main)
scope.launch {
    //新的协程,它的parent是CoroutineScope
    val result = async {
        //新的协程  它的parent是launch
    }.await()
}
```

该层次结构的根通常是CoroutineScope。协程在一个任务层次中被执行，父级可以是CoroutineScope，也可以是另一个协程。

![协程的层次结构](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/协程的层次结构.png)

### <span id="head4">Job的生命周期</span>

Job可以经历一系列的状态：New、Active、Completing、Completed、Cancelling、Cancelled。虽然我们不能访问这些状态本身，但我们可以访问Job的属性来判断：isActive、isCancelled和isCompleted。

![Job的生命周期](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/协程Job的生命周期.png)

如果协程处于Active状态，协程执行失败或者调用job.cancel()将使Job进入Cancelling状态（isActive = false，isCancelled = true）。

### <span id="head5">父级CoroutineContext</span>

在任务层次结构中，每个协程都有一个父级，可以是CoroutineScope或另一个协程。然而，构建出来的协程的父级CoroutineContext可以与父级的CoroutineContext不同（有点绕），它是基于下面这个公式计算出来的。

```
Parent context = Defaults + inherited CoroutineContext + arguments
```

- defaults: 一些元素是有默认值的，Dispatchers.Default是CoroutineDispatcher的默认值；"coroutine"是CoroutineName的默认值
- inherited CoroutineContext： 继承的CoroutineContext，是创建它的CoroutineScope或协程的CoroutineContext
- arguments： 在协程构造器中传递的参数将优先于继承的context中的那些元素。（如launch(xx){}，这里的xx就是参数）

> ps: CoroutineContext可以使用`+`操作符进行组合。由于CoroutineContext是一组元素，在创建CoroutineContext的时候，加号右边的元素将覆盖左边的元素。例如：`(Dispatchers.Main, “name”) + (Dispatchers.IO) = (Dispatchers.IO, “name”)`

```
//Defaults: Dispatchers.Default,"coroutine"
val scope = CorotineScope (
    Job() + Dispatchers.Main + coroutineExceptionHandler
)

//Parent context : Dispatchers.Main、"coroutine"（默认值）、Job、coroutineExceptionHandler
```

现在我们知道什么是一个新的协程的父级CoroutineContext，而协程本身的CoroutineContext是：

```
New coroutine context = parent CoroutineContext + Job()
```

如果用上面的CorotineScope创建一个新的协程，像下面这样：

```kotlin
val job = scope.launch(Dispatchers.IO) {
    //new coroutine
}
```

这个协程的父CoroutineContext和它的实际CoroutineContext是什么？

![CoroutineContext示例](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/CoroutineContext示例.png)

CoroutineContext中的Job和父级上下文中的Job永远不会是同一个实例，因为一个新的coroutine总是得到一个Job的新实例。注意，这个协程的父CoroutineContext的Dispatchers是Dispatchers.IO而不是scope的Dispatchers.Main，因为它被协程构造器的参数所覆盖。另外，这个新创建出来的协程的父CoroutineContext的Job其实是scope的Job实例，而该协程本身的Job的实例是新创建的。

在本系列的第3部分中，将会提到一个SupervisorJob，它是Job的另一种实现方式，它改变了CoroutineScope处理异常的方式。因此，用上面那个scope创建的新的协程可以将SupervisorJob作为父Job。然而，当一个协程的parent是另一个协程时，parent job将总是属于Job类型。