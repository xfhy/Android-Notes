> 平时在开发安卓的过程中,View是我们用的非常非常多的东西.用户所看到的一切关于UI的,都是通过View绘制出来展示到屏幕上的.大多数情况下我们仅仅了解基本控件的使用方法,我们是无法做出非常复杂炫酷的自定义View的.我们需要掌握View的工作原理:测量、布局、绘制流程,掌握了这几个基本的流程我们才能做出更加完美的自定义View.做起来也更加得心应手.当然,View的工作原理,也是大多数面试所必问的知识点.要想了解工作原理,就只能read the fucking code. 

```
/***
 *                                         ,s555SB@@&                          
 *                                      :9H####@@@@@Xi                        
 *                                     1@@@@@@@@@@@@@@8                       
 *                                   ,8@@@@@@@@@B@@@@@@8                      
 *                                  :B@@@@X3hi8Bs;B@@@@@Ah,                   
 *             ,8i                  r@@@B:     1S ,M@@@@@@#8;                 
 *            1AB35.i:               X@@8 .   SGhr ,A@@@@@@@@S                
 *            1@h31MX8                18Hhh3i .i3r ,A@@@@@@@@@5               
 *            ;@&i,58r5                 rGSS:     :B@@@@@@@@@@A               
 *             1#i  . 9i                 hX.  .: .5@@@@@@@@@@@1               
 *              sG1,  ,G53s.              9#Xi;hS5 3B@@@@@@@B1                
 *               .h8h.,A@@@MXSs,           #@H1:    3ssSSX@1                  
 *               s ,@@@@@@@@@@@@Xhi,       r#@@X1s9M8    .GA981               
 *               ,. rS8H#@@@@@@@@@@#HG51;.  .h31i;9@r    .8@@@@BS;i;          
 *                .19AXXXAB@@@@@@@@@@@@@@#MHXG893hrX#XGGXM@@@@@@@@@@MS        
 *                s@@MM@@@hsX#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&,      
 *              :GB@#3G@@Brs ,1GM@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@B,     
 *            .hM@@@#@@#MX 51  r;iSGAM@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8     
 *          :3B@@@@@@@@@@@&9@h :Gs   .;sSXH@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@:    
 *      s&HA#@@@@@@@@@@@@@@M89A;.8S.       ,r3@@@@@@@@@@@@@@@@@@@@@@@@@@@r    
 *   ,13B@@@@@@@@@@@@@@@@@@@5 5B3 ;.         ;@@@@@@@@@@@@@@@@@@@@@@@@@@@i    
 *  5#@@#&@@@@@@@@@@@@@@@@@@9  .39:          ;@@@@@@@@@@@@@@@@@@@@@@@@@@@;    
 *  9@@@X:MM@@@@@@@@@@@@@@@#;    ;31.         H@@@@@@@@@@@@@@@@@@@@@@@@@@:    
 *   SH#@B9.rM@@@@@@@@@@@@@B       :.         3@@@@@@@@@@@@@@@@@@@@@@@@@@5    
 *     ,:.   9@@@@@@@@@@@#HB5                 .M@@@@@@@@@@@@@@@@@@@@@@@@@B    
 *           ,ssirhSM@&1;i19911i,.             s@@@@@@@@@@@@@@@@@@@@@@@@@@S   
 *              ,,,rHAri1h1rh&@#353Sh:          8@@@@@@@@@@@@@@@@@@@@@@@@@#:  
 *            .A3hH@#5S553&@@#h   i:i9S          #@@@@@@@@@@@@@@@@@@@@@@@@@A.
 *
 *
 *    又看源码，看你妹呀！
 */
```

## 1. View是从什么时候开始绘制的?

### 1.1 先简单来个demo

新建一个自定义View,名字叫MyView,分别在MyView的onMeasure(),onLayout(),onDraw()打上log.

```
@Override
protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
    super.onMeasure(widthMeasureSpec, heightMeasureSpec);
    Log.e(TAG, "onMeasure: ---MyView");
}

@Override
protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
    super.onLayout(changed, left, top, right, bottom);
    Log.e(TAG, "onLayout: ---MyView");
}

@Override
protected void onDraw(Canvas canvas) {
    super.onDraw(canvas);
    Log.e(TAG, "onDraw: ---MyView");
}
```

然后在Activity的布局中添加这个MyView,并在Activity的onCreate(),onStart(),onResume()打上log.

```java
@Override
protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_main);
    Log.e(TAG, "onCreate: ");
}

@Override
protected void onStart() {
    super.onStart();
    Log.e(TAG, "onStart: ");
}

@Override
protected void onResume() {
    super.onResume();
    Log.e(TAG, "onResume: ");
}
```

运行demo,看一下log:

```
05-13 22:35:37.130 17346-17346/com.xfhy.demo E/xfhy: onCreate: 
05-13 22:35:37.130 17346-17346/com.xfhy.demo E/xfhy: onStart: 
05-13 22:35:37.130 17346-17346/com.xfhy.demo E/xfhy: onResume: 
05-13 22:35:37.155 17346-17346/com.xfhy.demo E/xfhy: onMeasure: ---MyView
05-13 22:35:37.295 17346-17346/com.xfhy.demo E/xfhy: onLayout: ---MyView
05-13 22:35:37.315 17346-17346/com.xfhy.demo E/xfhy: onMeasure: ---MyView
05-13 22:35:37.315 17346-17346/com.xfhy.demo E/xfhy: onLayout: ---MyView
05-13 22:35:37.315 17346-17346/com.xfhy.demo E/xfhy: onDraw: ---MyView
```

