
## 1. 前言

首先,LPL赛区S9再度夺冠,让我们恭喜FPX凤凰涅槃!

好长好长一段时间没有写博客了,中间经历了很多很多事. 比较庆幸的是找到了一份满意的工作.现在工作空闲之余,又可以写写博客归纳总结了.

图片加载可能是现在所有APP都必备的,当然有很多选择,可以自己写一个库用来展示网络图片.也可以用Glide,Fresco,Picasso等等.Glide由于我们公司在用,而且这是谷歌也推荐的一个图片加载库,用了也很久了,一直没有去研究它的底层实现逻辑.这次一定要好好研究研究.毕竟,需要用到图片加载的地方实在太多了.


关于如何阅读源码,郭神以前总结过8个字:抽丝剥茧、点到即止.意思就是我们在看的时候,抓关键,主流程,不要沉迷在代码细节中无法自拔.本篇文章主要着重于展示网络图片主流程,代码细节就不展开了,实在是太庞大太庞大了,而且细节贼多....

查看Glide源码的方式很简单,新建一个demo,然后通过gradle引入Glide,然后就可以愉快的查看源码了.

ps: 下面所用到的源码是属于Glide 4.8.0的,引入Glide: `implementation 'com.github.bumptech.glide:glide:4.8.0'`

## 2. 阅读前准备

总所周知,Glide加载图片的基本方式是`Glide.with(context).load(url).into(imageView);`,三步走. 那么我们阅读主流程也是跟着这三步走,去看一下主流程是怎么实现的.

## 3. with() 

鼠标左键+Ctrl,点击with方法.

```java
public static RequestManager with(@NonNull Activity activity) {
    //分析2
    return getRetriever(activity).get(activity);
}
public static RequestManager with(@NonNull FragmentActivity activity) {
    return getRetriever(activity).get(activity);
}
public static RequestManager with(@NonNull Fragment fragment) {
    return getRetriever(fragment.getActivity()).get(fragment);
}
public static RequestManager with(@NonNull View view) {
    return getRetriever(view.getContext()).get(view);
}

private static RequestManagerRetriever getRetriever(@Nullable Context context) {
    //分析1 Glide单例 
    return Glide.get(context).getRequestManagerRetriever();
}
public RequestManagerRetriever getRequestManagerRetriever() {
    return requestManagerRetriever;
}
```

首先分析1处进行Glide初始化,它其实里面是通过GlideBuilder进行的初始化
```java
Glide build(@NonNull Context context) {
    //加载资源线程池  包括从网络加载
    if (sourceExecutor == null) {
      sourceExecutor = GlideExecutor.newSourceExecutor();
    }

    //磁盘缓存线程池
    if (diskCacheExecutor == null) {
      diskCacheExecutor = GlideExecutor.newDiskCacheExecutor();
    }

    //动画线程池
    if (animationExecutor == null) {
      animationExecutor = GlideExecutor.newAnimationExecutor();
    }

    if (memorySizeCalculator == null) {
      memorySizeCalculator = new MemorySizeCalculator.Builder(context).build();
    }

    if (connectivityMonitorFactory == null) {
      connectivityMonitorFactory = new DefaultConnectivityMonitorFactory();
    }

    if (bitmapPool == null) {
      int size = memorySizeCalculator.getBitmapPoolSize();
      if (size > 0) {
        bitmapPool = new LruBitmapPool(size);
      } else {
        bitmapPool = new BitmapPoolAdapter();
      }
    }

    if (arrayPool == null) {
      arrayPool = new LruArrayPool(memorySizeCalculator.getArrayPoolSizeInBytes());
    }

    if (memoryCache == null) {
      memoryCache = new LruResourceCache(memorySizeCalculator.getMemoryCacheSize());
    }

    if (diskCacheFactory == null) {
      diskCacheFactory = new InternalCacheDiskCacheFactory(context);
    }

    if (engine == null) {
      //注意,这里有一个引擎,后面会使用到
      engine =
          new Engine(
              memoryCache,
              diskCacheFactory,
              diskCacheExecutor,
              sourceExecutor,
              GlideExecutor.newUnlimitedSourceExecutor(),
              GlideExecutor.newAnimationExecutor(),
              isActiveResourceRetentionAllowed);
    }

    RequestManagerRetriever requestManagerRetriever =
        new RequestManagerRetriever(requestManagerFactory);

    return new Glide(
        context,
        engine,
        memoryCache,
        bitmapPool,
        arrayPool,
        requestManagerRetriever,
        connectivityMonitorFactory,
        logLevel,
        defaultRequestOptions.lock(),
        defaultTransitionOptions);
}
```

Glide就是初始化一些线程池,引擎什么的,稍后会用到.

再从分析2处可以看到,Glide 有很多重载方法,但是都是调用的RequestManagerRetriever的get方法,下面我们随便看一个RequestManagerRetriever的get重载方法

