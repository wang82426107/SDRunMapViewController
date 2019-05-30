//
//  SDMotionManager.h
//  RunDemo
//
//  Created by bnqc on 2019/5/30.
//  Copyright © 2019年 Dong. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    MotionStateRun,//运动状态
    MotionStateStop,//停止状态
    MotionStateError//错误状态,可能该设备不支持加速仪
} MotionState;

// 陀螺仪更新通知
#define MotionManagerUpdateNotificationName @"MotionManagerUpdateNotificationName"

//更新通知中字典的步数字段
#define MotionManagerStep @"MotionManagerUpdateStep"

//更新通知中字典的时间字段,单位秒
#define MotionManagerTime @"MotionManagerTime"

// 陀螺仪已停止更新通知
#define MotionManagerEndUpdateNotificationName @"MotionManagerEndUpdateNotificationName"

@interface SDMotionManager : NSObject

// SDMotionManager 是加速仪管理类

+ (instancetype)defaultManager;

/**
 计步器最小启动时间 默认为2秒;
 */
@property(nonatomic,assign)NSTimeInterval minStartTime;

/**
 计步器最长停止时间,大于该时间则停止 默认为10秒;
 */
@property(nonatomic,assign)NSTimeInterval maxStopTime;

/**
 发送更新通知的频率,停止通知不受其影响.默认为1秒;
 */
@property(nonatomic,assign)NSTimeInterval postUpdateTime;

/**
 运动状态
 */
@property(nonatomic,assign)MotionState motionState;

/**
 运动步数（总计）
 */
@property(nonatomic,assign)NSInteger step;

/**
 运动用时（总计）
 */
@property(nonatomic,assign)NSInteger second;

/**
 距离 (估算)
 */
@property(nonatomic,assign)NSInteger distance;

/**
 最大振动浮动,默认为 -0.12
 */
@property(nonatomic,assign)float maxG;

/**
 两步之间允许的最小时间间隔 默认为259毫秒;
 */
@property(nonatomic,assign)NSTimeInterval minSpaceTime;



- (void)start;

- (void)stop;



@end

