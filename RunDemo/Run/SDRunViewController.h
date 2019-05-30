//
//  SDRunViewController.h
//  RunDemo
//
//  Created by bnqc on 2019/5/30.
//  Copyright © 2019年 Dong. All rights reserved.
//

#import <UIKit/UIKit.h>

//GPS信号枚举
typedef enum : NSUInteger {
    StrengthGradeBest  = 1,//信号最好 可精确到0-20米
    StrengthGradeBetter,//信号强 可精确到20-100米
    StrengthGradeAverage,//信号弱 可精确到100-200米
    StrengthGradeBad,//信号很弱 ,200米开外
} StrengthGrade;

//运动状态枚举
typedef enum : NSUInteger {
    SportsStateIdle,//准备中
    SportsStateStart,//开始跑步,状态完成之后会自动流转到跑步中
    SportsStateRunning,//跑步中
    SportsStateStop,//停止跑步
    SportsStateUserPause,//用户暂停,必须交互启动
    SportsStateStystemPause,//系统暂停,可以自动重启(加速仪影响,不建议手动设置)
} SportsState;


@protocol SDRunViewControllerDelegate <NSObject>

@optional
//信号强度发生改变的回调
- (void)strengthGradeChangeActionWith:(StrengthGrade)nowGPS;

@end

@interface SDRunViewController : UIViewController

// SDRunViewController 是基于高德地图的实时轨迹绘制控制器.部分调优方向仿写于Keep

- (instancetype)initWithGaoDeAppKey:(NSString *)appKey;

- (void)startRunAction;

- (void)pauseRunAction;

- (void)systemPauseRunAction;

- (void)stopRunAction;

@property(nonatomic,weak)id <SDRunViewControllerDelegate>delegate;

/**
 当前信号强度
 */
@property(nonatomic,assign,readonly)StrengthGrade nowGPS;

/**
 当前跑步状态
 */
@property(nonatomic,assign)SportsState sportsState;

/**
 当前跑步距离
 */
@property(nonatomic,assign)NSInteger distance;

/**
 最大定位间隔 默认为2s
 */
@property(nonatomic,assign)NSTimeInterval locationTimeout;

/**
 定位图片,如果需要展示方向的话,图片中的箭头方向应为向上.
 */
@property(nonatomic,strong)UIImage *locationImage;

/**
 轨迹线条的颜色,默认为浅蓝色
 */
@property(nonatomic,strong)UIColor *lineColor;

/**
 轨迹线条的宽度,默认为8.0f;
 */
@property(nonatomic,assign)float lineWidth;

/**
 允许的最大速度,单位m/s.默认为100/9.74(飞人速度).
 */
@property(nonatomic,assign)float maxSpeed;

/**
 是否要考虑加速仪作为数据筛选条件? 当轨迹为跑步或者步行的业务是,建议要考虑,默认为Yes.
 */
@property(nonatomic,assign)BOOL isThinkMotion;



@end
