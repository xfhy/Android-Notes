
> 本文基于 `leakcanary-android:2.5`

思维导图

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/LeakCanary%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90%E6%80%9D%E7%BB%B4%E5%AF%BC%E5%9B%BE.png)

## 1. 背景

Android开发中,内存泄露时常有发生在,有可能是你自己写的,也有可能是三方库里面的.程序中已动态分配的堆内存由于某种特殊原因程序未释放或无法释放,造成系统内存的浪费,导致程序运行速度减慢甚至程序崩溃等严重后果.本来Android内存就吃紧,还内存泄露的话,后果不堪设想.所以我们要尽量避免内存泄露,一方面我们要学习哪些常见场景下会发生内存泄露,一方面我们引入LeakCanary帮我们自动检测有内存泄露的地方.

LeakCanary是Square公司(对,又是这个公司,OkHttp和Retrofit等都是这家公司开源的)开源的一个库,通过它我们可以在App运行的过程中检测内存泄露,它把对象内存泄露的引用链也给开发人员分析出来了,我们去修复这个内存泄露非常方面.

> ps: LeakCanary直译过来是内存泄露的金丝雀,关于这个名字其实有一个小故事在里面.金丝雀,美丽的鸟儿.她的歌声不仅动听,还曾挽救过无数矿工的生命.17世纪,英国矿井工人发现,金丝雀对瓦斯这种气体十分敏感.空气中哪怕有极其微量的瓦斯，金丝雀也会停止歌唱;而当瓦斯含量超过一定限度时,虽然鲁钝的人类毫无察觉,金丝雀却早已毒发身亡.当时在采矿设备相对简陋的条件下，工人们每次下井都会带上一只金丝雀作为"瓦斯检测指标",以便在危险状况下紧急撤离. 同样的,LeakCanary这只"金丝雀"能非常敏感地帮我们发现内存泄露,从而避免OOM的风险.

## 2. 初始化

在引入LeakCanary的时候,只需要在build.gradle中加入下面这行配置即可:

```gradle
// debugImplementation because LeakCanary should only run in debug builds.
debugImplementation 'com.squareup.leakcanary:leakcanary-android:2.5'
```

**That’s it, there is no code change needed!** 我们不需要改动任何的代码,就这样,LeakCanary就已经引入进来了. 那我有疑问了?我们一般引入一个库都是在Application的onCreate中初始化,它不需要在代码中初始化,它是如何起作用的呢?

我只想到一种方案可以实现这个,就是它在内部定义了一个ContentProvider,然后在ContentProvider的里面进行的初始化.

咱验证一下: 引入LeakCanary之后,运行一下项目,然后在debug的apk里面查看AndroidManifest文件,搜一下provider定义.果然,我找到了:

```xml
<provider
    android:name="leakcanary.internal.AppWatcherInstaller$MainProcess"
    android:enabled="@ref/0x7f040007"
    android:exported="false"
    android:authorities="com.xfhy.allinone.leakcanary-installer" />
<!--这里的@ref/0x7f040007对应的是@bool/leak_canary_watcher_auto_install-->
```

```kotlin
class AppWatcherInstaller : ContentProvider() {
    override fun onCreate(): Boolean {
        val application = context!!.applicationContext as Application
        AppWatcher.manualInstall(application)
        return true
    }
}
```

哈哈,果然是在ContentProvider里面进行的初始化.App在启动时会自动初始化ContentProvider,也就自动调用了AppWatcher.manualInstall()进行了初始化.一开始的时候,我觉得这样挺好的,挺优雅,后来发现好多三方库都这么干了.每个库一个ContentProvider进行初始化,有点冗余的感觉.后来Jetpack推出了App Startup,解决了这个问题,它就是基于这个原理进行的封装.

需要注意的是ContentProvider的onCreate执行时机比Application的onCreate执行时机还早.如果你想在其他时机进行初始化优化启动时间,也是可以的.只需要在app里重写`@bool/leak_canary_watcher_auto_install`的值为false即可.然后手动在合适的地方调用`AppWatcher.manualInstall(application)`.但是LeakCanary本来就是在debug的时候用的,所以感觉优化启动时间不是那么必要.