好了,我们从log中就可以看出,**View的绘制其实是从Activity的onResume()之后才开始的.**

### 1.2 从源码层看看工作过程

在Activity的启动过程中,我们知道,在最后那里,ActivityThread中的handleLaunchActivity，performLaunchActivity，handleResumeActivity,这3个主要的方法完成了Activity的创建到启动工作.

> ps: 如果有不清楚的在网上查阅一下资料,这里推荐刚哥的书籍:安卓开发艺术探索 第九章

#### 1.2.1 handleLaunchActivity()

下面看一下handleLaunchActivity()方法:

```java
private void handleLaunchActivity(ActivityClientRecord r, Intent customIntent) {
    ...

    if (localLOGV) Slog.v(
        TAG, "Handling launch of " + r);
    
    //分析1 : 这里是创建Activity,并调用了Activity的onCreate()和onStart()
    Activity a = performLaunchActivity(r, customIntent);

    if (a != null) {
        r.createdConfig = new Configuration(mConfiguration);
        Bundle oldState = r.state;
        //分析2 : 这里调用Activity的onResume()
        handleResumeActivity(r.token, false, r.isForward,
                !r.activity.mFinished && !r.startsNotResumed);
    }
    ....
}
```

handleLaunchActivity()主要是为了调用performLaunchActivity()和handleResumeActivity()

#### 1.2.2 performLaunchActivity()

```java
private Activity performLaunchActivity(ActivityClientRecord r, Intent customIntent) {
    ......
    //分析1 : 这里底层是通过反射来创建的Activity实例
    java.lang.ClassLoader cl = r.packageInfo.getClassLoader();
    activity = mInstrumentation.newActivity(cl, component.getClassName(), r.intent);

    //底层也是通过反射构建Application,如果已经构建则不会重复构建,毕竟一个进程只能有一个Application
    Application app = r.packageInfo.makeApplication(false, mInstrumentation);

    if (activity != null) {
        Context appContext = createBaseContextForActivity(r, activity);
        CharSequence title = r.activityInfo.loadLabel(appContext.getPackageManager());
        Configuration config = new Configuration(mCompatConfiguration);
        if (DEBUG_CONFIGURATION) Slog.v(TAG, "Launching activity "
                + r.activityInfo.name + " with config " + config);
        //分析2 : 在这里实例化了PhoneWindow,并将该Activity设置为PhoneWindow的Callback回调,还初始化了WindowManager
        activity.attach(appContext, this, getInstrumentation(), r.token,
                r.ident, app, r.intent, r.activityInfo, title, r.parent,
                r.embeddedID, r.lastNonConfigurationInstances, config);

        //分析3 : 间接调用了Activity的performCreate方法,间接调用了Activity的onCreate方法.
        mInstrumentation.callActivityOnCreate(activity, r.state);
        
        //分析4: 这里和上面onCreate过程差不多,调用Activity的onStart方法
        if (!r.activity.mFinished) {
            activity.performStart();
            r.stopped = false;
        }
        ....
    }
}
```

主要过程:

1. 通过反射来创建的Activity实例
2. 在这里实例化了PhoneWindow,并将该Activity设置为PhoneWindow的Callback回调.建立起Activity与PhoneWindow之间的联系.
3. 调用了Activity的onCreate方法
4. 调用Activity的onStart方法

对于分析1中的代码:

```java
public Activity newActivity(ClassLoader cl, String className,
        Intent intent)
        throws InstantiationException, IllegalAccessException,
        ClassNotFoundException {
    //反射->实例化
    return (Activity)cl.loadClass(className).newInstance();
}
```

对于分析2中的代码:

```java
final void attach(Context context, ActivityThread aThread,
        Instrumentation instr, IBinder token, int ident,
        Application application, Intent intent, ActivityInfo info,
        CharSequence title, Activity parent, String id,
        NonConfigurationInstances lastNonConfigurationInstances,
        Configuration config, String referrer, IVoiceInteractor voiceInteractor,
        Window window, ActivityConfigCallback activityConfigCallback) {
    ......

    //实例化PhoneWindow
    mWindow = new PhoneWindow(this, window, activityConfigCallback);
    mWindow.setWindowControllerCallback(this);
    mWindow.setCallback(this);
    mWindow.setOnWindowDismissedCallback(this);
    
    .....
    //还有一些其他的配置代码

    mWindow.setWindowManager(
            (WindowManager)context.getSystemService(Context.WINDOW_SERVICE),
            mToken, mComponent.flattenToString(),
            (info.flags & ActivityInfo.FLAG_HARDWARE_ACCELERATED) != 0);

    mWindowManager = mWindow.getWindowManager();
    ....
}
```

对于分析3中的代码:

```java
//首先是来到Instrumentation的callActivityOnCreate方法
public void callActivityOnCreate(Activity activity, Bundle icicle) {
    prePerformCreate(activity);
    activity.performCreate(icicle);
    postPerformCreate(activity);
}

//然后就来到Activity的performCreate方法
final void performCreate(Bundle icicle) {
    performCreate(icicle, null);
}

final void performCreate(Bundle icicle, PersistableBundle persistentState) {
    ....
    if (persistentState != null) {
        onCreate(icicle, persistentState);
    } else {
        onCreate(icicle);
    }
    ......
}

```

对于分析4中的代码:

```java
//Activity
final void performStart() {
    ......
    mInstrumentation.callActivityOnStart(this);
    ......
}

//Instrumentation
public void callActivityOnStart(Activity activity) {
    activity.onStart();
}
```

#### 1.2.3 handleResumeActivity()

```java
final void handleResumeActivity(IBinder token,
        boolean clearHide, boolean isForward, boolean reallyResume, int seq, String reason) {
    .....
    //分析1 : 在其内部调用Activity的onResume方法
    r = performResumeActivity(token, clearHide, reason);

    .....
    r.window = r.activity.getWindow();
    View decor = r.window.getDecorView();
    decor.setVisibility(View.INVISIBLE);
    //获取WindowManager
    ViewManager wm = a.getWindowManager();
    WindowManager.LayoutParams l = r.window.getAttributes();
    a.mDecor = decor;

    if (a.mVisibleFromClient) {
        .....
        //分析2 : WindowManager添加DecorView
        wm.addView(decor, l);
        ...
    }
    .....

}
```

细看分析2中的逻辑:

```java
@Override
public void addView(@NonNull View view, @NonNull ViewGroup.LayoutParams params) {
    applyDefaultToken(params);
    mGlobal.addView(view, params, mContext.getDisplay(), mParentWindow);
}
```

我们看到,方法里面将逻辑交给了mGlobal,mGlobal是WindowManagerGlobal,WindowManagerGlobal是全局单例.WindowManagerImpl的方法都是由WindowManagerGlobal完成的.我们跟着来到了WindowManagerGlobal的addView方法.

```java
public void addView(View view, ViewGroup.LayoutParams params,
        Display display, Window parentWindow) {
    ....

    ViewRootImpl root;

    synchronized (mLock) {
        root = new ViewRootImpl(view.getContext(), display);
        view.setLayoutParams(wparams);

        .....

        root.setView(view, wparams, panelParentView);
    }
}
```

在这里我们看到了,实例化ViewRootImpl,然后建立ViewRootImpl与View的联系.跟着进入setView方法

```java
public void setView(View view, WindowManager.LayoutParams attrs, View panelParentView) {
    .....
    requestLayout();
    .....
}

@Override
public void requestLayout() {
    if (!mHandlingLayoutInLayoutRequest) {
        //检查线程合法性
        checkThread();
        mLayoutRequested = true;
        scheduleTraversals();
    }
}

void scheduleTraversals() {
    if (!mTraversalScheduled) {
        mTraversalScheduled = true;
        mTraversalBarrier = mHandler.getLooper().getQueue().postSyncBarrier();
        mChoreographer.postCallback(
                Choreographer.CALLBACK_TRAVERSAL, mTraversalRunnable, null);
        ......
    }
}

final class TraversalRunnable implements Runnable {
    @Override
    public void run() {
        doTraversal();
    }
}
final TraversalRunnable mTraversalRunnable = new TraversalRunnable();


void doTraversal() {
    if (mTraversalScheduled) {
        ....
        performTraversals();
        ....
    }
}

```

一路下来,我们来到了熟悉的方法面前:performTraversals方法.

#### 1.2.4 performTraversals()

performTraversals()方法相信大家都已经非常熟悉啦,它是整个View绘制的核心,从measure到layout,再从layout到draw,全部在这个方法里面完成了,所以这个方法里面的代码非常长,这是肯定的.由于本人水平有限,就不每句代码逐行分析了,我们需要学习的是一个主要的流程.

下面的performTraversals()方法的超精简代码,里面的代码真的超级超级多,下面是主要流程,也是今天的主角

```java
private void performTraversals() {
    //分析1 : 这里面会调用performMeasure开始测量流程
    measureHierarchy(host, lp, res,
                    desiredWindowWidth, desiredWindowHeight);
    //分析2 : 开始布局流程
    performLayout(lp, mWidth, mHeight);
    //分析3 : 开始绘画流程
    performDraw();
}
```

首先,来个主要的流程图,这个是performTraversals()的大致流程.

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/performTraversals%E7%9A%84%E5%A4%A7%E8%87%B4%E6%B5%81%E7%A8%8B.png)

如上面的代码所示,performTraversals()会依次调用performMeasure、performLayout、performDraw方法,而这三个方法是View的绘制流程的核心所在.

