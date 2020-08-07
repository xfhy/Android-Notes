
> 平时使用ConstraintLayout,断断续续的,基本都是在自己的小demo里面使用.公司的项目暂时还没有使用.这次公司项目需要大改,我决定用上这个nice的布局.减少嵌套(之前的老代码,实在是嵌套得太深了....无力吐槽).

首先,ConstraintLayout是一个新的布局,它是直接继承自ViewGroup的,所以在兼容性方面是非常好的.官方称可以兼容到API 9.可以放心食用.

#### 一、Relative positioning  

先来看看下面一段简单示例:
```
<android.support.constraint.ConstraintLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <Button
        android:id="@+id/btn1"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="按钮1"/>

    <Button
        android:id="@+id/btn2"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        app:layout_constraintLeft_toRightOf="@+id/btn1"
        android:text="按钮2"/>

</android.support.constraint.ConstraintLayout>
```

![image](9ABBDB40D0884C5AA6391E364BFBF830)

上面有一个简单的属性:`layout_constraintLeft_toRightOf`,表示将按钮2放到按钮1的左边.如果没有这一句属性,那么两个按钮会重叠在一起,就像FrameLayout.

像这样的属性还有很多:
```
layout_constraintLeft_toLeftOf  我的左侧与你的左侧对齐
layout_constraintLeft_toRightOf  我的左侧与你的右侧对齐
layout_constraintRight_toLeftOf 我的右侧与你的左侧对齐
layout_constraintRight_toRightOf 我的右侧与你的右侧对齐
layout_constraintTop_toTopOf 我的顶部与你的顶部对齐
layout_constraintTop_toBottomOf 我的顶部与你的底部对齐 (相当于我在你下面)
layout_constraintBottom_toTopOf 
layout_constraintBottom_toBottomOf
layout_constraintBaseline_toBaselineOf 基线对齐
layout_constraintStart_toEndOf 我的左侧与你的右侧对齐
layout_constraintStart_toStartOf
layout_constraintEnd_toStartOf
layout_constraintEnd_toEndOf
```
上面的属性都非常好理解,除了一个相对陌生的`layout_constraintBaseline_toBaselineOf`基线对齐.咱们上代码:
```xml
 <TextView
        android:id="@+id/btn1"
        android:text="按钮1"
        android:textSize="26sp"/>

    <TextView
        android:id="@+id/btn2"
        android:text="按钮2"
        app:layout_constraintBaseline_toBaselineOf="@+id/btn1"
        app:layout_constraintLeft_toRightOf="@+id/btn1"/>
```
![image](17A4BEA1BE4F441C92D09AEA7656F492)

一目了然,相当于文字的基线是对齐了的.如果没有加`layout_constraintBaseline_toBaselineOf`属性,那么是下面这样的:

![image](06063B4972C84E12A71A788A4A61CEF8)


#### 二、与父亲边缘对齐

当需要子view放在父view的底部或者最右侧时. 我们使用:

```xml
<android.support.constraint.ConstraintLayout
        app:layout_constraintEnd_toEndOf="parent">

        <TextView
            android:text="按钮2"
            app:layout_constraintBottom_toBottomOf="parent"/>

    </android.support.constraint.ConstraintLayout>
```
![image](6AC3D9D6A8634B67A36EFFDAECB9E0F7)

```
app:layout_constraintBottom_toBottomOf="parent"  我的底部与父亲底部对齐
app:layout_constraintTop_toTopOf="parent"   我的顶部与父亲的顶部对齐
app:layout_constraintLeft_toLeftOf="parent"  我的左侧与父亲的左侧对齐
app:layout_constraintRight_toRightOf="parent"  我的右侧与父亲的右侧对齐
```

#### 三、居中对齐

![image](06039B3438824F23A4D962EB7FEFF906)

下面的TextView,与父亲左侧对齐,与父亲右侧对齐,所以,最右,它水平居中对齐.

```xml
<TextView
        app:layout_constraintLeft_toLeftOf="parent"
        app:layout_constraintRight_toRightOf="parent"/>
```

![image](E309BE9D1E5A48859BC348CEAB717C8C)

