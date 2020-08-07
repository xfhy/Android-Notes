
    
  
# 一文读懂Android View事件分发机制


Android View 虽然不是四大组件，但其并不比四大组件的地位低。而View的核心知识点事件分发机制则是不少刚入门同学的拦路虎。ScrollView嵌套RecyclerView(或者ListView)的滑动冲突这种老大难的问题的理论基础就是事件分发机制。<br />


事件分发机制面试也会经常被提及，如果你能get到要领，并跟面试官深入的灵魂交流一下，那么一定会让面试官对你印象深刻，抛出爱的橄榄枝~想想都有点小激动呢~。那么就让我们从浅入深，由表及里的去看事件分发机制，全方位，立体式，去弄懂这个神秘的事件分发机制吧。

# 
MotionEvent事件初探


我们对屏幕的点击，滑动，抬起等一系的动作都是由一个一个MotionEvent对象组成的。根据不同动作，主要有以下三种事件类型：<br />
1.ACTION_DOWN：手指刚接触屏幕，按下去的那一瞬间产生该事件<br />
2.ACTION_MOVE：手指在屏幕上移动时候产生该事件<br />
3.ACTION_UP：手指从屏幕上松开的瞬间产生该事件


从ACTION_DOWN开始到ACTION_UP结束我们称为一个事件序列


正常情况下，无论你手指在屏幕上有多么骚的操作，最终呈现在MotionEvent上来讲无外乎下面两种。<br />1.点击后抬起，也就是单击操作：ACTION_DOWN -&gt; ACTION_UP<br />
2.点击后再风骚的滑动一段距离，再抬起：ACTION_DOWN -&gt; ACTION_MOVE -&gt; ... -&gt; ACTION_MOVE -&gt; ACTION_UP<br />

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">public class MotionEventActivity extends BaseActivity {
    private Button mButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_motion_event);
        mButton = (Button) findViewById(R.id.button);
        mButton.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        e("MotionEvent: ACTION_DOWN");
                        break;
                    case MotionEvent.ACTION_MOVE:
                        e("MotionEvent: ACTION_MOVE");
                        break;
                    case MotionEvent.ACTION_UP:
                        e("MotionEvent: ACTION_UP");
                        break;
                }
                return false;
            }
        });
    }

    public void click(View v) {
        e("点击了按钮");
    }
}</code>
```


注：e("xxx")是BaseActivity封装的Log显示方法，具体请看[BaseProject](http://www.jianshu.com/p/d5ad3f127ebf)


当我们单击按钮：<br />


<br />
当我们在按钮上风骚走位（滑动）：<br />


细心的同学一定发现了我们常用的按钮的onclick事件都是在ACTION_UP以后才被调用的。这和View的事件分发机制是不是有某种不可告人的关系呢？！<br />


<br />上面代码我们给button设置了OnTouchListener并重写了onTouch方法，方法返回值默认为false。如果这里我们返回true，那么你会发现onclick方法不执行了！！！What？<br />
这些随着我们的深入探讨，结论就会浮出水面！针对MotionEvent，我们先说这么多。

# 
MotionEvent事件分发


当一个MotionEvent产生了以后，就是你的手指在屏幕上做一系列动作的时候，系统需要把这一系列的MotionEvent分发给一个具体的View。我们重点需要了解这个分发的过程，那么系统是如何去判断这个事件要给哪个View，也就是说是如何进行分发的呢？


事件分发需要View的三个重要方法来共同完成：

> 
<ul style="margin-left:22px;"><li style="line-height:30px;">
<p style="overflow:visible;line-height:1.7;">
public boolean dispatchTouchEvent(MotionEvent event)<br />
通过方法名我们不难猜测，它就是事件分发的重要方法。那么很明显，如果一个MotionEvent传递给了View，那么dispatchTouchEvent方法一定会被调用！<br />返回值：表示是否消费了当前事件。可能是View本身的onTouchEvent方法消费，也可能是子View的dispatchTouchEvent方法中消费。返回true表示事件被消费，本次的事件终止。返回false表示View以及子View均没有消费事件，将调用父View的onTouchEvent方法</p>
</li><li style="line-height:30px;">
<p style="overflow:visible;line-height:1.7;">
public boolean onInterceptTouchEvent(MotionEvent ev)<br />
事件拦截，当一个ViewGroup在接到MotionEvent事件序列时候，首先会调用此方法判断是否需要拦截。特别注意，这是ViewGroup特有的方法，View并没有拦截方法<br />返回值：是否拦截事件传递，返回true表示拦截了事件，那么事件将不再向下分发而是调用View本身的onTouchEvent方法。返回false表示不做拦截，事件将向下分发到子View的dispatchTouchEvent方法。</p>
</li><li style="line-height:30px;">
<p style="overflow:visible;line-height:1.7;">
public boolean onTouchEvent(MotionEvent ev)<br />
真正对MotionEvent进行处理或者说消费的方法。在dispatchTouchEvent进行调用。<br />返回值：返回true表示事件被消费，本次的事件终止。返回false表示事件没有被消费，将调用父View的onTouchEvent方法</p>
</li></ul>


上面的三个方法可以用以下的伪代码来表示其之间的关系。

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">    public boolean dispatchTouchEvent(MotionEvent ev) {
        boolean consume = false;//事件是否被消费
        if (onInterceptTouchEvent(ev)){//调用onInterceptTouchEvent判断是否拦截事件
            consume = onTouchEvent(ev);//如果拦截则调用自身的onTouchEvent方法
        }else{
            consume = child.dispatchTouchEvent(ev);//不拦截调用子View的dispatchTouchEvent方法
        }
        return consume;//返回值表示事件是否被消费，true事件终止，false调用父View的onTouchEvent方法
    }</code>
```