```java
public RequestManager get(@NonNull Activity activity) {
    //如果是子线程,那么生命周期就很长,和application一样,当然,这些是细节,别去影响主流程的阅读
    if (Util.isOnBackgroundThread()) {
      return get(activity.getApplicationContext());
    } else {
      assertNotDestroyed(activity);
      android.app.FragmentManager fm = activity.getFragmentManager();
      return fragmentGet(
          activity, fm, /*parentHint=*/ null, isActivityVisible(activity));
    }
  }
public RequestManager get(@NonNull Context context) {
    if (context == null) {
      throw new IllegalArgumentException("You cannot start a load on a null Context");
    } else if (Util.isOnMainThread() && !(context instanceof Application)) {
      //这些都会调用get方法  
      if (context instanceof FragmentActivity) {
        return get((FragmentActivity) context);
      } else if (context instanceof Activity) {
        return get((Activity) context);
      } else if (context instanceof ContextWrapper) {
        return get(((ContextWrapper) context).getBaseContext());
      }
    }

    //创建一个生命周期是application相同的RequestManager
    return getApplicationManager(context);
}

public RequestManager get(@NonNull FragmentActivity activity) {
    if (Util.isOnBackgroundThread()) {
      return get(activity.getApplicationContext());
    } else {
      assertNotDestroyed(activity);
      FragmentManager fm = activity.getSupportFragmentManager();
      return supportFragmentGet(
          activity, fm, /*parentHint=*/ null, isActivityVisible(activity));
    }
}

private RequestManager getApplicationManager(@NonNull Context context) {
    if (applicationManager == null) {
      synchronized (this) {
        if (applicationManager == null) {
          Glide glide = Glide.get(context.getApplicationContext());
          applicationManager =
              factory.build(
                  glide,
                  new ApplicationLifecycle(),
                  new EmptyRequestManagerTreeNode(),
                  context.getApplicationContext());
        }
      }
    }
    return applicationManager;
}

```

上面得分2种情况,一种是非application,一种是传入的是application.这两种情况下的生命周期是不太一样的,非application的会调用下面的fragmentGet方法创建一个fragment观察activity的生命周期,即activity销毁,那么图片就不会继续加载,释放资源等.而传入的是application的话,生命周期就和application一样了.

```java
private RequestManager fragmentGet(@NonNull Context context,
      @NonNull android.app.FragmentManager fm,
      @Nullable android.app.Fragment parentHint,
      boolean isParentVisible) {
    RequestManagerFragment current = getRequestManagerFragment(fm, parentHint, isParentVisible);
    RequestManager requestManager = current.getRequestManager();
    if (requestManager == null) {
      Glide glide = Glide.get(context);
      requestManager =
          factory.build(
              glide, current.getGlideLifecycle(), current.getRequestManagerTreeNode(), context);
      //给这个fragment设置一个RequestManager
      current.setRequestManager(requestManager);
    }
    return requestManager;
}

private RequestManagerFragment getRequestManagerFragment(
      @NonNull final android.app.FragmentManager fm,
      @Nullable android.app.Fragment parentHint,
      boolean isParentVisible) {
    ...
    //构建一个空fragment
    RequestManagerFragment current = new RequestManagerFragment();
    current.setParentFragmentHint(parentHint);
    if (isParentVisible) {
        current.getGlideLifecycle().onStart();
    }
    fm.beginTransaction().add(current, FRAGMENT_TAG).commitAllowingStateLoss();
    ...
    return current;
}

```
可以看到,如果传入的是非application那么就去构建一个fragment用于观察加载的那张图片的所在activity的生命周期,如果已经销毁了,那么肯定就没必要再加载了.最后with返回的是RequestManager.with这里知道这些就OK了.

## 4. load()

再开看load方法,它是with返回的RequestManager里面的方法.

```java
public RequestBuilder<Drawable> load(@Nullable String string) {
    return asDrawable().load(string);
  }
public RequestBuilder<Drawable> asDrawable() {
    return as(Drawable.class);
  }
public <ResourceType> RequestBuilder<ResourceType> as(
      @NonNull Class<ResourceType> resourceClass) {
    return new RequestBuilder<>(glide, this, resourceClass, context);
}
```

load方法里面调用的asDrawable(),主要是初始化RequestBuilder

```java
protected RequestBuilder(Glide glide, RequestManager requestManager,
      Class<TranscodeType> transcodeClass, Context context) {
    this.glide = glide;
    this.requestManager = requestManager;
    //注意,这里传入的是Drawable.class
    this.transcodeClass = transcodeClass;
    this.defaultRequestOptions = requestManager.getDefaultRequestOptions();
    this.context = context;
    this.transitionOptions = requestManager.getDefaultTransitionOptions(transcodeClass);
    this.requestOptions = defaultRequestOptions;
    this.glideContext = glide.getGlideContext();
}
public RequestBuilder<TranscodeType> load(@Nullable String string) {
    return loadGeneric(string);
  }
private RequestBuilder<TranscodeType> loadGeneric(@Nullable Object model) {
    this.model = model;
    isModelSet = true;
    return this;
}
```

然后调用load进行model的赋值.load流程走完了,就是创建了一个RequestBuilder

## 5. into() 

下面就比较复杂了,我找网络通信的代码找了特别久才找到了,看Glide源码看得欲仙欲死.如郭神所说,into方法里面有着成吨的操作.各种复杂逻辑.前面load流程走完了是返回了一个RequestBuilder,那么into方法就是在RequestBuilder里面的.

```java
public ViewTarget<ImageView, TranscodeType> into(@NonNull ImageView view) {
    Util.assertMainThread();
    Preconditions.checkNotNull(view);

    RequestOptions requestOptions = this.requestOptions;
    if (!requestOptions.isTransformationSet()
        && requestOptions.isTransformationAllowed()
        && view.getScaleType() != null) {
      switch (view.getScaleType()) {
        case CENTER_CROP:
          requestOptions = requestOptions.clone().optionalCenterCrop();
          break;
        case CENTER_INSIDE:
          requestOptions = requestOptions.clone().optionalCenterInside();
          break;
        case FIT_CENTER:
        case FIT_START:
        case FIT_END:
          requestOptions = requestOptions.clone().optionalFitCenter();
          break;
        case FIT_XY:
          requestOptions = requestOptions.clone().optionalCenterInside();
          break;
        case CENTER:
        case MATRIX:
        default:
          // Do nothing.
      }
    }

    //这里的transcodeClass是前面的Drawable.class
    return into(
        glideContext.buildImageViewTarget(view, transcodeClass),
        /*targetListener=*/ null,
        requestOptions);
}
```

