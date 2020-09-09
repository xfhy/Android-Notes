
#### 1. String是如何实现的?
里面是char数组实现的,最新的版本换成了byte数组(ASCII占1位,中文的话占2位).

#### 2. 字符串常量池

Java堆内存中一个特殊的存储区域,当创建一个String对象时,假如此字符串值已经存在于常量池中,则不会创建一个新的对象,而是引用已经存在的对象.JDK 1.6及之前字符串常量池是存放在方法区的,JDK 1.7才开始放在堆中.

#### 3. 为什么设计成不可变的? final修饰

1. 提高String Pool的效率和安全性.
2. 多线程安全

#### 4. String,StringBuilder,StringBuffer的区别

> StringBuilder和StringBuffer的核心代码逻辑都是一样的,都在父类AbstractStringBuilder里面,父类维护着一个char类型的数组,需要操作字符串数据的时候其实就是在操作这个数组里面的数据.String里面也维护着一个char类型的数组,只不过是final修饰的,任何change操作都会新创建String,而不是在原来的基础上修改.

1. String是不可变的字符序列,StringBuilder和StringBuffer是可变的字符序列.
2. StringBuffer是线程安全的,StringBuilder是线程不安全的.
3. 速度上: StringBuilder > StringBuffer > String

#### 5. String中的intern方法是什么含义?

intern方法可以用来声明字符串,它会从字符串常量池中查询当前字符串是否存在,存在则直接返回当前字符串;不存在就会将当前字符串放入常量池中,再返回.

#### 6. 编译器对String做了哪些优化?

使用"+"连接常量字符串与常量字符串的时候,会将字符串全部加在一起然后存放. 如果用"+"号连接字符串与变量的时候,则是创建StringBuilder或StringBuffer来拼接.


#### 7. "+"连接符的实现原理

先来一段简单的代码:

```java
public class Solution {

    public static void main(String[] args) {
        int i = 10;
        String s = "dasdas";
        System.out.println(s + i);
    }

}
```

javap看一下它的字节码:

```
public static void main(java.lang.String[]);
    Code:
       0: bipush        10
       2: istore_1
       3: ldc           #2                  // String dasdas
       5: astore_2
       6: getstatic     #3                  // Field java/lang/System.out:Ljava/io/PrintStream;
       9: new           #4                  // class java/lang/StringBuilder
      12: dup
      13: invokespecial #5                  // Method java/lang/StringBuilder."<init>":()V   调用StringBuilder的构造方法
      16: aload_2
      17: invokevirtual #6                  // Method java/lang/StringBuilder.append:(Ljava/lang/String;)Ljava/lang/StringBuilder;   调用append方法
      20: iload_1
      21: invokevirtual #7                  // Method java/lang/StringBuilder.append:(I)Ljava/lang/StringBuilder;    //调用append方法
      24: invokevirtual #8                  // Method java/lang/StringBuilder.toString:()Ljava/lang/String;   //调用toString方法
      27: invokevirtual #9                  // Method java/io/PrintStream.println:(Ljava/lang/String;)V 调用println方法
      30: return

```

所以当字符串与其他变量相加的时候,其实会创建StringBuilder(或StringBuffer)来完成.

咱们来看另一段代码:

```java

public class Solution {

    private static final String TAG = "tag";

    public static void main(String[] args) {
        String s = "dasdas" + TAG;
        String b = "I like " + "java";
        String c = s + b;
    }

}

//反编译后
public static void main(java.lang.String[]);
    Code:
       0: ldc           #3                  // String dasdastag   自动就给我拼接好了
       2: astore_1
       3: ldc           #4                  // String I like java  自动拼接好了
       5: astore_2
       6: new           #5                  // class java/lang/StringBuilder  使用StringBuilder拼接
       9: dup
      10: invokespecial #6                  // Method java/lang/StringBuilder."<init>":()V
      13: aload_1
      14: invokevirtual #7                  // Method java/lang/StringBuilder.append:(Ljava/lang/String;)Ljava/lang/StringBuilder;
      17: aload_2
      18: invokevirtual #7                  // Method java/lang/StringBuilder.append:(Ljava/lang/String;)Ljava/lang/StringBuilder;
      21: invokevirtual #8                  // Method java/lang/StringBuilder.toString:()Ljava/lang/String;
      24: astore_3
      25: return

```

可以看到,编译器在连接字符串时,需要连接的字符串都是常量,就会在编译期直接将其相加;如果需要连接的是变量,则会使用StringBuilder(或StringBuffer)进行拼接.

#### 8. String str = new String("abc")创建了多少个对象？

代码的执行过程和类的加载过程不同.在类的加载过程中,确实在运行时常量池中创建了一个"abc"对象,而在代码执行过程中只创建了一个String对象.

这里String str = new String("abc")涉及的是2个对象. 