## 3. 监听泄露的时机

LeakCanary自动检测以下对象的泄露:

- destroyed **Activity** instances
- destroyed **Fragment** instances
- destroyed fragment **View** instances
- cleared **ViewModel** instances

可以看到,检测的都是些Android开发中容易被泄露的东西.那么它是如何检测的,下面我们来分析一下

### 3.1 Activity

通过Application#registerActivityLifecycleCallbacks()注册Activity生命周期监听,然后在onActivityDestroyed()中进行`objectWatcher.watch(activity,....)`进行检测对象是否泄露.检测对象是否泄露这块后面单独分析.  

### 3.2 Fragment、Fragment View

同样的,检测这2个也是需要监听周期,不过这次监听的是Fragment的生命周期,利用`fragmentManager.registerFragmentLifecycleCallbacks`可以实现.Fragment是在onFragmentDestroy()中检测Fragment对象是否泄露,Fragment View在onFragmentViewDestroyed()里面检测Fragment View对象是否泄露.

但是,拿到这个fragmentManager的过程有点曲折.

- Android O以上,通过activity#getFragmentManager()获得. (AndroidOFragmentDestroyWatcher)
- AndroidX中,通过activity#getSupportFragmentManager()获得.  (AndroidXFragmentDestroyWatcher)
- support包中,通过activity#getSupportFragmentManager()获得.  (AndroidSupportFragmentDestroyWatcher)

可以看到,不同的场景下,取FragmentManager的方式是不同的.取FragmentManager的实现过程、注册Fragment生命周期、在onFragmentDestroyed和onFragmentViewDestroyed中检测对象是否有泄漏这一套逻辑,在不同的环境下,实现不同.所以把它们封装进不同的策略(对应着上面3种策略)中,这就是策略模式的应用.

因为上面获取FragmentManager需要Activity实例,所以这里还需要监听Activity生命周期,在onActivityCreated()中拿到Activity实例,从而拿到FragmentManager去监听Fragment生命周期.

```kotlin
//AndroidOFragmentDestroyWatcher.kt

override fun onFragmentViewDestroyed(
  fm: FragmentManager,
  fragment: Fragment
) {
  val view = fragment.view
  if (view != null && configProvider().watchFragmentViews) {
    objectWatcher.watch(
        view, "${fragment::class.java.name} received Fragment#onDestroyView() callback " +
        "(references to its views should be cleared to prevent leaks)"
    )
  }
}

override fun onFragmentDestroyed(
  fm: FragmentManager,
  fragment: Fragment
) {
  if (configProvider().watchFragments) {
    objectWatcher.watch(
        fragment, "${fragment::class.java.name} received Fragment#onDestroy() callback"
    )
  }
}
```

### 3.3 ViewModel

在前面讲到的AndroidXFragmentDestroyWatcher中还会单独监听onFragmentCreated()

```kotlin
override fun onFragmentCreated(
  fm: FragmentManager,
  fragment: Fragment,
  savedInstanceState: Bundle?
) {
  ViewModelClearedWatcher.install(fragment, objectWatcher, configProvider)
}
```

install里面实际是通过fragment和ViewModelProvider生成一个ViewModelClearedWatcher,这是一个新的ViewModel,然后在这个ViewModel的onCleared()里面检测这个fragment里面的每个ViewModel是否存在泄漏

