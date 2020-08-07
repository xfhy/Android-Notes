
## 一.背景

> 公司业务上需要用到换肤.为了不重复造轮子,并且快速实现需求,并且求稳,,于是到Github上找了一个star数比较多的换肤框架-`Android-skin-support`(一款用心去做的Android 换肤框架, 极低的学习成本, 极好的用户体验. 一行代码就可以实现换肤, 你值得拥有!!!).  简单了解之后,可以快速上手,并且侵入性很低.作为一名合格的程序员,当然需要了解其背后的原理才能算是真正的灵活运用.并且有bug的话,也能很快定位是哪里的问题,这对于公司的项目后期维护是非常有用的. 这里只讲原理,具体的使用方式还是去看官方的文档吧,源码地址:https://github.com/ximsfei/Android-skin-support

## 二.AppCompatActivity实现

在开始之前,先来点预备知识吧,看看AppCompatActivity的实现,这对于之后的理解框架原理非常有用.

```java
public class AppCompatActivity extends FragmentActivity implements AppCompatCallback,
        TaskStackBuilder.SupportParentable, ActionBarDrawerToggle.DelegateProvider {
             @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        final AppCompatDelegate delegate = getDelegate();
        delegate.installViewFactory();
        delegate.onCreate(savedInstanceState);
        if (delegate.applyDayNight() && mThemeId != 0) {
            // If DayNight has been applied, we need to re-apply the theme for
            // the changes to take effect. On API 23+, we should bypass
            // setTheme(), which will no-op if the theme ID is identical to the
            // current theme ID.
            if (Build.VERSION.SDK_INT >= 23) {
                onApplyThemeResource(getTheme(), mThemeId, false);
            } else {
                setTheme(mThemeId);
            }
        }
        super.onCreate(savedInstanceState);
    }
    @Override
    protected void onPostResume() {
        super.onPostResume();
        getDelegate().onPostResume();
    }

    @Override
    protected void onStart() {
        super.onStart();
        getDelegate().onStart();
    }

    @Override
    protected void onStop() {
        super.onStop();
        getDelegate().onStop();
    }
    @Override
    protected void onDestroy() {
        super.onDestroy();
        getDelegate().onDestroy();
    }

    @Override
    protected void onTitleChanged(CharSequence title, int color) {
        super.onTitleChanged(title, color);
        getDelegate().setTitle(title);
    }
    ......
}
```
我们看到有一个AppCompatDelegate,这玩意儿有什么用呢?查阅资料得知,它是Activity的委托,AppCompatActivity将大部分生命周期都委托给了AppCompatDelegate,这点可从上面的源码中可以看出.接着我们查看AppCompatDelegate的源码,发现其类注释也是这么写的.


接下来,我们看看AppCompatDelegate的创建

 AppCompatActivity.java
```java
    /**
     * @return The {@link AppCompatDelegate} being used by this Activity.
     */
    @NonNull
    public AppCompatDelegate getDelegate() {
        if (mDelegate == null) {
            mDelegate = AppCompatDelegate.create(this, this);
        }
        return mDelegate;
    }
```

AppCompatDelegate.java
```java
public static AppCompatDelegate create(Activity activity, AppCompatCallback callback) {
        return create(activity, activity.getWindow(), callback);
    }
     private static AppCompatDelegate create(Context context, Window window,
            AppCompatCallback callback) {
        if (Build.VERSION.SDK_INT >= 24) {
            return new AppCompatDelegateImplN(context, window, callback);
        } else if (Build.VERSION.SDK_INT >= 23) {
            return new AppCompatDelegateImplV23(context, window, callback);
        } else if (Build.VERSION.SDK_INT >= 14) {
            return new AppCompatDelegateImplV14(context, window, callback);
        } else if (Build.VERSION.SDK_INT >= 11) {
            return new AppCompatDelegateImplV11(context, window, callback);
        } else {
            return new AppCompatDelegateImplV9(context, window, callback);
        }
    }
```

