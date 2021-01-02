

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

本文假设应用程序是用面向对象语言实现的.

Binder本质上只是一种底层通信方式,和具体服务没有关系.为了提供具体服务,Server必须提供一套接口函数以便Client通过远程访问使用各种服务.这时通常采用Proxy设计模式: 将接口函数定义在一个抽象类中,Server和Client都会以该抽象类为基类实现所有接口函数,所不同的是Server端是真正的功能实现,而Client端是对这些函数远程调用请求的包装.如何将Binder和Proxy设计模式结合起来是应用程序面向对象Binder通信的根本问题.

#### 5.1.1 Binder在Server端的表述 - Binder实体

作为Proxy设计模式的基础,首先定义一个抽象接口类封装Server所有功能,其中包含一系列纯虚函数留待Server和Proxy各自实现.由于这些函数需要跨进程调用,需为其一一编号,从而Server可以根据收到的编号决定调用哪个函数.其次就要引用Binder了.Server端定义另一个Binder抽象类(我理解就是IXX.Stub)处理来自Client的Binder请求数据包,其中最重要的成员是虚函数onTransact().该函数分析收到的数据包,调用相应的接口函数处理请求.

接下来采用继承方式以接口类和Binder抽象类为基类构建Binder在Server中的实体(我理解就是我们自己继承IXX.Stub写个类,然后onBind返回回去那里),实现基类里所有的虚函数,包括公共接口函数以及数据包处理函数: onTransact() (就是IXX.Stub里面的那个onTransact方法,如果是编写aidl的话,AS会自动生成onTransact方法,不用我们自己实现.当然,onTransact是有规律的,自己实现也是ok的). 这个函数的输入是来自Client的`binder_transaction_data`结构的数据包.前面提到,该结构里有个成员code,包含这次请求的接口函数编号.onTransact()将case-by-case地解析code值,从数据包里取出函数参数,调用接口类中相应的,已经实现的公共接口函数(调用时已经和Server处于同一进程了,这些公共接口函数的实现是在Server端).函数执行完毕,如果需要返回数据就再构建一个`binder_transaction_data`包将返回数据包填入其中.

那么各个Binder实体的onTransact()又是什么时候调用呢? 这就需要驱动参与了. 前面说过,Binder实体须要以Binder传输结构`flat_binder_object`形式发生给其他进程才能建立Binder通信,而Binder实体指针就存放在该结构的handle域中.驱动根据Binder位置数组从传输数据中获取该Binder的传输结构,为它创建位于内核中的Binder节点,将BInder实体指针记录在该节点中.如果接下来有其他进程向该Binder发送数据,驱动会根据节点中记录的信息将Binder实体指针填入`binder_transaction_data`的target.ptr中返回给接收线程.接收线程从数据包中取出该指针,`reinterpret_cast`成Binder抽象类并调用onTransact()函数.由于这是个虚函数,不同的Binder实体中有各自的实现,从而可以调用到不同Binder实体提供的onTransact().  

#### 5.1.2 Binder 在Client端的表述 - Binder引用

作为Proxy设计模式的一部分,Client端的Binder同样要继承Server提供的公共接口类并实现公共函数(IXX.Stub.Proxy).但这不是真正的实现,而是对远程函数调用的包装: 将函数参数打包,通过Binder向Server发送申请并等待返回值.为此Client端还要知道Binder实体的相关信息,即对Binder实体的引用(在onServiceConnected中拿到的).该引用是由ServiceManager转发过来的,对实名Binder的引用或是由另一个进程直接发送过来的对匿名Binder的引用.

举例: 

```java
private static class Proxy implements com.xfhy.allinone.ipc.aidl.IPersonManager {
    private android.os.IBinder mRemote;

    Proxy(android.os.IBinder remote) {
        mRemote = remote;
    }

    @Override
    public android.os.IBinder asBinder() {
        return mRemote;
    }

    public java.lang.String getInterfaceDescriptor() {
        return DESCRIPTOR;
    }

    @Override
    public java.util.List<com.xfhy.allinone.ipc.aidl.Person> getPersonList() throws android.os.RemoteException {
        android.os.Parcel _data = android.os.Parcel.obtain();
        android.os.Parcel _reply = android.os.Parcel.obtain();
        java.util.List<com.xfhy.allinone.ipc.aidl.Person> _result;
        try {
            _data.writeInterfaceToken(DESCRIPTOR);
            boolean _status = mRemote.transact(Stub.TRANSACTION_getPersonList, _data, _reply, 0);
            if (!_status && getDefaultImpl() != null) {
                return getDefaultImpl().getPersonList();
            }
            _reply.readException();
            _result = _reply.createTypedArrayList(com.xfhy.allinone.ipc.aidl.Person.CREATOR);
        } finally {
            _reply.recycle();
            _data.recycle();
        }
        return _result;
    }
}
```

