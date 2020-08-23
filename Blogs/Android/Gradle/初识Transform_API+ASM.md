> 阅读本篇文章需要有写简单Gradle插件的背景知识.

在Android Gradle Plugin中,有一个叫Transform API(从1.5.0版本才有的)的东西.利用这个Transform API咱可以在.class文件转换成dex文件之前,对.class文件进行处理.比如监控,埋点之类的.

## 1. 使用Transform API

### 1.1 注册一个自定义的Transform

首先写一个Plugin,然后通过registerTransform方法进行注册自定义的Transform.

```groovy
class MethodTimeTransformPlugin implements Plugin<Project> {
    @Override
    void apply(Project project) {
        //注册方式1
        AppExtension appExtension = project.extensions.getByType(AppExtension)
        appExtension.registerTransform(new MethodTimeTransform())

        //注册方式2
        //project.android.registerTransform(new MethodTimeTransform())
    }
}
```

通过获取module的Project的AppExtension,通过它的registerTransform方法注册的Transform.

这里注册之后,会在编译过程中的TransformManager#addTransform中生成一个task,然后在执行这个task的时候会执行到我们自定义的Transform的transform方法.这个task的执行时机其实就是`.class`文件转换成`.dex`文件的时候,转换的逻辑是定义在transform方法中的.

### 1.2 自定义一个Transform

先让大家看一下比较标准的Transform模板代码:

```groovy
class MethodTimeTransform extends Transform {

    @Override
    String getName() {
        return "MethodTimeTransform"
    }

    @Override
    Set<QualifiedContent.ContentType> getInputTypes() {
        //需要处理的数据类型,这里表示class文件
        return TransformManager.CONTENT_CLASS
    }

    @Override
    Set<? super QualifiedContent.Scope> getScopes() {
        //作用范围
        return TransformManager.SCOPE_FULL_PROJECT
    }

    @Override
    boolean isIncremental() {
        //是否支持增量编译
        return true
    }

    @Override
    void transform(TransformInvocation transformInvocation) throws TransformException, InterruptedException, IOException {
        super.transform(transformInvocation)

        //TransformOutputProvider管理输出路径,如果消费型输入为空,则outputProvider也为空
        TransformOutputProvider outputProvider = transformInvocation.outputProvider

        //transformInvocation.inputs的类型是Collection<TransformInput>,可以从中获取jar包和class文件夹路径。需要输出给下一个任务
        transformInvocation.inputs.each { input -> //这里的input是TransformInput

            input.jarInputs.each { jarInput ->
                //处理jar
                processJarInput(jarInput, outputProvider)
            }

            input.directoryInputs.each { directoryInput ->
                //处理源码文件
                processDirectoryInput(directoryInput, outputProvider)
            }
        }
    }

    void processJarInput(JarInput jarInput, TransformOutputProvider outputProvider) {
        File dest = outputProvider.getContentLocation(jarInput.file.absolutePath, jarInput.contentTypes, jarInput.scopes, Format.JAR)
        //将修改过的字节码copy到dest,就可以实现编译期间干预字节码的目的
        println("拷贝文件 $dest -----")
        FileUtils.copyFile(jarInput.file, dest)
    }

    void processDirectoryInput(DirectoryInput directoryInput, TransformOutputProvider outputProvider) {
        File dest = outputProvider.getContentLocation(directoryInput.name, directoryInput.contentTypes, directoryInput.scopes, Format
                .DIRECTORY)
        //将修改过的字节码copy到dest,就可以实现编译期间干预字节码的目的
        println("拷贝文件夹 $dest -----")
        FileUtils.copyDirectory(directoryInput.file, dest)
    }

}
```

1. `getName()`: 表示当前Transform名称,这个名称会被用来创建目录,它会出现在app/build/intermediates/transforms目录下面.
2. `getInputTypes()`: 需要处理的数据类型,用于确定我们需要对哪些类型的结果进行转换,比如class,资源文件等:
    - `CONTENT_CLASS`：表示需要处理java的class文件
    - `CONTENT_JARS`：表示需要处理java的class与资源文件
    - `CONTENT_RESOURCES`：表示需要处理java的资源文件
    - `CONTENT_NATIVE_LIBS`：表示需要处理native库的代码
    - `CONTENT_DEX`：表示需要处理DEX文件
    - `CONTENT_DEX_WITH_RESOURCES`：表示需要处理DEX与java的资源文件