可能你也想到了,居中对齐其实就是2个对齐方式相结合.最后产生的效果.  比如:

```
这是垂直居中
app:layout_constraintTop_toTopOf="parent"
app:layout_constraintBottom_toBottomOf="parent"
```

```
位于父亲的正中央
app:layout_constraintBottom_toBottomOf="parent"
app:layout_constraintLeft_toLeftOf="parent"
app:layout_constraintRight_toRightOf="parent"
app:layout_constraintTop_toTopOf="parent"
```


#### 四、边距

![image](D5AA0A67A7CC420682C5A7942D920AF3)

边距和原来是一样的.

```
android:layout_marginStart
android:layout_marginEnd
android:layout_marginLeft
android:layout_marginTop
android:layout_marginRight
android:layout_marginBottom
```

举个例子:

```xml
<TextView
    android:id="@+id/btn1"
    android:text="按钮1"
    android:textSize="26sp"/>
<TextView
    android:id="@+id/btn2"
    android:text="按钮2"
    android:layout_marginStart="40dp"
    app:layout_constraintLeft_toRightOf="@+id/btn1"/>
```

效果如下:

![image](A65C7680017540B3B495448F33E16C85)

#### Bias(偏向某一边)

上面的水平居中,是使用的与父亲左侧对齐+与父亲右侧对齐.  可以理解为左右的有一种约束力,默认情况下,左右的力度是一样大的,那么view就居中了.

当左侧的力度大一些时,view就会偏向左侧.就像下面这样.

![image](BB0C7376A24F44B39568F76E2D1D34DF)

当我们需要改变这种约束力的时候,需要用到如下属性:

```
layout_constraintHorizontal_bias  水平约束力
layout_constraintVertical_bias  垂直约束力
```

来举个例子:

```xml
<android.support.constraint.ConstraintLayout
    <Button
        android:text="按钮1"
        app:layout_constraintHorizontal_bias="0.3"
        app:layout_constraintLeft_toLeftOf="parent"
        app:layout_constraintRight_toRightOf="parent"/>
</android.support.constraint.ConstraintLayout>        
```

![image](F8012EDC726743EDAB5C7E948B870A2C)

可以看到,左右有2根约束线.左侧短一些.那么就偏向于左侧

#### 五、Circular positioning (Added in 1.1)

> 翻译为:圆形的定位 ? 

这个就比较牛逼了,可以以角度和距离约束某个view中心相对于另一个view的中心,

可能比较抽象,来看看谷歌画的图:

![image](C020CEA52A1D4315ABCB157DC0705216)

他的属性有:

```
layout_constraintCircle ：引用另一个小部件ID
layout_constraintCircleRadius ：到其他小部件中心的距离
layout_constraintCircleAngle ：小部件应该处于哪个角度（以度为单位，从0到360）
```

举个例子:

```xml
<Button
    android:id="@+id/btn1"
    android:text="按钮1"/>
<Button
    android:text="按钮2"
    app:layout_constraintCircle="@+id/btn1"
    app:layout_constraintCircleRadius="100dp"
    app:layout_constraintCircleAngle="145"/>
```

![image](31E79ECAEA4F4D84BBFA80CC6583DA57)

#### 六、Visibility behavior 可见性行为

当一个View在ConstraintLayout中被设置为gone,那么你可以把它当做一个点(这个view所有的margin都将失效).  这个点是假设是实际存在的.

![image](EA2729CC32F9415093C0E197BAA5DC8C)

举个例子:

```
<Button
    android:id="@+id/btn1"
    android:text="按钮1"
    android:textSize="26sp"/>


<Button
    android:id="@+id/btn2"
    android:layout_marginStart="20dp"
    android:text="按钮2"
    android:visibility="gone"
    app:layout_constraintLeft_toRightOf="@+id/btn1"/>

<Button
    android:id="@+id/btn3"
    android:layout_marginStart="20dp"
    android:text="按钮3"
    app:layout_constraintLeft_toRightOf="@+id/btn2"/>
```

![image](7935B80A30F94D65B0C13A263D6CB26E)

可以看到,按钮3和按钮1中间的margin只有20.


再举个例子:

