
### AQS概念及存在的意义

- AQS: 是一个用于构建锁、同步器等线程协作工具类的框架,即AbstractQueuedSynchronizer类
- ReentrantLock、Semaphore、CountDownLatch等工具类的工作都是类似的,AQS就是这些类似工作提取出来的公共部分,比如阀门功能、调度线程等
- AQS可以极大的减少上层工具类的开发工作量,也可以避免上层处理不当导致的线程安全问题
