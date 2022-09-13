Kotlin作用域函数
---
#### 目录
- [1.前置知识](#head1)
- [2.使用](#head2)
- [3.源码赏析](#head3)
	- [3.1 let和run](#head4)
	- [3.2 also和apply](#head5)
	- [3.3 repeat](#head6)
	- [3.4 with](#head7)
- [4.反编译](#head8)
- [5.小结](#head9)

---

### <span id="head1">1.前置知识</span>

在Kotlin中，函数是一等公民，它也是有自己的类型的。比如`()->Unit`，函数类型是可以被存储在变量中的。

Kotlin中的函数类型形如：`()->Unit`、`(Int,Int)->String`、`Int.(String)->String`等。它们有参数和返回值。

最后一个`Int.(String)->String`比较奇怪，它表示函数类型可以有一个额外的接收者类型。这里表示可以在Int对象上调用一个String类型参数并返回一个String类型的函数。

```kotlin
val test: Int.(String) -> String = { param ->
    "$this param=$param"
}
println(1.test("2"))
println(test(1, "2"))
```

如果我们把`Int.(String) -> String`类型定义成变量，并给它赋值，后面的Lambda的参数param就是传入的String类型，最后返回值也是String，而在这个Lambda中用this表示前面的接收者类型Int的对象，有点像扩展函数，可以在函数内部通过this来访问一些成员变量、成员方法什么的。**可以把这种带接收者的函数类型，看成是成员方法**。

因为它的声明方式有点像扩展函数，所以我们可以使用`1.test("2")`来调用test这个函数类型，它其实编译之后最终是将1这个Int作为参数传进去的。所以后面的`test(1, "2")`这种调用方式也是OK的。

有了上面的知识补充，咱们再来看Kotlin的标准库函数apply

```kotlin
public inline fun <T> T.apply(block: T.() -> Unit): T {
    contract {
        callsInPlace(block, InvocationKind.EXACTLY_ONCE)
    }
    block()
    return this
}
```

- 首先apply是一个扩展函数，其次是带泛型的，意味着任何对象都可以调用apply函数。
- 接着它的参数是带接收者的函数类型，接收者是T，那么调用block()就像是调用了T对象里面的一个成员函数一样，在block函数内部可以使用this来对公开的成员变量和公开的成员函数进行访问
- 返回值：就是T，哪个对象调用的该扩展函数就返回哪个对象

### <span id="head2">2.使用</span>

作用域函数是Kotlin内置的，可对数据进行操作转换等。

先来看个demo，let和run

```kotlin
data class User(val name: String)

fun main() {

    val user = User("云天明")
    val letResult = user.let { param ->
        "let 输出点东西 ${param.name}"
    }
    println(letResult)
    val runResult = user.run {  //this:User
        "run 输出点东西 ${this.name}"
    }
    println(runResult)
}
```

let和run是类似的，都会返回Lambda的执行结果，区别在于let有Lambda参数，而run没有。但run可以使用this来访问user对象里面的公开属性和函数。

also和apply也是类似的

```kotlin
user.also { param->
    println("also ${param.name}")
}.apply { //this:User
    println("apply ${this.name}")
}
```

also和apply返回的是当前执行的对象，also有Lambda参数（这里的Lambda参数就是当前执行的对象），而apply没有Lambda参数（而是通过this来访问当前执行的对象）。

repeat是重复执行当前Lambda

```kotlin
repeat(5) {
    println(user.name)
}
```

with比较特殊，它不是以扩展方法的形式存在的，而是一个顶级函数

```kotlin
with(user) { //this: User
    println("with ${this.name}")
}
```

with的Lambda内部没有参数，而是可以通过this来访问传入对象的公开属性和函数。

### <span id="head3">3.源码赏析</span>

使用这块的话，不多说，想必大家已经非常熟悉，我们直接开始源码赏析。

#### <span id="head4">3.1 let和run</span>

```kotlin
//let和run是类似的，都会返回Lambda的执行结果，区别在于let有Lambda参数，而run没有。但run可以使用this来访问user对象里面的公开属性和函数。
public inline fun <T, R> T.let(block: (T) -> R): R {
    contract {
        callsInPlace(block, InvocationKind.EXACTLY_ONCE)
    }
    return block(this)
}
public inline fun <T, R> T.run(block: T.() -> R): R {
    contract {
        callsInPlace(block, InvocationKind.EXACTLY_ONCE)
    }
    return block()
}
```

1. let和run都是扩展函数
2. let的Lambda有参数，该参数就是T，也就是待扩展的那个对象，所以可以在Lambda内访问该参数，从而访问该参数对象的内部公开属性和函数
3. run的Lambda没有参数，但这个Lambda是待扩展的那个对象T的扩展，这是带接收者的函数类型，所以可以看做这个Lambda是T的成员函数，直接调用该Lambda就是相当于直接调用该T对象的成员函数，所以在该Lambda内部可以通过this来访问T的公开属性和函数（只能访问公开的，稍后解释是为什么）。
3. let和run都是返回的Lambda的执行结果

#### <span id="head5">3.2 also和apply</span>

```kotlin
//also和apply都是返回原对象本身，区别是apply没有Lambda参数，而also有
public inline fun <T> T.also(block: (T) -> Unit): T {
    contract {
        callsInPlace(block, InvocationKind.EXACTLY_ONCE)
    }
    block(this)
    return this
}
public inline fun <T> T.apply(block: T.() -> Unit): T {
    contract {
        callsInPlace(block, InvocationKind.EXACTLY_ONCE)
    }
    block()
    return this
}
```

1. also和apply都是扩展函数
2. also和apply都是返回原对象本身，区别是apply没有Lambda参数，而also有
3. also的Lambda有参数，该参数就是T，也就是待扩展的那个对象，所以可以在Lambda内访问该参数，从而访问该参数对象的内部公开属性和函数
4. apply的Lambda没有参数，但这个Lambda是待扩展的那个对象T的扩展，这是带接收者的函数类型，所以可以看做这个Lambda是T的成员函数，直接调用该Lambda就是相当于直接调用该T对象的成员函数，所以在该Lambda内部可以通过this来访问T的公开属性和函数（只能访问公开的，稍后解释是为什么）。

#### <span id="head6">3.3 repeat</span>

```repeat
public inline fun repeat(times: Int, action: (Int) -> Unit) {
    contract { callsInPlace(action) }

    for (index in 0 until times) {
        action(index)
    }
}
```

1. repeat是一个顶层函数
2. 该函数有2个参数，一个是重复次数，另一个是需执行的Lambda，Lambda带参数，该参数表示第几次执行
3. 函数内部非常简单，就是一个for循环，执行Lambda


#### <span id="head7">3.4 with</span>

```kotlin
public inline fun <T, R> with(receiver: T, block: T.() -> R): R {
    contract {
        callsInPlace(block, InvocationKind.EXACTLY_ONCE)
    }
    return receiver.block()
}
```

1. with是一个顶层函数
2. with有2个参数，一个是接收者，一个是带接收者的函数
3. with的返回值就是block函数的返回值
4. block是T的扩展，所以可以使用receiver对象直接调用block函数，而且block内部可以使用this来访问T的公开属性和函数

### <span id="head8">4.反编译</span>

了解一下这些作用域函数编译之后到底长什么样子,先看下demo

```kotlin
data class User(val name: String)

fun main() {

    val user = User("云天明")
    val letResult = user.let { param ->
        "let 输出点东西 ${param.name}"
    }
    println(letResult)
    val runResult = user.run {  //this:User
        "run 输出点东西 ${this.name}"
    }
    println(runResult)

    user.also { param ->
        println("also ${param.name}")
    }.apply { //this:User
        println("apply ${this.name}")
    }

    repeat(5) {
        println(user.name)
    }

    val withResult = with(user) { //this: User
        println("with ${this.name}")
        "with 输出点东西 ${this.name}"
    }
    println(withResult)
}
```

然后反编译看一下,data class的反编译咱就不看了，只关注main内部的代码

```kotlin
User user = new User("云天明");
System.out.println("let 输出点东西 " + user.getName());
System.out.println("run 输出点东西 " + user.getName());
User $this$test_u24lambda_u2d3 = user;
System.out.println("also " + $this$test_u24lambda_u2d3.getName());
System.out.println("apply " + $this$test_u24lambda_u2d3.getName());
for (int i = 0; i < 5; i++) {
    int i2 = i;
    System.out.println(user.getName());
}
User $this$test_u24lambda_u2d5 = user;
System.out.println("with " + $this$test_u24lambda_u2d5.getName());
System.out.println("with 输出点东西 " + $this$test_u24lambda_u2d5.getName());
```

可以看到，let、run、also、apply、repeat、with的Lambda内部执行的东西，全部放外面来了（因为inline），不用把Lambda转换成Function（匿名内部类啥的），这样执行起来性能会高很多。

额...我其实还想看一下`block: T.() -> R`这种编译出来是什么样子的，上面的那些作用域函数全部是inline的函数，看不出来了。我自己写一个看一下,自己写几个类似let、run、with的函数，但不带inline：

```kotlin
public fun <T, R> T.letMy(block: (T) -> R): R {
    return block(this)
}
public fun <T, R> T.runMy(block: T.() -> R): R {
    return block()
}
public fun <T, R> withMy(receiver: T, block: T.() -> R): R {
    return receiver.block()
}


fun test() {
    val user = User("云天明")
    val letResult = user.letMy { param ->
        "let 输出点东西 ${param.name}"
    }
    println(letResult)
    val runResult = user.runMy {  //this:User
        "run 输出点东西 ${this.name}"
    }
    println(runResult)

    val withResult = withMy(user) { //this: User
        println("with ${this.name}")
        "with 输出点东西 ${this.name}"
    }
    println(withResult)
}
```

反编译出来的样子：

```kotlin
final class TestKt$test$letResult$1 extends Lambda implements Function1<User, String> {
    public static final TestKt$test$letResult$1 INSTANCE = new TestKt$test$letResult$1();

    TestKt$test$letResult$1() {
        super(1);
    }

    public final String invoke(User param) {
        Intrinsics.checkNotNullParameter(param, "param");
        return "let 输出点东西 " + param.getName();
    }
}

final class TestKt$test$runResult$1 extends Lambda implements Function1<User, String> {
    public static final TestKt$test$runResult$1 INSTANCE = new TestKt$test$runResult$1();

    TestKt$test$runResult$1() {
        super(1);
    }

    public final String invoke(User $this$runMy) {
        Intrinsics.checkNotNullParameter($this$runMy, "$this$runMy");
        return "run 输出点东西 " + $this$runMy.getName();
    }
}

final class TestKt$test$withResult$1 extends Lambda implements Function1<User, String> {
    public static final TestKt$test$withResult$1 INSTANCE = new TestKt$test$withResult$1();

    TestKt$test$withResult$1() {
        super(1);
    }

    public final String invoke(User $this$withMy) {
        Intrinsics.checkNotNullParameter($this$withMy, "$this$withMy");
        System.out.println("with " + $this$withMy.getName());
        return "with 输出点东西 " + $this$withMy.getName();
    }
}

public final class TestKt {
    public static final <T, R> R letMy(T $this$letMy, Function1<? super T, ? extends R> block) {
        Intrinsics.checkNotNullParameter(block, "block");
        return block.invoke($this$letMy);
    }

    public static final <T, R> R runMy(T $this$runMy, Function1<? super T, ? extends R> block) {
        Intrinsics.checkNotNullParameter(block, "block");
        return block.invoke($this$runMy);
    }

    public static final <T, R> R withMy(T receiver, Function1<? super T, ? extends R> block) {
        Intrinsics.checkNotNullParameter(block, "block");
        return block.invoke(receiver);
    }

    public static final void test() {
        User user = new User("云天明");
        System.out.println((String) letMy(user, TestKt$test$letResult$1.INSTANCE));
        System.out.println((String) runMy(user, TestKt$test$runResult$1.INSTANCE));
        System.out.println((String) withMy(user, TestKt$test$withResult$1.INSTANCE));
    }
}
```

在我写的demo中letMy、runMy、withMy的Lambda都被编译成了匿名内部类，它们都继承自`kotlin.jvm.internal.Lambda`这个类，且都实现了`Function1<User, String>`接口。

```kotlin

abstract class Lambda<out R>(override val arity: Int) : FunctionBase<R>, Serializable {
    override fun toString(): String = Reflection.renderLambdaToString(this)
}

interface FunctionBase<out R> : Function<R> {
    val arity: Int
}

public interface Function<out R>

public interface Function1<in P1, out R> : Function<R> {
    public operator fun invoke(p1: P1): R
}
```

这里的Lambda是一个Kotlin内置的一个类，它就是一个Function，用来表示函数类型的值。而Function1则是继承自Function，它表示有一个参数的函数类型。除了Function1，Kotlin还内置了Function2、Function3、Function4等等，分别代表了2、3、4个参数的函数类型。就是这么简单粗暴。

回到上面的反编译代码中，我们发现letMy函数，传入user对象和`TestKt$test$letResult$1.INSTANCE`这个单例对象，并且在执行的时候，是用单例对象调用invoke函数，然后将user传进去的。在`TestKt$test$letResult$1#invoke`中，接收到了user对象，然后通过该对象访问其函数。可以看到，这里是用user对象去访问对象中的属性或者函数，那么肯定是只能访问到公开的属性和函数，这也就解答了上面的疑惑。

其他2个，runMy和withMy函数，竟然在编译之后和letMy长得一模一样。这意味着`block: (T) -> R`和`block: T.() -> R`是类似的，编译之后代码一模一样。都是将T对象传入invoke函数，然后在invoke函数内部进行操作T对象。



### <span id="head9">5.小结</span>

Kotlin作用域函数在日常编码中，使用频率极高，所以我们需要简单了解其基本原理，万一出了什么事方便找问题。理解作用域函数，得先理解函数类型，在Kotlin中函数也是有类型的，形如：`()->Unit`、`(Int,Int)->String`、`Int.(String)->String`等，它们可以被存储与变量中。let、run、apply、also都是扩展函数，with、repeat是顶层函数，它们都是inline修饰的函数，编译之后Lambda就没了，直接把Lambda内部的代码搬到了外边，提高了性能。

感谢大家的观看，希望本文能帮助大家更深地理解作用域函数。

课后小练习：

如果你觉得自己完全理解了本文，不妨拿出文本编辑器，把let、run、apply、also、with、repeat默写出来，可能会有更深地理解效果。