3. `getScopes()`: 表示Transform要操作的内容范围(上面demo里面使用的`SCOPE_FULL_PROJECT`是Scope的集合,包含了`Scope.PROJECT`,`Scope.SUB_PROJECTS`,`Scope.EXTERNAL_LIBRARIES`这几个东西.当然,TransformManager里面还有一些其他集合,这里不做举例).
    - PROJECT: 只有项目内容
    - SUB_PROJECTS: 只有子项目
    - EXTERNAL_LIBRARIES: 只有外部库
    - TESTED_CODE: 测试代码
    - PROVIDED_ONLY: 只提供本地或远程依赖项
4. `isIncremental()`: 是否支持增量更新
    - 如果返回true,则TransformInput会包含一份修改的文件列表
    - 如果是false,则进行全量编译,删除上一次输出内容
5. `transform()`: 进行具体转换逻辑.
    - 消费型Transform: 在transform方法中,我们需要将每个jar包和class文件复制到dest路径,这个dest路径就是下一个Transform的输入数据.在复制的时候,我们可以将jar和class文件的字节码做一些修改,再进行复制. 可以看出,如果我们注册了Transform,但是又不将内容复制到下一个Transform需要的输入路径的话,就会出问题,比如少了一些class之类的.上面的demo中仅仅是将所有的输入文件拷贝到目标目录下,并没有对字节码文件进行任何处理.
    - 引用型Transform: 当前Transform可以读取这些输入,而不需要输出给下一个Transform.

可以看出,最关键的核心代码就是transform()方法里面,我们需要做一些class文件字节码的修改,才能让Transform发挥其效果.

