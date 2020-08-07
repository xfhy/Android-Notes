
## 1. 前言

Android开发,打包的时候可能会打内测包,外侧包,release包等,还有就是有时候还需要打不同渠道的包等.这时它们里面的包名,应用图标,应用名称,某些资源文件,某些java文件等可能不同,如果通过人工去手动改,改了之后再打包的话,那就太麻烦了.现在有了Gradle,它可以帮到我们.

ps: 请先搞懂Android DSL的基本配置,比如compileSdkVersion是什么本文不会再介绍.有需要则查[官方文档](http://google.github.io/android-gradle-dsl/current/index.html),还有就是皇叔写的[写给Android开发的Gradle知识体系](https://mp.weixin.qq.com/s/YFMkJZXSqmc0OOuyAnc4mA)非常不错.

## 2. 统一配置

### 2.1 以前的配置方式

今天我来带大家实现一种很方便的配置项目诸如compileSdkVersion,三方库引入等.最终的效果如下,可以直接通过Config点出来,并且还可以通过Ctrl+鼠标左键点过去.

![QQempF.png](https://s2.ax1x.com/2019/12/03/QQempF.png)

以前,很多很多项目会将一些基本的配置放到Project的build.gradle中,类似

```gradle
ext {
    compileSdkVersion = 29
    buildToolsVersion = "29.0.0"
    targetSdkVersion = 29
    minSdkVersion = 21
    versionCode = 1
    versionName = "1.0.0"
}
```

然后在各个module的build.gradle中进行使用这个配置

```gradle
android {
    compileSdkVersion rootProject.compileSdkVersion
    defaultConfig {
        versionCode rootProject.versionCode
        versionName rootProject.versionName
        minSdkVersion rootProject.minSdkVersion
        targetSdkVersion rootProject.targetSdkVersion
    }
}
```

这种方式可以,但是不够优雅.我们写好rootProject,然后再输入"."的时候AS不会提示你有哪些可用的变量,不能智能提示.而且即使你一字不差的写好了,用Ctrl+鼠标左键也点不过去.在ext{}下的那些变量,你用快捷键搜索在哪些地方使用到了,AS也不知道....是不是觉得差点意思.

### 2.2 推荐的配置方式

> ps: 这种配置方式,最开始是看到[柯基大佬](https://github.com/Blankj)在使用,觉得太棒了,哈哈.这种配置方式,好像只能是3.5+版本的AS

我们来实现一种更优雅的方式,实现上面的功能.创建一个buildSrc这个名字的module,这个module的名称必须为buildSrc.因为我们创建的这个module是AS专门用来写插件的,会自动参与编译.创建好之后删除Android那一堆东西,什么java代码,res,清单文件等.只剩下build.gradle和.gitignore

![QQleEj.png](https://s2.ax1x.com/2019/12/03/QQleEj.png)

把build.gradle文件内容改成
```gradle
repositories {
    google()
    jcenter()
}
apply {
    plugin 'groovy'
    plugin 'java-gradle-plugin'
}
dependencies {
    implementation gradleApi()
    implementation localGroovy()
    implementation "commons-io:commons-io:2.6"
}
```

然后在main下面创建文件夹groovy,sync一下.没啥问题的话,应该能编译过.然后在groovy文件夹下面创建Config.groovy文件

```groovy
class Config {

    static applicationId = 'com.xfhy.gradledemo'
    static appName = 'GradleDemo'
    static compileSdkVersion = 29
    static buildToolsVersion = '29.0.2'
    static minSdkVersion = 22
    static targetSdkVersion = 29
    static versionCode = 1
    static versionName = '1.0.0'

}
```

可以看到,我们将常用配置全部填入这里.这个时候去module的build.gradle将这些参数全部替换掉.

```gradle
android {
    compileSdkVersion Config.compileSdkVersion
    buildToolsVersion Config.buildToolsVersion
    defaultConfig {
        applicationId Config.applicationId
        minSdkVersion Config.minSdkVersion
        targetSdkVersion Config.targetSdkVersion
        versionCode Config.versionCode
        versionName Config.versionName
    }
    ....
}
```

完美.同理,将三方库也可以加进来

```groovy
class Config {
    static depConfig = [
            support      : [
                    appcompat_androidx   : "androidx.appcompat:appcompat:$appcompat_androidx_version",
                    recyclerview_androidx: "androidx.recyclerview:recyclerview:$recyclerview_androidx_version",
                    design               : "com.google.android.material:material:$design_version",
                    multidex             : "com.android.support:multidex:$multidex_version",
                    constraint           : "com.android.support.constraint:constraint-layout:$constraint_version",
            ],
            kotlin       : "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version",
            leakcanary   : [
                    android         : "com.squareup.leakcanary:leakcanary-android:$leakcanary_version",
                    android_no_op   : "com.squareup.leakcanary:leakcanary-android-no-op:$leakcanary_version",
                    support_fragment: "com.squareup.leakcanary:leakcanary-support-fragment:$leakcanary_version",
            ],
    ]
}
```

在build.gradle中使用
```gradle
dependencies {
    implementation Config.depConfig.support.recyclerview_androidx
    ....
}
```

## 3. 渠道包

### 3.1 productFlavors

productFlavors直译为产品风味,Android这边用它来做多渠道.在app的build.gradle中加入如下配置

```gradle
android {
    flavorDimensions "channel"
    productFlavors {
        free {
            dimension "channel"
            //程序包名
            applicationId "com.xfhy.free"
            //替换清单文件中的标签
            manifestPlaceholders = [
                    APP_ICON: "@drawable/ic_launcher",
                    APP_NAME: "xx免费版",
            ]
            //versionName
            versionName "2.0.0"
            //versionCode
            versionCode 2
        }
        vip {
            dimension "channel"
            //程序包名
            applicationId "com.xfhy.vip"
            //替换清单文件中的标签
            manifestPlaceholders = [
                    APP_ICON: "@drawable/ic_launcher",
                    APP_NAME: "xxVip版",
            ]
            //versionName
            versionName "3.0.0"
            //versionCode
            versionCode 3
        }
        svip {
            dimension "channel"
        }
    }
}

```

如代码所示,我们配置了3种类型的风味,在productFlavors中可以配置包名（applicationId）、版本号（versionCode）、版本名（versionName）、icon、应用名.并且可以在里面配置各种你之前在defaultConfig里面配置的东西.还可以配置src代码目录,res目录之类的.并且这个时候Build Variants里面有了多种类型,比如:freeDebug,freeRelease,vipDebug,vipRelease等.你在Build Variants里面选择freeDebug,则是使用free风味,并且是debug时使用的配置.

```xml
<application
    xmlns:tools="http://schemas.android.com/tools"
    android:icon="${APP_ICON}"
    android:label="${APP_NAME}"
    android:theme="@style/AppTheme"
    android:largeHeap="true"
    tools:replace="android:label">
    ...
</application>
```

### 3.2 渠道变量

首先来介绍一个关键词扩展:applicationVariants,它是在AppExtension里面的,[它的官方文档](http://google.github.io/android-gradle-dsl/current/com.android.build.gradle.AppExtension.html#com.android.build.gradle.AppExtension:applicationVariants),它意思是返回应用程序项目包含的构建变体的集合,是用all关键词进行遍历.我们拿到了这些变体之后,可以根据当前是哪个变体来构建出相应变体所特殊的变量.比如内测和外测它们的地址肯定不一样的,那么通过这种方式可以很方便地整出来.构建的变量会存在于相应的BuildConfig中,然后在java代码中直接引用就行,替换地址时也不需要动java代码,只需在gradle中改一下,然后它编译的时候就会自动构建BuildConfig,自动将地址搞成最新的了.说了这些多,show me the code!

```gradle
android {
    applicationVariants.all { variant ->
        //构建变体专属变量
        switch (variant.flavorName) {
            case 'free':
                buildConfigField("String", "BASE_URL", "\"http://31.13.66.23\"")
                buildConfigField("String", "TOKEN", "\"dhaskufguakfaskfkjasjhbfree\"")
                break
            case 'vip':
                buildConfigField("String", "BASE_URL", "\"http://31.13.66.24\"")
                buildConfigField("String", "TOKEN", "\"dhaskfagafkjasjhbvip\"")
                break
            case 'svip':
                buildConfigField("String", "BASE_URL", "\"http://31.13.66.25\"")
                buildConfigField("String", "TOKEN", "\"dhaskufgufgsdagajasjhbsvip\"")
                break
        }
    }
}
```

将上面的代码写在app的build.gradle中,在上面的gradle代码中我们定义了2个变量,不同的变体会构建不同的值,比如上面的`BASE_URL`我们会在free变体编译的时候就会在BuildConfig生成一个变量,值是`http://31.13.66.23`.我们来看一下BuildConfig中是些什么内容:

```java
//build\generated\source\buildConfig\free\debug\com\xfhy\gradledemo\BuildConfig.java
public final class BuildConfig {
  public static final boolean DEBUG = Boolean.parseBoolean("true");
  public static final String APPLICATION_ID = "com.xfhy.free";
  public static final String BUILD_TYPE = "debug";
  public static final String FLAVOR = "free";
  public static final int VERSION_CODE = 2;
  public static final String VERSION_NAME = "2.0.0";
  // Fields from the variant
  public static final String BASE_URL = "http://31.13.66.23";
  public static final String TOKEN = "dhaskufguakfaskfkjasjhbfree";
}
```

这个文件是gradle构建时自动为我们创建的,不需要去修改.我们构建的变体变量在最下面,这里面的值确实是我们在gradle代码中写的那样.这个里面已经有一些不是我们搞出来的变量了,比如是否是DEBUG,APPLICATION_ID,VERSION_CODE之类的.我们在java代码中使用的时候,直接`BuildConfig.BASE_URL`这种方式进行使用即可,它就是一个普通的java类,里面定义了一些变量而已.

当然除了上面的渠道变量之外,还有一些变量是公用的,每个变体都是一样的那种.我们可以写到`defaultConfig`下面.

```gradle
android {
    defaultConfig {
        buildConfigField("String", "APP_DESCRIPTION", "\"你没有见过的船新版本\"")
        buildConfigField("String[]", "TAB", "{\"首页\",\"排行榜\",\"我的\"}")
    }
}
```

### 3.3 打包文件命名

还是利用上面的`applicationVariants`,当我们拿到了变体之后,在打包的时候动态的将打包之后的文件名改一下.比如改成下面这种形式

```
applicationVariants.all { variant ->
    variant.outputs.all {
        def type = variant.buildType.name
        def channel = variant.flavorName
        outputFileName = "demo_${variant.versionName}_${channel}_${type}.apk"
    }
}
```

最后它打出来的包是这样的`demo_2.0.0_free_debug.apk`,写完之后可以使用`gradlew assembleFreeDebug`命令试一下.命令运行之后会在`app\build\outputs\apk\free\debug`目录下产生相应的apk文件.

### 3.4 签名

可以在gradle中指定打包时的签名文件,密码啥的

```gradle
signingConfigs {
    debug {
        storeFile file('../keys/xfhy.jks')
        storePassword "qqqqqq"
        keyAlias "xfhy"
        keyPassword "qqqqqq"
        v1SigningEnabled true
        v2SigningEnabled true
    }
    release {
        storeFile file('../keys/xfhy.jks')
        storePassword "qqqqqq"
        keyAlias "xfhy"
        keyPassword "qqqqqq"
        v1SigningEnabled true
        v2SigningEnabled true
    }
}
```

指定了签名以及密码之后,打包的时候就只需要在命令行执行`gradlew assembleVipRelease`即可,不用打开Android Studio了.

### 3.5 资源

Android Studio提供了代码整合功能.只需要创建`app/src/xxFlavorName/assets`,`app/src/xxFlavorName/src`,`app/src/xxFlavorName/res`即可.当在Build Variants中切换切换变体之后,AS就只会编译对应变体的资源+main下面的资源.

[![Qr9JqP.md.png](https://s2.ax1x.com/2019/12/10/Qr9JqP.md.png)](https://imgse.com/i/Qr9JqP)

可以看到,free下面的文件夹自动变色了,这些是free变体特殊的东西,只有在free编译的时候才会被用到.java代码,res资源等,到时是需要和main下面的一起合并的.

假如我在free变体下创建了Test.java,然后可以在main下面引用到,就和平时使用一样.但是如果相同包名下如果free中有Test.java,main中也有,那么是编译不过的. 还有就是当main里面用到了Test.java的时候,在Build Variants中切换成了vip,而vip中刚好没有Test.java,就会报错的,因为找不到这个文件.

上面这个问题,可以用sourceSets来解决,sourceSets可以指定代码资源文件的位置.虽然上面创建的free,vip等变体文件夹下面也是放这些东西的,但是用sourceSets比他们优先级高.

下面来看它的普通用法,一看就懂.

```gradle
sourceSets {
    main {
        manifest.srcFile 'AndroidManifest.xml'
        java.srcDirs = ['src']
        aidl.srcDirs = ['src']
        renderscript.srcDirs = ['src']
        res.srcDirs = ['res']
        assets.srcDirs = ['assets']
    }
}
```

然后我们除了在`src/main/java`下有java代码,还可以指定在其他地方有java代码.比如下面这样.可以在src下面创建`common/java`文件夹,用于存放公共的代码.

```gradle
sourceSets {
    sourceSets.main.java.srcDirs = ['src/main/java', 'src/common/java']
}
```

上面的Test.java问题,可以用sourceSets解决.在common文件夹创建一个公共的Test.java,然后其他变体可以使用.在free在使用自己特殊的Test.java,只拿给free用.

项目的结果是这样的,这是变体是vip的时候:

[![QszS5F.md.png](https://s2.ax1x.com/2019/12/11/QszS5F.md.png)](https://imgse.com/i/QszS5F)

```gradle
sourceSets {
    main {
        java.srcDirs = ['src/main/java']
    }
    free {
        java.srcDirs = ['src/free/java']
    }

    svip {
        java.srcDirs = ['src/common/java']
    }

    vip {
        java.srcDirs = ['src/common/java']
    }
}
```

## 4. 总结

又学到了一大波干货内容.对于渠道包,可能不一定会用得到,但是其实还是挺有用的. 同一套代码可以产出多个app,俗称马甲包,可能很多公司都在搞这种.如果用得上,希望能帮到你.

参考:

- 这样使用Gradle可以神奇地打各种渠道包 https://mp.weixin.qq.com/s/_CahiMe8A6m40TI-iiP9kw
- 一个项目如何编译多个不同签名、包名、资源等，的apk？ https://mp.weixin.qq.com/s/OQtAVhQVPNVxo9zJc3NG9w
