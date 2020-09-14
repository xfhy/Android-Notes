
> 文中相关工具下载链接：https://pan.baidu.com/s/1_bknFSnsYxLUNJ3WTulEFA 提取码：4qo8

### 1. 反编译基操

#### 1.1 借鉴code

一般来说,如果只是想借鉴一下友商的code,我们只需要拿到对方的apk,拖到jadx里面就行.jadx能查看apk的xml布局和java代码.jadx有时候会出现部分class反编译失败的情况,这时可以试试Bytecode-Viewer,它也能反编译,
而且还能反编译出jadx不能反编译的class.但是如果apk是已加固了的,那么jadx是不能查看代码的.这时需要脱壳,然后再进行反编译.

#### 1.2 修改执行逻辑

如果是想修改程序的执行逻辑,则需要修改smali代码.

如何拿smali代码?
这时需要用到apktool,使用命令:`apktool d xx.apk`即可将apk逆向完成,拿到smali代码.这里如果反编译失败了且报错`org.jf.dexlib2.dexbacked.DexBackedDexFile$NotADexFile: Not a valid dex magic value: cf 77 4c c7 9b 21 01 cd`,则试试`apktool d xx.apk -o xx --only-main-classes`这条命令.

然后用VS Code打开,这里最好在VS Code里面装一个`Smali`插件,用于在VS Code里面支持smali语法,高亮之类的.完成之后大概是这个样子:

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/20200909163611.png)