```kotlin
//ViewModelClearedWatcher.kt

init {
    // We could call ViewModelStore#keys with a package spy in androidx.lifecycle instead,
    // however that was added in 2.1.0 and we support AndroidX first stable release. viewmodel-2.0.0
    // does not have ViewModelStore#keys. All versions currently have the mMap field.
    //通过反射拿到该fragment的所有ViewModel
    viewModelMap = try {
      val mMapField = ViewModelStore::class.java.getDeclaredField("mMap")
      mMapField.isAccessible = true
      @Suppress("UNCHECKED_CAST")
      mMapField[storeOwner.viewModelStore] as Map<String, ViewModel>
    } catch (ignored: Exception) {
      null
    }
  }

  override fun onCleared() {
    if (viewModelMap != null && configProvider().watchViewModels) {
      viewModelMap.values.forEach { viewModel ->
        objectWatcher.watch(
            viewModel, "${viewModel::class.java.name} received ViewModel#onCleared() callback"
        )
      }
    }
  }
```

## 4. 监测对象是否泄露

在讲这个之前得先回顾一个知识点,Java中的WeakReference是弱引用类型,每当发生GC时,它所持有的对象如果没有被其他强引用所持有,那么它所引用的对象就会被回收,同时或者稍后的时间这个WeakReference会被入队到ReferenceQueue中.LeakCanary中检测内存泄露就是基于这个原理.

```java
/**
 * Weak reference objects, which do not prevent their referents from being
 * made finalizable, finalized, and then reclaimed.  Weak references are most
 * often used to implement canonicalizing mappings.
 *
 * <p> Suppose that the garbage collector determines at a certain point in time
 * that an object is <a href="package-summary.html#reachability">weakly
 * reachable</a>.  At that time it will atomically clear all weak references to
 * that object and all weak references to any other weakly-reachable objects
 * from which that object is reachable through a chain of strong and soft
 * references.  At the same time it will declare all of the formerly
 * weakly-reachable objects to be finalizable.  At the same time or at some
 * later time it will enqueue those newly-cleared weak references that are
 * registered with reference queues.
 *
 * @author   Mark Reinhold
 * @since    1.2
 */

public class WeakReference<T> extends Reference<T> {

    /**
     * Creates a new weak reference that refers to the given object and is
     * registered with the given queue.
     *
     * @param referent object the new weak reference will refer to
     * @param q the queue with which the reference is to be registered,
     *          or <tt>null</tt> if registration is not required
     */
    public WeakReference(T referent, ReferenceQueue<? super T> q) {
        super(referent, q);
    }

}
```

实现要点:

1. 当一个对象需要被回收时,生成一个唯一的key,将它们封装进KeyedWeakReference中,并传入自定义的ReferenceQueue
2. 将key和KeyedWeakReference放入一个map中
3. 过一会儿之后(默认是5秒)主动触发GC,将自定义的ReferenceQueue中的KeyedWeakReference全部移除(它们所引用的对象已被回收),并同时根据这些KeyedWeakReference的key将map中的KeyedWeakReference也移除掉.
4. 此时如果map中还有KeyedWeakReference剩余,那么就是没有入队的,也就是说这些KeyedWeakReference所对应的对象还没被回收.这是不合理的,这里就产生了内存泄露.
5. 将这些内存泄露的对象分析引用链,保存数据

下面来看具体代码:

```koltin
//ObjectWatcher.kt

/**
* Watches the provided [watchedObject].
*
* @param description Describes why the object is watched.
*/
@Synchronized fun watch(
watchedObject: Any,
description: String
) {
    ......
    //移除引用队列中的所有KeyedWeakReference,同时也将其从map中移除
    removeWeaklyReachableObjects()
    val key = UUID.randomUUID().toString()
    val watchUptimeMillis = clock.uptimeMillis()
    val reference = KeyedWeakReference(watchedObject, key, description, watchUptimeMillis, queue)

    //存入map    
    watchedObjects[key] = reference
    
    //默认5秒之后执行moveToRetained()检查
    //这里是用的handler.postDelay实现的延迟
    checkRetainedExecutor.execute {
      moveToRetained(key)
    }
}

@Synchronized private fun moveToRetained(key: String) {
    //移除那些已经被回收的
    removeWeaklyReachableObjects()
    //判断一下这个key锁对应的KeyedWeakReference是否被移除了
    val retainedRef = watchedObjects[key]
    //没有被移除的话,说明是发生内存泄露了
    if (retainedRef != null) {
      retainedRef.retainedUptimeMillis = clock.uptimeMillis()
      onObjectRetainedListeners.forEach { it.onObjectRetained() }
    }
}

```