由于继承了同样的公共接口类,Client Binder提供了与Server Binder一样的函数原型,使用户感觉不出Server是运行在本地还是远端.Client Binder中,公共接口函数的包装方式是: 创建一个`binder_transaction_data`数据包,将其对应的编码填入code域,将调用该函数所需的参数填入data.buffer指向的缓存中,并指明数据包的目的地,那就是已经获得的对Binder实体的引用,填入数据包的target.handle中.注意这里和Server的区别: 实际上target域是个联合体,包括ptr和handle两个成员,前者用于接收数据包的Server,指向Binder实体对应的内存空间;后者用于作为请求方的Client,存放Binder实体的引用,告知驱动数据包将路由给哪个实体.数据包准备好后,通过驱动接口发送出去.经过`BC_TRANSACTION/BC_REPLY`回合完成函数的远程调用并得到返回值.

### 5.2 Binder在传输数据中的表述

Binder可以塞在数据包的有效数据中越进程边界从一个进程传递给另一个进程,这些传输中的Binder用结构`flat_binder_object`表示,如下表所示:

<div style="width: 150pt">成员</div> | 含义
---|---
unsigned long type | 表明该Binder的类型，包括以下几种：BINDER_TYPE_BINDER：表示传递的是Binder实体，并且指向该实体的引用都是强类型；BINDER_TYPE_WEAK_BINDER：表示传递的是Binder实体，并且指向该实体的引用都是弱类型；BINDER_TYPE_HANDLE：表示传递的是Binder强类型的引用;BINDER_TYPE_WEAK_HANDLE：表示传递的是Binder弱类型的引用;BINDER_TYPE_FD：表示传递的是文件形式的Binder，详见下节.
unsigned long flags | 该域只对第一次传递Binder实体时有效，因为此刻驱动需要在内核中创建相应的实体节点，有些参数需要从该域取出：第0-7位：代码中用FLAT_BINDER_FLAG_PRIORITY_MASK取得，表示处理本实体请求数据包的线程的最低优先级。当一个应用程序提供多个实体时，可以通过该参数调整分配给各个实体的处理能力。第8位：代码中用FLAT_BINDER_FLAG_ACCEPTS_FDS取得，置1表示该实体可以接收其它进程发过来的文件形式的Binder。由于接收文件形式的Binder会在本进程中自动打开文件，有些Server可以用该标志禁止该功能，以防打开过多文件。
union {void *binder;signed long handle;}; | 当传递的是Binder实体时使用binder域，指向Binder实体在应用程序中的地址。当传递的是Binder引用时使用handle域，存放Binder在进程中的引用号。
void *cookie; | 该域只对Binder实体有效，存放与该Binder有关的附加信息。

无论是Binder实体还是对实体的引用都从属于某个进程,所以该结构不能透明地在进程之间传输,必须经过驱动翻译.例如当Server把Binder实体传递给Client时,在发送数据流中,`flat_binder_object`中的type是`BINDER_TYPE_BINDER`,binder指向Server进程用户空间地址.如果透传给接收端将毫无用处,驱动必须对数据流中的这个Binder做修改: 将type改成`BINDER_TYPE_HANDLE`;为这个Binder在接收进程中创建位于内核中的引用并将引用号填入handle中.对于发送数据流中引用类型的Binder也要做同样转换.经过处理后接收进程从数据流中取得的Binder引用才是有效的,才可以将其填入数据包`binder_transaction_data`的target.handle域,向Binder实体发送请求.

这样做是出于安全性考虑: 应用程序不能随便猜测一个引用号填入target.handle中就可以向Server请求服务了,因为驱动并没有为你在内核中创建该引用,必定会被驱动拒绝.唯有经过身份认证确认合法后,由"权威机构"亲手授予你的Binder才能使用,因为这时驱动已经在内核中为你使用该Binder做了注册,交给你的引用号是合法的.

下表总结了当`flat_binder_object`结构穿过驱动时驱动所做的操作：

