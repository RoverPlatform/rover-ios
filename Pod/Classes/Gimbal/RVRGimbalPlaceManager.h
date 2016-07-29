//
//  RVRGimbalPlaceManager.h
//  Pods
//
//  Created by Ata Namvari on 2016-07-22.
//
//

#import <Foundation/Foundation.h>

@protocol RVRGimbalPlaceManagerDelegate;

@class CLLocation;

@interface RVRGimbalPlaceManager : NSObject
@property (nonatomic, weak) id delegate;
@end

@protocol RVRGimbalPlaceManagerDelegate <NSObject>
- (void)placeManager:(RVRGimbalPlaceManager *)manager didEnterGimbalPlaceWithIdentifier:(NSString *)identifier;
- (void)placeManager:(RVRGimbalPlaceManager *)manager didExitGimbalPlaceWithIdentifier:(NSString *)identifier;
- (void)placeManager:(RVRGimbalPlaceManager *)manager didUpdateLocation:(CLLocation *)location;
@end