通过上面的介绍相信我们已经初步了解了View事件分发的机制<br />


接下来我们来看一下View 和ViewGroup 在事件分发的时候有什么不一样的地方


ViewGroup是View的子类，也就是说ViewGroup本身就是一个View，但是它可以包含子View（当然子View也可能是一个ViewGroup），所以不难理解，上面所展示的伪代码表示的是ViewGroup 处理事件分发的流程。而View本身是不存在分发，所以也没有拦截方法（onInterceptTouchEvent），它只能在onTouchEvent方法中进行处理消费或者不消费。


上面结论先简单的理解一下，通过下面的流程图，会更加清晰的帮助我们梳理事件分发机制


可以看出事件的传递过程都是从父View到子View。

> 
<p style="line-height:1.7;">
但是这里有三点需要特别强调一下</p>
<ul style="margin-left:22px;"><li style="line-height:30px;">
<p style="overflow:visible;line-height:1.7;">
子View可以通过requestDisallowInterceptTouchEvent方法干预父View的事件分发过程（ACTION_DOWN事件除外），而这就是我们处理滑动冲突常用的关键方法。关于处理滑动冲突，我们下一篇文章会专门去分析，这里就不做过多解释。</p>
</li><li style="line-height:30px;">
<p style="overflow:visible;line-height:1.7;">
对于View（注意！ViewGroup也是View）而言，如果设置了onTouchListener，那么OnTouchListener方法中的onTouch方法会被回调。onTouch方法返回true，则onTouchEvent方法不会被调用（onClick事件是在onTouchEvent中调用）所以三者优先级是onTouch-&gt;onTouchEvent-&gt;onClick</p>
</li><li style="line-height:30px;">
<p style="overflow:visible;line-height:1.7;">
View 的onTouchEvent 方法默认都会消费掉事件（返回true），除非它是不可点击的（clickable和longClickable同时为false），View的longClickable默认为false，clickable需要区分情况，如Button的clickable默认为true，而TextView的clickable默认为false。</p>
</li></ul>

# 
View事件分发源码


作为程序猿，最不想看的但是也不得不去看的就是源码！所谓知其然也要知其所以然，神秘的大佬曾经说过提高的方法就是READ THE FUCKING CODE！那么我们就带大家来看一下Android对事件分发的处理方式，看是否与我们上面说的结论一致！（为方便阅读，以下都只给出了关键代码并额外添加上一些简单注释，全部代码请自行阅读源码）<br />


