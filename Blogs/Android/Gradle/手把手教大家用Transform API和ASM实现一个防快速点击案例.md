
## 0. 前言

我的所有原创[Android知识体系](https://github.com/xfhy/Android-Notes),已打包整理到GitHub.努力打造一系列适合初中高级工程师能够看得懂的优质文章,欢迎star~

> 建议阅读本篇文章之前掌握以下相关知识点: Android打包流程+Gradle插件+Java字节码

在Android Gradle Plugin中,有一个叫Transform API(从1.5.0版本才有的)的东西.利用这个Transform API咱可以在.class文件转换成dex文件之前,对.class文件进行处理.比如监控,埋点之类的. 

而对.class文件进行处理这个操作,咱们这里使用ASM.ASM是一个通用的Java字节码操作和分析框架。它可以直接以二进制形式用于修改现有类或动态生成类.咱们在打包的时候,直接操作字节码修改class,对运行时性能是没有任何影响的,所以它的效率是相当高的.

本篇文章给大家简单介绍一下Transform和ASM的使用,最后再结合一个小栗子练习一下.文中demo[源码地址](https://github.com/xfhy/GradleStudy/tree/master/buildSrc/src/main/groovy/transform)

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

### 2.1 介绍

[ASM官网](https://asm.ow2.io/)

官网上是这样介绍ASM的: ASM是一个通用的Java字节码操作和分析框架。它可以直接以二进制形式用于修改现有类或动态生成类。ASM提供了一些常见的字节码转换和分析算法，可从中构建定制的复杂转换和代码分析工具。ASM提供了与其他Java字节码框架类似的功能，但是侧重于 性能。因为它的设计和实现是尽可能的小和尽可能快，所以它非常适合在动态系统中使用（但当然也可以以静态方式使用，例如在编译器中）。(可能翻译得不是很准确,英文好的同学可以去官网看原话)

### 2.2 引入ASM

下面是我的demo中的buildSrc里面build.gradle配置.它包含了Plugin+Transform+ASM的所有依赖,放心拿去用.

```gradle
dependencies {
    implementation gradleApi()
    implementation localGroovy()
    //常用io操作
    implementation "commons-io:commons-io:2.6"

    // Android DSL  Android编译的大部分gradle源码
    implementation 'com.android.tools.build:gradle:3.6.2'
    implementation 'com.android.tools.build:gradle-api:3.6.2'
    //ASM
    implementation 'org.ow2.asm:asm:7.1'
    implementation 'org.ow2.asm:asm-util:7.1'
    implementation 'org.ow2.asm:asm-commons:7.1'
}
```

### 2.3 ASM基本使用

在使用之前我们先来看一些常用的对象

- **ClassReader** : 按照Java虚拟机规范中定义的方式来解析class文件中的内容,在遇到合适的字段时调用ClassVisitor中相应的方法
- **ClassVisitor** : Java中类的访问者,提供一系列方法由ClassReader调用.它是一个抽象类,在使用时需要继承此类.
- **ClassWriter** : 它是一个继承了ClassVisitor的类,主要负责将ClassReader传递过来的数据写到一个字节流中.在传递数据完成之后,可以通过它的toByteArray方法获得完整的字节流.
- **ModuleVisitor** : Java中模块的访问者,作为ClassVisitor.visitModule方法的返回值,要是不关心模块的使用情况,可以返回一个null.
- **AnnotationVisitor** : Java中注解的访问者,作为ClassVisitor.visitTypeAnnotation的返回值,不关心注解使用情况也是可以返回null.
- **FieldVisitor** : Java中字段的访问者,作为ClassVisitor.visitField的返回值,不关心字段使用情况也是可以返回null.
- **MethodVisitor**：Java中方法的访问者,作为ClassVisitor.visitMethod的返回值,不关心方法使用情况也是可以返回null.

上面这些对象先简单过一下,眼熟就行,待会儿会使用到这些对象.

大体工作流程: 通过ClassReader读取class字节码文件,然后ClassReader将读取到的数据通过一个ClassVisitor(上面的ClassWriter其实就是一个ClassVisitor)将数据表现出来.表现形式: 将字节码的每个细节按顺序通过接口的方式传递给ClassVisitor.就比如说,访问到了class文件的xx方法,就会回调ClassVisitor的visitMethod方法;访问到了class文件的属性,就会回调ClassVisitor的visitField方法.

ClassWriter是一个继承了ClassVisitor的类,它保存了这些由ClassReader读取出来的字节流数据,最后通过它的toByteArray方法获得完整的字节流.

上面的概念比较生硬,咱们先来写一个简单的复制class文件的方法:

```groovy
private void copyFile(File inputFile, File outputFile) {
    FileInputStream inputStream = new FileInputStream(inputFile)
    FileOutputStream outputStream = new FileOutputStream(outputFile)
    
    //1. 构建ClassReader对象
    ClassReader classReader = new ClassReader(inputStream)
    //2. 构建ClassVisitor的实现类ClassWriter
    ClassWriter classWriter = new ClassWriter(ClassWriter.COMPUTE_MAXS)
    //3. 将ClassReader读取到的内容回调给ClassVisitor接口
    classReader.accept(classWriter, ClassReader.EXPAND_FRAMES)
    //4. 通过classWriter对象的toByteArray方法拿到完整的字节流
    outputStream.write(classWriter.toByteArray())

    inputStream.close()
    outputStream.close()
}
```

看到这里,可能有的同学已经有点感觉了.ClassReader对象就是专门负责读取字节码文件的,而ClassWriter就是一个继承了ClassVisitor的类,当ClassReader读取字节码文件的时候,数据会通过ClassVisitor回调回来.咱们可以自定义一个ClassWriter用来接收读取到的字节数据,接收数据的同时,咱们再插入一点东西到这些数据的前面或者后面,最后通过ClassWriter的toByteArray方法将这些字节码数据导出,写入新的文件,这就是我们所说的插桩了.

现在咱们举个栗子,到底插桩能有啥用?就实现一个简单的需求吧,在每个方法的最前面插入一句打印`Hello World!`的代码.

修改前的代码如下所示:
```java
private void test() {
    System.out.println("test");
}
```
预期修改后的代码:
```java
private void test() {
    System.out.println("Hello World!");
    System.out.println("test");
}
```

将上面的复制文件的代码简单改改

```groovy
void traceFile(File inputFile, File outputFile) {
    FileInputStream inputStream = new FileInputStream(inputFile)
    FileOutputStream outputStream = new FileOutputStream(outputFile)

    ClassReader classReader = new ClassReader(inputStream)
    ClassWriter classWriter = new ClassWriter(ClassWriter.COMPUTE_MAXS)
    classReader.accept(new HelloClassVisitor(classWriter)), ClassReader.EXPAND_FRAMES)
    outputStream.write(classWriter.toByteArray())

    inputStream.close()
    outputStream.close()
}
```

唯一有变化的地方就是classReader的accept方法传入的ClassVisitor对象变了,咱自定义了一个HelloClassVisitor.

```groovy
class HelloClassVisitor extends ClassVisitor {

    HelloClassVisitor(ClassVisitor cv) {
        //这里需要指定一下版本Opcodes.ASM7
        super(Opcodes.ASM7, cv)
    }

    @Override
    MethodVisitor visitMethod(int access, String name, String descriptor, String signature, String[] exceptions) {
        def methodVisitor = cv.visitMethod(access, name, descriptor, signature, exceptions)
        return new HelloMethodVisitor(api, methodVisitor, access, name, descriptor)
    }
}
```

我们自定义了一个ClassVisitor,它将ClassWriter传入其中.在ClassVisitor的实现中,只要传入了classVisitor对象,那么就会将功能委托给这个classVisitor对象.相当于我传入的这个ClassWriter就读取到了字节码,最后toByteArray就是所有的字节码.多说无益,看看代码:

```java
public abstract class ClassVisitor {
    /** The class visitor to which this visitor must delegate method calls. May be null. */
  protected ClassVisitor cv;
  
   public ClassVisitor(final int api, final ClassVisitor classVisitor) {
    if (api != Opcodes.ASM7 && api != Opcodes.ASM6 && api != Opcodes.ASM5 && api != Opcodes.ASM4) {
      throw new IllegalArgumentException("Unsupported api " + api);
    }
    this.api = api;
    this.cv = classVisitor;
  }
  
  public AnnotationVisitor visitAnnotation(final String descriptor, final boolean visible) {
    if (cv != null) {
      return cv.visitAnnotation(descriptor, visible);
    }
    return null;
  }
  
  public MethodVisitor visitMethod(
      final int access,
      final String name,
      final String descriptor,
      final String signature,
      final String[] exceptions) {
    if (cv != null) {
      return cv.visitMethod(access, name, descriptor, signature, exceptions);
    }
    return null;
  }
  
  ...
}
```

有了我们传入的ClassWriter,咱们在自定义ClassVisitor的时候,只需要关注需要修改的地方即可.咱们是想对方法进行插桩,自然就得关心visitMethod方法,该方法会在ClassReader阅读class文件里面的方法时会回调.这里我们首先是在HelloClassVisitor的visitMethod中调用了ClassVisitor的visitMethod方法,拿到MethodVisitor对象.

而MethodVisitor是和ClassVisitor是类似的,在ClassReader阅读方法的时候会回调这个类里面的visitParameter(访问方法参数),visitAnnotationDefault(访问注解的默认值),visitAnnotation(访问注解)等等.

所以为了能够对方法插桩,咱们需要再包一层,自己实现一下MethodVisitor,我们将ClassWriter.visitMethod返回的MethodVisitor传入自定义的MethodVisitor,并在方法刚开始的地方进行插桩.AdviceAdapter是一个继承自MethodVisitor的类,它能够方便的回调方法进入(onMethodEnter)和方法退出(onMethodExit). 我们只需要在方法进入,也就是onMethodEnter方法里面进行插桩即可.

```groovy
class HelloMethodVisitor extends AdviceAdapter {

        HelloMethodVisitor(int api, MethodVisitor methodVisitor, int access, String name, String descriptor) {
            super(api, methodVisitor, access, name, descriptor)
        }

        //方法进入
        @Override
        protected void onMethodEnter() {
            super.onMethodEnter()
            //这里的mv是MethodVisitor
            mv.visitFieldInsn(GETSTATIC, "java/lang/System", "out", "Ljava/io/PrintStream;");
            mv.visitLdcInsn("Hello World!");
            mv.visitMethodInsn(INVOKEVIRTUAL, "java/io/PrintStream", "println", "(Ljava/lang/String;)V", false);
        }
}
```

插桩的核心代码,需要一些字节码的核心知识,这里不展开介绍,推荐大家阅读《深入理解Java虚拟机》关于字节码的章节.

当然,要想快速地写出这些代码也是有捷径的,安装一个`ASM Bytecode Outline`插件,然后随便写一个Test类,然后随便写一个方法

```java
public class Test {
    public void hello() {
        System.out.println("Hello World!");
    }
}
```
然后选中该Test.java文件,右键菜单,点击`Show ByteCode outline`

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/ASMified%E6%8F%92%E5%9B%BE.png)


在右侧窗口内选择ASMified,即可得到如下代码:

```
mv = cw.visitMethod(ACC_PUBLIC, "hello", "()V", null, null);
mv.visitCode();
Label l0 = new Label();
mv.visitLabel(l0);
mv.visitLineNumber(42, l0);
mv.visitFieldInsn(GETSTATIC, "java/lang/System", "out", "Ljava/io/PrintStream;");
mv.visitLdcInsn("Hello World!");
mv.visitMethodInsn(INVOKEVIRTUAL, "java/io/PrintStream", "println", "(Ljava/lang/String;)V", false);
Label l1 = new Label();
mv.visitLabel(l1);
mv.visitLineNumber(43, l1);
mv.visitInsn(RETURN);
Label l2 = new Label();
mv.visitLabel(l2);
mv.visitLocalVariable("this", "Lcom/xfhy/gradledemo/Test;", null, l0, l2, 0);
mv.visitMaxs(2, 1);
mv.visitEnd();
```

其中关于Label的咱不需要,所以只剩下核心代码

```
mv.visitFieldInsn(GETSTATIC, "java/lang/System", "out", "Ljava/io/PrintStream;");
mv.visitLdcInsn("Hello World!");
mv.visitMethodInsn(INVOKEVIRTUAL, "java/io/PrintStream", "println", "(Ljava/lang/String;)V", false);
```

到这里,ASM的基本使用已经告一段落.ASM可操作性非常强,人有多大胆,地有多大产.只要你想实现的,基本都能实现.关键在于你的想法.但是有个小问题,上面的插件只能生成一些简单的代码,如果需要写一些复杂的逻辑,就必须深入Java字节码,才能自己写出来或者是看懂ASM的插桩代码.

## 3. ASM 实战 防快速点击(抖动)

上面那个小demo在每个方法里面打印一句"Hello World!"好像没什么实际意义..咱决定做个有实际意义的东西,一般情况下,我们在做开发的会去防止用户快速点击某个View.这是为了追求更好的用户体验,如果不处理的话,在快速点击Button的时候可能会连续打开2个相同的界面,在用户看来确实有点奇怪,影响体验.所以,一般情况下,我们会去做一下限制.

处理的时候,其实也很简单,我们只需要取快速点击事件中的其中一次点击事件就行了.有哪些方案进行处理呢?下面是我想到的几种

1. 在BaseActivity的dispatchTouchEvent里判断一下,如果`ACTION_DOWN`&&快速点击则返回true就行.
2. 写一个工具类,记录上一次点击的时间,每次在onClick里面判断一下,是否为快速点击,如果是,则不响应事件.
3. 可以在方案2的基础上,记录每个View上一次的点击时间,控制更为精准.

下面是我简单实现的一个工具类`FastClickUtil.java`

```java
public class FastClickUtil {

    private static final int FAST_CLICK_TIME_DISTANCE = 300;
    private static long sLastClickTime = 0;

    public static boolean isFastDoubleClick() {
        long time = System.currentTimeMillis();
        long timeDistance = time - sLastClickTime;
        if (0 < timeDistance && timeDistance < FAST_CLICK_TIME_DISTANCE) {
            return true;
        }
        sLastClickTime = time;
        return false;
    }

}
```

有了这个工具类,那咱们就可以在每个onClick方法的最前面插入`isFastDoubleClick()`判断语句,简单判断一下即可实现防抖.就像下面这样:

```java
public void onClick(View view) {
    if (!FastClickUtil.isFastDoubleClick()) {
        ......
    }
}
```

为了实现上面这个最终效果,我们其实只需要这样做:

1. 找到onClick方法
2. 进行插桩

除了自定义ClassVisitor,其他代码是和上面的demo差不多的,咱直接看自定义ClassVisitor.

```java
class FastClickClassVisitor extends ClassVisitor {

    FastClickClassVisitor(ClassVisitor classVisitor) {
        super(Opcodes.ASM7, classVisitor)
    }

    @Override
    MethodVisitor visitMethod(int access, String name, String descriptor, String signature, String[] exceptions) {
        def methodVisitor = cv.visitMethod(access, name, descriptor, signature, exceptions)
        if (name == "onClick" && descriptor == "(Landroid/view/View;)V") {
            return new FastMethodVisitor(api, methodVisitor, access, name, descriptor)
        } else {
            return methodVisitor
        }
    }
}
```

在ClassVisitor里面的visitMethod里面,只需要找到onClick方法,然后自定义自己的MethodVisitor.

```java
class FastMethodVisitor extends AdviceAdapter {

    FastMethodVisitor(int api, MethodVisitor methodVisitor, int access, String name, String descriptor) {
        super(api, methodVisitor, access, name, descriptor)
    }

    //方法进入
    @Override
    protected void onMethodEnter() {
        super.onMethodEnter()
        mv.visitMethodInsn(INVOKESTATIC, "com/xfhy/gradledemo/FastClickUtil", "isFastDoubleClick", "()Z", false)
        Label label = new Label()
        mv.visitJumpInsn(IFEQ, label)
        mv.visitInsn(RETURN)
        mv.visitLabel(label)
    }
}
```

在方法进入(`onMethodEnter()`)里面调用FastClickUtil的静态方法isFastDoubleClick()判断一下即可.到此,我们的小案例计算全部完成了.可以看到,利用ASM轻轻松松就能实现我们之前看起来比较麻烦的功能,而且低侵入性,不用改动之前的所有代码.

插桩之后可以将编译完成的apk直接拖入jadx里面看一下最终源码验证,也可以直接将apk安装到手机上进行验证.

当然了,上面的这种实现有些不太人性化的地方.比如某些View的点击事件,不需要防抖.怎么办?用上面这种方式不太合适,咱可以自定义一个注解,在不需要处理防抖的onClick方法上标注一下这个注解.然后在ASM这边判断一下,如果某onClick方法上有这个注解就不进行插桩.事情完美解决.这里就不带着大家实现了,留给大家课后实践.

## 参考

- [ASM 官网](https://asm.ow2.io/)
- [AOP 的利器：ASM 3.0 介绍](https://developer.ibm.com/zh/articles/j-lo-asm30/)
- [ASM 库的介绍和使用](https://www.jianshu.com/p/905be2a9a700)
- [ASM（初探使用）](https://www.jianshu.com/p/a8efa6fac367)
- [Android Gradle Plugin打包Apk过程中的Transform API](https://www.jianshu.com/p/811b0d0975ef)
- [一起玩转Android项目中的字节码](https://mp.weixin.qq.com/s/s4WgLFN0A-vO0ko0wi25mA)
- [【Android】函数插桩（Gradle + ASM）](https://www.jianshu.com/p/16ed4d233fd1)
- [Hunter](https://github.com/Leaking/Hunter)