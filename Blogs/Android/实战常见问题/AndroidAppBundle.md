
## 1. Android App Bundle 是什么？

从 2021 年 8 月起，新应用需要使用 Android App Bundle 才能在 Google Play 中发布。

Android App Bundle是一种发布格式，打包出来的格式为aab，而之前我们打包出来的格式为apk。编写完代码之后，将其打包成aab格式（里面包含了所有经过编译的代码和资源），然后上传到Google Play。用户最后安装的还是apk，只不过不是一个，而是多个apk，这些apk是Google Play根据App Bundle生成的。

既然已经有了apk，那要App Bundle有啥用？咱之前打一个apk，会把各种架构、各种语言、各种分辨率的图片等全部放入一个apk中，但具体到某个用户的设备上，这个设备只需要一种so库架构、一种语言、一种分辨率的图片，那其他的东西都在apk里面，这就有点浪费了，不仅下载需要更多的流量，而且还占用用户设备更多的存储空间。当然，也可以通过在打包的时候打多个apk，分别支持各种密度、架构、语言的设备，但这太麻烦了。

于是，Google Play出手了。

App Bundle是经过签名的二进制文件，可将应用的代码和资源组织到不同的模块中。比如，当某个用户的设备是`xxhdpi+arm64-v8a+values-zh`环境，那Google Play后台会利用App Bundle中的对应的模块(`xxhdpi+arm64-v8a+values-zh`)组装起来，组成一个base apk和多个配置apk供该用户下载并安装，而不会去把其他的像`armeabi-v7a`、`x86`之类的与当前设备无关的东西组装进apk，这样用户下载的apk体积就会小很多。体积越小，转化率越高，也更环保。