<br />
点击事件产生最先传递到当前的Activity，由Acivity的dispatchTouchEvent方法来对事件进行分发。那么很明显我们先看Activity的dispatchTouchEvent方法

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">Class Activity：
    public boolean dispatchTouchEvent(MotionEvent ev) {
        if (ev.getAction() == MotionEvent.ACTION_DOWN) {
            onUserInteraction();
        }
        if (getWindow().superDispatchTouchEvent(ev)) {//事件分发并返回结果
            return true;//事件被消费
        }
        return onTouchEvent(ev);//没有View可以处理，调用Activity onTouchEvent方法
    }</code>
```


通过上面的代码我们可以发现，事件会给Activity附属的Window进行分发。如果返回true，那么事件被消费。如果返回false表示事件发下去却没有View可以进行处理，则最后return Activity自己的onTouchEvent方法。


跟进getWindow().superDispatchTouchEvent(ev)方法发现是Window类当中的一个抽象方法

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">Window类说明
/**
 * Abstract base class for a top-level window look and behavior policy.  An
 * instance of this class should be used as the top-level view added to the
 * window manager. It provides standard UI policies such as a background, title
 * area, default key processing, etc.
 *
 * &lt;p&gt;The only existing implementation of this abstract class is
 * android.view.PhoneWindow, which you should instantiate when needing a
 * Window.
 */
Class Window:
//抽象方法，需要看PhoneWindow的实现
public abstract boolean superDispatchTouchEvent(MotionEvent event);</code>
```


Window的源码有说明The only existing implementation of this abstract class is<br />
android.view.PhoneWindow，Window的唯一实现类是PhoneWindow。那么去看PhoneWindow对应的代码。<br />

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">class PhoneWindow
    // This is the top-level view of the window, containing the window decor.
    private DecorView mDecor;
    public boolean superDispatchTouchEvent(MotionEvent event) {
        return mDecor.superDispatchTouchEvent(event);
    }</code>
```


PhoneWindow又调用了DecorView的superDispatchTouchEvent方法。而这个DecorView就是Window的顶级View，我们通过setContentView设置的View是它的子View（Activity的setContentView，最终是调用PhoneWindow的setContentView，有兴趣同学可以去阅读，这块不是我们讨论重点）


到这里事件已经被传递到我们的顶级View中，一般是ViewGroup。<br />
那么接下来重点将放到ViewGroup的dispatchTouchEvent方法中。我们之前说过，事件到达View会调用dispatchTouchEvent方法，如果View是ViewGroup那么会先判断是否拦截该事件。

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">class ViewGroup:
    public boolean dispatchTouchEvent(MotionEvent ev) {
        ...
        final int action = ev.getAction();
        final int actionMasked = action &amp; MotionEvent.ACTION_MASK;
        // Handle an initial down.
        if (actionMasked == MotionEvent.ACTION_DOWN) {
            // Throw away all previous state when starting a new touch gesture.
            // The framework may have dropped the up or cancel event for the previous gesture
            // due to an app switch, ANR, or some other state change.
            cancelAndClearTouchTargets(ev);
            resetTouchState();//清除FLAG_DISALLOW_INTERCEPT设置，并且mFirstTouchTarget 设置为null
        }
        // Check for interception.
        final boolean intercepted;//是否拦截事件
        if (actionMasked == MotionEvent.ACTION_DOWN
                || mFirstTouchTarget != null) {
            //FLAG_DISALLOW_INTERCEPT是子类通过requestDisallowInterceptTouchEvent方法进行设置的
            final boolean disallowIntercept = (mGroupFlags &amp; FLAG_DISALLOW_INTERCEPT) != 0;
            if (!disallowIntercept) {
                //调用onInterceptTouchEvent方法判断是否需要拦截
                intercepted = onInterceptTouchEvent(ev);
                ev.setAction(action); // restore action in case it was changed
            } else {
                intercepted = false;
            }
        } else {
            // There are no touch targets and this action is not an initial down
            // so this view group continues to intercept touches.
            intercepted = true;
        }
        ...
    }</code>
```


