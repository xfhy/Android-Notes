
## 0. 前情提示

这是一个gradle系列,尽量从前往后阅读.已完成文章:

[Gradle系列(一) Groovy 基础](https://blog.csdn.net/xfhy_/article/details/103329430)

## 1. 什么是gradle

维基百科:Gradle是一个基于Apache Ant和Apache Maven概念的项目自动化建构工具。它使用一种基于Groovy的特定领域语言来声明项目设置，而不是传统的XML。当前其支持的语言限于Java、Groovy和Scala，计划未来将支持更多的语言。

按我的理解,通俗一点讲,就是拿来构建项目的,我们平时在Android Studio上开发Android项目就是用Gradle进行构建的,相比于传统的xml方式,我感觉更加灵活.毕竟,可以写代码,根据不同的环境搞些骚操作.

gradle里面其实需要学习的有3个

- Groovy, 官方文档: http://docs.groovy-lang.org/latest/html/groovy-jdk/index-all.html
- Gradle DSL, 官方文档: https://docs.gradle.org/current/javadoc/org/gradle/api/Project.html
- Android Plugin DSL, 官方文档: http://google.github.io/android-gradle-dsl/current/index.html

刚哥说过,遇到不会的直接查官方文档,不要每次去搜索引擎东搜西搜,这样效率很低.

这里插播一个小知识点,如何查询官方文档.比如在gradle中经常用的buildscript到底是什么?来到[官方文档首页](https://docs.gradle.org/current/javadoc/org/gradle/api/Project.html),点开顶部INDEX,搜索buildscript,即可找到这个东西是解释.

## 2. gradle项目结构

首先我们来新建一个Android项目,什么都不要动.

![QZLQBT.png](https://s2.ax1x.com/2019/12/01/QZLQBT.png)

- 最外层setting.gradle为根项目的配置,可以知道需要包含哪些模块,然后最外层的build.gralde也是根项目的配置.模块中的build.gradle是子项目的配置.
- gradle文件夹下面是版本配置以及gradle所需要的脚本
- 最外层的gradlew为linux/mac下的脚本,gradlew.bat是windows下面用的脚本

## 3. gradle配置顺序

简单在gradle中输出语句,看看配置顺序

```gradle
//settings.gradle
println("setting 开始配置")
include ':app'
rootProject.name='Hello'
println("setting 配置完成")
```

```gradle
//project build.gradle
println("根build.gradle 开始配置")
buildscript {
    repositories {
    }
    dependencies {
    }
}
println("根build.gradle 配置完成")
```

```gradle
//app build.gradle
println("app build.gradle 开始配置")

project.afterEvaluate {
    println "所有模块都已配置完成"
}

android {
    defaultConfig {
    }
    buildTypes {
    }
}

dependencies {
}
println("app build.gradle 配置完成")
```

打印语句写好后,clean Project,即可执行,输出如下:

```
setting 开始配置
setting 配置完成

> Configure project :
根build.gradle 开始配置
根build.gradle 配置完成

> Configure project :app
app build.gradle 开始配置
app build.gradle 配置完成
所有模块都已配置完成
```

可以看到首先是配置setting,知道有哪些模块.然后是配置根项目的build.gradle,然后才是子项目的build.gradle配置.

我在上面加了一个监听器`project.afterEvaluate`,可以通过查询[官方文档](https://docs.gradle.org/current/javadoc/org/gradle/api/Project.html#afterEvaluate-groovy.lang.Closure-)了解它的详细内容,这是一个当所有的模块都配置完了的时候的回调.

其中,还可以在settings.gradle中添加一个监听器
```
gradle.addBuildListener(new BuildListener() {
    @Override
    void buildStarted(Gradle gradle) {
        println("buildStarted------------")
    }

    @Override
    void settingsEvaluated(Settings settings) {
        println("settingsEvaluated------------")
    }

    @Override
    void projectsLoaded(Gradle gradle) {
        println("projectsLoaded------------")
    }

    @Override
    void projectsEvaluated(Gradle gradle) {
        println("projectsEvaluated------------")
    }

    @Override
    void buildFinished(BuildResult result) {
        println("buildFinished------------")
    }
})
```

在执行构建的时候,这个监听器会监听到主要的生命周期事件,看名字大概就能大概猜出是什么意思,buildStarted已过时.也可以看看[官方文档](https://docs.gradle.org/current/javadoc/org/gradle/BuildListener.html)详细了解

加入之后打印如下:
```
setting 开始配置
setting 配置完成
settingsEvaluated------------
projectsLoaded------------

> Configure project :
根build.gradle 开始配置
根build.gradle 配置完成

> Configure project :app
app build.gradle 开始配置
app build.gradle 配置完成
所有模块都已配置完成
projectsEvaluated------------

buildFinished------------
```

## 4. gradle task

### 4.1 初识task

gradle中所有的构建工作都是由task完成的,它帮我们处理了很多工作,比如编译,打包,发布等都是task.我们可以在项目的根目录下,打开命令行(AS自带,底部有Terminal,打开就行)执行`gradlew tasks`查看当前项目所有的task.

> 在命令行如果执行失败,则将项目的JDK location设置成本地jdk的路径,而且jdk的版本还需要是java 8. 我用的jdk版本是1.8.0_231.

```
> Task :tasks

------------------------------------------------------------
Tasks runnable from root project
------------------------------------------------------------

Android tasks
-------------
androidDependencies - Displays the Android dependencies of the project.
signingReport - Displays the signing info for the base and test modules
sourceSets - Prints out all the source sets defined in this project.

Build tasks
-----------
assemble - Assemble main outputs for all the variants.
assembleAndroidTest - Assembles all the Test applications.
build - Assembles and tests this project.
buildDependents - Assembles and tests this project and all projects that depend on it.
buildNeeded - Assembles and tests this project and all projects it depends on.
bundle - Assemble bundles for all the variants.
clean - Deletes the build directory.
cleanBuildCache - Deletes the build cache directory.
compileDebugAndroidTestSources
compileDebugSources
compileDebugUnitTestSources
compileReleaseSources
compileReleaseUnitTestSources

Build Setup tasks
-----------------
init - Initializes a new Gradle build.
wrapper - Generates Gradle wrapper files.

Cleanup tasks
-------------
lintFix - Runs lint on all variants and applies any safe suggestions to the source code.

Help tasks
----------
buildEnvironment - Displays all buildscript dependencies declared in root project 'Hello'.
components - Displays the components produced by root project 'Hello'. [incubating]
dependencies - Displays all dependencies declared in root project 'Hello'.
dependencyInsight - Displays the insight into a specific dependency in root project 'Hello'.
dependentComponents - Displays the dependent components of components in root project 'Hello'. [incubating]
help - Displays a help message.
model - Displays the configuration model of root project 'Hello'. [incubating]
projects - Displays the sub-projects of root project 'Hello'.
properties - Displays the properties of root project 'Hello'.
tasks - Displays the tasks runnable from root project 'Hello' (some of the displayed tasks may belong to subprojects).

Install tasks
-------------
installDebug - Installs the Debug build.
installDebugAndroidTest - Installs the android (on device) tests for the Debug build.
uninstallAll - Uninstall all applications.
uninstallDebug - Uninstalls the Debug build.
uninstallDebugAndroidTest - Uninstalls the android (on device) tests for the Debug build.
uninstallRelease - Uninstalls the Release build.

Verification tasks
------------------
check - Runs all checks.
connectedAndroidTest - Installs and runs instrumentation tests for all flavors on connected devices.
connectedCheck - Runs all device checks on currently connected devices.
connectedDebugAndroidTest - Installs and runs the tests for debug on connected devices.
deviceAndroidTest - Installs and runs instrumentation tests using all Device Providers.
deviceCheck - Runs all device checks using Device Providers and Test Servers.
lint - Runs lint on all variants.
lintDebug - Runs lint on the Debug build.
lintRelease - Runs lint on the Release build.
lintVitalRelease - Runs lint on just the fatal issues in the release build.
test - Run unit tests for all variants.
testDebugUnitTest - Run unit tests for the debug build.
testReleaseUnitTest - Run unit tests for the release build.

To see all tasks and more detail, run gradlew tasks --all

```

可以看到,这里有很多的task.比如我们在命令行执行`gradlew clean`就是clean.执行`gradlew installDebug`就是构建debug项目然后安装到手机上.

### 4.2 编写task

书写task非常简单,比如我们在根目录的build.gradle中加入一个hello的task

```
task hello() {
    println "hello world"

    //将给定的闭包 添加到此task操作链表的开头
    doFirst {
        println "hello task doFirst"
    }

    doLast {
        println "hello task doLast"
    }
}
```

然后在命令行执行`gradlew hello`,输出如下

```
setting 开始配置
setting 配置完成

> Configure project :
根build.gradle 开始配置
hello world
根build.gradle 配置完成

> Configure project :app
app build.gradle 开始配置
app build.gradle 配置完成

> Task :hello
hello task doFirst
hello task doLast
```

它会先配置完成,才会执行.在一个task内部其实拥有一个action列表,执行的时候其实就是执行这个列表,它的类型是一个List.上面的doFirst和doLast就是创建action的两个方法,[文档](https://docs.gradle.org/current/javadoc/org/gradle/api/Task.html#doFirst-groovy.lang.Closure-).doFirst是在最开始执行,doLast是在最后执行,大括号里面传入的是闭包.

### 4.3 task执行顺序

task是有执行顺序的,在创建完Android项目之后,根目录下的build.gradle中,有一个clean的task.这个是AS自动给我们生成的.
```
task clean(type: Delete) {
    delete rootProject.buildDir
}
```

我们先在根目录下创建test.txt文件,然后我们在这个task中做一些改动,执行到clean这个task时删除根目录下的test.txt文件.
```
task clean(type: Delete) {
    delete rootProject.buildDir

    doLast {
        def file = new File('test.txt')
        delete file
        println "清理"
    }
}
```

然后我们在hello这个task的下面写上
```
hello.dependsOn clean
```
这样就表示hello这个task依赖clean这个task,当执行hello这个task时需要先执行clean.
我们在命令行执行`gradlew hello`看看是不是这样.我执行之后它的输出是
```
> Task :clean
清理

> Task :hello
hello task doFirst
hello task doLast
```

先执行clean,再执行hello这个task.而且还看到test.txt文件被删除(如果看到没删除,刷新一下看看)了,那么说明确实是clean先执行.

这个顺序有什么用?其实是很有用的,比如执行安装task的时候,肯定会先执行编译,打包这些步骤.

### 4.4 自带 gradle task

当我们在AS中创建Android项目的时候,默认会带一些Android的一些gradle task,这些task都是gradle和Android Gradle Plugin给我们创建好的,可以直接用.

![Qe1fy9.png](https://s2.ax1x.com/2019/12/01/Qe1fy9.png)

比如我们上面使用到的`gradlew clean`是用来清理项目的.和编译相关的task主要有：build和assemble，其中build依赖assemble，也就是说执行build之前会先执行assemble。在Android上，会根据buildType和productFlavor的不同自动创建多个assembleXxx任务，如assembleDebug，assembleRelease等，assemble会依赖所有的assembleXxx任务，也就是说执行assemble会先执行assembleDebug，assembleRelease等一系列的assemble任务。

如果想看Android Gradle Plugin源码,可以在app/build.gradle中的dependencies下面引入

```gradle
compileOnly 'com.android.tools.build:gradle:3.5.2'
```

然后就可以在项目的External Libraries中看到该jar的源码,

![QeUB5R.png](https://s2.ax1x.com/2019/12/01/QeUB5R.png)

比如clean这个task是在`com.android.build.gradle.tasks.CleanBuildCache.java`里面定义的
```java
@TaskAction
public void clean() throws IOException {
    Preconditions.checkNotNull(buildCache, "buildCache must not be null");
    buildCache.delete();
}
```

通过查询gradle官方文档可知,@TaskAction的作用:Marks a method as the action to run when the task is executed. 将方法标记为执行任务时要运行的动作.

## 5.Build script blocks

还有一个东西,就是几乎每个项目都需要用到的地方,但是我之前却根本不知道它真正的名字.就是Build script blocks,打开项目的根目录的build.gradle文件.

```gradle
buildscript {
    repositories {
        google()
        jcenter()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:3.5.2'
    }
}

allprojects {
    repositories {
        google()
        jcenter()
    }
}

```

每个项目都需要配置这些东西,但是我们真的知道他们的含义么?

首先是buildscript,查询文档可知:

```
void buildscript​(Closure configureClosure)

Configures the build script classpath for this project.

The given closure is executed against this project's ScriptHandler. The ScriptHandler is passed to the closure as the closure's delegate.
```
为该项目配置构建脚本类路径.参数是Closure,闭包.这个闭包是委托给了ScriptHandler,又去看看ScriptHandler

```
dependencies​(Closure configureClosure)	 Configures the dependencies for the script.
repositories​(Closure configureClosure)   Configures the repositories for the script dependencies.
```

dependencies​是添加编译依赖项的,repositories​是为脚本依赖项配置存储库.他们的配置,都是用闭包的形式.

然后dependencies​又是委托了DependencyHandler进行配置,对于怎么配置,官方还给了示例

```
Example shows a basic way of declaring dependencies.

 apply plugin: 'java'
 //so that we can use 'implementation', 'testImplementation' for dependencies

 dependencies {
   //for dependencies found in artifact repositories you can use
   //the group:name:version notation
   implementation 'commons-lang:commons-lang:2.6'
   testImplementation 'org.mockito:mockito:1.9.0-rc1'

   //map-style notation:
   implementation group: 'com.google.code.guice', name: 'guice', version: '1.0'

   //declaring arbitrary files as dependencies
   implementation files('hibernate.jar', 'libs/spring.jar')

   //putting all jars from 'libs' onto compile classpath
   implementation fileTree('libs')
 }
```

## 6. 总结

本文带大家梳理了Gradle的执行顺序,Task和Build script blocks这些知识点.为了更好的认识Gradle.现在对Gradle了解又深了一步,而且如果以后遇到不懂的还知道到哪里去查文档,方便快捷,不用再到处搜了.
