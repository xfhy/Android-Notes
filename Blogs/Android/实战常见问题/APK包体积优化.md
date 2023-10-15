
### apk构成

- assets文件夹   存放一些配置文件,资源文件,assets不会自动生成对应的ID,而是通过AssetManager类的接口获取
- res目录  res是resource的缩写,这个目录存放资源文件,会自动生成对应的ID并映射到.R文件中,访问直接使用资源ID
- META-INF  保存应用的签名信息,签名信息可以验证APK文件的完整性
- AndroidManifest.xml 这个文件用来描述Android应用的配置信息,一些组件的注册信息,可使用权限等.
- classes.dex Dalvik字节码程序,让Dalvik虚拟机可执行,一般情况下,Android应用在打包时通过Android SDK中的dx工具将Java字节码转换为Dalvik字节码.
- resources.arsc 记录着资源文件和资源ID之间的映射关系,用来根据资源ID寻找资源.

### 安装包监控

1. Android Studio自带的APK Analyser，它是一个APK分析工具，在AS里面双击apk即可查看apk里面的内容，比如各个资源的大小、代码分包情况、smali源码、清单文件内容等等。根据各个资源的大小，我们就能把apk里面较大的文件找出来，比如某些图片太大了，通过这种方式很容易就找出来了。
2. Matrix中的ApkChecker，它是Matrix的一部分，主要是用来对安装包进行分析检测，并输出较为详细的检测结果报告。除具备 APKAnalyzer 的功能外，还支持统计 APK 中包含的 R 类、检查是否有多个动态库静态链接了 STL 、搜索 APK 中包含的无用资源，以及支持自定义检查规则等。

### 安装包优化

1. 混淆，减小dex文件的大小
2. 尽量使用vsg。如果UI不能提供SVG，那么webp也勉强可以。如果之前已经有很多png图片，则可以用AS批量转成webp，体积将减少特别多。
3. 利用lint删除无用资源和代码
4. 如果只支持中文，则可以用resConfigs限制一下只将中文的国际化资源文件打包进去
5. 动画尽量用代码实现，别用gif或者帧动画，占体积
6. 少引入三方库，减少代码
7. App Bundle，实际上一台手机设备只会用到apk中的一套资源（drawable、so等）。而谷歌的 Dynamic Delivery 功能就天然地解决了这个问题，通过 Google Play Store 安装 APK 时，会根据安装设备的属性，只选取相应的资源打包到 APK 文件中。
8. release打包时，shrinkResources设置为true。当其为true时，表示在编译时自动移除没有引用到的资源文件，主要包括layout布局文件和drawable图片文件。其处理方式保留文件，但内容置空。需要注意，在某些情况下，这个参数可能导致资源加载失败。在项目中使用了反射机制来加载图片或布局，如果刚好这些资源文件没有被其他方式引用的话，那这些资源就会被误判，而被置空。如何敌敌？自定义要保留的资源就行：在项目中创建一个包含<resources>标记的xml文件（一般是res/raw/keep.xml），并在tools:keep属性中指定每个要保留的资源(以逗号分隔)，在tools：discard属性中指定每个要舍弃的资源。

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@layout/l_used*_c,@layout/l_used_a,@layout/l_used_b*"
    tools:discard="@layout/unused2" />
```

9. release打包时，将minifyEnabled设置为true。移除所有不使用的代码，可以在ProGuard 规则文件中keep或者使用@Keep注解保留那些你需要留下来的类。比如某些方法是JNI调用的，而Java中未使用到此方法，就默认会被移除。
10. 重用资源: 比如一个三角按钮，点击前三角朝上代表收起的意思,点击后三角朝下，代表展开，一般情况下，我们会用两张图来切换，我们其实完全可以用旋转的形式去改变。
11. 同一图像的着色不同,我们可以用android:tint和tintMode属性，低版本可以使用ColorFilter
12. 插件化：将功能模块放服务器上，按需下载，可以减少安装包大小
13. R文件瘦身


### 参考资料

- [Google Developers - 缩减、混淆处理和优化应用](https://developer.android.com/studio/build/shrink-code?hl=zh-cn#shrink-code)