<div style="width: 150pt">Binder类型(type域)</div> | 在发送方的操作 | 在接收方的操作
---|---|---
`BINDER_TYPE_BINDER`,`BINDER_TYPE_WEAK_BINDER` | 只有实体所在的进程能发送该类型的Binder。如果是第一次发送驱动将创建实体在内核中的节点，并保存binder，cookie，flag域。| 如果是第一次接收该Binder则创建实体在内核中的引用；将handle域替换为新建的引用号；将type域替换为BINDER_TYPE_(WEAK_)HANDLE
`BINDER_TYPE_HANDLE`,`BINDER_TYPE_WEAK_HANDLE` | 获得Binder引用的进程都能发送该类型Binder。驱动根据handle域提供的引用号查找建立在内核的引用。如果找到说明引用号合法，否则拒绝该发送请求。| 如果收到的Binder实体位于接收进程中：将ptr域替换为保存在节点中的binder值；cookie替换为保存在节点中的cookie值；type替换为`BINDER_TYPE_(WEAK_)BINDER`。如果收到的Binder实体不在接收进程中：如果是第一次接收则创建实体在内核中的引用；将handle域替换为新建的引用号
BINDER_TYPE_FD | 验证handle域中提供的打开文件号是否有效，无效则拒绝该发送请求。| 在接收方创建新的打开文件号并将其与提供的打开文件描述结构绑定。

#### 5.2.1 文件形式的Binder

除了通常意义上用来通信的Binder,还有一种特殊的Binder: 文件Binder.这种Binder的基本思想是: 将文件看成Binder实体,进程打开的文件号看成Binder的引用.一个进程可以将它打开文件的文件号传递给另一个进程,从而另一个进程也打开了同一个文件,就像Binder的引用在进程之间传递一样.

一个进程打开一个文件,就获得与该文件绑定的打开文件号.从Binder的角度,linux在内核创建的打开文件描述结构struct file是Binder的实体,打开文件号是该进程对该实体的引用.既然是Binder那么就可以在进程之间传递,故也可以用flat_binder_object结构将文件Binder通过数据包发送至其它进程,只是结构中type域的值为BINDER_TYPE_FD,表明该Binder是文件Binder.而结构中的handle域则存放文件在发送方进程中的打开文件号.我们知道打开文件号是个局限于某个进程的值,一旦跨进程就没有意义了.这一点和Binder实体用户指针或Binder引用号是一样的,若要跨进程同样需要驱动做转换.驱动在接收Binder的进程空间创建一个新的打开文件号,将它与已有的打开文件描述结构struct file勾连上,从此该Binder实体又多了一个引用.新建的打开文件号覆盖flat_binder_object中原来的文件号交给接收进程.接收进程利用它可以执行read(),write()等文件操作.

传个文件为啥要这么麻烦,直接将文件名用Binder传过去,接收方用open()打开不就行了吗？其实这还是有区别的.首先对同一个打开文件共享的层次不同：使用文件Binder打开的文件共享linux VFS中的struct file,struct dentry,struct inode结构,这意味着一个进程使用read()/write()/seek()改变了文件指针,另一个进程的文件指针也会改变；而如果两个进程分别使用同一文件名打开文件则有各自的struct file结构,从而各自独立维护文件指针,互不干扰.其次是一些特殊设备文件要求在struct file一级共享才能使用,例如android的另一个驱动ashmem,它和Binder一样也是misc设备,用以实现进程间的共享内存.一个进程打开的ashmem文件只有通过文件Binder发送到另一个进程才能实现内存共享,这大大提高了内存共享的安全性,道理和Binder增强了IPC的安全性是一样的.

### 5.3 Binder在驱动中的表述

驱动是Binder通信的核心,系统中所有的Binder实体以及每个实体在各个进程中的引用都登记在驱动中.驱动需要记录Binder引用->实体之间多对一的关系;为引用找到对应的实体;在某个进程中为实体创建或查找到对应的引用;记录Binder的归属地(位于哪个进程中);通过管理Binder强/弱引用来创建/销毁Binder实体等等.

驱动里的Binder是什么时候创建的呢?前面提到过,为了实现实名Binder的注册,系统必须创建第一只鸡-为ServiceManager创建的,用于注册实名Binder的Binder实体,负责实名Binder注册过程中的进程间通信.既然创建了实体就要有对应的引用: 驱动将所有进程的0号引用都预留给该Binder实体,即所有进程的0号引用天然地指向注册实名Binder专用的Binder,无须特殊操作既可以使用0号引用来注册实名Binder.

接下来随着应用程序不断地注册实名Binder,不断向ServiceManager索要Binder的引用,不断将Binder从一个进程传递给另一个进程,越来越多的Binder以传输结构-`flat_binder_object`的形式穿越驱动做跨进程的迁徙.由于`binder_transaction_data`中data.offset数组的存在,所有流经驱动的Binder都逃不过驱动的眼睛.Binder将这些穿越进程边界的Binder做如下操作: 检查传输结构的type域,如果是`BINDER_TYPE_BINDER`或`BINDER_TYPE_WEAK_BINDER`则创建Binder的实体;如果是`BINDER_TYPE_HANDLE`或`BINDER_TYPE_WEAK_HANDLE`则创建Binder的引用;如果是`BINDER_TYPE_HANDLE`则为进程打开文件,无须创建任何数据结构.随着越来越多的Binder实体或引用在进程间传递,驱动会在内核里创建越来越多的节点或引用,当然这个过程对用户来说是透明的.

