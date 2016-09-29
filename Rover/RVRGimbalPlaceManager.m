//
//  RVRGimbalPlaceManager.m
//  Pods
//
//  Created by Ata Namvari on 2016-07-22.
//
//

#import "RVRGimbalPlaceManager.h"

@interface GMBLPlaceManager : NSObject
@property (weak, nonatomic) id delegate;
- (NSArray *)currentVisits;
@end

@interface GMBLPlace : NSObject
@property (nonatomic, readonly) NSString *identifier;
@end

@interface GMBLVisit : NSObject
@property (nonatomic, readonly) GMBLPlace *place;
@end

@interface RVRGimbalPlaceManager ()
@property (strong, nonatomic) GMBLPlaceManager *placeManager;
@end

@implementation RVRGimbalPlaceManager

#pragma mark - Initialization

- (id)init {
    self = [super init];
    if (self) {
        
        Class gimbalPlaceManagerClass = NSClassFromString(@"GMBLPlaceManager");
        if (gimbalPlaceManagerClass) {
            _placeManager = [[gimbalPlaceManagerClass alloc] init];
            _placeManager.delegate = self;
        } else {
            NSLog(@"Gimbal SDK not found. Make sure you have linked against the Gimbal.framework");
            abort();
        }
    }
    return self;
}

#pragma mark - GMBLPlaceManagerDelegate

- (void)placeManager:(GMBLPlaceManager *)manager didBeginVisit:(GMBLVisit *)visit {
    NSString *gimbalIdentifier = visit.place.identifier;
    [self.delegate placeManager:self didEnterGimbalPlaceWithIdentifier:gimbalIdentifier];
}

- (void)placeManager:(GMBLPlaceManager *)manager didEndVisit:(GMBLVisit *)visit {
    NSString *gimbalIdentifier = visit.place.identifier;
    [self.delegate placeManager:self didExitGimbalPlaceWithIdentifier:gimbalIdentifier];
}

- (void)placeManager:(GMBLPlaceManager *)manager didDetectLocation:(CLLocation *)location {
    [self.delegate placeManager:self didUpdateLocation:location];
}

@end
