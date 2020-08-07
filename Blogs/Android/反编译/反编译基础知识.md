
## !!! 严正声明

本文相关反编译技术仅限于技术研究使用,不能用于非法目的,否则后果自负.

## 1. apktool 逆向APK文件的工具

[官方网站](https://ibotpeaches.github.io/Apktool/)

apktool主要用于逆向apk文件,可以将资源解码,并在修改之后可以重新构建它们.它还可以用来重新构建apk.

### 1.1 功能

- 将资源解码成近乎原始的形式(包括resources.arsc, classes.dex, 9.png. 和 XMLs)
- 将解码的资源重新打包成apk/jar
- 组织和处理依赖于框架资源的APK
- Smali调试
- 执行自动化任务

[安装教程](https://ibotpeaches.github.io/Apktool/install/)

### 1.2 使用

- 逆向apk文件: `apktool d xx.apk`,逆向之后只能看到代码的smali格式文件,需要学习smali语法才能看懂.
- 重新打包: `apktool b xx`,打包出来的是没有签名的apk,需要签名才能安装

### 1.3 smali 语法

smali是Dalvik虚拟机指令语言. 当使用apktool反编译apk文件之后,会生成一个smali文件夹,里面是虚拟机需要执行的smali代码.smali语言的一些基本语法还是不复杂,可以简单了解下.万一需要看一下别人实现的炫酷的UI效果呢....顺手偷一段别人的代码,哈哈..不对,读书人的事情怎么能算偷呢?

下面是用apktool反编译之后的smali目录:

![smali](https://i.loli.net/2020/06/14/vzjeJDWHOLY7A3Z.png)

为了学习它的语法结构,先随便写一个Activity,代码如下:
```java
public class SmaliActivity extends AppCompatActivity {

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_smail);

        initView();
    }

    private void initView() {
        int num = 2 + 3;
        String name = "zhangsan";
        Log.w("xfhy666", "initView: num = " + num + "  name = " + name);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }
}
```

来看下它的smali代码如下:
```smali
# 这里简单介绍了类的名称,父类是谁
.class public Lcom/xfhy/allinone/smali/SmaliActivity;
.super Landroidx/appcompat/app/AppCompatActivity;
.source "SmaliActivity.java"

# direct methods 从这里开始的都是在当前类定义的方法
# .method 表示这是一个方法
# 这里定义的是当前类的不带参数缺省的构造方法,末尾的V表示方法返回类型是void
.method public constructor <init>()V
    # .locals 表示当前方法需要申请多少个寄存器
    .locals 0

    .line 16
    invoke-direct {p0}, Landroidx/appcompat/app/AppCompatActivity;-><init>()V

    return-void
.end method

.method private initView()V
    .locals 4

    .line 27
    const/4 v0, 0x5

    .line 28
    .local v0, "num":I
    const-string v1, "lisi"

    .line 29
    .local v1, "name":Ljava/lang/String;
    new-instance v2, Ljava/lang/StringBuilder;

    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V

    const-string v3, "initView: num = "

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2, v0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    const-string v3, "  name = "

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v2

    const-string v3, "xfhy666"

    invoke-static {v3, v2}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;)I

    .line 30
    return-void
.end method


# virtual methods  从这里开始的都是覆写父类的方法
.method protected onCreate(Landroid/os/Bundle;)V
    .locals 1
    .param p1, "savedInstanceState"    # Landroid/os/Bundle;

    .line 20
    invoke-super {p0, p1}, Landroidx/appcompat/app/AppCompatActivity;->onCreate(Landroid/os/Bundle;)V

    .line 21
    const v0, 0x7f0b001f

    invoke-virtual {p0, v0}, Lcom/xfhy/allinone/smali/SmaliActivity;->setContentView(I)V

    .line 23
    invoke-direct {p0}, Lcom/xfhy/allinone/smali/SmaliActivity;->initView()V

    .line 24
    return-void
.end method

.method protected onDestroy()V
    .locals 0

    .line 35
    invoke-super {p0}, Landroidx/appcompat/app/AppCompatActivity;->onDestroy()V

    .line 36
    return-void
.end method

```

可以看到,其实大部分smali语法我们是能够看懂的,外加一些猜测的话,能看懂60%左右.上面的这份smali代码就比Java代码多了一个缺省的构造方法.然后每个方法的开始是以`.method`开始的,以`.end method`结束.

smali语法简单过一下: 

[官方文档](https://source.android.com/devices/tech/dalvik/dalvik-bytecode)

Davlik字节码中,寄存器是32位,一般的类型用一个寄存器就够存了.只有64位类型的需要2个寄存器来存储,Long和Double就是64位类型的.

**原始数据类型**

类型表示 | 原始类型
---|---
v | void
Z | boolean
B | byte
S | short
C | char
I | int
J | long (64位)
F | float
D | double (64位)

**对象类型**

类型表示 | Java中的类型
---|---
Ljava/lang/String; | String
Landroid/os/Bundle; | Bundle

- 对象类型的前面会加一个L
- 末尾会加一个`;`
- 包名全路径,中间以`/`分隔

**数组**

类型表示 | Java中的类型
---|---
[I | int[]
`[[I` | `int[][]`
[Ljava/lang/String; | String[]

**方法定义**

类型表示 | Java中的表示
---|---
public getDouble()D | public double getDouble()
public getNum(ILjava/lang/String;Z)Ljava/lang/String; | public String getNum(int a,String b,boolean c)

eg:
```smali
.method public getDouble()D
    .locals 2

    .line 45
    const-wide/16 v0, 0x0

    return-wide v0
.end method
```

**字段定义**

类型表示 | Java中的表示
---|---
.field private num:I | private int num
.field public text:Ljava/lang/String; | public String text
.field private tvName:Landroid/widget/TextView; | private TextView tvName

可以看到在字段定义的前面会加一个关键字`.field`,然后修饰符+名称+`:`+类型.

**指定方法寄存器个数**

一个方法中需要多少个寄存器是需要指定好的.有2种方式

- `.registers` 指定方法寄存器总数
- `.locals` 表名方法中非参寄存器的总数,一般在方法的第一行

eg:
```smali
.method public getNum(ILjava/lang/String;Z)Ljava/lang/String;
    .registers 6
    .param p1, "a"    # I
    .param p2, "b"    # Ljava/lang/String;
    .param p3, "c"    # Z

    .prologue
    .line 40
    const/4 v0, 0x2

    .line 41
    .local v0, "num":I
    const-string v1, ""

    return-object v1
.end method

.method public getNum(ILjava/lang/String;Z)Ljava/lang/String;
    .locals 2
    .param p1, "a"    # I
    .param p2, "b"    # Ljava/lang/String;
    .param p3, "c"    # Z

    .line 40
    const/4 v0, 0x2

    .line 41
    .local v0, "num":I
    const-string v1, ""

    return-object v1
.end method

```

**方法传参**

方法的形参也会被存储于寄存器中,形参一般被放置于该方法的最后N个寄存器中(eg:形参是2个,那么该方法的最后2个寄存器就是拿来存储形参的). 值得注意的是,非静态方法隐含有一个this参数.

**寄存器命名方式**

命名方式有2种,v命名法(v0,v1...)和p命名法(p0,p1...)

来看一段smali代码加深一下印象

```smali
.method public getNum(ILjava/lang/String;Z)Ljava/lang/String;
    .locals 2
    .param p1, "a"    # I
    .param p2, "b"    # Ljava/lang/String;
    .param p3, "c"    # Z

    .line 40
    const/4 v0, 0x2

    .line 41
    .local v0, "num":I
    const-string v1, ""

    return-object v1
.end method
```

- 首先通过`.locals 2`表明该方法内有2个v寄存器.
- 然后定义了p1,p2,p3这3个寄存器,其实还有一个p0寄存器,p0表示`this`(即本身的引用,this指针).
- 这个方法里面既有v命名的,也有p命名的
- 只有v命名的寄存器需要在`.locals`处声明个数,而p命名的不需要

**标记**

标记 | 含义
---|---
# static fields | 定义静态变量
# instance fields | 定义实例变量
# direct methods | 定义静态方法
# virtual methods | 定义非静态方法

**控制条件**

语句 | 含义
---|---
`if-eq vA, vB, :cond_**` | `如果vA等于vB则跳转到:cond_**`
`if-nevA, vB, :cond_**` | 如果vA不等于vB则跳转到:cond_**
`if-ltvA, vB, :cond_**` | 如果vA小于vB则跳转到:cond_**
`if-gevA, vB, :cond_**` | 如果vA大于等于vB则跳转到:cond_**
`if-gtvA, vB, :cond_**` | 如果vA大于vB则跳转到:cond_**
`if-levA, vB, :cond_**` | 如果vA小于等于vB则跳转到:cond_**
`if-eqz vA, :cond_**` | 如果vA等于0则跳转到:cond_**
`if-nezvA, :cond_**` | 如果vA不等于0则跳转到:cond_**
`if-ltzvA, :cond_**` | 如果vA小于0则跳转到:cond_**
`if-gezvA, :cond_**` | 如果vA大于等于0则跳转到:cond_**
`if-gtzvA, :cond_**` | 如果vA大于0则跳转到:cond_**
`if-lezvA, :cond_**` | 如果vA小于等于0则跳转到:cond_**

这个很难记忆,建议需要用到的时候再回来查.

这里的z表示zero,可以是0,也可以是null,或者是false,具体看上下文环境.

### 1.4 Smali插桩(代码注入)

通过smali插桩,我们可以修改原有代码的走向,比如修改某个逻辑或者是修改某个app的展示文本,汉化等等.

简单举个例子让大家感受一下:

showText函数中有一个形参isVip,如果是true则跳过广告,如果是false,则观看广告.我现在想把这个isVip永远的改成true,那么我就永远跳过广告,哈哈....仅测试用..
```java
private void showText(boolean isVip) {
    if (isVip) {
        Toast.makeText(this, "Skip ad", Toast.LENGTH_SHORT).show();
    } else {
        Toast.makeText(this, "Watch ad", Toast.LENGTH_SHORT).show();
    }
}
```

上面的java代码对应的smali代码如下:

```smali
.method private showText(Z)V
    .locals 2
    .param p1, "isVip"    # Z

    .line 38
    const/4 v0, 0x0

    if-eqz p1, :cond_0  # 如果p1是true,那么跳过cond_0

    .line 39
    const-string v1, "Skip ad"

    invoke-static {p0, v1, v0}, Landroid/widget/Toast;->makeText(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;

    move-result-object v0

    invoke-virtual {v0}, Landroid/widget/Toast;->show()V

    goto :goto_0

    .line 41
    :cond_0
    const-string v1, "Watch ad"

    invoke-static {p0, v1, v0}, Landroid/widget/Toast;->makeText(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;

    move-result-object v0

    invoke-virtual {v0}, Landroid/widget/Toast;->show()V

    .line 43
    :goto_0
    return-void
.end method

```

上面的代码比较简单,我直接在`if-eqz`判断的前面将isVip改成true不就ok了么.

```smali
.method private showText(Z)V
    .locals 2
    .param p1, "isVip"    # Z

    const/4 p1, 0x1

    .line 38
    const/4 v0, 0x0

    if-eqz p1, :cond_0  
    ......
.end method
```

smali代码改好之后保存,然后用apktool工具,打包成apk : `apktool b apkFileName`. 

打包完成之后,是不能立即在Android手机上进行安装的,还需要签名.得去下载一个autosign,给这个apk签名,命令是`java -jar signapk.jar testkey.x509.pem testkey.pk8 update.apk update_signed.apk`. 打包好之后,运行到手机上,完美,toast输出的是Skip ad.插桩成功.

可以下载一个Android逆向助手,里面有autosign工具包. 下载地址如下:

链接:https://pan.baidu.com/s/1NW9PAyuar1dWeUfQBQEftg  密码:8nb7

## 2.dex2jar 

一个将dex转换成jar的工具,下载下来之后是一个压缩包,里面有很多工具.

![dex2jar](https://i.loli.net/2020/06/23/VtdnjN4OqABlPpX.png)

这些工具一看名字就知道是干啥的.

使用方式也比较简单,随便举个例子,命令行进入解压之后的文件夹,将待转成jar的dex(假设为classes.dex,拷贝到当前文件夹)准备好.让这些文件全部有执行权限,`chmod +x *`(Windows不需要).然后执行`./d2j-dex2jar.sh classes.dex`即可将dex转成jar(转出来的jar包名字是classes-dex2jar.jar),然后用jd-gui工具即可查看该jar中的class对应的java源码(和原始的源码不太一样哈).

下载地址: https://sourceforge.net/projects/dex2jar/

## 3. jd-gui

jd-gui是一款反编译软件,可以将查看jar中的class对应的java代码.使用方式: 直接将jar文件拖入jd-gui即可,查看里面的class对应的java代码.

![jd-gui](https://i.loli.net/2020/06/24/AbPTc9nv6g5Cf4q.png)

jd-gui github : https://github.com/java-decompiler/jd-gui

## 4. jadx

jadx github : https://github.com/skylot/jadx

需要下载jadx的直接到GitHub页面下载最新的Relase包.

jadx就更厉害了,直接将apk文件将其拖入.可得到如下信息:

- 签名的详细信息(类型,版本,主题,签名算法,MD5,SHA-1,SHA-256等等)
- 所有资源文件(比如layout布局文件都是反编译了的,可以直接查看)
- 所有class对应的java代码(未加壳的才行),java代码对应的smali代码也能看.
- so文件

![jadx界面](https://i.loli.net/2020/06/24/GJhQ91B3wUdRioS.png)

据说,jadx是史上最好用的反编译软件,从使用上来看,确实是这样,操作简单.除了上面提到的功能点外,还有些你可能更喜欢的,比如:

- 导出Gradle工程
- 反混淆
- 代码跳转(Ctrl+鼠标左键)
- 全局搜索文本

有了jadx我感觉其实可以不用上面的那些工具了,这个已经有上面的那些工具的功能了.


## 5. 脱壳

说到脱壳,这里简单介绍几个工具

- Xposed 框架
- VirtualXposed 
- FDex2 

如果手机已经root,则选择Xposed框架+FDex2.
如果手机没有root,则选择VirtualXposed+FDex2.

### 5.1 Xposed 框架

首先我们得知道什么是Xposed框架? 

维基百科: Xposed框架（Xposed framework）是一套开放源代码的、在Android高权限模式下运行的框架服务，可以在不修改APK文件的情况下修改程序的运行（修改系统），基于它可以制作出许多功能强大的模块，且在功能不冲突的情况下同时运作。这套框架需要设备解锁了Bootloader方可安装使用（root为解锁Bootloader的充分不必要条件，而xposed安装仅需通过TWRP等第三方Recovery卡刷安装包而不需要设备拥有完整的root权限）。

Xposed框架非常非常牛皮,可以安装各种插件(xposed插件,这里有很多 https://www.xda.im/),比如自动抢红包、防撤回、步数修改等等各种骚操作.就是Xpose框架的安装非常麻烦.安装教程这里就不说了,每个手机可能不太一样.我记得我的手机当时解锁BootLoader,刷机啥的,麻烦.

传统的Xposed框架只支持到Android N,后续的Android版本可以使用[EdXposed](https://github.com/ElderDrivers/EdXposed)替代.

### 5.2 VirtualXposed

> 官网: https://vxposed.com/

VirtualXposed也非常牛逼,它看起来提供了一个虚拟的安卓环境,但它其实是一个app.它提供Xposed框架环境,而不需要将手机root,不需要解锁BootLoader,也不需要刷机.Xposed模块提供了超多应用、游戏的辅助,但是苦于Xposed框架安装的麻烦很多用户只能放弃,VirtualXposed最新版让用户可以非常方便地使用各种Xposed模块.

### 5.3 FDex2

FDex2是Xposed的一个插件,用来从运行中的app中导出dex文件的工具.

使用:首先安装FDex2这个apk,然后在Xposed框架中勾选这个插件,然后手机重启.进入FDex2,点击需要脱壳的应用,然后FDex2会展示该app脱壳之后的dex输出目录.然后去运行那个需要脱壳的app,就可以获得该app对应的dex.然后导出dex到电脑上,用jadx查看反编译的代码.

当然,FDex2不一定能成功.

## 6. 开发者助手

这个工具特别厉害,但是大部分功能是需要root权限才能使用的.主要功能如下:

- 实时查看任何应用数据库和SP
- 网络请求信息
- log输出
- 当前Activity或者Fragment
- 界面资源分析(可以查看那个控件是什么做的)

apk酷安下载地址: https://www.coolapk.com/apk/com.toshiba_dealin.developerhelper

从应用详情里面看到,开发者助手还有电脑版本,功能也不少

- 支持了大部分手机版开发者助手的功能
- 支持截图到电脑
- 支持全局debug开启 (动态调试用)
- 支持进程优先级查看
- 更稳定的当前包名/activity名/fragment名获取

开发者助手电脑版下载链接：https://pan.baidu.com/s/1MFagBWVbR1xNDMakWUlv5g
提取码：l4hv

## 7. 其他

大概的工具就是上面这些了,勉强够用了.还有些其他的工具我也一并放入下面的下载链接里面了.

链接:https://pan.baidu.com/s/1kuoJ83vob13SM971mIwrmw  密码:lc6p

这里有一个库,里面关于安卓应用的安全和破解讲解的很全面,喜欢的可以去看看. https://github.com/crifan/android_app_security_crack

## 参考资料

- [ApkTool官网](https://ibotpeaches.github.io/Apktool/)
- [Smali--Dalvik虚拟机指令语言-->【android_smali语法学习一】](https://blog.csdn.net/wdaming1986/article/details/8299996)
- [关于smali插桩](https://www.cnblogs.com/wangaohui/p/5071647.html)
- [安卓从开发到逆向（四），smali插桩](https://blog.csdn.net/wy450120127/article/details/101280797)
- [android逆向分析之smali语法](https://blog.csdn.net/L25000/article/details/46842013)
- [Xposed框架-维基百科](https://zh.wikipedia.org/wiki/Xposed_(%E6%A1%86%E6%9E%B6))