道理是这个道理,但是字节码那玩意儿想改就能改么? 忘记字节码是什么的小伙伴可以看我之前发的文章 [Java字节码解读](https://blog.csdn.net/xfhy_/article/details/107776716) 复习一下. 字节码比较复杂,连"读懂"都非常非常困难,还让我去改它,那更是难上加难.

不过,幸好咱们可以借助后面介绍的ASM工具进行方便的修改字节码工作.

### 1.3 增量编译

就是Transform中的`isIncremental()`方法返回值,如果是false的话,则表示不开启增量编译,每次都得处理每个文件,非常非常拖慢编译时间. 我们可以借助该方法,返回值改成true,开启增量编译.当然,开启了增量编译之后需要检查每个文件的Status,然后根据这个文件的Status进行不同的操作.

具体的Status如下:

- NOTCHANGED: 当前文件不需要处理,连复制操作也不用
- ADDED: 正常处理,输出给下一个任务
- CHANGED: 正常处理,输出给下一个任务
- REMOVED: 移除outputProvider获取路径对应的文件

来看一下代码如何实现,咱将上面的dmeo代码简单改改:
```java
@Override
void transform(TransformInvocation transformInvocation) throws TransformException, InterruptedException, IOException {
    super.transform(transformInvocation)
    printCopyRight()

    //TransformOutputProvider管理输出路径,如果消费型输入为空,则outputProvider也为空
    TransformOutputProvider outputProvider = transformInvocation.outputProvider

    //当前是否是增量编译,由isIncremental方法决定的
    // 当上面的isIncremental()写的返回true,这里得到的值不一定是true,还得看当时环境.比如clean之后第一次运行肯定就不是增量编译嘛.
    boolean isIncremental = transformInvocation.isIncremental()
    if (!isIncremental) {
        //不是增量编译则删除之前的所有文件
        outputProvider.deleteAll()
    }

    //transformInvocation.inputs的类型是Collection<TransformInput>,可以从中获取jar包和class文件夹路径。需要输出给下一个任务
    transformInvocation.inputs.each { input -> //这里的input是TransformInput

        input.jarInputs.each { jarInput ->
            //处理jar
            processJarInput(jarInput, outputProvider, isIncremental)
        }

        input.directoryInputs.each { directoryInput ->
            //处理源码文件
            processDirectoryInput(directoryInput, outputProvider, isIncremental)
        }
    }
}

/**
 * 处理jar
 * 将修改过的字节码copy到dest,就可以实现编译期间干预字节码的目的
 */
void processJarInput(JarInput jarInput, TransformOutputProvider outputProvider, boolean isIncremental) {
    def status = jarInput.status
    File dest = outputProvider.getContentLocation(jarInput.file.absolutePath, jarInput.contentTypes, jarInput.scopes, Format.JAR)
    if (isIncremental) {
        switch (status) {
            case Status.NOTCHANGED:
                break
            case Status.ADDED:
            case Status.CHANGED:
                transformJar(jarInput.file, dest)
                break
            case Status.REMOVED:
                if (dest.exists()) {
                    FileUtils.forceDelete(dest)
                }
                break
        }
    } else {
        transformJar(jarInput.file, dest)
    }

}

void transformJar(File jarInputFile, File dest) {
    //println("拷贝文件 $dest -----")
    FileUtils.copyFile(jarInputFile, dest)
}

/**
 * 处理源码文件
 * 将修改过的字节码copy到dest,就可以实现编译期间干预字节码的目的
 */
void processDirectoryInput(DirectoryInput directoryInput, TransformOutputProvider outputProvider, boolean isIncremental) {
    File dest = outputProvider.getContentLocation(directoryInput.name, directoryInput.contentTypes, directoryInput.scopes, Format
            .DIRECTORY)
    FileUtils.forceMkdir(dest)

    println("isIncremental = $isIncremental")

    if (isIncremental) {
        String srcDirPath = directoryInput.getFile().getAbsolutePath()
        String destDirPath = dest.getAbsolutePath()
        Map<File, Status> fileStatusMap = directoryInput.getChangedFiles()
        for (Map.Entry<File, Status> changedFile : fileStatusMap.entrySet()) {
            Status status = changedFile.getValue()
            File inputFile = changedFile.getKey()
            String destFilePath = inputFile.getAbsolutePath().replace(srcDirPath, destDirPath)
            File destFile = new File(destFilePath)
            switch (status) {
                case Status.NOTCHANGED:
                    break
                case Status.ADDED:
                case Status.CHANGED:
                    FileUtils.touch(destFile)
                    transformSingleFile(inputFile, destFile)
                    break
                case Status.REMOVED:
                    if (destFile.exists()) {
                        FileUtils.forceDelete(destFile)
                    }
                    break
            }
        }
    } else {
        transformDirectory(directoryInput.file, dest)
    }
}

void transformSingleFile(File inputFile, File destFile) {
    println("拷贝单个文件")
    FileUtils.copyFile(inputFile, destFile)
}

void transformDirectory(File directoryInputFile, File dest) {
    println("拷贝文件夹 $dest -----")
    FileUtils.copyDirectory(directoryInputFile, dest)
}
```

根据是否为增量更新,如果不是,则删除之前的所有文件.然后对每个文件进行状态判断,根据其状态来决定到底是该删除,或者复制.开启增量编译之后,速度会有特别大的提升.

### 1.4 并发编译

毕竟是在电脑上进行编译,尽管压榨电脑性能,我们把并发编译给搞起.说来也轻巧,就下面几行代码就行

```groovy
private WaitableExecutor mWaitableExecutor = WaitableExecutor.useGlobalSharedThreadPool()
transformInvocation.inputs.each { input -> //这里的input是TransformInput

    input.jarInputs.each { jarInput ->
        //处理jar
        mWaitableExecutor.execute(new Callable<Object>() {
            @Override
            Object call() throws Exception {
                //多线程
                processJarInput(jarInput, outputProvider, isIncremental)
                return null
            }
        })
    }

    //处理源码文件
    input.directoryInputs.each { directoryInput ->
        //多线程
        mWaitableExecutor.execute(new Callable<Object>() {
            @Override
            Object call() throws Exception {
                processDirectoryInput(directoryInput, outputProvider, isIncremental)
                return null
            }
        })
    }
}

//等待所有任务结束
mWaitableExecutor.waitForTasksWithQuickFail(true)
```

增加的代码不多,其他都是之前的.就是让处理逻辑的地方放线程里面去执行,然后得等这些线程都处理完成才结束任务.

到这里Transform基本的API也将介绍完了,原理(系统有一些列Transform用于在class转dex的过程中的处理逻辑,我们也可以自定义Transform参与其中,这个Transform最终其实是在一个Task里面执行的.)的话也知晓了个大概,接下来我们看看如何利用ASM修改字节码实现炫酷的功能吧.

## 2. ASM


## 参考

- https://www.jianshu.com/p/811b0d0975ef
- https://mp.weixin.qq.com/s/s4WgLFN0A-vO0ko0wi25mA 郭霖公众号
- 别人写的库 https://github.com/Leaking/Hunter