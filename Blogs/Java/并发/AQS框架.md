
### AQS用法

这里是JDK里利用AQS的主要步骤:

1. 新建一个自己的线程协作工具类，在内部写一个 Sync 类，该 Sync 类继承 AbstractQueuedSynchronizer，即 AQS；
2. 想好设计的线程协作工具类的协作逻辑，在 Sync 类里，根据是否是独占，来重写对应的方法。如果是独占，则重写 tryAcquire 和 tryRelease 等方法；如果是非独占，则重写 tryAcquireShared 和 tryReleaseShared 等方法；
3. 在自己的线程协作工具类中，实现获取/释放的相关方法，并在里面调用 AQS 对应的方法，如果是独占则调用 acquire 或 release 等方法，非独占则调用 acquireShared 或 releaseShared 或 acquireSharedInterruptibly 等方法

### AQS概念及存在的意义

- AQS: 是一个用于构建锁、同步器等线程协作工具类的框架,即AbstractQueuedSynchronizer类
- ReentrantLock、Semaphore、CountDownLatch等工具类的工作都是类似的,AQS就是这些类似工作提取出来的公共部分,比如阀门功能、调度线程等
- AQS可以极大的减少上层工具类的开发工作量,也可以避免上层处理不当导致的线程安全问题

### AQS内部关键原理

- state值: AQS中具有一个int类型的state变量,在不同的工具类中代表不同的含义,比如在Semaphore中代表剩余许可证的数量;在CountDownLatch中代表需要倒数的数量;在ReentrantLock中代表锁的占有情况,0是没占有,1是被占有,大于1代表同一个线程重入了.
- FIFO队列:用于存储、管理等待的线程
- 获取、释放锁:需要工具类自行实现,比如比如 Semaphore#acquire、ReentrantLock#lock 为获取；Semaphore#release、ReentrantLock#unlock 为释放.