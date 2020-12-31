

## 1. 为什么采用Binder作为IPC机制

Android开发了新的IPC机制Binder,而且大量采用Binder机制进行IPC,少量使用已有的IPC机制.这是为什么?

### 1.1 Linux现有的IPC方式

1. 管道: 管道是半双工的,管道的描述符只能读或写,想要既可以读也可以写就需要两个描述符,而且管道一般用在父子进程之间;而且缓存区大小比较有限;
2. 消息队列: 信息复制2次,额外的CPU消耗;不适合频繁或信息量大的通信;
3. 共享内存: 无须复制,共享缓冲区直接附加到进程虚拟地址空间,速度快;但进程间的同步问题操作系统无法实现,必须各进程利用同步工具解决;
4. 套接字: 更通用的接口,传输效率低,主要用于不同机器或跨网络的通信
5. 信号量: 常作为锁机制,防止某进程正在访问共享资源时,其他进程也访问该资源.因此,主要作为进程间以及同一进程内不同线程之间的同步手段;
6. 信号: 不适合用于信息交换,更适合进程中断控制,比如非法内存访问,杀死某个进程等.

### 1.2 采用Binder的理由分析

(1) **从性能的角度,数据拷贝次数**: Binder数据只需要拷贝一次,而管道、消息队列、Socket都需要2次,但共享内存方式一次内存拷贝都不需要;从性能角度,Binder性能仅次于共享内存

(2) **稳定性角度**: Binder是基于C/S架构.C/S架构是指客户端(Client)和服务端(Server)组成的架构,Client端有什么需求,直接发送给Server端去完成,架构清晰明朗,Server端与Client端相对独立,稳定性较好;而共享内存实现方式复杂,没有客户与服务端之别,需要充分考虑到访问临界资源的并发同步问题,否则可能出现死锁等问题; 从稳定性角度,Binder架构优于共享内存;

(3) **安全角度**: 传统Linux IPC的接收方无法获得对方进程可靠的UID/PID,从而无法鉴别对方身份;而Android作为一个开放的开源体系,拥有非常多的开发平台,App来源甚广,因此手机的全球显得非常重要;对于普通用户,肯定是不希望app偷窥隐私数据、后台造成手机耗电等问题,传统Linux IPC无任何保护措施,完全由上层协议来确保. 传统IPC只能由用户在数据包里填入UID/PID;另外,**可靠的身份标记只有由IPC机制本身在内核中添加**.其次传统IPC访问接入点是开放的,无法建立私有通道.从安全角度,Binder安全性更高.

(4) 语言层面: Linux是基于C语言(面向过程的语言),而Android是基于Java语言(面向对象的语句),而对于Binder恰恰也符合面向对象的思想,将进程间通信转化为通过对某个Binder对象的引用调用该对象的方法,而其独特之处在于Binder对象是一个可以跨进程引用的对象,它的实体位于一个进程中,而它的引用却遍布于系统的各个进程之中.可以从一个进程传给其它进程,让大家都能访问同一Server,就像将一个对象或引用赋值给另一个引用一样.Binder模糊了进程边界,淡化了进程间通信过程,整个系统仿佛运行于同一个面向对象的程序之中.从语言层面,Binder更适合基于面向对象语言的Android系统,对于Linux系统可能会有点“水土不服”.

## 2. 概述

Android四大组件所涉及的多进程间的通信底层都是依赖于Binder IPC机制.例如进程A中Activity向进程B中Service进行通信,这便需要依赖于Binder IPC.不仅如此,整个Android系统架构中,大量采用了Binder机制作为IPC方案,当然也存在部分其他的IPC方式,比如Zygote通信便是采用socket.

### 2.1 IPC原理

对于用户空间,不同进程之间彼此是不能共享的,而内核空间却是可以共享的.Client进程向Server进程通信,恰恰是利用进程间可共享的内核内存空间来完成底层通信工作的,Client端与Server端进程往往采用ioctl等方法跟内核空间的驱动进行交互.

### 2.2 Binder原理

