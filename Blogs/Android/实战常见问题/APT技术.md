[TOC]


### 前置知识

- 注解(元数据): 从JDK5开始,Java提供的为类、方法、字段、参数等Java结构提供额外信息的机制
- 反射: 运行时动态地获取信息以及调用对象方法的功能被称为Java语言的反射机制。任何一个类都能知道它的属性和方法，任何一个对象都能调用它的属性和方法。

因为之前已经详细解读过[注解](https://github.com/xfhy/Android-Notes/blob/master/Blogs/Java/%E5%9F%BA%E7%A1%80/%E6%B3%A8%E8%A7%A3.md)、[反射](https://github.com/xfhy/Android-Notes/blob/master/Blogs/Java/%E5%9F%BA%E7%A1%80/%E5%8F%8D%E5%B0%84.md)、[反射性能开销原理及优化](https://github.com/xfhy/Android-Notes/blob/master/Blogs/Java/%E5%9F%BA%E7%A1%80/%E5%8F%8D%E5%B0%84%E6%80%A7%E8%83%BD%E5%BC%80%E9%94%80%E5%8E%9F%E7%90%86%E5%8F%8A%E4%BC%98%E5%8C%96.md)，这里就不再过多描述。

### 什么是APT

APT即Annotation Processing Tool，它是javac的一个工具，常被称作注解处理器。既然是javac的一个工具，那想都不用想，肯定是发生在编译期的处理。它被用来在编译期扫描和处理注解，获取被注解对象的一些相关信息，拿到这些信息之后根据业务需求自动生成一些代码，省去模板代码的手动编写，提高开发效率。而且这些代码是编译期生成的，所以相比反射在运行期处理注解性能要高一些。

APT应用广泛，常见的ButterKnife、EventBus、Dagger2和ARouter等都用到了APT技术。

### 编译期注解运行原理

1. 将源文件解析成抽象语法树
2. 调用已注册的注解处理器
3. 生成字节码

如果第2步调用注解处理器过程中生成了新的源文件，那么编译器将重复第1、2步骤，解析并处理新生成的源文件。

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/%E6%B3%A8%E8%A7%A3%E8%BF%90%E8%A1%8C%E5%8E%9F%E7%90%86.png)

### APT工程一般结构

- lib-annotation：Java-Library，用于存放注解
- lib-processor：Java-Library，用于存放注解处理器，继承自AbstractProcessor的类都放这里
- lib：Android-Library，封装好生成出来的类的调用方式提供给上层，比如上面lib-processor将XXBinging类生成出来了，那么在这里就需要去调用XXBinging使其发挥作用

### 自动生成代码

如何自动生成代码？其实就是写一个类，让它继承自AbstractProcessor。这是根本，然后我们需要让编译器知道这个类（注解处理器）的存在，那么就需要将其声明，然后编译器才知道。编译的时候会走注解处理器过，我们需要根据业务自己写生成相应Java代码的逻辑。

#### 注解处理器声明

在lib-processor中建一个类，继承AbstractProcessor。

```kotlin
class BindingProcessor : AbstractProcessor() {

    var filer: Filer? = null

    //做一些初始化的工作
    @Synchronized
    override fun init(processingEnvironment: ProcessingEnvironment) {
        super.init(processingEnvironment)
        filer = processingEnvironment.filer
    }

    /**
     * 生成Java类的逻辑就在这里写
     * @param annotations              支持处理的注解集合
     * @param roundEnv 通过该对象查找指定注解下的节点信息
     * @return true: 表示注解已处理，后续注解处理器无需再处理它们；false: 表示注解未处理，可能要求后续注解处理器处理
     */
    override fun process(annotations: MutableSet<out TypeElement>?, roundEnv: RoundEnvironment): Boolean {
        return false
    }

    //当前注解处理器支持的注解集合，如果支持，就会调用process方法
    override fun getSupportedAnnotationTypes(): MutableSet<String> {
        return Collections.singleton(BindView::class.java.canonicalName)
    }

}
```

**TypeElement**

这里需要简单介绍一下TypeElement：

Java代码中的每一个部分都对应了一个特定类型的Element，例如包、类、字段、方法等。

```java
package com.xfhy;         // PackageElement：包元素

public class Main<T> {     // TypeElement：类元素; 其中 <T> 属于 TypeParameterElement 泛型元素

    private int x;         // VariableElement：变量、枚举、方法参数元素

    public Main() {        // ExecuteableElement：构造函数、方法元素
    }
}
```

Element 是一个接口

```java
public interface Element extends javax.lang.model.AnnotatedConstruct {
    // 获取元素的类型，实际的对象类型
    TypeMirror asType();
    // 获取Element的类型，判断是哪种Element
    ElementKind getKind();
    // 获取修饰符，如public static final等关键字
    Set<Modifier> getModifiers();
    // 获取类名
    Name getSimpleName();
    // 返回包含该节点的父节点，与getEnclosedElements()方法相反
    Element getEnclosingElement();
    // 返回该节点下直接包含的子节点，例如包节点下包含的类节点
    List<? extends Element> getEnclosedElements();

    @Override
    boolean equals(Object obj);
  
    @Override
    int hashCode();
  
    @Override
    List<? extends AnnotationMirror> getAnnotationMirrors();
  
    //获取注解
    @Override
    <A extends Annotation> A getAnnotation(Class<A> annotationType);
  
    <R, P> R accept(ElementVisitor<R, P> v, P p);
}
```

我们可以通过Element获取很多信息，如上面注释所示。但是，有时Element代表多种元素，例如 TypeElement 代表类或接口，此时我们可以通过 element.getKind() 来区分：

```java
Set<? extends Element> elements = roundEnvironment.getElementsAnnotatedWith(AptAnnotation.class);
for (Element element : elements) {
    if (element.getKind() == ElementKind.CLASS) {
        // 如果元素是类

    } else if (element.getKind() == ElementKind.INTERFACE) {
        // 如果元素是接口

    }
}
```

ElementKind 是一个枚举类，它的取值有很多，如下：

```java
PACKAGE	//表示包
ENUM //表示枚举
CLASS //表示类
ANNOTATION_TYPE	//表示注解
INTERFACE //表示接口
ENUM_CONSTANT //表示枚举常量
FIELD //表示字段
PARAMETER //表示参数
LOCAL_VARIABLE //表示本地变量
EXCEPTION_PARAMETER //表示异常参数
METHOD //表示方法
CONSTRUCTOR //表示构造函数
OTHER //表示其他
```

#### 注解处理器注册
#### 注解处理器生成类文件

### 使用生成的代码完成业务需求

### 实战
