
## 1. 前言

Okhttp3 俨然已成为Android的主流网络请求开源框架,它的设计非常巧妙,而且非常灵活,功能强大.它有如下默认特性:

- 支持HTTP/2，允许所有同一个主机地址的请求共享同一个Socket连接
- 连接池减少请求延时
- 透明的GZIP压缩减少响应数据的大小
- 缓存响应内容，避免一些完全重复的请求

现在的Android项目基本上都是以OkHttp来进行高效的网络请求.当然,在使用的同时我们需要去研究它的底层实现,从而让我们写出更好的代码.

## 2. 基本使用

这里简单介绍2种,GET和POST.推荐让 OkHttpClient 保持单例，用同一个 OkHttpClient 实例来执行你的所有请求，因为每一个 OkHttpClient 实例都拥有自己的连接池和线程池，重用这些资源可以减少延时和节省资源，如果为每个请求创建一个 OkHttpClient实例，显然就是一种资源的浪费。

### 1. 使用GET方式请求

```java
public static final String URL = "http://www.baidu.com";
private OkHttpClient mOkHttpClient = new OkHttpClient();
private final Request mRequest = new Request.Builder().url(URL).build();

@Override
public void request() {
    mOkHttpClient.newCall(mRequest)
            //异步请求
            .enqueue(new Callback() {
                @Override
                public void onFailure(Call call, IOException e) {
                    e.printStackTrace();
                }

                @Override
                public void onResponse(Call call, Response response) throws IOException {
                    Log.w(TAG, "onResponse: " + response.body().string());
                }
            });
}
```

### 2. 使用POST请求

```java
public static final String URL = "https://api.github.com/markdown/raw";
private OkHttpClient mOkHttpClient = new OkHttpClient.Builder()
        .build();
MediaType mMediaType = MediaType.parse("text/x-markdown; charset=utf-8");
String requestBody = "I am xfhy.";
private final Request mRequest = new Request.Builder()
        .url(URL)
        .post(RequestBody.create(mMediaType, requestBody))
        .build();

@Override
public void request() {
    //每一个Call（其实现是RealCall）只能执行一次，否则会报异常
    mOkHttpClient.newCall(mRequest).enqueue(new Callback() {
        @Override
        public void onFailure(Call call, IOException e) {
            e.printStackTrace();
        }

        @Override
        public void onResponse(Call call, Response response) throws IOException {
            Log.w(TAG, "onResponse: " + response.body().string());
        }
    });
}
```

## 3. interceptor 拦截器-精髓

使用OkHttp3请求网络还是比较简单,而且异步请求也比较轻松.

### 3.1 构建OkHttpClient

正如名字所描述的,OkHttpClient像是一个请求网络的客户端.它内部有很多很多的配置信息(支持协议、任务调度器、连接池、超时时间等),通过构造器模式初始化的这些配置信息.(这里穿插一下,正如你所看到的这种一个类里面很多很多属性需要初始化的,一般就用构造器模式)

```java
public OkHttpClient() {
    this(new Builder());
}

public Builder() {
  //任务调度器
  dispatcher = new Dispatcher();
  //支持的协议
  protocols = DEFAULT_PROTOCOLS;
  connectionSpecs = DEFAULT_CONNECTION_SPECS;
  eventListenerFactory = EventListener.factory(EventListener.NONE);
  proxySelector = ProxySelector.getDefault();
  if (proxySelector == null) {
    proxySelector = new NullProxySelector();
  }
  cookieJar = CookieJar.NO_COOKIES;
  socketFactory = SocketFactory.getDefault();
  hostnameVerifier = OkHostnameVerifier.INSTANCE;
  certificatePinner = CertificatePinner.DEFAULT;
  proxyAuthenticator = Authenticator.NONE;
  authenticator = Authenticator.NONE;
  //连接池
  connectionPool = new ConnectionPool();
  dns = Dns.SYSTEM;
  followSslRedirects = true;
  followRedirects = true;
  retryOnConnectionFailure = true;
  callTimeout = 0;
  //超时时间
  connectTimeout = 10_000;
  readTimeout = 10_000;
  writeTimeout = 10_000;
  pingInterval = 0;
}
```

