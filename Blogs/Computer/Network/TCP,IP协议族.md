### TCP/IP协议族

概念：一系列协议所组成的一个网络分层模型

为什么要分层？因为网络的不稳定性

具体分层：

- 应用层（Application Layer）：HTTP、FTP、DNS
- 传输层（Transport Layer ）：
- 网络层（Internet Layer）：
- 数据链路层（Link Layer）：


层 | 英文名 | 协议 | 备注
---|---|---|---
应用层 | Application Layer | HTTP、FTP、DNS | 给出需要传输的数据
传输层 | Transport Layer | TCP、UDP | 将需要传输的数据分块，然后交给网络层，重传也是这里负责
网络层 | Internet Layer | IP | 负责传输，路由、寻址什么的
数据链路层 | Link Layer | 以太网、WiFi | 

### TCP连接

#### 什么叫做连接

这里的连接是TCP连接，必须先建立连接，双方才能发送消息，不然不认识你，就会把你的消息丢掉。

#### TCP连接的建立与关闭

##### 3次握手



##### 4次挥手

#### 长连接

##### 为什么要长连接
##### 长连接的实现方式