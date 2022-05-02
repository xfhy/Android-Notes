协程的取消和异常Part3-异常
---
#### 目录
- [一个协程突然失败了！我该怎么办？😱](#head1)
- [SupervisorJob 来拯救你](#head2)
- [Job or SupervisorJob? 🤔](#head3)
- [协程的parent是谁？🎯](#head4)
- [底层原理](#head5)
- [处理异常🚒](#head6)
	- [launch](#head7)
	- [async](#head8)
	- [CoroutineExceptionHandler](#head9)
- [小结](#head10)

---
翻译自：https://medium.com/androiddevelopers/exceptions-in-coroutines-ce8da1ec060c

标题：Exceptions in coroutines

副标题：Cancellation and Exceptions in coroutines (Part 3) — Gotta catch ’em all!

我们作为开发者，在开发app时，如果程序的运行没有按预期执行时，应适当地给用户提示。一方面，看到应用程序崩溃对用户来说是一种糟糕的体验；另一方面，当操作没有成功时，向用户显示正确的信息是必不可少的。

正确处理异常会对用户如何看待你的应用程序产生巨大影响，在本文中，我将解释异常是如何在协程中传播的，以及你如何始终处于控制之中，包括处理它们的不同方式。

### <span id="head1">一个协程突然失败了！我该怎么办？😱</span>

当一个协程发生了异常，它会将该异常传播到它的父级。然后，父协程将执行以下逻辑：

1. 取消其他的子协程
2. 取消自己
3. 将异常传播到其父级

最终该异常会传播到协程的层次结构的根部，最顶层，所有被CoroutineScope启动的协程都将被取消。

![协程中异常在层次结构中传播](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/协程中异常在层次结构中传播.png)

虽然传播异常在某些情况下是有意义的，但在其他情况下这是不合适的。举个例子：假设，某个点击按钮的处理逻辑交给一个CoroutineScope启协程来处理。如果其中的一个子协程抛出了一个异常，那么该CoroutineScope就会被取消，那么该按钮的点击操作就变得没有任何反应，因为一个被取消了的CoroutineScope不能再启动更多的协程。

怎么解决上面的问题？你可以在创建CoroutineScope的CoroutineContext的时候，使用Job的另一个实现，即SupervisorJob。

### <span id="head2">SupervisorJob 来拯救你</span>

用上SupervisorJob之后，其中一个子协程崩了，并不影响其他子协程。SupervisorJob不会取消自己或其他子协程。而且，SupervisorJob也不会传播异常，而是让子协程处理它。你可以像`val uiScope = CoroutineScope(SupervisorJob())`这样创建一个协程，此协程失败时不会传播异常，如下图所示：

![SupervisorJob不会取消自己或其他子协程](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/SupervisorJob不会取消自己或其他子协程.png)

如果这个异常没有被处理，并且该CoroutineScope的CoroutineContext没有配置CoroutineExceptionHandler（稍后会讲到），那么该异常会达到线程的ExceptionHandler。如果是JVM，那么该异常会打印log到控制台上；如果是Android，那么app将会崩溃无论发生在什么Dispatcher上。

举个例子：

```kotlin
val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
scope.launch {
    val deferred1 = async {
        log("hello")
        delay(300)
        throw IllegalStateException("hello")
    }
    val deferred2 = async {
        log("world")
        delay(10000)
        log("卧槽")
    }
    deferred1.await()
    deferred2.await()
    log("哈哈")
}

//打印结果：
//hello
//world
```

之后app崩了

```log
2022-04-26 07:34:28.872 30183-31481/com.xfhy.allinone E/AndroidRuntime: FATAL EXCEPTION: DefaultDispatcher-worker-2
    Process: com.xfhy.allinone, PID: 30183
    java.lang.IllegalStateException: hello
        at com.xfhy.allinone.kotlin.coroutine.concept.KotlinCoroutineActivity$childCoroutineThrowsException$1$deferred1$1.invokeSuspend(KotlinCoroutineActivity.kt:340)
        at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
        at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:106)
        at kotlinx.coroutines.scheduling.CoroutineScheduler.runSafely(CoroutineScheduler.kt:571)
        at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.executeTask(CoroutineScheduler.kt:738)
        at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.runWorker(CoroutineScheduler.kt:678)
        at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.run(CoroutineScheduler.kt:665)
```

💥 无论你使用哪种类型的Job，都会抛出未捕获的异常

> ps: lifecycleScope和viewModelScope的CoroutineContext都有SupervisorJob()

### <span id="head3">Job or SupervisorJob? 🤔</span>

什么时候该用SupervisorJob？什么时候该用Job？

当你不想让一个异常取消父级协程和其他兄弟协程时，就用SupervisorJob。

举个例子：

```kotlin
val scope = CoroutineScope(SupervisorJob())

scope.launch {
    // Child 1
}

scope.launch {
    // Child 2
}
```

在这种情况下，如果child 1失败，则scope和child 2都不会被取消。

### <span id="head4">协程的parent是谁？🎯</span>

大家请看下面这段代码，你能识别出协程的Job是什么类型吗？

```kotlin
val scope = CoroutineScope(Job())

scope.launch(SupervisorJob()) {
    // new coroutine -> can suspend
    
   launch {
        // Child 1
    }
    
    launch {
        // Child 2
    }
}
```

child 1的Job是Job类型，并不是SupervisorJob。一个新的协程总是被分配一个新的Job实例，在上面这种情况下，会覆盖SupervisorJob。从代码上看，SupervisorJob在上面这段代码中什么作用都没有。

请记住：SupervisorJob仅在它是scope的一部分时才正常工作，使用supervisorScope 或 CoroutineScope(SupervisorJob()) 创建。将SupervisorJob作为协程构造器的参数传递并不会产生任何效果。

关于异常，如果任何子协程抛出异常，SupervisorJob不会在协程的层次结构中向上传播异常，而是让其协程处理它。

### <span id="head5">底层原理</span>

如果你对Job的工作原理感到好奇，请查看JobSupport.kt文件中childCancelled和notifyCancelling函数的实现。

在SupervisorJob实现中，childCancelled方法只返回false，这意味着它不传播取消，但也不处理异常。

### <span id="head6">处理异常🚒</span>

协程使用常规的kotlin语法来处理异常：try.catch。或者使用内置的函数，如runCatching(其内部也是try.catch)。

我们之前说过，未捕获的异常总是会被抛出。但是，不同的协程构建器（launch、async等）有不同的处理异常的方式。

#### <span id="head7">launch</span>

**使用launch时，一旦发生异常就会被立刻抛出**。因此，你可以将可能引发异常的代码块用try.catch包一下。如下面的示例代码一样：

```kotlin
scope.launch {
    try {
        codeThatCanThrowExceptions()
    } catch(e: Exception) {
        // Handle exception
    }
}
```

#### <span id="head8">async</span>

当使用async时，如果async被当做一个根协程（它是CoroutineScope或者supervisorScope的直接子协程）使用时，**异常不会被立刻抛出，而是等到你调用.await()时才抛出。**

无论async是否被当做一个根协程，处理异常的方式都是将await调用处用try.catch包一下。

```kotlin
supervisorScope {
    val deferred = async {
        codeThatCanThrowExceptions()
    }
    try {
        deferred.await()
    } catch(e: Exception) {
        // Handle exception thrown in async
    }
}
```

在上面的示例中，调用async不会抛出异常，因此不需要用try.catch包住。调用await将抛出异常，这个异常是在async协程内部抛出的。

> 当async用作根协程时，调用await时才会抛出异常。

另外，需要注意的是，上面的示例代码中我们使用的是supervisorScope来调用async和await。正如我们之前所说，SupervisorJob是让协程处理异常；与Job不同，Job将自动在层次结构中向上传播，因此不会调用catch块：

```kotlin
coroutineScope {
    try {
        val deferred = async {
            codeThatCanThrowExceptions()
        }
        deferred.await()
    } catch(e: Exception) {
        // Exception thrown in async WILL NOT be caught here 
        // but propagated up to the scope
    }
}
```

此外，由其他协程创建的协程中发生的异常将始终被传播，而与协程构建器无关。举个例子：

```kotlin
val scope = CoroutineScope(Job())
scope.launch {
    async {
        // If async throws, launch throws without calling .await()
    }
}
```

在这种情况下，如果async抛出异常，它会在它发生时立即被抛出，因为该scope的直接子协程是launch。原因是async（在其CoroutineContext中附带的是Job）将自动将异常传播到其父协程（launch），所以将引发异常。

⚠️**在coroutineScope构建器或由其他协程创建的协程中抛出的异常不会被try.catch捕获**

下面是个很常见的场景：

```kotlin
lifecycleScope.launch {
    try {
        val deferred = async {
            throw IllegalStateException("hello")
        }
        deferred.await()
    } catch (e: Exception) {
        //异常不会在这里被捕获到,但会在作用域内传播
        log("catch")
    }
}
```

上面的try.catch是捕获不住异常的，如果你把try.catch加在lifecycleScope.launch外面，也依然不能捕获住异常。那咋办？解决方案有2个：

1. **每个子协程内部都用try.catch包住**
2. **设置CoroutineExceptionHandler**（后面会详细说这个）

#### <span id="head9">CoroutineExceptionHandler</span>

CoroutineExceptionHandler是一个可选的CoroutineContext参数，可以在构建Scope时传入，它的作用是允许你自己处理未捕获的异常。有点像Thread的UncaughtExceptionHandler。

下面定义了一个CoroutineExceptionHandler，每当捕获到异常时，你可以拿到发生异常的CoroutineContext以及异常本身的信息：

```kotlin
val handler = CoroutineExceptionHandler {
    context, exception -> println("Caught $exception")
}
```

CoroutineExceptionHandler满足下面这些条件时，异常才会被捕获：

- 何时：异常由自动抛出异常的协程抛出（适用于launch，不适用于async）
- 何处：它在CoroutineScope 或根协程（CoroutineScope 或 supervisorScope 的直接子级）的CoroutineContext

让我们来看一些使用上面定义的CoroutineExceptionHandler的例子。在下面的示例中，异常将被处理程序捕获：

```kotlin
//示例1
val scope = CoroutineScope(Job())
//这个launch就是根协程，handler是它的CoroutineContext的一员
scope.launch(handler) {
    launch {
        throw Exception("Failed coroutine")
    }
}
```

```kotlin
//示例2
private val exceptionHandler = CoroutineExceptionHandler { croutineContext, throwable ->
    log("exceptionHandler ${throwable.message}")
}

fun coroutineExceptionHandler(view: View) {
    lifecycleScope.launch(exceptionHandler) {
        val deferred = async {
            delay(1000)
            throw Exception("async 抛出了一个异常")
        }
        //加个延时 主要是验证异常是不是在await的时候抛出
        delay(2000)
        try {
            deferred.await()
        } catch (e: Exception) {
            log("deferred await catch")
        }
        log("后续代码")
    }
    //打印结果
    //exceptionHandler async 抛出了一个异常
}
```

上面的示例2中，async并不是在await处抛出的异常，在执行async时就抛出来了，而且launch后续的代码也不执行了，因为遇到了未捕获的异常，向上传递到CoroutineExceptionHandler那里去了。

在下面的例子例子中，CoroutineExceptionHandler被放到了内部的协程中，它将不再起作用：

```kotlin
val scope = CoroutineScope(Job())
scope.launch {
    launch(handler) {
        throw Exception("Failed coroutine")
    }
}
```

异常没有被捕获，因为CoroutineExceptionHandler没有放在正确的CoroutineContext中。内部launch将在异常发生时将异常传播到父级，因为父级对处理程序一无所知，因此将抛出异常。

### <span id="head10">小结</span>

在你的应用程序中优雅地处理异常对于拥有良好的用户体验非常重要，即使事情没有按预期进行。当你想避免在发生异常时传播cancel状态时，请使用SupervisorJob，否则使用Job。

没有捕获的异常将向上传播，捕获它们以提供出色的用户体验！