- performMeasure : 在performMeasure里面会调用measure方法,然后measure会调用onMeasure方法,而在onMeasure方法中则会对所有的子元素进行measure过程.这相当于完成了一次从父元素到子元素的measure传递过程,如果子元素是一个ViewGroup,那么继续向下传递,直到所有的View都已测量完成.测量完成之后,我们可以根据getMeasureHeight和getMeasureWidth方法获取该View的高度和宽度.
- performLayout : performLayout的原理其实是和performMeasure差不多,在performLayout里面调用了layout方法,然后在layout方法会调用onLayout方法,onLayout又会对所有子元素进行layout过程.由父元素向子元素传递,最终完成所有View的layout过程.确定View的4个点: left+top+right+bottom,layout完成之后可以通过getWidth和getHeight获取View的最终宽高.
- performDraw : 也是和performMeasure差不多,从父元素从子元素传递.在performDraw里面会调用draw方法,draw方法再调用drawSoftware方法,drawSoftware方法里面回调用View的draw方法,然后再通过dispatchDraw方法分发,遍历所有子元素的draw方法,draw事件就这样一层层地传递下去.

## 2. View 测量流程

### 2.1 MeasureSpec

在开始进行理解View的测量流程之前,需要先理解MeasureSpec.

MeasureSpec代表的是32位的int值,它的高2位是SpecMode(也是一个int),低30位是SpecSize(也是一个int),SpecMode是测量模式,SpecSize是测量大小. MeasureSpec相当于是两者的结合. 系统封装了如何从MeasureSpec中提取SpecMode和SpecSize,也封装了用SpecMode和SpecSize组合成MeasureSpec.

```java
public static class MeasureSpec {
    private static final int MODE_SHIFT = 30;
    private static final int MODE_MASK  = 0x3 << MODE_SHIFT;
    public static final int UNSPECIFIED = 0 << MODE_SHIFT;
    public static final int EXACTLY     = 1 << MODE_SHIFT;
    public static final int AT_MOST     = 2 << MODE_SHIFT;

    public static int makeMeasureSpec(int size,int mode) {
        if (sUseBrokenMakeMeasureSpec) {
            return size + mode;
        } else {
            return (size & ~MODE_MASK) | (mode & MODE_MASK);
        }
    }

    public static int getMode(int measureSpec) {
        return (measureSpec & MODE_MASK);
    }

    public static int getSize(int measureSpec) {
        return (measureSpec & ~MODE_MASK);
    }
}
```

SpecMode有3种,分别是

- `UNSPECIFIED` 父容器对View不会有任何限制,要多大给多大,一般是用在系统内部使用,我们开发的APP用不到.
- `EXACTLY` 这种情况对应于`match_parent`和具体数值这两种模式,父容器已经检测出View需要的精确大小.
- `AT_MOST` 这种情况对应于`wrap_content`,父容器指定了一个最大值,View不能超过这个值.

一般来说,View的MeasureSpec由父容器的MeasureSpec和自己的LayoutParams共同决定.因为有了MeasureSpec才可以在onMeasure中确定测量宽高.

下面是从源码中提取出来的摘要信息,后面会详细看源码分析,这里先提取出来

- 如果View的宽高是固定的值,那么不管父容器的MeasureSpec是什么,View的MeasureSpec都是EXACTLY
- 如果View的宽高是`wrap_content`,那么不管父容器的MeasureSpec是EXACTLY还是`AT_MOST`,最终View的MeasureSpec都是`AT_MOST`,这里暂时不用管UNSPECIFIED(我们用不到).而且View最终的大小不能超过父容器的剩余空间
- 如果View的宽高是`match_parent`,那么要分两种情况
  - 如果父容器是EXACTLY,那么View就是EXACTLY
  - 如果父容器是`AT_MOST`,那么View也是`AT_MOST`.

这里不得不引用一张刚哥书籍里面的经典表格来表示一下:

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/%E6%99%AE%E9%80%9AView%E7%9A%84MeasureSpec%E7%9A%84%E5%88%9B%E5%BB%BA%E8%A7%84%E5%88%99.png)

ps:这里必须要强烈推荐一波刚哥的安卓开发艺术探索这本书.没看过这本书,都不敢说自己是学安卓的.去年我作为萌新买了这本书看了一遍,觉得受益匪浅.今年打算再看一遍,重新梳理一下.好书是值得反复推敲琢磨的.

### 2.2 从performMeasure()开始View测量

我们从ViewRootImpl的performTraversals()开始着手,仔细观察

```java
private void performTraversals() {
    //host为根视图,即DecorView
    //desiredWindowWidth是Window的宽度
    measureHierarchy(host, lp, res,
                    desiredWindowWidth, desiredWindowHeight);
}

private boolean measureHierarchy(final View host, final WindowManager.LayoutParams lp,
                                     final Resources res, final int desiredWindowWidth, 									final int desiredWindowHeight) {
    //分析1 : desiredWindowWidth就是Window的宽度,desiredWindowHeight是Window的高度
    childWidthMeasureSpec = getRootMeasureSpec(desiredWindowWidth, lp.width);
    childHeightMeasureSpec = getRootMeasureSpec(desiredWindowHeight, lp.height);
    //分析2 : 开始测量流程
    performMeasure(childWidthMeasureSpec, childHeightMeasureSpec);                     
}
```

measure是从上往下执行的,widthMeasureSpec和heightMeasureSpec通常情况下是由父容器传递给子视图的.但是最外层的根视图,怎么拿到MeasureSpec呢? 在执行performMeasure方法之前,我们需要拿到最外层的视图的MeasureSpec,看代码

