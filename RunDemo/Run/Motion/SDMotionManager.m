//
//  SDMotionManager.m
//  RunDemo
//
//  Created by bnqc on 2019/5/30.
//  Copyright © 2019年 Dong. All rights reserved.
//

#import "SDMotionManager.h"
#import <CoreMotion/CoreMotion.h>
#import "SDStepModel.h"

// 计步器开始计步步数（步）
#define ACCELERO_START_STEP 1

@interface SDMotionManager (){
    
    NSDate *lastDate;
}

@property(nonatomic,strong)CMMotionManager *motionManager;// 加速度传感器采集的原始单元
@property(nonatomic,strong)NSOperationQueue *motionQueue;//加速仪所需要的线程
@property(nonatomic,strong)NSDateFormatter *dateFormatter;//时间格式化

@property(nonatomic,weak)NSTimer *timer;// 计时器

@property(nonatomic,strong)NSMutableArray <SDStepModel *>*originalArray;
@property(nonatomic,strong)NSMutableArray <SDStepModel *>*stepArray;
@property(nonatomic,assign)NSInteger startStep;//计步器开始步数,作为一个判别值
@property(nonatomic,assign)NSInteger overTime;// 运动超时变量
@property(nonatomic,assign)NSInteger postTime;// 发送时间临时变量
@property(nonatomic,assign)BOOL isEndSpeed;// 停止运动临时变量

@end

@implementation SDMotionManager

static SDMotionManager *manager = nil;

+ (instancetype)defaultManager {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (manager == nil) {
            manager = [[SDMotionManager alloc] init];
            manager.postUpdateTime = 1.0f;
            manager.minSpaceTime = 0.259;
            manager.minStartTime = 2.0f;
            manager.maxStopTime = 10.0f;
            manager.maxG = -0.12;
        }
    });
    return manager;
}

#pragma mark - 懒加载

- (CMMotionManager *)motionManager {
    
    if (_motionManager == nil) {
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.accelerometerUpdateInterval = 1.0/40.0f;
    }
    return _motionManager;
}

- (NSOperationQueue *)motionQueue {
    
    if (_motionQueue == nil) {
        _motionQueue = [[NSOperationQueue alloc] init];
    }
    return _motionQueue;
}

- (NSDateFormatter *)dateFormatter {
    
    if (_dateFormatter == nil) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    }
    return _dateFormatter;
}

#pragma mark - 启动

- (void)start {
    
    //初始化数据
    manager.step = 0;
    manager.second = 0;
    manager.distance = 0;
    manager.overTime = 0;
    manager.postTime = 0;
    manager.isEndSpeed = YES;
    manager.originalArray = [NSMutableArray arrayWithCapacity:16];
    manager.stepArray = [NSMutableArray arrayWithCapacity:16];
    
    if (!manager.motionManager.isAccelerometerAvailable) {
        manager.motionState = MotionStateError;
        return;
    }
    [self startAccelerometerAction];
}

- (void)startAccelerometerAction {
    
    __weak typeof(self) weakself = self;
    @try {

        //  isAccelerometerAvailable方法用来查看加速度器的状态：是否Active（启动）。
        if (!self.motionManager.isAccelerometerActive) {

            self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(addTimeAction) userInfo:nil repeats:YES];
            [self.timer fire];
            
            [self.motionManager startAccelerometerUpdatesToQueue:self.motionQueue withHandler:^(CMAccelerometerData * _Nullable accelerometerData, NSError * _Nullable error) {
                
                if (!weakself.motionManager.isAccelerometerActive) {
                    return;
                }
                
                //三个方向加速度值
                double x = accelerometerData.acceleration.x;
                double y = accelerometerData.acceleration.y;
                double z = accelerometerData.acceleration.z;
                //g是一个double值 ,根据它的大小来判断是否计为1步.
                double g = sqrt(pow(x, 2) + pow(y, 2) + pow(z, 2)) - 1;
                
                //进行数据处理
                [weakself disposeAccelerometerDataWithG:g];
                
            }];
        }
    } @catch (NSException *exception) {
        manager.motionState = MotionStateError;
        return;
    }
}

