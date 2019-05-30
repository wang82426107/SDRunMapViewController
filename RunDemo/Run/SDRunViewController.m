//
//  SDRunViewController.m
//  RunDemo
//
//  Created by bnqc on 2019/5/30.
//  Copyright © 2019年 Dong. All rights reserved.
//

#import "SDRunViewController.h"

#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import "SDRunLocationModel.h"
#import <MAMapKit/MAMapKit.h>
#import "SDMotionManager.h"
#import "UIImage+Rotate.h"

#define DefaultAppKey @"6a1e9064d51bb95bdeb10435fdfed5d4"

@interface SDRunViewController ()<MAMapViewDelegate,AMapLocationManagerDelegate>

@property(nonatomic,strong)AMapLocationManager *locationManager;
@property(nonatomic,strong)MAMapView *mapView;

@property(nonatomic,strong)MAAnnotationView *myAnnotationView;//我的当前位置的大头针
@property(nonatomic,strong)MAPolyline *polyline;//当前绘制的轨迹曲线

@property(nonatomic,strong)NSMutableArray <SDRunLocationModel *>*perfectArray;//优化完成的定位数据数组
@property(nonatomic,strong)NSMutableArray <SDRunLocationModel *>*drawLineArray;//待绘制定位线数据
@property(nonatomic,assign)int lastDrawIndex;//绘制最后数据的下标次数(perfectArray)
@property(nonatomic,assign)NSInteger locationNumber;//定位次数
@property(nonatomic,assign)BOOL isFirstLocation;//是否是第一次定位

@end

@implementation SDRunViewController

- (instancetype)initWithGaoDeAppKey:(NSString *)appKey {
    
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateStepAction:) name:MotionManagerUpdateNotificationName object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endUpdateAction) name:MotionManagerEndUpdateNotificationName object:nil];
        [AMapServices sharedServices].apiKey = appKey == nil ? DefaultAppKey : appKey;
        self.lineColor = [UIColor colorWithRed:0/255.0 green:191/255.0 blue:255/255.0 alpha:1.0];
        self.locationImage = [UIImage imageNamed:@"running_point_icon"];
        self.sportsState = SportsStateIdle;
        _nowGPS = StrengthGradeBest;
        self.locationTimeout = 2;
        self.maxSpeed = 100/9.74;
        self.isThinkMotion = YES;
        self.lineWidth = 8.0f;
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self.view addSubview:self.mapView];
}

- (void)updateStepAction:(NSNotification *)notification {
    
    NSLog(@"运动中.");
    if (self.sportsState == SportsStateStystemPause) {
        self.sportsState = SportsStateRunning;
    }
}

- (void)endUpdateAction {
    
    NSLog(@"停止计步");
    self.sportsState = SportsStateStystemPause;
}

#pragma mark - 懒加载

