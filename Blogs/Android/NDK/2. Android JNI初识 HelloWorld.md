
> 以前学过一点JNI,很久没用,然后又忘了,复习一下.

### 一.引入NDK

1. 新建项目,勾选`include C++ support`,一路next,finish.
2. 完成.

完成上述步骤就已经配置好了NDK,我们来看看比一般的项目多了哪些东西.

![](http://olg7c0d2n.bkt.clouddn.com/18-9-20/55579079.jpg)

#### 1. cpp文件夹

很明显,这里面是存放cpp源文件的.

```cpp
#include <jni.h>
#include <string>

//这里的jstring表示的是返回值,对应于Java中的String
extern "C" JNIEXPORT jstring

JNICALL
Java_com_xfhy_ndkdemo_MainActivity_stringFromJNI(
        JNIEnv *env,
        jobject /* this */) {
    std::string hello = "Hello from C++";
    return env->NewStringUTF(hello.c_str());
}

```

- 必须引入jni.h头文件,因为下面的JNIEnv,jstring和jobject都是里面的.(jni.h文件定义了JNI（Java Native Interface）所支持的类型与接口。通过预编译命令可以支持C和C++。jni.h文件还依赖jni_md.h文件，jni_md.h文件定义了机器相关的jbyte, jint和jlong对应的本地类型。)
- JNIEXPORT和JNICALL这两个宏(被定义在jni.h)确保这个函数在本地库外可见,并且C编译器会进行正确的调用转换.
- `extern "C"`的主要作用是为了能够正确实现C++代码调用其他C语言代码.
- 这里的jstring表示的是返回值,对应于Java中的String
- 注意`Java_com_xfhy_ndkdemo_MainActivity_stringFromJNI`,这里表示的是Java+类的全名+方法名,必须按照这个格式声明方法.(这个方法对应的java代码如下,平时我们写了一个native方法,可以直接按alt+enter生成cpp这边的方法定义,真是太方便了,哈哈)
> ```
> public native String stringFromC();
> ```


**Java和Jni的类型对照表**

![](http://olg7c0d2n.bkt.clouddn.com/18-9-20/5353689.jpg)

**引用类型对照表**

![](http://olg7c0d2n.bkt.clouddn.com/18-9-20/72728007.jpg)

#### 2. CMakeLists.txt

多了个txt文件,看看里面都有啥东西

```

# cmake版本
cmake_minimum_required(VERSION 3.4.1)

add_library( # Sets the name of the library. lib的名称
             native-lib

             # Sets the library as a shared library.
             SHARED

             # Provides a relative path to your source file(s).  源文件
             src/main/cpp/native-lib.cpp )

find_library( # Sets the name of the path variable.
              log-lib

              # Specifies the name of the NDK library that
              # you want CMake to locate.
              log )

target_link_libraries( # Specifies the target library.
                       native-lib

                       # Links the target library to the log library
                       # included in the NDK.
                       ${log-lib} )

```
1. `cmake_minimum_required` cmake版本
1. `add_library` 指定要编译的库，并将所有的 .c 或 .cpp 文件包含指定。
2. `find_library`  查找库所在目录
4. `target_link_libraries` 将库与其他库相关联

#### 3. build.gradle

```gradle
android {
    defaultConfig {
        externalNativeBuild {
            cmake {
                cppFlags ""
            }
        }
    }
    externalNativeBuild {
        cmake {
            path "CMakeLists.txt"
        }
    }
}

```
使用cmake配置gradle关联.

#### 4. java代码

```
static {
    System.loadLibrary("native-lib");
}

public native String stringFromJNI();
```

1. 在应用启动的时候加载`native-lib`库
2. 声明native()方法.