into成吨的逻辑,从最后一行开始.首先进入GlideContext的buildImageViewTarget方法.

```java
public <X> ViewTarget<ImageView, X> buildImageViewTarget(
      @NonNull ImageView imageView, @NonNull Class<X> transcodeClass) {
    return imageViewTargetFactory.buildTarget(imageView, transcodeClass);
  }

public class ImageViewTargetFactory {
  @NonNull
  @SuppressWarnings("unchecked")
  public <Z> ViewTarget<ImageView, Z> buildTarget(@NonNull ImageView view,
      @NonNull Class<Z> clazz) {
    if (Bitmap.class.equals(clazz)) {
      return (ViewTarget<ImageView, Z>) new BitmapImageViewTarget(view);
    } else if (Drawable.class.isAssignableFrom(clazz)) {
      return (ViewTarget<ImageView, Z>) new DrawableImageViewTarget(view);
    } else {
      throw new IllegalArgumentException(
          "Unhandled class: " + clazz + ", try .as*(Class).transcode(ResourceTranscoder)");
    }
  }
}

```
毫无疑问,这里创建的是DrawableImageViewTarget.然后DrawableImageViewTarget被作为参数传入into方法.

```java
private <Y extends Target<TranscodeType>> Y into(
      @NonNull Y target,
      @Nullable RequestListener<TranscodeType> targetListener,
      @NonNull RequestOptions options) {
    
    ...
    //分析1 
    Request request = buildRequest(target, targetListener, options);
    ...

    requestManager.clear(target);
    target.setRequest(request);
    //分析2
    requestManager.track(target, request);

    return target;
  }
```

分析1处,通过buildRequest构建一个Request,最后会走到RequestBuilder的obtainRequest方法构建一个SingleRequest.

```java
private Request obtainRequest(
      Target<TranscodeType> target,
      RequestListener<TranscodeType> targetListener,
      RequestOptions requestOptions,
      RequestCoordinator requestCoordinator,
      TransitionOptions<?, ? super TranscodeType> transitionOptions,
      Priority priority,
      int overrideWidth,
      int overrideHeight) {
    return SingleRequest.obtain(
        context,
        glideContext,
        //String
        model,
        //Drawable.class
        transcodeClass,
        //options 
        requestOptions,
        //宽高
        overrideWidth,
        overrideHeight,
        priority,
        //DrawableImageViewTarget
        target,
        targetListener,
        requestListeners,
        requestCoordinator,
        glideContext.getEngine(),
        transitionOptions.getTransitionFactory());
  }
```

省略了很多处理缩略图的逻辑,直接到最后构建SingleRequest. 这个Request也就是我们要进行的请求,猜测大部分逻辑都是在这里面.

继续回到分析2处,`requestManager.track(target, request);`
```java
void track(@NonNull Target<?> target, @NonNull Request request) {
    targetTracker.track(target);
    requestTracker.runRequest(request);
  }

//RequestTracker.java
public void runRequest(@NonNull Request request) {
    requests.add(request);
    if (!isPaused) {
      //开始搞事情
      request.begin();
    } else {
      request.clear();
      pendingRequests.add(request);
    }
  }
```

调用了Request的begin,看样子是要开始了,上面分析了这里是SingleRequest,所以直接看SingleRequest的begin().

```java
public void begin() {
    ......
    if (status == Status.COMPLETE) {
      //已加载完成   回调
      onResourceReady(resource, DataSource.MEMORY_CACHE);
      return;
    }

    status = Status.WAITING_FOR_SIZE;
    //测量一下ImageView的大小
    if (Util.isValidDimensions(overrideWidth, overrideHeight)) {
      onSizeReady(overrideWidth, overrideHeight);
    } else {
      target.getSize(this);
    }

    if ((status == Status.RUNNING || status == Status.WAITING_FOR_SIZE)
        && canNotifyStatusChanged()) {
      target.onLoadStarted(getPlaceholderDrawable());
    }
  }
```

测量一下ImageView的大小,如果在调用Glide加载图片时设置override设置宽高,那么直接会走onSizeReady方法处.如果没有写,那么走`target.getSize(this);`测量一下宽高,然后在里面还是会调用SingleRequest的onSizeReady()方法.

```java
public void onSizeReady(int width, int height) {
    ......
    status = Status.RUNNING;

    float sizeMultiplier = requestOptions.getSizeMultiplier();
    this.width = maybeApplySizeMultiplier(width, sizeMultiplier);
    this.height = maybeApplySizeMultiplier(height, sizeMultiplier);
    
    //开始用引擎
    loadStatus = engine.load(
        glideContext,
        model,
        requestOptions.getSignature(),
        this.width,
        this.height,
        requestOptions.getResourceClass(),
        transcodeClass,
        priority,
        requestOptions.getDiskCacheStrategy(),
        requestOptions.getTransformations(),
        requestOptions.isTransformationRequired(),
        requestOptions.isScaleOnlyOrNoTransform(),
        requestOptions.getOptions(),
        requestOptions.isMemoryCacheable(),
        requestOptions.getUseUnlimitedSourceGeneratorsPool(),
        requestOptions.getUseAnimationPool(),
        requestOptions.getOnlyRetrieveFromCache(),
        this);
}
```