Binder通信采用C/S架构,从组件视角来说,包含Client、Server、ServiceManager以及binder驱动,其中ServiceManager用于管理系统中的各种服务.

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/Binder%E5%8E%9F%E7%90%86%E6%9E%B6%E6%9E%84%E5%9B%BE.png)

无论是注册服务和获取服务的过程都需要ServiceManager,此处的ServiceManager是Native层的ServiceManager(C++),并非指framework层的ServiceManager(Java). ServiceManager是整个Binder通信机制的大管家,是Android进程间通信机制Binder的守护进程.

Client/Server/ServiceManage之间的相互通信都是基于Binder机制,既然基于Binder机制通信，那么同样也是C/S架构，则图中的3大步骤都有相应的Client端与Server端

- 注册服务(addService): Server进程要先注册Service到ServiceManager.该过程: Server是客户端，ServiceManager是服务端
- 获取服务(getService): Client进程使用某个Service前,须先向ServiceManager中获取相应的Service.该过程: Client是客户端,ServiceManager是服务端.
- 使用服务: Client根据得到的Service信息建立与Service所在的Server进程通信的通路,然后就可以直接与Service交互. 该过程: client是客户端,server是服务端.

Client,Server,ServiceManager之间交互图中用虚线表示,是因为它们之间不是直接交互的,而是通过与Binder驱动进行交互的,从而实现IPC通信方式.其中Binder驱动位于内核空间,Client、Server、ServiceManager位于用户空间.Binder驱动和ServiceManager可以看做是Android平台的基础架构,而Client和Server是Android的应用层,开发人员只需自定义实现Client、Server端,借助Android的基本平台架构便可以直接进行IPC通信.

### 2.3 Android Binder架构

Zygote孵化出`system_server`进程后,在`system_server`进程中初始化支持整个Android framework的各种各样的Service,而这些Service大体分为Java层Framework和Native Framework层(C++)的Service,几乎都是基于Binder IPC机制

1. Java Framework : **作为Server端继承(或间接继承)于Binder类,Client端继承(或间接继承)与BinderProxy类**.例如ActivityManagerService(用于控制Activity、Service、进程等)这个服务作为Server端,间接继承Binder类,而相应的ActivityManager作为Client端,间接继承于BinderProxy类.当然还有PackageManagerService、WindowManagerService等等很多系统服务都是采用C/S架构
2. Native Framework层: **C++层,作为Server端继承(或间接继承)于BBinder类,Client端继承(或间接继承)于BpBinder**.例如MediaPlayService(用于多媒体相关)作为Server端,继承于BBinder类,而相应的MediaPlay作为Client端,间接继承于BpBinder类.

> Gityuan: 无Binder不Android

## 3. Binder 通信模型

Binder框架定义了四个角色:Server,Client,ServiceManager,Binder驱动.其中Server,Client,ServiceManager运行于用户空间,驱动运行于内核空间.这四个角色的关系和互联网类似:Server是服务器,Client是客户端,ServiceManager是域名服务器(DNS),驱动是路由器

### 3.1 Binder驱动

Binder驱动是通信的核心.虽然名字叫"驱动",但实际上和硬件设备没有任何关系,只是实现方式和设备驱动程序是一样的: 工作于内核态,提供open(),mmap(),poll(),ioctl()等标准文件操作,以字符驱动设备中的misc设备注册在设备目录`/dev`下,用户通过`/dev/binder`访问它.驱动负责进程之间Binder通信的建立,Binder在进程之间的传递,Binder引用计数,数据包在进程之间的传递和交互等一系列底层支持.驱动和应用程序之间定义了一套接口协议,主要功能由ioctl()接口实现,不提供read()、write()接口,因为ioctl()灵活方便,且能够一次调用实现先写后读以满足同步交互,而不必分别调用read()和write().

### 3.2 ServiceManager 与 实名Binder