有了Android App Bundle之后，Google Play还提供了2个东西：[Play Feature Delivery](https://developer.android.google.cn/guide/playcore/feature-delivery?hl=zh-cn) 和 [Play Asset Delivery](https://developer.android.google.cn/guide/playcore/asset-delivery?hl=zh-cn)。Play Feature Delivery可以按某种条件分发或按需下载应用的某些功能，从而进一步减小包体积。Play Asset Delivery是Google Play用于分发大体积应用的解决方案，为开发者提供了灵活的分发方式和极高的性能。

## 2. Android App Bundle打包

打Android App Bundle非常简单，直接通过Android Studio就能很方便地打包，当然命令行也可以的。

- Android Studio打包：`Build` -> `Generate Signed Bundle / APK` -> 选中Android App Bundle -> 选中签名和输入密码 -> 选中debug或者release包 -> finish开始打包
- gradle命令行打包：`./gradlew bundleDebug` 或者 `./gradlew bundleRelease`

打出来之后是一个类似`app-debug.aab`的文件，可以将aab文件直接拖入Android Studio进行分析和查看其内部结构，很方便。

## 3. 如何测试Android App Bundle？

Android App Bundle包倒是打出来了，那怎么进行测试呢？我们设备上仅允许安装apk文件，aab是不能直接进行安装的。这里官方提供了3种方式可供选择：Android Studio 、Google Play 和 bundletool，下面我们一一来介绍。

### 3.1 Android Studio

利用Android Studio，在我们平时开发时就可以直接将项目打包成debug的aab并且运行到设备上，只需要点一下运行按钮即可（当然，这之前需要一些简单的配置才行）。Android Studio和Google Play使用相同的工具从aab中提取apk并将其安装在设备上，因此这种本地测试策略也是可行的。这种方式可以验证以下几点：

- 该项目是否可以构建为app bundle
- Android Studio是否能够从app bundle中提取目标设备配置的apk
- 功能模块的功能与应用的基本模块是否兼容
- 该项目是否可以在目标设备上按预期运行

默认情况下，设备连接上Android Studio之后，运行时打的包是apk。所以我们需要配置一下，改成运行时先打app bundle，然后再从app bundle中提取出该设备需要的配置apk，再组装成一个新的apk并签名，随后安装到设备上。具体配置步骤如下：

1. 从菜单栏中依次选择 Run -> Edit Configurations。
2. 从左侧窗格中选择一项运行/调试配置。
3. 在右侧窗格中，选择 General 标签页。
4. 从 Deploy 旁边的下拉菜单中选择 APK from app bundle。
5. 如果你的应用包含要测试的免安装应用体验，请选中 Deploy as an instant app 旁边的复选框。
6. 如果你的应用包含功能模块，你可以通过选中每个模块旁边的复选框来选择要部署的模块。默认情况下，Android Studio 会部署所有功能模块，并且始终都会部署基本应用模块。
7. 点击 Apply 或 OK。

好了，现在已经配置好了，现在点击运行按钮，Android Studio会构建app bundle，并使用它来仅部署连接的设备及你选择的功能模块所需要的apk。

### 3.2 bundletool

bundletool 是一种命令行工具，谷歌开源的，Android Studio、Android Gradle 插件和 Google Play 使用这一工具将应用的经过编译的代码和资源转换为 App Bundle，并根据这些 Bundle 生成可部署的 APK。

前面使用Android Studio来测试app bundle比较方便，但是，官方推荐使用bundletool 从 app bundle 将应用部署到连接的设备。因为bundletool提供了专门为了帮助你测试app bundle并模拟通过Google Play分发而设计的命令，这样的话我们就不必上传到Google Play管理中心去测试了。

下面我们就来实验一把。

1. 首先是下载bundletool，到GitHub上去下载bundletool，地址：https://github.com/google/bundletool/releases
2. 然后通过Android Studio或者Gradle将项目打包成Android App Bundle，然后通过bundletool将Android App Bundle生成一个apk容器（官方称之为split APKs），这个容器以`.apks`作为文件扩展名，这个容器里面包含了该应用支持的所有设备配置的一组apk。这么说可能不太好懂，我们实操一下：

```
//使用debug签名生成apk容器
java -jar bundletool-all-1.14.0.jar build-apks --bundle=app-release.aab --output=my_app.apks

//使用自己的签名生成apk容器
java -jar bundletool-all-1.14.0.jar build-apks --bundle=app-release.aab --output=my_app.apks
--ks=keystore.jks
--ks-pass=file:keystore.pwd
--ks-key-alias=MyKeyAlias
--key-pass=file:key.pwd
```

> ps: build-apks命令是用来打apks容器的，它有很多可选参数，比如这里的`--bundle=path`表示：指定你的 app bundle 的路径，`--output=path`表示：指定输出 `.apks` 文件的名称，该文件中包含了应用的所有 APK 零部件。它的其他参数大家感兴趣可以到[bundletool](https://developer.android.google.cn/studio/command-line/bundletool?hl=zh-cn)查阅。

执行完命令之后，会生成一个`my_app.apks`的文件，我们可以把这个apks文件解压出来，看看里面有什么。

```
│ toc.pb
│
└─splits
        base-af.apk
        base-am.apk
        base-ar.apk
        base-as.apk
        base-az.apk
        base-be.apk
        base-bg.apk
        base-bn.apk
        base-bs.apk
        base-ca.apk
        base-cs.apk
        base-da.apk
        base-de.apk
        base-el.apk
        base-en.apk
        base-es.apk
        base-et.apk
        base-eu.apk
        base-fa.apk
        base-fi.apk
        base-fr.apk
        base-gl.apk
        base-gu.apk
        base-hdpi.apk
        base-hi.apk
        base-hr.apk
        base-hu.apk
        base-hy.apk
        base-in.apk
        base-is.apk
        base-it.apk
        base-iw.apk
        base-ja.apk
        base-ka.apk
        base-kk.apk
        base-km.apk
        base-kn.apk
        base-ko.apk
        base-ky.apk
        base-ldpi.apk
        base-lo.apk
        base-lt.apk
        base-lv.apk
        base-master.apk
        base-mdpi.apk
        base-mk.apk
        base-ml.apk
        base-mn.apk
        base-mr.apk
        base-ms.apk
        base-my.apk
        base-nb.apk
        base-ne.apk
        base-nl.apk
        base-or.apk
        base-pa.apk
        base-pl.apk
        base-pt.apk
        base-ro.apk
        base-ru.apk
        base-si.apk
        base-sk.apk
        base-sl.apk
        base-sq.apk
        base-sr.apk
        base-sv.apk
        base-sw.apk
        base-ta.apk
        base-te.apk
        base-th.apk
        base-tl.apk
        base-tr.apk
        base-tvdpi.apk
        base-uk.apk
        base-ur.apk
        base-uz.apk
        base-vi.apk
        base-xhdpi.apk
        base-xxhdpi.apk
        base-xxxhdpi.apk
        base-zh.apk
        base-zu.apk
```


里面有一个toc.pb文件和一个splits文件夹（splits顾名思义，就是拆分出来的所有apk文件），splits里面有很多apk，`base-`开头的apk是主module的相关apk，其中`base-master.apk`是基本功能apk，`base-xxhdpi.apk`则是对资源分辨率进行了拆分，`base-zh.apk`则是对语言资源进行拆分。

我们可以将这些apk拖入Android Studio看一下里面有什么，比如`base-xxhdpi.apk`：

```
│  AndroidManifest.xml
|  
|  resources.arsc
│
├─META-INF
│      BNDLTOOL.RSA
│      BNDLTOOL.SF
│      MANIFEST.MF
│
└─res
    ├─drawable-ldrtl-xxhdpi-v17
    │      abc_ic_menu_copy_mtrl_am_alpha.png
    │      abc_ic_menu_cut_mtrl_alpha.png
    │      abc_spinner_mtrl_am_alpha.9.png
    │
    ├─drawable-xhdpi-v4
    │      notification_bg_low_normal.9.png
    │      notification_bg_low_pressed.9.png
    │      notification_bg_normal.9.png
    │      notification_bg_normal_pressed.9.png
    │      notify_panel_notification_icon_bg.png
    │
    └─drawable-xxhdpi-v4
            abc_textfield_default_mtrl_alpha.9.png
            abc_textfield_search_activated_mtrl_alpha.9.png
            abc_textfield_search_default_mtrl_alpha.9.png
            abc_text_select_handle_left_mtrl_dark.png
            abc_text_select_handle_left_mtrl_light.png
            abc_text_select_handle_middle_mtrl_dark.png
            abc_text_select_handle_middle_mtrl_light.png
            abc_text_select_handle_right_mtrl_dark.png
            abc_text_select_handle_right_mtrl_light.png
```

首先，这个apk有自己的AndroidManifest.xml，其次是resources.arsc，还有META-INF签名信息，最后是与自己名称对应的xxhdpi的资源。

再来看一个`base-zh.apk`:

```
│  AndroidManifest.xml
│  resources.arsc
│
└─META-INF
        BNDLTOOL.RSA
        BNDLTOOL.SF
        MANIFEST.MF
```

也是有自己的AndroidManifest.xml、resources.arsc、签名信息，其中resources.arsc里面包含了字符串资源（可以直接在Android Studio中查看）。

分析到这里大家对apks文件就有一定的了解了，它是一个压缩文件，里面包含了各种最终需要组成apk的各种零部件，这些零部件可以根据设备来按需组成一个完整的app。 比如我有一个设备是只支持中文、xxhdpi分辨率的设备，那么这个设备其实只需要下载部分apk就行了，也就是base-master.apk(基本功能的apk)、base-zh.apk（中文语言资源）和base-xxhdpi.apk（图片资源）给组合起来。到Google Play上下载apk，也是这个流程（如果这个项目的后台上传的是app bundle的话），Google Play会根据设备的特性（CPU架构、语言、分辨率等），首先下载基本功能apk，然后下载与之配置的CPU架构的apk、语言apk、分辨率apk等，这样下载的apk是最小的。

3. 生成好了apks之后，现在我们可以把安卓测试设备插上电脑，然后利用bundletool将apks中适合设备的零部件apk挑选出来，并部署到已连接的测试设备。具体操作命令：`java -jar bundletool-all-1.14.0.jar install-apks --apks=my_app.apks`，执行完该命令之后设备上就安装好app了，可以对app进行测试了。bundletool会去识别这个测试设备的语言、分辨率、CPU架构等，然后挑选合适的apk安装到设备上，base-master.apk是首先需要安装的，其次是语言、分辨率、CPU架构之类的apk，利用Android 5.0以上的split apks，这些apk安装之后可以共享一套代码和资源。

### 3.3 Google Play

如果我最终就是要将Android App Bundle发布到Google Play，那可以先上传到Google Play Console的测试渠道，再通过测试渠道进行分发，然后到Google Play下载这个测试的App，这样肯定是最贴近于用户的使用环境的，比较推荐这种方式进行最后的测试。

## 4. 拆解Android App Bundle格式

首先，放上官方的格式拆解图（下图包含：一个基本模块、两个功能模块、两个资源包）：

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/ImagesAndroidAppBundle%E6%A0%BC%E5%BC%8F.png)

app bundle是经过签名的二进制文件，可将应用的代码和资源装进不同的模块中，这些模块中的代码和资源的组织方式和apk中相似，它们都可以作为单独的apk生成。Google Play会使用app bundle生成向用户提供的各种apk，如base apk、feature apk、configuration apks、multi-APKs。图中蓝色标识的目录（drawable、values、lib）表示Google Play用来为每个模块创建configuration apks的代码和资源。

- base、feature1、feature2：每个顶级目录都表示一个不同的应用模块，基本模块是包含在app bundle的base目录中。
- `asset_pack_1`和`asset_pack_2`：游戏或者大型应用如果需要大量图片，则可以将asset模块化处理成资源包。资源包可以根据自己的需要，在合适的时机去请求到本地来。
- `BUNDLE-METADATA/`：包含元数据文件，其中包含对工具或应用商店有用的信息。
- 模块协议缓冲区(`*pb`)文件：元数据文件，向应用商店说明每个模块的内容。如：BundleConfig.pb 提供了有关 bundle 本身的信息（如用于构建 app bundle 的构建工具版本），native.pb 和 resources.pb 说明了每个模块中的代码和资源，这在 Google Play 针对不同的设备配置优化 APK 时非常有用。
- `manifest/`：与 APK 不同，app bundle 将每个模块的 AndroidManifest.xml 文件存储在这个单独的目录中。
- `dex/`：与 APK 不同，app bundle 将每个模块的 DEX 文件存储在这个单独的目录中。
- `res/`、`lib/` 和 `assets/`：这些目录与典型 APK 中的目录完全相同。
- root/：此目录存储的文件之后会重新定位到包含此目录所在模块的任意 APK 的根目录。

## 5. Split APKs

Android 5.0 及以上支持Split APKs机制，Split APKs与常规的apk相差不大，都是包含经过编译的dex字节码、资源和清单文件等。区别是：Android可以将安装的多个Split APKs视为一个应用，也就是虽然我安装了多个apk，但Android系统认为它们是同一个app，用户也只会在设置里面看到一个app被安装上了；而平时我们安装的普通apk，一个apk就对应着一个app。Android上，我们可以安装多个Split APK，它们是共用代码和资源的。

Split APKs的好处是可以将单体式app做拆分，比如将ABI、屏幕密度、语言等形式拆分成多个独立的apk，按需下载和安装，这样可以让用户更快的下载并安装好apk，并且占用更小的空间。

Android App Bundle最终也就是利用这种方式来进行安装的，比如我上面在执行完`java -jar bundletool-all-1.14.0.jar install-apks --apks=my_app.apks`命令之后，那么最后安装到手机上的apk文件如下：

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/Imagessplit_apks%E5%AE%89%E8%A3%85.jpg)