开始用引擎load

```java
public <R> LoadStatus load(
      GlideContext glideContext,
      Object model,
      Key signature,
      int width,
      int height,
      Class<?> resourceClass,
      Class<R> transcodeClass,
      Priority priority,
      DiskCacheStrategy diskCacheStrategy,
      Map<Class<?>, Transformation<?>> transformations,
      boolean isTransformationRequired,
      boolean isScaleOnlyOrNoTransform,
      Options options,
      boolean isMemoryCacheable,
      boolean useUnlimitedSourceExecutorPool,
      boolean useAnimationPool,
      boolean onlyRetrieveFromCache,
      ResourceCallback cb) {

    EngineKey key = keyFactory.buildKey(model, signature, width, height, transformations,
        resourceClass, transcodeClass, options);

    //从弱引用中找,有就直接返回
    EngineResource<?> active = loadFromActiveResources(key, isMemoryCacheable);
    if (active != null) {
      cb.onResourceReady(active, DataSource.MEMORY_CACHE);
      if (VERBOSE_IS_LOGGABLE) {
        logWithTimeAndKey("Loaded resource from active resources", startTime, key);
      }
      return null;
    }

    //缓存中
    EngineResource<?> cached = loadFromCache(key, isMemoryCacheable);
    if (cached != null) {
      cb.onResourceReady(cached, DataSource.MEMORY_CACHE);
      if (VERBOSE_IS_LOGGABLE) {
        logWithTimeAndKey("Loaded resource from cache", startTime, key);
      }
      return null;
    }

    //查找之前缓存的EngineJob
    EngineJob<?> current = jobs.get(key, onlyRetrieveFromCache);
    if (current != null) {
      current.addCallback(cb);
      if (VERBOSE_IS_LOGGABLE) {
        logWithTimeAndKey("Added to existing load", startTime, key);
      }
      return new LoadStatus(cb, current);
    }

    //engineJob是为decodeJob干事情的,管理下载过程以及状态
    EngineJob<R> engineJob =
        engineJobFactory.build(
            key,
            isMemoryCacheable,
            useUnlimitedSourceExecutorPool,
            useAnimationPool,
            onlyRetrieveFromCache);

    DecodeJob<R> decodeJob =
        decodeJobFactory.build(
            glideContext,
            model,
            key,
            signature,
            width,
            height,
            resourceClass,
            transcodeClass,
            priority,
            diskCacheStrategy,
            transformations,
            isTransformationRequired,
            isScaleOnlyOrNoTransform,
            onlyRetrieveFromCache,
            options,
            engineJob);

    jobs.put(key, engineJob);

    //注册ResourceCallback
    engineJob.addCallback(cb);
    //开始真正的工作
    engineJob.start(decodeJob);

    return new LoadStatus(cb, engineJob);
}
```

首先是从各种缓存中拿之前的数据,有则返回,没有则创建DecodeJob开始工作.

```java
//EngineJob.java
public void start(DecodeJob<R> decodeJob) {
    this.decodeJob = decodeJob;
    GlideExecutor executor = decodeJob.willDecodeFromCache()
        ? diskCacheExecutor
        : getActiveSourceExecutor();
    executor.execute(decodeJob);
}
```

我们这里暂时不考虑缓存的情况,那么使用的这里使用的GlideExecutor是GlideBuilder的build方法中初始化的`sourceExecutor = GlideExecutor.newSourceExecutor();`其实就是一个线程池. 然后DecodeJob是Runnable,放到线程池中去执行,所以我们知道找重点,去DecodeJob的run方法看

```java
public void run() {
    DataFetcher<?> localFetcher = currentFetcher;
    try {
        //已经取消
      if (isCancelled) {
        notifyFailed();
        return;
      }

      //重点 这里是执行
      runWrapped();
    } catch (Throwable t) {
    } finally {
    }
  }

private enum Stage {
    /** The initial stage. */
    INITIALIZE,
    /** Decode from a cached resource. */
    RESOURCE_CACHE,
    /** Decode from cached source data. */
    DATA_CACHE,
    /** Decode from retrieved source. */
    SOURCE,
    /** Encoding transformed resources after a successful load. */
    ENCODE,
    /** No more viable stages. */
    FINISHED,
}

private void runWrapped() {
    //runReason在DecodeJob初始化的时候初始值是INITIALIZE,上面没有带大家看,这不是重点.
    switch (runReason) {
      case INITIALIZE:
        //获取下一个state 
        stage = getNextStage(Stage.INITIALIZE);
        //这里会去获取一个SourceGenerator
        currentGenerator = getNextGenerator();
        runGenerators();
        break;
      case SWITCH_TO_SOURCE_SERVICE:
        runGenerators();
        break;
      case DECODE_DATA:
        decodeFromRetrievedData();
        break;
      default:
        throw new IllegalStateException("Unrecognized run reason: " + runReason);
    }
}

//一次完整的请求,会把这里的都走完.
private DataFetcherGenerator getNextGenerator() {
    switch (stage) {
      case RESOURCE_CACHE:
        return new ResourceCacheGenerator(decodeHelper, this);
      case DATA_CACHE:
        return new DataCacheGenerator(decodeHelper, this);
      case SOURCE:
        //会走到这里
        return new SourceGenerator(decodeHelper, this);
      case FINISHED:
        return null;
      default:
        throw new IllegalStateException("Unrecognized stage: " + stage);
    }
}

private void runGenerators() {
    currentThread = Thread.currentThread();
    startFetchTime = LogTime.getLogTime();
    boolean isStarted = false;
    while (!isCancelled && currentGenerator != null
        //重点
        && !(isStarted = currentGenerator.startNext())) {
      stage = getNextStage(stage);
      currentGenerator = getNextGenerator();

      if (stage == Stage.SOURCE) {
        reschedule();
        return;
      }
    }
    // We've run out of stages and generators, give up.
    if ((stage == Stage.FINISHED || isCancelled) && !isStarted) {
      notifyFailed();
    }
}

```

