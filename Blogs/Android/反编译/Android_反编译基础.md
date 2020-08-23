
## 1. jd-gui

用于查看jar源码,[下载地址](https://github.com/java-decompiler/jd-gui)

## 2. dex-tools-2.1-SNAPSHOT

[下载地址](https://github.com/pxb1988/dex2jar)

这个工具可以将dex文件转换成jar,当然还有其他功能.可以解压缩后配置成环境变量.

解压apk文件,进入到apk解压出来的目录下面,执行下面这条命令

```
d2j-dex2jar classes.dex
```

这条命令会将dex文件转成jar文件.有了jar文件再用上面的jd-gui进行查看源码.

不用脱壳什么的,这种方式,非常简单.这种方式已经可以拿到市面上大部分的apk源码了,但是对于梆梆加固的apk,没有效果.

## 3. 插件化

比如某安全卫士,会去下载jar包到`/data/user/0/包名`下面,这个里面访问需要root权限,然后我们找到之后,将其复制到sdcard表面,再push到电脑上.解压该jar之后,拿到dex文件,再将dex文件转成jar文件,查看源码,ok.

## 4. 反编译工具

jadx,可以直接反编译一个apk,简单方便

https://github.com/skylot/jadx
