# SDRunMapViewController

跑步运动轨迹不知道如何优化?看这里就OK了~

* 第一,速度优化
* 第二,加速仪优化

大家需要改造的控制器就是 **SDRunViewController**,初始化方法如下所示.

```
    SDRunViewController *rootVC = [[SDRunViewController alloc] initWithGaoDeAppKey:@"高德地图AppKey"];
```

然后改造**SDRunViewController**UI即可.

逻辑部分可以参考[iOS跑步软件开发-从无到有](https://www.jianshu.com/p/3f37bece55f8)