其中Dispatcher有一个线程池,用于执行异步的请求.并且内部还维护了3个双向任务队列,分别是:准备异步执行的任务队列、正在异步执行的任务队列、正在同步执行的任务队列.

```
/** Executes calls. Created lazily. */
//这个线程池是需要的时候才会被初始化
private @Nullable ExecutorService executorService;

/** Ready async calls in the order they'll be run. */
private final Deque<AsyncCall> readyAsyncCalls = new ArrayDeque<>();

/** Running asynchronous calls. Includes canceled calls that haven't finished yet. */
private final Deque<AsyncCall> runningAsyncCalls = new ArrayDeque<>();

/** Running synchronous calls. Includes canceled calls that haven't finished yet. */
private final Deque<RealCall> runningSyncCalls = new ArrayDeque<>();

public synchronized ExecutorService executorService() {
    if (executorService == null) {
       //注意,该线程池没有核心线程,线程数量可以是Integer.MAX_VALUE个(相当于没有限制),超过60秒没干事就要被回收
      executorService = new ThreadPoolExecutor(0, Integer.MAX_VALUE, 60, TimeUnit.SECONDS,
          new SynchronousQueue<>(), Util.threadFactory("OkHttp Dispatcher", false));
    }
    return executorService;
}

```

### 3.2 构建Request

Request感觉就是一个请求的封装.它里面封装了url、method、header、body,该有的都有了.而且它也是用构造器模式来构建的,它默认的请求方式是GET

```java
public final class Request {
  final HttpUrl url;
  final String method;
  final Headers headers;
  final @Nullable RequestBody body;
  final Map<Class<?>, Object> tags;


 public Builder() {
  this.method = "GET";
  this.headers = new Headers.Builder();
 }
    
  public static class Builder {
    @Nullable HttpUrl url;
    String method;
    Headers.Builder headers;
    @Nullable RequestBody body;

    /** A mutable map of tags, or an immutable empty map if we don't have any. */
    Map<Class<?>, Object> tags = Collections.emptyMap();

    public Builder() {
      this.method = "GET";
      this.headers = new Headers.Builder();
    }
}
```

### 3.3 开始请求

我们进入mOkHttpClient的newCall方法,它构造的是一个Call对象,实际上是一个RealCall

```java
/**
* Prepares the {@code request} to be executed at some point in the future.
*/
@Override public Call newCall(Request request) {
    return RealCall.newRealCall(this, request, false /* for web socket */);
}
```

**RealCall#enqueue(Callback)**

所以示例中的enqueue实际上是RealCall中的方法

```java
@Override public void enqueue(Callback responseCallback) {
    ......
    //将AsyncCall传入任务调度器,
    client.dispatcher().enqueue(new AsyncCall(responseCallback));
}
```

将AsyncCall(这个我们稍后再说)传入任务调度器,任务任务调度器会将其存入待执行的请求队列(上面提到的readyAsyncCalls)中,然后条件允许的话再加入到运行中的请求队列(runningAsyncCalls)中,然后将这个请求放到任务调度器中的线程池中进行消费.下面是详细代码