Glide定义了几个步骤,在枚举类Stage里面.这是每一步的状态,当执行完一个状态的时候,又去获取下一个状态进行执行相应的逻辑.在runGenerators方法里面有一个while控制.我们第一步是SourceGenerator,所以会走到SourceGenerator的startNext()里面.

```java
//SourceGenerator.java
public boolean startNext() {
    if (dataToCache != null) {
      Object data = dataToCache;
      dataToCache = null;
      cacheData(data);
    }

    //有缓存
    if (sourceCacheGenerator != null && sourceCacheGenerator.startNext()) {
      return true;
    }
    sourceCacheGenerator = null;

    loadData = null;
    boolean started = false;
    while (!started && hasNextModelLoader()) {
      loadData = helper.getLoadData().get(loadDataListIndex++);
      if (loadData != null
          && (helper.getDiskCacheStrategy().isDataCacheable(loadData.fetcher.getDataSource())
          || helper.hasLoadPath(loadData.fetcher.getDataClass()))) {
        started = true;
        //这里的fetcher是HttpUrlFetcher
        loadData.fetcher.loadData(helper.getPriority(), this);
      }
    }
    return started;
}
```

主流程是根据HttpUrlFetcher去加载数据,这里就不分析为啥HttpUrlFetcher,比较麻烦,篇幅收不住.

```java
//HttpUrlFetcher.java
public void loadData(@NonNull Priority priority,
      @NonNull DataCallback<? super InputStream> callback) {
    try {
      //看情况,这个方法是获取到了网络数据了  盲猜应该是请求网络了
      InputStream result = loadDataWithRedirects(glideUrl.toURL(), 0, null, glideUrl.getHeaders());
      //将数据返回回去
      callback.onDataReady(result);
    } catch (IOException e) {
      callback.onLoadFailed(e);
    } finally {
    }
}
```

终于,感觉要开始请求网络了,并且结果还通过回调回去了.来看一下loadDataWithRedirects方法

```java
private InputStream loadDataWithRedirects(URL url, int redirects, URL lastUrl,
      Map<String, String> headers) throws IOException {
    if (redirects >= MAXIMUM_REDIRECTS) {
      throw new HttpException("Too many (> " + MAXIMUM_REDIRECTS + ") redirects!");
    } else {
      // Comparing the URLs using .equals performs additional network I/O and is generally broken.
      // See http://michaelscharf.blogspot.com/2006/11/javaneturlequals-and-hashcode-make.html.
      try {
        if (lastUrl != null && url.toURI().equals(lastUrl.toURI())) {
          throw new HttpException("In re-direct loop");

        }
      } catch (URISyntaxException e) {
        // Do nothing, this is best effort.
      }
    }

    urlConnection = connectionFactory.build(url);
    for (Map.Entry<String, String> headerEntry : headers.entrySet()) {
      urlConnection.addRequestProperty(headerEntry.getKey(), headerEntry.getValue());
    }
    urlConnection.setConnectTimeout(timeout);
    urlConnection.setReadTimeout(timeout);
    urlConnection.setUseCaches(false);
    urlConnection.setDoInput(true);

    // Stop the urlConnection instance of HttpUrlConnection from following redirects so that
    // redirects will be handled by recursive calls to this method, loadDataWithRedirects.
    urlConnection.setInstanceFollowRedirects(false);

    // Connect explicitly to avoid errors in decoders if connection fails.
    urlConnection.connect();
    // Set the stream so that it's closed in cleanup to avoid resource leaks. See #2352.
    stream = urlConnection.getInputStream();
    if (isCancelled) {
      return null;
    }
    final int statusCode = urlConnection.getResponseCode();
    if (isHttpOk(statusCode)) {
      //重点   网络请求OK
      return getStreamForSuccessfulRequest(urlConnection);
    } else if (isHttpRedirect(statusCode)) {
      String redirectUrlString = urlConnection.getHeaderField("Location");
      if (TextUtils.isEmpty(redirectUrlString)) {
        throw new HttpException("Received empty or null redirect url");
      }
      URL redirectUrl = new URL(url, redirectUrlString);
      // Closing the stream specifically is required to avoid leaking ResponseBodys in addition
      // to disconnecting the url connection below. See #2352.
      cleanup();
      return loadDataWithRedirects(redirectUrl, redirects + 1, url, headers);
    } else if (statusCode == INVALID_STATUS_CODE) {
      throw new HttpException(statusCode);
    } else {
      throw new HttpException(urlConnection.getResponseMessage(), statusCode);
    }
}

private InputStream getStreamForSuccessfulRequest(HttpURLConnection urlConnection)
      throws IOException {
    if (TextUtils.isEmpty(urlConnection.getContentEncoding())) {
      int contentLength = urlConnection.getContentLength();
      stream = ContentLengthInputStream.obtain(urlConnection.getInputStream(), contentLength);
    } else {
      if (Log.isLoggable(TAG, Log.DEBUG)) {
        Log.d(TAG, "Got non empty content encoding: " + urlConnection.getContentEncoding());
      }
      stream = urlConnection.getInputStream();
    }
    return stream;
}

```

