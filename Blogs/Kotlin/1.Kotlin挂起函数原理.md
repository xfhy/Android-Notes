Kotlin挂起函数原理
---
#### 目录
- [一、序言](#head1)
- [二、CPS原理](#head2)
	- [CPS参数变化](#head3)
	- [CPS返回值变化](#head4)
- [三、挂起函数的反编译](#head5)
- [四、伪挂起函数](#head6)
- [五、多个挂起函数前后关联](#head7)
- [六、在Java中调用suspend函数](#head8)
- [七、小结](#head9)

---

### <span id="head1">一、序言</span>

Kotlin挂起函数平时在学习和工作中用的比较多，掌握其原理还是很有必要的。本文将一步一步带着大家分析其原理实现。

> ps: 文中所用的Kotlin版本是1.7.0。

### <span id="head2">二、CPS原理</span>

在某个Kotlin函数的前面加个suspend函数，它就成了挂起函数（虽然内部不一定会挂起，内部不挂起的称为伪挂起函数）。

先随便写个挂起函数

```kotlin
suspend fun getUserName(): String {
    delay(1000L)
    return "云天明"
}
```

然后通过Android Studio的Tools->Kotlin->Show Kotlin Bytecode->Decompile，现在我们拿到了Kotlin字节码反编译之后的Java代码：

```java
public static final Object getUserName(@NotNull Continuation var0) {
    ...
}
```

可以看到该函数被编译之后，多了一个Continuation参数，其次，返回值变成了Object。下面，我们详细来讨论一下这2种变化：函数参数和函数返回值。

#### <span id="head3">CPS参数变化</span>

上面的`suspend fun getUserName(): String`函数，如果我在Java中调用的话，会看到Android Studio提示我们

![Java中看到的suspend函数](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/Java中看到的suspend函数.png)

从图中可以看到，新增了一个参数，也就是Continuation，它其实是一个Callback，只是换了个名字而已。

来看下它的定义：

```kotlin
/**
 * Interface representing a continuation after a suspension point that returns a value of type `T`.
 */
@SinceKotlin("1.3")
public interface Continuation<in T> {
    /**
     * 当前continuation所在协程的上下文
     */
    public val context: CoroutineContext

    /**
     * 继续执行后面的协程代码，同时把结果回调出去，结果可能是成功或失败
     */
    public fun resumeWith(result: Result<T>)
}
```

这个Callback接口会在resumeWith回调结果给外部。

#### <span id="head4">CPS返回值变化</span>

在上面的Continuation接口的定义中，其实还有个小细节，它带了个泛型T。这个泛型T就是我们suspend函数返回值的类型，上面的getUserName返回值是String，编译之后，这个String就来到了Continuation的泛型中。

而getUserName编译之后的返回值变成了Object。为啥是Object？它有什么用？这个返回值其实是用来标识该函数是否挂起的标志，如果返回值是`Intrinsics.COROUTINE_SUSPENDED`，那么说明该函数被挂起了（挂起函数的结果不是通过函数返回值来获取的，而是通过Continuation，也就是Callback回调得到的结果）。如果该函数是伪挂起函数（里面没有其他挂起函数，但还是会进行CPS转换），则是直接返回结果。

举个例子，下面这个就是真正的挂起函数：

```kotlin
suspend fun getUserName(): String {
    delay(1000L)
    return "云天明"
}
```

当执行到delay的时候，就会返回`Intrinsics.COROUTINE_SUSPENDED`表示该函数被挂起了。

下面这个则是伪挂起函数：

```kotlin
suspend fun getName():String {
    return "dadad"
}
```

这种伪挂起函数不会返回`Intrinsics.COROUTINE_SUSPENDED`，而是直接返回结果，它不会被挂起。它看起来就仅仅是一个普通函数，但还是会进行CPS转换，CPS转换只认suspend关键字。你如果像上面这样写，其实Android Studio也会提示你，说这个suspend关键字没用，叫你把它移除掉。

所以，suspend函数编译之后的返回值变成了Object，因为要兼容伪挂起函数的返回值，而伪挂起函数可能返回任何值，而且还可能为空。

下面我们就来详细的探索一下挂起函数的底层原理，看看挂起函数反编译之后是什么样子。

### <span id="head5">三、挂起函数的反编译</span>

我们先写个很简单的suspend函数，然后将其反编译，然后分析一下。具体的流程是我们用Android Studio写个挂起函数的demo，然后编译成apk，然后将apk用jadx反编译一下，拿到对应class的反编译Java源码，这样弄出来的源码我感觉比直接通过Android Studio的`Tools->Kotlin->Show Kotlin`拿到的源码稍微好看懂一些。

首先，我创建了一个CpsTest.kt文件，然后在里面写了一个函数：

```kotlin
package com.xfhy.coroutine

import kotlinx.coroutines.delay

suspend fun getUserName(): String {
    delay(1000L)
    return "云天明"
}
```

就这样，一个很普通的挂起函数，在内部只是简单调用了下delay，延迟1000L，再返回结果“云天明”。虽然这个函数很简单，但反编译出来的代码却有点多，而且不好看懂，我先把原代码贴出来，待会儿再放我重新组织过的代码，作为对比：

```java
public final class CpsTestKt {
   @Nullable
   public static final Object getUserName(@NotNull Continuation var0) {
      Object $continuation;
      label20: {
         if (var0 instanceof <undefinedtype>) {
            $continuation = (<undefinedtype>)var0;
            if ((((<undefinedtype>)$continuation).label & Integer.MIN_VALUE) != 0) {
               ((<undefinedtype>)$continuation).label -= Integer.MIN_VALUE;
               break label20;
            }
         }

         $continuation = new ContinuationImpl(var0) {
            // $FF: synthetic field
            Object result;
            int label;

            @Nullable
            public final Object invokeSuspend(@NotNull Object $result) {
               this.result = $result;
               this.label |= Integer.MIN_VALUE;
               return CpsTestKt.getUserName(this);
            }
         };
      }

      Object $result = ((<undefinedtype>)$continuation).result;
      Object var3 = IntrinsicsKt.getCOROUTINE_SUSPENDED();
      switch(((<undefinedtype>)$continuation).label) {
      case 0:
         ResultKt.throwOnFailure($result);
         ((<undefinedtype>)$continuation).label = 1;
         if (DelayKt.delay(1000L, (Continuation)$continuation) == var3) {
            return var3;
         }
         break;
      case 1:
         ResultKt.throwOnFailure($result);
         break;
      default:
         throw new IllegalStateException("call to 'resume' before 'invoke' with coroutine");
      }

      return "云天明";
   }
}

```

这反编译之后的东西不太好看懂，我重新组织了一下：

```java
public final class CpsTestKt {

    public static final Object getUserName(Continuation<? super java.lang.String> continuation) {

        //这个TestContinuation实质上是一个匿名内部类，这里给它取个名字而已
        final class TestContinuation extends ContinuationImpl {
            //协程状态机当前的状态
            int label;
            //保存invokeSuspend回调时吐出来的返回结果
            Object result;

            TestContinuation(Continuation continuation) {
                super(continuation);
            }
            
            //invokeSuspend比较重要，它是状态机的入口，会将执行流程交给getUserName再次调用
            //协程的本质，就是CPS+状态机
            public final Object invokeSuspend(Object obj) {
                //callback回调时会把结果带出来
                this.result = obj;
                this.label |= Integer.MIN_VALUE;
                //开启协程状态机
                return CpsTestKt.getUserName(this);
            }
        }

        TestContinuation testContinuation;
        label20:
        {
            //不是第一次进入，则走这里，把continuation转成TestContinuation，TestContinuation只会生成一个实例，不会每次都生成。
            if (continuation instanceof TestContinuation) {
                testContinuation = (TestContinuation) continuation;
                if ((testContinuation.label & Integer.MIN_VALUE) != 0) {
                    testContinuation.label -= Integer.MIN_VALUE;
                    break label20;
                }
            }

            //如果是第一次进入getUserName，则TestContinuation还没被创建，会走到这里，此时先去创建一个TestContinuation
            testContinuation = new TestContinuation(continuation);
        }

        //将之前执行的结果取出来
        Object $result = testContinuation.result;
        //挂起的标志,如果需要挂起的话,就返回这个flag
        Object flag = IntrinsicsKt.getCOROUTINE_SUSPENDED();
        
        //状态机
        switch (testContinuation.label) {
            case 0:
                // 检测异常
                ResultKt.throwOnFailure($result);
                //将label的状态改成1,方便待会儿执行delay后面的代码
                testContinuation.label = 1;
                //0. 调用DelayKt.delay函数
                //1. 将testContinuation传了进去
                //2. DelayKt.delay是一个挂起函数，正常情况下，它会立马返回一个值：IntrinsicsKt.COROUTINE_SUSPENDED（也就是这里的flag），表示该函数已被挂起，这里就直接return了，该函数被挂起
                //3. 恢复执行：在DelayKt.delay内部，到了指定的时间后就会调用testContinuation这个Callback的invokeSuspend
                //4. invokeSuspend中又将执行getUserName函数，同时将之前创建好的testContinuation传入其中，开始执行后面的逻辑(label为1的逻辑)，该函数继续往后面执行(也就是恢复执行)
                if (DelayKt.delay(1000L, testContinuation) == flag) {
                    return flag;
                }
                break;
            case 1:
                // 检测异常
                ResultKt.throwOnFailure($result);
                //label 1这里没有return,而是会走到下面的return "云天明"语句
                break;
            default:
                throw new IllegalStateException("call to 'resume' before 'invoke' with coroutine");
        }

        return "云天明";
    }
}
```

在getUserName函数中，会多出一个ContinuationImpl的子类，它是一个匿名内部类（为了方便，给它取了个名字TestContinuation），也是整个协程挂起函数的核心。在这个TestContinuation中有2个变量

- label: 协程状态机当前的状态
- result: 保存invokeSuspend回调时吐出来的返回结果

invokeSuspend是一个抽象方法，当协程从挂起状态想要恢复时，就得调用这个invokeSuspend，然后继续走状态机逻辑，继续执行后面的代码。具体是怎么调用这个invokeSuspend的，后面有机会再细说。暂时我们只要知道，这里是恢复的入口就行。invokeSuspend内部会把结果（这个结果可能是正常的结果，也可能是Exception）取出来，开启协程状态机。

分析完TestContinuation，再来看一下第一次进入getUserName是怎么走的。首先，第一次进入时，continuation肯定不是TestContinuation，因为此时还没有new过TestContinuation实例，所以会走到创建TestContinuation的逻辑，并且会把continuation包进去。然后刚创建完的testContinuation的label未赋其他值，那就是初始值0了。那么switch状态机那里，就走case 0，先把label改成1，因为马上就要挂起了，待会儿恢复时需要执行下一个状态的代码。调用Kotlin的库函数delay，它是一个挂起函数，将testContinuation传入其中，方便它进行invokeSuspend回调。调用挂起函数，那么它可能会返回`COROUTINE_SUSPENDED`，表示它已经被挂起了，如果是挂起了那么getUserName就走完了，到时会从invokeSuspend恢复。在还没有恢复的时候，这个协程所在的线程可以去做其他事情。

恢复的时候，又开始从头走getUserName，此时的continuation已经是TestContinuation，不会重新创建。它的label之前已经被改成1了的，所以switch状态机那里，会走到case 1，先检测一下有没有异常，没有异常就返回真正的返回值了“云天明”。

分析到这里也就完了，上面就是一个非常简单的挂起函数的反编译分析的整个过程。下面我们简单分析一下伪挂起函数会带来什么效果。

### <span id="head6">四、伪挂起函数</span>

在之前的CpsTest.kt里面简单改一下

```kotlin
suspend fun fakeSuspendFun() = "维德"

suspend fun getUserName(): String {
    println(fakeSuspendFun())
    return "云天明"
}
```

像fakeSuspendFun这种就是伪挂起函数，平时不建议像fakeSuspendFun这么写，即使写了，Android Studio也会提示你，这suspend关键字没用，内部没有挂起。它内部没有挂起的逻辑，但是它有suspend关键字，那么Kotlin编译器依然会给它做CPS转换。

```java
public final class CpsTestKt {
   @Nullable
   public static final Object fakeSuspendFun(@NotNull Continuation<? super java.lang.String> $completion) {
      return "维德";
   }

   @Nullable
   public static final Object getUserName(@NotNull Continuation<? super java.lang.String> continuation) {

    final class TestContinuation extends ContinuationImpl {
        int label;
        Object result;

        TestContinuation(Continuation continuation) {
            super(continuation);
        }
        
        public final Object invokeSuspend(Object obj) {
            this.result = obj;
            this.label |= Integer.MIN_VALUE;
            return CpsTestKt.getUserName(this);
        }
    }

    TestContinuation testContinuation;
    label20:
    {
        if (continuation instanceof TestContinuation) {
            testContinuation = (TestContinuation) continuation;
            if ((testContinuation.label & Integer.MIN_VALUE) != 0) {
                testContinuation.label -= Integer.MIN_VALUE;
                break label20;
            }
        }

        testContinuation = new TestContinuation(continuation);
    }

      Object $result = testContinuation.result;
      Object flag = IntrinsicsKt.getCOROUTINE_SUSPENDED();
      //变化在这里，这个变量用来存储fakeSuspendFun的返回值
      Object var10000;
      switch(testContinuation.label) {
      case 0:
         ResultKt.throwOnFailure($result);
         testContinuation.label = 1;
         var10000 = fakeSuspendFun((Continuation)$continuation);
         if (var10000 == flag) {
            //如果是挂起，那么直接返回COROUTINE_SUSPENDED
            return flag;
         }
         //显然，这里是不会挂起的，会走这里的break
         break;
      case 1:
         ResultKt.throwOnFailure($result);
         var10000 = $result;
         break;
      default:
         throw new IllegalStateException("call to 'resume' before 'invoke' with coroutine");
      }

      //走这里
      Object var1 = var10000;
      System.out.println(var1);
      return "云天明";
   }
}
```

在调用伪挂起函数时，不会挂起，它不会返回`COROUTINE_SUSPENDED`，而是继续往下走。

### <span id="head7">五、多个挂起函数前后关联</span>

平时在工作中，可能经常会有多个挂起函数前后是关联的,后面一个挂起函数需要前面一个挂起函数的结果来干点事情，比上面只有一个getUserName挂起函数稍微复杂些，我们来分析一下。

比如我们拿到一个需求，展示我的朋友圈，假设获取流程如下：获取用户id->根据用户id获取该用户的好友列表->获取好友列表每个人的朋友圈。下面是非常简单的实现：

```kotlin
//需求: 获取用户id->根据用户id获取该用户的好友列表->获取好友列表每个人的朋友圈
suspend fun showMoments() {
    println("start")
    val userId = getUserId()
    println(userId)
    val friendList = getFriendList(userId)
    println(friendList)
    val feedList = getFeedList(userId, friendList)
    println(feedList)
}

suspend fun getUserId(): String {
    delay(1000L)
    return "1sa13124daadar2"
}

suspend fun getFriendList(userId: String): String {
    println("正在获取${userId}的朋友列表")
    delay(1000L)
    return "云天明, 维德"
}

suspend fun getFeedList(userId: String, list: String): String {
    println("获取${userId}的朋友圈($list)")
    delay(1000L)
    return "云天明: 酒好喝吗？烟好抽吗？即使是可口可乐，第一次尝也不好喝，让人上瘾的东西都是这样;\n维德: 前进！前进！！不择手段地前进！！！"
}
```

它的执行结果如下：

```log
start
1sa13124daadar2
正在获取1sa13124daadar2的朋友列表
云天明, 维德
获取1sa13124daadar2的朋友圈(云天明, 维德)
云天明: 酒好喝吗？烟好抽吗？即使是可口可乐，第一次尝也不好喝，让人上瘾的东西都是这样;
维德: 前进！前进！！不择手段地前进！！！
end
```

这段代码要稍微复杂一些，这些挂起函数前后关联，前面获取到的数据后面的挂起函数需要使用到。相应的，它们反编译之后也要复杂一些。但是没关系，我已经把晦涩难懂的代码重新组装了一下，方便大家阅读。同时，在下面的代码中，每一步在走哪个分支，都有详细的注释分析，帮助大家理解。

```java
public final class TestSuspendKt {
   @Nullable
   public static final Object showMoments(@NotNull Continuation<? super Unit> continuation) {
      
      ShowMomentsContinuation showMomentsContinuation;
      label37: {
         if (continuation instanceof ShowMomentsContinuation) {
            //非第一次进showMoments，则走这里，continuation已经是ShowMomentsContinuation了
            showMomentsContinuation = (ShowMomentsContinuation)continuation;
            if ((showMomentsContinuation.label & Integer.MIN_VALUE) != 0) {
               showMomentsContinuation.label -= Integer.MIN_VALUE;
               break label37;
            }
         }

         //第一次，走这里，初始化ShowMomentsContinuation，将传入的continuation包起来
         showMomentsContinuation = new ShowMomentsContinuation(continuation);

         final class ShowMomentsContinuation extends ContinuationImpl {
            int label;
            Object result;
            //存放临时数据
            Object tempData;
    
            ShowMomentsContinuation(Continuation continuation) {
                super(continuation);
            }
            
            public final Object invokeSuspend(Object obj) {
                this.result = obj;
                this.label |= Integer.MIN_VALUE;
                return CpsTestKt.getUserName(this);
            }
        }

      }

      //存放每个函数的返回结果，临时放一下
      Object computeResult;
      
      label31: {
         String userId;
         Object flag;
         label30: {
            //从continuation中把result取出来
            Object $result = showMomentsContinuation.result;
            flag = IntrinsicsKt.getCOROUTINE_SUSPENDED();
            switch(showMomentsContinuation.label) {
            case 0:
               //第一次，走这里，检测异常
               ResultKt.throwOnFailure($result);
               System.out.println("start");
               //将label改成1
               showMomentsContinuation.label = 1;
               //执行getUserId函数，computeResult用来接收返回值
               computeResult = getUserId((Continuation)showMomentsContinuation);
               //getUserId是挂起函数，不出意外的话，computeResult的值会是COROUTINE_SUSPENDED，这里就直接return了
               //showMoments函数这一次执行，就算完成了。
               //恢复执行时，会走ShowMomentsContinuation 的invokeSuspend，走下面label等于1的逻辑
               if (computeResult == flag) {
                  return flag;
               }
               break;
            case 1:
               //第二次执行showMoments时，label已经等于1了，走这里. 
               ResultKt.throwOnFailure($result);
               computeResult = $result;
               break;
            case 2:
               //第三次执行showMoments时，label已经等于2了，走这里. 
               //先将之前暂存的userId取出来，马上需要用到
               userId = (String)showMomentsContinuation.tempData;
               ResultKt.throwOnFailure($result);
               computeResult = $result;
               break label30;
            case 3:
               //第四次执行showMoments时，label已经等于3了，走这里. 
               ResultKt.throwOnFailure($result);
               computeResult = $result;
               break label31;
            default:
               throw new IllegalStateException("call to 'resume' before 'invoke' with coroutine");
            }

            //第二次执行showMoments时，label=1，会走到这里来,将getUserId函数回调回来的userId保存起来，并输出
            userId = (String)computeResult;
            System.out.println(userId);
            //将userId放continuation里面暂存起来
            showMomentsContinuation.tempData = userId;
            //又要执行挂起函数了，这里将label改成2
            showMomentsContinuation.label = 2;
            //开始调用getFriendList
            computeResult = getFriendList(userId, (Continuation)showMomentsContinuation);

            //getFriendList是挂起函数，不出意外的话，computeResult的值会是COROUTINE_SUSPENDED，这里就直接return了
            //showMoments函数这一次执行，就算完成了。
            //恢复执行时，会走ShowMomentsContinuation 的invokeSuspend，走上面label等于2的逻辑
            if (computeResult == flag) {
               return flag;
            }
         }

         //第三次执行showMoments时，label=2，会走到这里来,将getFriendList函数回调回来的friendList输出
         String friendList = (String)computeResult;
         System.out.println(friendList);
         showMomentsContinuation.tempData = null;
         //又要执行挂起函数了，这里将label改成3
         showMomentsContinuation.label = 3;
         //开始调用getFeedList
         computeResult = getFeedList(userId, friendList, (Continuation)showMomentsContinuation);

         //getFeedList是挂起函数，不出意外的话，computeResult的值会是COROUTINE_SUSPENDED，这里就直接return了
         //showMoments函数这一次执行，就算完成了。
         //恢复执行时，会走ShowMomentsContinuation 的invokeSuspend，走上面label等于3的逻辑
         if (computeResult == flag) {
            return flag;
         }
      }
      
      //第四次执行showMoments时，label=3，会走到这里来,将getFeedList函数回调回来的feedList输出
      String feedList = (String)computeResult;
      System.out.println(feedList);
      System.out.println("end");

      //showMoments函数这一次执行，就算完成了。
      //没有剩下的挂起函数需要执行了
      return Unit.INSTANCE;
   }

    //因为getUserId、getFriendList、getFeedList中的匿名内部类逻辑与showMoments中的一模一样，故没有将其重新组织语言

   @Nullable
   public static final Object getUserId(@NotNull Continuation var0) {
      Object $continuation;
      label20: {
        //这里的<undefinedtype>就是在getUserId函数里生成的new ContinuationImpl匿名内部类
         if (var0 instanceof <undefinedtype>) {
            $continuation = (<undefinedtype>)var0;
            if ((((<undefinedtype>)$continuation).label & Integer.MIN_VALUE) != 0) {
               ((<undefinedtype>)$continuation).label -= Integer.MIN_VALUE;
               break label20;
            }
         }

         $continuation = new ContinuationImpl(var0) {
            // $FF: synthetic field
            Object result;
            int label;

            @Nullable
            public final Object invokeSuspend(@NotNull Object $result) {
               this.result = $result;
               this.label |= Integer.MIN_VALUE;
               return TestSuspendKt.getUserId(this);
            }
         };
      }

      Object $result = ((<undefinedtype>)$continuation).result;
      Object var3 = IntrinsicsKt.getCOROUTINE_SUSPENDED();
      switch(((<undefinedtype>)$continuation).label) {
      case 0:
         //第一次执行getUserId时，走这里
         ResultKt.throwOnFailure($result);
         //马上要开始执行挂起函数了，label先改一下
         ((<undefinedtype>)$continuation).label = 1;
         //执行delay，正常情况下，会返回COROUTINE_SUSPENDED，于是getUserId这一次就执行完了，return了
         //恢复时会回调上面的匿名内部类$continuation中的invokeSuspend
         if (DelayKt.delay(1000L, (Continuation)$continuation) == var3) {
            return var3;
         }
         break;
      case 1:
         //第二次执行getUserId时，也就是delay执行完回来，走这里
         ResultKt.throwOnFailure($result);
         break;
      default:
         throw new IllegalStateException("call to 'resume' before 'invoke' with coroutine");
      }

      //拿到数据，getUserId就算真正的执行完了，接着会去执行showMoments函数中的ShowMomentsContinuation#invokeSuspend，也就是恢复showMoments,继续执行showMoments中getUserId后面的逻辑
      return "1sa13124daadar2";
   }

   @Nullable
   public static final Object getFriendList(@NotNull String userId, @NotNull Continuation var1) {
      Object $continuation;
      label20: {
         if (var1 instanceof <undefinedtype>) {
            $continuation = (<undefinedtype>)var1;
            if ((((<undefinedtype>)$continuation).label & Integer.MIN_VALUE) != 0) {
               ((<undefinedtype>)$continuation).label -= Integer.MIN_VALUE;
               break label20;
            }
         }

         $continuation = new ContinuationImpl(var1) {
            // $FF: synthetic field
            Object result;
            int label;

            @Nullable
            public final Object invokeSuspend(@NotNull Object $result) {
               this.result = $result;
               this.label |= Integer.MIN_VALUE;
               return TestSuspendKt.getFriendList((String)null, this);
            }
         };
      }

      Object $result = ((<undefinedtype>)$continuation).result;
      Object var5 = IntrinsicsKt.getCOROUTINE_SUSPENDED();
      switch(((<undefinedtype>)$continuation).label) {
      case 0:
         ResultKt.throwOnFailure($result);
         String var2 = "正在获取" + userId + "的朋友列表";
         System.out.println(var2);
         ((<undefinedtype>)$continuation).label = 1;
         if (DelayKt.delay(1000L, (Continuation)$continuation) == var5) {
            return var5;
         }
         break;
      case 1:
         ResultKt.throwOnFailure($result);
         break;
      default:
         throw new IllegalStateException("call to 'resume' before 'invoke' with coroutine");
      }

      return "云天明, 维德";
   }

   @Nullable
   public static final Object getFeedList(@NotNull String userId, @NotNull String list, @NotNull Continuation var2) {
      Object $continuation;
      label20: {
         if (var2 instanceof <undefinedtype>) {
            $continuation = (<undefinedtype>)var2;
            if ((((<undefinedtype>)$continuation).label & Integer.MIN_VALUE) != 0) {
               ((<undefinedtype>)$continuation).label -= Integer.MIN_VALUE;
               break label20;
            }
         }

         $continuation = new ContinuationImpl(var2) {
            // $FF: synthetic field
            Object result;
            int label;

            @Nullable
            public final Object invokeSuspend(@NotNull Object $result) {
               this.result = $result;
               this.label |= Integer.MIN_VALUE;
               return TestSuspendKt.getFeedList((String)null, (String)null, this);
            }
         };
      }

      Object $result = ((<undefinedtype>)$continuation).result;
      Object var6 = IntrinsicsKt.getCOROUTINE_SUSPENDED();
      switch(((<undefinedtype>)$continuation).label) {
      case 0:
         ResultKt.throwOnFailure($result);
         String var3 = "获取" + userId + "的朋友圈(" + list + ')';
         System.out.println(var3);
         ((<undefinedtype>)$continuation).label = 1;
         if (DelayKt.delay(1000L, (Continuation)$continuation) == var6) {
            return var6;
         }
         break;
      case 1:
         ResultKt.throwOnFailure($result);
         break;
      default:
         throw new IllegalStateException("call to 'resume' before 'invoke' with coroutine");
      }

      return "云天明: 酒好喝吗？烟好抽吗？即使是可口可乐，第一次尝也不好喝，让人上瘾的东西都是这样;\n维德: 前进！前进！！不择手段地前进！！！";
   }
}
```

观察源码，发现一些东西：

- 每个挂起函数都有一个匿名内部类，继承ContinuationImpl，在invokeSuspend中开启状态机
- 每个挂起函数都经过了CPS转换
- 在挂起之后，当前执行协程的这个线程其实是空闲的，没有代码交给它执行。在invokeSuspend恢复之后，才继续执行
- 每个挂起函数，都有一个状态机
- 挂起函数中的逻辑被分块执行（也就是状态机那块的逻辑），分块的数量=挂起函数数量+1

基本上来说，挂起函数的实现原理就是上面这些了。

### <span id="head8">六、在Java中调用suspend函数</span>

既然Kotlin是兼容Java的，那么如果我想在Java里面调用Kotlin的suspend函数按道理也是可以的。那具体如何调用呢？

就拿上面的案例举例，假设我想在Activity中点击某个按钮时调用showMoments这个suspend函数，该怎么搞？大家先思考一下，稍后给出答案。

```kotlin
//将上面的案例加了个返回值
suspend fun showMoments(): String {
    println("start")
    val userId = getUserId()
    println(userId)
    val friendList = getFriendList(userId)
    println(friendList)
    val feedList = getFeedList(userId, friendList)
    println(feedList)
    println("end")

    return feedList
}
```

因为showMoments函数有suspend关键字，那么最终会经过CPS转换，有一个Continuation参数。在Java中调用showMoments时，肯定需要把Continuation传进去才行。Continuation是一个接口，需要传个实现类过去，把getContext和resumeWith实现起。

```kotlin
TestSuspendKt.showMoments(new Continuation<String>() {
    @NonNull
    @Override
    public CoroutineContext getContext() {
        return (CoroutineContext) Dispatchers.getIO();
    }

    @Override
    public void resumeWith(@NonNull Object result) {
        //这里的result就是showMoments的返回值
        Log.d("xfhy666", "" + result);
    }
});
```

Java中调用挂起函数，看起来就像是调用了一个方法，这个方法需要传一个callback过去，这个方法的返回值是通过回调给出来的，并且可以自定义该方法运行在哪个线程中。

### <span id="head9">七、小结</span>

好了，今天的Kotlin挂起函数就分析到这里，基本上谜团已全部解开(除了invokeSuspend是在什么时候回调的，后面有机会再和大家分享)。

Kotlin的挂起函数，本质上就是：CPS+状态机。

- CPS：挂起函数比普通函数多了suspend关键字，Kotlin编译器会对其特殊处理。将该函数转换成一个带有Callback的函数，Callback就是Continuation接口，它的泛型就是原来函数的返回值类型。转换之后的返回值类型是`Any?`，因为加了suspend关键字的不一定会被挂起，挂起的话返回`Intrinsics.COROUTINE_SUSPENDED`，伪挂起函数（里面没有其他挂起函数，但还是会进行CPS转换）则是直接返回结果，这个结果可以是任何类型，所以返回值只能是`Any?`。
- 状态机：当挂起函数经过编译之后，会变成switch和label组成的状态机结构。label代表了当前状态机的具体状态，每改变一次，就代表挂起函数被调用一次。在里面会创建一个Callback接口，当挂起之后，挂起函数的结果返回是通过Callback回调回来的，回调回来之后，因为之前修改过label，根据该label来判断该继续往下走了，执行后面的逻辑。上面的Callback就是Continuation，我觉得它在这里的意思可以翻译成继续执行剩余的代码。
