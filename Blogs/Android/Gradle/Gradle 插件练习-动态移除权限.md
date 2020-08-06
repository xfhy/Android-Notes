
### 1. 开始之前

**[Gradle DSL 文档](https://docs.gradle.org/current/dsl/)**

Gradle基于Groovy,而Groovy基于Java,最后始终得运行在JVM之上.Gradle、build.gradle、settings.gradle之类的最终都会被搞成一个对象,然后才能执行.

- Gradle 对象: 每次执行`gradle taskName`时,Gradle都会默认构造出一个Gradle对象.在执行过程中,只有这么一个Gradle对象,一般很少去定制它.
- Project对象: 一个build.gradle就对应着一个Project对象.
- Settings对象: 一个settings.gradle就对应着一个Settings对象.

它们的生命周期节点如下:

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/Android/Gradle生命周期节点.png)

### 2. 创建Plugin

先创建buildSrc这个module,用于开发插件.(不清楚的可以看我之前发的[Gradle系列(四) Gradle插件](https://blog.csdn.net/xfhy_/article/details/103657451)).
然后新建一个插件类: `ManifestDemoPlugin`.

```groovy
import org.gradle.api.Plugin
import org.gradle.api.Project
class ManifestDemoPlugin implements Plugin<Project> {
    @Override
    void apply(Project project) {
        
    }
}
```

上面这份代码是标准代码,写插件都得继承自Plugin.

### 3. 分析

需求: 假设是移除`android.permission.READ_PHONE_STATE`权限(有时三方库aar里面可能会定义一些权限,但是又不能让app有这些权限,就需要移除掉.这里仅仅是为了练习Gradle,其实有更好的方式移除权限`tools:remove`).

思路: 我们需要拿到合并之后的AndroidManifest.xml文件,且在打包之前修改这个AndroidManifest.xml文件,将`android.permission.READ_PHONE_STATE`内容移除.

但是我们怎么hook这个合并AndroidManifest.xml文件的时机,从而拿到清单文件内容呢?首先通过`./gradlew tasks --all`命令看看有哪些task,因为合并清单文件肯定是一个task里面做的,我们只需要在这个task之后执行我们写的代码逻辑即可.

```
//task实在太多了,这里只是节选.
> Task :tasks

......
app:makeApkFromBundleForDebug
app:makeApkFromBundleForRelease
app:mergeDebugAndroidTestAssets
app:mergeDebugAndroidTestGeneratedProguardFiles
app:mergeDebugAndroidTestJavaResource
app:mergeDebugAndroidTestJniLibFolders
app:mergeDebugAndroidTestNativeLibs
app:mergeDebugAndroidTestResources
app:mergeDebugAndroidTestShaders
app:mergeDebugAssets
app:mergeDebugGeneratedProguardFiles
app:mergeDebugJavaResource
app:mergeDebugJniLibFolders
app:mergeDebugNativeLibs
app:mergeDebugResources
app:mergeDebugShaders
app:mergeDexRelease
app:mergeExtDexDebug
app:mergeExtDexDebugAndroidTest
app:mergeExtDexRelease
app:mergeLibDexDebug
app:mergeLibDexDebugAndroidTest
app:mergeProjectDexDebug
app:mergeProjectDexDebugAndroidTest
app:packageDebug
app:packageDebugAndroidTest
app:packageDebugBundle
app:packageDebugUniversalApk
app:packageRelease
app:packageReleaseBundle
app:packageReleaseUniversalApk
app:parseDebugIntegrityConfig
app:parseReleaseIntegrityConfig
app:preBuild
app:preDebugAndroidTestBuild
app:preDebugBuild
app:preDebugUnitTestBuild
prepareKotlinBuildScriptModel
app:prepareKotlinBuildScriptModel
app:prepareLintJar
app:prepareLintJarForPublish
......

```

其中有一个task叫`app:mergeDebugResources`,翻译过来就是合并资源嘛,看起来就是我们要找的.下面是Android Plugin Task的大致含义.

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/Android%20Plugin%20Task%E5%90%AB%E4%B9%891.jpg)

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/Android%20Plugin%20Task%E5%90%AB%E4%B9%892.jpg)

### 4. 开始写代码

