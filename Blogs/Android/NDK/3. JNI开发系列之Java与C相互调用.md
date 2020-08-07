**Java和Jni的类型对照表**

![](http://olg7c0d2n.bkt.clouddn.com/18-9-20/5353689.jpg)

**引用类型对照表**

![](http://olg7c0d2n.bkt.clouddn.com/18-9-20/72728007.jpg)

### 一.Java调用C函数

#### 1.字符串拼接

```java
public native String concatString(String a, String b);
```

```cpp
/**
 * 字符串拼接
 */
extern "C"
JNIEXPORT jstring JNICALL
Java_com_xfhy_ndkdemo_MainActivity_concatString(JNIEnv *env, jobject instance, jstring a_, jstring b_) {
    //jstring 转 char*
    const char *a = env->GetStringUTFChars(a_, 0);
    const char *b = env->GetStringUTFChars(b_, 0);

    //释放拷贝的内存
    /*
     * 第一个参数指定一个jstring变量，即是要释放的本地字符串的来源。
        第二个参数就是要释放的本地字符串
     * */
    env->ReleaseStringUTFChars(a_, a);
    env->ReleaseStringUTFChars(b_, b);
    //动态申请一个地址空间
    char *c = (char *) malloc(strlen(a) + strlen(b));
    strcpy(c, a);
    strcat(c, b);

    //将char* 转jstring
    return env->NewStringUTF(c);
}
```

#### 2.比较字符串

```java
public native int compareString(String a, String b);
```

```cpp
/**
 * 比较字符串
 */
extern "C"
JNIEXPORT jint JNICALL
Java_com_xfhy_ndkdemo_MainActivity_compareString(JNIEnv *env, jobject instance, jstring a_, jstring b_) {
    const char *a = env->GetStringUTFChars(a_, 0);
    const char *b = env->GetStringUTFChars(b_, 0);


    env->ReleaseStringUTFChars(a_, a);
    env->ReleaseStringUTFChars(b_, b);

    return strcmp(a, b);
}
```

#### 3. 数组求和

```java
public native int sumArray(int[] array);
```

```cpp
/**
 * 数组求和
 */
extern "C"
JNIEXPORT jint JNICALL
Java_com_xfhy_ndkdemo_MainActivity_sumArray(JNIEnv *env, jobject instance, jintArray array_) {
    //从java数组获取数组指针
    jint *array = env->GetIntArrayElements(array_, NULL);

    int sum = 0;
    int len = env->GetArrayLength(array_);
    for (int i = 0; i < len; i++) {
        sum += array[i];
    }

    env->ReleaseIntArrayElements(array_, array, 0);

    return sum;
}
```
### 二.C调用Java方法

```java
public class CallJava {
    static {
        System.loadLibrary("native-lib");
    }

    private static final String TAG = "CallJava";

    public native void callVoidMethod();

    public void hello() {
        Log.e(TAG, "Java的hello方法");
    }
}
```

```cpp
/**
 * 调用java的方法
 */
extern "C"
JNIEXPORT void JNICALL
Java_com_xfhy_ndkdemo_CallJava_callVoidMethod(JNIEnv *env, jobject instance) {
    //通过反射调用java中的方法
    //找class 使用FindClass方法，参数就是要调用的函数的类的完全限定名，但是需要把点换成/
    jclass clazz = env->FindClass("com/xfhy/ndkdemo/CallJava");
    //获取对应的函数: 参数1:类class,参数2:方法名,参数3:方法签名
    //ps:方法签名的获取:进入build->intermediates->classes->debug目录下,使用javap -s 类的完全限定名,就能获得函数签名
    jmethodID method = env->GetMethodID(clazz, "hello", "()V");
    //实例化该class对应的实例  使用AllocObject方法，使用clazz创建该class的实例。
    jobject object = env->AllocObject(clazz);
    //调用方法
    env->CallVoidMethod(object, method);
}
```

### 三.在C中打印日志

在CMakeLists.txt中加入
```
find_library(
             log-lib


              log )

target_link_libraries( 
                       native-lib

                       ${log-lib} )
```

然后在cpp文件中加入
```cpp
#include "android/log.h"

#define LOG_TAG "JNI_TEST"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
```

使用方式:
```cpp
int a = 10;
LOGE("xfhy   我是C代码中的日志    a=%d", a);

LOGE("我是xfhy");
```