```xml
 <Button
    android:id="@+id/btn2"
    android:layout_marginStart="20dp"
    android:text="按钮2"
    app:layout_constraintBottom_toBottomOf="parent"
    app:layout_constraintLeft_toLeftOf="parent"
    app:layout_constraintRight_toRightOf="parent"
    app:layout_constraintTop_toTopOf="parent"/>

<Button
    android:id="@+id/btn3"
    android:text="按钮3"
    app:layout_constraintLeft_toRightOf="@+id/btn2"
    app:layout_constraintTop_toTopOf="@+id/btn2"
    app:layout_constraintBottom_toBottomOf="@+id/btn2"/>
```

我将按钮3放到按钮2的右侧,这时是没有给按钮2加`android:visibility="gone"`的.

![image](DE810ED40FD2429CA480B31491711B92)

现在我们来给按钮2加上`android:visibility="gone"`

![image](54ABE24F468D40A8A32DFA988FCB38FB)

这时,按钮2相当于缩小成一个点,那么按钮3还是在他的右侧不离不弃.

####  七、Dimensions constraints 尺寸限制

在ConstraintLayout中,可以给一个view设置最小和最大尺寸.

属性如下(这些属性只有在给出的宽度或高度为wrap_content时才会生效):

```
android:minWidth 设置布局的最小宽度
android:minHeight 设置布局的最小高度
android:maxWidth 设置布局的最大宽度
android:maxHeight 设置布局的最大高度
```

#### 八、Widgets dimension constraints  宽高约束

平时我们使用`android:layout_width和 android:layout_height`来指定view的宽和高.

在ConstraintLayout中也是一样,只不过多了一个0dp.

- 使用长度,例如
- 使用wrap_content，view计算自己的大小
- 使用0dp，相当于“ MATCH_CONSTRAINT”


![image](FAE9F8A07F704D839BD53275F16C9C49)

下面是例子

```
<Button
    android:id="@+id/btn1"
    android:layout_width="100dp"
    android:layout_height="wrap_content"
    android:text="按钮1"
    app:layout_constraintLeft_toLeftOf="parent"
    app:layout_constraintRight_toRightOf="parent"/>

<Button
    android:id="@+id/btn2"
    android:layout_width="0dp"
    android:layout_height="wrap_content"
    android:text="按钮2"
    app:layout_constraintLeft_toLeftOf="parent"
    app:layout_constraintRight_toRightOf="parent"
    app:layout_constraintTop_toBottomOf="@+id/btn1"/>


<Button
    android:id="@+id/btn3"
    android:layout_width="0dp"
    android:layout_height="wrap_content"
    android:layout_marginStart="60dp"
    android:text="按钮3"
    app:layout_constraintLeft_toLeftOf="parent"
    app:layout_constraintRight_toRightOf="parent"
    app:layout_constraintTop_toBottomOf="@+id/btn2"/>
```

展示出来的是:

![image](E9F3B3F9BC6848FABDB86FF9F2A3B872)

#### 九、WRAP_CONTENT：强制约束（在1.1中添加）

当一个view的宽或高,设置成wrap_content时,如果里面的内容实在特别宽的时候,他的约束会出现问题.我们来看一个小栗子:

```xml
<Button
    android:id="@+id/btn1"
    android:layout_width="100dp"
    android:layout_height="wrap_content"
    android:text="Q"/>

<Button
    android:id="@+id/btn2"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:text="VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
    app:layout_constraintLeft_toRightOf="@id/btn1"
    app:layout_constraintRight_toRightOf="parent"
    app:layout_constraintTop_toBottomOf="@id/btn1"/>
```

![image](C27B3B41662B46CF957AC71E8A33D352)

从右侧的图片可以看出,按钮2里面的内容确实是在按钮1的内容的右侧.但是按钮2整个来说,却是没有整个的在按钮1的右侧.

这时需要用到下面2个属性

```
app:layout_constrainedWidth=”true|false”
app:layout_constrainedHeight=”true|false”
```

给按钮2加一个`app:layout_constrainedWidth="true"`,来看效果:

![image](3E719F9268F144C098F88828B1185193)

哈哈,又看到了我们想要的效果.爽歪歪.

#### 十、MATCH_CONSTRAINT尺寸（在1.1中添加）