ServiceManager的作用是将字符形式的Binder名字转化成Client中对该Binder的引用,使得Client能够通过Binder名字获得对Server中Binder实体的引用.注册了名字的Binder叫实名Binder.Server创建了Binder实体,为其取一个字符形式、可读易记的名字,将这个Binder连同名字以数据包的形式通过Binder驱动发送给ServiceManager,通知ServiceManager注册一个名叫张三的Binder,它位于某个Server中.驱动为这个穿过进程边界的Binder创建位于内核中的实体节点以及ServiceManager对实体的引用,将名字及新建的引用打包传递给ServiceManager.ServiceManager收到数据包后,从中取出名字和引用填入一张查找表中.

事有蹊跷: ServiceManager是一个进程,Server是另一个进程,Server向ServiceManager注册Binder必然会涉及进程间通信.当前实现的是进程间通信却又要用到进程间通信,这就好像蛋可以孵出鸡之前却是要找只鸡来孵蛋. Binder的实现非常巧妙: 预先创造一只鸡来孵蛋.ServiceManager和其他进程同样采用Binder通信,ServiceManager是Server端,有自己的Binder对象(实体),其他进程都是Client,需要通过这个Binder的引用来实现Binder的注册,查询和获取.ServiceManager提供的Binder比较特殊,它没有名字也不需要注册,当一个进程使用`BINDER_SET_CONTEXT_MGR`命令将自己注册成ServiceManager时Binder驱动会自动为它创建Binder实体(这是那只预先造好的鸡).其次这个Binder的引用在所有Client中都固定为0而无须通过其他手段获得.也就是说,一个Server若要向ServiceManager注册自己的Binder就必须通过0这个引用号和ServiceManager的Binder进行通信.类比网络通信,0号引用就好比域名服务器的地址,你必须预先手工或动态配置好.要注意这里说的Client是相对ServiceManager而言的,一个应用程序可能是个提供服务的Server,但对ServiceManager来说它仍然是个Client.

### 3.3 Client 获得实名Binder的引用

Server向ServiceManager注册了Binder实体及其名字后,Client就可以通过名字获得该Binder的引用了.Client也利用保留的0号引用向ServiceManager请求访问某个Binder: 我申请获得名字叫张三的Binder的引用.ServiceManager收到这个连接请求,从请求数据包里获得Binder的名字,在查找表里找到该名字对应的条目,从条目中取出Binder的引用,将该引用作为回复发送给发起请求的Client.从面向对象的角度,这个Binder对象现在有了2个引用:一个位于ServiceManager中,一个位于发起请求的Client中.如果接下来有更多的Client请求该Binder,系统中就会有更多的引用指向该Binder,就像Java里一个对象存在多个引用一样.而且类似的这些指向Binder的引用是强类型,从而确保只要有引用Binder实体就不会被释放掉.通过以上过程可以看出,ServiceManager像个火车票代售点,收集了所有火车的车票,可以通过它购买到乘坐各趟火车的票-得到某个Binder的引用.

### 3.4 匿名Binder

并不是所有Binder都需要注册给ServiceManager.Server端可以通过已经建立的Binder连接将创建的Binder实体传给Client,这条已经建立的Binder连接必须是通过实名Binder实现.由于这个Binder没有向ServiceManager注册名字,所以是个匿名Binder.Client将会收到这个匿名Binder的引用,通过这个引用向位于Server中的实体发送请求.匿名Binder为通信双方建立一条私密通道,只要Server没有把匿名Binder发送给别的进程,别的进程就无法通过穷举或猜测等任何方式获得该Binder的引用,向该Binder发送请求.

![Binder通信示例](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/Binder%E9%80%9A%E4%BF%A1%E7%A4%BA%E4%BE%8B.png)

## 4. Binder协议

Binder协议基本格式是:命令+数据,使用`ioctl(fd,cmd,arg)`函数实现交互.命令由参数cmd承载,数据由参数arg承载,随cmd不同而不同.

<font color='red'>**BINDER_WRITE_READ**</font> : 该命令向Binder写入或读取数据.参数分为两段:写部分和读部分.如果`write_size`不为0就先将`write_buffer`里的数据写入Binder;如果`read_size`不为0再从Binder中读取数据存入`read_buffer`中.`write_consumed`和`read_consumed`表示操作完成时Binder驱动实际写入或读出的数据个数 

