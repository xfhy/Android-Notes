
## 1. 前言

准备写一个新的系列,专注于Gradle,计划会有如下几篇文章

1. Groovy 基础
2. Gradle 执行顺序和task
3. Gradle 差异化包
4. Gradle 插件

## 2. 什么是Groovy

在学习Gradle之前,需要简单普及一下Groovy的语言基础.Groovy是一门jvm语言,特定领域的语言,里面的水特别深.我们不需要全部记住和掌握,只需要记得一些常用的,不清楚的立刻去查API 文档.

[Groovy官方文档](http://docs.groovy-lang.org/latest/html/groovy-jdk/index-all.html)

因为目前Android的主流构建工具是用的Gradle,而Gradle使用时就需要用到Groovy,还有Gradle DSL和Android DSL.Gradle里面其实东西比较多.随便说几个,比如渠道包(差异包),AOP,插桩,热修复,插件化等等,都需要用到Gradle.所以我们Android开发人员对于Gradle的需求非常大.有必要搞清楚.

## 3. 简单使用Groovy

打开Android Studio,随便新建一个Android项目.点击顶部Tools->Groovy Console即可,这时AS会出来一个窗口,专门拿来运行那种临时的Groovy代码的.因为是在本地执行,所以执行速度会非常快.写好代码后点击窗口左上角的三角按钮即可运行代码.

## 4. 语法

droovy的语法比java简洁很多

### 4.1 简单示范

```groovy
int r = 1
def a = 1
a = 'da'
println(a)

def b = "dasa"
def c = 56.4

//调用下面的test方法
def d = test()
println(d)
def test() {
    println("test method")
    return 1
}

//输出
da
test method
1
```

- groovy中不用写分号
- 变量类型可以省略
- 方法返回类型可以省略,上面test方法中的return也可以省略
- 变量类型比较弱,可以推断出来
- 字符串可以用双引号或者单引号包起来

### 4.2 String

```
def name = "zhangsan"
def b = 2

def test(a, b) {
    println("a=${a} b=${b}")
}

test(name, b)

//输出
a=zhangsan b=2
```

- String中如果需要使用到变量,则需要使用$和{}关键字,并且需要使用双引号的时候才能这样用
- 可以看到方法的入参那里也可以省略类型
- Java中String有的方法,它都有

### 4.3 闭包

闭包感觉有点像kotlin的高阶函数(不知道对不对),可以将一个闭包作为参数传入方法,也可以赋值给变量.然后调用call方法即可调用闭包.kotlin是调用invoke.

```
//定义闭包      闭包的参数
def closure = { int a, String b ->
    println("a=${a} b=${b}")
    //闭包返回值
    return a + b
}
//调用闭包   定义result变量不用写def也可以,666
result = closure.call(1, "name")
println(result)

//输出
a=1 b=name
1name
```

- 闭包使用call方法调起,需要传入参数
- 闭包定义时的参数类型是可以省略的

### 4.4 List

比Java中的更加强大.当遇到不会的方法的时候去查API文档,比如下面的示例代码中的each闭包,你肯定不知道闭包的参数是什么,这时我们打开,List的[文档地址](http://docs.groovy-lang.org/latest/html/groovy-jdk/java/util/List.html),找到each方法,知道了原来是遍历每个元素,参数是每个元素.

```
//list 可以存放不同的数据类型
def list = [1, "test", true, 2.3]
list.each { item ->
    println(item)
}

list.each {
  println(it)
}

//输出
1
test
true
2.3
```

- 闭包的参数只有一个时是可以省略的,在里面使用时用it代替.和kotlin很像.
- list支持`list[1]`这种形式的访问


### 4.5 Map

```
//空的map
def map1 = [:]
//
def map = ["id":1, "name":"xfhy"]

map['id'] = 2
println(map['id'])

map.id = "idStr"
println(map.id)

map.each { key, value ->
    println("key=${key} value=${value}")
}

map.each { entry ->
    println(entry)
}

//输出
2
idStr
key=id value=idStr
key=name value=xfhy
id=idStr
name=xfhy
```

- map支持`map['id']`访问和赋值
- 也支持map.id访问和赋值
- each遍历支持2种闭包,使用方式如上,记不清楚没关系,使用的时候去查API就行

### 4.6 IO

groovy的文件操作也是非常非常好使

```
def file = new File("D:/test.txt")
file.eachLine { line, lineNo ->
    println("第${lineNo}行 $line")
}

//输出
第1行 name
第2行 age
第3行 book
```
- 非常好用,简单直接地读取文件内容
- 其他好用的API,请参阅[这里](http://docs.groovy-lang.org/latest/html/groovy-jdk/java/io/File.html)

### 4.7 类

```
class Book {
    String bookName
    double price
}

def book = new Book()
book.with {
    bookName = '字典'
    price = 24.5
}
println(book.bookName)
println(book.price)
book=null
println(book?.price)


//输出
字典
24.5
null
```

- 使用with操作符,可以对book对象内部属性进行操作,调用方法等
- 使用?可以避免空指针,免得判空.就像kotlin一样,很棒.

## 5. 总结

我个人认为,基础掌握差不多这么多就行了,剩下的遇到了再查官方文档.