我们前面说过子View可以通过requestDisallowInterceptTouchEvent方法干预父View的事件分发过程（ACTION_DOWN事件除外）


为什么ACTION_DOWN除外？通过上述代码我们不难发现。如果事件是ACTION_DOWN，那么ViewGroup会重置FLAG_DISALLOW_INTERCEPT标志位并且将mFirstTouchTarget 设置为null。对于mFirstTouchTarget 我们可以先这么理解，如果事件由子View去处理时mFirstTouchTarget 会被赋值并指向子View。


所以当事件为ACTION_DOWN 或者 mFirstTouchTarget ！=null（即事件由子View处理）时会进行拦截判断。具体规则是如果子View设置了FLAG_DISALLOW_INTERCEPT标志位，那么intercepted =false。否则调用onInterceptTouchEvent方法。


如果事件不为ACTION_DOWN 且事件为ViewGroup本身处理（即mFirstTouchTarget ==null）那么intercepted =false，很显然事件已经交给自己处理根本没必要再调用onInterceptTouchEvent去判断是否拦截。

### 
结论：

> 
<p style="line-height:1.7;">
当ViewGroup决定拦截事件后，后续事件将默认交给它处理并且不会再调用onInterceptTouchEvent方法来判断是否拦截。子View可以通过设置FLAG_DISALLOW_INTERCEPT标志位来不让ViewGroup拦截除ACTION_DOWN以外的事件。</p>
<p style="line-height:1.7;">
所以我们知道了onInterceptTouchEvent并非每次都会被调用。如果要处理所有的点击事件那么需要选择dispatchTouchEvent方法<br />
而FLAG_DISALLOW_INTERCEPT标志位可以帮助我们去有效的处理滑动冲突</p>



当ViewGroup不拦截事件，那么事件将下发给子View进行处理。

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">class ViewGroup:
    public boolean dispatchTouchEvent(MotionEvent ev) {
        final View[] children = mChildren;
        //对子View进行遍历
        for (int i = childrenCount - 1; i &gt;= 0; i--) {
            final int childIndex = getAndVerifyPreorderedIndex(
                    childrenCount, i, customOrder);
            final View child = getAndVerifyPreorderedView(
                    preorderedList, children, childIndex);

            // If there is a view that has accessibility focus we want it
            // to get the event first and if not handled we will perform a
            // normal dispatch. We may do a double iteration but this is
            // safer given the timeframe.
            if (childWithAccessibilityFocus != null) {
                if (childWithAccessibilityFocus != child) {
                    continue;
                }
                childWithAccessibilityFocus = null;
                i = childrenCount - 1;
            }

            //判断1，View可见并且没有播放动画。2，点击事件的坐标落在View的范围内
            //如果上述两个条件有一项不满足则continue继续循环下一个View
            if (!canViewReceivePointerEvents(child)
                    || !isTransformedTouchPointInView(x, y, child, null)) {
                ev.setTargetAccessibilityFocus(false);
                continue;
            }

            newTouchTarget = getTouchTarget(child);
            //如果有子View处理即newTouchTarget 不为null则跳出循环。
            if (newTouchTarget != null) {
                // Child is already receiving touch within its bounds.
                // Give it the new pointer in addition to the ones it is handling.
                newTouchTarget.pointerIdBits |= idBitsToAssign;
                break;
            }

            resetCancelNextUpFlag(child);
            //dispatchTransformedTouchEvent第三个参数child这里不为null
            //实际调用的是child的dispatchTouchEvent方法
            if (dispatchTransformedTouchEvent(ev, false, child, idBitsToAssign)) {
                // Child wants to receive touch within its bounds.
                mLastTouchDownTime = ev.getDownTime();
                if (preorderedList != null) {
                    // childIndex points into presorted list, find original index
                    for (int j = 0; j &lt; childrenCount; j++) {
                        if (children[childIndex] == mChildren[j]) {
                            mLastTouchDownIndex = j;
                            break;
                        }
                    }
                } else {
                    mLastTouchDownIndex = childIndex;
                }
                mLastTouchDownX = ev.getX();
                mLastTouchDownY = ev.getY();
                //当child处理了点击事件，那么会设置mFirstTouchTarget 在addTouchTarget被赋值
                newTouchTarget = addTouchTarget(child, idBitsToAssign);
                alreadyDispatchedToNewTouchTarget = true;
                //子View处理了事件，然后就跳出了for循环
                break;
            }
        }
    }</code>
