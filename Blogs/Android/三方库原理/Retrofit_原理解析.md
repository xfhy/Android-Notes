
Retrofit,一个远近闻名的网络框架,它是由Square公司开源的.Square公司,是我们的老熟人了,很多框架都是他开源的,比如OkHttp,picasso,leakcanary等等.他们公司的很多开源库,几乎已经成为现在开发Android APP的标配.

简单来说,Retrofit其实是底层还是用的OkHttp来进行网络请求的,只不过他包装了一下,使得开发者在使用访问网络的时候更加方便简单高效.

> 一句话总结:Retrofit将接口动态生成实现类,该接口定义了请求方式+路径+参数等注解,Retrofit可以方便得从注解中获取这些参数,然后拼接起来,通过OkHttp访问网络.

## 1. 基本使用

很简单,我就是简单请求一个GET接口,拿点json数据,解析成对象实例.

首先,我们需要定义一个interface.这个interface是网络请求的API接口,里面定义了请求方式,入参,数据,返回值等数据.

我这里使用的接口是鸿神的wanandroid网站的开放接口,地址: https://www.wanandroid.com/blog/show/2 . 我使用的是https://wanandroid.com/wxarticle/chapters/json.

```java
interface TodoService {

     @GET("wxarticle/list/{id}/{page}/json")
    fun getAirticles(@Path("id") id: String, @Path("page") page: String): Call<BaseData>

}

```

API接口定义好了之后,我们需要构建一个Retrofit实例.

```java
private val mRetrofit by lazy {
        Retrofit.Builder()
            .baseUrl("https://wanandroid.com/")
            .addConverterFactory(GsonConverterFactory.create())   //数据解析器
            .build()
    }
```

有了Retrofit实例之后,我们需要让Retrofit帮我们把上面定义的API接口转换成实例,然后我们就可以直接把它当做实例来调用了

```java
//用接口生成实例
val iArticleApi = mRetrofit.create(IArticleApi::class.java)
//调用方法  返回Call对象
val airticlesCall = iArticleApi.getAirticles("408", "1")
```

调用之后会返回一个Call对象,我们可以拿着这个Call对象去访问网络了

```java
//异步请求方式
airticlesCall.enqueue(object : Callback<BaseData> {
    override fun onFailure(call: Call<BaseData>, t: Throwable) {
        //请求失败
        t.printStackTrace()
        Log.e("xfhy", "请求失败")
    }

    override fun onResponse(call: Call<BaseData>, response: Response<BaseData>) {
        //请求成功
        val baseData = response.body()
        Log.e("xfhy", "请求成功 ${baseData?.toString()}")
    }
})
```

拿着这个Call对象调用enqueue方法即可异步访问网络,获取结果,非常简单.

## 2. 构建Retrofit

