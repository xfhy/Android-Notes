
Choreographer对于一些同学来说可能比较陌生，但是，它其实出场率是极高的。View的三大流程就是靠着Choreographer来实现的，翻译过来这个单词的意思是“编舞者”。下面我们来详细介绍，它的具体作用是什么。

### 1. 前置知识

在讲Choreographer之前，必须得提一些前置知识来辅助学习。

#### 刷新率

刷新率代表屏幕在一秒内刷新屏幕的次数，这个值用赫兹来表示，取决于硬件的固定参数。这个值一般是60Hz，即每16.66ms刷新一次屏幕。

#### 帧速率

帧速率代表了GPU在一秒内绘制操作的帧数，比如30FPS/60FPS。在这种情况下，高点的帧速率总是好的。

#### VSYNC

刷新率和帧速率需要协同工作，才能让应用程序的内容显示到屏幕上，GPU会获取图像数据进行绘制，然后硬件负责把内容呈现到屏幕上，这将在应用程序的生命周期中周而复始地发生。

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/%E5%88%B7%E6%96%B0%E7%8E%87%E5%92%8C%E5%B8%A7%E9%80%9F%E7%8E%87%E5%8D%8F%E5%90%8C%E5%B7%A5%E4%BD%9C.webp)

刷新率和帧速率并不是总能够保持相同的节奏：

如果帧速率实际上比刷新率快，那么就会出现一些视觉上的问题，下面的图中可以看到，当帧速率在100fps而刷新率只有75Hz的时候，GPU所渲染的图像并非全部都被显示出来。

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/%E5%B8%A7%E9%80%9F%E7%8E%87%E6%AF%94%E5%88%B7%E6%96%B0%E7%8E%87%E5%BF%AB%E7%9A%84%E6%83%85%E5%86%B5.webp)

刷新率和帧速率不一致会导致屏幕撕裂效果。当GPU正在写入帧数据，从顶部开始，新的一帧覆盖前一帧，并立刻输出一行内容。屏幕开始刷新的时候，实际上并不知道缓冲区是什么状态（不知道缓冲区中的一帧是否绘制完毕，绘制未完的话，就是某些部分是这一帧的，某些部分是上一帧的），因此它从GPU中抓住的帧可能并不是完全完整的。

![](https://raw.githubusercontent.com/xfhy/Android-Notes/master/Images/%E5%B1%8F%E5%B9%95%E6%92%95%E8%A3%82%E7%8E%B0%E8%B1%A1.webp)

**VSYNC是为了解决屏幕刷新率和GPU帧率不一致导致的“屏幕撕裂”问题**。

#### FPS



### 应用卡顿

- https://www.youtube.com/watch?v=1iaHxmfZGGc&list=UU_x5XG1OV2P6uZZ5FSM9Ttw&index=1964
- https://juejin.cn/post/6890407553457963022
- http://gityuan.com/2017/02/25/choreographer/