```


上面代码是将事件分发给子View的关键代码，需要关注的地方都加了注释。分发过程首先需要遍历ViewGroup的所有子View，可以接收点击事件的View需要满足下面条件。<br />1.如果View可见并且没有播放动画canViewReceivePointerEvents方法判断

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">    /**
     * Returns true if a child view can receive pointer events.
     * @hide
     */
    private static boolean canViewReceivePointerEvents(@NonNull View child) {
        return (child.mViewFlags &amp; VISIBILITY_MASK) == VISIBLE
                || child.getAnimation() != null;
    }</code>
```


2.点击事件的坐标落在View的范围内isTransformedTouchPointInView方法判断

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">    /**
     * Returns true if a child view contains the specified point when transformed
     * into its coordinate space.
     * Child must not be null.
     * @hide
     */
    protected boolean isTransformedTouchPointInView(float x, float y, View child,
            PointF outLocalPoint) {
        final float[] point = getTempPoint();
        point[0] = x;
        point[1] = y;
        transformPointToViewLocal(point, child);
        //调用View的pointInView方法进行判断坐标点是否在View内
        final boolean isInView = child.pointInView(point[0], point[1]);
        if (isInView &amp;&amp; outLocalPoint != null) {
            outLocalPoint.set(point[0], point[1]);
        }
        return isInView;
    }</code>
```


如果满足上面两个条件，接着我们看后面的代码newTouchTarget = getTouchTarget(child);

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">    /**
     * Gets the touch target for specified child view.
     * Returns null if not found.
     */
    private TouchTarget getTouchTarget(@NonNull View child) {
        for (TouchTarget target = mFirstTouchTarget; target != null; target = target.next) {
            if (target.child == child) {
                return target;
            }
        }
        return null;
    }</code>
```


可以看到当mFirstTouchTarget不为null的时候并且target.child就为我们当前遍历的child的时候，那么返回的newTouchTarget 就不为null，则跳出循环。我们前面说过，当子View处理了点击事件那么mFirstTouchTarget就不为nulll。事实上此时我们还没有将事件分发给子View，所以正常情况下我们的newTouchTarget 此时为null


接下来关键来了<br />dispatchTransformedTouchEvent(ev, false, child, idBitsToAssign)方法。为方便我们将代码再一次贴到后面来<br />

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">        if (dispatchTransformedTouchEvent(ev, false, child, idBitsToAssign)) {
            // Child wants to receive touch within its bounds.
            mLastTouchDownTime = ev.getDownTime();
            if (preorderedList != null) {
                // childIndex points into presorted list, find original index
                for (int j = 0; j &lt; childrenCount; j++) {
                    if (children[childIndex] == mChildren[j]) {
                        mLastTouchDownIndex = j;
                        break;
                    }
                }
            } else {
                mLastTouchDownIndex = childIndex;
            }
            mLastTouchDownX = ev.getX();
            mLastTouchDownY = ev.getY();
            //当child处理了点击事件，那么会设置mFirstTouchTarget 在addTouchTarget被赋值
            newTouchTarget = addTouchTarget(child, idBitsToAssign);
            alreadyDispatchedToNewTouchTarget = true;
            //子View处理了事件，然后就跳出了for循环
            break;
        }</code>
```


可以看到它被最后一个if包围，如果它返回为true，那么就break跳出循环，如果返回为false则继续遍历下一个子View。<br />
我们跟进dispatchTransformedTouchEvent方法可以看到这样的关键逻辑

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">        if (child == null) {
            handled = super.dispatchTouchEvent(event);
        } else {
            handled = child.dispatchTouchEvent(event);
        }</code>
```