环境倒是OK了,回到正题,我们需要修改执行逻辑.在此之前,我们最好先简单学习一下smali的基本语法,详情见我之前写过的文章[反编译基础知识](https://blog.csdn.net/xfhy_/article/details/107026357).

修改好逻辑之后,我们需要将这些代码重新打包成apk,此时需要用到apktool,执行:`apktool b xx`.执行完成之后,输出的apk会在`xx/dist`目录下.它打包出来的是没有签名的apk,需要签名才能安装.

签名需要用到autosign这个工具包,使用命令`java -jar signapk.jar testkey.x509.pem testkey.pk8 debug.apk debug_signed.apk`

### 2. 加日志

有时候,你可能需要在修改原有执行逻辑之后,在代码里面加点日志,方便查看打出来的包逻辑是否正确.这里我摸索出一个简单的方式打日志,写一个日志打印工具类,然后将这个工具类转成smali文件,然后放入apk反编译出来的smali代码文件夹中,
之后就可以在这个项目的任何smali中使用这个工具类了.下面详细介绍一下:

#### 2.1 写日志打印工具类LogUtil

这个日志打印工具类是为了外界方便调用的,所以需要让外界调用的时候尽量简单.下面是我简单实现的工具类,tag都是我定义好了的,免得外面再定义一次(麻烦).

```java
public class LogUtil {

    public static void logNoTrace(String str) {
        Log.d("xfhy888", str);
    }

    public static void test() {
        logNoTrace("大撒大撒大撒");
    }

}
```

#### 2.2 打印调用栈

上面的工具类目前只能打印普通的日志,但是有时我们想在打印日志的同时输出这个地方的调用栈,此时我们再加个方法扩展一下.

```java
public static void log(String str) {
        Log.d("xfhy888", str);

        Throwable throwable = new Throwable();
        StackTraceElement[] stackElements = throwable.getStackTrace();
        StringBuilder stringBuilder = new StringBuilder();
        if (stackElements != null) {
            for (StackTraceElement stackElement : stackElements) {
                stringBuilder.append(stackElement.getClassName()).append(" ");
                stringBuilder.append(stackElement.getFileName()).append(" ");
                stringBuilder.append(stackElement.getMethodName()).append(" ");
                stringBuilder.append(stackElement.getLineNumber()).append("\n");
            }
        }
        Log.d("xfhy888", stringBuilder.toString());
    }
```

在log方法中我们手工构建了一个Throwable,然后通过其getStackTrace方法即可得到调用栈信息,通过Log打印出来.效果如下:

```
12817-12817/com.xfhy.demo D/xfhy888: com.xfhy.LogUtil LogUtil.java log 10
com.xfhy.startactivitydemo.MainActivity$1 MainActivity.java onClick 45
android.view.View View.java performClick 6724
android.view.View View.java performClickInternal 6682
android.view.View View.java access$3400 797
android.view.View$PerformClick View.java run 26472
android.os.Handler Handler.java handleCallback 873
android.os.Handler Handler.java dispatchMessage 99
android.os.Looper Looper.java loop 233
android.app.ActivityThread ActivityThread.java main 7210
java.lang.reflect.Method Method.java invoke -2
com.android.internal.os.RuntimeInit$MethodAndArgsCaller RuntimeInit.java run 499
com.android.internal.os.ZygoteInit ZygoteInit.java main 956
```

#### 2.3 将工具类转smali

在Android Studio里面写好这个工具类之后,装一个`java2smali`插件.然后选中LogUtil文件,再依次点击`Build->Compile to Smali`,即可将LogUtil.java转成smali.下面是我转好的
```smali
.class public Lcom/xfhy/LogUtil;
.super Ljava/lang/Object;
.source "LogUtil.java"


# direct methods
.method public constructor <init>()V
    .registers 1

    .prologue
    .line 5
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method

.method public static log(Ljava/lang/String;)V
    .registers 9
    .param p0, "str"    # Ljava/lang/String;

    .prologue
    .line 8
    const-string v4, "xfhy888"

    invoke-static {v4, p0}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I

    .line 10
    new-instance v3, Ljava/lang/Throwable;

    invoke-direct {v3}, Ljava/lang/Throwable;-><init>()V

    .line 11
    .local v3, "throwable":Ljava/lang/Throwable;
    invoke-virtual {v3}, Ljava/lang/Throwable;->getStackTrace()[Ljava/lang/StackTraceElement;

    move-result-object v1

    .line 12
    .local v1, "stackElements":[Ljava/lang/StackTraceElement;
    new-instance v2, Ljava/lang/StringBuilder;

    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V

    .line 13
    .local v2, "stringBuilder":Ljava/lang/StringBuilder;
    if-eqz v1, :cond_52

    .line 14
    array-length v5, v1

    const/4 v4, 0x0

    :goto_17
    if-ge v4, v5, :cond_52

    aget-object v0, v1, v4

    .line 15
    .local v0, "stackElement":Ljava/lang/StackTraceElement;
    invoke-virtual {v0}, Ljava/lang/StackTraceElement;->getClassName()Ljava/lang/String;

    move-result-object v6

    invoke-virtual {v2, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v6

    const-string v7, " "

    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    .line 16
    invoke-virtual {v0}, Ljava/lang/StackTraceElement;->getFileName()Ljava/lang/String;

    move-result-object v6

    invoke-virtual {v2, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v6

    const-string v7, " "

    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    .line 17
    invoke-virtual {v0}, Ljava/lang/StackTraceElement;->getMethodName()Ljava/lang/String;

    move-result-object v6

    invoke-virtual {v2, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v6

    const-string v7, " "

    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    .line 18
    invoke-virtual {v0}, Ljava/lang/StackTraceElement;->getLineNumber()I

    move-result v6

    invoke-virtual {v2, v6}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v6

    const-string v7, "\n"

    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    .line 14
    add-int/lit8 v4, v4, 0x1

    goto :goto_17

    .line 21
    .end local v0    # "stackElement":Ljava/lang/StackTraceElement;
    :cond_52
    const-string v4, "xfhy888"

    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v5

    invoke-static {v4, v5}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I

    .line 22
    return-void
.end method

.method public static logNoTrace(Ljava/lang/String;)V
    .registers 2
    .param p0, "str"    # Ljava/lang/String;

    .prologue
    .line 25
    const-string v0, "xfhy888"

    invoke-static {v0, p0}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I

    .line 26
    return-void
.end method

```

有了编译好的smali文件,还需要放到反编译项目的对应包名里面,我这里的是`com/xfhy/`,那我就得放到这个目录下.

#### 2.4 使用工具类

这里我随便写个方法测试一下,java代码如下:

```java
public void test() {
    for (int i = 0; i < 10; i++) {
        System.out.println(i);
    }
}
```

它所对应的smali代码如下:
```smali
.method public test()V
    .registers 3

    .prologue
    .line 29
    const/4 v0, 0x0

    .local v0, "i":I
    :goto_1
    const/16 v1, 0xa

    if-ge v0, v1, :cond_d

    .line 30
    sget-object v1, Ljava/lang/System;->out:Ljava/io/PrintStream;

    invoke-virtual {v1, v0}, Ljava/io/PrintStream;->println(I)V

    .line 29
    add-int/lit8 v0, v0, 0x1

    goto :goto_1

    .line 32
    :cond_d
    return-void
.end method
```

我在方法的一开始就打印一句日志,首先加registers个数+1,因为需要新定义一个变量来存字符串,然后再调用LogUtil的静态方法打印这个字符串.
```smali
.method public test()V
    .registers 4

    const-string v2, "test method"

    invoke-static {v2}, Lcom/xfhy/LogUtil;->log(Ljava/lang/String;)V

    .prologue
    .line 29
    const/4 v0, 0x0

    .local v0, "i":I
    :goto_1
    const/16 v1, 0xa

    if-ge v0, v1, :cond_d

    .line 30
    sget-object v1, Ljava/lang/System;->out:Ljava/io/PrintStream;

    invoke-virtual {v1, v0}, Ljava/io/PrintStream;->println(I)V

    .line 29
    add-int/lit8 v0, v0, 0x1

    goto :goto_1

    .line 32
    :cond_d
    return-void
.end method
```

### 3. 调试smali

我们不能直接调试反编译拿到的java代码,而是只能调试反编译拿到的smali代码.当然,调试的时候,需要懂一些smali的基本语法,这样的话,基本能看懂程序在干嘛.

#### 3.1 让App可以调试

首先是让App可以调试

1. 可以修改AndroidManifest.xml中的debuggable改为true(具体操作:先用apktool反编译,再修改AndroidManifest,再打包签名,运行到手机上);
2. 也可以使用[XDebug](https://github.com/deskid/XDebug) 让所有进程处于可以被调试的状态;

#### 3.2 如何调试?

首先是在Android Studio里装一个smalidea的插件,我上面分享的网盘地址里面有.我试了下,smalidea是不支持最新版的Android Studio的.我去查了下,smalidea最后一个版本是0.05,
最后更新时间是2017-03-31。确实有点老了,我看18年年末的时候有人在博客中提到了这个插件,于是我想了下,同时期的Android Studio肯定可以用这个插件. 在Android Studio官网一顿乱串之后发现,
官网提供了历史版本的[下载地址](https://developer.android.google.cn/studio/archive#android-studio-3-0?utm_source=androiddevtools&utm_medium=website).
最后下载了一个2018年10月11日的Android 3.2.1,装上插件试了下->可行->完美.

把apktool反编译好的文件夹导入Android Studio,把所有smali开头的文件夹都标记一下Sources Root(标记方法: 文件夹右键,Mark Directory as -> Sources Root).然后找到你需要调试的类,打好断点.

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/smalidea%E6%89%93%E6%96%AD%E7%82%B9.png)

打开需要调试的App,然后打开Android Device Monitor(在`SDK\tools`里面).打开Monitor的时候需要关闭Android Studio.

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/Monitor%E7%AB%AF%E5%8F%A3%E5%8F%B7.png)

查看该App对应的端口是多少,记录下来.重新打开Android Studio,编辑`Edit Configurations`,点击`Add New Configuration`,添加之后再修改一下端口号就行,这里的端口号填上面Monitor看到的那个端口号.

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/ConfigurationPort.png)

Configuration添加好之后,点击Debug按钮即可进行调试.

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/smalidea%E8%B0%83%E8%AF%95.png)

熟悉的界面,熟悉的调试方式,开始愉快的调试吧,起飞~

### 4. 小结

这次反编译实战环节告一段落,内容不多,但是都是用得上的小技巧.