这个就比较熟悉了,就是通过HttpURLConnection进行的网络请求,并且结果就是通过`urlConnection.getInputStream();`拿到的.这里拿到了结果后,就返回了,然后就是上面的`callback.onDataReady(result);`进行回调,处理结果

```java
//SourceGenerator.java
public void onDataReady(Object data) {
    DiskCacheStrategy diskCacheStrategy = helper.getDiskCacheStrategy();
    if (data != null && diskCacheStrategy.isDataCacheable(loadData.fetcher.getDataSource())) {
      dataToCache = data;
      cb.reschedule();
    } else {
      //没有缓存  走这里   
      //这里的cb是上面private DataFetcherGenerator getNextGenerator()中初始化SourceGenerator时传入的DecodeJob
      cb.onDataFetcherReady(loadData.sourceKey, data, loadData.fetcher,
          loadData.fetcher.getDataSource(), originalKey);
    }
}

//DecodeJob.java
public void onDataFetcherReady(Key sourceKey, Object data, DataFetcher<?> fetcher,
      DataSource dataSource, Key attemptedKey) {
    ....
    if (Thread.currentThread() != currentThread) {
      runReason = RunReason.DECODE_DATA;
      callback.reschedule(this);
    } else {
      GlideTrace.beginSection("DecodeJob.decodeFromRetrievedData");
      try {
        //上面的都不看了,会走到这里来
        decodeFromRetrievedData();
      } finally {
        GlideTrace.endSection();
      }
    }
}

private void decodeFromRetrievedData() {
    Resource<R> resource = null;
    try {
      //重点1
      //从数据中解码得到资源
      resource = decodeFromData(currentFetcher, currentData, currentDataSource);
    } catch (GlideException e) {
      e.setLoggingDetails(currentAttemptingKey, currentDataSource);
      throwables.add(e);
    }
    if (resource != null) {
      //重点2 
      notifyEncodeAndRelease(resource, currentDataSource);
    } else {
      runGenerators();
    }
}

```

拿到数据之后,经过了几个方法,到了重点1处,开始从数据中解码.

```java
private <Data> Resource<R> decodeFromData(DataFetcher<?> fetcher, Data data,
      DataSource dataSource) throws GlideException {
    try {
      //这里又把解码包了一下
      Resource<R> result = decodeFromFetcher(data, dataSource);
      return result;
    } finally {
      fetcher.cleanup();
    }
}

private <Data> Resource<R> decodeFromFetcher(Data data, DataSource dataSource)
      throws GlideException {
    LoadPath<Data, ?, R> path = decodeHelper.getLoadPath((Class<Data>) data.getClass());
    //重点代码
    //将解码交给LoadPath对象去搞
    return runLoadPath(data, dataSource, path);
}

private <Data, ResourceType> Resource<R> runLoadPath(Data data, DataSource dataSource,
      LoadPath<Data, ResourceType, R> path) throws GlideException {
    Options options = getOptionsWithHardwareConfig(dataSource);
    //将数据又包装了一下,,,,,,好多好多包装啊
    DataRewinder<Data> rewinder = glideContext.getRegistry().getRewinder(data);
    try {
      // ResourceType in DecodeCallback below is required for compilation to work with gradle.
      //在LoadPath对象中load  解码
      return path.load(
          rewinder, options, width, height, new DecodeCallback<ResourceType>(dataSource));
    } finally {
      rewinder.cleanup();
    }
}

```

各种包装,各种转,最后将数据交给LoadPath对象对象去解码.

```java
public Resource<Transcode> load(DataRewinder<Data> rewinder, @NonNull Options options, int width,
      int height, DecodePath.DecodeCallback<ResourceType> decodeCallback) throws GlideException {
    List<Throwable> throwables = Preconditions.checkNotNull(listPool.acquire());
    try {
      //核心代码
      return loadWithExceptionList(rewinder, options, width, height, decodeCallback, throwables);
    } finally {
      listPool.release(throwables);
    }
}

private Resource<Transcode> loadWithExceptionList(DataRewinder<Data> rewinder,
      @NonNull Options options,
      int width, int height, DecodePath.DecodeCallback<ResourceType> decodeCallback,
      List<Throwable> exceptions) throws GlideException {
    Resource<Transcode> result = null;
    //noinspection ForLoopReplaceableByForEach to improve perf
    for (int i = 0, size = decodePaths.size(); i < size; i++) {
      DecodePath<Data, ResourceType, Transcode> path = decodePaths.get(i);
      try {
        //核心代码   
        //将解码任务又转给了DecodePath去做  我擦,,,,转了好几手了
        result = path.decode(rewinder, width, height, options, decodeCallback);
      } catch (GlideException e) {
        exceptions.add(e);
      }
      if (result != null) {
        break;
      }
    }

    return result;
}

```

又转了一手,到DecodePath手中去解码