```java
private static int getRootMeasureSpec(int windowSize, int rootDimension) {
    int measureSpec;
    switch (rootDimension) {
    //如果是MATCH_PARENT,那么就是EXACTLY
    case ViewGroup.LayoutParams.MATCH_PARENT:
        // Window can't resize. Force root view to be windowSize.
        measureSpec = MeasureSpec.makeMeasureSpec(windowSize, MeasureSpec.EXACTLY);
        break;
    //如果是WRAP_CONTENT,就是AT_MOST
    case ViewGroup.LayoutParams.WRAP_CONTENT:
        // Window can resize. Set max size for root view.
        measureSpec = MeasureSpec.makeMeasureSpec(windowSize, MeasureSpec.AT_MOST);
        break;
    default:
        //如果是固定的值,也是EXACTLY
        // Window wants to be an exact size. Force root view to be that size.
        measureSpec = MeasureSpec.makeMeasureSpec(rootDimension, MeasureSpec.EXACTLY);
        break;
    }
    return measureSpec;
}
```

最外层的根视图的MeasureSpec只由自己的LayoutParams决定,做自己的主人,舒服.

既然我们根视图拿到了MeasureSpec,接下来就要拿自己的MeasureSpec教孩子做人了.

```java
private void performMeasure(int childWidthMeasureSpec, int childHeightMeasureSpec) {
    //调用根视图的measure方法,开始测量流程
    mView.measure(childWidthMeasureSpec, childHeightMeasureSpec);
}
```

这里的mView就是DecorView.DecorView是一个FrameLayout,而FrameLayout是一个ViewGroup,而ViewGroup是一个View,这个measure方法就是在View里面的. 因为measure是一个final方法,哈哈,所以子类不能覆写它.

```java
public final void measure(int widthMeasureSpec, int heightMeasureSpec) {
    ......
    //调用onMeasure方法  
    onMeasure(widthMeasureSpec, heightMeasureSpec);
    ......
}
```

measure方法里面有一些检测是否需要重新onMeasure的代码,被我略去了.

onMeasure是View里面的方法,ViewGroup是一个抽象类并且没有重写onMeasure.因为onMeasure方法的实现,每个都是不一样的,比如LinearLayout和FrameLayout的onMeasure方法肯定是实现逻辑不一样的.

因为DecorView是FrameLayout,所以我们看看FrameLayout中的onMeasure.

FrameLayout->onMeasure()

```java
@Override
protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
    int count = getChildCount();

    for (int i = 0; i < count; i++) {
        final View child = getChildAt(i);
        if (mMeasureAllChildren || child.getVisibility() != GONE) {
            //分析1 : 遍历所有子控件,测量每个子控件的大小
                //参数1:View控件
                //参数2:宽MeasureSpec
                //参数3:父容器在宽度上已经用了多少了,因为FrameLayout的规则是:前面已经放置的View并不会影响后面放置View的宽高,是直接覆盖到上一个View上的.所以这里传0
                //参数4:高MeasureSpec
                //参数5:父容器在高度上已经用了多少了
            measureChildWithMargins(child, widthMeasureSpec, 0, heightMeasureSpec, 0);
        }
    }
    ......

    //分析2 : 测量完所有的子控件的大小之后,才知道自己的大小  这很符合FrameLayout的规则嘛
    setMeasuredDimension(resolveSizeAndState(maxWidth, widthMeasureSpec, childState),
            resolveSizeAndState(maxHeight, heightMeasureSpec,
                    childState << MEASURED_HEIGHT_STATE_SHIFT));
    ......
}
```

FrameLayout的onMeasure方法中会遍历所有子控件,然后进行所有子控件的大小测量.最后才来设置自己的大小.注意,onMeasure方法的入参MeasureSpec是从父容器传过来的,意思就是给你个参考,你自己看着办吧.

在测量子控件大小的时候会调用ViewGroup的measureChildWithMargins方法,下面是代码:

```java
protected void measureChildWithMargins(View child,
        int parentWidthMeasureSpec, int widthUsed,
        int parentHeightMeasureSpec, int heightUsed) {
    //获取子控件的LayoutParams
    final MarginLayoutParams lp = (MarginLayoutParams) child.getLayoutParams();
    
    //分析1: 计算子控件在宽上的MeasureSpec  
        //参数1:父容器的MeasureSpec
        //参数2:这里官方的入参名称是padding,从下面这个传值的形式来看,显然是子控件在宽上不能利用的空间(ViewGroup的左右两边padding+子控件的左右margin+父容器在宽度上已经使用了并且不能再使用的空间)
        //参数3:子控件想要的宽度
    final int childWidthMeasureSpec = getChildMeasureSpec(parentWidthMeasureSpec,
            mPaddingLeft + mPaddingRight + lp.leftMargin + lp.rightMargin
                    + widthUsed, lp.width);
    final int childHeightMeasureSpec = getChildMeasureSpec(parentHeightMeasureSpec,
            mPaddingTop + mPaddingBottom + lp.topMargin + lp.bottomMargin
                    + heightUsed, lp.height);
    
    //分析2: 将measure过程传递给子控件  如果子控件又是一个ViewGroup,那么继续向下传递
    child.measure(childWidthMeasureSpec, childHeightMeasureSpec);
}
```