不同的API版本号使用的AppCompatDelegate是不一样的,下面是类的继承关系图
![](http://olg7c0d2n.bkt.clouddn.com/18-7-27/16681656.jpg)

因为上面的`delegate.installViewFactory();`其实是在AppCompatDelegateImplV9里面实现的.看一下源码.

AppCompatDelegateImplV9.java
```java
@Override
    public void installViewFactory() {
        LayoutInflater layoutInflater = LayoutInflater.from(mContext);
        if (layoutInflater.getFactory() == null) {
            LayoutInflaterCompat.setFactory2(layoutInflater, this);
        } else {
            if (!(layoutInflater.getFactory2() instanceof AppCompatDelegateImplV9)) {
                Log.i(TAG, "The Activity's LayoutInflater already has a Factory installed"
                        + " so we can not install AppCompat's");
            }
        }
    }
```

`LayoutInflaterCompat.setFactory2(layoutInflater, this);`最终是调用的LayoutInflater的`setFactory2()`方法,看看实现

```java
/**
* Like {@link #setFactory}, but allows you to set a {@link Factory2}
* interface.
*/
public void setFactory2(Factory2 factory) {
    if (mFactorySet) {
        throw new IllegalStateException("A factory has already been set on this LayoutInflater");
    }
    if (factory == null) {
        throw new NullPointerException("Given factory can not be null");
    }
    mFactorySet = true;
    if (mFactory == null) {
        mFactory = mFactory2 = factory;
    } else {
        mFactory = mFactory2 = new FactoryMerger(factory, factory, mFactory, mFactory2);
    }
}
```

这里有个小细节,Factory2只能被设置一次,设置完成后mFactorySet属性就为true,下一次设置时被直接抛异常.
那么Factory2有什么用呢?看看其实现

```java
public interface Factory2 extends Factory {
        /**
         * Version of {@link #onCreateView(String, Context, AttributeSet)}
         * that also supplies the parent that the view created view will be
         * placed in.
         *
         * @param parent The parent that the created view will be placed
         * in; <em>note that this may be null</em>.
         * @param name Tag name to be inflated.
         * @param context The context the view is being created in.
         * @param attrs Inflation attributes as specified in XML file.
         *
         * @return View Newly created view. Return null for the default
         *         behavior.
         */
        public View onCreateView(View parent, String name, Context context, AttributeSet attrs);
    }
```
它是一个接口,只有一个方法,看起来是用来创建View的.到达是不是呢?答案稍后揭晓.

AppCompatActivity设置了一个委托,并给LayoutInflater设置了一个mFactory2.现在知道这个就够了.

## 三.Android创建View全过程解析

下面先看看Android是如何根据xml布局创建一个View的

平时我们最常使用的Activity中的setContentView()设置布局ID,看看Activity中的实现,
```java
public void setContentView(@LayoutRes int layoutResID) {
        getWindow().setContentView(layoutResID);
        initWindowDecorActionBar();
    }
```

调用的是Window中的setContentView(),而Window只有一个实现类,就是PhoneWindow.看看setContentView()实现
```java
@Override
    public void setContentView(int layoutResID) {
        ...
        if (hasFeature(FEATURE_CONTENT_TRANSITIONS)) {
            final Scene newScene = Scene.getSceneForLayout(mContentParent, layoutResID,
                    getContext());
            transitionTo(newScene);
        } else {
            mLayoutInflater.inflate(layoutResID, mContentParent);
        }
        ...
    }
```

看到了今天的主角mLayoutInflater,mLayoutInflater是在PhoneWindow的构造方法中初始化的.用mLayoutInflater去加载这个布局(layoutResID).点进去看看实现

LayoutInflater.java
```java
public View inflate(@LayoutRes int resource, @Nullable ViewGroup root) {
        return inflate(resource, root, root != null);
    }
public View inflate(@LayoutRes int resource, @Nullable ViewGroup root, boolean attachToRoot) {
        final Resources res = getContext().getResources();
        if (DEBUG) {
            Log.d(TAG, "INFLATING from resource: \"" + res.getResourceName(resource) + "\" ("
                    + Integer.toHexString(resource) + ")");
        }

        final XmlResourceParser parser = res.getLayout(resource);
        try {
            return inflate(parser, root, attachToRoot);
        } finally {
            parser.close();
        }
    }

```
可以看到将用布局创建了一个Xml解析器,然后进行解析


```java
public View inflate(XmlPullParser parser, @Nullable ViewGroup root, boolean attachToRoot) {
    // Temp is the root view that was found in the xml
    final View temp = createViewFromTag(root, name, inflaterContext, attrs);

    // Inflate all children under temp against its context.
    rInflateChildren(parser, temp, attrs, true);
    ...
}

```
其实里面我觉得就只有2句关键代码,就是去根据xml写的东西去构建View嘛.`rInflateChildren()`最后还是会去调用`createViewFromTag()`方法,这里是为了先创建出rootView,然后将子View添加进rootView.

来看看createViewFromTag()的实现

```java
View createViewFromTag(View parent, String name, Context context, AttributeSet attrs,
            boolean ignoreThemeAttr) {
        ...
        try {
            View view;
            if (mFactory2 != null) {
                view = mFactory2.onCreateView(parent, name, context, attrs);
            } else if (mFactory != null) {
                view = mFactory.onCreateView(name, context, attrs);
            } else {
                view = null;
            }

            if (view == null && mPrivateFactory != null) {
                view = mPrivateFactory.onCreateView(parent, name, context, attrs);
            }

            if (view == null) {
                final Object lastContext = mConstructorArgs[0];
                mConstructorArgs[0] = context;
                try {
                    if (-1 == name.indexOf('.')) {
                        view = onCreateView(parent, name, attrs);
                    } else {
                        view = createView(name, null, attrs);
                    }
                } finally {
                    mConstructorArgs[0] = lastContext;
                }
            }
            ...
            return view;
    }
```

可以看到**如果mFactory2不为空的话,那么就会调用mFactory2去创建View(mFactory2.onCreateView(parent, name, context, attrs)) .** 这句结论很重要.前面的答案已揭晓.如果设置了mFactory2就会用mFactory2去创建View.而mFactory2在上面的`AppCompatDelegateImplV9`的`installViewFactory()`中已设置好了的,其实mFactory2就是AppCompatDelegateImplV9.

来看看createView()的具体实现
```java
@Override
    public View createView(View parent, final String name, @NonNull Context context,
            @NonNull AttributeSet attrs) {
        if (mAppCompatViewInflater == null) {
            mAppCompatViewInflater = new AppCompatViewInflater();
        }

        boolean inheritContext = false;
        if (IS_PRE_LOLLIPOP) {
            inheritContext = (attrs instanceof XmlPullParser)
                    // If we have a XmlPullParser, we can detect where we are in the layout
                    ? ((XmlPullParser) attrs).getDepth() > 1
                    // Otherwise we have to use the old heuristic
                    : shouldInheritContext((ViewParent) parent);
        }

        return mAppCompatViewInflater.createView(parent, name, context, attrs, inheritContext,
                IS_PRE_LOLLIPOP, /* Only read android:theme pre-L (L+ handles this anyway) */
                true, /* Read read app:theme as a fallback at all times for legacy reasons */
                VectorEnabledTintResources.shouldBeUsed() /* Only tint wrap the context if enabled */
        );
    }
```
可以看到,最后是调用的AppCompatViewInflater的对象的`createView()`去创建View.我感觉AppCompatViewInflater就是专门用来创建View的,面向对象的五大原则之一--单一职责原则.

AppCompatViewInflater类非常重要,先来看看上面提到的`createView()`方法的源码:
```java
public final View createView(View parent, final String name, @NonNull Context context,
            @NonNull AttributeSet attrs, boolean inheritContext,
            boolean readAndroidTheme, boolean readAppTheme, boolean wrapContext) {
        ......
        View view = null;

        // We need to 'inject' our tint aware Views in place of the standard framework versions
        switch (name) {
            case "TextView":
                view = new AppCompatTextView(context, attrs);
                break;
            case "ImageView":
                view = new AppCompatImageView(context, attrs);
                break;
            case "Button":
                view = new AppCompatButton(context, attrs);
                break;
            case "EditText":
                view = new AppCompatEditText(context, attrs);
                break;
            case "Spinner":
                view = new AppCompatSpinner(context, attrs);
                break;
            case "ImageButton":
                view = new AppCompatImageButton(context, attrs);
                break;
            case "CheckBox":
                view = new AppCompatCheckBox(context, attrs);
                break;
            case "RadioButton":
                view = new AppCompatRadioButton(context, attrs);
                break;
            case "CheckedTextView":
                view = new AppCompatCheckedTextView(context, attrs);
                break;
            case "AutoCompleteTextView":
                view = new AppCompatAutoCompleteTextView(context, attrs);
                break;
            case "MultiAutoCompleteTextView":
                view = new AppCompatMultiAutoCompleteTextView(context, attrs);
                break;
            case "RatingBar":
                view = new AppCompatRatingBar(context, attrs);
                break;
            case "SeekBar":
                view = new AppCompatSeekBar(context, attrs);
                break;
        }

        if (view == null && originalContext != context) {
            // If the original context does not equal our themed context, then we need to manually
            // inflate it using the name so that android:theme takes effect.
            view = createViewFromTag(context, name, attrs);
        }

        if (view != null) {
            // If we have created a view, check its android:onClick
            checkOnClickListener(view, attrs);
        }

        return view;
    }
```
可以看到如果在xml中写了一个`TextView`控件,其实是通过我们写的控件名称判断是什么控件,然后去new的方式创建出来的,并且new的不是TextView,而是`AppCompatTextView`.其他的一些系统控件也是这么new出来的.

但是,有个问题,如果我在xml布局中不是写的这些控件(比如RecyclerView,自定义控件等),那么怎么创建view呢?注意到代码中如果执行完switch块之后view为空(说明不是上面列的那些控件),调用了`createViewFromTag()`方法.来看看实现

```java

private static final String[] sClassPrefixList = {
            "android.widget.",
            "android.view.",
            "android.webkit."
};

private View createViewFromTag(Context context, String name, AttributeSet attrs) {
        if (name.equals("view")) {
            name = attrs.getAttributeValue(null, "class");
        }

        try {
            mConstructorArgs[0] = context;
            mConstructorArgs[1] = attrs;

            //这里判断一下name(即在xml中写的控件名称)中是否含有'.'
            //如果没有那么肯定就是系统控件(比如ProgressBar,在布局中是不需要加ProgressBar的具体包名的)
            //如果有那么就是自定义控件,或者是系统的控件(比如android.support.v7.widget.SwitchCompat)
            if (-1 == name.indexOf('.')) {
                for (int i = 0; i < sClassPrefixList.length; i++) {
                    final View view = createView(context, name, sClassPrefixList[i]);
                    if (view != null) {
                        return view;
                    }
                }
                return null;
            } else {
                return createView(context, name, null);
            }
        } catch (Exception e) {
            // We do not want to catch these, lets return null and let the actual LayoutInflater
            // try
            return null;
        } finally {
            // Don't retain references on context.
            mConstructorArgs[0] = null;
            mConstructorArgs[1] = null;
        }
    }
```

这里比较有意思,首先是判断一下是否是系统控件,怎么判断呢?通过判断控件名称中是否包含'.'来判断.系统控件在xml布局中声明时是不需要加具体包名的,比如ProgressBar,所以没有'.'的肯定是系统控件.那么有'.'的就是自定义控件或者一些特殊的系统控件了(比如android.support.v7.widget.SwitchCompat).

有个小疑问?为什么系统控件可以在布局中声明时不加包名,而自定义控件必须要加包名呢?

<img src="https://ss0.bdstatic.com/94oJfD_bAAcT8t7mm9GUKT-xh_/timg?image&quality=100&size=b4000_4000&sec=1532670081&di=a57c80745a7af4517f0e30a60564789e&src=http://07.imgmini.eastday.com/mobile/20171017/20171017045451_1d939f2d4f0edad71f85f1afb779ff88_4.jpeg" height=100></img>

其实是系统的控件大多放在sClassPrefixList定义的这些包名下,所以待会儿可以通过拼接的方式将控件的位置找到.随便举个例子,我们来看看哪些系统控件在`android.widget.`包下面
![](http://olg7c0d2n.bkt.clouddn.com/18-7-27/92621264.jpg)

源码中创建系统控件和非系统控件分开去创建.其实方法都是同一个,只是一个传了前缀,一个没有传前缀.来看看创建方法实现
```java

private static final Class<?>[] sConstructorSignature = new Class[]{
            Context.class, AttributeSet.class};

private static final Map<String, Constructor<? extends View>> sConstructorMap
            = new ArrayMap<>();

private View createView(Context context, String name, String prefix)
            throws ClassNotFoundException, InflateException {
        //这里的sConstructorMap是用来做缓存的,如果之前已经创建,则会将构造方法缓存起来,下次直接用
        Constructor<? extends View> constructor = sConstructorMap.get(name);

        try {
            if (constructor == null) {
                // Class not found in the cache, see if it's real, and try to add it
                //通过classLoader去寻找该class,这里的classLoader其实是PathClassLoader
                //看到没? (prefix + name)这种直接将前缀与名称拼接的方式就可以将View的位置拼接出来
                //然后其他的全类名的View就不需要拼接前缀
                Class<? extends View> clazz = context.getClassLoader().loadClass(
                        prefix != null ? (prefix + name) : name).asSubclass(View.class);
                //获取构造方法
                constructor = clazz.getConstructor(sConstructorSignature);
                //缓存构造方法
                sConstructorMap.put(name, constructor);
            }
            //设置构造方法可访问
            constructor.setAccessible(true);
            //通过构造方法new一个View对象出来
            return constructor.newInstance(mConstructorArgs);
        } catch (Exception e) {
            // We do not want to catch these, lets return null and let the actual LayoutInflater
            // try
            return null;
        }
    }
```
其实这个创建View就是利用ClassLoader去寻找这个类的class,然后获取其`{
            Context.class, AttributeSet.class}`这个构造方法,然后通过反射将View创建出来.具体逻辑在代码中已标明注释.

至此,Android的控件加载方式已全部剖析完毕.

其中,有一个小细节,刚刚为了流程顺畅没有在上面说到,上面有一段构建View(根据控件名称创建AppCompatXX控件)的代码如下:
```java
switch (name) {
    case "TextView":
        view = new AppCompatTextView(context, attrs);
        break;
    case "ImageView":
        view = new AppCompatImageView(context, attrs);
        break;
    case "Button":
        view = new AppCompatButton(context, attrs);
        break;
}
```

我们来随便看一下控件的源码,比如`AppCompatTextView`,其他的AppCompatXX控件实现都是差不多的.

```java
public class AppCompatTextView extends TextView implements TintableBackgroundView,
        AutoSizeableTextView {

    //这2个是关键类
    private final AppCompatBackgroundHelper mBackgroundTintHelper;
    private final AppCompatTextHelper mTextHelper;

    public AppCompatTextView(Context context) {
        this(context, null);
    }

    public AppCompatTextView(Context context, AttributeSet attrs) {
        this(context, attrs, android.R.attr.textViewStyle);
    }

    public AppCompatTextView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(TintContextWrapper.wrap(context), attrs, defStyleAttr);

        mBackgroundTintHelper = new AppCompatBackgroundHelper(this);
        mBackgroundTintHelper.loadFromAttributes(attrs, defStyleAttr);

        mTextHelper = AppCompatTextHelper.create(this);
        mTextHelper.loadFromAttributes(attrs, defStyleAttr);
        mTextHelper.applyCompoundDrawablesTints();
    }
    ......


class AppCompatBackgroundHelper {
    ......
    void loadFromAttributes(AttributeSet attrs, int defStyleAttr) {
        TintTypedArray a = TintTypedArray.obtainStyledAttributes(mView.getContext(), attrs,
                R.styleable.ViewBackgroundHelper, defStyleAttr, 0);
        try {
            if (a.hasValue(R.styleable.ViewBackgroundHelper_android_background)) {
                //获取android:background 背景的资源id
                mBackgroundResId = a.getResourceId(
                        R.styleable.ViewBackgroundHelper_android_background, -1);
                ColorStateList tint = mDrawableManager
                        .getTintList(mView.getContext(), mBackgroundResId);
                if (tint != null) {
                    setInternalBackgroundTint(tint);
                }
            }
            if (a.hasValue(R.styleable.ViewBackgroundHelper_backgroundTint)) {
                //获取android:backgroundTint
                ViewCompat.setBackgroundTintList(mView,
                        a.getColorStateList(R.styleable.ViewBackgroundHelper_backgroundTint));
            }
            if (a.hasValue(R.styleable.ViewBackgroundHelper_backgroundTintMode)) {
                //获取android:backgroundTintMode
                ViewCompat.setBackgroundTintMode(mView,
                        DrawableUtils.parseTintMode(
                                a.getInt(R.styleable.ViewBackgroundHelper_backgroundTintMode, -1),
                                null));
            }
        } finally {
            a.recycle();
        }
    }
}

class AppCompatTextHelper {
    ......
    @SuppressLint("NewApi")
    void loadFromAttributes(AttributeSet attrs, int defStyleAttr) {
        final Context context = mView.getContext();
        final AppCompatDrawableManager drawableManager = AppCompatDrawableManager.get();

        // First read the TextAppearance style id
        TintTypedArray a = TintTypedArray.obtainStyledAttributes(context, attrs,
                R.styleable.AppCompatTextHelper, defStyleAttr, 0);
        final int ap = a.getResourceId(R.styleable.AppCompatTextHelper_android_textAppearance, -1);
        // Now read the compound drawable and grab any tints
        if (a.hasValue(R.styleable.AppCompatTextHelper_android_drawableLeft)) {
            mDrawableLeftTint = createTintInfo(context, drawableManager,
                    a.getResourceId(R.styleable.AppCompatTextHelper_android_drawableLeft, 0));
        }
        if (a.hasValue(R.styleable.AppCompatTextHelper_android_drawableTop)) {
            mDrawableTopTint = createTintInfo(context, drawableManager,
                    a.getResourceId(R.styleable.AppCompatTextHelper_android_drawableTop, 0));
        }
        if (a.hasValue(R.styleable.AppCompatTextHelper_android_drawableRight)) {
            mDrawableRightTint = createTintInfo(context, drawableManager,
                    a.getResourceId(R.styleable.AppCompatTextHelper_android_drawableRight, 0));
        }
        if (a.hasValue(R.styleable.AppCompatTextHelper_android_drawableBottom)) {
            mDrawableBottomTint = createTintInfo(context, drawableManager,
                    a.getResourceId(R.styleable.AppCompatTextHelper_android_drawableBottom, 0));
        }
        a.recycle();

        // PasswordTransformationMethod wipes out all other TransformationMethod instances
        // in TextView's constructor, so we should only set a new transformation method
        // if we don't have a PasswordTransformationMethod currently...
        final boolean hasPwdTm =
                mView.getTransformationMethod() instanceof PasswordTransformationMethod;
        boolean allCaps = false;
        boolean allCapsSet = false;
        ColorStateList textColor = null;
        ColorStateList textColorHint = null;
        ColorStateList textColorLink = null;

        // First check TextAppearance's textAllCaps value
        if (ap != -1) {
            a = TintTypedArray.obtainStyledAttributes(context, ap, R.styleable.TextAppearance);
            if (!hasPwdTm && a.hasValue(R.styleable.TextAppearance_textAllCaps)) {
                allCapsSet = true;
                allCaps = a.getBoolean(R.styleable.TextAppearance_textAllCaps, false);
            }

            updateTypefaceAndStyle(context, a);
            if (Build.VERSION.SDK_INT < 23) {
                // If we're running on < API 23, the text color may contain theme references
                // so let's re-set using our own inflater
                if (a.hasValue(R.styleable.TextAppearance_android_textColor)) {
                    textColor = a.getColorStateList(R.styleable.TextAppearance_android_textColor);
                }
                if (a.hasValue(R.styleable.TextAppearance_android_textColorHint)) {
                    textColorHint = a.getColorStateList(
                            R.styleable.TextAppearance_android_textColorHint);
                }
                if (a.hasValue(R.styleable.TextAppearance_android_textColorLink)) {
                    textColorLink = a.getColorStateList(
                            R.styleable.TextAppearance_android_textColorLink);
                }
            }
            a.recycle();
        }

        // Now read the style's values
        a = TintTypedArray.obtainStyledAttributes(context, attrs, R.styleable.TextAppearance,
                defStyleAttr, 0);
        if (!hasPwdTm && a.hasValue(R.styleable.TextAppearance_textAllCaps)) {
            allCapsSet = true;
            allCaps = a.getBoolean(R.styleable.TextAppearance_textAllCaps, false);
        }
        if (Build.VERSION.SDK_INT < 23) {
            // If we're running on < API 23, the text color may contain theme references
            // so let's re-set using our own inflater
            if (a.hasValue(R.styleable.TextAppearance_android_textColor)) {
                textColor = a.getColorStateList(R.styleable.TextAppearance_android_textColor);
            }
            if (a.hasValue(R.styleable.TextAppearance_android_textColorHint)) {
                textColorHint = a.getColorStateList(
                        R.styleable.TextAppearance_android_textColorHint);
            }
            if (a.hasValue(R.styleable.TextAppearance_android_textColorLink)) {
                textColorLink = a.getColorStateList(
                        R.styleable.TextAppearance_android_textColorLink);
            }
        }

        updateTypefaceAndStyle(context, a);
        a.recycle();

        if (textColor != null) {
            mView.setTextColor(textColor);
        }
        if (textColorHint != null) {
            mView.setHintTextColor(textColorHint);
        }
        if (textColorLink != null) {
            mView.setLinkTextColor(textColorLink);
        }
        if (!hasPwdTm && allCapsSet) {
            setAllCaps(allCaps);
        }
        if (mFontTypeface != null) {
            mView.setTypeface(mFontTypeface, mStyle);
        }

        mAutoSizeTextHelper.loadFromAttributes(attrs, defStyleAttr);

        if (PLATFORM_SUPPORTS_AUTOSIZE) {
            // Delegate auto-size functionality to the framework implementation.
            if (mAutoSizeTextHelper.getAutoSizeTextType()
                    != TextViewCompat.AUTO_SIZE_TEXT_TYPE_NONE) {
                final int[] autoSizeTextSizesInPx =
                        mAutoSizeTextHelper.getAutoSizeTextAvailableSizes();
                if (autoSizeTextSizesInPx.length > 0) {
                    if (mView.getAutoSizeStepGranularity() != AppCompatTextViewAutoSizeHelper
                            .UNSET_AUTO_SIZE_UNIFORM_CONFIGURATION_VALUE) {
                        // Configured with granularity, preserve details.
                        mView.setAutoSizeTextTypeUniformWithConfiguration(
                                mAutoSizeTextHelper.getAutoSizeMinTextSize(),
                                mAutoSizeTextHelper.getAutoSizeMaxTextSize(),
                                mAutoSizeTextHelper.getAutoSizeStepGranularity(),
                                TypedValue.COMPLEX_UNIT_PX);
                    } else {
                        mView.setAutoSizeTextTypeUniformWithPresetSizes(
                                autoSizeTextSizesInPx, TypedValue.COMPLEX_UNIT_PX);
                    }
                }
            }
        }
    }

```

这里的这里,不得不说Android源码真是让在下佩服的五体投地,又一次体现了单一职责原则.你问我在哪里?  系统将背景相关的交给AppCompatBackgroundHelper去处理,将文字相关的交给AppCompatTextHelper处理.

AppCompatBackgroundHelper和AppCompatTextHelper拿到了xml中定义的属性的值之后,将其值赋值给控件.就是这么简单.

看到了这里,预备知识就介绍得差不多了,看了半天,你说的这些乱七八糟的东西与我的换肤有个毛关系啊?

<img src="http://olg7c0d2n.bkt.clouddn.com/18-7-27/77497119.jpg" width=100px height=100px></img>

请各位看官放下手中的砖头,且听贫道细细道来.

## 四.换肤原理详细解析

### 1.上文预备知识与换肤的关系

源码中可以通过拦截View创建过程, 替换一些基础的组件(比如`TextView -> AppCompatTextView`), 然后对一些特殊的属性(比如:background, textColor) 做处理, 那我们为什么不能将这种思想拿到换肤框架中来使用呢?我擦,一语惊醒梦中人啊,老哥.我们也可以搞一个委托啊,我们也可以搞一个类似于AppCompatViewInflater的控件加载器啊,我们也可以设置mFactory2啊,相当于创建View的过程由我们接手.既然我们接手了,那岂不是对所有控件都可以为所欲为????那是当然啦.  既然都可以为所欲为了,那换个肤算什么,so easy.

### 2.源码一，创建控件全过程

```java
SkinCompatManager.withoutActivity(application)
                .addInflater(new SkinAppCompatViewInflater());
```

首先我们从库的初始化处着手,这里将Application传入,又添加了一个SkinAppCompatViewInflater,SkinAppCompatViewInflater其实就是用来创建View的,和系统的AppCompatViewInflater差不多.我们来看看`withoutActivity(application)`做了什么.

```java
//SkinCompatManager.java
public static SkinCompatManager withoutActivity(Application application) {
    init(application);
    SkinActivityLifecycle.init(application);
    return sInstance;
}

//SkinActivityLifecycle.java
public static SkinActivityLifecycle init(Application application) {
    if (sInstance == null) {
        synchronized (SkinActivityLifecycle.class) {
            if (sInstance == null) {
                sInstance = new SkinActivityLifecycle(application);
            }
        }
    }
    return sInstance;
}
private SkinActivityLifecycle(Application application) {
    //就是这里,注册了ActivityLifecycleCallbacks,可以监听所有Activity的生命周期
    application.registerActivityLifecycleCallbacks(this);
    //这个方法稍后看
    installLayoutFactory(application);
    SkinCompatManager.getInstance().addObserver(getObserver(application));
}
```

可以看到,初始化时在SkinActivityLifecycle中其实就注册了ActivityLifecycleCallbacks,现在我们可以监听app所有Activity的生命周期.

来看看SkinActivityLifecycle中监听到Activity的onCreate()方法时干了什么
```java
@Override
public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
    //判断是否需要换肤  这个可以外部初始化时控制
    if (isContextSkinEnable(activity)) {
        //在Activity创建的时候,直接将Factory设置成三方库里面的
        installLayoutFactory(activity);

        //更新状态栏颜色
        updateStatusBarColor(activity);
        //更新window背景颜色
        updateWindowBackground(activity);
        if (activity instanceof SkinCompatSupportable) {
            ((SkinCompatSupportable) activity).applySkin();
        }
    }
}

/**
    * 设置Factory(创建View的工厂)
    */
private void installLayoutFactory(Context context) {
    LayoutInflater layoutInflater = LayoutInflater.from(context);
    try {
        //setFactory只能调用一次,用于设置Factory(创建View),  设置了Factory了mFactorySet就会是true
        //如果需要重新设置Factory,则需要先将mFactorySet设置为false,不然系统判断到mFactorySet是true则会抛异常.
        //这里使用自己构建的Factory去创建View,在创建View时当然也就可以控制它的背景或者文字颜色.
        //(在这里之前需要知道哪些控件需要换肤,其中一部分是继承自三方库的控件,这些控件是实现了SkinCompatSupportable接口的,可以很方便的控制.
        // 还有一部分是系统的控件,在创建时直接创建三方库中的控件(比如View就创建SkinCompatView).
        // 在设置系统控件的背景颜色和文字颜色时,直接从三方库缓存颜色中取值,然后进行设置.)
        Field field = LayoutInflater.class.getDeclaredField("mFactorySet");
        field.setAccessible(true);
        field.setBoolean(layoutInflater, false);
        LayoutInflaterCompat.setFactory(layoutInflater, getSkinDelegate(context));
    } catch (NoSuchFieldException | IllegalArgumentException | IllegalAccessException e) {
        e.printStackTrace();
    }
}
```
在我们的Activity创建的时候,首先判断一下是否需要换肤,需要换肤才去搞.

我们重点看看`installLayoutFactory()`方法,在上面的预备知识中说了`mFactory`只能设置一次,不然就要抛异常,所以需要先利用发射将`mFactorySet`的值设置为false才不会抛异常.然后才能`setFactory()`.

下面我们来看看`setFactory()`的第二个参数创建过程,第二个参数其实是一个创建View的工厂.
```java
//SkinActivityLifecycle.java
private SkinCompatDelegate getSkinDelegate(Context context) {
    if (mSkinDelegateMap == null) {
        mSkinDelegateMap = new WeakHashMap<>();
    }

    SkinCompatDelegate mSkinDelegate = mSkinDelegateMap.get(context);
    if (mSkinDelegate == null) {
        mSkinDelegate = SkinCompatDelegate.create(context);
        mSkinDelegateMap.put(context, mSkinDelegate);
    }
    return mSkinDelegate;
}

//SkinCompatDelegate.java
public class SkinCompatDelegate implements LayoutInflaterFactory {
    private final Context mContext;
    //主角  在这里 在这里!!!
    private SkinCompatViewInflater mSkinCompatViewInflater;
    private List<WeakReference<SkinCompatSupportable>> mSkinHelpers = new ArrayList<>();

    private SkinCompatDelegate(Context context) {
        mContext = context;
    }

    @Override
    public View onCreateView(View parent, String name, Context context, AttributeSet attrs) {
        View view = createView(parent, name, context, attrs);

        if (view == null) {
            return null;
        }
        if (view instanceof SkinCompatSupportable) {
            mSkinHelpers.add(new WeakReference<>((SkinCompatSupportable) view));
        }

        return view;
    }

    public View createView(View parent, final String name, @NonNull Context context,
                           @NonNull AttributeSet attrs) {
        if (mSkinCompatViewInflater == null) {
            mSkinCompatViewInflater = new SkinCompatViewInflater();
        }

        List<SkinWrapper> wrapperList = SkinCompatManager.getInstance().getWrappers();
        for (SkinWrapper wrapper : wrapperList) {
            Context wrappedContext = wrapper.wrapContext(mContext, parent, attrs);
            if (wrappedContext != null) {
                context = wrappedContext;
            }
        }
        return mSkinCompatViewInflater.createView(parent, name, context, attrs);
    }

    public static SkinCompatDelegate create(Context context) {
        return new SkinCompatDelegate(context);
    }

    public void applySkin() {
        if (mSkinHelpers != null && !mSkinHelpers.isEmpty()) {
            for (WeakReference ref : mSkinHelpers) {
                if (ref != null && ref.get() != null) {
                    ((SkinCompatSupportable) ref.get()).applySkin();
                }
            }
        }
    }
}
```

可以看到SkinCompatDelegate是一个SkinCompatViewInflater的委托.这里其实和系统的AppCompatDelegateImplV9很类似.

当系统需要创建View的时候,就会回调SkinCompatDelegate的`@Override
    public View onCreateView(View parent, String name, Context context, AttributeSet attrs)`方法,因为前面设置了LayoutInflater的Factory为SkinCompatDelegate.  然后SkinCompatDelegate将创建View的工作交给SkinCompatViewInflater去处理(也是和系统一模一样).

来看看SkinCompatViewInflater是如何创建View的
```java
public final View createView(View parent, final String name, @NonNull Context context, @NonNull AttributeSet attrs) {
    View view = createViewFromHackInflater(context, name, attrs);

    if (view == null) {
        view = createViewFromInflater(context, name, attrs);
    }

    if (view == null) {
        view = createViewFromTag(context, name, attrs);
    }

    if (view != null) {
        // If we have created a view, check it's android:onClick
        checkOnClickListener(view, attrs);
    }

    return view;
}
private View createViewFromInflater(Context context, String name, AttributeSet attrs) {
    View view = null;
    //这里的SkinLayoutInflater(我理解为控件创建器)就是我们之前在初始化时设置的SkinAppCompatViewInflater
    //当然,SkinLayoutInflater可以有多个
    for (SkinLayoutInflater inflater : SkinCompatManager.getInstance().getInflaters()) {
        view = inflater.createView(context, name, attrs);
        if (view == null) {
            continue;
        } else {
            break;
        }
    }
    return view;
}

//这个方法和系统的完全一模一样嘛,so easy
public View createViewFromTag(Context context, String name, AttributeSet attrs) {
    if ("view".equals(name)) {
        name = attrs.getAttributeValue(null, "class");
    }

    try {
        mConstructorArgs[0] = context;
        mConstructorArgs[1] = attrs;

        //自定义控件
        if (-1 == name.indexOf('.')) {
            for (int i = 0; i < sClassPrefixList.length; i++) {
                final View view = createView(context, name, sClassPrefixList[i]);
                if (view != null) {
                    return view;
                }
            }
            return null;
        } else {
            return createView(context, name, null);
        }
    } catch (Exception e) {
        // We do not want to catch these, lets return null and let the actual LayoutInflater
        // try
        return null;
    } finally {
        // Don't retain references on context.
        mConstructorArgs[0] = null;
        mConstructorArgs[1] = null;
    }
}
```
可以看到,这些实现其实是和系统的实现是差不多的.原理已在上面的预备知识中给出.


这里也有不同的地方,`createViewFromInflater()`方法中利用了我们在初始化库时设置的SkinLayoutInflater(我觉得是控件创造器)去创建view.

为什么要在SkinCompatViewInflater还要细化,还需要交由更细的SkinLayoutInflater来处理呢?我觉得是因为方便扩展,库中给出了几个SkinLayoutInflater,有SkinAppCompatViewInflater（基础控件构建器）、SkinMaterialViewInflater（material design控件构造器）、SkinConstraintViewInflater（ConstraintLayout构建器）、SkinCardViewInflater（CardView v7构建器）。

由于初始化时我们设置的是SkinAppCompatViewInflater，其他的构建器都是类似的原理.我们就来看看
```java
//SkinAppCompatViewInflater.java
@Override
public View createView(Context context, String name, AttributeSet attrs) {
    View view = createViewFromFV(context, name, attrs);

    if (view == null) {
        view = createViewFromV7(context, name, attrs);
    }
    return view;
}

private View createViewFromFV(Context context, String name, AttributeSet attrs) {
    View view = null;
    if (name.contains(".")) {
        return null;
    }
    switch (name) {
        case "View":
            view = new SkinCompatView(context, attrs);
            break;
        case "LinearLayout":
            view = new SkinCompatLinearLayout(context, attrs);
            break;
        case "RelativeLayout":
            view = new SkinCompatRelativeLayout(context, attrs);
            break;
        case "FrameLayout":
            view = new SkinCompatFrameLayout(context, attrs);
            break;
        case "TextView":
            view = new SkinCompatTextView(context, attrs);
            break;
        case "ImageView":
            view = new SkinCompatImageView(context, attrs);
            break;
        case "Button":
            view = new SkinCompatButton(context, attrs);
            break;
        case "EditText":
            view = new SkinCompatEditText(context, attrs);
            break;
        ......
        default:
            break;
    }
    return view;
}

private View createViewFromV7(Context context, String name, AttributeSet attrs) {
    View view = null;
    switch (name) {
        case "android.support.v7.widget.Toolbar":
            view = new SkinCompatToolbar(context, attrs);
            break;
        default:
            break;
    }
    return view;
}
```
柳暗花明又一村?这不就是之前我们在Android源码中看过的代码吗？几乎是一模一样。我们在这里将View的创建拦截，然后创建自己的控件。既然是我们自己创建的控件，想干啥还不容易么？

我们看一下`SkinCompatTextView`的源码
```java
//SkinCompatTextView.java
public class SkinCompatTextView extends AppCompatTextView implements SkinCompatSupportable {
    private SkinCompatTextHelper mTextHelper;
    private SkinCompatBackgroundHelper mBackgroundTintHelper;

    public SkinCompatTextView(Context context) {
        this(context, null);
    }

    public SkinCompatTextView(Context context, AttributeSet attrs) {
        this(context, attrs, android.R.attr.textViewStyle);
    }

    public SkinCompatTextView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        mBackgroundTintHelper = new SkinCompatBackgroundHelper(this);
        mBackgroundTintHelper.loadFromAttributes(attrs, defStyleAttr);
        mTextHelper = SkinCompatTextHelper.create(this);
        mTextHelper.loadFromAttributes(attrs, defStyleAttr);
    }
    ......

    @Override
    public void applySkin() {
        if (mBackgroundTintHelper != null) {
            mBackgroundTintHelper.applySkin();
        }
        if (mTextHelper != null) {
            mTextHelper.applySkin();
        }
    }

}
```
还是那套经典的操作，将background相关的属性交给SkinCompatBackgroundHelper去处理，将textColor相关的操作交给SkinCompatTextHelper去处理。与源码中一模一样。

### 3. 源码二，从皮肤包加载皮肤

> 其实皮肤包就是一个apk,只不过里面没有任何代码,只有一些需要换肤的资源或者颜色什么的.而且这些资源的名称必须和当前app中的资源名称是一致的,才能替换. 需要什么皮肤资源,直接去皮肤包里面去拿就好了.

使用方式
```java
SkinCompatManager.getInstance().loadSkin("night.skin", null, CustomSDCardLoader.SKIN_LOADER_STRATEGY_SDCARD);
```

来吧,我们进入loadSkin()方法看一下:

```java
/**
* 加载皮肤包.
* @param skinName 皮肤包名称.
* @param listener 皮肤包加载监听.
* @param strategy 皮肤包加载策略.
*/
public AsyncTask loadSkin(String skinName, SkinLoaderListener listener, int strategy) {
    //加载策略  分为好几种:从SD卡中加载皮肤,从assets文件中加载皮肤等等
    SkinLoaderStrategy loaderStrategy = mStrategyMap.get(strategy);
    if (loaderStrategy == null) {
        return null;
    }
    return new SkinLoadTask(listener, loaderStrategy).executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR, skinName);
}
```

可以看到SkinLoadTask应该是一个AsyncTask,然后在后台去解析这个皮肤包.既然是AsyncTask,那肯定看`doInBackground()`方法咯

我们来看看SkinLoadTask的`doInBackground()`
```java
//SkinLoadTask.java
@Override
protected String doInBackground(String... params) {
    ......
    try {
        if (params.length == 1) {
            //根据加载策略去后台加载皮肤
            String skinName = mStrategy.loadSkinInBackground(mAppContext, params[0]);
            if (TextUtils.isEmpty(skinName)) {
                SkinCompatResources.getInstance().reset(mStrategy);
            }
            return params[0];
        }
    } catch (Exception e) {
        e.printStackTrace();
    }
    SkinCompatResources.getInstance().reset();
    return null;
}

//加载策略 随便挑一个吧 SkinSDCardLoader.java  从SD卡加载皮肤
@Override
public String loadSkinInBackground(Context context, String skinName) {
    if (TextUtils.isEmpty(skinName)) {
        return skinName;
    }
    //获取皮肤路径
    String skinPkgPath = getSkinPath(context, skinName);
    if (SkinFileUtils.isFileExists(skinPkgPath)) {
        //获取皮肤包包名.
        String pkgName = SkinCompatManager.getInstance().getSkinPackageName(skinPkgPath);
        //获取皮肤包的Resources
        Resources resources = SkinCompatManager.getInstance().getSkinResources(skinPkgPath);
        if (resources != null && !TextUtils.isEmpty(pkgName)) {
            SkinCompatResources.getInstance().setupSkin(
                    resources,
                    pkgName,
                    skinName,
                    this);
            return skinName;
        }
    }
    return null;
}

//SkinCompatManager.java
//获取皮肤包包名.
public String getSkinPackageName(String skinPkgPath) {
    PackageManager mPm = mAppContext.getPackageManager();
    PackageInfo info = mPm.getPackageArchiveInfo(skinPkgPath, PackageManager.GET_ACTIVITIES);
    return info.packageName;
}
//获取皮肤包资源{@link Resources}.
@Nullable
public Resources getSkinResources(String skinPkgPath) {
    try {
        AssetManager assetManager = AssetManager.class.newInstance();
        Method addAssetPath = assetManager.getClass().getMethod("addAssetPath", String.class);
        addAssetPath.invoke(assetManager, skinPkgPath);

        Resources superRes = mAppContext.getResources();
        return new Resources(assetManager, superRes.getDisplayMetrics(), superRes.getConfiguration());
    } catch (Exception e) {
        e.printStackTrace();
    }
    return null;
}
```
大概就是去子线程获取皮肤包的包名和Resources(要这个干啥?后面我们需要获取皮肤包中的颜色或者资源时需要通过这个进行获取).

`SkinCompatResources.getInstance().setupSkin()`方法中就是将这些从皮肤包中加载的Resources,包名,皮肤名,加载策略全部存下来.有了这些东西,待会儿就能取皮肤包里面的资源了.


库中定义的控件都是实现了SkinCompatSupportable接口的，方便控制换肤。比如SkinCompatTextView的applySkin（）方法中调用了BackgroundTintHelper和TextHelper的`applySkin()`方法，就是说换肤时会去动态的更换背景或文字颜色什么的。我们来看看` mBackgroundTintHelper.applySkin()`的实现

```java
//SkinCompatBackgroundHelper.java
@Override
public void applySkin() {
    //该控件是否有背景  检测
    mBackgroundResId = checkResourceId(mBackgroundResId);
    if (mBackgroundResId == INVALID_ID) {
        return;
    }
    Drawable drawable = SkinCompatVectorResources.getDrawableCompat(mView.getContext(), mBackgroundResId);
    if (drawable != null) {
        int paddingLeft = mView.getPaddingLeft();
        int paddingTop = mView.getPaddingTop();
        int paddingRight = mView.getPaddingRight();
        int paddingBottom = mView.getPaddingBottom();
        ViewCompat.setBackground(mView, drawable);
        mView.setPadding(paddingLeft, paddingTop, paddingRight, paddingBottom);
    }
}

```
就是获取drawable然后给view设置背景嘛.关键在于这里的获取drawable是怎么实现的.来看看具体实现

```java
//SkinCompatVectorResources.java
private Drawable getSkinDrawableCompat(Context context, int resId) {
    //当前是非默认皮肤
    if (!SkinCompatResources.getInstance().isDefaultSkin()) {
        try {
            return SkinCompatDrawableManager.get().getDrawable(context, resId);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    ......
    return AppCompatResources.getDrawable(context, resId);
}

//SkinCompatDrawableManager.java
public Drawable getDrawable(@NonNull Context context, @DrawableRes int resId) {
    return getDrawable(context, resId, false);
}

Drawable getDrawable(@NonNull Context context, @DrawableRes int resId,
                        boolean failIfNotKnown) {
    //检查Drawable是否能被正确解码
    checkVectorDrawableSetup(context);

    Drawable drawable = loadDrawableFromDelegates(context, resId);
    if (drawable == null) {
        drawable = createDrawableIfNeeded(context, resId);
    }
    if (drawable == null) {
        //这里是关键
        drawable = SkinCompatResources.getDrawable(context, resId);
    }

    if (drawable != null) {
        // Tint it if needed
        drawable = tintDrawable(context, resId, failIfNotKnown, drawable);
    }
    if (drawable != null) {
        // See if we need to 'fix' the drawable
        SkinCompatDrawableUtils.fixDrawable(drawable);
    }
    return drawable;
}

```
最后是调用的SkinCompatDrawableManager去获取drawable,我发现这个SkinCompatDrawableManager和系统的AppCompatDrawableManager一模一样.
唯一不同点是上面的31行处`drawable = SkinCompatResources.getDrawable(context, resId);`,在这里我们去创建drawable时就使用SkinCompatResources去获取.

还记得SkinCompatResources么?就是上面我们获取了皮肤包的信息后,将信息全部保存到了这个类里面.

```java
//SkinCompatResources.java
//皮肤的Resources可以通过它来获取皮肤里面的资源
private Resources mResources;
//皮肤包名
private String mSkinPkgName = "";
//皮肤名
private String mSkinName = "";
//加载策略
private SkinCompatManager.SkinLoaderStrategy mStrategy;
//是默认皮肤?
private boolean isDefaultSkin = true;

public static Drawable getDrawable(Context context, int resId) {
    return getInstance().getSkinDrawable(context, resId);
}
/**
* 通过id获取皮肤中的drawable资源
* @param context Context
* @param resId   资源id
*/
private Drawable getSkinDrawable(Context context, int resId) {
    //是否有皮肤颜色缓存
    if (!SkinCompatUserThemeManager.get().isColorEmpty()) {
        ColorStateList colorStateList = SkinCompatUserThemeManager.get().getColorStateList(resId);
        if (colorStateList != null) {
            return new ColorDrawable(colorStateList.getDefaultColor());
        }
    }
    //是否有皮肤drawable缓存
    if (!SkinCompatUserThemeManager.get().isDrawableEmpty()) {
        Drawable drawable = SkinCompatUserThemeManager.get().getDrawable(resId);
        if (drawable != null) {
            return drawable;
        }
    }
    //加载策略非空  可以通过加载策略去加载drawable,开发者可自定义
    if (mStrategy != null) {
        Drawable drawable = mStrategy.getDrawable(context, mSkinName, resId);
        if (drawable != null) {
            return drawable;
        }
    }
    //非默认皮肤 去皮肤中加载资源
    if (!isDefaultSkin) {
        //皮肤资源id   这是我们的目标
        int targetResId = getTargetResId(context, resId);
        if (targetResId != 0) {
            //根据id通过皮肤的Resources去获取drawable
            return mResources.getDrawable(targetResId);
        }
    }
    return context.getResources().getDrawable(resId);
}
```
大概意思就是有缓存资源(之前在皮肤包中取过这个resId的资源)则取缓存资源,没有缓存则根据resId通过皮肤的Resources去获取drawable.

到此,已经获取到皮肤包中的drawable,也就是实现了动态的加载皮肤包中的图片,shape等等的资源,加载皮肤中的颜色的过程也是类似的,这里就不多介绍了.终于,我们完成了换肤大业.

### 4.简单总结一下原理(本文精髓)

1. 监听APP所有Activity的生命周期(registerActivityLifecycleCallbacks())
2. 在每个Activity的onCreate()方法调用时setFactory(),设置创建View的工厂.将创建View的琐事交给SkinCompatViewInflater去处理.
3. 库中自己重写了系统的控件(比如View对应于库中的SkinCompatView),实现换肤接口(接口里面只有一个applySkin()方法),表示该控件是支持换肤的.并且将这些控件在创建之后收集起来,方便随时换肤.
4. 在库中自己写的控件里面去解析出一些特殊的属性(比如:background, textColor),并将其保存起来
5. 在切换皮肤的时候,遍历一次之前缓存的View,调用其实现的接口方法applySkin(),在applySkin()中从皮肤资源(可以是从网络或者本地获取皮肤包)中获取资源.获取资源后设置其控件的background或textColor等,就可实现换肤.

感谢开源,感谢作者.项目地址:https://github.com/ximsfei/Android-skin-support
