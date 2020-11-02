Future
---

- [<span id="head1"> Callable和Runnable的不同</span>](#-callable和runnable的不同)
  - [<span id="head2"> 为什么需要Callable?</span>](#-为什么需要callable)
  - [<span id="head3"> 为什么设计成这样?</span>](#-为什么设计成这样)
  - [<span id="head4"> Callable</span>](#-callable)
  - [<span id="head5"> Callable和Runnable的不同之处</span>](#-callable和runnable的不同之处)
- [<span id="head6"> Future的主要功能</span>](#-future的主要功能)
  - [<span id="head7"> Future作用</span>](#-future作用)
  - [<span id="head8"> Callable和Future的关系</span>](#-callable和future的关系)
  - [<span id="head9"> Future的方法和用法</span>](#-future的方法和用法)
    - [<span id="head10">get() 获取结果</span>](#get-获取结果)
    - [<span id="head11">isDone() 判断是否执行完毕</span>](#isdone-判断是否执行完毕)
    - [<span id="head12">cancel() 取消任务的执行</span>](#cancel-取消任务的执行)
    - [<span id="head13">isCancelled() 是否被取消</span>](#iscancelled-是否被取消)
  - [<span id="head14"> 用FutureTask来创建Future</span>](#-用futuretask来创建future)
- [<span id="head15"> Future注意点</span>](#-future注意点)
  - [<span id="head16"> 当for循环批量获取Future的结果时容易block,get方法调用时应使用timeout限制</span>](#-当for循环批量获取future的结果时容易blockget方法调用时应使用timeout限制)
  - [<span id="head17"> Future生命周期不能后退</span>](#-future生命周期不能后退)
  - [<span id="head18"> Future并没有产生新的线程</span>](#-future并没有产生新的线程)
- [<span id="head19"> 旅游平台问题</span>](#-旅游平台问题)
  - [<span id="head20"> CountDownLatch</span>](#-countdownlatch)
  - [<span id="head21"> CompletableFuture</span>](#-completablefuture)

### <span id="head1"> Callable和Runnable的不同</span>

比较它们之前先把定义拿出来:

```java
public interface Runnable {
    public abstract void run();
}
```

```java
public interface Callable<V> {
    V call() throws Exception;
}
```

#### <span id="head2"> 为什么需要Callable?</span>

**Runnable不能返回一个返回值**

虽然可以利用一些其他方法,比如在Runnable方法中写入日志文件,修改某个共享的对象或者Handler等方法,来达到保存线程执行结果的目的,但是这种解决问题的行为千曲百折,属于曲线救国,效率着实不高.

**Runnable不能抛出checkedException**

重写run方法之后,我们不能在这个run方法的方法签名上声明throws一个异常出来.

#### <span id="head3"> 为什么设计成这样?</span>

> 定义Runnable时,run方法没有声明抛出任何异常,返回值是void.

即使run方法可以返回返回值,或者可以抛异常,也无济于事,因为我们并没有办法在外层捕获并处理.因为调用run方法的类(比如Thread类和线程池)是Java直接提供的,不是我们编写的.

所以就算它有一个返回值,我们也很难把这个返回值利用到.要弥补这两个缺陷,可以用Callable.

#### <span id="head4"> Callable</span>

Callable类似Runnable,实现Callable的类和实现Runnable的类都是可以被其他线程执行的任务.

它的call方法声明了返回值,也已经声明了throws Exception,这和之前的Runnable有很大的区别.

#### <span id="head5"> Callable和Runnable的不同之处</span>

- **方法名: Callable规定的执行方法是call(),Runnable是run()**
- **返回值: Callable的任务执行后有返回值,Runnable没有**
- **抛出异常: call()方法可以抛异常,而run()不能抛出受检查异常**
- **和Callable配合的有一个Future类,通过Future可以了解任务的执行情况,或者取消任务的执行,还可获取任务执行的结果,这些功能都是Runnable做不到的,Callable的功能要比Runnable强大.**

### <span id="head6"> Future的主要功能</span>

#### <span id="head7"> Future作用</span>

比如当做一定运算的时候,运算过程比较耗时,有时会去查数据库,或是繁重的计算,比如压缩,加密等,在这种情况下,如果我们一直在原地等待方法返回,显然是不明智的,整体程序的运行效率会大大降低.我们可以把运算的过程放到子线程去执行,再通过Future去控制子线程执行的计算过程,最后获取计算结果.提高运行效率,是一种异步的思想.

#### <span id="head8"> Callable和Future的关系</span>

Callable的返回结果需要通过Future的get方法来获取.Future相当于一个存储器,存储了call方法的任务结果.除此之外,还可以通过Future的isDone方法来判断任务是否已经执行完毕了,还可以通过cancel方法取消这个任务,或限时获取任务结果等.

#### <span id="head9"> Future的方法和用法</span>

Future的定义如下,一共有5个方法:

```java
public interface Future<V> {
    boolean cancel(boolean mayInterruptIfRunning);
    boolean isCancelled();
    boolean isDone();
    
    V get() throws InterruptedException, ExecutionException;
    V get(long timeout, TimeUnit unit)
        throws InterruptedException, ExecutionException, TimeoutExceptio
}
```

##### <span id="head10">get() 获取结果</span>

主要是获取任务执行的结果,该方法在执行时的行为取决于Callable任务的状态.

- **最常见: 当执行get的时候,任务已经执行完毕了**.可以立刻返回,获取到任务执行的结果.
- **任务还没有结果**,可能任务还在线程池的队列中还没开始执行. 或者**任务正在执行中**,也是没有结果的. 无论任务还没开始,还是任务正在执行中,调用get的时候都会把当前的线程阻塞,直到任务完成再把结果返回.
- **任务执行过程中抛出异常**,一旦出现这种情况,我们再去调用get方法时,就会抛出ExecutionException异常,不管我们执行call方法时里面抛出的异常类型是什么,在执行get方法时所获得的异常都是ExecutionException.
- **任务被取消了**,如果任务已被取消,则调用get方法会抛出CancellationException
- **任务超时**,get有一个重载方法,带延迟参数的.调用这个带延迟参数的get方法后,如果在时间内完成任务会正常返回;如果到了指定时间还没完成任务,就会抛出TimeoutException,代表超时了.

```java

示例代码:

public class OneFuture {

    public static void main(String[] args) {
        ExecutorService service = Executors.newFixedThreadPool(10);
        Future<Integer> future = service.submit(new CallableTask());
        try {
            System.out.println(future.get());
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }
        service.shutdown();
    }

    static class CallableTask implements Callable<Integer> {
        @Override
        public Integer call() throws Exception {
            Thread.sleep(3000);
            return new Random().nextInt();
        }
    }

}
```

##### <span id="head11">isDone() 判断是否执行完毕</span>

需要注意的是,这个方法如果返回true则代表执行完成了.如果返回false则代表还没完成.但这里如果返回false,并不代表这个任务是成功执行的,比如说任务执行到一半抛出了异常.

##### <span id="head12">cancel() 取消任务的执行</span>

- 当任务还没开始执行时,调用cancel,任务会被正常取消,未来也不会执行,那么cancel方法返回true.
- 如果任务已经完成,或者之前已经被取消过,那么cancel方法就代表取消失败,返回false.
- 当任务正在执行,这时调用cancel方法是不会直接取消这个任务的,而是会根据传入的参数做判断.cancel方法必须传入一个参数mayInterruptIfRunning,如果是true则执行任务的线程就会收到一个中断的信号,正在执行的任务可能会有一些处理中断的逻辑,进而停止.如果是false,则就代表不中断正在运行的任务,本次cancel不会有任何效果,同时cancel方法返回false.

##### <span id="head13">isCancelled() 是否被取消</span>

#### <span id="head14"> 用FutureTask来创建Future</span>

除了用线程池的submit方法会返回一个Future对象之外,同样还可以用FutureTask来获取Future类和任务的结果.FutureTask首先是一个任务(Task),然后具有Future接口的语义,因为它可以在将来得到执行的结果.

```java
public class FutureTask<V> implements RunnableFuture<V>{
 ...
}

public interface RunnableFuture<V> extends Runnable, Future<V> {
    void run();
}
```
既然 RunnableFuture 继承了 Runnable 接口和 Future 接口,而 FutureTask 又实现了 RunnableFuture 接口,所以 FutureTask 既可以作为 Runnable 被线程执行,又可以作为 Future 得到 Callable 的返回值.典型用法是,把 Callable 实例当作 FutureTask 构造函数的参数,生成 FutureTask 的对象,然后把这个对象当作一个 Runnable 对象,放到线程池中或另起线程去执行,最后还可以通过 FutureTask 获取任务执行的结果.

```java
public class FutureTaskDemo {
    public static void main(String[] args) {
        Task task = new Task();
        FutureTask<Integer> integerFutureTask = new FutureTask<>(task);
        new Thread(integerFutureTask).start();
        try {
            System.out.println("task运行结果："+integerFutureTask.get());
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }
    }
}
class Task implements Callable<Integer> {
    @Override
    public Integer call() throws Exception {
        System.out.println("子线程正在计算");
        int sum = 0;
        for (int i = 0; i < 100; i++) {
            sum += i;
        }
        return sum;
    }
}
```

### <span id="head15"> Future注意点</span>

#### <span id="head16"> 当for循环批量获取Future的结果时容易block,get方法调用时应使用timeout限制</span>

#### <span id="head17"> Future生命周期不能后退</span>

一旦完成了任务,它就永久停在了已完成状态,不能从头再来.也不能让一个已经完成计算的Future再次执行任务.这一点和线程、线程池的状态是一样的,线程和线程池的状态也是不能后退的.

#### <span id="head18"> Future并没有产生新的线程</span>

其实 Callable 和 Future 本身并不能产生新的线程,它们需要借助其他的比如 Thread 类或者线程池才能执行任务.例如，在把 Callable 提交到线程池后,真正执行 Callable 的其实还是线程池中的线程,而线程池中的线程是由 ThreadFactory 产生的,这里产生的新线程与 Callable、Future 都没有关系,所以 Future 并没有产生新的线程.

### <span id="head19"> 旅游平台问题</span>

#### <span id="head20"> CountDownLatch</span>

```java
public class CountDownLatchDemo {
    ExecutorService threadPool = Executors.newFixedThreadPool(3);
    public static void main(String[] args) throws InterruptedException {
        CountDownLatchDemo countDownLatchDemo = new CountDownLatchDemo();
        System.out.println(countDownLatchDemo.getPrices());
    }
    private Set<Integer> getPrices() throws InterruptedException {
        Set<Integer> prices = Collections.synchronizedSet(new HashSet<Integer>());
        CountDownLatch countDownLatch = new CountDownLatch(3);
        threadPool.submit(new Task(123, prices, countDownLatch));
        threadPool.submit(new Task(456, prices, countDownLatch));
        threadPool.submit(new Task(789, prices, countDownLatch));
        countDownLatch.await(3, TimeUnit.SECONDS);
        return prices;
    }
    private class Task implements Runnable {
        Integer productId;
        Set<Integer> prices;
        CountDownLatch countDownLatch;
        public Task(Integer productId, Set<Integer> prices,
                CountDownLatch countDownLatch) {
            this.productId = productId;
            this.prices = prices;
            this.countDownLatch = countDownLatch;
        }
        @Override
        public void run() {
            int price = 0;
            try {
                Thread.sleep((long) (Math.random() * 4000));
                price = (int) (Math.random() * 4000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            prices.add(price);
            countDownLatch.countDown();
        }
    }
}
```

在执行 countDownLatch.await(3,
TimeUnit.SECONDS) 这个函数进行等待时,如果三个任务都非常快速地执行完毕了，那么三个线程都已经执行了 countDown 方法,那么这个 await 方法就会立刻返回,不需要傻等到 3 秒钟.即使比较慢,到达了3秒,也会超时,不再等待.

#### <span id="head21"> CompletableFuture</span>

```java
public class CompletableFutureDemo {
    public static void main(String[] args)
            throws Exception {
        CompletableFutureDemo completableFutureDemo = new CompletableFutureDemo();
        System.out.println(completableFutureDemo.getPrices());
    }
    private Set<Integer> getPrices() {
        Set<Integer> prices = Collections.synchronizedSet(new HashSet<Integer>());
        CompletableFuture<Void> task1 = CompletableFuture.runAsync(new Task(123, prices));
        CompletableFuture<Void> task2 = CompletableFuture.runAsync(new Task(456, prices));
        CompletableFuture<Void> task3 = CompletableFuture.runAsync(new Task(789, prices));
        CompletableFuture<Void> allTasks = CompletableFuture.allOf(task1, task2, task3);
        try {
            allTasks.get(3, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
        } catch (ExecutionException e) {
        } catch (TimeoutException e) {
        }
        return prices;
    }
    private class Task implements Runnable {
        Integer productId;
        Set<Integer> prices;
        public Task(Integer productId, Set<Integer> prices) {
            this.productId = productId;
            this.prices = prices;
        }
        @Override
        public void run() {
            int price = 0;
            try {
                Thread.sleep((long) (Math.random() * 4000));
                price = (int) (Math.random() * 4000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            prices.add(price);
        }
    }
}
```

如果在 3 秒钟之内这 3 个任务都可以顺利返回,也就是这个任务包括的那三个任务,每一个都执行完毕的话,则这个 get 方法就可以及时正常返回,并且往下执行,相当于执行到 return prices.如果超时则会收到TimeoutException,也能即使返回数据.