在measureChildWithMargins方法里我们首先是看到根据子控件的LayoutParams和父容器的MeasureSpec计算子控件的MeasureSpec,然后将计算出的MeasureSpec通过子控件的measure方法传递下去.如果子控件又是一个ViewGroup,那么它又会重复的measure流程,一直向下传递这个过程,直接最后的那个是View为止.因为View没有子控件,它就不能向下传递了.

所以我们自定义View(这里指那种直接继承自View)的时候,在onMeasure方法里面,需要根据自身的LayoutParams+父容器的MeasureSpec来计算SpecSize和SpecMode,最后根据业务场景来确定自己的大小(调用setMeasuredDimension来确定大小).

**注意了,接下来的getChildMeasureSpec方法就比较重要了**

```java
//这里来自ViewGroup的getChildMeasureSpec方法,无删减
public static int getChildMeasureSpec(int spec, int padding, int childDimension) {
    //根据父容器的MeasureSpec获取父容器的SpecMode和SpecSize
    int specMode = MeasureSpec.getMode(spec);
    int specSize = MeasureSpec.getSize(spec);
    
    //剩下的size
    int size = Math.max(0, specSize - padding);

    //最终的size和mode
    int resultSize = 0;
    int resultMode = 0;

    switch (specMode) {
    // Parent has imposed an exact size on us
    //父容器有一个确定的大小
    case MeasureSpec.EXACTLY:
        if (childDimension >= 0) {
            //子控件也是确定的大小,那么最终的大小就是子控件设置的大小,SpecMode为EXACTLY
            resultSize = childDimension;
            resultMode = MeasureSpec.EXACTLY;
        } else if (childDimension == LayoutParams.MATCH_PARENT) {
            // Child wants to be our size. So be it.
            // 子控件想要占满剩余的空间,那么就给它吧.
            resultSize = size;
            resultMode = MeasureSpec.EXACTLY;
        } else if (childDimension == LayoutParams.WRAP_CONTENT) {
            // Child wants to determine its own size. It can't be
            // bigger than us.
            //子控件想要自己定义大小,但是不能超过剩余空间 size
            resultSize = size;
            resultMode = MeasureSpec.AT_MOST;
        }
        break;

    // Parent has imposed a maximum size on us
    case MeasureSpec.AT_MOST:
        if (childDimension >= 0) {
            // Child wants a specific size... so be it
            resultSize = childDimension;
            resultMode = MeasureSpec.EXACTLY;
        } else if (childDimension == LayoutParams.MATCH_PARENT) {
            // Child wants to be our size, but our size is not fixed.
            // Constrain child to not be bigger than us.
            resultSize = size;
            resultMode = MeasureSpec.AT_MOST;
        } else if (childDimension == LayoutParams.WRAP_CONTENT) {
            // Child wants to determine its own size. It can't be
            // bigger than us.
            resultSize = size;
            resultMode = MeasureSpec.AT_MOST;
        }
        break;

    // Parent asked to see how big we want to be
    case MeasureSpec.UNSPECIFIED:
        if (childDimension >= 0) {
            // Child wants a specific size... let him have it
            resultSize = childDimension;
            resultMode = MeasureSpec.EXACTLY;
        } else if (childDimension == LayoutParams.MATCH_PARENT) {
            // Child wants to be our size... find out how big it should
            // be
            resultSize = View.sUseZeroUnspecifiedMeasureSpec ? 0 : size;
            resultMode = MeasureSpec.UNSPECIFIED;
        } else if (childDimension == LayoutParams.WRAP_CONTENT) {
            // Child wants to determine its own size.... find out how
            // big it should be
            resultSize = View.sUseZeroUnspecifiedMeasureSpec ? 0 : size;
            resultMode = MeasureSpec.UNSPECIFIED;
        }
        break;
    }
    //noinspection ResourceType
    return MeasureSpec.makeMeasureSpec(resultSize, resultMode);
}
```

这段代码对应着下面这段总结

- 如果View的宽高是固定的值,那么不管父容器的MeasureSpec是什么,View的MeasureSpec都是EXACTLY
- 如果View的宽高是`wrap_content`,那么不管父容器的MeasureSpec是EXACTLY还是`AT_MOST`,最终View的MeasureSpec都是`AT_MOST`,这里暂时不用管UNSPECIFIED(我们用不到).而且View最终的大小不能超过父容器的剩余空间
- 如果View的宽高是`match_parent`,那么要分两种情况
  - 如果父容器是EXACTLY,那么View就是EXACTLY
  - 如果父容器是`AT_MOST`,那么View也是`AT_MOST`.

这段代码对应着上面刚哥总结的那个表格.同时也是measure流程的核心内容.

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/%E6%99%AE%E9%80%9AView%E7%9A%84MeasureSpec%E7%9A%84%E5%88%9B%E5%BB%BA%E8%A7%84%E5%88%99.png)

因为在measureChildWithMargins方法里我们已经计算出子控件的MeasureSpec,然后通过measure传递给子控件了,如果子控件又是一个ViewGroup,那么它又会重复的measure流程,一直向下传递这个过程,直接最后的那个是View为止.因为View没有子控件,它就不能向下传递了.到这里其实我们的View的measure流程已经走完了,哈哈,不知不觉.

下面简单画一个流程图,方便理解上面的流程.

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/measure%E6%B5%81%E7%A8%8B%E5%9B%BE.png)

