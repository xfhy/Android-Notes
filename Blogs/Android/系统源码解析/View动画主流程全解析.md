View动画主流程全解析
---
#### 目录
- [1. 回顾View动画基本用法](#head1)
- [2. 动画流程](#head2)
	- [2.1 invalidate(true)](#head3)
- [3. setFillAfter](#head4)
- [4. View动画会导致measure吗？](#head5)

---

View动画，即补间动画。包含：渐变、旋转、平移、缩放四种基本的动画，当然，我们可以自己扩展实现。View动画不会改变View的属性，指数视觉效果变化，动画完成之后它还是在原本的位置上。

这篇文章主要着手于View动画的主流程进行分析，动画的呈现原理不在本文的分析范围之内（如Matrix之类的原理）。

> 文中所展示的源码为android-30

> 调试小技巧：用Android Studio创建一个模拟器，Android系统版本与demo的compileSdkVersion对应的版本一致，这样的话，在调试View、ViewGroup、ViewRootImpl等源码时非常方便，不会出现源码对不上的情况。

### <span id="head1">1. 回顾View动画基本用法</span>

View动画大家已经非常熟悉了，举个简单例子简单回顾下：

```kotlin
val scaleAnimation = ScaleAnimation(0f, 1f, 0f, 1f)
scaleAnimation.duration = 1000
iv_animation_img.startAnimation(scaleAnimation)
```

此处列举了一个缩放动画，大小由0到1，再由0到1，动画时长为1000毫秒，然后`iv_animation_img`这个View开始执行ScaleAnimation这个动画。不管是缩放动画，还是平移动画等，都是将animation参数配置好之后，交给View去执行。其实这里还可以通过xml来配置这些参数，原理是类似的。

### <span id="head2">2. 动画流程</span>

因为开始动画是调用的startAnimation方法，所以我们就从这里入手。

```java
//View.java
public void startAnimation(Animation animation) {
    animation.setStartTime(Animation.START_ON_FIRST_FRAME);
    setAnimation(animation);
    invalidateParentCaches();
    invalidate(true);
}

public void setStartTime(long startTimeMillis) {
    mStartTime = startTimeMillis;
    mStarted = mEnded = false;
    mCycleFlip = false;
    mRepeated = 0;
    mMore = true;
}

public void setAnimation(Animation animation) {
    mCurrentAnimation = animation;
    ...
}

protected void invalidateParentCaches() {
    if (mParent instanceof View) {
        ((View) mParent).mPrivateFlags |= PFLAG_INVALIDATED;
    }
}

```

startAnimation方法中，前面的setStartTime、setAnimation、invalidateParentCaches都是对参数进行初始化，invalidateParentCaches给mParent设置了一个标志位`PFLAG_INVALIDATED`。最后一个调用的是invalidate，这个我们熟悉，就是在必要的时候重绘嘛。重绘和动画有什么关系？看一下具体实现

```java
public void invalidate(boolean invalidateCache) {
    invalidateInternal(0, 0, mRight - mLeft, mBottom - mTop, invalidateCache, true);
}

void invalidateInternal(int l, int t, int r, int b, boolean invalidateCache,
        boolean fullInvalidate) {
    ...

    if ((mPrivateFlags & (PFLAG_DRAWN | PFLAG_HAS_BOUNDS)) == (PFLAG_DRAWN | PFLAG_HAS_BOUNDS)
            || (invalidateCache && (mPrivateFlags & PFLAG_DRAWING_CACHE_VALID) == PFLAG_DRAWING_CACHE_VALID)
            || (mPrivateFlags & PFLAG_INVALIDATED) != PFLAG_INVALIDATED
            || (fullInvalidate && isOpaque() != mLastIsOpaque)) {
        ...

        mPrivateFlags |= PFLAG_DIRTY;

        //上面invalidateCache传入的是true，会打上PFLAG_INVALIDATED标记
        if (invalidateCache) {
            mPrivateFlags |= PFLAG_INVALIDATED;
            mPrivateFlags &= ~PFLAG_DRAWING_CACHE_VALID;
        }

        // Propagate the damage rectangle to the parent view.
        final AttachInfo ai = mAttachInfo;
        final ViewParent p = mParent;
        if (p != null && ai != null && l < r && t < b) {
            final Rect damage = ai.mTmpInvalRect;
            damage.set(l, t, r, b);
            //mParent一般是ViewGroup，这里调用了ViewGroup的invalidateChild
            p.invalidateChild(this, damage);
        }

        ...
    }
}
```

invalidate(true)中，感觉好像没干啥，就是调用mParent的invalidateChild，而mParent一般是ViewGroup，这里调用了ViewGroup的invalidateChild。

```java
@Override
public final void invalidateChild(View child, final Rect dirty) {
    final AttachInfo attachInfo = mAttachInfo;
    //1. 开启了硬件加速，走这里
    if (attachInfo != null && attachInfo.mHardwareAccelerated) {
        // HW accelerated fast path
        onDescendantInvalidated(child, child);
        return;
    }

    //2. 没开启硬件加速，走这里
    ViewParent parent = this;
    ...
    do {
        ...
        parent = parent.invalidateChildInParent(location, dirty);
        ...
    } while (parent != null);
}
```

从invalidateChild方法开始，就分流了，开启了硬件加速和未开启硬件加速，走的是不同的逻辑。下面我们分别来分析：

#### <span id="head3">2.1 invalidate(true)</span>

在invalidateChild方法中，开启了硬件加速也就是会走onDescendantInvalidated方法：

```java
public void onDescendantInvalidated(@NonNull View child, @NonNull View target) {
    //如果target带了PFLAG_DRAW_ANIMATION标志，那么把这个标志也附加给当前View的mPrivateFlags
    mPrivateFlags |= (target.mPrivateFlags & PFLAG_DRAW_ANIMATION);
    ...
    if (mParent != null) {
        mParent.onDescendantInvalidated(this, target);
    }
}
```

onDescendantInvalidated中主要是调用mParent.onDescendantInvalidated方法，具体到某个View的话，它的mParent应该是ViewGroup，而ViewGroup的mParent也应该是ViewGroup，相当于沿着View树不断地向上调用父View的onDescendantInvalidated，知道View树的最顶层View。最顶层View，也就是DecorView。在调用DecorView的onDescendantInvalidated方法时，也会去调用mParent.onDescendantInvalidated方法，那么此时的mParent是什么呢？是ViewRootImpl。也就是说，mParent.onDescendantInvalidated最终会调用到ViewRootImpl的onDescendantInvalidated：

```java
//ViewRootImpl.java
@Override
public void onDescendantInvalidated(@NonNull View child, @NonNull View descendant) {
    ...
    invalidate();
}
```

ViewRootImpl的onDescendantInvalidated异常简单，就是调用了下invalidate()。

```java
void invalidate() {
    mDirty.set(0, 0, mWidth, mHeight);
    if (!mWillDrawSoon) {
        scheduleTraversals();
    }
}
```

如果正在执行performTraversals方法，那么mWillDrawSoon会被赋值为true，这里应该是为了避免同一时间多次调用scheduleTraversals。当我们没有在执行performTraversals方法时，mWillDrawSoon为false，此时进入到scheduleTraversals。

```java
void scheduleTraversals() {
    if (!mTraversalScheduled) {
        mTraversalScheduled = true;
        mTraversalBarrier = mHandler.getLooper().getQueue().postSyncBarrier();
        mChoreographer.postCallback(
                Choreographer.CALLBACK_TRAVERSAL, mTraversalRunnable, null);
        notifyRendererOfFramePending();
        pokeDrawLockIfNeeded();
    }
}
```

这个方法大家应该比较熟悉了，它是View三大绘制流程的起点，开启同步屏障，然后通过Choreographer注册vsync信号的观察者，等待着vsync信号的来临，来临之后开始调用performTraversals方法，执行View绘制的三大流程。

不太清楚这块儿的同学可以看之前的文章：

*   [死磕Android\_View工作原理你需要知道的一切](https://github.com/xfhy/Android-Notes/blob/master/Blogs/Android/%E7%B3%BB%E7%BB%9F%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90/%E6%AD%BB%E7%A3%95Android_View%E5%B7%A5%E4%BD%9C%E5%8E%9F%E7%90%86%E4%BD%A0%E9%9C%80%E8%A6%81%E7%9F%A5%E9%81%93%E7%9A%84%E4%B8%80%E5%88%87.md)
*   [Handler同步屏障](https://github.com/xfhy/Android-Notes/blob/master/Blogs/Android/%E7%B3%BB%E7%BB%9F%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90/Handler%E5%90%8C%E6%AD%A5%E5%B1%8F%E9%9A%9C.md)
*   [Choreographer原理及应用](https://github.com/xfhy/Android-Notes/blob/master/Blogs/Android/%E7%B3%BB%E7%BB%9F%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90/Choreographer%E5%8E%9F%E7%90%86%E5%8F%8A%E5%BA%94%E7%94%A8.md)

我们接着分析，当我们调用startAnimation开始动画之后，到现在，还没看到动画相关的东西。仅仅是让View重新走performTraversals。既然是仅仅调用了performTraversals方法，那动画是什么时候执行的？现在只能先猜了，可能动画是在performTraversals中的三大流程中去执行的。

1.  首先看一下是否在performMeasure中执行的：

```java
private void performTraversals() {
    //mLayoutRequested在requestLayout中会被置为true，还有就是第一次执行performTraversals时也会赋值为true
    //mStopped：当时不是Stop相关的生命周期内
    boolean layoutRequested = mLayoutRequested && (!mStopped || mReportNextDraw);
    if (layoutRequested) {
        ...
        windowSizeMayChange |= measureHierarchy(host, lp, res, desiredWindowWidth, desiredWindowHeight);
    }
    ...
}
```

在measureHierarchy内部会执行performTraversals进行协商测量，在执行measureHierarchy之前首先mLayoutRequested得为true才行。mLayoutRequested在requestLayout中会被置为true，还有就是第一次执行performTraversals时也会赋值为true。而动画是从invalidate方法从下往上的，所以这里mLayoutRequested就是false，然后performMeasure不会被执行。

1.  再看一下performLayout是否被执行：

```java
private void performTraversals() {
    //mLayoutRequested在requestLayout中会被置为true，还有就是第一次执行performTraversals时也会赋值为true
    //mStopped：当时不是Stop相关的生命周期内
    boolean layoutRequested = mLayoutRequested && (!mStopped || mReportNextDraw);
    ...
    final boolean didLayout = layoutRequested && (!mStopped || mReportNextDraw);
    if (didLayout) {
        performLayout(lp, mWidth, mHeight);
        ...
    }
    ...
}
```

performLayout和measureHierarchy的执行条件是一样的，也就是performLayout也不会执行。

1.  最后看一下performDraw

```java
private void performTraversals() {
    ...
    boolean cancelDraw = mAttachInfo.mTreeObserver.dispatchOnPreDraw() || !isViewVisible;

    if (!cancelDraw) {
        ...
        performDraw();
    }
    ...
}
```

只要View可见，就会执行performDraw。那我们接下来的重点就是要去理一理performDraw里面的逻辑了。performDraw里面会执行draw方法，draw方法内部

```java
void invalidate() {
    mDirty.set(0, 0, mWidth, mHeight);
    if (!mWillDrawSoon) {
        scheduleTraversals();
    }
}

private boolean draw(boolean fullRedrawNeeded) {
    final Rect dirty = mDirty;
    ...
    if (!dirty.isEmpty() || mIsAnimating || accessibilityFocusDirty) {
        //开启了硬件加速
        if (mAttachInfo.mThreadedRenderer != null && mAttachInfo.mThreadedRenderer.isEnabled()) {
            ...
            mAttachInfo.mThreadedRenderer.draw(mView, mAttachInfo, this);
        }
    }
}
```

在draw方法内部，因为mDirty在invalidate时设置了值，所以这里`!dirty.isEmpty()`肯定是为true的，如果开启了硬件加速（一般都是开启的，从Android4.0开始，以“run fast, smooth, and responsively” 为核心目标对 UI 进行优化，应用默认都开启和使用硬件加速方式加速 UI 的绘制），则会走到硬件加速绘制流程：

```java
//ThreadedRenderer.java
void draw(View view, AttachInfo attachInfo, DrawCallbacks callbacks) {
    final Choreographer choreographer = attachInfo.mViewRootImpl.mChoreographer;
    choreographer.mFrameInfo.markDrawStart();

    updateRootDisplayList(view, callbacks);
    ...
    
    //开始真正的绘制，这里调用的是HardwareRenderer.java的syncAndDrawFrame方法，然后它内部会调用一个native方法（nSyncAndDrawFrame）进行绘制
    int syncResult = syncAndDrawFrame(choreographer.mFrameInfo);
    ...
}

private void updateRootDisplayList(View view, DrawCallbacks callbacks) {
    updateViewTreeDisplayList(view);
    ...
}

private void updateViewTreeDisplayList(View view) {
    view.mPrivateFlags |= View.PFLAG_DRAWN;
    
    //动画开始执行的时候，会把执行动画的那个view的parent view打上一个PFLAG_INVALIDATED标记，其他View则没有。也就是只有执行动画的View的parent View的mRecreateDisplayList为true，其他则为false
    view.mRecreateDisplayList = (view.mPrivateFlags & View.PFLAG_INVALIDATED)
            == View.PFLAG_INVALIDATED;
    //去掉PFLAG_INVALIDATED标记
    view.mPrivateFlags &= ~View.PFLAG_INVALIDATED;
    
    //更新DisplayList
    view.updateDisplayListIfDirty();
    
    //重新将mRecreateDisplayList置为false
    view.mRecreateDisplayList = false;
}
```

走硬件绘制流程时会先走updateRootDisplayList遍历View树更新DisplayList，当然，这里是只更新那些打上`PFLAG_INVALIDATED`标记的view的DisplayList。打上`PFLAG_INVALIDATED`标记的View，也就是执行动画的那个view的parent view，在动画开始执行的时候就打上这个标记了。我们看下具体是怎么更新DisplayList的

```java
/**
 * Gets the RenderNode for the view, and updates its DisplayList (if needed and supported)
 */
public RenderNode updateDisplayListIfDirty() {
    final RenderNode renderNode = mRenderNode;
    if (!canHaveDisplayList()) {
        // can't populate RenderNode, don't try
        return renderNode;
    }

    //之前画出来的东西依然有效，无需重绘 || 该RenderNode没有DisplayList || 需要重新构建DisplayList
    if ((mPrivateFlags & PFLAG_DRAWING_CACHE_VALID) == 0
            || !renderNode.hasDisplayList()
            || (mRecreateDisplayList)) {
        
        //上面分析过，其他与动画不相关的View的mRecreateDisplayList是false   ，
        //所以会走进这个if，然后return 
        // Don't need to recreate the display list, just need to tell our
        // children to restore/recreate theirs
        if (renderNode.hasDisplayList()
                && !mRecreateDisplayList) {
            mPrivateFlags |= PFLAG_DRAWN | PFLAG_DRAWING_CACHE_VALID;
            mPrivateFlags &= ~PFLAG_DIRTY_MASK;
            
            //注意，虽然它自己不用重新构建DisplayList，但如果它是ViewGroup的话，需要把这个这个事件分发下去，让子View也走一遍这个流程
            dispatchGetDisplayList();

            return renderNode; // no work needed
        }

        //动画View的parent会走到这里
        // If we got here, we're recreating it. Mark it as such to ensure that
        // we copy in child display lists into ours in drawChild()
        mRecreateDisplayList = true;

        int width = mRight - mLeft;
        int height = mBottom - mTop;
        int layerType = getLayerType();

        final RecordingCanvas canvas = renderNode.beginRecording(width, height);

        try {
            if (layerType == LAYER_TYPE_SOFTWARE) {
                buildDrawingCache(true);
                Bitmap cache = getDrawingCache(true);
                if (cache != null) {
                    canvas.drawBitmap(cache, 0, 0, mLayerPaint);
                }
            } else {
                //因为是硬件加速，所以会走这里
                computeScroll();

                canvas.translate(-mScrollX, -mScrollY);
                mPrivateFlags |= PFLAG_DRAWN | PFLAG_DRAWING_CACHE_VALID;
                mPrivateFlags &= ~PFLAG_DIRTY_MASK;

                // Fast path for layouts with no backgrounds
                if ((mPrivateFlags & PFLAG_SKIP_DRAW) == PFLAG_SKIP_DRAW) {
                    //ViewGroup走这里
                    dispatchDraw(canvas);
                    drawAutofilledHighlight(canvas);
                    if (mOverlay != null && !mOverlay.isEmpty()) {
                        mOverlay.getOverlayView().draw(canvas);
                    }
                    if (isShowingLayoutBounds()) {
                        debugDrawFocus(canvas);
                    }
                } else {
                    draw(canvas);
                }
            }
        } finally {
            renderNode.endRecording();
            setDisplayListProperties(renderNode);
        }
    } else {
        mPrivateFlags |= PFLAG_DRAWN | PFLAG_DRAWING_CACHE_VALID;
        mPrivateFlags &= ~PFLAG_DIRTY_MASK;
    }
    return renderNode;
}

protected void dispatchGetDisplayList() {
    final int count = mChildrenCount;
    final View[] children = mChildren;
    for (int i = 0; i < count; i++) {
        final View child = children[i];
        if (((child.mViewFlags & VISIBILITY_MASK) == VISIBLE || child.getAnimation() != null)) {
            recreateChildDisplayList(child);
        }
    }
    ...
}

private void recreateChildDisplayList(View child) {
    child.mRecreateDisplayList = (child.mPrivateFlags & PFLAG_INVALIDATED) != 0;
    child.mPrivateFlags &= ~PFLAG_INVALIDATED;
    child.updateDisplayListIfDirty();
    child.mRecreateDisplayList = false;
}
```

在updateDisplayListIfDirty内部，如果是与动画不相关的view的话，则会执行dispatchGetDisplayList()，在dispatchGetDisplayList内部如果当前view是ViewGroup的话，则会遍历自己的子View，子View执行recreateChildDisplayList方法，在里面又执行updateDisplayListIfDirty方法。这样沿着View树逐渐向下传递。而如果mRecreateDisplayList为true，也就是与需要执行动画相关的view的时候，则会走到下面的dispatchDraw里面去。我们重点看下这个

```java
@Override
protected void dispatchDraw(Canvas canvas) {
    final int childrenCount = mChildrenCount;
    final View[] children = mChildren;
    
    ...
    for (int i = 0; i < childrenCount; i++) {
        final int childIndex = getAndVerifyPreorderedIndex(childrenCount, i, customOrder);
        final View child = getAndVerifyPreorderedView(preorderedList, children, childIndex);
        //View可见或者view的child非空，那么开始drawChild
        if ((child.mViewFlags & VISIBILITY_MASK) == VISIBLE || child.getAnimation() != null) {
            more |= drawChild(canvas, child, drawingTime);
        }
    }
    ...
}
protected boolean drawChild(Canvas canvas, View child, long drawingTime) {
    return child.draw(canvas, this, drawingTime);
}

boolean draw(Canvas canvas, ViewGroup parent, long drawingTime) {
    final boolean hardwareAcceleratedCanvas = canvas.isHardwareAccelerated();
    boolean drawingWithRenderNode = mAttachInfo != null
            && mAttachInfo.mHardwareAccelerated
            && hardwareAcceleratedCanvas;

    Transformation transformToApply = null;
    boolean concatMatrix = false;
    final boolean scalingRequired = mAttachInfo != null && mAttachInfo.mScalingRequired;
    //注意，当执行到需执行动画的view时，这个animation是非空的
    final Animation a = getAnimation();
    if (a != null) {
        more = applyLegacyAnimation(parent, drawingTime, a, scalingRequired);
        concatMatrix = a.willChangeTransformationMatrix();
        if (concatMatrix) {
            mPrivateFlags3 |= PFLAG3_VIEW_IS_ANIMATING_TRANSFORM;
        }
        transformToApply = parent.getChildTransformation();
    }
    
    ...
    return more;
}
```

在ViewGroup执行dispatchDraw的内部，会通知自己的各个子View去draw，在draw里面的时候，会执行到applyLegacyAnimation了，看起来就是我们要找的了。

```java
private boolean applyLegacyAnimation(ViewGroup parent, long drawingTime,
        Animation a, boolean scalingRequired) {
    Transformation invalidationTransform;
    final int flags = parent.mGroupFlags;
    final boolean initialized = a.isInitialized();
    if (!initialized) {
        a.initialize(mRight - mLeft, mBottom - mTop, parent.getWidth(), parent.getHeight());
        a.initializeInvalidateRegion(0, 0, mRight - mLeft, mBottom - mTop);
        if (mAttachInfo != null) a.setListenerHandler(mAttachInfo.mHandler);
        //开始执行动画
        onAnimationStart();
    }

    final Transformation t = parent.getChildTransformation();
    //这里是动画的核心
    boolean more = a.getTransformation(drawingTime, t, 1f);
    ...
    return more;
}

public boolean getTransformation(long currentTime, Transformation outTransformation) {
    //记录动画第一帧开始的时间
    if (mStartTime == -1) {
        mStartTime = currentTime;
    }
    
    //偏移量，默认是0
    final long startOffset = getStartOffset();
    //动画时长
    final long duration = mDuration;
    
    //动画进度
    float normalizedTime;
    if (duration != 0) {
        normalizedTime = ((float) (currentTime - (mStartTime + startOffset))) /
                (float) duration;
    } else {
        // time is a step-change with a zero duration
        normalizedTime = currentTime < mStartTime ? 0.0f : 1.0f;
    }

    final boolean expired = normalizedTime >= 1.0f || isCanceled();
    mMore = !expired;

    if (!mFillEnabled) normalizedTime = Math.max(Math.min(normalizedTime, 1.0f), 0.0f);

    if ((normalizedTime >= 0.0f || mFillBefore) && (normalizedTime <= 1.0f || mFillAfter)) {
        ...

        if (mFillEnabled) normalizedTime = Math.max(Math.min(normalizedTime, 1.0f), 0.0f);

        if (mCycleFlip) {
            normalizedTime = 1.0f - normalizedTime;
        }
        
        //根据插值器计算动画进度
        final float interpolatedTime = mInterpolator.getInterpolation(normalizedTime);
        //应用动画效果
        applyTransformation(interpolatedTime, outTransformation);
    }

    if (expired) {
        //重复次数已经达成，或者已经取消
        if (mRepeatCount == mRepeated || isCanceled()) {
            if (!mEnded) {
                mEnded = true;
                guard.close();
                fireAnimationEnd();
            }
        } else {
            //重复次数不足
            if (mRepeatCount > 0) {
                mRepeated++;
            }

            if (mRepeatMode == REVERSE) {
                mCycleFlip = !mCycleFlip;
            }
                
            //将开始时间重置
            mStartTime = -1;
            mMore = true;

            fireAnimationRepeat();
        }
    }
    
    //如果动画未执行完，则返回true，继续invalidate，执行下一次动画
    if (!mMore && mOneMoreTime) {
        mOneMoreTime = false;
        return true;
    }

    return mMore;
}

```

在applyLegacyAnimation内部，首先是通知外面动画开始了。然后执行getTransformation()，这个是动画的核心部分。它内部主要做了以下几件事：

1. 记录动画第一帧的时间
2. 根据当前时间和第一帧的时间的差来计算当前动画的进度
3. 根据插值器计算动画的实际进度
4. 使用applyTransformation应用动画效果
5. 判断是否为重复动画，重复动画如果没执行到足够的次数，则需要重置，然后再次执行
6. 最后将是否需要继续执行动画给return回去

这里面的applyTransformation方法是用来应用动画效果的，它是Animation的方法，然后不同的Animation子类有自己相应的实现，下面我举个例子，看一下ScaleAnimation的实现

```java
@Override
protected void applyTransformation(float interpolatedTime, Transformation t) {
    float sx = 1.0f;
    float sy = 1.0f;
    float scale = getScaleFactor();

    if (mFromX != 1.0f || mToX != 1.0f) {
        sx = mFromX + ((mToX - mFromX) * interpolatedTime);
    }
    if (mFromY != 1.0f || mToY != 1.0f) {
        sy = mFromY + ((mToY - mFromY) * interpolatedTime);
    }

    if (mPivotX == 0 && mPivotY == 0) {
        t.getMatrix().setScale(sx, sy);
    } else {
        t.getMatrix().setScale(sx, sy, scale * mPivotX, scale * mPivotY);
    }
}
```

内部主要是利用Matrix去做一些运算，主要是算法相关的，我没继续深入了。

咱们再回到getTransformation的返回值上面来，如果还需要执行动画则会返回true。这个返回值是在上面的applyLegacyAnimation里面被接收到

```java
private boolean applyLegacyAnimation(ViewGroup parent, long drawingTime,
            Animation a, boolean scalingRequired) {
    ...

    final Transformation t = parent.getChildTransformation();
    //执行getTransformation并拿到返回值
    boolean more = a.getTransformation(drawingTime, t, 1f);
    if (scalingRequired && mAttachInfo.mApplicationScale != 1f) {
        if (parent.mInvalidationTransformation == null) {
            parent.mInvalidationTransformation = new Transformation();
        }
        invalidationTransform = parent.mInvalidationTransformation;
        a.getTransformation(drawingTime, invalidationTransform, 1f);
    } else {
        invalidationTransform = t;
    }
    
    //如果需要继续执行动画
    if (more) {
        //该动画是否影响视图的边界，这个是Animation的方法，这个方法默认返回true，只有在AlphaAnimation中才返回false，因为alpha动画不会改变视图边界
        
        //在下面的逻辑内部都会将parent的mPrivateFlags赋值上PFLAG_DRAW_ANIMATION这个flag，然后调用parent的invalidate，继续执行下一帧动画
        if (!a.willChangeBounds()) {
            if ((flags & (ViewGroup.FLAG_OPTIMIZE_INVALIDATE | ViewGroup.FLAG_ANIMATION_DONE)) ==
                    ViewGroup.FLAG_OPTIMIZE_INVALIDATE) {
                parent.mGroupFlags |= ViewGroup.FLAG_INVALIDATE_REQUIRED;
            } else if ((flags & ViewGroup.FLAG_INVALIDATE_REQUIRED) == 0) {
                // The child need to draw an animation, potentially offscreen, so
                // make sure we do not cancel invalidate requests
                parent.mPrivateFlags |= PFLAG_DRAW_ANIMATION;
                parent.invalidate(mLeft, mTop, mRight, mBottom);
            }
        } else {
            if (parent.mInvalidateRegion == null) {
                parent.mInvalidateRegion = new RectF();
            }
            final RectF region = parent.mInvalidateRegion;
            a.getInvalidateRegion(0, 0, mRight - mLeft, mBottom - mTop, region,
                    invalidationTransform);

            // The child need to draw an animation, potentially offscreen, so
            // make sure we do not cancel invalidate requests
            parent.mPrivateFlags |= PFLAG_DRAW_ANIMATION;

            final int left = mLeft + (int) region.left;
            final int top = mTop + (int) region.top;
            parent.invalidate(left, top, left + (int) (region.width() + .5f),
                    top + (int) (region.height() + .5f));
        }
    }
    return more;
}
```

在applyLegacyAnimation里面，我们执行了getTransformation并拿到了返回值。如果需要继续执行动画，则会给parent的mPrivateFlags赋值上`PFLAG_DRAW_ANIMATION`这个flag，然后调用parent的invalidate，继续下一帧动画的执行，相当于把之前的流程再跑一遍。

**现在，我们理清了。某个View需要执行动画时，先是初始化好一些基本信息，然后不是立马执行动画，而是走到ViewRootImpl里面注册VSYNC信号，等到下一次VSYNC来临时执行scheduleTraversals方法，在里面执行View的三大流程。但其实measure和layout没有执行到，因为不需要它们参与。在draw的过程中，顺便把动画给执行了，一次只执行一帧的动画，如果动画没有执行完，则调用invalidate继续下一帧动画的执行。在draw过程中也进行了优化，只有参与动画执行的view才需要走draw流程。**

### <span id="head4">3. setFillAfter</span>

众所周知，View 动画区别于属性动画的就是 View 动画并不会对这个 View 的属性值做修改，比如平移动画，平移之后 View 还是在原来的位置上，实际位置并不会随动画的执行而移动，这是什么原理？

首先，我们平时使用setFillAfter时是调用的Animation对象的方法，那么直接进Animation看一下

```java
boolean mFillAfter = false;
public boolean getFillAfter() {
    return mFillAfter;
}
public void setFillAfter(boolean fillAfter) {
    mFillAfter = fillAfter;
}
public boolean getTransformation(long currentTime, Transformation outTransformation) {
    if (mStartTime == -1) {
        mStartTime = currentTime;
    }
    
    final long startOffset = getStartOffset();
    final long duration = mDuration;
    float normalizedTime;
    if (duration != 0) {
        normalizedTime = ((float) (currentTime - (mStartTime + startOffset))) /
                (float) duration;
    } else {
        // time is a step-change with a zero duration
        normalizedTime = currentTime < mStartTime ? 0.0f : 1.0f;
    }
    
    final boolean expired = normalizedTime >= 1.0f || isCanceled();
    mMore = !expired;
    
    if (!mFillEnabled) normalizedTime = Math.max(Math.min(normalizedTime, 1.0f), 0.0f);
    
    if ((normalizedTime >= 0.0f || mFillBefore) && (normalizedTime <= 1.0f || mFillAfter)) {
        ...
        
        if (mFillEnabled) normalizedTime = Math.max(Math.min(normalizedTime, 1.0f), 0.0f);
    
        final float interpolatedTime = mInterpolator.getInterpolation(normalizedTime);
        applyTransformation(interpolatedTime, outTransformation);
    }
    ...
}
```
Animation里面有mFillAfter属性和它的getter、setter方法，同时在getTransformation中也用到了这个属性，可能会走到applyTransformation里面的逻辑去。

再搜索一下getFillAfter使用的地方，发现在ViewGroup的finishAnimatingView中使用到了

```java
void finishAnimatingView(final View view, Animation animation) {
    final ArrayList<View> disappearingChildren = mDisappearingChildren;
    if (disappearingChildren != null) {
        if (disappearingChildren.contains(view)) {
            disappearingChildren.remove(view);

            if (view.mAttachInfo != null) {
                view.dispatchDetachedFromWindow();
            }

            view.clearAnimation();
            mGroupFlags |= FLAG_INVALIDATE_REQUIRED;
        }
    }

    if (animation != null && !animation.getFillAfter()) {
        view.clearAnimation();
    }

    if ((view.mPrivateFlags & PFLAG_ANIMATION_STARTED) == PFLAG_ANIMATION_STARTED) {
        view.onAnimationEnd();
        // Should be performed by onAnimationEnd() but this avoid an infinite loop,
        // so we'd rather be safe than sorry
        view.mPrivateFlags &= ~PFLAG_ANIMATION_STARTED;
        // Draw one more frame after the animation is done
        mGroupFlags |= FLAG_INVALIDATE_REQUIRED;
    }
}
```

这个parent.finishAnimatingView，是在View的`boolean draw(Canvas canvas, ViewGroup parent, long drawingTime)`中被调用的。如果不是fillAfter，则会调用`view.clearAnimation();`，看起来应该就是我们要找的了。

```java
//View.java
public void clearAnimation() {
    if (mCurrentAnimation != null) {
        mCurrentAnimation.detach();
    }
    mCurrentAnimation = null;
    invalidateParentIfNeeded();
}

protected void invalidateParentIfNeeded() {
    if (isHardwareAccelerated() && mParent instanceof View) {
        ((View) mParent).invalidate(true);
    }
}
```

在`View.clearAnimation()`中会把Animation属性清空，然后调用invalidateParentIfNeeded，接着会触发`invalidate(true)`，接着会重新走一遍ViewRootImpl的performTraversals，然后走三大流程，其中measure和layout不会走，draw流程也只会走View动画相关的View，因为没有了Animation，那么就依然还是画在原来的位置了。

如果设置了fillAfter则不会走最后这一步，还是在原来的位置上。

### <span id="head5">4. View动画会导致measure吗？</span>

既然 View 动画不会改变 View 的属性值，那么如果是缩放动画时，View 需要重新执行测量操作么？

从我们上面的源码分析中，我们发现，其实是不会走measure和layout的。


*   Android 屏幕绘制机制及硬件加速：https://blog.csdn.net/qian520ao/article/details/81144167
*   Android GPU硬件加速渲染流程（上）：<https://zhuanlan.zhihu.com/p/464492155>
*   Android GPU硬件加速渲染流程（下）：<https://zhuanlan.zhihu.com/p/464564859>
*   软件绘制 & 硬件加速绘制 【DisplayList & RenderNode】<https://juejin.cn/post/7128779284503592991>
*   硬件加速绘制基础知识   <https://juejin.cn/post/7129330919990624269>
*   View 动画 Animation 运行原理解析：<https://www.cnblogs.com/dasusu/p/8287822.html>