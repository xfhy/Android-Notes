协程官网4-不应取消的协程
---
#### 目录
- [用协程 还是 WorkManager?](#head1)
- [那些在协程中不应该取消的操作](#head2)
- [使用哪个协程构造器？launch or async？](#head3)
- [能不能稍微简单一点？](#head4)
- [替代方案](#head5)
	- [❌ GlobalScope](#head6)
	- [❌ ProcessLifecycleOwner scope in Android](#head7)
	- [❌ ✅ 使用 NonCancellable](#head8)
- [小结](#head9)

---


翻译自：https://medium.com/androiddevelopers/coroutines-patterns-for-work-that-shouldnt-be-cancelled-e26c40f142ad

标题：Coroutines & Patterns for work that shouldn’t be cancelled

副标题：Cancellation and Exceptions in Coroutines (Part 4)

在本系列的第2篇文章（协程的取消和异常）中，我们学习了及时取消协程的重要性。在Android上，你可以使用Jetpack提供的CoroutineScope：viewModelScope或lifecycleScope，当它们的scope是完成状态时，它们会自动取消所有的协程。即当Activity、fragment、Lifecycle结束时，取消所有正在进行的工作。如果你是自己创建CoroutineScope，那么请你确保启动协程时将Job实例保存起来，并在不需要的时候调用cancel取消掉。

然而，在有些情况下，你想让一个操作全部完成，而不能被中途取消掉，即使用户已离开此Activity。比如写入数据库或向服务器发起某种网络请求。然而，viewModelScope或lifecycleScope在完成状态时，会cancel掉，那我有个重要的工作还没做完，你给我cancel了不合适（cancel之后，其实并不会停止协程中代码的执行，因为cancel动作需要协程里面配合才行）。那咋办？

继续阅读，你将学习到如何解决上面的问题。

### <span id="head1">用协程 还是 WorkManager?</span>

如果你需要运行的某个操作的生命周期长于app进程（例如向服务器发送日志），那么，请使用WorkManager。WorkManager是用于预期在未来某个时间点执行的关键操作的库。

只要app进程还活着，那么协程就可以一直运行。对于那些需要在当前进程生命周期内有效，并且在用户杀掉app时可以取消的操作，就使用协程（例如，发起一个网络请求获取新闻列表数据）。

### <span id="head2">那些在协程中不应该取消的操作</span>

假如，我们的应用中有一个ViewModel和一个Repository，其逻辑如下：

```kotlin
class MyViewModel(private val repo: Repository) : ViewModel() {
  fun callRepo() {
    viewModelScope.launch {
      repo.doWork()
    }
  }
}
class Repository(private val ioDispatcher: CoroutineDispatcher) {
  suspend fun doWork() {
    withContext(ioDispatcher) {
      doSomeOtherWork()
      veryImportantOperation() // 这个操作不应该被取消，它非常重要
    }
  }
}
```

我们不希望veryImportantOperation()被viewModelScope控制，因为它可以在任何时候被取消。我们希望该操作比viewModelScope生命周期更长。我们怎么才能做到这一点？

为此，**请在Application类中创建自己的Scope，并在由它启动的协程中调用这些重要的操作**。哪些类需要用到该Scope，直接从Application中取就行了。

与我们稍后将看到的其他解决方案（如GlobalScope）相比，创建自己的CoroutineScope的好处是你可以根据需要对其进行配置。比如：你可以配置一个CoroutineExceptionHandler，将自己的线程池用作Dispatcher等，将所有常见的配置放在它的CoroutineContext中，非常方便。

你可以将其称为applicationScope，并且它必须包含一个SupervisorJob()以便协程中的异常不会在层次结构中传播（如本系列的第3篇文章中所示）。

```kotlin
class MyApplication : Application() {
  // No need to cancel this scope as it'll be torn down with the process
  //不需要取消该Scope，因为它会随着进程死亡而终止。
  val applicationScope = CoroutineScope(SupervisorJob() + otherConfig)
}
```

我们不需要取消该scope，因为我们希望只要应用程序进程还活着，它就保持活跃状态，所以我们不持有对SupervisorJob的引用。我们可以使用这个scope来运行协程，这些协程通常需要一个比调用处（比如ViewModel、Activity、Fragment等）更长的生命周期。

**对于不应取消的操作，请从Application中创建CoroutineScope，然后用该CoroutineScope创建协程来调用它们。**

每当你创建一个新的Repository实例时，请传入我们在上面创建的applicationScope。

### <span id="head3">使用哪个协程构造器？launch or async？</span>

根据veryImportantOperation()的行为，你需要根据需要使用launch或async启动一个新的协程：

- 如果你需要返回结果，那么使用async并调用await等待它完成
- 如果没有，请使用launch，等待它完成可以使用join。如本系列第3篇文章所示，你必须在launch中手动处理异常

下面是你将使用launch启动协程的方式：

```kotlin
class Repository(
  private val externalScope: CoroutineScope,
  private val ioDispatcher: CoroutineDispatcher
) {
  suspend fun doWork() {
    withContext(ioDispatcher) {
      doSomeOtherWork()
      externalScope.launch {
        //如果这里可能会抛异常，那么请用try.catch把这里包起来，或者定义一个CoroutineExceptionHandler在externalScope的CoroutineContext中
        veryImportantOperation()
      }.join()
    }
  }
}
```

或者你使用async：

```kotlin
class Repository(
  private val externalScope: CoroutineScope,
  private val ioDispatcher: CoroutineDispatcher
) {
  suspend fun doWork(): Any { // Use a specific type in Result
    withContext(ioDispatcher) {
      doSomeOtherWork()
      return externalScope.async {
        //调用await时会暴露异常，异常将在调用doWork的协程中传播。如果调用doWork处的协程已经cancel，把me该异常将被忽略。
        veryImportantOperation()
      }.await()
    }
  }
}
```

在ViewModel中用viewModelScope调用了上面的doWork后，在任何情况下，都不会影响externalScope的执行，即使viewModelScope被破坏。此外，doWork()在veryImportantOperation()完成之前不会返回，就像任何其他suspend函数调用一样。

### <span id="head4">能不能稍微简单一点？</span>

另一种使用方式是用withContext，然后将veryImportantOperation()包在externalScope的context中：

```kotlin
class Repository(
  private val externalScope: CoroutineScope,
  private val ioDispatcher: CoroutineDispatcher
) {
  suspend fun doWork() {
    withContext(ioDispatcher) {
      doSomeOtherWork()
      withContext(externalScope.coroutineContext) {
        veryImportantOperation()
      }
    }
  }
}
```

然而，使用这种方式有些地方需要注意一下：

- 如果调用doWork的协程在执行veryImportantOperation()时被取消，它将一直执行到下一个退出节点，而不是在veryImportantOperation()执行完成之后
- 当在withContext中使用context时，externalScope中的CoroutineExceptionHandler就不起作用了，异常将被重新抛出

### <span id="head5">替代方案</span>

其实还有一些其他的方式可以让我们使用协程来实现这一行为。不过，这些解决方案不是在任何条件下都能有条理地实现。下面就让我们看看一些替代方案，以及为何适用或者不适用，何时使用或者不使用它们。

#### <span id="head6">❌ GlobalScope</span>

这里有几个原因，为什么你不应该使用GlobalScope：

- **诱导我们写出硬编码值**：直接使用GlobalScope可能会让我们倾向于写出硬编码的Dispatchers，这是一种很差的实践方式。
- **它使测试变得非常困难**：由于你的代码将在不受控制的scope中执行，因此你将无法管理由它启动的协程的执行
- 你不能像我们对applicationScope所做的那样，为作用域中的所有协程都建立一个通用的CoroutineContext传递给GlobalScope启动所有的协程。

**建议：不要直接使用GlobalScope。**

#### <span id="head7">❌ ProcessLifecycleOwner scope in Android</span>

在Android中，`androidx.lifecycle:lifecycle-process`库中有一个applicationScope可用，可通过`ProcessLifecycleOwner.get().lifecycleScope` 访问。

在这种情况下，你需要传入一个LifecycleOwner而不是我们之前所传入的CoroutineScope。在生产环境中，你需要传入 ProcessLifecycleOwner.get()。

请注意，此Scope的默认CoroutineContext使用的是Dispatchers.Main.immediate，这可能不适合后台工作。与GlobalScope一样，你必须将一个公共的CoroutineContext传递给由GlobalScope启动的所有协程。

由于以上所有原因，这种替代方法相比在Application类中创建CoroutineScope要麻烦得多。而且，我个人不喜欢在 ViewModel 或 Presenter 层之下与 Android lifecycle 建立关系，我希望这些层级是平台无关的。

**建议：不要直接使用它。**

**特别说明**

如果你将GlobalScope 或 ProcessLifecycleOwner.get().lifecycleScope直接赋值给applicationScope，就像下面这样：

```kotlin
class MyApplication : Application() {
  val applicationScope = GlobalScope
}
```

你仍然可以获得上文所述的所有优点，并且将来可以根究需要轻松进行更改。

#### <span id="head8">❌ ✅ 使用 NonCancellable</span>

正如你在本系列第2篇文章所看到的，你可以使用withContext(NonCancelable)在被取消的协程中调用suspend函数。我们建议你使用它来执行suspend函数，这些函数一般用于清理资源。但是，你不应该滥用它。

这样做的风险很高，因为你将无法控制协程的执行。确实，它可以使代码更简洁，可读性更强，但与此同时，它也可能在将来引起一些无法预测的问题。

例如：

```kotlin
class Repository(
  private val ioDispatcher: CoroutineDispatcher
) {
  suspend fun doWork() {
    withContext(ioDispatcher) {
      doSomeOtherWork()
      withContext(NonCancellable) {
        veryImportantOperation()
      }
    }
  }
}
```

尽管这个方案很有诱惑力，但是你可能无法总是知道 veryImportantOperation() 背后有什么逻辑。它可能是一个扩展库；也可能是一个接口背后的实现。它可能会导致各种各样的问题:

- 你将无法在测试中结束这些操作；
- 使用延迟的无限循环将永远无法被取消；
- 从其中收集 Flow 会导致 Flow 也变得无法从外部取消；
- ......

而这些问题会导致出现细微且非常难以调试的错误。

建议：仅用它来挂起清理操作相关的代码。

### <span id="head9">小结</span>

**每当你需要执行一些超出当前作用域范围的工作时，我们都建议你在自己的Application类中创建一个自定义作用域，并在此作用域中执行协程。同时要注意，在执行这类任务时，避免使用GlobalScope、ProcessLifecycleOwner作用域或NonCancellable。**