```
----Dispatcher#enqueue(AsyncCall)
void enqueue(AsyncCall call) {
    synchronized (this) {
      readyAsyncCalls.add(call);

      // Mutate the AsyncCall so that it shares the AtomicInteger of an existing running call to
      // the same host.
      if (!call.get().forWebSocket) {
        AsyncCall existingCall = findExistingCallWithHost(call.host());
        if (existingCall != null) call.reuseCallsPerHostFrom(existingCall);
      }
    }
    promoteAndExecute();
  }

private boolean promoteAndExecute() {
    List<AsyncCall> executableCalls = new ArrayList<>();
    boolean isRunning;
    synchronized (this) {
      //从待执行队列中取出来
      for (Iterator<AsyncCall> i = readyAsyncCalls.iterator(); i.hasNext(); ) {
        AsyncCall asyncCall = i.next();
        //如果正在执行的任务>=64  那么就算了,先缓一缓
        if (runningAsyncCalls.size() >= maxRequests) break; // Max capacity.
        if (asyncCall.callsPerHost().get() >= maxRequestsPerHost) continue; // Host max capacity.
    
        i.remove();
        asyncCall.callsPerHost().incrementAndGet();
        executableCalls.add(asyncCall);
        //加入到运行队列中
        runningAsyncCalls.add(asyncCall);
      }
      isRunning = runningCallsCount() > 0;
    }
    
    for (int i = 0, size = executableCalls.size(); i < size; i++) {
      AsyncCall asyncCall = executableCalls.get(i);
      //一个个地开始执行    executorService方法是获取线程池
      asyncCall.executeOn(executorService());
    }
    
    return isRunning;
}

//获取线程池代码
public synchronized ExecutorService executorService() {
    if (executorService == null) {
      executorService = new ThreadPoolExecutor(0, Integer.MAX_VALUE, 60, TimeUnit.SECONDS,
          new SynchronousQueue<>(), Util.threadFactory("OkHttp Dispatcher", false));
    }
    return executorService;
  }

```

上面我们提到了很多次AsyncCall,它其实是一个RealCall的非静态内部类,所以能直接访问到RealCall的属性啥的,方便.同时,AsyncCall继承自NamedRunnable,NamedRunnable实现了NamedRunnable.

```java
public abstract class NamedRunnable implements Runnable {
  protected final String name;

  public NamedRunnable(String format, Object... args) {
    this.name = Util.format(format, args);
  }

  @Override public final void run() {
    String oldName = Thread.currentThread().getName();
    Thread.currentThread().setName(name);
    try {
      execute();
    } finally {
      Thread.currentThread().setName(oldName);
    }
  }

  protected abstract void execute();
}
```

NamedRunnable中使用了模板方法模式,子类必须实现execute方法,并且将逻辑放在execute中.并且NamedRunnable中还设置了自己线程的名字,实属方便管理.

上面的任务调度器中执行的AsyncCall,相当于就是执行的AsyncCall的execute的逻辑

```java
@Override protected void execute() {
  boolean signalledCallback = false;
  transmitter.timeoutEnter();
  try {
    
    //-----------------------重点代码  华丽的分割线围起来---------------------------------
    //1. 通过拦截器链条,获取最终的网络请求结果
    Response response = getResponseWithInterceptorChain();
    //2. 标记已执行   不能再执行第二次了
    signalledCallback = true;
    //3. 将结果回调给调用处
    responseCallback.onResponse(RealCall.this, response);
    //--------------------------------------------------------
    
  } catch (IOException e) {
    if (signalledCallback) {
      // Do not signal the callback twice!
      Platform.get().log(INFO, "Callback failure for " + toLoggableString(), e);
    } else {
      responseCallback.onFailure(RealCall.this, e);
    }
  } finally {
    client.dispatcher().finished(this);
  }
}
```

开始了,开始了,重点来了,通过getResponseWithInterceptorChain方法这条拦截器链路可以获取到网络请求的结果.然后我们通过CallBack接口回调回调用处.

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/%E4%BD%A0%E5%BC%80%E5%A7%8B%E4%BA%86.png)

在开始之前,大家先看两张图,这张图是整个拦截器的流程,也是OkHttp的精华,设计之巧妙.

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/OkHttp%E6%8B%A6%E6%88%AA%E5%99%A8%E6%B5%81%E7%A8%8B.png)

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/OkHttp%E6%8B%A6%E6%88%AA%E5%99%A8%E4%BB%A3%E7%A0%81%E9%80%BB%E8%BE%91.png)

