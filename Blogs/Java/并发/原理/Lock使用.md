
### 前言

Lock和synchronized相比都是可重入的独占锁,不用的是Lock是显式锁,lock/unlock需要手动调用加解锁(一般将unlock放入finally中),而synchronized是隐式锁.Lock本身是一个接口,可以通过调用lockInterruptibly方法设置可中断锁,也可以调用其newCondition获取一个Condition,它的一个实现子类ReentrantLock也可以实现公平锁(通过同步队列来实现多个线程按照申请锁的顺序获取锁)和非公平锁,默认是非公平锁(synchronized是非公平锁).

但是,现在基本上大多数还是使用synchronized,因为synchronized是JVM的一个内置属性,它能执行一些优化,例如锁消除、锁力度粗化等等.

### ReentrantLock基本使用

需要手动加锁和解锁

```java
class ReentrantLockTest {

    ReentrantLock mReentrantLock = new ReentrantLock();

    public static void main(String[] args) {
        ReentrantLockTest reentrantLockTest = new ReentrantLockTest();

        Thread thread1 = new Thread(new Runnable() {
            @Override
            public void run() {
                reentrantLockTest.printLog();
            }
        });

        Thread thread2 = new Thread(new Runnable() {
            @Override
            public void run() {
                reentrantLockTest.printLog();
            }
        });

        thread1.start();
        thread2.start();
    }

    public void printLog() {
        try {
            mReentrantLock.lock();
            for (int i = 0; i < 5; i++) {
                System.out.println(Thread.currentThread().getName() + " is printing " + i);
            }
        } finally {
            //一般是放这里任何情况都解锁了
            mReentrantLock.unlock();
        }
    }
}

//输出
Thread-0 is printing 0
Thread-0 is printing 1
Thread-0 is printing 2
Thread-0 is printing 3
Thread-0 is printing 4
Thread-1 is printing 0
Thread-1 is printing 1
Thread-1 is printing 2
Thread-1 is printing 3
Thread-1 is printing 4
```

ReentrantLock有一个带参数的构造器,传入true的话则是公平锁,默认不是公平锁. 公平锁就是通过同步队列来实现多个线程按照申请锁的顺序获取锁.

### ReentrantReadWriteLock 使用

有时候需要定义一个线程间共享的用作缓存的数据结构,这时候写数据的话,不能再有其他读操作进来,并且写操作完成之后的更新数据需要后续的读操作可见.

使用读写锁ReentrantReadWriteLock可以实现上述功能,只需要在读操作时获取读锁,写操作时获取写锁即可.当写锁被获取到时,后续的读写锁都会被阻塞,写锁释放之后,所有操作继续执行,这种编程方式相对于使用等待通知机制的实现方式而言,变得简单明了.


```java
class ReadWriteTest {

    //搞个公平锁
    private static final ReentrantReadWriteLock REENTRANT_READ_WRITE_LOCK = new ReentrantReadWriteLock(true);
    //共享的缓存数据
    private static String number = "0";

    public static void main(String[] args) {
        //读线程
        Thread t1 = new Thread(new Reader(), "读线程 1");
        Thread t2 = new Thread(new Reader(), "读线程 2");

        //写线程
        Thread t3 = new Thread(new Writer(), "写线程");

        t1.start();
        t2.start();
        t3.start();
    }

    static class Reader implements Runnable {
        @Override
        public void run() {
            for (int i = 0; i < 10; i++) {
                //使用读锁（ReadLock）将读取数据的操作加锁
                REENTRANT_READ_WRITE_LOCK.readLock().lock();
                System.out.println(Thread.currentThread().getName() + " is printing " + number);
                REENTRANT_READ_WRITE_LOCK.readLock().unlock();
            }
        }
    }

    static class Writer implements Runnable {
        @Override
        public void run() {
            for (int i = 1; i <= 7; i += 2) {
                try {
                    //使用写锁（WriteLock）将写入数据到缓存中的操作加锁
                    REENTRANT_READ_WRITE_LOCK.writeLock().lock();
                    System.out.println(Thread.currentThread().getName() + " 写入 " + i);
                    number = number.concat("" + i);
                } finally {
                    REENTRANT_READ_WRITE_LOCK.writeLock().unlock();
                }
            }
        }
    }

}

//输出
读线程 2 is printing 0
读线程 1 is printing 0
写线程 写入 1
读线程 2 is printing 01
读线程 1 is printing 01
写线程 写入 3
读线程 2 is printing 013
读线程 1 is printing 013
写线程 写入 5
读线程 2 is printing 0135
读线程 1 is printing 0135
写线程 写入 7
读线程 2 is printing 01357
读线程 1 is printing 01357
读线程 2 is printing 01357
读线程 1 is printing 01357
读线程 2 is printing 01357
读线程 1 is printing 01357
读线程 2 is printing 01357
读线程 1 is printing 01357
读线程 2 is printing 01357
读线程 1 is printing 01357
读线程 2 is printing 01357
读线程 1 is printing 01357
```

当写入操作在执行时,读取数据的操作会被阻塞.当写入执行成功后,读取数据的操作继续执行,并且读取的数据也是最新写入后的实时数据.