> ps：5.0以下不支持Split APKs，那咋办？没事，Google Play会为这些设备的用户安装一个全量的apk，里面什么都有，问题不大。

## 6. 国内商店支持Android App Bundle吗？

> Android App Bundle不是Google Play的专有格式，它是开源的，任何商店想支持都可以的。

上面扯那么大一堆有的没的，这玩意儿这么好用，那国内商店的支持情况如何。我查了下，发现就华为可以支持，手动狗头。

> 华为 Android App Bundle https://developer.huawei.com/consumer/cn/doc/distribution/app/agc-help-releasebundle-0000001100316672

## 7. 小结

现在上架Google Play必须上传Android App Bundle才行了，所以有必要简单了解下。简单来说就是Android App Bundle是一种新的发布格式，上传到商店之后，商店会利用这个Android App Bundle生成一堆Split APKs，当用户要去安装某个app时，只需要按需下载Split APKs中的部分apk（base apk + 各种配置apk），进行安装即可，总下载量大大减少。

## 参考资料

- splits——安卓gradle  https://blog.csdn.net/weixin_37625173/article/details/103284575
- Android App Bundle探索   https://juejin.cn/post/6844903615895699470
- Android App Bundle 简介 https://developer.android.google.cn/guide/app-bundle?hl=zh-cn
- 配置基本模块 https://developer.android.google.cn/guide/app-bundle/configure-base?hl=zh-cn
- 测试 Android App Bundle https://developer.android.google.cn/guide/app-bundle/test?hl=zh-cn
- app bundle 的代码透明性机制   https://developer.android.google.cn/guide/app-bundle/code-transparency?hl=zh-cn
- Android App Bundle 格式  https://developer.android.google.cn/guide/app-bundle/app-bundle-format?hl=zh-cn
- Android App Bundle 常见问题解答  https://developer.android.google.cn/guide/app-bundle/faq?hl=zh-cn
- 视频资料 App Bundles - MAD Skills ：https://www.youtube.com/playlist?list=PLWz5rJ2EKKc9RJo0uMB_Di3xZ_ZLeau-D
- Android App Bundle解析 https://zhuanlan.zhihu.com/p/86995941
- bundletool  https://developer.android.google.cn/studio/command-line/bundletool?hl=zh-cn
- 从命令行构建应用  https://developer.android.google.cn/studio/build/building-cmdline?hl=zh-cn#deploy_from_bundle