这里child是我们遍历传入的子View此时不为null，则调用了child.dispatchTouchEvent(event);<br />
我们子View的dispatchTouchEvent方法返回true，表示子View处理了事件，那么我们一直提到的，mFirstTouchTarget 会被赋值，是在哪里完成的呢？<br />
再回头看dispatchTransformedTouchEvent则为true进入最后一个if语句，有这么一句newTouchTarget = addTouchTarget(child, idBitsToAssign);

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">    /**
     * Adds a touch target for specified child to the beginning of the list.
     * Assumes the target child is not already present.
     */
    private TouchTarget addTouchTarget(@NonNull View child, int pointerIdBits) {
        final TouchTarget target = TouchTarget.obtain(child, pointerIdBits);
        target.next = mFirstTouchTarget;
        mFirstTouchTarget = target;
        return target;
    }</code>
```


没错，mFirstTouchTarget 就是在addTouchTarget中被赋值！到此子View遍历结束


如果在遍历完子View以后ViewGroup仍然没有找到事件处理者即ViewGroup并没有子View或者子View处理了事件，但是子View的dispatchTouchEvent返回了false（一般是子View的onTouchEvent方法返回false）那么ViewGroup会去处理这个事件。<br />
从代码上看就是我们遍历的dispatchTransformedTouchEvent方法返回了false。那么mFirstTouchTarget 必然为null；<br />
在ViewGroup的dispatchTouchEvent遍历完子View后有下面的处理。

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">        // Dispatch to touch targets.
        if (mFirstTouchTarget == null) {
            // No touch targets so treat this as an ordinary view.
            handled = dispatchTransformedTouchEvent(ev, canceled, null,
                    TouchTarget.ALL_POINTER_IDS);
        }</code>
```


上面的dispatchTransformedTouchEvent方法第三个child参数传null<br />
我们刚看了这个方法。当child为null时，handled = super.dispatchTouchEvent(event);所以此时将调用View的dispatchTouchEvent方法，点击事件给了View。到此事件分发过程全部结束！

### 
结论：

> 
<p style="line-height:1.7;">
ViewGroup会遍历所有子View去寻找能够处理点击事件的子View（可见，没有播放动画，点击事件坐标落在子View内部）最终调用子View的dispatchTouchEvent方法处理事件</p>
<p style="line-height:1.7;">
当子View处理了事件则mFirstTouchTarget 被赋值，并终止子View的遍历。</p>
<p style="line-height:1.7;">
如果ViewGroup并没有子View或者子View处理了事件，但是子View的dispatchTouchEvent返回了false（一般是子View的onTouchEvent方法返回false）那么ViewGroup会去处理这个事件（本质调用View的dispatchTouchEvent去处理）</p>



通过ViewGroup对事件的分发，我们知道事件最终是调用View的dispatchTouchEvent来处理<br />

### 
View最终是怎么去处理事件的

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">class View:
    public boolean dispatchTouchEvent(MotionEvent ev) {
        // If the event should be handled by accessibility focus first.
        if (event.isTargetAccessibilityFocus()) {
            // We don't have focus or no virtual descendant has it, do not handle the event.
            if (!isAccessibilityFocusedViewOrHost()) {
                return false;
            }
            // We have focus and got the event, then use normal event dispatch.
            event.setTargetAccessibilityFocus(false);
        }

        boolean result = false;

        if (mInputEventConsistencyVerifier != null) {
            mInputEventConsistencyVerifier.onTouchEvent(event, 0);
        }

        final int actionMasked = event.getActionMasked();
        if (actionMasked == MotionEvent.ACTION_DOWN) {
            // Defensive cleanup for new gesture
            stopNestedScroll();
        }

        if (onFilterTouchEventForSecurity(event)) {
            if ((mViewFlags &amp; ENABLED_MASK) == ENABLED &amp;&amp; handleScrollBarDragging(event)) {
                result = true;
            }
            //noinspection SimplifiableIfStatement
            ListenerInfo li = mListenerInfo;
            if (li != null &amp;&amp; li.mOnTouchListener != null
                    &amp;&amp; (mViewFlags &amp; ENABLED_MASK) == ENABLED
                    &amp;&amp; li.mOnTouchListener.onTouch(this, event)) {
                result = true;
            }

            if (!result &amp;&amp; onTouchEvent(event)) {
                result = true;
            }
        }

        if (!result &amp;&amp; mInputEventConsistencyVerifier != null) {
            mInputEventConsistencyVerifier.onUnhandledEvent(event, 0);
        }

        // Clean up after nested scrolls if this is the end of a gesture;
        // also cancel it if we tried an ACTION_DOWN but we didn't want the rest
        // of the gesture.
        if (actionMasked == MotionEvent.ACTION_UP ||
                actionMasked == MotionEvent.ACTION_CANCEL ||
                (actionMasked == MotionEvent.ACTION_DOWN &amp;&amp; !result)) {
            stopNestedScroll();
        }

        return result;
    }</code>