从上面的代码也可以看到,getResponseWithInterceptorChain方法是获取到了网络请求的最终数据的.紧接着根据我画了两张图,这两张图主要是描绘了从getResponseWithInterceptorChain进去之后发生的事,它内部会串行的执行一些特定的拦截器(interceptors),每个拦截器负责一个特殊的职责.最后那个拦截器负责请求服务器,然后服务器返回了数据再根据这个拦截器的顺序逆序返回回去,最终就得到了网络数据.

下面先简单介绍一下这些拦截器,方便后面的源码梳理

- **RetryAndFollowUpInterceptor**   负责请求的重定向操作，用于处理网络请求中，请求失败后的重试机制。
- **BridgeInterceptor**   主要是添加一些header
- **CacheInterceptor**   负责缓存
- **ConnectInterceptor**    打开与目标服务器的连接
- **CallServerInterceptor**   最后一个拦截器,负责请求网络

### 3.4 进入拦截器调用链

有了上面的简单介绍,我们直接进入getResponseWithInterceptorChain方法一探究竟.

```java
Response getResponseWithInterceptorChain() throws IOException {
    // Build a full stack of interceptors.
    //用来盛放所有的拦截器的
    List<Interceptor> interceptors = new ArrayList<>();
    
    //1. 添加用户定义的拦截器
    interceptors.addAll(client.interceptors());
    //2. 添加一些OkHttp自带的拦截器
    interceptors.add(new RetryAndFollowUpInterceptor(client));
    interceptors.add(new BridgeInterceptor(client.cookieJar()));
    interceptors.add(new CacheInterceptor(client.internalCache()));
    interceptors.add(new ConnectInterceptor(client));
    
    if (!forWebSocket) {
      //这里还有一个网络拦截器,也是可以用户自定义的
      interceptors.addAll(client.networkInterceptors());
    }
    
    //最终访问服务器的拦截器
    interceptors.add(new CallServerInterceptor(forWebSocket));
    
    //3. 将拦截器,当前拦截器索引等传入Interceptor.Chain
    Interceptor.Chain chain = new RealInterceptorChain(interceptors, transmitter, null, 0,
        originalRequest, this, client.connectTimeoutMillis(),
        client.readTimeoutMillis(), client.writeTimeoutMillis());
    
    boolean calledNoMoreExchanges = false;
    try {
      //4. 请求访问下一个拦截器
      Response response = chain.proceed(originalRequest);
      if (transmitter.isCanceled()) {
        closeQuietly(response);
        throw new IOException("Canceled");
      }
      return response;
    } catch (IOException e) {
      calledNoMoreExchanges = true;
      throw transmitter.noMoreExchanges(e);
    } finally {
      if (!calledNoMoreExchanges) {
        transmitter.noMoreExchanges(null);
      }
    }
}
```

可以看到,OkHttp这个拦截器链的大体流程,最开始是用户自定义的拦截器,然后才是OkHttp自己默认的拦截器(需要注意的是,最后一个拦截器是CallServerInterceptor).然后将拦截器集合和当前拦截器的索引等数据传入RealInterceptorChain,调用RealInterceptorChain对象的proceed,并最终得到执行结果.看来逻辑在RealInterceptorChain的proceed方法内部

```java

public final class RealInterceptorChain implements Interceptor.Chain {
    private final List<Interceptor> interceptors;
    private final Transmitter transmitter;
    private final @Nullable Exchange exchange;
    private final int index;
    private final Request request;
    private final Call call;
    private final int connectTimeout;
    private final int readTimeout;
    private final int writeTimeout;
    private int calls;
    
    public RealInterceptorChain(List<Interceptor> interceptors, Transmitter transmitter,
    @Nullable Exchange exchange, int index, Request request, Call call,
    int connectTimeout, int readTimeout, int writeTimeout) {
        this.interceptors = interceptors;
        this.transmitter = transmitter;
        this.exchange = exchange;
        this.index = index;
        this.request = request;
        this.call = call;
        this.connectTimeout = connectTimeout;
        this.readTimeout = readTimeout;
        this.writeTimeout = writeTimeout;
    }

    @Override 
    public Response proceed(Request request) throws IOException {
        return proceed(request, transmitter, exchange);
    }
    
    public Response proceed(Request request, Transmitter transmitter, @Nullable Exchange exchange)
      throws IOException {
        calls++;
        
        // Call the next interceptor in the chain.
        //调用下一个interceptor.注意到,这里的index索引+1了的,所以是下一个interceptor
        RealInterceptorChain next = new RealInterceptorChain(interceptors, transmitter, exchange,
            index + 1, request, call, connectTimeout, readTimeout, writeTimeout);
        //当前interceptor
        Interceptor interceptor = interceptors.get(index);
        //调用interceptor的intercept方法
        Response response = interceptor.intercept(next);
        
        return response;
    }
}
```

