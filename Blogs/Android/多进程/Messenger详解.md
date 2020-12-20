
## 1. 概念

Messenger,即进程间通信的信使.它是基于Message的进程间通信,我们可以像在线程间利用Handler.send(Message)一样.

Messenger是一种轻量级的IPC方案,它的底层实现其实就是AIDL.跨进程通信使用Messenger时,Messenger会将所有服务调用加入队列,然后服务端那边一次处理一个调用,不会存在同时调用的情况.而AIDL则可能是多个调用同时执行,必须处理多线程问题.

对于大多数应用,跨进程通信无需一对多,也就是无需执行多线程处理,此时使用Messenger更适合.

## 2. 使用

### 2.1 大致流程

1. 服务端实现一个Handler,由其接收来自客户端的每个调用的回调
2. 服务端使用Handler来创建Messenger对象
3. Messenger创建一个IBinder,服务端通过onBind()将其返回给客户端
4. 客户端使用IBinder将Messenger实例化,然后再用起将Message对象发送给服务端
5. 服务端在其Handler#handleMessage()中,接收每个Message

## 3. 原理
## 资料