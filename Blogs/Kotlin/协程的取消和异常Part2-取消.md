协程的取消和异常Part2-取消
---
#### 目录
- [取消协程](#head1)
- [为什么我的协程没有停止？](#head2)
- [让你的协程可取消](#head3)
- [检查Job的活动状态](#head4)
- [使用yield()让权](#head5)
- [Job.join() 和 Deferred.await() 的取消](#head6)
- [取消之后的收尾工作](#head7)
	- [方式1：检查 !isActive](#head8)
	- [方式2：Try catch finally](#head9)
	- [方式3：suspendCancellableCoroutine 和 invokeOnCancellation](#head10)
- [结语](#head11)

---


翻译自：https://medium.com/androiddevelopers/cancellation-in-coroutines-aa6b90163629

标题：Coroutines: first things first

副标题：Cancellation and Exceptions in Coroutines (Part 1)

在不需要协程继续工作时，需要及时地取消它，以免浪费内存和电量。本篇文章将带你了解协程取消的来龙去脉。

> ps: 为了能够顺利地阅读本篇文章，需要阅读和理解本系列的第一部分。

### <span id="head1">取消协程</span>

当启动多个协程时，要及时地跟踪它们或者单独取消每个协程可能是一件很麻烦的事情。我们当然可以取消启动协程的整个scope，但这样的话，该scope下面的所有子协程都会被取消。

```kotlin
//假设我们定义了一个CoroutineScope
val job1 = scope.launch { ... }
val job2 = scope.launch { ... }

scope.cancel()
```

**关注点：取消scope会取消其子协程**。

有时候，你可能只需要取消一个协程。调用job1.cancel()可以确保只有那个特定的协程会被取消，而所有其他的同级协程不受影响。

```kotlin
val job1 = scope.launch { ... }
val job2 = scope.launch { ... }

//第一个协程将被取消，另一个不会被影响
job1.cancel()
```

**关注点：一个子协程被取消不会影响到其他的兄弟姐妹**

协程内部是通过抛出一个特殊的异常来实现取消的：CancellationException。如果你想在取消时传递一些关于取消的原因，可以在调用cancel时提供一个CancellationException的实例：

```kotlin
fun cancel(cause: CancellationException? = null)
```

当然，你如果不想提供自己的CancellationException实例，内部将创建一个默认的CancellationException：

```kotlin
public override fun cancel(cause: CancellationException?) {
    cancelInternal(cause ?: defaultCancellationException())
}
```

在协程内部，子协程通过异常来通知其父协程自己已经取消了。父协程首先要看一下抛出来的异常是什么，如果是CancellationException，那么就不需要采取其他行动。而如果不是，那么就该抛异常就抛异常。比如下面这段代码，就会引起app崩溃：

```kotlin
private val jobScope = CoroutineScope(Job() + Dispatchers.Default)
jobScope.launch {
    val job1 = launch {
        log("job1")
        throw NullPointerException()
    }
}

崩溃栈：
2022-04-09 08:00:08.914 3004-3113/com.xfhy.allinone E/AndroidRuntime: FATAL EXCEPTION: DefaultDispatcher-worker-1
    Process: com.xfhy.allinone, PID: 3004
    java.lang.NullPointerException
        at com.xfhy.allinone.kotlin.coroutine.concept.CoroutineCancel$testCancel$1$job1$1.invokeSuspend(CoroutineCancel.kt:23)
        at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
        at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:106)
        at kotlinx.coroutines.scheduling.CoroutineScheduler.runSafely(CoroutineScheduler.kt:571)
        at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.executeTask(CoroutineScheduler.kt:738)
        at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.runWorker(CoroutineScheduler.kt:678)
        at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.run(CoroutineScheduler.kt:665)

```

而下面这段代码则不会崩溃:

```kotlin
jobScope.launch {
    val job1 = launch {
        delay(1000)
        log("job1")
    }
    job1.cancel()
}
```

**注意：一旦你取消了一个scope，你就不能在被取消的scope中启动新的协程。**

如果你使用androidx KTX库，那么你可以不用创建自己的scope，也不需要手动去取消它们。你可以在ViewModel中使用viewModelScope，或者，如果你想启动与生命周期作用域绑定的协程，你还可以使用lifecycleScope。viewModelScope和lifecycleScope都是CoroutineScope对象，viewModelScope会在ViewModel的clear()时会被取消，lifecycleScope会在DESTROYED时机时取消。

### <span id="head2">为什么我的协程没有停止？</span>

首先，我们需要搞清楚一点，如果我们只是调用cancel，这并不意味着协程的执行就会立刻停止。如果你没有在协程代码块中进行cancel的感知，然后手动停止协程代码块的执行，那么它就会继续执行，直到协程里面的工作全部做完。

来看个例子，假设我们需要在一秒钟内使用协程打印“Hello”两次。我们让协程允许1秒钟，然后取消它。

```kotlin
fun testCancelEarly() {
    val startTime = System.currentTimeMillis()

    scope.launch {
        val job = scope.launch {
            var nextPrintTime = startTime
            var i = 0
            while (i < 5) {
                if (System.currentTimeMillis() >= nextPrintTime) {
                    log("Hello ${i++}")
                    nextPrintTime += 500L
                }
            }
        }
        delay(1000L)
        log("Cancel")
        job.cancel()
        log("Done")
    }
}
```

输出：

```log
Hello 0
Hello 1
Hello 2
Cancel
Done
Hello 3
Hello 4
```

可以看到，虽然我们调用了cancel，但是并没有立即停止下来，而是继续执行到结束。一旦job.cancel被调用，协程就会进入Cancelling状态。但随后，我们看到Hello 3和Hello 4被打印出来。说明只有在工作完成后，协程才会进入Cancelled状态。

协程的执行并不是在调用cancel时停止。我们需要修改我们的代码，定期检查该协程是否处于active状态。

**关键点：取消协程需要开发者手动配合**

### <span id="head3">让你的协程可取消</span>

你需要确保你实现的所有协程都是可以取消的，因此你需要定期或在开始一个长期运行的工作之前检查当前协程的状态。例如，如果你正在从磁盘上读取多个文件，在你开始读取每个文件之前，检查该协程是否被取消。这样就可以避免在不需要的时候做多余的工作。

```kotlin
val job = launch {
    for(file in files) {
        // TODO 在这里检查状态，是否应该继续执行
        readFile(file)
    }
}
```

下面这段是官方原话：

All suspend functions from kotlinx.coroutines are cancellable: withContext, delay etc. So if you’re using any of them you don’t need to check for cancellation and stop execution or throw a CancellationException. But, if you’re not using them, to make your coroutine code cooperative we have two options:

所有来自kotlinx.coroutines的suspend函数都是可取消的，withContext、delay等。因此，如果你使用其中的任何一个suspend函数，那么其实不需要检查取消状态并停止执行或抛出一个CancellationException。但是，你如果不是用的kotlinx.coroutines的suspend函数，那么你要想取消协程，有下面2个方案：

- 检查job.isActive状态或ensureActive()
- 调用yield()让出资源

我们先来验证一下，既然withContext、delay都是可取消的，并且不需要检查取消状态。那我们就在Activity中用lifecycleScope起一个协程，然后在里面起一个withContext，在withContext里面不断地做事情（i++），当事情还没做完的时候就调用finish，当Activity在onDestroy状态的时候，lifecycleScope会被取消，那么自然而然的withContext也会被取消，那我们正在withContext里面做的事情会被停止吗？咱们来试一试。

```kotlin
fun testCancellationIsNotPossible(view: View) {
    val startTime = System.currentTimeMillis()
    lifecycleScope.launch {
        withContext(Dispatchers.IO) {
            var nextPrintTime = startTime
            var i = 0
            while (i < 15) {
                if (System.currentTimeMillis() >= nextPrintTime) {
                    log("Hello ${i++}")
                    nextPrintTime += 500L
                }
                if (i == 5) {
                    finish()
                }
            }
        }

        withContext(Dispatchers.Default) {
            log("Hello Dispatchers.Default")
        }

        log("Done")
    }
}

override fun onDestroy() {
    super.onDestroy()
    log("onDestroy")
}
    
//打印结果:
//Hello 0
//Hello 1
//Hello 2
//Hello 3
//Hello 4
//Hello 5
//onDestroy
//Hello 6
//Hello 7
//Hello 8
//Hello 9
//Hello 10
//Hello 11
//Hello 12
//Hello 13
//Hello 14
```

出乎意料，竟然没有停下来，和官方的`So if you’re using any of them you don’t need to check for cancellation and stop execution or throw a CancellationException`这句话有点出入，不知道是不是我理解错了，但这里确实withContext没有停下来。因为在i==5的时候，进行了finish，所以onDestroy被打印出来了。 这个时候其实lifecycleScope已经cancel了，然而第一个withContext并没有结束，因为它没有感知到已经cancel了，继续执行，一直到执行完成。但最后的Done和第二个withContext没有打印出来，因为已经cancel了，不会再切线程回来执行了。

### <span id="head4">检查Job的活动状态</span>

下面我们来让withContext可取消：

```kotlin 
fun cancellableWithContext(view: View) {
    val startTime = System.currentTimeMillis()
    lifecycleScope.launch {
        withContext(Dispatchers.IO) {
            var nextPrintTime = startTime
            var i = 0
            while (i < 15 /* && isActive*/) {
                ensureActive()
                if (System.currentTimeMillis() >= nextPrintTime) {
                    log("Hello ${i++}")
                    nextPrintTime += 1000L
                }
                if (i == 5) {
                    finish()
                }
            }
        }
        log("Done")
    }
}

//打印结果:
//Hello 0
//Hello 1
//Hello 2
//Hello 3
//Hello 4
//onDestroy
```

让withContext感知到取消很简单，就是使用isActive或者ensureActive()。用isActive可以感知状态，而调用ensureActive()方法的话，则是在内部判断到已取消时抛出CancellationException,它的实现：

```kotlin
fun Job.ensureActive(): Unit {
    if (!isActive) {
         throw getCancellationException()
    }
}
```

上面的withContext替换成async之类的也是同样的道理，但有一个比较特殊，就是delay。下面来看个例子：

```kotlin
fun cancellableDelay(view: View) {
    lifecycleScope.launch {
        delay(2000)
        log("Hello")
        finish()
        log("finish")
        delay(3000)
        log("World")
    }
}
//打印结果:
//2022-04-14 08:01:22.133 18324-18324/com.xfhy.allinone D/xfhy_tag: Hello
//2022-04-14 08:01:22.137 18324-18324/com.xfhy.allinone D/xfhy_tag: finish
//2022-04-14 08:01:22.719 18324-18324/com.xfhy.allinone D/xfhy_tag: onDestroy
```

调用finish之后，582毫秒之后才执行onDestroy，这个时候早就已经执行到delay(3000)，这时lifecycleScope取消了，这里的delay(3000)也被取消了，因为后面的World没有被打印出来。说明在delay时，能感知到取消状态，并取消。

### <span id="head5">使用yield()让权</span>

首先yield()是一个官方定义的suspend函数，我们可以在协程中使用它，它有几个作用：

- 它暂时降低当前长时间运行的CPU任务的优先级，为其他任务提供公平的运行机会
- 检查当前Job是否被取消
- 允许子任务的执行，当你的任务数大于当前允许并行执行的数目时，这可能很重要。

如果你正在做的工作是下面几种类型：

1. CPU繁重
2. 可能会耗尽线程池
3. 你想让线程做其他工作，而不需要向线程池添加更多线程

那么就使用yield()函数。yield所做的第一个操作将是检查完成情况，如果工作已经完成，则通过抛出CancellationException退出协程。

是不是有点不好理解，下面来看段代码：

```kotlin
fun yieldTest(view: View) {
    val singleDispatcher = newSingleThreadContext("singleDispatcher")
    lifecycleScope.launch(singleDispatcher) {
        launch {
            withContext(singleDispatcher) {
                repeat(3) {
                    log("Task1 $it")
                    //yield()
                }
            }
        }
        launch {
            withContext(singleDispatcher) {
                repeat(3) {
                    log("Task2 $it")
                    //yield()
                }
            }
        }
    }
    //注释掉yield()的情况下，打印结果：
    //Task1 0
    //Task1 1
    //Task1 2
    //Task2 0
    //Task2 1
    //Task2 2
    
    //放开注释yield()的情况下，打印结果：
    //Task1 0
    //Task2 0
    //Task1 1
    //Task2 1
    //Task1 2
    //Task2 2
}
```

看到这里，大家应该清楚是为什么了吧。yield在协程中可以简单的理解为，挂起当前任务，让其他正在等待的任务公平的竞争，去获得执行权。

### <span id="head6">Job.join() 和 Deferred.await() 的取消</span>

有2种方式可以等待一个协程执行完成：

1. 调用launch时会返回一个job实例，调用job的join方法
2. 调用async时会返回一个Deferred(Job的一种类型)，调用Deferred的await方法

Job.join会挂起一个协程直到job对应的协程执行完成，当它和job.cancel一起配合时的一些情况：

1. 如果你先调用job.cancel然后再调用job.join，那么该协程的isActive是false，而且该协程不会执行。
2. 在job.join后调用job.cancel没有任何效果，因为job已经执行完成了。

举个例子：

```kotlin
//案例1
fun testJobCancel(view: View) {
    val startTime = System.currentTimeMillis()
    lifecycleScope.launch {
        val job = launch {
            var i = 0
            var nextPrintTime = startTime
            while (i < 5) {
                if (System.currentTimeMillis() >= nextPrintTime) {
                    log("Hello ${i++}")
                    nextPrintTime += 1000L
                }
            }
        }
        log("job isActive: ${job.isActive}")
        log("cancel job")
        job.cancel()
        log("job isActive: ${job.isActive}")
        log("join job")
        job.join()
    }
    //打印结果：
    //job isActive: true
    //cancel job
    //job isActive: false
    //join job
}

//案例2
fun testJobCancel(view: View) {
    val startTime = System.currentTimeMillis()
    lifecycleScope.launch {
        val job = launch {
            var i = 0
            var nextPrintTime = startTime
            while (i < 5 && isActive) {
                if (System.currentTimeMillis() >= nextPrintTime) {
                    log("Hello ${i++}")
                    nextPrintTime += 1000L
                }
                cancel()
                log("inner isActive: ${isActive}")
            }
        }
        log("job isActive: ${job.isActive}")
        log("join job")
        job.join()
    }
    //打印结果：
    //job isActive: true
    //join job
    //Hello 0
    //inner isActive: false
}
```

如果你想拿到协程执行的结果，那么可以使用Deferred。该结果由Deferred.await返回（协程结束时），Deferred是Job的一种类型，它也可以被取消。

如果一个Deferred已经被取消，那么再调用await时会抛出JobCancellationException。

```kotlin
val deferred = async { … }
deferred.cancel()
val result = deferred.await() // throws JobCancellationException!
```

为什么这里会抛一个异常？await的作用是挂起协程直到结果被计算出来，由于协程被取消，那么结果就计算不出来了。因此，在取消后调用await会抛出`JobCancellationException: Job was cancelled`。

另一方面，如果你在await之后再调用cancel，那什么也不会发生，因为该协程已经执行完成了。

### <span id="head7">取消之后的收尾工作</span>

假如，当一个协程被取消时，你想执行一个特定的动作：关闭任何你想关闭的资源、清理代码之类的。我们有3种方式可以帮你做到这一点。

#### <span id="head8">方式1：检查 !isActive</span>

如果你定期检查isActive，那么一旦isActive为false，说明已经被cancel了，就可以开始清理资源了。

```kotlin
while (i < 5 && isActive) {
    // print a message twice a second
    if (…) {
        println(“Hello ${i++}”)
        nextPrintTime += 500L
    }
}
// the coroutine work is completed so we can cleanup
println(“Clean up!”)
```

#### <span id="head9">方式2：Try catch finally</span>

因为当一个协程被取消时，会抛出CancellationException，那么我们可以用try..catch包住我们在协程中需要执行的代码，在finally块中，执行清理动作。

```kotlin
val job = launch {
   try {
      work()
   } catch (e: CancellationException){
      println(“Work cancelled!”)
    } finally {
      println(“Clean up!”)
    }
}
delay(1000L)
println(“Cancel!”)
job.cancel()
println(“Done!”)
```

但是，如果需要在finally代码块执行suspend函数，是不行的。因为这个时候协程已经处于Canceling状态，因此不能再挂起。

**关键点：处于取消状态的协程，无法再挂起**

为了能够在协程被取消时调用suspend函数，我们需要切换到NonCancellable CoroutineContext中做清理工作。这允许协程代码挂起，并将协程保持在Canceling状态，直到清理工作完成。什么是NonCancellable？它是官方提供的一个工具类，继承自Job，但始终处于isActive为true的状态，且是不可取消的Job。它是专门为withContext设计的，像上面这种需要在不可取消的情况下执行的代码块，就需要用到它。

```kotlin
public object NonCancellable : AbstractCoroutineContextElement(Job), Job 
```

下面来看一段示例代码：

```kotlin
private suspend fun work(){
    val startTime = System.currentTimeMillis()
    var nextPrintTime = startTime
    var i = 0
    while (i < 5) {
        yield()
        // print a message twice a second
        if (System.currentTimeMillis() >= nextPrintTime) {
            log("Hello ${i++}")
            nextPrintTime += 500L
        }
    }
}

fun cleanByTryCatch(view: View) {
    lifecycleScope.launch {
        val job = launch (Dispatchers.Default) {
            try {
                work()
            } finally {
                withContext(NonCancellable){
                    delay(2000L)
                    log("Cleanup done!")
                }
            }
        }
        delay(1000L)
        log("Cancel!")
        job.cancel()
        log("Done!")
    }
    //打印结果：
    //Hello 0
    //Hello 1
    //Hello 2
    //Cancel!
    //Done!
    //Cleanup done!
}
```

从示例代码中可以看出，即使job已经被cancel了，但是在withContext里面的执行清理的代码还是继续在执行着，符合我们的需求。

#### <span id="head10">方式3：suspendCancellableCoroutine 和 invokeOnCancellation</span>

如果你使用suspendCancellableCoroutine，那么做取消时的清理工作就非常方便，直接使用continuation.invokeOnCancellation就行：

```kotlin
suspend fun work() {
   return suspendCancellableCoroutine { continuation ->
       continuation.invokeOnCancellation { 
          // do cleanup
       }
       // rest of the implementation
   }
}
```

举个例子：

```kotlin
fun cleanByInvokeOnCancellation(view: View) {
    suspend fun work() {
        return suspendCancellableCoroutine { continuation ->
            continuation.invokeOnCancellation {
                // do cleanup
                log("Cleanup done!")
            }
            // rest of the implementation
            val startTime = System.currentTimeMillis()
            var nextPrintTime = startTime
            var i = 0
            
            while (i < 5 && continuation.isActive) {
                // print a message twice a second
                if (System.currentTimeMillis() >= nextPrintTime) {
                    log("Hello ${i++}")
                    nextPrintTime += 500L
                }
            }
        }
    }
    lifecycleScope.launch {
        val job = launch(Dispatchers.Default) {
            work()
        }
        delay(1000L)
        log("Cancel!")
        job.cancel()
        log("Done!")
    }
    
    //打印结果：
    //Hello 0
    //Hello 1
    //Hello 2
    //Cancel!
    //Cleanup done!
    //Done!
}
```

在调用cancel的时候，invokeOnCancellation立刻就被感知到了。

### <span id="head11">结语</span>

为了更好地利用结构化并发带来的好处，并确保我们没有做不必要的工作，你需要确保你的代码也可以取消。

使用Jetpack中定义的CoroutineScope：viewModelScope或lifecycleScope，它们会在其作用域完成时取消其工作。如果你使用的是自定义的CoroutineScope，请确保在不需要时即时调用cancel将其取消掉。

协程的取消需要开发者在代码中做配合，及时判断isActive状态，避免做多余的工作。
