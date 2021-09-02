[TOC]


### 前置知识

- 注解(元数据): 从JDK5开始,Java提供的为类、方法、字段、参数等Java结构提供额外信息的机制
- 反射: 运行时动态地获取信息以及调用对象方法的功能被称为Java语言的反射机制。任何一个类都能知道它的属性和方法，任何一个对象都能调用它的属性和方法。

因为之前已经详细解读过[注解](https://github.com/xfhy/Android-Notes/blob/master/Blogs/Java/%E5%9F%BA%E7%A1%80/%E6%B3%A8%E8%A7%A3.md)、[反射](https://github.com/xfhy/Android-Notes/blob/master/Blogs/Java/%E5%9F%BA%E7%A1%80/%E5%8F%8D%E5%B0%84.md)、[反射性能开销原理及优化.](https://github.com/xfhy/Android-Notes/blob/master/Blogs/Java/%E5%9F%BA%E7%A1%80/%E5%8F%8D%E5%B0%84%E6%80%A7%E8%83%BD%E5%BC%80%E9%94%80%E5%8E%9F%E7%90%86%E5%8F%8A%E4%BC%98%E5%8C%96.md)，这里就不再过多描述。

### 什么是APT

APT即Annotation Processing Tool，它是javac的一个工具，常被称作注解处理器。既然是javac的一个工具，那想都不用想，肯定是发生在编译期的处理。它被用来在编译期扫描和处理注解，获取被注解对象的一些相关信息，拿到这些信息之后根据业务需求自动生成一些代码，省去模板代码的手动编写，提高开发效率。而且这些代码是编译期生成的，所以相比反射在运行期处理注解性能要高一些。

APT应用广泛，常见的ButterKnife、EventBus、Dagger2和ARouter等都用到了APT技术。

### 编译期注解运行原理

1. 将源文件解析成抽象语法树
2. 调用已注册的注解处理器
3. 生成字节码

如果第2步调用注解处理器过程中生成了新的源文件，那么编译器将重复第1、2步骤，解析并处理新生成的源文件。

### APT工程基础结构

### 自动生成代码

#### 注解处理器声明
#### 注解处理器注册
#### 注解处理器生成类文件

### 使用生成的代码完成业务需求

### 实战