- (AMapLocationManager *)locationManager {
    
    if (_locationManager == nil) {
        _locationManager = [[AMapLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.distanceFilter = 10;//设置移动精度(单位:米)
        _locationManager.locationTimeout = self.locationTimeout;//定位时间
        _locationManager.allowsBackgroundLocationUpdates = YES;//开启后台定位
        [_locationManager setLocatingWithReGeocode:YES];
    }
    return _locationManager;
}

-(MAMapView *)mapView {
    
    if (_mapView == nil) {
        _mapView = [[MAMapView alloc] initWithFrame:self.view.bounds];
        _mapView.desiredAccuracy = kCLLocationAccuracyBest;
        _mapView.distanceFilter = 1.0f;
        _mapView.showsUserLocation = YES;
        _mapView.userTrackingMode = MAUserTrackingModeFollow;//地图跟着位置移动
        _mapView.zoomLevel = 16;
        _mapView.maxZoomLevel = 18;
        _mapView.showsScale =NO;//不显示比例尺
        _mapView.showsCompass = NO;//不显示罗盘
        _mapView.delegate  = self;
        MAUserLocationRepresentation *r = [[MAUserLocationRepresentation alloc] init];
        r.showsAccuracyRing = NO;///精度圈是否显示，默认YES
        r.showsHeadingIndicator = YES;
        [_mapView updateUserLocationRepresentation:r];
    }
    return _mapView;
}

#pragma mark - 跑步的开始、暂停、停止,状态机实现

- (void)startRunAction {
    
    self.sportsState = SportsStateStart;
}

- (void)pauseRunAction {
    
    self.sportsState = SportsStateUserPause;
}

- (void)systemPauseRunAction {
    
    self.sportsState = SportsStateStystemPause;
}

- (void)stopRunAction {
    
    self.sportsState = SportsStateStop;
}

#pragma mark - 状态监听

- (void)setSportsState:(SportsState)sportsState {
    
    _sportsState = sportsState;
    
    switch (sportsState) {
            
        case SportsStateIdle:{
            if (_polyline != nil) {
                [self.locationManager stopUpdatingLocation];
                [self.mapView removeOverlay:_polyline];
            }
            self.distance = 0;
            self.locationNumber = 0;
            self.isFirstLocation = YES;
            self.perfectArray = [NSMutableArray arrayWithCapacity:16];
            self.drawLineArray = [NSMutableArray arrayWithCapacity:16];
            break;
        }
        case SportsStateStart:{
            
            if (_polyline != nil) {
                [self.mapView removeOverlay:_polyline];
            }
            self.distance = 0;
            self.locationNumber = 0;
            self.isFirstLocation = YES;
            self.perfectArray = [NSMutableArray arrayWithCapacity:16];
            self.drawLineArray = [NSMutableArray arrayWithCapacity:16];
            [self.locationManager startUpdatingLocation];//开始持续定位
            if (self.isThinkMotion) {
                [[SDMotionManager defaultManager] start];
            }
            break;
        }
        case SportsStateRunning:{
            
            break;
        }
        case SportsStateStop:{
            [self.locationManager stopUpdatingLocation];
            break;
        }
        case SportsStateUserPause:{
            
            break;
        }
        case SportsStateStystemPause:{
            
            break;
        }
    }
}

#pragma mark - 定位数据回调(原始定位数据)

- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode{
    
    // 如果是考虑加速仪,并且状态是系统暂停状态,那么我们不能进行任何的操作,直接返回即可.
    if (_isThinkMotion && self.sportsState == SportsStateStystemPause) {
        return;
    }
    
    SDRunLocationModel *locationModel = [[SDRunLocationModel alloc]init];
    locationModel.location = location.coordinate;
    locationModel.time = [NSDate date];
    locationModel.gpsStrength = [self gpsStrengthWithLocation:location];
    
    _locationNumber++;
    if (_locationNumber > 1) {
        [self drawStartRunPointAction:locationModel];
        SDRunLocationModel *lastModel =locationModel;
        SDRunLocationModel *lastButOneModel = self.perfectArray.lastObject;
        [self distanceWithLocation:lastModel andLastButOneModel:lastButOneModel];
    }
}

//计算距离,估算误差值
-(void)distanceWithLocation:(SDRunLocationModel *)lastModel andLastButOneModel:(SDRunLocationModel *)lastButOneModel {
    
    MAMapPoint point1 = MAMapPointForCoordinate(lastModel.location);
    MAMapPoint point2 = MAMapPointForCoordinate(lastButOneModel.location);
    //2.计算距离
    CLLocationDistance newdistance = MAMetersBetweenMapPoints(point1,point2);
    
    //估算两者之间的时间差,单位 秒
    NSTimeInterval secondsBetweenDates= [lastModel.time timeIntervalSinceDate:lastButOneModel.time];
    
    //世界飞人9.97秒百米,当超过这个速度,即为误差值,可能是GPS不准
    if ((float)newdistance/secondsBetweenDates <= self.maxSpeed) {
        
        [self.perfectArray addObject:lastModel];
        [self drawRunLineAction];
        self.distance = self.distance + newdistance;
        if (self.sportsState == SportsStateUserPause || self.sportsState == SportsStateStystemPause) {
            self.distance  = self.distance - newdistance;
        }
    }
}

#pragma mark - 绘制轨迹

// 绘制优化: 全图只绘制一条轨迹,减少性能损耗
- (void)drawRunLineAction {
    
    SDRunLocationModel *endLocation = self.perfectArray[_lastDrawIndex];
    for (int i = _lastDrawIndex; i < self.perfectArray.count; i++) {
        
        SDRunLocationModel *newlocation = self.perfectArray[i];
        MAMapPoint point1 = MAMapPointForCoordinate(newlocation.location);
        MAMapPoint point2 = MAMapPointForCoordinate(endLocation.location);
        //2.计算距离
        CLLocationDistance newDistance = MAMetersBetweenMapPoints(point1,point2);
        
        if ( newDistance > 10 ) {
            endLocation = newlocation;
            self.lastDrawIndex = i;
            [self.drawLineArray addObject:newlocation];
        }
    }
    
    CLLocationCoordinate2D commonPolylineCoords[self.drawLineArray.count];
    for (int i = 0; i < self.drawLineArray.count; i++) {
        
        SDRunLocationModel *locationModel = self.drawLineArray[i];
        commonPolylineCoords[i] = locationModel.location;
    }
    
    [self.mapView removeOverlay:self.polyline];
    self.polyline = [MAPolyline polylineWithCoordinates:commonPolylineCoords count:self.drawLineArray.count];
    [self.mapView addOverlay: self.polyline];
}

//绘制折线样式
- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id <MAOverlay>)overlay {
    
    if ([overlay isKindOfClass:[MAPolyline class]]) {
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc] initWithPolyline:overlay];
        polylineRenderer.strokeColor = self.lineColor;
        polylineRenderer.lineWidth = self.lineWidth;
        return polylineRenderer;
    }
    return nil;
}