在proceed方法里面主要是将下一个拦截器的RealInterceptorChain构建出来,然后传入当前拦截器的intercept方法里面,方便在intercept方法里面执行下一个RealInterceptorChain的proceed方法.intercept方法返回的是获取数据之后的Response.

下面进入intercept方法内部,Interceptor其实是一个接口,然后所有的拦截器都实现了这个接口Interceptor.如果没有用户自定义的拦截器,那么第一个拦截器就是RetryAndFollowUpInterceptor

RetryAndFollowUpInterceptor#intercept
```java
@Override public Response intercept(Chain chain) throws IOException {
    Request request = chain.request();
    RealInterceptorChain realChain = (RealInterceptorChain) chain;
    Transmitter transmitter = realChain.transmitter();

    int followUpCount = 0;
    Response priorResponse = null;
    
    //死循环  直到达到重定向的最大次数
    while (true) {
      //准备一个流来承载request,如果存在则复用
      transmitter.prepareToConnect(request);

      if (transmitter.isCanceled()) {
        throw new IOException("Canceled");
      }

      Response response;
      boolean success = false;
      try {
        //调用下一个拦截器  
        response = realChain.proceed(request, transmitter, null);
        success = true;
      } catch (RouteException e) {
      
        //下面是一些失败,然后又重新请求的代码
      
        // The attempt to connect via a route failed. The request will not have been sent.
        if (!recover(e.getLastConnectException(), transmitter, false, request)) {
          throw e.getFirstConnectException();
        }
        continue;
      } catch (IOException e) {
        // An attempt to communicate with a server failed. The request may have been sent.
        boolean requestSendStarted = !(e instanceof ConnectionShutdownException);
        if (!recover(e, transmitter, requestSendStarted, request)) throw e;
        continue;
      } finally {
        // The network call threw an exception. Release any resources.
        if (!success) {
          transmitter.exchangeDoneDueToException();
        }
      }

      // Attach the prior response if it exists. Such responses never have a body.
      if (priorResponse != null) {
        response = response.newBuilder()
            .priorResponse(priorResponse.newBuilder()
                    .body(null)
                    .build())
            .build();
      }

      Exchange exchange = Internal.instance.exchange(response);
      Route route = exchange != null ? exchange.connection().route() : null;
      Request followUp = followUpRequest(response, route);

      if (followUp == null) {
        if (exchange != null && exchange.isDuplex()) {
          transmitter.timeoutEarlyExit();
        }
        return response;
      }

      RequestBody followUpBody = followUp.body();
      if (followUpBody != null && followUpBody.isOneShot()) {
        return response;
      }

      closeQuietly(response.body());
      if (transmitter.hasExchange()) {
        exchange.detachWithViolence();
      }

      if (++followUpCount > MAX_FOLLOW_UPS) {
        throw new ProtocolException("Too many follow-up requests: " + followUpCount);
      }

      request = followUp;
      priorResponse = response;
    }
  }
```

RetryAndFollowUpInterceptor主要是负责错误处理,以及重定向.当然重定向是有最大次数的,OkHttp规定是20次.

RetryAndFollowUpInterceptor执行proceed方法是来到了BridgeInterceptor,它是一个连接桥.添加了很多header

