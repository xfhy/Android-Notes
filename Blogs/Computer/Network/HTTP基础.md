
### 什么是HTTP？

HTTP（HyperText Transfer Protocol，超文本传输协议），是客户端和服务器之间的一种数据传输协议。

### HTTP的工作方式

- 浏览器：用户输入网址后回车或点击链接->DNS查询->浏览器拼装HTTP报文并发送请求给服务器->服务器处理请求后发送响应报文给浏览器 -> 浏览器解析响应报文并使用渲染引擎显示
- 手机APP：用户点击或界面自动触发联网->代码调用拼装HTTP报文并发送请求到服务器->服务器处理请求后发送响应报文给手机->代码处理响应报文并作出相应处理（存储、展示、加工等）

### URI、URL

URI，Uniform Resource Identifier ，统一资源标识符。

URL，Uniform Resource Locator，统一资源定位符。描述了一台特定服务器上某资源的特定位置。它分为三部分：协议类型、服务器地址（和端口号）、路径Path。一般遵循语法：`协议类型://服务器地址[:端口号]/路径`。比如：`https://baidu.com/x/yy`

### 报文格式

分为2种：请求报文、响应报文

#### 请求报文

```
GET   /users   HTTP/1.1
Host: api.github.com
Content-Type: text/plain
Content-Length: 243

fafasfajfhajfjas
```

- 第一行是请求行
    - method: GET
    - path: /users
    - HTTP version : HTTP/1.1
- 第2、3、4行是Header
- 最后一行是Body

#### 响应报文

```
HTTP/1.1 200 0K
content-type: application/ json; charset=utf-8
cache-control: public, max-age=60, s-maxage=60
vary: Accept , Accept-Encoding
etag: W/"Ø2eec5b334bØe4c05253d3f4138daa46"
content-encoding: gzip

{"data":...}
```

- 第一行的状态行
    - HTTP version : HTTP/1.1
    - status code : 200
    - status message : OK
- 第2、3、4、5、6行是header
- 最后一行是Body

### 请求方法 Request Method

HTTP1.0 定义了三种请求方法： GET, POST 和 HEAD方法。

HTTP1.1 新增了六种请求方法：OPTIONS、PUT、PATCH、DELETE、TRACE 和 CONNECT 方法。

下面我们来讲讲常用的GET、POST、PUT、DELETE、HEAD

#### GET

GET请求用于获取资源，对服务器数据不进行修改，不发送Body。

```
GET /users/1 HTTP/1.1
Host: api.github.com
```

对应的Retrofit代码：

```java
@GET("/users/{id}")
Call<User> getUser(@Path("id") String id,@Query("gender") String gender);
```

#### POST

POST用于增加或修改资源，发送给服务器的内容写在Body里面。

```
POST  /users   HTTP/1.1
Host: api.github.com
Content-Type: application/x-www-form-urlencoded
Content-Length: 13

name=xfhy&gender=male
```

对应Retrofit代码

### 状态码 Status Code
### 首部 Header