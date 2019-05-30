//
//  SDStepModel.h
//  RunDemo
//
//  Created by bnqc on 2019/5/30.
//  Copyright © 2019年 Dong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SDStepModel : NSObject

//g是一个震动幅度的系数,通过一定的判断条件来判断是否计做一步
@property(nonatomic,assign) double g;

@property(nonatomic,strong) NSDate *date;

@property(nonatomic,assign) int record_no;

@property(nonatomic, strong) NSString *record_time;

@property(nonatomic,assign) int step;

@end