```


上面是View的dispatchTouchEvent方法的全部代码。相比ViewGroup我们需要好几段去拆开看的长篇大论而言，它就简洁多了。很明显View是单独的一个元素，它没有子View，所以也没有分发的代码。我们需要关注的也只是上面当中的一部分代码。

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">        //如果窗口没有被遮盖
        if (onFilterTouchEventForSecurity(event)) {
            if ((mViewFlags &amp; ENABLED_MASK) == ENABLED &amp;&amp; handleScrollBarDragging(event)) {
                result = true;
            }
            //noinspection SimplifiableIfStatement
            //当前监听事件
            ListenerInfo li = mListenerInfo;
            //需要特别注意这个判断当中的li.mOnTouchListener.onTouch(this, event)条件
            if (li != null &amp;&amp; li.mOnTouchListener != null
                    &amp;&amp; (mViewFlags &amp; ENABLED_MASK) == ENABLED
                    &amp;&amp; li.mOnTouchListener.onTouch(this, event)) {
                result = true;
            }
            //result为false调用自己的onTouchEvent方法处理
            if (!result &amp;&amp; onTouchEvent(event)) {
                result = true;
            }
        }</code>
```


通过上面代码我们可以看到View会先判断是否设置了OnTouchListener，如果设置了OnTouchListener并且onTouch方法返回了true，那么onTouchEvent不会被调用。<br />
当没有设置OnTouchListener或者设置了OnTouchListener但是onTouch方法返回false则会调用View自己的onTouchEvent方法。接下来看onTouchEvent方法：

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">class View:
    public boolean onTouchEvent(MotionEvent event) {
        final float x = event.getX();
        final float y = event.getY();
        final int viewFlags = mViewFlags;
        final int action = event.getAction();
        //1.如果View是设置成不可用的（DISABLED）仍然会消费点击事件
        if ((viewFlags &amp; ENABLED_MASK) == DISABLED) {
            if (action == MotionEvent.ACTION_UP &amp;&amp; (mPrivateFlags &amp; PFLAG_PRESSED) != 0) {
                setPressed(false);
            }
            // A disabled view that is clickable still consumes the touch
            // events, it just doesn't respond to them.
            return (((viewFlags &amp; CLICKABLE) == CLICKABLE
                    || (viewFlags &amp; LONG_CLICKABLE) == LONG_CLICKABLE)
                    || (viewFlags &amp; CONTEXT_CLICKABLE) == CONTEXT_CLICKABLE);
        }
        ...
        //2.CLICKABLE 和LONG_CLICKABLE只要有一个为true就消费这个事件
        if (((viewFlags &amp; CLICKABLE) == CLICKABLE ||
                (viewFlags &amp; LONG_CLICKABLE) == LONG_CLICKABLE) ||
                (viewFlags &amp; CONTEXT_CLICKABLE) == CONTEXT_CLICKABLE) {
            switch (action) {
                case MotionEvent.ACTION_UP:
                    boolean prepressed = (mPrivateFlags &amp; PFLAG_PREPRESSED) != 0;
                    if ((mPrivateFlags &amp; PFLAG_PRESSED) != 0 || prepressed) {
                        // take focus if we don't have it already and we should in
                        // touch mode.
                        boolean focusTaken = false;
                        if (isFocusable() &amp;&amp; isFocusableInTouchMode() &amp;&amp; !isFocused()) {
                            focusTaken = requestFocus();
                        }

                        if (prepressed) {
                            // The button is being released before we actually
                            // showed it as pressed.  Make it show the pressed
                            // state now (before scheduling the click) to ensure
                            // the user sees it.
                            setPressed(true, x, y);
                        }

                        if (!mHasPerformedLongPress &amp;&amp; !mIgnoreNextUpEvent) {
                            // This is a tap, so remove the longpress check
                            removeLongPressCallback();

                            // Only perform take click actions if we were in the pressed state
                            if (!focusTaken) {
                                // Use a Runnable and post this rather than calling
                                // performClick directly. This lets other visual state
                                // of the view update before click actions start.
                                if (mPerformClick == null) {
                                    mPerformClick = new PerformClick();
                                }
                                if (!post(mPerformClick)) {
                                    //3.在ACTION_UP方法发生时会触发performClick()方法
                                    performClick();
                                }
                            }
                        }
                        ...
                    break;
            }
            ...
            return true;
        }
        return false;
    }</code>
```


上述代码有三个关键点分别在注释处标出。可以看出即便View是disabled状态，依然不会影响事件的消费，只是它看起来不可用。只要CLICKABLE和LONG_CLICKABLE有一个为true，就一定会消费这个事件，就是onTouchEvent返回true。这点也印证了我们前面说的View 的onTouchEvent 方法默认都会消费掉事件（返回true），除非它是不可点击的（clickable和longClickable同时为false），View的longClickable默认为false，clickable需要区分情况，如Button的clickable默认为true，而TextView的clickable默认为false。<br />
（没错这是复制前面的！！！）


ACTION_UP方法中有performClick()；接下来看一下它：

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">class View:
    /**
     * Call this view's OnClickListener, if it is defined.  Performs all normal
     * actions associated with clicking: reporting accessibility event, playing
     * a sound, etc.
     *
     * @return True there was an assigned OnClickListener that was called, false
     *         otherwise is returned.
     */
    public boolean performClick() {
        final boolean result;
        final ListenerInfo li = mListenerInfo;
        if (li != null &amp;&amp; li.mOnClickListener != null) {
            playSoundEffect(SoundEffectConstants.CLICK);
            li.mOnClickListener.onClick(this);
            result = true;
        } else {
            result = false;
        }

        sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_CLICKED);
        return result;
    }</code>
```


很明显，如果View设置了OnClickListener，那么会回调onClick方法。到这里相信大家对一开始的例子已经没有什么疑惑了吧。<br />


最后再强调一点，我们刚说过View的longClickable默认为false，clickable需要区分情况，如Button的clickable默认为true，而TextView的clickable默认为false。<br />
这是默认情况，我们可以单独给View设置clickable属性，但有时候会发现View的setClickable方法失效了。假如我们想让View默认不可点击，将View的clickable设置成false，在合适的时候需要可点击所以我们又给View设置了OnClickListener，那么你会发现View默认依然可以点击，也就是说setClickable失效了。[关于setClickable失效问题](http://blog.csdn.net/u010302764/article/details/52300610)

```
<code class="java" style="font-family:Menlo, Monaco, Consolas, 'Courier New', monospace;font-size:12px;background-color:transparent;border:none;">class View:
    public void setOnClickListener(@Nullable OnClickListener l) {
        if (!isClickable()) {
            setClickable(true);
        }
        getListenerInfo().mOnClickListener = l;
    }

    public void setOnLongClickListener(@Nullable OnLongClickListener l) {
        if (!isLongClickable()) {
            setLongClickable(true);
        }
        getListenerInfo().mOnLongClickListener = l;
    }</code>
```


View的setOnClickListener会默认将View的clickable设置成true。<br />
View的setOnLongClickListener同样会将View的longClickable设置成true。


至此，MotionEvent事件分发机制与源码的分析已经搞定，大家是否有get到技能+1的感觉？