```java
@Override public Response intercept(Chain chain) throws IOException {
    Request userRequest = chain.request();
    Request.Builder requestBuilder = userRequest.newBuilder();
    
    //进行header的包装
    RequestBody body = userRequest.body();
    if (body != null) {
      MediaType contentType = body.contentType();
      if (contentType != null) {
        requestBuilder.header("Content-Type", contentType.toString());
      }

      long contentLength = body.contentLength();
      if (contentLength != -1) {
        requestBuilder.header("Content-Length", Long.toString(contentLength));
        requestBuilder.removeHeader("Transfer-Encoding");
      } else {
        requestBuilder.header("Transfer-Encoding", "chunked");
        requestBuilder.removeHeader("Content-Length");
      }
    }

    if (userRequest.header("Host") == null) {
      requestBuilder.header("Host", hostHeader(userRequest.url(), false));
    }

    if (userRequest.header("Connection") == null) {
      requestBuilder.header("Connection", "Keep-Alive");
    }

    //添加Accept-Encoding：gzip
    // If we add an "Accept-Encoding: gzip" header field we're responsible for also decompressing
    // the transfer stream.
    boolean transparentGzip = false;
    if (userRequest.header("Accept-Encoding") == null && userRequest.header("Range") == null) {
      transparentGzip = true;
      requestBuilder.header("Accept-Encoding", "gzip");
    }

    //创建OkhttpClient配置的cookieJar
    List<Cookie> cookies = cookieJar.loadForRequest(userRequest.url());
    if (!cookies.isEmpty()) {
      requestBuilder.header("Cookie", cookieHeader(cookies));
    }

    if (userRequest.header("User-Agent") == null) {
      requestBuilder.header("User-Agent", Version.userAgent());
    }
    
    //执行下一个Interceptor
    Response networkResponse = chain.proceed(requestBuilder.build());

    HttpHeaders.receiveHeaders(cookieJar, userRequest.url(), networkResponse.headers());

    Response.Builder responseBuilder = networkResponse.newBuilder()
        .request(userRequest);

    //先判断服务器是否支持gzip压缩,支持则交给Okio处理
    if (transparentGzip
        && "gzip".equalsIgnoreCase(networkResponse.header("Content-Encoding"))
        && HttpHeaders.hasBody(networkResponse)) {
      GzipSource responseBody = new GzipSource(networkResponse.body().source());
      Headers strippedHeaders = networkResponse.headers().newBuilder()
          .removeAll("Content-Encoding")
          .removeAll("Content-Length")
          .build();
      responseBuilder.headers(strippedHeaders);
      String contentType = networkResponse.header("Content-Type");
      responseBuilder.body(new RealResponseBody(contentType, -1L, Okio.buffer(responseBody)));
    }
    
    //最后将结果返回
    return responseBuilder.build();
  }
```

BridgeInterceptor就跟它的名字那样，它是一个连接桥.它负责把用户构造的请求转换成发送给服务器的请求,就是添加了不少的header,其中还有gzip等.

BridgeInterceptor的下一个拦截器是CacheInterceptor