arg:
```c
struct binder_write_read {
    signed long write_size;
    signed long write_consumed;
    unsigned long write_buffer;
    signed long read_size;
    signed long read_consumed;
    unsigned long read_buffer;
};
```

最常用的命令是`BINDER_WRITE_READ`.该命令的参数包含两部分数据:一部分是向Binder写入的数据,一部分是要从Binder读出的数据,驱动程序先处理写部分再处理读部分.这样安排的好处是应用程序可以很灵活地处理命令的同步或异步.例如想要发送异步命令可以只填入写部分而将`read_size`置为0,若要只从Binder获得数据可以将写部分置空即`write_size`置为0;若要发送请求并同步等待返回数据可以将两部分都置上.

### 4.1 BINDER_WRITE_READ 之写操作

Binder写操作数据时格式同样也是:命令+数据.这时命令和数据都存放在`binder_write_read`结构`write_buffer`域指向的内存空间里,多条命令连续存放.数据紧接着存放在命令后面,格式根据命令不同而不同.最常用的命令是`BC_TRANSACTION/BC_REPLY`命令.

**BC_TRANSACTION/BC_REPLY**: BC_TRANSACTION用于Client向Server发送请求数据；BC_REPLY用于Server向Client发送回复（应答）数据。其后面紧接着一个`binder_transaction_data`结构体表明要写入的数据。它的arg是`struct binder_transaction_data`.

Binder请求和应答数据就是通过`BC_TRANSACTION/BC_REPLY`这对命令发送给接收方.这对命令所承载的数据包由结构体`struct binder_transaction_data`定义.Binder交互有同步和异步之分,利用`binder_transaction_data`中flag域区分.如果flag域的`TF_ONE_WAY`位为1则为异步交互,即Client端发送完请求交互即结束,Server端不再返回`BC_REPLY`数据包;否则Server会返回`BC_REPLY`数据包,Client端必须等待接收完该数据包方才完成一次交互.

### 4.2 BINDER_WRITE_READ 从Binder读出数据

从Binder里读出的数据格式和向Binder中写入的数据格式一样,采用`消息ID+数据`形式,并且多条消息可以连续存放.

最重要的消息是`BR_TRANSACTION/BR_REPLY`,这两条消息分别对应发送方的`BC_TRANSACTION`和`BC_REPLY`,表示当前接收的数据是请求还是回复.参数是`binder_transaction_data`.

和写数据一样,其中最重要的消息是`BR_TRANSACTION 或BR_REPLY`，表明收到了一个格式为`binder_transaction_data`的请求数据包`BR_TRANSACTION`或返回数据包`BR_REPLY`.

### 4.3 struct `binder_transaction_data`: 收发数据包结构

该结构是Binder接收/发送数据包的标准格式.