```java
public Resource<Transcode> decode(DataRewinder<DataType> rewinder, int width, int height,
      @NonNull Options options, DecodeCallback<ResourceType> callback) throws GlideException {
    Resource<ResourceType> decoded = decodeResource(rewinder, width, height, options);
    Resource<ResourceType> transformed = callback.onResourceDecoded(decoded);
    return transcoder.transcode(transformed, options);
}

private Resource<ResourceType> decodeResource(DataRewinder<DataType> rewinder, int width,
      int height, @NonNull Options options) throws GlideException {
    List<Throwable> exceptions = Preconditions.checkNotNull(listPool.acquire());
    try {
      //->
      return decodeResourceWithList(rewinder, width, height, options, exceptions);
    } finally {
      listPool.release(exceptions);
    }
}

private Resource<ResourceType> decodeResourceWithList(DataRewinder<DataType> rewinder, int width,
      int height, @NonNull Options options, List<Throwable> exceptions) throws GlideException {
    Resource<ResourceType> result = null;
    //noinspection ForLoopReplaceableByForEach to improve perf
    for (int i = 0, size = decoders.size(); i < size; i++) {
      ResourceDecoder<DataType, ResourceType> decoder = decoders.get(i);
      try {
        DataType data = rewinder.rewindAndGet();
        if (decoder.handles(data, options)) {
          data = rewinder.rewindAndGet();
          //终于在这里开始解码了....
          //根据DataType, ResourceType区别,分发给不同的解码器
          result = decoder.decode(data, width, height, options);
        }
        // Some decoders throw unexpectedly. If they do, we shouldn't fail the entire load path, but
        // instead log and continue. See #2406 for an example.
      } catch (IOException | RuntimeException | OutOfMemoryError e) {
        exceptions.add(e);
      }

      if (result != null) {
        break;
      }
    }

    return result;
}

```

终于在这里开始调用解码器开始解码了,,,,上面的decoder其实是StreamBitmapDecoder,在初始化Glide的时候就初始化好了....一直放那里没用它.来看StreamBitmapDecoder的decode方法

```java
public Resource<Bitmap> decode(@NonNull InputStream source, int width, int height,
      @NonNull Options options)
      throws IOException {
    ...
    //这里又将解码任务交给了Downsampler
    return downsampler.decode(invalidatingStream, width, height, options, callbacks);
}

//Downsampler.java
public Resource<Bitmap> decode(InputStream is, int requestedWidth, int requestedHeight,
      Options options, DecodeCallbacks callbacks) throws IOException {
    Preconditions.checkArgument(is.markSupported(), "You must provide an InputStream that supports"
        + " mark()");

    byte[] bytesForOptions = byteArrayPool.get(ArrayPool.STANDARD_BUFFER_SIZE_BYTES, byte[].class);
    BitmapFactory.Options bitmapFactoryOptions = getDefaultOptions();
    bitmapFactoryOptions.inTempStorage = bytesForOptions;

    DecodeFormat decodeFormat = options.get(DECODE_FORMAT);
    DownsampleStrategy downsampleStrategy = options.get(DownsampleStrategy.OPTION);
    boolean fixBitmapToRequestedDimensions = options.get(FIX_BITMAP_SIZE_TO_REQUESTED_DIMENSIONS);
    boolean isHardwareConfigAllowed =
      options.get(ALLOW_HARDWARE_CONFIG) != null && options.get(ALLOW_HARDWARE_CONFIG);

    try {
      //->  重点4
      Bitmap result = decodeFromWrappedStreams(is, bitmapFactoryOptions,
          downsampleStrategy, decodeFormat, isHardwareConfigAllowed, requestedWidth,
          requestedHeight, fixBitmapToRequestedDimensions, callbacks);
      // 解码得到Bitmap对象后，包装成BitmapResource对象返回，
      // 通过内部的get方法得到Bitmap对象
      return BitmapResource.obtain(result, bitmapPool);
    } finally {
      releaseOptions(bitmapFactoryOptions);
      byteArrayPool.put(bytesForOptions);
    }
}
```

解码任务又转手了,,,转到了Downsampler,

```java
private Bitmap decodeFromWrappedStreams(InputStream is,
      BitmapFactory.Options options, DownsampleStrategy downsampleStrategy,
      DecodeFormat decodeFormat, boolean isHardwareConfigAllowed, int requestedWidth,
      int requestedHeight, boolean fixBitmapToRequestedDimensions,
      DecodeCallbacks callbacks) throws IOException {
    ...
    //省去Bitmap压缩的代码

    //通过BitmapFactory.decodeStream搞到Bitmap
    Bitmap downsampled = decodeStream(is, options, callbacks, bitmapPool);
    callbacks.onDecodeComplete(bitmapPool, downsampled);

    //Bitmap旋转处理
    ....
    return rotated;
}
```

Glide在拿到InputStream之后各种包装,各种转手,终于还是压缩处理之后通过BitmapFactory.decodeStream生成出Bitmap.最后这里是交给了Downsampler在处理,它的decode方法是返回到了DecodeJob的run方法，然后使用了notifyEncodeAndRelease()方法对Resource对象进行了回调.

```java
//DecodeJob.java
private void notifyEncodeAndRelease(Resource<R> resource, DataSource dataSource) {
    ...
    notifyComplete(result, dataSource);
    ...
}
private void notifyComplete(Resource<R> resource, DataSource dataSource) {
    setNotifiedOrThrow();
    //这里的callback其实是EngineJob,在初始化DecodeJob的时候传入的
    callback.onResourceReady(resource, dataSource);
}
```

开始通过DecodeJob进行回调,然后又传到了EngineJob