```groovy
class ManifestDemoPlugin implements Plugin<Project> {
    @Override
    void apply(Project project) {
        //在afterEvaluate,配置完成之后才能拿到那些task完整的有向图
        project.afterEvaluate {
            //1. 找到mergeFreeDebugResources这个task
            def mergeDebugResourcesTask = project.tasks.findByName("mergeFreeDebugResources")
            if (mergeDebugResourcesTask != null) {
                //2. 创建一个task
                def parseDebugTask = project.tasks.create("ParseDebugTask", ParseDebugTask.class)
                //3. 添加一个mergeDebugResourcesTask结束后立马执行的task: parseDebugTask
                mergeDebugResourcesTask.finalizedBy(parseDebugTask)
            }
        }
    }
}
```

1. 我们需要在Project配置完成之后才能拿到所有的task,因为这个时候才真正生成了完整的有向图task依赖.
2. 其次是通过API: `project.tasks`拿到所有的task([API文档地址在这里](https://docs.gradle.org/current/javadoc/org/gradle/api/Project.html#getTasks--)),然后再[findByName方法](https://docs.gradle.org/current/javadoc/org/gradle/api/NamedDomainObjectCollection.html#findByName-java.lang.String-)找到这个task.
3. 这时我们得创建一个自己的task并在`mergeFreeDebugResources`执行完成之后立马开始执行.
   
来看看我们的Task该怎么写:

```groovy
class ParseDebugTask extends DefaultTask {

    @TaskAction
    void doAction() {
        //1. 找到清单文件这个file
        def file = new File(project.buildDir, "/intermediates/merged_manifests/freeDebug/AndroidManifest.xml")
        if (!file.exists()) {
            println("文件不存在")
            return
        }

        //2. 获得文件内容
        def fileContent = file.getText()

        removePermission(file, fileContent)
    }

    /**
     * 动态给清单文件移除权限
     * @param rootNode Node
     * @param file 清单文件
     */
    void removePermission(File file,String fileContent) {
        //方案1  这样会把所有权限都移除了,暂时没找到合适的办法
        //def rootNode = new XmlParser().parseText(fileContent)
        //def node = new Node(rootNode, "uses-permission"/*,["android:name" : "android.permission.READ_PHONE_STATE"]*/)
        //rootNode.remove(node)
        //def updateXmlContent = XmlUtil.serialize(rootNode)
        //println(updateXmlContent)

        //方案2 读取到xml内容之后,将制定权限的字符串给替换掉,,妙啊 妙啊
        fileContent = fileContent.replace("android.permission.READ_PHONE_STATE", "")
        println(fileContent)
        //将字符串写入文件
        file.write(fileContent)
    }

}
```

1. 首先Task得继承自DefaultTask
2. 合并之后的清单文件是在`build/intermediates/merged_manifests/freeDebug/`目录下,先得到这个文件
3. 通过`file.getText()`获取文件内容,再将内容里面的字符串"android.permission.READ_PHONE_STATE"移除掉.
4. 然后再将字符串写入清单文件(待会儿打包的时候就是用的这个文件进行打包的).


顺便,咱还可以再来一个,动态添加一个权限:`android.permission.INTERNET`

```groovy
/**
* 动态给清单文件添加权限
* @param rootNode Node
* @param file 清单文件
*/
void addPermission(File file,,String fileContent) {
    def rootNode = new XmlParser().parseText(fileContent)
    //3. 添加网络权限  这里得加上xmlns:android
    //<uses-permission android:name="android.permission.INTERNET"/>
    //xmlns:android="http://schemas.android.com/apk/res/android"
    rootNode.appendNode("uses-permission", ["xmlns:android": "http://schemas.android.com/apk/res/android",
                                            "android:name" : "android.permission.INTERNET"])

    //还可以动态将meta-data加到Application中                                        
    //rootNode.application[0].appendNode("meta-data", ['android:name': 'appId', 'android:value': 546525])  

    //4. 拿到修改后的xml内容
    def updateXmlContent = XmlUtil.serialize(rootNode)
    println(updateXmlContent)

    //5. 将修改后的xml 写入file中
    file.write(updateXmlContent)
}
```

### 5. 总结

刚开始的时候API非常不熟悉,咱得疯狂地查API.尽量想一些需求做练习,多写写代码,多查查API,熟悉这个过程.Gradle插件非常重要.

![就这?](https://i.loli.net/2020/08/06/9MLJBA1jRSsF3G8.png)
