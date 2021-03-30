Window,Activity,View三者关系
---
#### 目录
- [简单概括三者关系](#head1)
- [三者各自创建时机](#head2)
	- [Activity的创建](#head3)
	- [Window的创建](#head4)
	- [View的创建](#head5)
- [WindowManager的addView](#head6)
- [ViewRootImpl的setView](#head7)
- [触摸事件的接收](#head8)
- [小结](#head9)
- [参考](#head10)

---

> ps：文中源码为API 28

经常听到和用到Window，Window到底是什么？

### <span id="head1">简单概括三者关系</span>

View其实是Android中视图的呈现方式，它必须附着在Window这个抽象的概念上，因此有视图的地方就有Window。有视图的地方不仅仅有Activity，还有Dialog、Toast，除此之外还有一些依托Window实现的视图：PopupWindow、菜单，它们也是视图，有视图的地方就有Window。因此Activity、Dialog、Toast都对应着一个Window。

### <span id="head2">三者各自创建时机</span>

这里是以Activity进行举例

#### <span id="head3">Activity的创建</span>

了解过Activity启动流程的应该知道，创建Activity是通过ActivityThread的performLaunchActivity()中进行的。

```java
ContextImpl appContext = createBaseContextForActivity(r);
Activity activity = null;
java.lang.ClassLoader cl = appContext.getClassLoader();
//在内部是通过反射的方式来创建实例的
activity = mInstrumentation.newActivity(
        cl, component.getClassName(), r.intent);
...        
activity.attach(appContext, this, getInstrumentation(), r.token,
                        r.ident, app, r.intent, r.activityInfo, title, r.parent,
                        r.embeddedID, r.lastNonConfigurationInstances, config,
                        r.referrer, r.voiceInteractor, window, r.configCallback,
                        r.assistToken);
```

创建好了Activity之后，紧接着就调用了Activity的attach方法，传过去了很多东西进行初始化。

#### <span id="head4">Window的创建</span>

创建好Activity，马上就调用attach方法，Window就是在这个attach方法中被创建的。

```java
 final void attach(Context context, ActivityThread aThread,
            Instrumentation instr, IBinder token, int ident,
            Application application, Intent intent, ActivityInfo info,
            CharSequence title, Activity parent, String id,
            NonConfigurationInstances lastNonConfigurationInstances,
            Configuration config, String referrer, IVoiceInteractor voiceInteractor,
            Window window, ActivityConfigCallback activityConfigCallback) {
    ...        
    mWindow = new PhoneWindow(this, window, activityConfigCallback);
    mWindow.setWindowControllerCallback(this);
    //设置了一个Callback，后面会用到
    mWindow.setCallback(this);
    mWindow.setOnWindowDismissedCallback(this);
    mWindow.getLayoutInflater().setPrivateFactory(this);
    if (info.softInputMode != WindowManager.LayoutParams.SOFT_INPUT_STATE_UNSPECIFIED) {
        mWindow.setSoftInputMode(info.softInputMode);
    }
    if (info.uiOptions != 0) {
        mWindow.setUiOptions(info.uiOptions);
    }
    ...
    mWindow.setWindowManager(
                (WindowManager)context.getSystemService(Context.WINDOW_SERVICE),
                mToken, mComponent.flattenToString(),
                (info.flags & ActivityInfo.FLAG_HARDWARE_ACCELERATED) != 0);
    mWindowManager = mWindow.getWindowManager();
}
```

可以看到，创建出来的Window其实是PhoneWindow实例，并且创建之后马上设置了一个回调`setCallback(this)`，这个有点用处，后面会讲到。

注意到在最后那里，mWindow.setWindowManager()设置了一个WindowManager。

```java
//Window.java
public void setWindowManager(WindowManager wm, IBinder appToken, String appName,
            boolean hardwareAccelerated) {
    mAppToken = appToken;
    mAppName = appName;
    mHardwareAccelerated = hardwareAccelerated;
    if (wm == null) {
        wm = (WindowManager)mContext.getSystemService(Context.WINDOW_SERVICE);
    }
    mWindowManager = ((WindowManagerImpl)wm).createLocalWindowManager(this);
}

//WindowManagerImpl.java
public WindowManagerImpl createLocalWindowManager(Window parentWindow) {
    return new WindowManagerImpl(mContext, parentWindow);
}
```

这样一来，Window中就持有了一个WindowManagerImpl的引用。

#### <span id="head5">View的创建</span>

Activity所对应的视图其实是在其对应的PhoneWindow中管理着的，它就是鼎鼎大名的DecorView。它是什么时候创建的呢？平时我们使用Activity时，设置一个布局是通过setContentView来完成的，它内部代码如下：

```java
public void setContentView(@LayoutRes int layoutResID) {
    getWindow().setContentView(layoutResID);
    initWindowDecorActionBar();
}
public Window getWindow() {
    return mWindow;
}
```

设置进来一个布局的id，然后交给PhoneWindow去处理，Activity自己啥事没干。然后在PhoneWindow的setContentView()中会调用installDecor()方法进行DecorView的初始化

```java
 private DecorView mDecor;
 private void installDecor() {
     if (mDecor == null) {
        mDecor = generateDecor(-1);
        mDecor.setDescendantFocusability(ViewGroup.FOCUS_AFTER_DESCENDANTS);
        mDecor.setIsRootNamespace(true);
    }
 }
 protected DecorView generateDecor(int featureId) {
   ...
    return new DecorView(context, featureId, this, getAttributes());
}
```

现在DecorView是创建好了，但是还没有跟Activity建立任何联系，也没有被绘制到界面上进行展示。那到底DecorView是什么时候绘制到屏幕上的呢？

### <span id="head6">WindowManager的addView</span>

在Activity的生命周期过程中，我们知道onCreate时界面是不可见的，要等到onResume时Activity的内容才可见。究其原因是因为onCreate中仅是创建了DecorView，并没有将其展示出来。而到onResume中，才真正去将PhoneWindow中的DecorView绘制到屏幕上。onResume是在ActivityThread的handleResumeActivity()方法开始执行的。

```java
@Override
public void handleResumeActivity(IBinder token, boolean finalStateRequest, boolean isForward,
String reason) {
    //执行Activity的onResume回调
    final ActivityClientRecord r = performResumeActivity(token, finalStateRequest, reason);
    final Activity a = r.activity;
    ...
    if (r.window == null && !a.mFinished && willBeVisible) {
        r.window = r.activity.getWindow();
        //将创建好的DecorView取出来
        View decor = r.window.getDecorView();
        decor.setVisibility(View.INVISIBLE);
        //从Activity中将WindowManager取出来，这个WindowManager是在Activity的attach方法中就初始化好了的，它是WindowManagerImpl
        ViewManager wm = a.getWindowManager();
        WindowManager.LayoutParams l = r.window.getAttributes();
        a.mDecor = decor;
        l.type = WindowManager.LayoutParams.TYPE_BASE_APPLICATION;
        l.softInputMode |= forwardBit;
        if (a.mVisibleFromClient) {
            if (!a.mWindowAdded) {
                a.mWindowAdded = true;
                //将DecorView交给WindowManagerImpl中进行添加View操作
                wm.addView(decor, l);
            } else {
                a.onWindowAttributesChanged(l);
            }
        }
    }
}
```

在handleResumeActivity最后，将DecorView交给了WindowManager的实现类WindowManagerImpl进行处理。WindowManager的addView结果有两个：

1. DecorView被渲染绘制到屏幕上显示
2. DecorView可以接收屏幕触摸事件

```java
//WindowManagerImpl.java
//WindowManagerGlobal是一个单例
private final WindowManagerGlobal mGlobal = WindowManagerGlobal.getInstance();
@Override
public void addView(@NonNull View view, @NonNull ViewGroup.LayoutParams params) {
    applyDefaultToken(params);
    mGlobal.addView(view, params, mContext.getDisplay(), mParentWindow);
}

//WindowManagerGlobal.java
public void addView(View view, ViewGroup.LayoutParams params,
            Display display, Window parentWindow) {
    ViewRootImpl root;
    root = new ViewRootImpl(view.getContext(), display);

    view.setLayoutParams(wparams);

    mViews.add(view);
    mRoots.add(root);
    mParams.add(wparams);

    // do this last because it fires off messages to start doing things
    try {
        root.setView(view, wparams, panelParentView);
    } catch (RuntimeException e) {
        ...
    }
}
```

WindowManagerImpl自己并没有执行任何操作，转手就把addView的工作交给了单例WindowManagerGlobal进行处理，这是典型的桥接模式。在addView方法中，创建出了一个非常重要的类：ViewRootImpl,它是WindowManager和DecorView之间的桥梁，View的三大流程（测量，布局，绘制）都是通过ViewRootImpl来完成的。

### <span id="head7">ViewRootImpl的setView</span>

ViewRootImpl的setView方法最终会将View添加到WindowManagerService中，下面我们来看一下具体细节：

```java
/**
* We have one child
*/
public void setView(View view, WindowManager.LayoutParams attrs, View panelParentView) {
    synchronized (this) {
        if (mView == null) {
            mView = view;
            ...
            mAdded = true;
            int res; /* = WindowManagerImpl.ADD_OKAY; */

            // Schedule the first layout -before- adding to the window
            // manager, to make sure we do the relayout before receiving
            // any other events from the system.
            //注释1 开始绘制布局那套流程
            requestLayout();
            if ((mWindowAttributes.inputFeatures
                    & WindowManager.LayoutParams.INPUT_FEATURE_NO_INPUT_CHANNEL) == 0) {
                //注释2 创建InputChannel
                mInputChannel = new InputChannel();
            }
            ...
            try {
                //注释3 添加View到WindowManagerService
                res = mWindowSession.addToDisplay(mWindow, mSeq, mWindowAttributes,
                        getHostVisibility(), mDisplay.getDisplayId(), mWinFrame,
                        mAttachInfo.mContentInsets, mAttachInfo.mStableInsets,
                        mAttachInfo.mOutsets, mAttachInfo.mDisplayCutout, mInputChannel);
            } catch (RemoteException e) {
                mAdded = false;
                mView = null;
                mAttachInfo.mRootView = null;
                mInputChannel = null;
                mFallbackEventHandler.setView(null);
                unscheduleTraversals();
                setAccessibilityFocus(null, null);
                throw new RuntimeException("Adding window failed", e);
            } finally {
                ...
            }
            ...
        }
    }
}
```

在ViewRoomImpl的setView中做了很多事情:

- 注释1 ： 通过requestLayout开始performTraversals那套测量、布局、绘制流程，这会让关联的View也执行了measure、layout、draw流程。
- 注释2 ： 创建InputChannel，在注释3中将InputChannel添加到WindowManagerService中创建socketpair（一对socket）用于发送和接收事件
- 注释3 ： 添加View到WindowManagerService，这里是通过mWindowSession来完成的，它的定义是`final IWindowSession mWindowSession;`，它其实是WindowManagerGlobal中的单例对象，初始化代码如下：

```java
public static IWindowSession getWindowSession() {
    synchronized (WindowManagerGlobal.class) {
        if (sWindowSession == null) {
            try {
                InputMethodManager imm = InputMethodManager.getInstance();
                IWindowManager windowManager = getWindowManagerService();
                sWindowSession = windowManager.openSession(
                        new IWindowSessionCallback.Stub() {
                            @Override
                            public void onAnimatorScaleChanged(float scale) {
                                ValueAnimator.setDurationScale(scale);
                            }
                        },
                        imm.getClient(), imm.getInputContext());
            } catch (RemoteException e) {
                throw e.rethrowFromSystemServer();
            }
        }
        return sWindowSession;
    }
}
```

从这里可以看出，mWindowSession是一个Binder代理对象，它引用了运行在WindowManagerService中的一个类型为Session的Binder本地对象，通过mWindowSession就向WindowManagerService中添加了一个View。mWindowSession的真正实现是在System进程中的Session对象，通过addToDisplay就将View传递给了WindowManagerService。

```java
//Session.java

final WindowManagerService mService;

@Override
public int addToDisplay(IWindow window, int seq, WindowManager.LayoutParams attrs,
        int viewVisibility, int displayId, Rect outFrame, Rect outContentInsets,
        Rect outStableInsets,
        DisplayCutout.ParcelableWrapper outDisplayCutout, InputChannel outInputChannel,
        InsetsState outInsetsState, InsetsSourceControl[] outActiveControls) {
    return mService.addWindow(this, window, seq, attrs, viewVisibility, displayId, outFrame,
            outContentInsets, outStableInsets, outDisplayCutout, outInputChannel,
            outInsetsState, outActiveControls, UserHandle.getUserId(mUid));
}
```

在System进程中，Session调用了WindowManagerService的addWindow，window被传递给了WindowManagerService，剩下的工作就全交给WindowManagerService来完成了。

### <span id="head8">触摸事件的接收</span>

当触摸事件发生后，Touch事件首先是被传入到Activity，然后被下发到布局中的ViewGroup或View。Touch事件是如何传递到Activity上的？

在ViewRootImpl中的setView方法的最后，设置了一系列输入管道。一个触摸事件的发生是由屏幕发起，然后经过驱动层一系列的优化计算通过Socket跨进程通知Android Framework层（实际是WMS），最终屏幕的触摸事件会被发送到下面的输入管道中。

```java
public void setView(View view, WindowManager.LayoutParams attrs, View panelParentView) {
    ...
    // Set up the input pipeline.
    //注释4 输入管道
    CharSequence counterSuffix = attrs.getTitle();
    mSyntheticInputStage = new SyntheticInputStage();
    InputStage viewPostImeStage = new ViewPostImeInputStage(mSyntheticInputStage);
    InputStage nativePostImeStage = new NativePostImeInputStage(viewPostImeStage,
            "aq:native-post-ime:" + counterSuffix);
    InputStage earlyPostImeStage = new EarlyPostImeInputStage(nativePostImeStage);
    InputStage imeStage = new ImeInputStage(earlyPostImeStage,
            "aq:ime:" + counterSuffix);
    InputStage viewPreImeStage = new ViewPreImeInputStage(imeStage);
    InputStage nativePreImeStage = new NativePreImeInputStage(viewPreImeStage,
            "aq:native-pre-ime:" + counterSuffix);
}
```

这些输入管道实际是一个链表结构，当某个触摸事件到达其中的ViewPostImeInputStage时，会经过onProcess来处理

```java
final class ViewPostImeInputStage extends InputStage {
    ...
    @Override
    protected int onProcess(QueuedInputEvent q) {
        if (q.mEvent instanceof KeyEvent) {
            return processKeyEvent(q);
        } else {
            final int source = q.mEvent.getSource();
            if ((source & InputDevice.SOURCE_CLASS_POINTER) != 0) {
                //注意，事件将经过这里
                return processPointerEvent(q);
            } else if ((source & InputDevice.SOURCE_CLASS_TRACKBALL) != 0) {
                return processTrackballEvent(q);
            } else {
                return processGenericMotionEvent(q);
            }
        }
    }
    private int processPointerEvent(QueuedInputEvent q) {
        final MotionEvent event = (MotionEvent)q.mEvent;
        ...
        //交给View处理
        boolean handled = mView.dispatchPointerEvent(event);
        ...
        return handled ? FINISH_HANDLED : FORWARD;
    }
    ...
}
```

最终调用到了mView的dispatchPointerEvent，而这个mView其实是PhoneWindow中的DecorView，也就是说dispatchPointerEvent是在DecorView中去追溯源码，但是DecorView本身是没有覆写这个方法的，它定义在View.java里面

```java
//View.java
public final boolean dispatchPointerEvent(MotionEvent event) {
    if (event.isTouchEvent()) {
        return dispatchTouchEvent(event);
    } else {
        return dispatchGenericMotionEvent(event);
    }
}

//DecorView.java
 private PhoneWindow mWindow;
@Override
public boolean dispatchTouchEvent(MotionEvent ev) {
    final Window.Callback cb = mWindow.getCallback();
    return cb != null && !mWindow.isDestroyed() && mFeatureId < 0
            ? cb.dispatchTouchEvent(ev) : super.dispatchTouchEvent(ev);
}
```

这里会使用到mWindow（也就是PhoneWindow）的Callback，这个Callback是在Activity的attach中进行赋值的，Activity本身就是这个Callback。所以这里cb是不为空的，事件就被传递到了Activity的dispatchTouchEvent中。

```java
//Activity.java
public boolean dispatchTouchEvent(MotionEvent ev) {
    if (ev.getAction() == MotionEvent.ACTION_DOWN) {
        onUserInteraction();
    }
    if (getWindow().superDispatchTouchEvent(ev)) {
        return true;
    }
    return onTouchEvent(ev);
}

//有down事件来的时候，会通知这里，这是个空方法，用户需要可以自己覆写
public void onUserInteraction() {
}
```

在Activity的dispatchTouchEvent中，将事件传递给了Window，在其superDispatchTouchEvent中进行处理

```java
//PhoneWindow.java
@Override
public boolean superDispatchTouchEvent(MotionEvent event) {
    return mDecor.superDispatchTouchEvent(event);
}

//DecorView.java
public boolean superDispatchTouchEvent(MotionEvent event) {
    return super.dispatchTouchEvent(event);
}
```

Touch事件从PhoneWindow中又交给DecorView来进行处理，DecorView本身是一个FrameLayout，所以它的dispatchTouchEvent是在ViewGroup中进行实现的，也就是开始将事件层层传递给内部的子View中了。

触摸事件到达ViewRootImpl中后，传递给PhoneWindow中的DecorView，再传递给Activity，Activity又将其传递给PhoneWindow，PhoneWindow最终交给顶级View--DecorView，由DecorView进行事件分发。

### <span id="head9">小结</span>

从表面上看Activity参与度比较低，大部分View的添加操作都被封装到Window中进行实现，而Activity相当于是提供给开发人员的一个管理类，通过它能更简单地实现Window和View的操作逻辑。

- 一个Activity中有一个Window，也就是PhoneWindow对象，在PhoneWindow中有一个DecorView，在setContentView中会将layout填充到此DecorView中
- 一个应用进程中只有一个WindowManagerGlobal对象，单例
- 每一个PhoneWindow对应一个ViewRootImpl对象
- WindowManagerGlobal通过ViewRootImpl的setView方法，完成Window的添加过程
- ViewRootImpl的setView方法中主要完成两件事情：View渲染以及接收触摸事件
- Dialog和Toast都有自己的Window，而PopupWindow没有

### <span id="head10">参考</span>

- https://mp.weixin.qq.com/s/oFVBrIAUwD0wnlSfm-95bQ
- https://mp.weixin.qq.com/s/-5lyASIaSFV6wG3wfMS9Yg
- Android 开发艺术探索