### 2.3 measure小结

从ViewRootImpl的performTraversals方法开始进入View的绘制过程,performTraversals方法里面会有一个performMeasure方法.这个performMeasure方法是专门拿来测量View的大小的.而且会遍历整个View树,全部进行测量.

在performMeasure里面会调用measure方法,然后measure会调用onMeasure方法,而在onMeasure方法中则会对所有的子元素进行measure过程.这相当于完成了一次从父元素到子元素的measure传递过程,如果子元素是一个ViewGroup,那么继续向下传递,直到所有的View都已测量完成.测量完成之后,我们可以根据getMeasureHeight和getMeasureWidth方法获取该View的高度和宽度.

## 3. View 布局流程

### 3.1 从performLayout开始布局

我们还是从ViewRootImpl的performTraversals()开始着手

```java
private void performTraversals() {
    ....
    //开始布局流程
    performLayout(lp, mWidth, mHeight);
    .....
}

private void performLayout(WindowManager.LayoutParams lp, int desiredWindowWidth,
        int desiredWindowHeight) {
    .....
    //这里的host其实是根视图(DecorView)
        //参数:left,top,right,bottom  这些位置都是相对于父容器而言的
    host.layout(0, 0, host.getMeasuredWidth(), host.getMeasuredHeight());
    .....
}

```

在performLayout方法里面调用了DecorView的layout方法,然后我发现:layout方法其实是View这个父类里面的,然后ViewGroup继承了View之后重写了一下,只是调了一下`super.layout(l, t, r, b);`,相当于实现还是在View的layout里面.而且ViewGroup的layout方法是final修饰的,意味着子类不能再重写这个方法了.

```java
//以下是View的layout方法
public void layout(int l, int t, int r, int b) {
    ......
    onLayout(changed, l, t, r, b);
    ......
}
```

layout方法其实就是调用onLayout方法,如果这里子控件是一个View的话,那么onLayout其实是空实现.onLayout在ViewGroup是一个抽象方法,如果是一个ViewGroup的话,比如FrameLayout,那么onLayout是需要自己实现的.


```java
//View中的定义
protected void onLayout(boolean changed, int left, int top, int right, int bottom) {}

//ViewGroup中的定义,没错,这是抽象方法,具体的实现交由实现类去实现
@Override
protected abstract void onLayout(boolean changed, int l, int t, int r, int b);
```

因为我们的根视图是DecorView,也就是FrameLayout,那么我们来看一下FrameLayout的onLayout实现:

```java
@Override
protected void onLayout(boolean changed, int left, int top, int right, int bottom) {   
    //布局子控件  我没看懂这个changed参数是拿来干什么的,好像并没有用上(这里已经是FrameLayout的onLayout方法的全部代码了)
    layoutChildren(left, top, right, bottom, false /* no force left gravity */);
}

void layoutChildren(int left, int top, int right, int bottom, boolean forceLeftGravity) {
    final int count = getChildCount();
    
    //最左侧
    final int parentLeft = getPaddingLeftWithForeground();
    //最右侧
    final int parentRight = right - left - getPaddingRightWithForeground();
    //最顶部
    final int parentTop = getPaddingTopWithForeground();
    //最底部
    final int parentBottom = bottom - top - getPaddingBottomWithForeground();

    for (int i = 0; i < count; i++) {
        final View child = getChildAt(i);
        if (child.getVisibility() != GONE) {
            final LayoutParams lp = (LayoutParams) child.getLayoutParams();
            
            //因为已经measure流程走完了,所以这里是能通过getMeasuredWidth方法获取测量宽度的
            final int width = child.getMeasuredWidth();
            final int height = child.getMeasuredHeight();

            //实际子控件的left
            int childLeft;
            int childTop;

            int gravity = lp.gravity;
            if (gravity == -1) {
                gravity = DEFAULT_CHILD_GRAVITY;
            }

            final int layoutDirection = getLayoutDirection();
            final int absoluteGravity = Gravity.getAbsoluteGravity(gravity, layoutDirection);
            final int verticalGravity = gravity & Gravity.VERTICAL_GRAVITY_MASK;

            switch (absoluteGravity & Gravity.HORIZONTAL_GRAVITY_MASK) {
                //水平居中
                case Gravity.CENTER_HORIZONTAL:
                    childLeft = parentLeft + (parentRight - parentLeft - width) / 2 +
                    lp.leftMargin - lp.rightMargin;
                    break;
                case Gravity.RIGHT:  //子控件在父容器的最右侧
                    if (!forceLeftGravity) {
                        childLeft = parentRight - width - lp.rightMargin;
                        break;
                    }
                case Gravity.LEFT: //子控件在父容器的最左侧
                default:
                    childLeft = parentLeft + lp.leftMargin;
            }
            
            //竖直方向上的gravity
            switch (verticalGravity) {
                case Gravity.TOP:  //位于父容器的顶部
                    childTop = parentTop + lp.topMargin;
                    break;
                case Gravity.CENTER_VERTICAL:  //垂直居中
                    childTop = parentTop + (parentBottom - parentTop - height) / 2 +
                    lp.topMargin - lp.bottomMargin;
                    break;
                case Gravity.BOTTOM:  //位于父容器底部
                    childTop = parentBottom - height - lp.bottomMargin;
                    break;
                default:
                    childTop = parentTop + lp.topMargin;
            }
            
            //最后给这个子控件一个最终的left,top,right,bottom值
            //把这个子控件放在这里
            child.layout(childLeft, childTop, childLeft + width, childTop + height);
        }
    }
}
```