#pragma mark -绘制定位大头针

//绘制开始位置大头针
- (void)drawStartRunPointAction:(SDRunLocationModel *)runModel {
    
    if (self.isFirstLocation && _mapView.userLocation.location != nil) {
        MAPointAnnotation *pointAnnotation = [[MAPointAnnotation alloc] init];
        pointAnnotation.coordinate = runModel.location;
        [self.perfectArray addObject:runModel];//消除误差的数组添加第一个元素
        [_mapView addAnnotation:pointAnnotation];
        self.isFirstLocation = NO;
        self.lastDrawIndex = 0;
    }
}

// 定义大头针样式
-(MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id <MAAnnotation>)annotation {
    
    if ([annotation isKindOfClass:[MAPointAnnotation class]]){
        
        MAAnnotationView *annotationView = (MAAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"startLocation"];
        if (annotationView == nil) {
            annotationView = [[MAAnnotationView alloc] initWithAnnotation:annotation
                                                          reuseIdentifier:@"startLocation"];
        }
        annotationView.image = [UIImage imageNamed:@"start_point_icon.png"];
        annotationView.centerOffset = CGPointMake(0, -20);
        return annotationView;
    } else {
        
        _myAnnotationView = (MAAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"myLocation"];
        if (_myAnnotationView == nil){
            _myAnnotationView = [[MAAnnotationView alloc] initWithAnnotation:annotation
                                                             reuseIdentifier:@"myLocation"];
        }
        return _myAnnotationView;
    }
    return nil;
}

//根据头部信息显示方向
-(void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation {
    
    if(nil == userLocation || nil == userLocation.heading
       || userLocation.heading.headingAccuracy < 0) {
        return;
    }
    
    CLLocationDirection  theHeading = userLocation.heading.magneticHeading;
    
    float direction = theHeading;
    
    if(nil != _myAnnotationView) {
        if (direction > 180) {
            direction = 360 - direction;
        } else {
            direction = 0 - direction;
        }
        _myAnnotationView.image = [self.locationImage imageRotatedByDegrees:-direction];
    }
}

#pragma mark ---GPS信号强弱---

- (StrengthGrade)gpsStrengthWithLocation:(CLLocation *)location {
    
    if ( location.horizontalAccuracy >= 200 ) {
        return StrengthGradeBad;
    }
    if ( location.horizontalAccuracy >= 100 && location.horizontalAccuracy < 200 ) {
        return StrengthGradeAverage;
    }
    if (location.horizontalAccuracy >= 20 && location.horizontalAccuracy < 100 ) {
        return StrengthGradeBetter;
    }
    if ( location.horizontalAccuracy < 20 ) {
        return StrengthGradeBest;
    }
    return StrengthGradeBad;
}


@end
