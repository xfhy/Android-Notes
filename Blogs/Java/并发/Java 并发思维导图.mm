
<map>
  <node ID="root" TEXT="Java 并发">
    <node TEXT="线程基础" ID="aXXQeoAj5z" STYLE="bubble" POSITION="default">
      <node TEXT="实现多线程" ID="fGrdWHLDNP" STYLE="fork">
        <node TEXT="实现Runnable" ID="qGMK5uO4tn" STYLE="fork"/>
        <node TEXT="继承Thread" ID="5UqxjPUM4G" STYLE="fork"/>
        <node TEXT="线程池" ID="sc6l7A2QSh" STYLE="fork"/>
        <node TEXT="有返回值的Callable" ID="36eGQ2o7Tp" STYLE="fork"/>
      </node>
      <node TEXT="启动线程" ID="mtPaK2e0bl" STYLE="fork">
        <node TEXT="start()" ID="xj9PYbzEPr" STYLE="fork"/>
      </node>
      <node TEXT="停止线程" ID="bKZJwdLRlP" STYLE="fork">
        <node TEXT="interrupt() 正确停止线程的方法,不强制停止,而是通知协作." ID="hCA09X8ZHI" STYLE="fork"/>
      </node>
      <node TEXT="线程的6种状态" ID="HvELwjpMFk" STYLE="fork">
        <node TEXT="New 新创建" ID="nMbNDLj70o" STYLE="fork"/>
        <node TEXT="Runnable 可运行" ID="ZJNLcJdHSg" STYLE="fork"/>
        <node TEXT="Blocked 被阻塞" ID="6fnuGoRDiC" STYLE="fork"/>
        <node TEXT="Waiting 等待" ID="ZIg3wqMb3n" STYLE="fork"/>
        <node TEXT="Timed Waiting 计时等待" ID="eporpNy4JP" STYLE="fork"/>
        <node TEXT="Terminated 被终止" ID="G9QhDENfza" STYLE="fork"/>
      </node>
      <node TEXT="wait/notify/sleep/join等重要方法" ID="qwG4KrGPMo" STYLE="fork">
        <node TEXT="wait 阻塞" ID="fYyWFZyFUN" STYLE="fork"/>
        <node TEXT="notify 释放" ID="xd08vaizFf" STYLE="fork"/>
        <node TEXT="sleep 睡眠" ID="eFL6rjaQ9K" STYLE="fork"/>
        <node TEXT="join 线程没执行完之前,会一直阻塞在join方法处 " ID="YQKkT8P6Sc" STYLE="fork"/>
      </node>
      <node TEXT="守护线程,优先级等属性" ID="ZDx4gfS8gv" STYLE="fork">
        <node TEXT="守护线程: 低优先级的线程,唯一作用是为用户线程提供服务,它不会阻止JVM退出" ID="WY6bVQpuz6" STYLE="fork"/>
        <node TEXT="优先级: 有时间片轮询机制,高优先级线程被分配CPU的概率高于低优先级线程;无时间片轮询机制,高优先级线程优先执行 " ID="XsE49dOwBk" STYLE="fork"/>
      </node>
      <node TEXT="线程安全" ID="Xo8Ny0Xxj4" STYLE="fork">
        <node TEXT="运行结果错误" ID="MDdHso7ZhR" STYLE="fork"/>
        <node TEXT="死锁等活跃性问题" ID="oAsx4QheWs" STYLE="fork"/>
        <node TEXT="对象发布和初始化" ID="ZYwCx3PMVR" STYLE="fork"/>
      </node>
    </node>
    <node TEXT="为了线程安全" ID="QZSQ5v5atb" STYLE="bubble" POSITION="default">
      <node TEXT="各种各样的锁" ID="j2t4rtLPTK" STYLE="fork">
        <node TEXT="悲观锁和乐观锁" ID="u851w7Dm6o" STYLE="fork">
          <node TEXT="悲观锁" ID="5PQmFPmGiB" STYLE="fork">
            <node TEXT="概念: 在获取资源之前,必须先拿到锁,以便达到独占的状态,当前线程在操作资源的时候,其他线程由于不能拿到锁,所以其他线程不能来影响我" ID="wWE54Gvncg" STYLE="fork"/>
            <node TEXT="典型: synchronized关键字和Lock接口" ID="MpXyGIAfSX" STYLE="fork"/>
            <node TEXT="使用场景: 并发写入多、临界区代码复杂、竞争激烈等场景,这种场景下悲观锁可以避免大量的无用的反复尝试等消耗" ID="GxpBnGgmz0" STYLE="fork"/>
          </node>
          <node TEXT="乐观锁" ID="i2vQo51uYC" STYLE="fork">
            <node TEXT="概念: 它并不要求在获取资源前拿到锁,也不会锁住资源,每次拿数据的时候都认为别的线程不会修改数据,但是在更新的时候会判断一下再次期间别的线程有没有修改过数据." ID="Sr9z2kLCue" STYLE="fork"/>
            <node TEXT="典型: 原子类" ID="10QppTxVkV" STYLE="fork"/>
            <node TEXT="使用场景: 适用于大部分是读取,少部分是修改的场景,也适用于虽然读写很多,但是并发并不激烈的场景.在这些场景下,乐观锁不加锁的特点能让性能大幅提高" ID="5qlUUD2g6v" STYLE="fork"/>
          </node>
        </node>
        <node TEXT="共享锁和独占锁" ID="rXTYtNgng6" STYLE="fork">
          <node TEXT="共享锁" ID="npr2Xw583h" STYLE="fork"/>
          <node TEXT="独占锁" ID="7EkWIIeIMo" STYLE="fork"/>
        </node>
        <node TEXT="公平锁和非公平锁" ID="0TgErR2jwo" STYLE="fork">
          <node TEXT="公平锁" ID="VdRn9Ed8n2" STYLE="fork"/>
          <node TEXT="非公平锁" ID="YtQsFkS6cS" STYLE="fork"/>
        </node>
        <node TEXT="可重入锁和非可重入锁" ID="Nj0kwqgmFF" STYLE="fork">
          <node TEXT="可重入锁" ID="bbtEnmRkAy" STYLE="fork"/>
          <node TEXT="非可重入锁" ID="4BhaEo3ZrB" STYLE="fork"/>
        </node>
        <node TEXT="可中断锁和非可中断锁" ID="jEDEEt5NFd" STYLE="fork">
          <node TEXT="可中断锁" ID="k2w2REgLys" STYLE="fork"/>
          <node TEXT="不可中断锁" ID="KFEuJ09gHx" STYLE="fork"/>
        </node>
        <node TEXT="自旋锁和非自旋锁" ID="nlknegaBJK" STYLE="fork">
          <node TEXT="自旋锁" ID="fQjwfBb1Wn" STYLE="fork"/>
          <node TEXT="非自旋锁" ID="IlMuhQ7iwV" STYLE="fork"/>
        </node>
        <node TEXT="偏斜锁/轻量级锁/重量级锁" ID="497nnv8Ecc" STYLE="fork">
          <node TEXT="偏斜锁" ID="7l64bDL64i" STYLE="fork"/>
          <node TEXT="轻量级锁" ID="dux5CKCXwY" STYLE="fork"/>
          <node TEXT="重量级锁" ID="9Wg74dxNi2" STYLE="fork"/>
        </node>
        <node TEXT="JVM对synchronized锁的优化" ID="fxKV47r9Hd" STYLE="fork">
          <node TEXT="锁的升级: 无锁-&gt;偏向锁-&gt;轻量级锁-&gt;重量级锁" ID="Mcbk2XquN0" STYLE="fork"/>
          <node TEXT="锁消除: 虚拟机编译时,对一些代码上使用synchronized同步,但是被检测到不可能存在共享数据竞争的锁进行消除" ID="5EVHMf3Rxp" STYLE="fork"/>
          <node TEXT="锁粗化: 把不间断、高频锁的请求合并成一个请求,以降低短时间内大量锁请求、同步、释放带来的性能损耗" ID="KFEwq9xgfw" STYLE="fork"/>
        </node>
      </node>
      <node TEXT="并发容器" ID="fky7BKjfJi" STYLE="fork">
        <node TEXT="Vector/Hashtable" ID="TV6GCxuba9" STYLE="fork">
          <node TEXT="内部使用synchronized方法级别的锁保证线程安全,锁的粒度比较大" ID="Pw55QQdJsI" STYLE="fork"/>
          <node TEXT="在并发量高的时候很容易发生竞争,并发效率比较低" ID="gkSF2TYgqe" STYLE="fork"/>
        </node>
        <node TEXT="ConcurrentHashMap" ID="TleiCbRoSj" STYLE="fork">
          <node TEXT="数据结构" ID="vyLERDkXtw" STYLE="fork">
            <node TEXT="Java7采用普通的数组+链表,而Java 8中使用数组+链表+红黑树" ID="GwElm2KJ0s" STYLE="fork"/>
          </node>
          <node TEXT="并发度" ID="flQmnhmgUS" STYLE="fork">
            <node TEXT="Java7中,每个Segment独立加锁,最大并发个数就是Segment的个数,默认是16" ID="FEfTPsmidt" STYLE="fork"/>
            <node TEXT="Java8中,锁粒度更细,理想情况下是table数组元素的个数(数组长度)就是其支持并发的最大个数,并发度比之前有提高" ID="Fb0cYu7gdh" STYLE="fork"/>
          </node>
          <node TEXT="保证并发安全的原理" ID="QAUiiA0BwA" STYLE="fork">
            <node TEXT="Java7采用Segment分段锁来保证安全,而Segment是继承自ReentrantLock" ID="MAwDQtG1gz" STYLE="fork"/>
            <node TEXT="Java8中放弃了Segment设计,采用Node+CAS+synchronized保证线程安全" ID="uUVMEdEjzw" STYLE="fork"/>
          </node>
          <node TEXT="遇到Hash碰撞" ID="tCZKrpUoqL" STYLE="fork">
            <node TEXT="Java7在Hash冲突时,使用拉链法(链表的形式)" ID="Qe3dAjdJ0z" STYLE="fork"/>
            <node TEXT="Java8中优先使用拉链法,在链表长度超过一定阈值时,将链表转换为红黑树,来提供查找效率" ID="HccZ8edfWP" STYLE="fork"/>
          </node>
          <node TEXT="查找时间复杂度" ID="5bUTwuVsgy" STYLE="fork">
            <node TEXT="Java7遍历链表的时间复杂度是O(n)" ID="X5Ssz7tgLL" STYLE="fork"/>
            <node TEXT="Java8如果变成遍历红黑树,那么时间复杂度降低为O(log(n))" ID="FzxOR3vXVp" STYLE="fork"/>
          </node>
        </node>
        <node TEXT="CopyOnWriteArrayList" ID="eK6S3ZtziM" STYLE="fork">
          <node TEXT="基于 CopyOnWrite 机制，写入时会先创建一份副本，写完副本后直接替换原内容" ID="knBbbaYAGl" STYLE="fork"/>
          <node TEXT="优点：比读写锁更近一步，只需写写互斥，读取不用加锁，对于读多写少的场景可以大幅提升性能" ID="V4PXhJlnfe" STYLE="fork"/>
          <node TEXT="缺点：写入时存在创建副本开销及副本所多占的内存，读写不互斥可能会导致数据无法及时保持同步" ID="554Mu5GcjO" STYLE="fork"/>
        </node>
        <node TEXT="阻塞队列" ID="hnwWKx5E7b" STYLE="fork">
          <node TEXT="特点: 阻塞" ID="aDjqn10llm" STYLE="fork"/>
          <node TEXT="常见阻塞队列" ID="5tLdXIp7HD" STYLE="fork">
            <node TEXT="ArrayBlockingQueue" ID="9LNIaAnPeh" STYLE="fork"/>
            <node TEXT="LinkedBlockingQueue" ID="bc24hJSgoA" STYLE="fork"/>
            <node TEXT="SynchronousQueue" ID="z2gZYlg1af" STYLE="fork"/>
            <node TEXT="PriorityBlockingQueue" ID="0CWnPZ1GkN" STYLE="fork"/>
            <node TEXT="DelayQueue" ID="Ya5j1WJPO4" STYLE="fork"/>
          </node>
        </node>
        <node TEXT="非阻塞队列" ID="amfCvUDeHP" STYLE="fork"/>
        <node TEXT="ConcurrentSkipListMap" ID="5ZmYVBnCp9" STYLE="fork"/>
      </node>
      <node TEXT="atomic包,6种原子类" ID="vapnCcioWw" STYLE="fork">
        <node TEXT="分类" ID="IljHky8HFl" STYLE="fork">
          <node TEXT="Atomic* 基本类型原子类" ID="1YOa2nvHHb" STYLE="fork">
            <node TEXT="AtomicInteger、AtomicLong、AtomicBoolean" ID="2KOKzVMC2f" STYLE="fork"/>
            <node TEXT="提供了基本类型的 getAndSet、compareAndSet 等原子操作" ID="joZYWNQTJx" STYLE="fork"/>
            <node TEXT="底层基于 Unsafe#compareAndSwapInt、Unsafe#compareAndSwapLong 等实现" ID="teljklPA1J" STYLE="fork"/>
          </node>
          <node TEXT="Atomic*Array 数组类型原子类" ID="Vy289x9X69" STYLE="fork">
            <node TEXT="AtomicIntegerArray、AtomicLongArray、AtomicReferenceArray" ID="qDym164hKh" STYLE="fork"/>
          </node>
          <node TEXT="Atomic*Reference 引用类型原子类" ID="NzrdlbbiCm" STYLE="fork">
            <node TEXT="AtomicReference、AtomicStampedReference、AtomicMarkableReference" ID="ESGgqsptmD" STYLE="fork"/>
            <node TEXT="用于让一个对象保证原子性，底层基于 Unsafe#compareAndSwapObject 等实现" ID="zbGINSTdVo" STYLE="fork"/>
            <node TEXT="AtomicStampedReference 是对 AtomicReference 的升级，在此基础上加了时间戳，用于解决 CAS 的 ABA 问题" ID="K0ds2yJcVR" STYLE="fork"/>
          </node>
          <node TEXT="Atomic*FieldUpdater 升级类型原子类" ID="p7lXvTzheT" STYLE="fork">
            <node TEXT="AtomicIntegerfieldupdater、AtomicLongFieldUpdater、AtomicReferenceFieldUpdater" ID="YeYypSHvxy" STYLE="fork"/>
            <node TEXT="对于非原子的基本或引用类型，在不改变其原类型的前提下，提供原子更新的能力" ID="JsueHLUXSq" STYLE="fork"/>
            <node TEXT="适用于由于历史原因改动成本太大或极少情况用到原子性的场景" ID="8vKtJJgCRW" STYLE="fork"/>
          </node>
          <node TEXT="Adder 累加器" ID="y99nSlAWM8" STYLE="fork">
            <node TEXT="LongAdder、DoubleAdder" ID="AjBSBXHWn8" STYLE="fork"/>
            <node TEXT="相比于基本类型原子类，累加器没有 compareAndSwap、addAndGet 等方法，功能较少" ID="8UvymBbuQ3" STYLE="fork"/>
            <node TEXT="设计原理：将 value 分散到一个数组中，不同线程只针对自己命中的槽位进行修改，减小高并发场景的线程竞争概率，类似于 ConcurrentHashMap 的分段锁思想" ID="WE0znpcjng" STYLE="fork"/>
            <node TEXT="可解决高并发场景 AtomicLong 的过多自旋问题" ID="1IrXS6yPyT" STYLE="fork"/>
          </node>
          <node TEXT="Accumulator 积累器" ID="A30u8Y5nha" STYLE="fork">
            <node TEXT="LongAccumulator、DoubleAccumulator" ID="fqHxWczbSW" STYLE="fork"/>
            <node TEXT="是 LongAdder、DoubleAdder 的功能增强版，提供了自定义的函数操作" ID="36ypMtTv8i" STYLE="fork"/>
          </node>
        </node>
        <node TEXT="原子类与锁" ID="OOu4pvyIDz" STYLE="fork">
          <node TEXT="都是为了保证并发场景下的线程安全" ID="XiB9Dj57WB" STYLE="fork"/>
          <node TEXT="原子类粒度更细,竞争范围为变量级别" ID="NHJIuyKdUj" STYLE="fork"/>
          <node TEXT="原子类效率更高,底层采取CAS操作,不会阻塞线程" ID="6vuRQD6P8M" STYLE="fork"/>
          <node TEXT="原子类不适用于高并发场景,因为无限循环的CAS操作会占用CPU" ID="rTNIRBIszJ" STYLE="fork"/>
        </node>
        <node TEXT="原子类与volatile" ID="jxH5GgWFOK" STYLE="fork">
          <node TEXT="volatile具有可见性和有序性,但不具备原子性" ID="f9UuRDsmVk" STYLE="fork"/>
          <node TEXT="volatile修饰boolean类型通常保证线程安全,因为赋值操作具有原子性" ID="ccndozavsy" STYLE="fork"/>
          <node TEXT="volatile修饰int类型通常无法保证线程安全,因为int类型的计算操作需要读取-&gt;修改-&gt;赋值回去,不是原子操作,这时需要使用原子类" ID="6IgGkJi8Im" STYLE="fork"/>
        </node>
      </node>
      <node TEXT="ThreadLocal" ID="dspU96C9V1" STYLE="fork">
        <node TEXT="使用场景" ID="aXfUeRNSfP" STYLE="fork">
          <node TEXT="保存每个线程独享的对象" ID="wamsvjKmAS" STYLE="fork"/>
          <node TEXT="每个线程内需要独立保存信息,供其他方法更方便得获取该信息." ID="iWPTUSF6wI" STYLE="fork"/>
        </node>
        <node TEXT="原理" ID="Ic20DGE6lj" STYLE="fork">
          <node TEXT="每个线程里面有一个ThreadLocalMap,ThreadLocalMap里面对应着多个ThreadLocal,每个ThreadLocal里面对应着一个value" ID="tptKVYoUJ9" STYLE="fork"/>
        </node>
      </node>
    </node>
    <node TEXT="管理线程,提高效率" ID="9WxBBm3UCr" STYLE="bubble" POSITION="default">
      <node TEXT="线程池" ID="EFHgbYXk2n" STYLE="fork">
        <node TEXT="优点" ID="uSHt5loFGV" STYLE="fork">
          <node TEXT="减少在创建和销毁线程上所花的时间以及系统资源的开销" ID="T2EkBZUOsj" STYLE="fork"/>
          <node TEXT="不使用线程池有可能造成系统创建大量的线程而导致消耗完系统内存以及过渡切换" ID="XtPLcOOT9h" STYLE="fork"/>
        </node>
        <node TEXT="参数" ID="7ZN7xQrqo1" STYLE="fork">
          <node TEXT="corePoolSize" ID="HC5l9TYcrJ" STYLE="fork">
            <node TEXT="核心线程数,默认情况下一直存活.如果将allowCoreThreadTimeOut设置为true,则核心线程会有超时策略,闲置时间超过keepAliveTime,核心线程也会被终止." ID="UbOwLp8m4f" STYLE="fork"/>
          </node>
          <node TEXT="maximumPoolSize" ID="9K2erzVnti" STYLE="fork">
            <node TEXT="线程池所能容纳的最大线程数,当活动线程数达到这个数值后,后续的新任务将会阻塞." ID="lTC2HWBsHV" STYLE="fork"/>
          </node>
          <node TEXT="keepAliveTime" ID="s3WG4XPdgS" STYLE="fork">
            <node TEXT="非核心线程闲置时的超时时长,超过该时长,非核心线程就会被回收.当ThreadPoolExecutor的allowCoreThreadTimeOut属性设置为true时,keepAliveTime同样会作用于核心线程." ID="vzfX31cTdw" STYLE="fork"/>
          </node>
          <node TEXT="unit" ID="4BCb02Ru0R" STYLE="fork">
            <node TEXT="用来指定keepAliveTime参数的时间单位." ID="JKcGKFUQkr" STYLE="fork"/>
          </node>
          <node TEXT="workQueue" ID="jfQpywxJiT" STYLE="fork">
            <node TEXT="线程池中的任务队列,通过线程池的execute方法提交的Runnable对象会存在在这个队列中" ID="OXQmaW20hi" STYLE="fork"/>
          </node>
          <node TEXT="threadFactory" ID="q8qYahcAK2" STYLE="fork">
            <node TEXT="线程工厂,为线程池提供创建新线程的功能.ThreadFactory是一个接口,它只有一个方法: Thread newThread(Runnable r)" ID="5jvkzqBxId" STYLE="fork"/>
          </node>
          <node TEXT="handler" ID="12IqFcZcAv" STYLE="fork">
            <node TEXT="处理被拒绝的任务.当线程池无法执行新任务时,这可能是由于任务队列已满或者是无法成功执行任务,这个时候ThreadPoolExecutor会调用handler的rejectedExecution方法来通知调用者.默认情况下,rejectedExecution方法会直接抛出一个RejectedExecutionException." ID="p1XgpJHzzu" STYLE="fork"/>
          </node>
        </node>
        <node TEXT="分类" ID="XBMve7UY8e" STYLE="fork">
          <node TEXT="FixedThreadPool   数量固定的线程池" ID="5RHjJ5DTwk" STYLE="fork"/>
          <node TEXT="CachedThreadPool   只有非核心线程,数量不定,空闲线程有超时机制,比较适合执行大量耗时较少的任务" ID="ZnJV1oZt7n" STYLE="fork"/>
          <node TEXT="ScheduledThreadPool   核心线程数量固定,非核心线程没有限制.主要用于执行定时任务和具有固定中周期的重复任务." ID="R4X7Fwwn6u" STYLE="fork"/>
          <node TEXT="SingleThreadPool     只有一个核心线程,确保所有的任务在同一个线程顺序执行,统一外界任务到一个线程中,这使得在这些任务之间不需要处理线程同步 的问题." ID="RyOSeK0LqW" STYLE="fork"/>
        </node>
        <node TEXT="执行任务流程" ID="aV5entL5jG" STYLE="fork">
          <node TEXT="1. 如果线程池中的数量未达到核心线程的数量,则直接启动一个核心线程来执行任务" ID="VK7fADtpLw" STYLE="fork"/>
          <node TEXT="2. 如果线程池中的数量已经达到或超过核心线程的数量,则任何会被插入到任务队列中等待执行" ID="Q7Ou3afQnx" STYLE="fork"/>
          <node TEXT="3. 如果2中的任务无法插入到任务队列中,由于任务队列已满,这时候如果线程数量未达到线程池规定的最大值,则会启动一个非核心线程来执行任务" ID="R9mUvWPKuK" STYLE="fork"/>
          <node TEXT="4. 如果3中的线程数量已经达到线程池最大值,则会拒绝执行此任务,ThreadPoolExecutor会调用RejectedExecutionHandler的rejectedExecution()方法通知调用者" ID="95HZKXccSZ" STYLE="fork"/>
        </node>
        <node TEXT="拒绝策略" ID="0SCY2l47Pp" STYLE="fork">
          <node TEXT="AbortPolicy：抛出 RejectedExecutionException 异常，可根据业务进行重试等操作" ID="mMFrwdxGvW" STYLE="fork"/>
          <node TEXT="DiscardPolicy：直接丢弃新提交的任务，不做其他反馈，有任务丢失风险" ID="9aUpXypduv" STYLE="fork"/>
          <node TEXT="DiscardOldestPolicy：如果线程池未关闭，就丢弃队列中存活时间最长的任务，但不做其他反馈，有任务丢失风险" ID="usVhDRpYQd" STYLE="fork"/>
          <node TEXT="CallerRunsPolicy：如果线程池未关闭，就在提交任务的线程直接开始执行任务，任务不会被丢失，由于阻塞了提交任务的线程，相当于提供了负反馈" ID="xR1dcvLNTi" STYLE="fork"/>
        </node>
        <node TEXT="正确关闭线程池" ID="pRTdvVfLju" STYLE="fork">
          <node TEXT="shutdown()：调用后会在执行完正在执行任务和队列中等待任务后才彻底关闭，并会根据拒绝策略拒绝后续新提交的任务" ID="R71q8t62nS" STYLE="fork"/>
          <node TEXT="shutdownNow()：调用后会给正在执行任务线程发送中断信号，并将任务队列中等待的任务转移到一个 List 中返回，后续会根据拒绝策略拒绝新提交的任务" ID="QUZn3OW2oI" STYLE="fork"/>
          <node TEXT="isShutdown()：判断是否开始关闭线程池，即是否调用了 shutdown() 或 shutdownNow() 方法" ID="4bPlePyDwp" STYLE="fork"/>
          <node TEXT="isTerminated()：判断线程池是否真正终止，即线程池已关闭且所有剩余的任务都执行完了" ID="yUM74FRBTA" STYLE="fork"/>
          <node TEXT="awaitTermination()：阻塞一段时间等待线程池终止，返回 true 代表线程池真正终止否则为等待超时" ID="SP71dqPosZ" STYLE="fork"/>
        </node>
        <node TEXT="线程池复用原理" ID="B4Zu1qg6DG" STYLE="fork">
          <node TEXT="线程池将线程和任务解耦，一个线程可以从任务队列中获取多个任务执行" ID="UNeHjCO3dJ" STYLE="fork"/>
          <node TEXT="关键类为 ThreadPoolExecutor 内部的 Worker 类，对应于一个线程，其内部会从任务队列中获取多个任务执行" ID="gzIojoGhlI" STYLE="fork"/>
        </node>
      </node>
      <node TEXT="Future获取运行结果" ID="bZr63cQJFH" STYLE="fork"/>
      <node TEXT="Fork/Join模式" ID="dxYpN11PAK" STYLE="fork"/>
    </node>
    <node TEXT="线程配合" ID="nzSiay4TKf" STYLE="bubble" POSITION="default">
      <node TEXT="CountDownLatch" ID="bcTrJkbFse" STYLE="fork">
        <node TEXT="用法一: 一个线程等待其他多个线程都执行完毕,再继续自己的工作" ID="3pXnvdf5GY" STYLE="fork"/>
        <node TEXT="用法二: 多个线程等待某一个线程的信号,同时开始执行" ID="2HK2oitCW3" STYLE="fork"/>
      </node>
      <node TEXT="CyclicBarrier" ID="NETuG0K2cP" STYLE="fork">
        <node TEXT="与CountDownLatch类似,都能阻塞一个或一组线程,直到某个预设的条件达成,再统一出发" ID="VUGfx51qpe" STYLE="fork"/>
      </node>
      <node TEXT="Semaphore" ID="oZrjXx4zPa" STYLE="fork">
        <node TEXT="通过控制许可证的发放和归还实现同一时刻可执行某任务的最大线程数" ID="Lp5mCCBZrL" STYLE="fork"/>
      </node>
      <node TEXT="Condition" ID="g2YAOztITn" STYLE="fork"/>
      <node TEXT="Phaser" ID="ctOXt1WxPk" STYLE="fork"/>
    </node>
    <node TEXT="底层原理" ID="66SlilpT1X" STYLE="bubble" POSITION="default">
      <node TEXT="Java内存模型" ID="7WBxwBdRF7" STYLE="fork">
        <node TEXT="重排序" ID="iAdtwLPM6G" STYLE="fork">
          <node TEXT="编译器优化" ID="k3YF0HyG2J" STYLE="fork"/>
          <node TEXT="CPU优化" ID="K1rGbdVlw0" STYLE="fork"/>
          <node TEXT="内存&quot;重排序&quot;" ID="lmdC5G3wHc" STYLE="fork"/>
        </node>
        <node TEXT="原子性" ID="2caaMQ7sle" STYLE="fork">
          <node TEXT="除了long和double之外的基本类型(int、byte、boolean、short、char、float)的读/写操作,都天然的具备原子性.long和double是64位的,需要分为2个32位来操作,这样可能导致读到一个错误,不完整的值" ID="OqxtNUkIU1" STYLE="fork"/>
          <node TEXT="所有引用reference的读/写操作" ID="syZYDg20rO" STYLE="fork"/>
          <node TEXT="加了volatile后,所有变量的读/写操作(包含long和double)." ID="mzbG99dW2i" STYLE="fork"/>
          <node TEXT="在java.concurrent.Atomic包中的一部分类的一部分方法是具备原子性的,比如AtomicInteger的incrementAndGet方法." ID="RHXBLfdksL" STYLE="fork"/>
        </node>
        <node TEXT="内存可见性" ID="uyYfth7Zmt" STYLE="fork">
          <node TEXT="每个线程只能够直接接触到工作内存,无法直接操作主内存,而工作内存中所保存的正是主内存的共享变量的副本,主内存和工作内存之间的通信是由JMM控制的." ID="WFz6FyvKOy" STYLE="fork"/>
        </node>
      </node>
      <node TEXT="CAS原理" ID="hRGlD5Tf9F" STYLE="fork"/>
      <node TEXT="AQS框架" ID="uMZImQHxGR" STYLE="fork">
        <node TEXT="存在意义" ID="qsgi2PJFOC" STYLE="fork">
          <node TEXT="AQS是一个用于构建锁、同步器等线程协作工具的框架,即AbstractQueuedSynchronizer类" ID="MX2qNOYMWz" STYLE="fork"/>
          <node TEXT="ReentrantLock、Semaphore、CountDownLatch 等工具类的工作都是类似的，AQS 就是这些类似工作提取出来的公共部分，比如阀门功能、调度线程等" ID="0PddXF0OyN" STYLE="fork"/>
          <node TEXT="AQS 可以极大的减少上层工具类的开发工作量，也可以避免上层处理不当导致的线程安全问题" ID="xU44xDVlPU" STYLE="fork"/>
        </node>
        <node TEXT="内部关键原理" ID="Tr08gvR4Ix" STYLE="fork">
          <node TEXT="state 值：AQS 中具有一个 int 类型的 state 变量，在不同工具类中代表不同的含义，比如在 Semaphore 中代表剩余许可证的数量；在 CountDownLatch 中代表需要倒数的数量；在 ReentrantLock 中代表锁的占有情况，0 代表没被占有，1 代表被占有，大于 1 代表同个线程重入了" ID="DqEiOmuvpY" STYLE="fork"/>
          <node TEXT="FIFO 队列：用于存储、管理等待的线程" ID="1Ms7NwE9qI" STYLE="fork"/>
          <node TEXT="获取、释放锁：需工具类自行实现，比如 Semaphore#acquire、ReentrantLock#lock 为获取；Semaphore#release、ReentrantLock#unlock 为释放" ID="82eBol8rLh" STYLE="fork"/>
        </node>
      </node>
    </node>
  </node>
</map>