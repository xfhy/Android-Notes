
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

```java
@FormUrlEncoded
@POST("/users")
Call<User> addUser(@Field("name") String name,@Field("gender") String gender);
```

#### PUT

PUT用于修改资源，发送给服务器的内容写在Body里面

```
PUT  /useers/1  HTTP/1.1
Host: api.github.com
Content-Type: application/x-www-form-urlencoded
Content-Length: 13

gender=male
```

对应Retrofit代码：

```java
@FormUrlEncoded
@PUT("users/{id}")
Call<User> updateGender(@Path("id") String id,@Field("gender") String gender);
```

#### DELETE

DELETE用于删除资源，不发送Body。

```
DELETE  /users/1  HTTP/1.1
Host: api.github.com
```

对应Retrofit代码：

```java
@DELETE("/users/{id}")
Call<User> getUser(@Path("id") String id,@Query("gender") String gender);
```

#### HEAD

HEAD方法与GET类似，但是服务器只会返回首部，不会返回Body。

作用：

- 在不获取资源的情况下了解资源的情况（比如，判断其类型）
- 通过查看响应中的状态码，查看资源是否存在
- 通过查看首部，测试资源是否被修改

### 状态码 Status Code

状态码是三位数字，用于对响应结果做出类型化描述（如「获取成功」「内容未找到」）

- 1xx: 临时性消息。 如：100（继续发送）、101（正在切换协议）
- 2xx: 成功。如200（OK）、201（创建成功）
- 3xx：重定向。如301（永久移动）、302（暂时移动）、304（内容未改变）
- 4xx：客户端错误。如400（客户端请求错误）、401（认证失败）、403（被禁止）、404（找不到内容）
- 5xx：服务器错误。如500（服务器内部错误）

### 首部 Header

HTTP协议的请求和响应报文中必定包含HTTP首部，也就是Header。HTTP消息的元数据（metadata），有些东西放Body里面不合理，放Header里面就刚好。

下面来介绍一些常见的Header：

#### HOST

目标主机。这个Host不是在网络上用于寻址的，而是在目标服务器上用于定位子服务器的。

#### Content-Type

指定Body的类型，主要有4类：

- text/html
- x-www-form-urlencoded
- multipart/form-data
- application/json,image/jpeg,application/zip ...

##### text/html

请web页面返回响应的类型，Body中返回HTML文本。格式如下：

```
HTTP/1.1  200  OK
Content-Type: text/html; charset=utf-8
Content-Length: 432

<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8"> 
......
```

##### x-www-form-urlencoded

web页面纯文本表单的提交方式

```
POST  /users/  HTTP/1.1
Host: api.github.com
Content-Type: application/x-www-form-urlencoded
Content-Length: 21

name=xfhy&gender=male
```

对应Retrofit代码：

```java
 
@FormUrlEncoded
@POST("/users")
Call<User> addUser(@Field("name") String name,@Field("gender") String gender);
```

##### multipart/form-data

web页面含有二进制文件时的提交方式，比如同时提交一个文件+文件名。

```
 
POST /users HTTP/1.1
Host: api.github.com
Content-Type: multipart/form-data; boundary=---- WebKitFormBoundary7MA4YWxkTrZu0gW 
Content-Length: 2382

------WebKitFormBoundary7MA4YWxkTrZu0gW 
Content-Disposition: form-data; name="name"

xfhy 
------WebKitFormBoundary7MA4YWxkTrZu0gW 
Content-Disposition: form-data; name="avatar"; 
filename="avatar.jpg"
Content-Type: image/jpeg

JFIFHHvOwX9jximQrWa...... 
------WebKitFormBoundary7MA4YWxkTrZu0gW--
```
其中boundary是分割符的意思，参数的名称是name，值是xfhy。

对应Retrofit代码：

```java
 
@Multipart
@POST("/users")
Call<User> addUser(@Part("name") RequestBody name,@Part("avatar") RequestBody avatar);
...
RequestBody namePart = RequestBody.create(MediaType.parse("text/plain"), nameStr);
RequestBody avatarPart = RequestBody.create(MediaType.parse("image/jpeg"), avatarFile);
api.addUser(namePart, avatarPart);
```

##### application/json,image/jpeg,application/zip ...

#### Content-Length
#### Transfer: chunked(分块传输编码)
#### Location
#### User-Agent
#### Range/Accept-Range
#### 其他Header