不同的ViewGroup的实现类的onLayout方法实现是不一样的,是根据自身情况来决定将子控件放在那里的,比如FrameLayout和LinearLayout的onLayout是不一样的实现,但是onLayout这个方法最终是将各个子控件有条不紊的放在对应的位置上.

我们看到在onLayout方法的最后,调用了子控件的layout方法,其实就是将layout流程向下进行传递了.如果子控件还是ViewGroup的话,那么它又会对它自己所有的子控件进行布局,放置.最后一层一层的往下,直到全部都layout完成.每个View都知道自己的left,top,right,bottom.这个时候是可以通过View的getWidth和getHeight来获取最终的宽高的.

下面的View的getWidth和getHeight方法的实现,可以看到,就是通过这四个位置来确定的宽高.
```java
public final int getWidth() {
    return mRight - mLeft;
}

public final int getHeight() {
    return mBottom - mTop;
}
```

### 3.2 layout小结

layout主要是为了确定该控件以及其子控件的位置和大小.在performLayout中,主要是确定每个控件的left+top+right+bottom,performLayout之后它们的位置就已经被确定了,就只剩下最后一步绘制了.

## 4. View 绘制流程

还是从ViewRootImpl的performTraversals方法开始分析

```java
private void performTraversals() {
    //开始绘画流程
    performDraw();
}

private void performDraw() {
    ......
    draw(fullRedrawNeeded);
    ......
}

private void draw(boolean fullRedrawNeeded){
    .....
    drawSoftware(surface, mAttachInfo, xOffset, yOffset, scalingRequired, dirty);
    .....
}

private boolean drawSoftware(Surface surface, AttachInfo attachInfo, int xoff, int yoff,
        boolean scalingRequired, Rect dirty) {
    ......
    mView.draw(canvas);
    ......
}

```

随着方法的调用深入,发现来到了View的draw方法

```java
public void draw(Canvas canvas) {
    .....

    /*
        注意了这是官方给的注释,谷歌工程师还真是贴心,把draw步骤写的详详细细,给力,点赞
     * Draw traversal performs several drawing steps which must be executed
     * in the appropriate order:
     *
     *      1. Draw the background
     *      2. If necessary, save the canvas' layers to prepare for fading
     *      3. Draw view's content
     *      4. Draw children
     *      5. If necessary, draw the fading edges and restore layers
     *      6. Draw decorations (scrollbars for instance)
     */

    // Step 1, draw the background, if needed
    //1. 绘制背景
    if (!dirtyOpaque) {
        drawBackground(canvas);
    }

    // skip step 2 & 5 if possible (common case)
    final int viewFlags = mViewFlags;
    boolean horizontalEdges = (viewFlags & FADING_EDGE_HORIZONTAL) != 0;
    boolean verticalEdges = (viewFlags & FADING_EDGE_VERTICAL) != 0;
    if (!verticalEdges && !horizontalEdges) {
        // Step 3, draw the content
        //3. 绘制自己的内容
        if (!dirtyOpaque) onDraw(canvas);

        // Step 4, draw the children
        //4. 绘制子控件  如果是View的话这个方法是空实现,如果是ViewGroup则绘制子控件
        dispatchDraw(canvas);

        drawAutofilledHighlight(canvas);

        // Overlay is part of the content and draws beneath Foreground
        if (mOverlay != null && !mOverlay.isEmpty()) {
            mOverlay.getOverlayView().dispatchDraw(canvas);
        }

        // Step 6, draw decorations (foreground, scrollbars)
        //6. 绘制装饰和前景
        onDrawForeground(canvas);

        // Step 7, draw the default focus highlight
        //7. 绘制默认焦点高亮显示
        drawDefaultFocusHighlight(canvas);

        if (debugDraw()) {
            debugDrawFocus(canvas);
        }

        // we're done...
        return;
    }
    .....
}
```

注意到,谷歌工程师将draw的步骤完完全全的写出来了的.还真是贴心啊.draw的基本步骤如下

1. 绘制背景
2. 绘制控件自己本身的内容
3. 绘制子控件
4. 绘制装饰(比如滚动条)和前景

这里简单提一下dispatchDraw方法,在这个方法里面会去调用drawChild方法,在drawChild里面会调用子控件的draw方法,这相当于完成了draw的传递过程,通知子控件去绘制它自己. 然后如果子控件是ViewGroup,它又会重复上面这个递推.

draw的流程比测量和布局要简单一些,但是需要注意的是,View绘制过程是通过dispatchDraw来传递的.

## 5. 结束语

写一篇深入(可能只是对我来说)的文章真的好不容易,期间遇到了很多坑,也学到了很多.之前其实这部分是学过的.但是只有当自己去看源码,一步步分析,输出成文档,才真正理解其中的原理,为什么代码要这样写.

可能还是太菜了吧,写这么一篇水文花了大概4天......