// 原始数据振动幅度处理
- (void)disposeAccelerometerDataWithG:(double)g {
    
    SDStepModel *stepModel = [[SDStepModel alloc] init];
    stepModel.date = [NSDate dateWithTimeIntervalSinceNow:0];
    stepModel.record_time = [self.dateFormatter stringFromDate:stepModel.date];
    stepModel.g = g;
    [self.originalArray addObject:stepModel];
    
    if (self.originalArray.count == 10) {
        
        NSMutableArray *bufferArray = [[NSMutableArray alloc] initWithCapacity:10];
        bufferArray = [self.originalArray mutableCopy];
        
        //清空数组
        if (self.originalArray != nil) {
            [self.originalArray removeAllObjects];
        }
        
        //采点数组采集数据
        NSMutableArray *caiDianArray = [[NSMutableArray alloc] initWithCapacity:16];

        //遍历步数缓存数组
        for (int i = 1; i < bufferArray.count - 2; i++) {
            
            //如果数组个数大于3,继续,否则跳出循环,用连续的三个点,要判断其振幅是否一样,如果一样,不做处理
            if (![bufferArray objectAtIndex:i-1] || ![bufferArray objectAtIndex:i] || ![bufferArray objectAtIndex:i+1]) {
                continue;
            }
            
            SDStepModel *bufferPrevious = (SDStepModel *)[bufferArray objectAtIndex:i-1];
            SDStepModel *bufferCurrent = (SDStepModel *)[bufferArray objectAtIndex:i];
            SDStepModel *bufferNext = (SDStepModel *)[bufferArray objectAtIndex:i+1];
            //控制震动幅度,根据震动幅度让其加入踩点数组,
            if (bufferCurrent.g < self.maxG && bufferCurrent.g < bufferPrevious.g && bufferCurrent.g < bufferNext.g) {
                [caiDianArray addObject:bufferCurrent];
            }
        }
        
        //进行最后的处理工作
        [self makeUpStepArrayActionWithCaiDianArray:caiDianArray];
    }
}

// 根据采点数组进一步组合最后的数据
- (void)makeUpStepArrayActionWithCaiDianArray:(NSArray <SDStepModel *>*)caiDianArray {
    
    for (int i = 0; i < caiDianArray.count; i++) {

        SDStepModel *caidianCurrent = [caiDianArray objectAtIndex:i];
        
        if (self.stepArray.count == 0) {
            
            lastDate = caidianCurrent.date;
            [self.stepArray addObject:caidianCurrent];
        } else {
            
            int caiDianInterval = [caidianCurrent.date timeIntervalSinceDate:lastDate];
            
            // 如果两步之间的时间间距大于最小时间并且加速仪是工作状态,那么就需要处理当前数据点
            if (caiDianInterval > self.minSpaceTime && self.motionManager.isAccelerometerActive) {
             
                lastDate = caidianCurrent.date;
                
                // 计步器开始计步时间（秒)
                if (caiDianInterval >= self.minStartTime) {
                    self.startStep = 0;
                }
                
                //统计数据
                if (self.startStep < ACCELERO_START_STEP) {
                    self.startStep ++;
                    break;
                } else if (self.startStep == ACCELERO_START_STEP) {
                    self.startStep ++;
                    self.step = self.step + self.startStep;
                } else {
                    self.step ++;
                }
                
                //运动超时变量重置
                self.overTime = 0;
                self.motionState = MotionStateRun;

            }
        }
    }
}

// 计算运动时间,同时监控运动停止状态
- (void)addTimeAction {
    
    if (self.motionState == MotionStateRun) {
        
        self.second ++;
        self.postTime ++;
        self.isEndSpeed = YES;//重置条件
        if (self.postTime >= self.postUpdateTime) {
            self.postTime = 0;//重置为0;
            [[NSNotificationCenter defaultCenter] postNotificationName:MotionManagerUpdateNotificationName object:@{
                                                                                                                    MotionManagerStep:@(self.step),
                                                                                                                    MotionManagerTime:@(self.second)
                                                                                                                    }];
        }
    } else{
        
        if (self.isEndSpeed) {
            // isEndSpeed的作用是让该代码块只会执行一次,然后等待重新启动
            self.isEndSpeed = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:MotionManagerEndUpdateNotificationName object:nil];
        }
    }
    
    //运动超时变量增加
    self.overTime ++;
    
    //当停止时间大于预设的最大值时,我们就认为当前运动已经停止
    if (self.overTime >= self.maxStopTime) {
        self.motionState = MotionStateStop;
    }
}

#pragma mark - 停止

- (void)stop {
    
    if (_timer != nil) {
        _timer = nil;
        [_timer invalidate];
    }
    [manager.motionManager stopAccelerometerUpdates];
}


@end