#### 5.3.1 Binder实体在驱动中的表述

驱动中的Binder实体也叫"节点",隶属于提供实体的进程,由`struct binder_node`结构来表示:

<div style="width: 150pt">成员</div> | 含义
---|---
int debug_id; | 用于调试
struct binder_work work; | 当本节点引用计数发生改变，需要通知所属进程时，通过该成员挂入所属进程的to-do队列里，唤醒所属进程执行Binder实体引用计数的修改
union {struct rb_node rb_node;struct hlist_node dead_node;}; | 每个进程都维护一棵红黑树，以Binder实体在用户空间的指针，即本结构的ptr成员为索引存放该进程所有的Binder实体。这样驱动可以根据Binder实体在用户空间的指针很快找到其位于内核的节点。`rb_node`用于将本节点链入该红黑树中。销毁节点时须将`rb_node`从红黑树中摘除，但如果本节点还有引用没有切断，就用dead_node将节点隔离到另一个链表中，直到通知所有进程切断与该节点的引用后，该节点才可能被销毁。
struct binder_proc *proc; | 本成员指向节点所属的进程，即提供该节点的进程
struct hlist_head refs; | 本成员是队列头，所有指向本节点的引用都链接在该队列里。这些引用可能隶属于不同的进程。通过该队列可以遍历指向该节点的所有引用
int internal_strong_refs; | 用以实现强指针的计数器：产生一个指向本节点的强引用该计数就会加1
int local_weak_refs; | 驱动为传输中的Binder设置的弱引用计数。如果一个Binder打包在数据包中从一个进程发送到另一个进程，驱动会为该Binder增加引用计数，直到接收进程通过BC_FREE_BUFFER通知驱动释放该数据包的数据区为止。
int local_strong_refs; | 驱动为传输中的Binder设置的强引用计数。同上。
void __user *ptr; | 指向用户空间Binder实体的指针，来自于flat_binder_object的binder成员
void __user *cookie; | 指向用户空间的附加指针，来自于flat_binder_object的cookie成员
unsigned has_strong_ref;unsigned pending_strong_ref;unsigned has_weak_ref;unsigned pending_weak_ref | 这一组标志用于控制驱动与Binder实体所在进程交互式修改引用计数
unsigned has_async_transaction；| 该成员表明该节点在to-do队列中有异步交互尚未完成。驱动将所有发送往接收端的数据包暂存在接收进程或线程开辟的to-do队列里。对于异步交互，驱动做了适当流控：如果to-do队列里有异步交互尚待处理则该成员置1，这将导致新到的异步交互存放在本结构成员 – asynch_todo队列中，而不直接送到to-do队列里。目的是为同步交互让路，避免长时间阻塞发送端。
unsigned accept_fds | 表明节点是否同意接受文件方式的Binder，来自flat_binder_object中flags成员的FLAT_BINDER_FLAG_ACCEPTS_FDS位。由于接收文件Binder会为进程自动打开一个文件，占用有限的文件描述符，节点可以设置该位拒绝这种行为。
int min_priority | 设置处理Binder请求的线程的最低优先级。发送线程将数据提交给接收线程处理时，驱动会将发送线程的优先级也赋予接收线程，使得数据即使跨了进程也能以同样优先级得到处理。不过如果发送线程优先级过低，接收线程将以预设的最小值运行。该域的值来自于flat_binder_object中flags成员。
struct list_head async_todo | 异步交互等待队列；用于分流发往本节点的异步交互包

每个进程都有一颗红黑树用于存放创建好的节点,以Binder在用户空间的指针作为索引.每当在传输数据中侦测到一个代表Binder实体的`flat_binder_object`,先以该结构的binder指针为索引搜索红黑树;如果没找到就创建一个新节点添加到树中.由于对于同一个进程来说内存地址是唯一的,所以不会重复建设造成混乱.

#### 5.3.2 Binder引用在驱动中的表述

## 资料

- [为什么Android 要采用 Binder 作为 IPC 机制？](https://www.zhihu.com/question/39440766/answer/89210950)
- [Binder系列—开篇](http://gityuan.com/2015/10/31/binder-prepare/)
- [Android Binder设计与实现 - 设计篇](https://blog.csdn.net/universus/article/details/6211589)
- [Android跨进程通信：图文详解 Binder机制 原理](https://blog.csdn.net/carson_ho/article/details/73560642)
