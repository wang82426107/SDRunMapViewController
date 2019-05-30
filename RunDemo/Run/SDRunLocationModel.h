//
//  SDRunLocationModel.h
//  RunDemo
//
//  Created by bnqc on 2019/5/30.
//  Copyright © 2019年 Dong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import "SDRunViewController.h"

@interface SDRunLocationModel : NSObject

//SDRunLocationModel是跑步过程中每一条记录的Model

@property(nonatomic,assign)CLLocationCoordinate2D location;

@property(nonatomic,strong)NSDate *time;//每一次记录的时间点

@property(nonatomic,assign)StrengthGrade gpsStrength;//gps信号强度

@end
