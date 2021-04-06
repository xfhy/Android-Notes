
先来看下[官网](https://developer.android.com/studio/build/index.html?hl=zh-cn#build-process)最新构建流程,比较简约.但是隐藏了很多过程.

![典型 Android 应用模块的构建流程](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/%E5%85%B8%E5%9E%8BAndroid%E5%BA%94%E7%94%A8%E6%A8%A1%E5%9D%97%E7%9A%84%E6%9E%84%E5%BB%BA%E6%B5%81%E7%A8%8B.png)

1. 编译器将您的源代码转换成 DEX（Dalvik Executable) 文件（其中包括运行在 Android 设备上的字节码），将所有其他内容转换成已编译资源。
2. APK 打包器将 DEX 文件和已编译资源合并成单个 APK。不过，必须先签署 APK，才能将应用安装并部署到 Android 设备上。
3. APK 打包器使用调试或发布密钥库签署您的 APK：
    a. 如果您构建的是调试版本的应用（即专用于测试和分析的应用），打包器会使用调试密钥库签署您的应用。Android Studio 自动使用调试密钥库配置新项目。
    b. 如果您构建的是打算向外发布的发布版本应用，打包器会使用发布密钥库签署您的应用。要创建发布密钥库，请阅读在 Android Studio 中签署您的应用
4. 在生成最终 APK 之前，打包器会使用 zipalign 工具对应用进行优化，减少其在设备上运行时的内存占用。

以下是官网的老图,构建过程
![老版本构建流程](https://s1.ax1x.com/2020/07/30/aM3qWd.png)

打包过程大概概括为以下几步:

1. 通过aapt打包res资源文件,生成R.java、resources.arsc和res文件(二进制&非二进制如res/raw和pic保持原样)。resources.arsc保存的是一个资源索引表，可以理解为一个map映射表，map的key是R.java中的资源ID，而value就是其对应的资源所在路径；R.java定义了各个资源ID常量，这两者结合就可以在代码中找到对应的资源引用。
2. 处理.aidl文件,生成对应的Java接口文件
3. 通过Java Compiler编译R.java、Java接口文件、Java源文件,生成.class文件
4. 通过dx工具,将.class文件和第三方库中的.class文件处理生成classes.dex
5. 通过apkbuilder工具,将aapt生成的resources.arsc和res文件、assets文件、动态库`.so`文件、`AndroidManifest.xml` 清单文件和classes.dex一起打包生成apk
6. 通过jarsigner对上面的apk进行debug或者release签名
7. 通过zipalign工具,将签名后的apk进行对齐处理