当一个view的长宽设置为MATCH_CONSTRAINT(即0dp)时,默认是使该view占用所有的可用的空间. 这里有几个额外的属性

```
layout_constraintWidth_min和layout_constraintHeight_min：将设置此维度的最小大小
layout_constraintWidth_max和layout_constraintHeight_max：将设置此维度的最大大小
layout_constraintWidth_percent和layout_constraintHeight_percent：将此维度的大小设置为父级的百分比
```

这里简单举个百分比的例子:居中并且view的宽是父亲的一半

```xml
 <Button
    android:id="@+id/btn1"
    android:layout_width="0dp"
    android:layout_height="wrap_content"
    android:text="Q"
    app:layout_constraintLeft_toLeftOf="parent"
    app:layout_constraintRight_toRightOf="parent"
    app:layout_constraintWidth_percent="0.5"/>
```

![image](B60CA01A91D145198F9E03AA569D4869)

It's so easy! 这极大的减少了我们的工作量.

**注意**

- 百分比布局是必须和MATCH_CONSTRAINT(0dp)一起使用
- `layout_constraintWidth_percent 或layout_constraintHeight_percent`属性设置为0到1之间的值


#### 十一、按比例设置宽高(Ratio)

可以设置View的宽高比例,需要将至少一个约束维度设置为0dp（即`MATCH_CONSTRAINT`）,再设置`layout_constraintDimensionRatio`.

举例子:

```xml
<Button
    android:layout_width="0dp"
    android:layout_height="0dp"
    android:text="按钮"
    app:layout_constraintDimensionRatio="16:9"
    app:layout_constraintLeft_toLeftOf="parent"
    app:layout_constraintRight_toRightOf="parent"
    app:layout_constraintTop_toTopOf="parent"/>
```

![image](130DF8050CDF44FE92FADDBA8B3E89D8)

该比率可表示为：

- 浮点值，表示宽度和高度之间的比率
- “宽度：高度”形式的比率

如果两个尺寸都设置为MATCH_CONSTRAINT（0dp），也可以使用比率。在这种情况下，系统设置满足所有约束的最大尺寸并保持指定的纵横比。要根据另一个特定边的尺寸限制一个特定边，可以预先附加W,“或” H,分别约束宽度或高度。例如，如果一个尺寸受两个目标约束（例如，宽度为0dp且以父节点为中心），则可以指示应该约束哪一边，通过 在比率前添加字母W（用于约束宽度）或H（用于约束高度），用逗号分隔：

```
<Button android:layout_width="0dp"
   android:layout_height="0dp"
   app:layout_constraintDimensionRatio="H,16:9"
   app:layout_constraintBottom_toBottomOf="parent"
   app:layout_constraintTop_toTopOf="parent"/>
```

上面的代码将按照16：9的比例设置按钮的高度，而按钮的宽度将匹配父项的约束。

#### 十二、Chains（链）

设置属性layout_constraintHorizontal_chainStyle或layout_constraintVertical_chainStyle链的第一个元素时，链的行为将根据指定的样式（默认值CHAIN_SPREAD）更改。

- CHAIN_SPREAD - 元素将展开（默认样式）
- 加权链接CHAIN_SPREAD模式，如果设置了一些小部件MATCH_CONSTRAINT，它们将分割可用空间
- CHAIN_SPREAD_INSIDE - 类似，但链的端点不会分散
- CHAIN_PACKED - 链条的元素将被包装在一起。然后，子项的水平或垂直偏差属性将影响打包元素的定位

![image](90AB6B5CE4C74D92A489DBE25F28B09E)

下面是一个类似LinearLayout的weight的效果,需要用到`layout_constraintHorizontal_weight`属性:

```xml
<Button
    android:id="@+id/btn1"
    android:layout_width="0dp"
    android:layout_height="wrap_content"
    android:text="A"
    app:layout_constraintEnd_toStartOf="@id/btn2"
    app:layout_constraintHorizontal_chainStyle="spread"
    app:layout_constraintHorizontal_weight="1"
    app:layout_constraintStart_toStartOf="parent"/>


<Button
    android:id="@+id/btn2"
    android:layout_width="0dp"
    android:layout_height="wrap_content"
    android:text="按钮2"
    app:layout_constraintEnd_toStartOf="@id/btn3"
    app:layout_constraintHorizontal_weight="2"
    app:layout_constraintStart_toEndOf="@id/btn1"/>

<Button
    android:id="@+id/btn3"
    android:layout_width="0dp"
    android:layout_height="wrap_content"
    android:text="问问"
    app:layout_constraintEnd_toEndOf="parent"
    app:layout_constraintHorizontal_weight="3"
    app:layout_constraintStart_toEndOf="@id/btn2"/>
```

例子的效果图如下:

![image](4FE3FA2F232C47DDBDE0AB8EAC3E2F86)

#### 十三、Guideline

> 这是一个虚拟视图

Guideline可以创建相对于ConstraintLayout的水平或者垂直准线. 这根辅助线,有时候可以帮助我们定位.


```
layout_constraintGuide_begin   距离父亲起始位置的距离（左侧或顶部）
layout_constraintGuide_end    距离父亲结束位置的距离（右侧或底部）
layout_constraintGuide_percent    距离父亲宽度或高度的百分比(取值范围0-1)
```

我们拿辅助线干嘛??? 比如有时候,可能会有这样的需求,有两个按钮,在屏幕中央一左一右.  如果是以前的话,我会搞一个LinearLayout,.然后将LinearLayout居中,然后按钮一左一右.

效果图如下:

![image](7F9AD9E66AEC40A6B1226CB8E6BD2E1D)


现在我们使用Guideline的话,就超级方便了,看代码:

```xml
<!--水平居中-->
<android.support.constraint.Guideline
    android:id="@+id/gl_center"
    android:layout_width="0dp"
    android:layout_height="wrap_content"
    android:orientation="vertical"
    app:layout_constraintGuide_percent="0.5"/>

<Button
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:text="按钮1"
    app:layout_constraintEnd_toStartOf="@id/gl_center"/>

<Button
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:text="按钮2"
    app:layout_constraintLeft_toRightOf="@id/gl_center"/>
```

#### 十四、Barrier

> 虚拟视图

Barrier是一个类似于屏障的东西.它和Guideline比起来更加灵活.它可以用来约束多个view.

比如下面的姓名和联系方式,右侧的EditText是肯定需要左侧对齐的,左侧的2个TextView可以看成一个整体,Barrier会在最宽的那个TextView的右边,然后右侧的EditText在Barrier的右侧.

![image](9103160F4648420A95B00A965F803C35)

Barrier有2个属性

- **barrierDirection**，取值有top、bottom、left、right、start、end，用于控制 Barrier 相对于给定的 View 的位置。比如在上面的栗子中，Barrier 应该在 姓名TextView 的右侧，因此这里取值right（也可end，可随意使用.这个right和end的问题,其实在RelativeLayout中就有体现,在RelativeLayout中写left或者right时会给你一个警告,让你换成start和end）。 
- **constraint_referenced_ids**，取值是要依赖的控件的id（不需要@+id/）。Barrier 将会使用ids中最大的一个的宽（高）作为自己的位置。

**ps**:这个东西有一个小坑,如果你写完代码,发现没什么问题,但是预览出来的效果却不是你想要的.这时,运行一下程序即可.然后预览就正常了,在手机上展示的也是正常的.

例子的代码如下(如果预览不正确,那么一定要运行一下,不要怀疑是自己代码写错了):
```xml
<TextView
    android:id="@+id/tv_name"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:text="姓名:"
    app:layout_constraintBottom_toBottomOf="@id/tvTitleText"/>

<TextView
    android:id="@+id/tv_phone"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:text="联系方式:"
    app:layout_constraintBottom_toBottomOf="@id/tvContentText"
    app:layout_constraintTop_toBottomOf="@+id/tv_name"/>

<EditText
    android:id="@+id/tvTitleText"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:background="null"
    android:text="张三"
    android:textSize="14sp"
    app:layout_constraintStart_toEndOf="@+id/barrier2"/>

<EditText
    android:id="@+id/tvContentText"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:background="null"
    android:text="xxxxxxxxxxxxxxx"
    android:textSize="14sp"
    app:layout_constraintStart_toEndOf="@+id/barrier2"
    app:layout_constraintTop_toBottomOf="@+id/tvTitleText"/>

<android.support.constraint.Barrier
    android:id="@+id/barrier2"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    app:barrierDirection="right"
    app:constraint_referenced_ids="tv_name,tv_phone"/>
```


