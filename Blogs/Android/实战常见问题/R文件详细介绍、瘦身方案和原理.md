R文件详细介绍、瘦身方案和原理
---
#### 目录
- [1. 背景](#head1)
- [2. R文件介绍](#head2)
	- [2.1 R文件概念](#head3)
		- [2.1.1 标识符是怎么与资源联系起来的？](#head4)
	- [2.2 R文件内容](#head5)
	- [2.3 library module和aar的R文件内容生成规则](#head6)
	- [2.4 是谁生成的R文件？](#head7)
	- [2.5 打包之后的R文件](#head8)
	- [2.6 R文件为啥大？这么多？](#head9)
- [3. 为什么R文件可以瘦身？](#head10)
- [4. 怎么对R文件进行瘦身？](#head11)
	- [4.1 R文件瘦身Transform demo](#head12)
- [5. 有没有开箱即用的开源库？](#head13)
	- [5.1 booster的R文件瘦身原理](#head14)
- [6. 官方R瘦身方案](#head15)
	- [6.1 官方方案介绍](#head16)
	- [6.2 官方R瘦身方案原理](#head17)
- [7. 其他](#head18)
	- [7.1 nonTransitiveRClass是什么？](#head19)
	- [7.2 AGP8.0，application module中R文件中的属性不再是常量](#head20)
	- [7.3 延伸：R文件field上限](#head21)
- [8. 小结](#head22)

---

## <span id="head1">1. 背景</span>

平时在代码里面可以用R.x.x引用资源文件，非常方便，但是方便的同时，也带来了一些副作用，也就是包体积的增长。特别是如果项目的体量比较大，module比较多的情况，包体积增大尤其突出，会有很多冗余的R文件，散落在各个角落。我们从实战出发，探索下通过内联R文件优化包体积的问题。

> 环境说明：文中demo所用的Android Gradle Plugin 版本为 4.0.1，Gradle 版本为 gradle-6.1.1，jadx版本为1.4.7，Android Studio版本为Android Studio Giraffe | 2022.3.1 Patch 2，不同版本存在差异！demo的仓库地址：https://github.com/xfhy/RInlineDemo

## <span id="head2">2. R文件介绍</span>

在开始之前，我们首先需要知道R文件是什么？以及里面有什么内容？作为一名Android Coder，不出意外的话，每天都会接触到R.x.x。

### <span id="head3">2.1 R文件概念</span>

R文件是什么：R文件是Android开发中的一个特殊的文件，它包含了应用程序中所使用的所有的资源。R文件是自动生成的，当你添加或删除资源时，R文件会自动更新。

R文件的主要作用是为应用程序中的资源提供一个唯一的标识符，表示资源索引，这样我们就可以在代码中使用这些标识符来使用资源。比如，如果有一个名为"main.xml"的布局文件，R文件会为它分配一个唯一的标识符，如R.layout.main。R文件里面包含了各种类型的资源标识符，除了布局，还有字符串、图像、颜色等。

apk在编译打包过程中，位于res目录下的文件会通过aapt2进行编译和压缩，最终生成：

- resources.arsc二进制文件：资源索引表（样式、字符串、dimens等），建立id与其对应资源的值
- R.java 文件（包含了所有资源的id常量），有了 id 之后，就可以去 resource.arsc 里面去查找到真正的资源，将 id 作为 key，就可以查到此 id 对应的资源；
- 非编译文件（图片音频视频等，直接copy，不会压缩）
- 编译后的二进制xml文件，如layout文件、drawable的xml文件

#### <span id="head4">2.1.1 标识符是怎么与资源联系起来的？</span>

R.x.x 标识符拿到了，那什么时候去resources.arsc取数据，并且使用起来的？在Android中，我们可以使用如下语句设置布局：

```java
setContentView(R.layout.activity_main);
```

这里仅仅是传入了一个标示符，`R.layout.activity_main`最终的值是类似`0x7f040000`这种，而不是传入`./res/layout/activity_main.xml`文件路径。实际上，R文件中所有的标识符所对应的资源在resources.arsc二进制文件中都有记录，所以resources.arsc也被称之为资源索引表。上面的`setContentView`，会先拿`0x7f040000`去resources.arsc里面找这个标识符对应的是哪个资源，然后才去实际加载对应的那个资源(`activity_main`)。

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/resources结构.png)

### <span id="head5">2.2 R文件内容</span>

先简单写个Demo：

> 不使用Kotlin，就使用纯Java，activity继承自Activity，移除core-ktx、appcompat、material、constraintlayout等，避免干扰

1. 有一个application module，里面一个MainActivity，对应布局为`activity_main`，里面有4个按钮，按钮id为`btn_app_module....`；
2. 新建一个library module命名为mylibrary，里面有一个Activity：MyActivity，对应布局为`activity_my`，里面有4个按钮，按钮id为`btn_first_library....`；
3. 新建一个library module命名为mylibrary2，里面有一个Activity：MySecondActivity，对应布局为`activity_my_second`，里面有4个按钮，按钮id为`btn_second_library....`；
4. application module引入mylibrary、mylibrary2，然后在MainActivity的onCreate里面启动MyActivity、MySecondActivity
5. Android Gradle Plugin 版本为 4.0.1，Gradle 版本为 gradle-6.1.1


现在我们看一下编译过程中会产生哪些R文件，我的R文件存在路径：`./app/build/intermediates/compile_and_runtime_not_namespaced_r_class_jar/release/R.jar`（不同gradle版本路径不同），这个R.jar文件包含了项目中所有的R文件，如application module的R文件、mylibrary的R文件、mylibrary2的R文件、三方库aar中的R文件等。用jadx打开看一下：

首先是mylibrary中的R文件

```java
package com.xfhy.mylibrary;

/* loaded from: R.jar:com/xfhy/mylibrary/R.class */
public final class R {

    /* loaded from: R.jar:com/xfhy/mylibrary/R$id.class */
    public static final class id {
        public static final int btn_first_library = 0x7f030004;
        public static final int btn_first_library_1 = 0x7f030005;
        public static final int btn_first_library_2 = 0x7f030006;
        public static final int btn_first_library_3 = 0x7f030007;

        private id() {
        }
    }

    /* loaded from: R.jar:com/xfhy/mylibrary/R$layout.class */
    public static final class layout {
        public static final int activity_my = 0x7f040001;

        private layout() {
        }
    }

    private R() {
    }
}
```

其次是mylibrary2中的R文件

```java
package com.xfhy.mylibrary2;

/* loaded from: R.jar:com/xfhy/mylibrary2/R.class */
public final class R {

    /* loaded from: R.jar:com/xfhy/mylibrary2/R$id.class */
    public static final class id {
        public static final int btn_second_library = 0x7f030008;
        public static final int btn_second_library1 = 0x7f030009;
        public static final int btn_second_library2 = 0x7f03000a;
        public static final int btn_second_library3 = 0x7f03000b;

        private id() {
        }
    }

    /* loaded from: R.jar:com/xfhy/mylibrary2/R$layout.class */
    public static final class layout {
        public static final int activity_my_second = 0x7f040002;

        private layout() {
        }
    }

    private R() {
    }
}
```

然后是application module中的R文件

```java
package com.xfhy.rinlinedemo;

/* loaded from: R.jar:com/xfhy/rinlinedemo/R.class */
public final class R {

    /* loaded from: R.jar:com/xfhy/rinlinedemo/R$color.class */
    public static final class color {
        public static final int black = 0x7f010000;
        public static final int white = 0x7f010001;

        private color() {
        }
    }

    /* loaded from: R.jar:com/xfhy/rinlinedemo/R$drawable.class */
    public static final class drawable {
        public static final int ic_launcher_background = 0x7f020001;
        public static final int ic_launcher_foreground = 0x7f020002;

        private drawable() {
        }
    }

    /* loaded from: R.jar:com/xfhy/rinlinedemo/R$id.class */
    public static final class id {
        public static final int btn_app_module = 0x7f030000;
        public static final int btn_app_module1 = 0x7f030001;
        public static final int btn_app_module2 = 0x7f030002;
        public static final int btn_app_module3 = 0x7f030003;
        // 注意看，这些id是library的
        public static final int btn_first_library = 0x7f030004;
        public static final int btn_first_library_1 = 0x7f030005;
        public static final int btn_first_library_2 = 0x7f030006;
        public static final int btn_first_library_3 = 0x7f030007;
        public static final int btn_second_library = 0x7f030008;
        public static final int btn_second_library1 = 0x7f030009;
        public static final int btn_second_library2 = 0x7f03000a;
        public static final int btn_second_library3 = 0x7f03000b;

        private id() {
        }
    }

    /* loaded from: R.jar:com/xfhy/rinlinedemo/R$layout.class */
    public static final class layout {
        public static final int activity_main = 0x7f040000;
        public static final int activity_my = 0x7f040001;
        public static final int activity_my_second = 0x7f040002;

        private layout() {
        }
    }

    /* loaded from: R.jar:com/xfhy/rinlinedemo/R$mipmap.class */
    public static final class mipmap {
        public static final int ic_launcher = 0x7f050000;
        public static final int ic_launcher_round = 0x7f050001;

        private mipmap() {
        }
    }

    /* loaded from: R.jar:com/xfhy/rinlinedemo/R$string.class */
    public static final class string {
        public static final int app_name = 0x7f060000;

        private string() {
        }
    }

    /* loaded from: R.jar:com/xfhy/rinlinedemo/R$style.class */
    public static final class style {
        public static final int RInlineDemo = 0x7f070000;

        private style() {
        }
    }

    /* loaded from: R.jar:com/xfhy/rinlinedemo/R$xml.class */
    public static final class xml {
        public static final int backup_rules = 0x7f080000;
        public static final int data_extraction_rules = 0x7f080001;

        private xml() {
        }
    }

    private R() {
    }
}
```

通过观察，我们简单分析一下：

- 首先我们注意到R首先是一个类，其内部又有很多`public static final`的静态内部类，内部类可能包含：anim、animator、attr、bool、color、dimen、drawable、id、integer、interpolator、layout、mipmap、plurals、string、style、styleable、xml，每个内部类有单独的含义，如anim就是动画相关资源的id、string则是字符串相关资源的id；
- 一个`R.java`里面有多少个静态内部类就要生成多少个`.class`文件；
- 每个id的值是唯一的，且是递增的（比如我们上面的id是从`0x7f030000`开始递增的），并且application module中的id是首先开始排序开始递增的，然后才是mylibray中的id开始排序递增，这样可以避免id冲突；
- 每个id的值都是通过`static final`来进行修饰的，也就是说这是常量（一提到常量，那么自然而然就想到编译时内联，如`R.xml.backup_rules`替换成`0x7f080000`）;
- 每个id的值都是通过16进制的int数值来表示的;
- 每个模块最后都是按照 AndroidManifest.xml 里面定义的 package 来决定要生成的 R 文件的包名
- application module中的R文件包含了各个library的R文件的所有数据，可以发现，R数据有冗余，有优化的空间


16进制的int数值含义：

1. 第一个字节7f：代表着这个资源属于本应用apk的资源，相应的以01代表开头的话（比如`0x01010000`）就代表这是一个与应用无关的系统资源。`0x7f010000`，表明`black` 属于我们应用的一个资源
2. 第二个字节01:是指资源的类型，比如01就代表着这个资源属于anim类型
3. 第三，四个字节0000:指资源的编号，在所属资源类型中，一般从0000开始递增


### <span id="head6">2.3 library module和aar的R文件内容生成规则</span>

library module和aar的R文件内容生成规则和application module的大致相同，但有一点点不同。app的R文件中的id类里面的`btn_app_module`是从`0x7f030000`开始的，如果library module和aar的R文件中的id类里面的属性也是从`0x7f030000`开始的话，那么就有问题，id冲突了，必须是唯一的才行。这个问题，gradle是这么解决的：对于library模块，R文件的索引值弄成非常量，也就是一个**普通的static属性**（！！！），因为暂时还不确定最终的id值是多少，编译library module或者aar时，生成一个R-def.txt（或R.txt，不同版本不一样），该文件记录着资源映射关系。而application module生成的R文件则里面都是`static final`的常量。我的mylibrary的R-def.txt文件路径：`./mylibrary/build/intermediates/local_only_symbol_list/debug/R-def.txt`

```java
public final class R {
    
    public static final class id {
        // 还未形成最终形态的R文件，是非常量的
        public static int btn_first_library = 0x00000000;
        public static int btn_first_library_1 = 0x00000000;
        public static int btn_first_library_2 = 0x00000000;
        public static int btn_first_library_3 = 0x00000000;

        private id() {
        }
    }

    /* loaded from: R.jar:com/xfhy/mylibrary/R$layout.class */
    public static final class layout {
        public static int activity_my = 0x00000000;

        private layout() {
        }
    }

    private R() {
    }
}
```

```txt
// R-def.txt
R_DEF: Internal format may change without notice
local
id btn_first_library
id btn_first_library_1
id btn_first_library_2
id btn_first_library_3
layout activity_my
```

很清晰，我的mylibrary有4个id，1个layout。可以看到，这里面只有名称和类型，没有资源真正的id值，生成的这些东西到时会当做一个输入传给app模块一起编译。从而得到最终的资源id，也就是一个全局的R文件，里面包含项目里面所有的资源的id（所有module和aar，所有layout和字符串等id），同时会生成一个项目总的R.txt文件（该txt文件里面包含着所有的资源id和对应的值，我的R.txt路径是`./app/build/intermediates/runtime_symbol_list/release/R.txt`）。并且此时会执行子library的generateReleaseRFile生成子library的专属R类文件，这个文件里面只包含该子module的id和资源映射关系。并且子library和aar生成的R文件是等aap module中的R文件生成好了之后，才能生成的，因为它们的数值得在application module的R.x最后一个的数值上进行递增。比如我们上面看到的：

```java
// application module R文件
public final class R {
    public static final class id {
        ....
        // 这是application module的最后一个id值
        public static final int btn_app_module3 = 0x7f030003;
        // 这是mylibrary的第一个id值
        public static final int btn_first_library = 0x7f030004;
        ....
    }
}
```

```java
// mylibrary module R文件
public final class R {

    public static final class id {
        public static final int btn_first_library = 0x7f030004;
        public static final int btn_first_library_1 = 0x7f030005;
        public static final int btn_first_library_2 = 0x7f030006;
        public static final int btn_first_library_3 = 0x7f030007;
        ....
    }
    ....
}
```

最终形成的library或aar的R文件就是常量类型的了。

### <span id="head7">2.4 是谁生成的R文件？</span>

**所有R文件的生成都是在apk生成的时候由AGP交给aapt2完成的**。开发期间对R文件的引用其实是一个临时的classpath:R.java(或者R.jar)，这里面包含了编译时期所需要的R文件，编译就不会出错。在打包时会扔掉这些临时的R文件，真正的R文件是aapt2生成的。

- module/aar里面临时生成的R文件只是为了让编译通过，在编译流程中扮演的是compileOnly的角色
- 在生成apk时，aapt2会根据app里面的资源，生成真正的R文件到apk中，运行的时候代码就会获取到aapt2生成的id

扩展：**aapt2（Android资源打包工具）是一种构建工具，Android Studio和AGP使用它来编译和打包应用的资源。aapt2会解析资源、为资源编制索引，并将资源编译为针对Android平台进行过优化的二进制格式。** AGP 3.0.0及之后的版本默认情况下会使用aapt2，之前的aapt已经过时了。

### <span id="head8">2.5 打包之后的R文件</span>

非常简单，将minifyEnabled设置为true，打个release包看一下R文件在release包中的存在形式是什么样的。直接将打包出来的apk拖入jadx，首先看下application module的MainActivity：

```java
package com.xfhy.rinlinedemo;

/* loaded from: classes.dex */
public class MainActivity extends Activity {
    @Override // android.app.Activity
    public void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        setContentView(R.layout.activity_main);
        startActivity(new Intent(this, MyActivity.class));
        startActivity(new Intent(this, MySecondActivity.class));
    }
}

//并且com.xfhy.rinlinedemo包名下，MainActivity旁边居然有一个R.java
package com.xfhy.rinlinedemo;

/* JADX INFO: This class is generated by JADX */
public final class R {

    public static final class layout {
        public static final int activity_main = 0x7f040000;
        public static final int activity_my = 0x7f040001;
        public static final int activity_my_second = 0x7f040002;
    }
}
```

可以看到，application module里面，MainActivity使用R内部的常量居然没有被内联？R文件也还在。后面我发现`JADX INFO: This class is generated by JADX`，jadx说这个R文件是它自己生成的。我：？？？这个R文件是jadx自动生成的话，那上面的`MainActivity#onCreate`里面的`R.layout.activity_main`你怎么解释？难道也是假的，优化阅读体验的障眼法？怀着忐忑的心情，我将apk拖入Android Studio，在MainActivity上右键 -> Show Bytecode：

```smail
.class public Lcom/xfhy/rinlinedemo/MainActivity;
...

# virtual methods
.method public onCreate(Landroid/os/Bundle;)V
    .registers 3
    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V
    const/high16 p1, 0x7f040000
    invoke-virtual {p0, p1}, Landroid/app/Activity;->setContentView(I)V
    ...
.end method
```

嗯，R文件中的常量`activity_main = 0x7f040000`已经被内联了，jadx弄了个假的R类出来方便阅读。对smali语法感兴趣的同学，可参考我之前写的文章[反编译基础知识](https://blog.csdn.net/xfhy_/article/details/107026357?spm=1001.2014.3001.5501)，这里不再赘述。咱们继续看下MyActivity和MySecondActivity的smali

```smali
// MyActivity
.class public Lcom/xfhy/mylibrary/MyActivity;
...
.method public onCreate(Landroid/os/Bundle;)V
    .registers 2
    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V
    // 注释1
    sget p1, La/a/a/a;->activity_my:I
    invoke-virtual {p0, p1}, Landroid/app/Activity;->setContentView(I)V
    return-void
.end method

// MySecondActivity
.class public Lcom/xfhy/mylibrary2/MySecondActivity;
...
# virtual methods
.method public onCreate(Landroid/os/Bundle;)V
    .registers 2
    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V
    // 注释2
    sget p1, La/a/b/a;->activity_my_second:I
    invoke-virtual {p0, p1}, Landroid/app/Activity;->setContentView(I)V
    return-void
.end method
```

重点看一下我上面标注的注释1和注释2处，MyActivity的布局是从`a/a/a/a`这个类里面取的`activity_my`属性，这是啥？我们看一下

```java
package a.a.a;

/* loaded from: classes.dex */
public final class a {
    public static final int activity_my = 2130968577;
}
```

其实就是mylibrary这个library的R文件，这里的`activity_my`常量没有被内联，所以该R文件也被最终打入到release的apk中。注释2处也是类似的：

```java
package a.a.b;

/* loaded from: classes.dex */
public final class a {
    public static final int activity_my_second = 2130968578;
}
```

从上面的分析不难得出一个结论：application module的R文件被内联了，该R文件因为没有用处所以没有被打入到release的apk中。library module的R文件中的常量没有被内联，所以对应的R文件最终会进入apk中。这里延伸一个点，其实每个aar（用到了R文件的）最终也会打一个R文件进入apk中，并且里面的属性都是常量。

**library或aar的R文件里面都是常量，为什么没有被内联？？？**

library module 或者 aar 在编译的时候，AGP 会为它们提供一个临时的 R.java 来帮助它们编译通过。我们知道，如果一个常量被标记为 `static final`，那么编译器会在编译的时候将它们内联到使用这个常量的代码处，来减少一次变量的内存寻址。AGP 为 library module 或者 aar 提供的 R.java 里面的 R.x.x 不是`static final`的，而是 `static` 的，那么自然在 library module 或者 aar 编译的时候不会去内联。如果设计成了`static final`的，R.x.x 肯定是不能用的，因为 module 里面的代码就不会去寻找 aapt2 生成的 R.x.x 了，而是用编译时期 AGP 提供给它的假的 R.x.x （假的这玩意儿内联进去了），这样会导致 resource not found。

生成这些常量的时候已经晚了，library最终生成的class列表里面根本就没有R.class，平时生成的那个R.java仅仅是为了编译通过，打aar时不会打进去，app引入时才能在自己的资源id的值基础上进行递增，产生library最终的R.class。但此时library的代码早已编译成class（比如上面的MyActivity），不能再进行内联了，晚了。

### <span id="head9">2.6 R文件为啥大？这么多？</span>

从上面的观察中就能看到application 的R文件其实是将依赖的2个library module的R文件相加，然后再加上自己的R文件内容。这里其实可以扩展开来，**module中的R文件采用对依赖库的R进行累计叠加的方式进行生成**。举个例子，假设app的架构如下：

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/R文件瘦身_module举例.png)

编译打包时每个模块生成的R文件如下：

- `R_lib1` = `R_lib1`;
- `R_lib2` = `R_lib2`;
- `R_lib3` = `R_lib3`;
- `R_business1` = `R_lib1` + `R_lib2` + `R_lib3` + `R_business1`(business1本身的R)
- `R_business2` = `R_lib2` + `R_lib3` + `R_business2`(business2本身的R)
- `R_app` = `R_lib1` + `R_lib2` + `R_lib3` + `R_business1` + `R_business2` + `R_app`(app本身R)

虽然最终每个模块生成的R文件内部都是常量，但只有application module中的R文件中的常量会被内联，从而在打release包的时候会把该R文件给移除掉，因为用不上了；library module和aar中的R文件中的常量生成的时间晚于class的生成时间，这些常量不会内联，于是R文件得以保留到release包中，module越多，引用层级越多，R文件内容就越庞大。最终在release包中，你随便查看一个module下的R文件可能都有几十k，甚至上百k的大小。假设你有上百个module，并且module的数量还在持续增加，你想想这R文件总体积得多大啊，最终它们会导致包体积急剧增长。

## <span id="head10">3. 为什么R文件可以瘦身？</span>

application module中的R文件是项目所有R文件内容的总和，所以按道理library和aar中的那些class能直接使用这个R文件中的常量，注意是直接使用里面的常量，而不是使用R文件去引用这些常量，类似于内联。这样的话，所有R文件都没有存在的必要了（除R#styleable, styleable字段是一个例外，它不是常量，它是 `int[]`），已经没人在引用它了，最后打release包时会被shrink掉，从而减小包体积。

有些地方通过 `TypedArray.getResourceId(int, int)` 或 `Resources.getIdentifier(String, String, String)` 来获取索引值的资源，这种情况不能进行上面的优化，需要保留相关的R文件。

## <span id="head11">4. 怎么对R文件进行瘦身？</span>

在了解怎么进行瘦身之前，先看下我的demo中，application module中的MainActivity对应release的字节码：

```
  protected void onCreate(android.os.Bundle);
    Code:
       0: aload_0
       1: aload_1
       2: invokespecial #2                  // Method android/app/Activity.onCreate:(Landroid/os/Bundle;)V
       5: aload_0
       6: ldc           #4                  // int 2130968576
       8: invokevirtual #5                  // Method setContentView:(I)V

```
可以看到，setContentView使用资源的索引时，直接使用的是ldc指令，ldc指令是将常量值压入栈顶的指令。

再看library中MySecondActivity的字节码

```
  protected void onCreate(android.os.Bundle);
    Code:
       0: aload_0
       1: aload_1
       2: invokespecial #2                  // Method android/app/Activity.onCreate:(Landroid/os/Bundle;)V
       5: aload_0
       6: getstatic     #3                  // Field com/xfhy/mylibrary2/R$layout.activity_my_second:I
       9: invokevirtual #4                  // Method setContentView:(I)V
      12: return
```
这里setContentView使用资源的索引时，使用的是getstatic指令，getstatic指令是从类的静态变量区中获取变量的值，并将其推送到操作数栈顶的指令。

application module中使用R文件的地方，使用的是ldc指令访问的资源id，从而没有引用R文件，常量被内联了。而在library module中，是使用getstatic访问的R文件中的常量，R文件被引用着的，R文件就会被保留。

所以，我们要对R文件进行瘦身，就要对class进行操作，首先想到的就是 `Transform+ASM` ，将class中读取R文件内容（ getstatic 指令）的地方替换成直接使用常量（LDC 指令），如直接使用`0x7f040000`替换原来的`a.a.b.a.activity_my_second`。替换完成之后，这些R文件就没有地方在引用了，最后打release包时会被shrink掉，从而减小包体积。

那么在 Transform 之前我们首先需要拿到所有资源名称与索引值的映射关系，才能根据class使用的资源名称进行索引值替换，这个可以通过解析 Symbol List (R.txt，位于`./app/build/intermediates/runtime_symbol_list/release/R.txt`)来解决，这个R文件里面的内容覆盖了整个项目。我的demo中R.txt内容如下：

```
int color black 0x7f010000
int color white 0x7f010001
int drawable ic_launcher_background 0x7f020001
int drawable ic_launcher_foreground 0x7f020002
int id btn_app_module 0x7f030000
int id btn_app_module1 0x7f030001
int id btn_app_module2 0x7f030002
int id btn_app_module3 0x7f030003
int id btn_first_library 0x7f030004
int id btn_first_library_1 0x7f030005
int id btn_first_library_2 0x7f030006
int id btn_first_library_3 0x7f030007
int id btn_second_library 0x7f030008
int id btn_second_library1 0x7f030009
int id btn_second_library2 0x7f03000a
int id btn_second_library3 0x7f03000b
int layout activity_main 0x7f040000
int layout activity_my 0x7f040001
int layout activity_my_second 0x7f040002
int mipmap ic_launcher 0x7f050000
int mipmap ic_launcher_round 0x7f050001
int string app_name 0x7f060000
int style RInlineDemo 0x7f070000
int xml backup_rules 0x7f080000
int xml data_extraction_rules 0x7f080001
```

### <span id="head12">4.1 R文件瘦身Transform demo</span>

Transform和ASM相关的这里不做介绍，我们只看核心代码：

```
// 第一步 
static Map<String, Integer> parseRFile() {
    // 读取 Symbol List R文件
    File rFile = new File("./build/intermediates/runtime_symbol_list/release/R.txt")
//        File rFile = new File("./build/intermediates/runtime_symbol_list/debug/R.txt")
    BufferedReader reader = new BufferedReader(new FileReader(rFile))

    // 解析 Symbol List R文件
    Map<String, Integer> resourceIds = new HashMap<>()
    String line
    while ((line = reader.readLine()) != null) {
        if (line == null || line.isEmpty()) {
            continue
        }
        def datas = line.split(" ")
        String resourceName = datas[2]
        Integer resourceId = Integer.parseInt(datas[3].substring(2), 16)
        resourceIds.put(resourceName, resourceId)
    }

    return resourceIds
}

// 第二步
@Override
void visitFieldInsn(int opcode, String owner, String name, String descriptor) {
    if (opcode == Opcodes.GETSTATIC) {
        // 检查是否引用了R资源
        if (owner.contains("/R\$")) {
            // 获取资源ID
            Integer resourceId = resourceIds.get(name)
            if (resourceId != null) {
                // 将资源ID直接写入字节码
                mv.visitLdcInsn(resourceId)
                return
            }
        }
    }

    super.visitFieldInsn(opcode, owner, name, descriptor)
}

```

其实要实现R文件瘦身的插件demo非常容易，就是先把R.txt内容读取出来，然后判断有地方在使用类似`R$xx.x`这种时，直接替换成我们从R.txt中读取出来的索引值。替换之后，打release包效果：

```
// demo中MySecondActivity.class
.method public onCreate(Landroid/os/Bundle;)V
    .registers 2

    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V

    const p1, 0x7f040002

    invoke-virtual {p0, p1}, Landroid/app/Activity;->setContentView(I)V

    return-void
.end method
```

上面是demo中一个library MySecondActivity的onCreate的smali代码，可以看到setContentView时已经不需要R文件了，直接用常量。此时demo打的release包中没有任何R文件，已经被完美去除。当然上面的R文件瘦身plugin是不完善的，比如白名单机制、各种健壮性处理等。

## <span id="head13">5. 有没有开箱即用的开源库？</span>

当然有，比如：

- 滴滴 booster  https://github.com/didi/booster
- 字节 bytex  https://github.com/bytedance/ByteX

怎么选择？这里我说一下我的看法，首先2个开源库都是大公司产的，有实际商业应用，而且开源时间也比较久了，稳定性这块有保证。再看2个库的更新时间，bytex上次更新是2021年，也就是说2年没更新了；booster上次更新是3周前，并且适配了各个gradle版本，这也太贴心了吧。所以我会毫不犹豫地选择booster。

### <span id="head14">5.1 booster的R文件瘦身原理</span>

核心原理和我上面的demo是类似的，只不过booster是用kotlin写的，而且兼容了各种gradle版本，开源很久了，稳定性很强。我们直接看R文件瘦身的核心逻辑：

```kotlin
// RInlineTransformer.kt
@AutoService(ClassTransformer::class)
class RInlineTransformer : ClassTransformer {
    override fun onPreTransform(context: TransformContext) {
        // 开始转换之前
        // 收集app包名
        this.appPackage = context.originalApplicationId.replace('.', '/')
        // 日志打印,最终会将日志全部写到report.txt
        this.logger = getReport(context, "report.txt").touch().printWriter()
        // 符号列表   R.txt
        this.symbols = SymbolList.from(context.artifacts.get(SYMBOL_LIST).single())
        // R$style
        this.appRStyleable = "$appPackage/$R_STYLEABLE"
        // 需要忽略的包名,这些包名下的R类会被忽略
        this.ignores = context.getProperty(PROPERTY_IGNORES, "").trim().split(',')
                .filter(String::isNotEmpty)
                .map(Wildcard.Companion::valueOf).toSet()

        //  R.txt为空,那没有干活的必要了
        if (this.symbols.isEmpty()) {
            logger_.error("Inline R symbols failed: R.txt doesn't exist or blank")
            this.logger.println("Inlining R symbols failed: R.txt doesn't exist or blank")
            return
        }

        val retainedSymbols: Set<String>
        val deps = context.dependencies
        // 如果有constraintlayout相关的依赖,则需要排除一些白名单R文件
        if (deps.any { it.contains(SUPPORT_CONSTRAINT_LAYOUT) || it.contains(JETPACK_CONSTRAINT_LAYOUT) }) {
            // Find symbols that should be retained
            retainedSymbols = context.findRetainedSymbols()
            if (retainedSymbols.isNotEmpty()) {
                this.ignores += setOf(Wildcard.valueOf("android/support/constraint/R\$id"))
                this.ignores += setOf(Wildcard.valueOf("androidx/constraintlayout/R\$id"))
                this.ignores += setOf(Wildcard.valueOf("androidx/constraintlayout/widget/R\$id"))
            }
        } else {
            retainedSymbols = emptySet()
        }

        logger.println(deps.joinToString("\n  - ", "dependencies:\n  - ", "\n"))
        logger.println("$PROPERTY_IGNORES=$ignores\n")

        retainedSymbols.ifNotEmpty { symbols ->
            logger.println("Retained symbols:")
            symbols.forEach {
                logger.println("  - R.id.$it")
            }
            logger.println()
        }

    }
}
```

在开始Transform之前，会对R.txt文件进行读取，拿到项目所有的索引值内容。然后是白名单的读取，在白名单里面的R文件，不进行内联优化。再看一下Transform的逻辑：

```kotlin
// RInlineTransformer.kt
@AutoService(ClassTransformer::class)
class RInlineTransformer : ClassTransformer {
    override fun transform(context: TransformContext, klass: ClassNode): ClassNode {
        if (this.symbols.isEmpty()) {
            return klass
        }
        if (this.ignores.any { it.matches(klass.name) }) {
            logger.println("Ignore `${klass.name}`")
        } else if (Pattern.matches(R_REGEX, klass.name) && klass.name != appRStyleable) {
            // 类似 com/xfhy/mylibrary2/R 或者 com/xfhy/mylibrary2/R$layout  ,就会走到这里来
            // 相当于是把R文件的fields全部清空,因为用不上了
            klass.fields.clear()
            removedR[klass.name] = klass.bytes()
        } else {
            klass.replaceSymbolReferenceWithConstant()
        }

        return klass
    }
    
    private fun ClassNode.replaceSymbolReferenceWithConstant() {
        methods.forEach { method ->
            val insns = method.instructions.iterator().asIterable().filter {
                it.opcode == GETSTATIC
            }.map {
                it as FieldInsnNode
            }.filter {
                ("I" == it.desc || "[I" == it.desc)
                        && it.owner.substring(it.owner.lastIndexOf('/') + 1).startsWith("R$")
                        && !(it.owner.startsWith(COM_ANDROID_INTERNAL_R) || it.owner.startsWith(ANDROID_R))
            }

            val intFields = insns.filter { "I" == it.desc }
            val intArrayFields = insns.filter { "[I" == it.desc }

            // Replace int field with constant   获取R文件中int值的地方,替换为常量
            intFields.forEach { field ->
                val type = field.owner.substring(field.owner.lastIndexOf("/R$") + 3)
                try {
                    method.instructions.insertBefore(field, LdcInsnNode(symbols.getInt(type, field.name)))
                    method.instructions.remove(field)
                    // 类似com/xfhy/mylibrary2/R$layout.activity_my_second => 2130968578: com/xfhy/mylibrary2/MySecondActivity.onCreate(Landroid/os/Bundle;)V
                    logger.println(" * ${field.owner}.${field.name} => ${symbols.getInt(type, field.name)}: $name.${method.name}${method.desc}")
                } catch (e: NullPointerException) {
                    logger.println(" ! Unresolvable symbol `${field.owner}.${field.name}`: $name.${method.name}${method.desc}")
                }
            }

            // Replace library's R fields with application's R fields
            // library的R,获取R文件中int数组的地方,替换为application的R文件中的属性引用,这样该R文件就没用了
            intArrayFields.forEach { field ->
                field.owner = "$appPackage/${field.owner.substring(field.owner.lastIndexOf('/') + 1)}"
            }
        }
    }
    
}
```

1. 首先是对白名单R文件的过滤
2. 其次是将内联的R文件的所有fields给清除了，这样R文件内部就没有field了，变成空class了（不过反正也没用到，没用到打release包时会被shrink掉，毕竟待会儿会内联）
3. 然后是寻找调用GETSTATIC指令的地方，如果是引用了R文件的属性，那么替换成常量调用，ldc
4. 还有个优化，如果引用的是R文件中的int数组，那么直接将其引用改为application module中R文件的int数组

booster的R文件瘦身原理就分析到这里。

## <span id="head15">6. 官方R瘦身方案</span>

虽然民间已经有很多方面的开源库可以帮助我们瘦身R文件，但如果有官方方案的话，肯定是优先使用官方的方案，更稳。那官方到底有没有方案可以解决这个R文件冗余的问题呢？当然是有的，官方肯定也是发现了这个问题的。所以，在Android Gradle Plugin 4.1.0的时候，官方出手了。

### <span id="head16">6.1 官方方案介绍</span>

下面是AGP 4.1.0的升级日志：

**App size significantly reduced for apps using code shrinking**

Starting with this release, fields from R classes are no longer kept by default, which may result in significant APK size savings for apps that enable code shrinking. This should not result in a behavior change unless you are accessing R classes by reflection, in which case it is necessary to add keep rules for those R classes.

大概意思是，用上AGP 4.1.0之后，apk的体积会有显著减少。不再保留R文件的keep规则，打release包的时候，app中不会再保留R文件，如果代码中反射使用了R文件的内容，那么需要手动keep一下。

把上面的demo改一下试试：

```gradle
// 1. 修改AGP版本为4.1.0
classpath "com.android.tools.build:gradle:4.1.0"

// 2. 修改gradle版本为6.5
distributionUrl=https\://services.gradle.org/distributions/gradle-6.5-bin.zip
```

然后打个release包，看到apk里面，已经没有R文件了，然后再看看MySecondActivity的smali

```smali
.method public onCreate(Landroid/os/Bundle;)V
    .registers 2

    .line 1
    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V

    const p1, 0x7f040002

    .line 2
    invoke-virtual {p0, p1}, Landroid/app/Activity;->setContentView(I)V

    return-void
.end method
```

果然，R文件索引值已经被内联了。再看下R.txt文件，看看有没有内联正确，

```
int color black 0x7f010000
int color white 0x7f010001
int drawable ic_launcher_background 0x7f020001
int drawable ic_launcher_foreground 0x7f020002
int id btn_app_module 0x7f030000
int id btn_app_module1 0x7f030001
int id btn_app_module2 0x7f030002
int id btn_app_module3 0x7f030003
int id btn_first_library 0x7f030004
int id btn_first_library_1 0x7f030005
int id btn_first_library_2 0x7f030006
int id btn_first_library_3 0x7f030007
int id btn_second_library 0x7f030008
int id btn_second_library1 0x7f030009
int id btn_second_library2 0x7f03000a
int id btn_second_library3 0x7f03000b
int layout activity_main 0x7f040000
int layout activity_my 0x7f040001
int layout activity_my_second 0x7f040002
int mipmap ic_launcher 0x7f050000
int mipmap ic_launcher_round 0x7f050001
int string app_name 0x7f060000
int style RInlineDemo 0x7f070000
int xml backup_rules 0x7f080000
int xml data_extraction_rules 0x7f080001
```

看起来是ok的，没啥问题。不得不说，用起来真简单，**不仅把R文件给删除了，还把所有对R文件的引用都改成了常量**。而且是官方的，用起来心里很踏实。

### <span id="head17">6.2 官方R瘦身方案原理</span>

在说这个之前先说一下R8，那么，什么是R8？当你使用 Android Studio 3.4 或 Android Gradle 插件 3.4.0 及更高版本时，R8 是默认编译器，用于将项目的 Java 字节码转换为在 Android 平台上运行的 dex 格式。

它有什么用？简单来说，它主要有4个功能：

- **代码缩减（既摇树优化）**：从应用及其库依赖中检测并安全地移除不使用的类、字段、方法和属性（可以用于规避64k 引用限制问题）。例如，如果你仅使用某个库依赖项的少数几个API，那么缩减功能可以识别应用不使用的库代码并从应用中移除这部分代码；
- **资源缩减**：移除不使用的资源，包括应用库依赖项中不使用的资源。此功能可与代码缩减功能结合使用，这样一来，移除不使用的代码后，也可以安全地移除不再引用的所有资源；
- **混淆**：缩短类和成员的名称，从而减小dex文件的大小；
- **优化**：检查并重写代码，以进一步减小应用的dex文件的大小。例如，R8检测到从未采用过给定if/else语句的 `else{}` 分支，则会移除 `else{}` 分支的代码。

详细内容请移步[R8官方详细介绍](https://developer.android.com/studio/build/shrink-code?hl=zh-cn#groovy)

**R8在对代码做优化时，会将代码中对常量的引用替换成常量值，这样R文件里面的常量都被内联了，R文件也就用不上了，R8在做代码缩减时会将R文件移除掉。**

有个小问题，我的demo中，Android Gradle Plugin 版本为 4.0.1，按道理已经用上了R8，为啥R文件没被优化？[官网](https://developer.android.com/studio/build/shrink-code?hl=zh-cn#groovy)中有一段话：Android Gradle 插件会生成 proguard-android-optimize.txt（其中包含了对大多数 Android 项目都有用的规则，
demo里面的位置是在`./App/build/intermediates/proguard-files/proguard-android-optimize.txt-4.0.1`，在编译的时候生成的），并启用 `@Keep*` 注解。

意思是AGP会自己生成一些默认的keep规则，而 AGP 4.1.0 之前的默认规则里面有一个

```
-keepclassmembers class **.R$* {
    public static <fields>;
}
```

将R文件keep住了。而在 AGP 4.1.0 及之后把这个keep规则移除了。

> 小结：agp4.1的默认keep规则把R class移除了，再配合R8：先把常量引用替换成常量，再shrink代码时把未使用的R class给移除掉。

## <span id="head18">7. 其他</span>

关于R文件，还有一些小东西要和大家聊一下。

### <span id="head19">7.1 nonTransitiveRClass是什么？</span>

随便创建一个 demo (此处AS我用的是 Android Studio Giraffe | 2022.3.1 Patch 2)，你会发现在gradle.properties中会有如下的语句：

```
# Enables namespacing of each library's R class so that its R class includes only the
# resources declared in the library itself and none from the library's dependencies,
# thereby reducing the size of the R class for that library
android.nonTransitiveRClass=true
```

从注释看，设置了nonTransitiveRClass为true之后，可启用每个库的 R 类的命名空间，以便其 R 类仅包含库本身中声明的资源，而不包含库的依赖项中的任何资源，从而缩减相应库的 R 类大小。搜了下，发现 nonTransitiveRClass 是 AGP 4.1.0 引入的([AGP 4.1.0 更新日志](https://developer.android.com/studio/past-releases/past-agp-releases/agp-4-1-0-release-notes?hl=zh-cn))，在 4.1.0 之前也有这个，但是是实验性质的（AGP 3.3 就有了，之前这个属性的名字是 android.namespacedRClass ），直到4.1.0才正式使用。

听起来好像不错，写个demo试试，将上面的demo简单改一下：

1. 将AGP版本改成4.0.1，Gradle版本改为gradle-6.1.1
2. gradle.properties中将`android.nonTransitiveRClass`移除掉，然后新增 `android.namespacedRClass=true` 
3. 新增baselib，它是一个library module，清单文件中的package是`com.xfhy.baselib`，在里面定义了一个BaseLibActivity，一个布局`activity_base_lib`，在baselib中新增字符串资源：`<string name="base_lib_str">hhhhhhh</string>`
4. 然后在mylibrary和mylibrary2中引入baselib，此时在mylibrary中使用baselib中的字符串资源需要这样用：`getString(com.xfhy.baselib.R.string.base_lib_str)`，注意看前面有 `com.xfhy.baselib`

改完打个release包，看下文件结构：

```
|____com
| |____xfhy
| | |____rinlinedemo
| | | |____MainActivity.class
| | |____baselib
| | | |____R$string.class
| | | |____R$layout.class
| | | |____BaseLibActivity.class
| | |____mylibrary
| | | |____MyActivity.class
| | | |____R$layout.class
| | |____mylibrary2
| | | |____R$layout.class
| | | |____MySecondActivity.class
```

对应的文件内容：

```java
// com.xfhy.baselib.R$layout.class
package com.xfhy.baselib;

public final class R$layout {
    public static final int activity_base_lib = 2130968576;
}

// com.xfhy.baselib.R$string.class
package com.xfhy.baselib;

public final class R$string {
    public static final int base_lib_str = 2131099649;
}

// com.xfhy.mylibrary.R$layout.class
package com.xfhy.mylibrary;

public final class R$layout {
    public static final int activity_my = 2130968578;
}

// com.xfhy.mylibrary2.R$layout.class
package com.xfhy.mylibrary2;

public final class R$layout {
    public static final int activity_my_second = 2130968579;
}
```

可以发现，每个module的R文件仅包含自己的那一部分，R文件内容没有被传递。

我现在把 `android.namespacedRClass=true` 移除掉，移除掉这个之后再mylibrary中使用baselib中的字符串资源时可以写成这样 `getString(R.string.base_lib_str)` 了，然后再打个release包：

```java
// com.xfhy.mylibrary.R$layout
package com.xfhy.mylibrary;

public final class R$layout {
    public static final int activity_base_lib = 2130968576;
    public static final int activity_my = 2130968578;
}

// com.xfhy.mylibrary.R$string
package com.xfhy.mylibrary;

public final class R$string {
    public static final int base_lib_str = 2131099649;
}
```

可以发现，现在的R文件具有了传递性，也就是说，mylibrary引入了baselib，那么mylibrary的R文件里面就有baselib中R文件的全部内容。

接下来再将demo改成 AGP 4.1.0，然后引入 `android.nonTransitiveRClass=true` ，打个release包看下是什么效果：R文件已经没了。我再把`android.nonTransitiveRClass=true`移除，发现release包里面还是没有R文件，可以，很强。

其实中间是生成了 `/mylibrary/build/intermediates/compile_r_class_jar/release/R.jar`，打开一看，发现R类里面是包含了baselib的R文件的全部内容的，但是后面R8处理之后，这个东西用不上，就被优化掉了，最终的包里面没有这个R类。

意味着在未加上 `android.nonTransitiveRClass=true` 的情况下，R文件还是具有传递性，里面的内容除了有自己库里面的R内容以外还有依赖库的R文件内容。虽然最终release包里面没有这些东西了，表面上看起来这个配置可有可无，实际上是有很大用处的。这个配置可以提升构建速度，因为上层的module的R文件内容会包含下层的R文件内容，下层的R文件内容变了，上层的R文件内容也需要跟着变，这样会很影响多module的构建效率。

小结一下，**`android.nonTransitiveRClass=true` 配置了之后，可以防止R类内容有传递性，这样不仅可以缩小包体积（AGP 4.1.0之前），还能提升构建速度**。

> 这个配置在 AGP 4.1.0 之前毕竟是属于实验性的，有没有坑，谁也说不准。

### <span id="head20">7.2 AGP8.0，application module中R文件中的属性不再是常量</span>

打开[AGP 8.0的更新日志](https://developer.android.com/build/releases/past-releases/agp-8-0-0-release-notes)，我发现AGP8.0中所有平时使用的R文件中的属性不再是常量了。在这之前仅是module/aar中的R文件属性非常量（static），application module中R文件属性是常量（static final）。

AGP 8.0 generates R classes with non-final fields by default.

将上面的demo改成AGP8.0，然后打release包，发现里面没有任何R文件（那是因为aapt2最终生成的R文件还是常量的），已经把常量内联，R文件被shrink掉了。但是AGP 8.0以上为啥要把平时使用的所有R文件中的属性变成非常量呢？原因我没想到，有知道的大佬望赐教。

### <span id="head21">7.3 延伸：R文件field上限</span>

还有个小问题，偶然看到一篇文章[记录一次 AGP 调研过程中的思考，我从一个事故搞出了一个故事！](https://juejin.cn/post/6891637731873882126?searchId=20231011152832D5E0334E484C887200F5)，作者想到一个问题：当单一类型资源特别多时，会发生什么事？思路清奇，写得很有深度，值得学习。

作者想表达的大概意思是：单一资源类型如果数量特别多，比如字符串，会导致R$string.class中的field数量特别多，超过了class允许的field数量上限（2^16-1=65535），导致编译失败，这个失败的时间非常早，处于aapt2编译时期。R8、multidex啥的都还没开始，就编译报错了。

这里提一下，class的filed为什么会有数量上限，因为class文件格式（Java字节码，JVM有严格要求）中规定field数量是用2个字节来存的，所以上限是2^16-1=65535。对字节码感兴趣的同学可移步[Java字节码解读](https://blog.csdn.net/xfhy_/article/details/107776716)进行详细了解。

我写了个demo，AGP是8.0，将然后用脚本写了65536个字符串，放到app module的strings.xml中，编译，发现报错了：

```
Caused by: com.android.builder.internal.aapt.v2.Aapt2Exception: Android resource linking failed
error: can't assign resource ID to resource com.xfhy.agp8demo:string/app_name9861 because resource type ID has exceeded the maximum number of resource entries (65536).
error: failed assigning IDs.

	at com.android.builder.internal.aapt.v2.Aapt2Exception$Companion.create(Aapt2Exception.kt:45)
	at com.android.builder.internal.aapt.v2.Aapt2Exception$Companion.create$default(Aapt2Exception.kt:33)
	at com.android.builder.internal.aapt.v2.Aapt2DaemonImpl.doLink(Aapt2DaemonImpl.kt:188)
	at com.android.builder.internal.aapt.v2.Aapt2Daemon.link(Aapt2Daemon.kt:124)
    ...
```

然后我又把这65536个字符串放到library module的strings.xml中，编译，还是报错了。我再把这65536个字符串分开，放到2个不同library module中，编译，还是报错了。看来，确实是存在这个问题的。只是现在一般的app没这么多单一资源类型，所以问题还没暴露出来。怎么解决这个问题？

1. 还没遇上，遇到了再说
2. 简单实现是把资源放assets里面，自己实现映射关系和读取

## <span id="head22">8. 小结</span>

简单小结一下本文：

1. 因为要对R文件进行瘦身，所以本文先是对R文件进行了详细介绍：R文件生成内容、生成规则、生产者、release产物等。
2. 然后谈到了R文件为什么可以瘦身：常量内联，无用的R文件shrink掉
3. R文件瘦身实战：利用ASM和自定义Gradle Plugin的方式实现demo
4. 介绍开源库booster及其R文件瘦身原理：与上述demo方案相似
5. 介绍官方瘦身方案及其原理：AGP 4.1.0及以上，R8配合keep规则改变
6. 关于R文件的其他内容：nonTransitiveRClass、AGP 8.0 no final、R文件常量上线

由于种种原因未升级AGP版本的项目可以选择使用booster、bytex进行R文件瘦身优化，如果可以升级AGP版本，则可以选择将AGP升级到4.1.0及以上。对R文件瘦身的效果的话，不同的项目可能不太一样，一般来讲module越多的话，可能瘦身效果会更明显（瘦好几M都是可能的）。


- Android性能优化 - 包体积杀手之R文件内联原理与实现 https://juejin.cn/post/7146807432755281927
- 网易云 Android agp 对 R 文件内联支持 https://zhuanlan.zhihu.com/p/391514305
- booster资源索引内联  https://booster.johnsonlee.io/zh/guide/shrinking/res-index-inlining.html#%E8%B5%84%E6%BA%90%E7%B4%A2%E5%BC%95%E7%9A%84%E9%97%AE%E9%A2%98
- 关于R的一切  https://medium.com/@morefreefg/%E5%85%B3%E4%BA%8E-r-%E7%9A%84%E4%B8%80%E5%88%87-355f5049bc2c
- 别搞错了，nonTransitiveRClass 不能解决资源冲突！ https://juejin.cn/post/7176111455236784185
- 记录一次 AGP 调研过程中的思考，我从一个事故搞出了一个故事！ https://juejin.cn/post/6891637731873882126?searchId=20231011152832D5E0334E484C887200F5
- 缩减、混淆处理和优化应用  https://developer.android.com/studio/build/shrink-code?hl=zh-cn
- Android 性能优化之 R 文件优化详解 https://zhuanlan.zhihu.com/p/545929235
- AGP 4.1.0 https://developer.android.com/studio/past-releases/past-agp-releases/agp-4-1-0-release-notes?hl=zh-cn
- aapt2 https://developer.android.com/studio/command-line/aapt2?hl=zh-cn