需要被回收的Activity、Fragment什么的都会走watch()这个方法这里,检测是否有内存泄露发生.上面这块代码对应着实现要点的1-4步.接下来具体分析内存泄露了是怎么走的

```kotlin
//InternalLeakCanary#onObjectRetained()
//InternalLeakCanary#scheduleRetainedObjectCheck()
//HeapDumpTrigger#scheduleRetainedObjectCheck()
//HeapDumpTrigger#checkRetainedObjects()

private fun checkRetainedObjects() {
    //比如如果是在调试,那么暂时先不dump heap,延迟20秒再判断一下状态

    val config = configProvider()
    
    ......
    //还剩多少对象没被回收  这些对象可能不是已经泄露的
    var retainedReferenceCount = objectWatcher.retainedObjectCount

    if (retainedReferenceCount > 0) {
      //手动触发GC,这里触发GC时还延迟了100ms,给那些回收了的对象入引用队列一点时间,好让结果更准确.
      gcTrigger.runGc()
      //再看看还剩多少对象没被回收
      retainedReferenceCount = objectWatcher.retainedObjectCount
    }
    
    //checkRetainedCount这里有2中情况返回true,流程return.
    //1. 未被回收的对象数是0,展示无泄漏的通知
    //2. 当retainedReferenceCount小于5个,展示有泄漏的通知(app可见或不可见超过5秒),延迟2秒再进行检查checkRetainedObjects()
    //app可见是在VisibilityTracker.kt中判断的,通过记录Activity#onStart和onStop的数量来判断
    if (checkRetainedCount(retainedReferenceCount, config.retainedVisibleThreshold)) return

    val now = SystemClock.uptimeMillis()
    val elapsedSinceLastDumpMillis = now - lastHeapDumpUptimeMillis
    if (elapsedSinceLastDumpMillis < WAIT_BETWEEN_HEAP_DUMPS_MILLIS) {
      //1分钟之内才dump过,再过会儿再来
      onRetainInstanceListener.onEvent(DumpHappenedRecently)
      showRetainedCountNotification(
          objectCount = retainedReferenceCount,
          contentText = application.getString(R.string.leak_canary_notification_retained_dump_wait)
      )
      scheduleRetainedObjectCheck(
          delayMillis = WAIT_BETWEEN_HEAP_DUMPS_MILLIS - elapsedSinceLastDumpMillis
      )
      return
    }

    //开始dump
    //通过 Debug.dumpHprofData(filePath)  dump heap
    //开始dump heap之前还得objectWatcher.clearObjectsWatchedBefore(heapDumpUptimeMillis) 清除一下这次dump开始之前的所有引用
    //最后是用HeapAnalyzerService这个IntentService去分析heap,具体在HeapAnalyzerService#runAnalysis()
    dumpHeap(retainedReferenceCount, retry = true)
  }
```

HeapAnalyzerService 里调用的是 Shark 库对 heap 进行分析，分析的结果再返回到 DefaultOnHeapAnalyzedListener.onHeapAnalyzed 进行分析结果入库、发送通知消息。

Shark 🦈 ：Shark is the heap analyzer that powers LeakCanary 2. It's a Kotlin standalone heap analysis library that runs at 「high speed」 with a 「low memory footprint」.

## 5. 总结

LeakCanary是一只优雅的金丝雀,帮助我们监测内存泄露.本文主要分析了LeakCanary的初始化、监听泄露的时机、监测某个对象泄露的过程.源码中实现非常优雅,本文中未完全展现出来,比较源码太多贴上来不太雅观.读源码不仅能让我们学到新东西,而且也让我们以后写代码有可以模仿的对象,甚至还可以在面试时得心应手,一举三得.