<div style="width: 150pt">成员</div>|含义
---|---
`union {size_t handle;void *ptr;} target;` <img width=200/> | 对于发送数据包的一方，该成员指明发送目的地。由于目的是在远端，所以这里填入的是对Binder实体的引用，存放在target.handle中。如前述，Binder的引用在代码中也叫句柄（handle）。当数据包到达接收方时，驱动已将该成员修改成Binder实体，即指向Binder对象内存的指针，使用target.ptr来获得。该指针是接收方在将Binder实体传输给其它进程时提交给驱动的，驱动程序能够自动将发送方填入的引用转换成接收方Binder对象的指针，故接收方可以直接将其当做对象指针来使用（通常是将其`reinterpret_cast`成相应类）。
void *cookie; | 发送方忽略该成员；接收方收到数据包时，该成员存放的是创建Binder实体时由该接收方自定义的任意数值，做为与Binder指针相关的额外信息存放在驱动中。驱动基本上不关心该成员。
unsigned int code; | 该成员存放收发双方约定的命令码，驱动完全不关心该成员的内容。通常是Server端定义的公共接口函数的编号。
unsigned int flags; | 与交互相关的标志位，其中最重要的是`TF_ONE_WAY`位。如果该位置上表明这次交互是异步的，Server端不会返回任何数据。驱动利用该位来决定是否构建与返回有关的数据结构。另外一位`TF_ACCEPT_FDS`是出于安全考虑，如果发起请求的一方不希望在收到的回复中接收文件形式的Binder可以将该位置上。因为收到一个文件形式的Binder会自动为数据接收方打开一个文件，使用该位可以防止打开文件过多。
`pid_t sender_pid;uid_t sender_euid;` | 该成员存放发送方的进程ID和用户ID，由驱动负责填入，接收方可以读取该成员获知发送方的身份。
`size_t data_size;` | 该成员表示data.buffer指向的缓冲区存放的数据长度。发送数据时由发送方填入，表示即将发送的数据长度；在接收方用来告知接收到数据的长度。
`size_t offsets_size;` | 驱动一般情况下不关心data.buffer里存放什么数据，但如果有Binder在其中传输则需要将其相对data.buffer的偏移位置指出来让驱动知道。有可能存在多个Binder同时在数据中传递，所以须用数组表示所有偏移位置。本成员表示该数组的大小。
`union {struct {const void *buffer;const void *offsets;} ptr;uint8_t buf[8];} data;` | data.bufer存放要发送或接收到的数据；data.offsets指向Binder偏移位置数组，该数组可以位于data.buffer中，也可以在另外的内存空间中，并无限制。buf[8]是为了无论保证32位还是64位平台，成员data的大小都是8个字节。

这里强调一下`offsets_size`和`data.offsets`两个成员,这是Binder通信有别于其他IPC的地方.如前述,Binder采用面向对象的设计思想,一个Binder实体可以发送给其他进程从而建立许多跨进程的引用;另外这些引用可以在进程之间传递,就像Java里将一个引用赋给另一个引用一样.为Binder在不同进程中建立引用必须有驱动参与,由驱动在内核创建并注册相关的数据结构后接收方才能使用该引用.而且这些引用可以是强类型,需要驱动为其维护引用计数.然而这些跨进程传递的Binder混杂在应用程序发送的数据包里,数据格式由用户定义,如果不把它们一一标记出来告知驱动,驱动将无法从数据中将它们提取出来.于是就使用数组`data.offsets`存放用户数据中每个Binder相对`data.buffer`的偏移量,用`offsets_size`表示这个数组的大小.驱动在发送数据包时会根据`data.offsets`和`offset_size`将散落于`data.buffer`中的Binder找出来并一一为它们创建相关的数据结构.在数据包中传输的Binder是类型为`struct flat_binder_object`的结构体.

对于接收方来说,该结构只相当于一个定长的消息头,真正的用户数据存放在`data.buffer`所指向的缓存区中.如果发送方在数据中嵌入了一个或多个Binder,接收到的数据包中同样会用`data.offsets`和`offset_size`指出每个Binder的位置和总个数. 不过通常接收方可以忽略这些信息,因为接收方是知道数据格式的,参考双方约定的格式定义就能知道这些Binder在什么位置.

## 5. Binder表述

考察一次Binder通信的全过程会发现,Binder存在于系统以下几个部分中:

- 应用程序进程: 分别位于Server进程和Client进程中
- Binder驱动: 分别管理为Server端的Binder实体和Client端的引用
- 传输数据: 由于Binder可以跨进程传递,需要在传输数据中予以表述

在系统不同部分,Binder实现的功能不同,表现形式也不一样.接下来逐一探讨Binder在各部分所扮演的角色和使用的数据结构.

### 5.1 Binder在应用程序中的表述



## 资料

- [为什么Android 要采用 Binder 作为 IPC 机制？](https://www.zhihu.com/question/39440766/answer/89210950)
- [Binder系列—开篇](http://gityuan.com/2015/10/31/binder-prepare/)
- [Android Binder设计与实现 - 设计篇](https://blog.csdn.net/universus/article/details/6211589)
- [Android跨进程通信：图文详解 Binder机制 原理](https://blog.csdn.net/carson_ho/article/details/73560642)