> ps:这里插播一个小技巧,当我们构建一个对象需要传入很多很多必要的参数才能构建起来的时候,我们需要使用Builder模式(构造器模式).如果不太了解的同学,看[这里](https://blog.csdn.net/xu404741377/article/details/73699523)

Retrofit源码中使用了很多Builder模式,像比如接下来要讲的Retrofit 构建,我们看一下它的构建

```java
Retrofit.Builder()
        .baseUrl("https://wanandroid.com/")
        .addConverterFactory(GsonConverterFactory.create())   //数据解析器
        .build()
```

Builder()方法内部就不细看了,里面就是获取一下当前是什么平台(Android,Java).我们来看一下baseUrl方法.

```java
Retrofit#Builder#baseUrl
public Builder baseUrl(String baseUrl) {
  return baseUrl(HttpUrl.get(baseUrl));
}
```

通过HttpUrl的静态get方法构建了一个HttpUrl,传入的是一个baseUrl,HttpUrl里面主要是根据baseUrl获取scheme,host,port,url等等信息的.

然后是addConverterFactory方法,添加解析器

```
private final List<Converter.Factory> converterFactories = new ArrayList<>();
public Builder addConverterFactory(Converter.Factory factory) {
  converterFactories.add(checkNotNull(factory, "factory == null"));
  return this;
}
```

解析器是可以有多个的.

最后就是Retrofit.Builder的build方法了

```java
public Retrofit build() {
  //就是一些各种判空的逻辑
  if (baseUrl == null) {
    throw new IllegalStateException("Base URL required.");
  }

  okhttp3.Call.Factory callFactory = this.callFactory;
  if (callFactory == null) {
    callFactory = new OkHttpClient();
  }

  Executor callbackExecutor = this.callbackExecutor;
  if (callbackExecutor == null) {
    callbackExecutor = platform.defaultCallbackExecutor();
  }

  // Make a defensive copy of the adapters and add the default Call adapter.
  //添加适配器,为了支持除了Call对象以外的返回类型
  List<CallAdapter.Factory> callAdapterFactories = new ArrayList<>(this.callAdapterFactories);
  callAdapterFactories.addAll(platform.defaultCallAdapterFactories(callbackExecutor));

  // Make a defensive copy of the converters.
  //转换器,用于序列化 和 反序列化
  List<Converter.Factory> converterFactories = new ArrayList<>(
      1 + this.converterFactories.size() + platform.defaultConverterFactoriesSize());

  // Add the built-in converter factory first. This prevents overriding its behavior but also
  // ensures correct behavior when using converters that consume all types.
  converterFactories.add(new BuiltInConverters());
  converterFactories.addAll(this.converterFactories);
  converterFactories.addAll(platform.defaultConverterFactories());

  return new Retrofit(callFactory, baseUrl, unmodifiableList(converterFactories),
      unmodifiableList(callAdapterFactories), callbackExecutor, validateEagerly);
}
```

可以看到,就是将前面的一些参数(baseUrl,转换器,适配器等)什么的都配置到Retrofit对象里面.

## 3. 获取网络请求参数 

接下来的就比较带感了,Retrofit其实是通过我们定义的API interface来获取网络请求的入参的.Retrofit为什么能将接口转换成实现类,让我们调用呢?下面来看源码

### 3.1 构建interface实例

在上面的示例中` mRetrofit.create(IArticleApi::class.java)`,这一句代码将接口转换成了实现类,我们进去看看

```java
public <T> T create(final Class<T> service) {
    //这里传入的必须是接口
    Utils.validateServiceInterface(service);
    
    return (T) Proxy.newProxyInstance(service.getClassLoader(), new Class<?>[] { service },
        new InvocationHandler() {
          private final Platform platform = Platform.get();

          @Override public Object invoke(Object proxy, Method method, @Nullable Object[] args)
              throws Throwable {
            ....
            //读取method中的所有数据  将是网络请求的所有入参
            ServiceMethod<Object, Object> serviceMethod =
                (ServiceMethod<Object, Object>) loadServiceMethod(method);
            //各种注解啊,数据啊都传过去    args是方法的参数数据
            OkHttpCall<Object> okHttpCall = new OkHttpCall<>(serviceMethod, args);
            return serviceMethod.adapt(okHttpCall);
          }
        });
  }
```

通过**动态代理**的方式,获取其执行时的方法上的注解+形参等数据,并保存于serviceMethod对象中.serviceMethod和args(形参的值)全都存入OkHttpCall中,先在这里,稍后使用.现在我们来看一下,如何获取到method里面的数据

### 3.2 ServiceMethod 获取入参

我们从上面的loadServiceMethod方法进入

```java
//缓存Method与ServiceMethod,每次根据Method去读取数据比较麻烦,缓存起来,下次进入直接返回,非常高效
private final Map<Method, ServiceMethod<?, ?>> serviceMethodCache = new ConcurrentHashMap<>();

ServiceMethod<?, ?> loadServiceMethod(Method method) {
    //有缓存用缓存
    ServiceMethod<?, ?> result = serviceMethodCache.get(method);
    if (result != null) return result;
    
    synchronized (serviceMethodCache) {
      result = serviceMethodCache.get(method);
      if (result == null) {
        //将method传入,然后去读取它的数据
        result = new ServiceMethod.Builder<>(this, method).build();
        //将serviceMethod存入缓存
        serviceMethodCache.put(method, result);
      }
    }
    return result;
}
```

loadServiceMethod主要是可以看到缓存Method与ServiceMethod,每次根据Method去读取数据比较麻烦,缓存起来,下次进入直接返回,非常高效.我们去看看它内部读取数据的部分

```java
ServiceMethod#Builder()
//又来了,这里又是Builder模式
Builder(Retrofit retrofit, Method method) {
  this.retrofit = retrofit;
  this.method = method;
  //接口方法的注解  比如GET,PUT,POST等
  this.methodAnnotations = method.getAnnotations();
  //参数类型
  this.parameterTypes = method.getGenericParameterTypes();
  //参数注解数组  比如Query
  this.parameterAnnotationsArray = method.getParameterAnnotations();
}
```

`ServiceMethod#Builder()`里面将Retrofit实例+method+接口方法的注解+参数类型+参数的注解存入ServiceMethod中,待会儿会用到.接下来就是`ServiceMethod#Builder`的build方法了

```java
public ServiceMethod build() {
      //1. 获取传入的适配器 如果没有传入则使用默认的ExecutorCallAdapterFactory
      callAdapter = createCallAdapter();
      //2. 获取接口的返回值类型
      responseType = callAdapter.responseType();
      //3. 获取转换器  我传入的是GsonResponseBodyConverter
      responseConverter = createResponseConverter();
    
      //循环接口的方法上的注解   比如我上面示例使用的是GET
      for (Annotation annotation : methodAnnotations) {
        //解析这个方法上的注解是啥  
        parseMethodAnnotation(annotation);
      }

      //参数上的注解
      int parameterCount = parameterAnnotationsArray.length;
      parameterHandlers = new ParameterHandler<?>[parameterCount];
      for (int p = 0; p < parameterCount; p++) {
        //参数类型
        Type parameterType = parameterTypes[p];
        
        //参数的注解
        Annotation[] parameterAnnotations = parameterAnnotationsArray[p];

        parameterHandlers[p] = parseParameter(p, parameterType, parameterAnnotations);
      }

      return new ServiceMethod<>(this);
    }



```

这个方法搞的操作比较多,1,2,3点都是和结果有关的,暂时先不看.然后就是解析接口方法上面的注解,通过parseMethodAnnotation方法.

```java
//解析这个方法上的注解是表示的哪种HTTP请求  
private void parseMethodAnnotation(Annotation annotation) {
  if (annotation instanceof DELETE) {
    parseHttpMethodAndPath("DELETE", ((DELETE) annotation).value(), false);
  } else if (annotation instanceof GET) {
    parseHttpMethodAndPath("GET", ((GET) annotation).value(), false);
  } else if (annotation instanceof HEAD) {
    parseHttpMethodAndPath("HEAD", ((HEAD) annotation).value(), false);
    if (!Void.class.equals(responseType)) {
      throw methodError("HEAD method must use Void as response type.");
    }
  } else if (annotation instanceof PATCH) {
    parseHttpMethodAndPath("PATCH", ((PATCH) annotation).value(), true);
  } else if (annotation instanceof POST) {
    parseHttpMethodAndPath("POST", ((POST) annotation).value(), true);
  }
  //后面也是这个逻辑
  .......
 
}
```

parseMethodAnnotation方法首先是判断是哪种HTTP请求的注解,然后通过parseHttpMethodAndPath方法去分析

```java
//获取注解上面的值
private void parseHttpMethodAndPath(String httpMethod, String value, boolean hasBody) {
  
  this.httpMethod = httpMethod;
  this.hasBody = hasBody;

  //获取方法注解里面的值   比如上面的示例是wxarticle/list/{id}/{page}/json
  this.relativeUrl = value;
  //把那种需要替换值的地方找出来   上面的示例获取出来的结果是id和page
  this.relativeUrlParamNames = parsePathParameters(value);
}
```
parseHttpMethodAndPath方法分析获取的是 http请求方式+省略域名的url+需要替换路径中值的地方.

我们继续看ServiceMethod的Builder的build方法.解析好了方法的注解之后,就开始解析参数的注解了.参数上的注解可能是一个数组,因为可能不止一个注解.

然后遍历参数的类型
```java
Type parameterType = parameterTypes[p];
```

获取参数的注解+参数类型,一起传入parseParameter方法进行解析

```java
//参数的注解
Annotation[] parameterAnnotations = parameterAnnotationsArray[p];
parameterHandlers[p] = parseParameter(p, parameterType, parameterAnnotations);
```

```java
private ParameterHandler<?> parseParameter(
    int p, Type parameterType, Annotation[] annotations) {
    
  ParameterHandler<?> result = null;
  for (Annotation annotation : annotations) {
    ParameterHandler<?> annotationAction = parseParameterAnnotation(
        p, parameterType, annotations, annotation);
    result = annotationAction;
  }

  return result;
}
```

parseParameter里面主要就是调用parseParameterAnnotation生成ParameterHandler

```java
private ParameterHandler<?> parseParameterAnnotation(
        int p, Type type, Annotation[] annotations, Annotation annotation) {
      if (annotation instanceof Url) {

        gotUrl = true;

        if (type == HttpUrl.class
            || type == String.class
            || type == URI.class
            || (type instanceof Class && "android.net.Uri".equals(((Class<?>) type).getName()))) {
          return new ParameterHandler.RelativeUrl();
        } else {
          throw parameterError(p,
              "@Url must be okhttp3.HttpUrl, String, java.net.URI, or android.net.Uri type.");
        }

      } else if (annotation instanceof Path) {
        gotPath = true;

        Path path = (Path) annotation;
        String name = path.value();
        validatePathName(p, name);

        Converter<?, String> converter = retrofit.stringConverter(type, annotations);
        return new ParameterHandler.Path<>(name, converter, path.encoded());

      } else if (annotation instanceof Query) {
        Query query = (Query) annotation;
        String name = query.value();
        boolean encoded = query.encoded();

        Class<?> rawParameterType = Utils.getRawType(type);
        gotQuery = true;
        if (Iterable.class.isAssignableFrom(rawParameterType)) {
          if (!(type instanceof ParameterizedType)) {
            throw parameterError(p, rawParameterType.getSimpleName()
                + " must include generic type (e.g., "
                + rawParameterType.getSimpleName()
                + "<String>)");
          }
          ParameterizedType parameterizedType = (ParameterizedType) type;
          Type iterableType = Utils.getParameterUpperBound(0, parameterizedType);
          Converter<?, String> converter =
              retrofit.stringConverter(iterableType, annotations);
          return new ParameterHandler.Query<>(name, converter, encoded).iterable();
        } 
      
      ......
      //后面的逻辑都差不多的,感兴趣可以阅读源码进行查看

      return null; // Not a Retrofit annotation.
    }

```
解析参数上的注解,这个注解可能的类型比较多,比如Path或者Query等等.所以parseParameterAnnotation方法里面有很多if..else..,我只列举了其中几种,其他的逻辑都差不多的,感兴趣可以阅读源码进行查看.

比如,我们就只分析一下Path的

```java
gotPath = true;
Path path = (Path) annotation;
//获取注解里面value的值
String name = path.value();

Converter<?, String> converter = retrofit.stringConverter(type, annotations);
return new ParameterHandler.Path<>(name, converter, path.encoded());
```

如果是Path则将获取到的数据放到了ParameterHandler.Path中,如果是Query则将数据放到ParameterHandler.Query中.每个注解都有一个属于自己的类型.

然后ServiceMethod剩下的build方法就是`new ServiceMethod<>(this)`了,就是将上面这些获取到的所有数据全部存进去.

然后我们回到动态代码的那个方法,我已经放到下面来了.
```java
ServiceMethod<Object, Object> serviceMethod =
                (ServiceMethod<Object, Object>) loadServiceMethod(method);
OkHttpCall<Object> okHttpCall = new OkHttpCall<>(serviceMethod, args);
return serviceMethod.adapt(okHttpCall);
```
OkHttpCall是Retrofit中的一个类,最后我们将ServiceMethod和args(形参数据)都放进了OkHttpCall对象中.

serviceMethod.adapt最终返回的是将serviceMethod和okHttpCall绑在了一起,

```java
T adapt(Call<R> call) {
    return callAdapter.adapt(call);
}
```

我初始化Retrofit时没有传addCallAdapterFactory(CallAdapterFactory),所以这里是默认的ExecutorCallAdapterFactory,然后ExecutorCallAdapterFactory的adapt方法是就是返回了一个ExecutorCallbackCall对象

```java
@Override public Call<Object> adapt(Call<Object> call) {
    return new ExecutorCallbackCall<>(callbackExecutor, call);
  }
```

到这里,网络请求的入参已经基本解析完了,其实还差一点点,下面会说到.把这些获取到的入参全部封装了起来

## 4. 请求网络

我们的示例是从下面这段代码进行网络请求的
```java
airticlesCall.enqueue(object : Callback<BaseData> {
    override fun onFailure(call: Call<BaseData>, t: Throwable) {
        t.printStackTrace()
        Log.e("xfhy", "请求失败")
    }

    override fun onResponse(call: Call<BaseData>, response: Response<BaseData>) {
        val body = response.body()
        Log.e("xfhy", "请求成功 ${body?.toString()}")
    }
})
```

进行Call的enqueue方法,这里的Call其实是ExecutorCallbackCall对象,因为在上面的动态代理中返回了这个对象的实例,所以就是调用的ExecutorCallbackCall的enqueue方法

```java
ExecutorCallbackCall#enqueue
@Override public void enqueue(final Callback<T> callback) {

  //这里的delegate是之前传入的OkHttpCall对象
  delegate.enqueue(new Callback<T>() {
    @Override public void onResponse(Call<T> call, final Response<T> response) {
      callbackExecutor.execute(new Runnable() {
        @Override public void run() {
          if (delegate.isCanceled()) {
            // Emulate OkHttp's behavior of throwing/delivering an IOException on cancellation.
            callback.onFailure(ExecutorCallbackCall.this, new IOException("Canceled"));
          } else {
            callback.onResponse(ExecutorCallbackCall.this, response);
          }
        }
      });
    }

    @Override public void onFailure(Call<T> call, final Throwable t) {
      callbackExecutor.execute(new Runnable() {
        @Override public void run() {
          callback.onFailure(ExecutorCallbackCall.this, t);
        }
      });
    }
  });
}
```

ExecutorCallbackCall的enqueue方法中调用了之前传入的OkHttpCall的enqueue方法,代理

```java
@Override public void enqueue(final Callback<T> callback) {
    okhttp3.Call call;
    Throwable failure;

    synchronized (this) {
      executed = true;

      call = rawCall;
      failure = creationFailure;
      if (call == null && failure == null) {
        try {
          //在开始之前,需要构建okhttp3.Call对象
          call = rawCall = createRawCall();
        } catch (Throwable t) {
          throwIfFatal(t);
          failure = creationFailure = t;
        }
      }
    }

    if (failure != null) {
      callback.onFailure(this, failure);
      return;
    }

    if (canceled) {
      call.cancel();
    }

    call.enqueue(new okhttp3.Callback() {
      @Override public void onResponse(okhttp3.Call call, okhttp3.Response rawResponse) {
        Response<T> response;
        try {
          response = parseResponse(rawResponse);
        } catch (Throwable e) {
          callFailure(e);
          return;
        }

        try {
          callback.onResponse(OkHttpCall.this, response);
        } catch (Throwable t) {
          t.printStackTrace();
        }
      }

      @Override public void onFailure(okhttp3.Call call, IOException e) {
        callFailure(e);
      }

      private void callFailure(Throwable e) {
        try {
          callback.onFailure(OkHttpCall.this, e);
        } catch (Throwable t) {
          t.printStackTrace();
        }
      }
    });
  }
```

上面一开始就需要构建OKHttp3的Call对象,因为最后还是需要用OkHttp来访问网络

```java
private okhttp3.Call createRawCall() throws IOException {
    okhttp3.Call call = serviceMethod.toCall(args);
    return call;
}
okhttp3.Call toCall(@Nullable Object... args) throws IOException {
    RequestBuilder requestBuilder = new RequestBuilder(httpMethod, baseUrl, relativeUrl, headers,
        contentType, hasBody, isFormEncoded, isMultipart);
    
    @SuppressWarnings("unchecked") // It is an error to invoke a method with the wrong arg types.
    //这是之前创建的ParameterHandler 数组  里面装的是方法参数的注解value值
    ParameterHandler<Object>[] handlers = (ParameterHandler<Object>[]) parameterHandlers;
    
    //因为上面示例的方法参数注解为Path,所以apply方法就是将url中的需要替换的id和page替换成真实的数据
    for (int p = 0; p < argumentCount; p++) {
      handlers[p].apply(requestBuilder, args[p]);
    }
    
    return callFactory.newCall(requestBuilder.build());
}
```

在构建OkHttp的Call之前,需要将url啊那些东西全部搞好,比如示例中的参数注解是Path,那么就需要先将url中的id和page换成真实的数据放在那里.然后

```java
//RequestBuilder#build
Request build() {
    HttpUrl url;
    HttpUrl.Builder urlBuilder = this.urlBuilder;
    if (urlBuilder != null) {
      url = urlBuilder.build();
    } else {
      // No query parameters triggered builder creation, just combine the relative URL and base URL.
      //noinspection ConstantConditions Non-null if urlBuilder is null.
      url = baseUrl.resolve(relativeUrl);
    }

    RequestBody body = this.body;
    if (body == null) {
      // Try to pull from one of the builders.
      if (formBuilder != null) {
        body = formBuilder.build();
      } else if (multipartBuilder != null) {
        body = multipartBuilder.build();
      } else if (hasBody) {
        // Body is absent, make an empty body.
        body = RequestBody.create(null, new byte[0]);
      }
    }

    MediaType contentType = this.contentType;
    if (contentType != null) {
      if (body != null) {
        body = new ContentTypeOverridingRequestBody(body, contentType);
      } else {
        requestBuilder.addHeader("Content-Type", contentType.toString());
      }
    }

    //requestBuilder是Request.Builder对象,在构造方法里面就初始化好了的
    //这里就是正常的OkHttp的网络请求该干的事儿了   封装url,method,然后Request构建出来
    return requestBuilder
        .url(url)
        .method(method, body)
        .build();
  }

```

到了这里,就是把之前获取的数据传入Request对象中,进行正常的OkHttp网络请求,构建一个Request对象.

然后通过这个Request对象创建Call对象,回到上面的OkHttpCall中的方法,只展示了剩下的逻辑

```java
@Override public void enqueue(final Callback<T> callback) {
    call.enqueue(new okhttp3.Callback() {
      @Override public void onResponse(okhttp3.Call call, okhttp3.Response rawResponse) {
        Response<T> response;
        try {
          response = parseResponse(rawResponse);
        } catch (Throwable e) {
          callFailure(e);
          return;
        }

        try {
          //这里是我们示例中传过来的那个CallBack对象,网络请求成功
          callback.onResponse(OkHttpCall.this, response);
        } catch (Throwable t) {
          t.printStackTrace();
        }
      }

      @Override public void onFailure(okhttp3.Call call, IOException e) {
        callFailure(e);
      }

      private void callFailure(Throwable e) {
        try {
          //网络请求失败
          callback.onFailure(OkHttpCall.this, e);
        } catch (Throwable t) {
          t.printStackTrace();
        }
      }
    });
  }
```

好了,到这里,网络请求算是完成了.如果对OkHttp访问网络有兴趣的请看[文章](https://blog.csdn.net/xfhy_/article/details/96909500)

## 5. 总结

Retrofit主要是利用动态代理模式来实现了接口方法,根据这个方法获取了网络访问请求所有的入参,然后再将入参组装配置OkHttp的请求方式,最终实现利用OkHttp来请求网络.方便开发者使用.代码封装得及其好,厉害.