```java
@Override public Response intercept(Chain chain) throws IOException {
    ////如果配置了缓存：优先从缓存中读取Response
    Response cacheCandidate = cache != null
        ? cache.get(chain.request())
        : null;

    long now = System.currentTimeMillis();
    
    //缓存策略，该策略通过某种规则来判断缓存是否有效
    CacheStrategy strategy = new CacheStrategy.Factory(now, chain.request(), cacheCandidate).get();
    Request networkRequest = strategy.networkRequest;
    Response cacheResponse = strategy.cacheResponse;

    if (cache != null) {
      cache.trackResponse(strategy);
    }

    if (cacheCandidate != null && cacheResponse == null) {
      closeQuietly(cacheCandidate.body()); // The cache candidate wasn't applicable. Close it.
    }

    // If we're forbidden from using the network and the cache is insufficient, fail.
    //如果根据缓存策略strategy禁止使用网络，并且缓存无效，直接返回空的Response
    if (networkRequest == null && cacheResponse == null) {
      return new Response.Builder()
          .request(chain.request())
          .protocol(Protocol.HTTP_1_1)
          .code(504)
          .message("Unsatisfiable Request (only-if-cached)")
          .body(Util.EMPTY_RESPONSE)
          .sentRequestAtMillis(-1L)
          .receivedResponseAtMillis(System.currentTimeMillis())
          .build();
    }

    // If we don't need the network, we're done.
    //如果根据缓存策略strategy禁止使用网络，且有缓存则直接使用缓存
    if (networkRequest == null) {
      return cacheResponse.newBuilder()
          .cacheResponse(stripBody(cacheResponse))
          .build();
    }

    //需要网络
    Response networkResponse = null;
    try {
      //执行下一个拦截器,发起网路请求
      networkResponse = chain.proceed(networkRequest);
    } finally {
      // If we're crashing on I/O or otherwise, don't leak the cache body.
      if (networkResponse == null && cacheCandidate != null) {
        closeQuietly(cacheCandidate.body());
      }
    }

    //本地有缓存，
    // If we have a cache response too, then we're doing a conditional get.
    if (cacheResponse != null) {
        //并且服务器返回304状态码（说明缓存还没过期或服务器资源没修改）
      if (networkResponse.code() == HTTP_NOT_MODIFIED) {
        //使用缓存数据
        Response response = cacheResponse.newBuilder()
            .headers(combine(cacheResponse.headers(), networkResponse.headers()))
            .sentRequestAtMillis(networkResponse.sentRequestAtMillis())
            .receivedResponseAtMillis(networkResponse.receivedResponseAtMillis())
            .cacheResponse(stripBody(cacheResponse))
            .networkResponse(stripBody(networkResponse))
            .build();
        networkResponse.body().close();

        // Update the cache after combining headers but before stripping the
        // Content-Encoding header (as performed by initContentStream()).
        cache.trackConditionalCacheHit();
        cache.update(cacheResponse, response);
        return response;
      } else {
        closeQuietly(cacheResponse.body());
      }
    }

    //如果网络资源已经修改：使用网络响应返回的最新数据
    Response response = networkResponse.newBuilder()
        .cacheResponse(stripBody(cacheResponse))
        .networkResponse(stripBody(networkResponse))
        .build();

    //将最新的数据缓存起来
    if (cache != null) {
      if (HttpHeaders.hasBody(response) && CacheStrategy.isCacheable(response, networkRequest)) {
        // Offer this request to the cache.
        CacheRequest cacheRequest = cache.put(response);
        return cacheWritingResponse(cacheRequest, response);
      }

      if (HttpMethod.invalidatesCache(networkRequest.method())) {
        try {
          cache.remove(networkRequest);
        } catch (IOException ignored) {
          // The cache cannot be written.
        }
      }
    }
    
    //返回最新的数据
    return response;
  }
```

CacheInterceptor是进行一些缓存上面的处理,接下来是ConnectInterceptor

```java
@Override 
public Response intercept(Chain chain) throws IOException {
    RealInterceptorChain realChain = (RealInterceptorChain) chain;
    Request request = realChain.request();
    Transmitter transmitter = realChain.transmitter();
    
    // We need the network to satisfy this request. Possibly for validating a conditional GET.
    //判断请求是不是GET方法, 不是的情况下,需要进行有效监测
    boolean doExtensiveHealthChecks = !request.method().equals("GET");
    Exchange exchange = transmitter.newExchange(chain, doExtensiveHealthChecks);
    
    //执行下一个拦截器
    return realChain.proceed(request, transmitter, exchange);
}
```

ConnectInterceptor的下一个拦截器就是最好一个拦截器CallServerInterceptor了.