```java
//EngineJob.java
private static final Handler MAIN_THREAD_HANDLER =
      new Handler(Looper.getMainLooper(), new MainThreadCallback());

public void onResourceReady(Resource<R> resource, DataSource dataSource) {
    this.resource = resource;
    this.dataSource = dataSource;
    MAIN_THREAD_HANDLER.obtainMessage(MSG_COMPLETE, this).sendToTarget();
}

//MainThreadCallback#handleMessage
public boolean handleMessage(Message message) {
      EngineJob<?> job = (EngineJob<?>) message.obj;
      switch (message.what) {
        case MSG_COMPLETE:
          //-> 这里
          job.handleResultOnMainThread();
          break;
        case MSG_EXCEPTION:
          job.handleExceptionOnMainThread();
          break;
        case MSG_CANCELLED:
          job.handleCancelledOnMainThread();
          break;
        default:
          throw new IllegalStateException("Unrecognized message: " + message.what);
      }
      return true;
}

void handleResultOnMainThread() {
    stateVerifier.throwIfRecycled();
    if (isCancelled) {
      resource.recycle();
      release(false /*isRemovedFromQueue*/);
      return;
    } else if (cbs.isEmpty()) {
      throw new IllegalStateException("Received a resource without any callbacks to notify");
    } else if (hasResource) {
      throw new IllegalStateException("Already have resource");
    }
    engineResource = engineResourceFactory.build(resource, isCacheable);
    hasResource = true;

    // Hold on to resource for duration of request so we don't recycle it in the middle of
    // notifying if it synchronously released by one of the callbacks.
    engineResource.acquire();
    listener.onEngineJobComplete(this, key, engineResource);

    //noinspection ForLoopReplaceableByForEach to improve perf
    for (int i = 0, size = cbs.size(); i < size; i++) {
      ResourceCallback cb = cbs.get(i);
      if (!isInIgnoredCallbacks(cb)) {
        engineResource.acquire();
        //关键代码 这里的cb是SingleRequest
        cb.onResourceReady(engineResource, dataSource);
      }
    }
    // Our request is complete, so we can release the resource.
    engineResource.release();

    release(false /*isRemovedFromQueue*/);
}

```

onResourceReady回调传回来的时候,通过handler切换到主线程,然后通过SingleRequest的onRrsourceReady方法将数据传递回去

```java
 public void onResourceReady(Resource<?> resource, DataSource dataSource) {
    stateVerifier.throwIfRecycled();
    loadStatus = null;
    if (resource == null) {
      GlideException exception = new GlideException("Expected to receive a Resource<R> with an "
          + "object of " + transcodeClass + " inside, but instead got null.");
      onLoadFailed(exception);
      return;
    }

    Object received = resource.get();
    if (received == null || !transcodeClass.isAssignableFrom(received.getClass())) {
      releaseResource(resource);
      GlideException exception = new GlideException("Expected to receive an object of "
          + transcodeClass + " but instead" + " got "
          + (received != null ? received.getClass() : "") + "{" + received + "} inside" + " "
          + "Resource{" + resource + "}."
          + (received != null ? "" : " " + "To indicate failure return a null Resource "
          + "object, rather than a Resource object containing null data."));
      onLoadFailed(exception);
      return;
    }

    if (!canSetResource()) {
      releaseResource(resource);
      // We can't put the status to complete before asking canSetResource().
      status = Status.COMPLETE;
      return;
    }

    onResourceReady((Resource<R>) resource, (R) received, dataSource);
}

private void onResourceReady(Resource<R> resource, R result, DataSource dataSource) {
    // We must call isFirstReadyResource before setting status.
    boolean isFirstResource = isFirstReadyResource();
    status = Status.COMPLETE;
    this.resource = resource;

    isCallingCallbacks = true;
    try {
      boolean anyListenerHandledUpdatingTarget = false;
      if (requestListeners != null) {
        for (RequestListener<R> listener : requestListeners) {
          anyListenerHandledUpdatingTarget |=
              listener.onResourceReady(result, model, target, dataSource, isFirstResource);
        }
      }
      anyListenerHandledUpdatingTarget |=
          targetListener != null
              && targetListener.onResourceReady(result, model, target, dataSource, isFirstResource);

      if (!anyListenerHandledUpdatingTarget) {
        Transition<? super R> animation =
            animationFactory.build(dataSource, isFirstResource);
        //这里的target是初始化SingleRequest时传入的DrawableImageViewTarget
        target.onResourceReady(result, animation);
      }
    } finally {
      isCallingCallbacks = false;
    }

    notifyLoadSuccess();
  }

```

在SingleRequest中做了一些判断,然后将数据传递给DrawableImageViewTarget去回调处理

```java
//下面2个方法是DrawableImageViewTarget的父类ImageViewTarget中的
public void onResourceReady(@NonNull Z resource, @Nullable Transition<? super Z> transition) {
    if (transition == null || !transition.transition(resource, this)) {
      setResourceInternal(resource);
    } else {
      maybeUpdateAnimatable(resource);
    }
}
private void setResourceInternal(@Nullable Z resource) {
    // Order matters here. Set the resource first to make sure that the Drawable has a valid and
    // non-null Callback before starting it.
    setResource(resource);
    maybeUpdateAnimatable(resource);
}

//DrawableImageViewTarget.java
protected void setResource(@Nullable Drawable resource) {
    view.setImageDrawable(resource);
}
```

这里的view就是我们在into时传入的ImageView对象....我擦,,,,终于把数据放到ImageView上了....不容易啊.

## 6. 总结

到这里,Glide的从网络加载图片到ImageView上的这个主流程是走完了.真的是成吨成吨的操作,各种复杂逻辑,各种封装,各种转换....看代码看得欲仙欲死....大量逻辑集中在into里面,很容易被绕晕..当然,我只是了解其中的主流程,细节真的太多太多了.


> ps: 太久没写博客了,,,,感觉写的不是很好,这写的是什么垃圾玩意儿....