#### 十五、Group 

> 固定思议,这是一个组.  这也是一个虚拟视图.

可以把View放到里面,然后Group可以同时控制这些view的隐藏.

```xml
<android.support.constraint.Group
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:visibility="gone"
    app:constraint_referenced_ids="btn1,btn2"/>

<Button
    android:id="@+id/btn1"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:text="按钮1"/>

<Button
    android:id="@+id/btn2"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:text="按钮2"
    app:layout_constraintTop_toBottomOf="@id/btn1"/>
```

- Group有一个属性`constraint_referenced_ids`,可以将那些需要同时隐藏的view丢进去.
- 别将view放Group包起来.这样会报错,因为Group只是一个不执行onDraw()的View.
- 使用多个 Group 时，尽量不要将某个View重复的放在 多个 Group 中，实测可能会导致隐藏失效.

#### 十六、何为虚拟视图

上面我们列举的虚拟视图一共有:
- Guideline
- Barrier
- Group

> 来我们看看源码


```java
//Guideline

public class Guideline extends View {
public Guideline(Context context) {
    super(context);
    //这个8是什么呢?  
    //public static final int GONE = 0x00000008;
    //其实是View.GONE的值
    super.setVisibility(8);
}

public Guideline(Context context, AttributeSet attrs) {
    super(context, attrs);
    super.setVisibility(8);
}

public Guideline(Context context, AttributeSet attrs, int defStyleAttr) {
    super(context, attrs, defStyleAttr);
    super.setVisibility(8);
}

public Guideline(Context context, AttributeSet attrs, int defStyleAttr, int defStyleRes) {
    super(context, attrs, defStyleAttr);
    super.setVisibility(8);
}

//可见性永远为GONE
public void setVisibility(int visibility) {
}

//没有绘画
public void draw(Canvas canvas) {
}

//大小永远为0
protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
    this.setMeasuredDimension(0, 0);
}
```

我们看到Guideline其实是一个普通的View,然后在构造函数里将自己设置为GONE

- 并且setVisibility()为空方法,该View就永远为GONE了.
- draw()方法为空,意思是不用去绘画.
- onMeasure()中将自己长宽设置成0.

综上所述,我觉得这个Guideline就是一个不可见的且不用测量,不用绘制,那么我们就可以忽略其绘制消耗.

然后Barrier和Group都是继承自ConstraintHelper的,ConstraintHelper是一个View.ConstraintHelper的onDraw()和onMeasure()如下:

```java
public void onDraw(Canvas canvas) {
}

protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
    //mUseViewMeasure一直是false,在Group中用到了,但是还是将它置为false了.
    if (this.mUseViewMeasure) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec);
    } else {
        this.setMeasuredDimension(0, 0);
    }

}
```

哈哈,其实是和Guideline一样的嘛,还是可以忽略其带来的性能消耗嘛.上面的mUseViewMeasure一直是false,所以长宽一直为0.

所以我们可以将Guideline,Barrier,Group视为虚拟试图,因为它们几乎不会带来多的绘制性能损耗.我是这样理解的.

#### 十七、Optimizer优化(add in 1.1)

可以通过将标签app：layout_optimizationLevel元素添加到ConstraintLayout来决定应用哪些优化。这个我感觉还处于实验性的阶段,暂时先别用..哈哈

使用方式如下:

```
<android.support.constraint.ConstraintLayout 
    app:layout_optimizationLevel="standard|dimensions|chains"
```

- none：不优化
- standard：默认,仅优化直接和障碍约束
- direct：优化直接约束
- barrier：优化障碍约束
- chain：优化链条约束
- dimensions: 优化维度测量，减少匹配约束元素的度量数量

#### 总结

我把一些常用的属性和怎么用都列举出来,方便大家查阅.如有不对的地方,欢迎指正.