```java
@Override public Response intercept(Chain chain) throws IOException {
    RealInterceptorChain realChain = (RealInterceptorChain) chain;
    Exchange exchange = realChain.exchange();
    Request request = realChain.request();

    long sentRequestMillis = System.currentTimeMillis();
    //整理请求头并写入
    exchange.writeRequestHeaders(request);

    boolean responseHeadersStarted = false;
    Response.Builder responseBuilder = null;
    if (HttpMethod.permitsRequestBody(request.method()) && request.body() != null) {
      // If there's a "Expect: 100-continue" header on the request, wait for a "HTTP/1.1 100
      // Continue" response before transmitting the request body. If we don't get that, return
      // what we did get (such as a 4xx response) without ever transmitting the request body.
      if ("100-continue".equalsIgnoreCase(request.header("Expect"))) {
        exchange.flushRequest();
        responseHeadersStarted = true;
        exchange.responseHeadersStart();
        responseBuilder = exchange.readResponseHeaders(true);
      }

      if (responseBuilder == null) {
        if (request.body().isDuplex()) {
          // Prepare a duplex body so that the application can send a request body later.
          exchange.flushRequest();
          BufferedSink bufferedRequestBody = Okio.buffer(
              exchange.createRequestBody(request, true));
          request.body().writeTo(bufferedRequestBody);
        } else {
          // Write the request body if the "Expect: 100-continue" expectation was met.
          BufferedSink bufferedRequestBody = Okio.buffer(
              exchange.createRequestBody(request, false));
          request.body().writeTo(bufferedRequestBody);
          bufferedRequestBody.close();
        }
      } else {
        exchange.noRequestBody();
        if (!exchange.connection().isMultiplexed()) {
          // If the "Expect: 100-continue" expectation wasn't met, prevent the HTTP/1 connection
          // from being reused. Otherwise we're still obligated to transmit the request body to
          // leave the connection in a consistent state.
          exchange.noNewExchangesOnConnection();
        }
      }
    } else {
      exchange.noRequestBody();
    }

    if (request.body() == null || !request.body().isDuplex()) {
      //发送最终的请求
      exchange.finishRequest();
    }

    if (!responseHeadersStarted) {
      exchange.responseHeadersStart();
    }

    if (responseBuilder == null) {
      //响应头
      responseBuilder = exchange.readResponseHeaders(false);
    }

    Response response = responseBuilder
        .request(request)
        .handshake(exchange.connection().handshake())
        .sentRequestAtMillis(sentRequestMillis)
        .receivedResponseAtMillis(System.currentTimeMillis())
        .build();

    int code = response.code();
    if (code == 100) {
      // server sent a 100-continue even though we did not request one.
      // try again to read the actual response
      response = exchange.readResponseHeaders(false)
          .request(request)
          .handshake(exchange.connection().handshake())
          .sentRequestAtMillis(sentRequestMillis)
          .receivedResponseAtMillis(System.currentTimeMillis())
          .build();

      code = response.code();
    }

    exchange.responseHeadersEnd(response);

    if (forWebSocket && code == 101) {
      // Connection is upgrading, but we need to ensure interceptors see a non-null response body.
      response = response.newBuilder()
          .body(Util.EMPTY_RESPONSE)
          .build();
    } else {
      response = response.newBuilder()
          .body(exchange.openResponseBody(response))
          .build();
    }

    //断开连接
    if ("close".equalsIgnoreCase(response.request().header("Connection"))
        || "close".equalsIgnoreCase(response.header("Connection"))) {
      exchange.noNewExchangesOnConnection();
    }

    //抛出协议异常
    if ((code == 204 || code == 205) && response.body().contentLength() > 0) {
      throw new ProtocolException(
          "HTTP " + code + " had non-zero Content-Length: " + response.body().contentLength());
    }

    return response;
  }
```

这是链中最后一个拦截器，它向 服务器 发起了一次网络访问.负责向服务器发送请求数据、从服务器读取响应数据.拿到数据之后再沿着链返回.

## 4. 总结

OkHttp的拦截器链设计得非常巧妙,是典型的责任链模式.并最终由最后一个链处理了网络请求,并拿到结果.本文主要是对OkHttp主流程进行了梳理,通过本文能对OkHttp有一个整体的了解.
