/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLLocationManager.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

/// Working implementation, for Skred

@interface TLLocationManager () <CLLocationManagerDelegate>

@property (nonatomic, nullable) CLLocationManager *locationManager;
@property (nonatomic, nullable, readwrite) CLLocation *userLocation;
@property (nonatomic, readwrite) BOOL canShareLocation;
@property (nonatomic, readwrite) BOOL canShareBackgroundLocation;
@property (nonatomic, readwrite) BOOL isLocationShared;
@property (nonatomic) double mapLongitudeDelta;
@property (nonatomic) double mapLatitudeDelta;
@property (nonatomic, readonly, nullable) id<TLLocationManagerDelegate> delegate;
@end

#undef LOG_TAG
#define LOG_TAG @"TLLocationManager"

@implementation TLLocationManager

- (nonnull instancetype)initWithDelegate:(nullable id<TLLocationManagerDelegate>)delegate {
    DDLogVerbose(@"%@ initWithDelegate:%@", LOG_TAG, delegate);

    self = [super init];
    
    if (self) {
        _isLocationShared = NO;
        _canShareLocation = NO;
        _canShareBackgroundLocation = NO;
        _delegate = delegate;
    }
    
    return self;
}

/*- (nullable CLLocation *) userLocation {
    DDLogVerbose(@"%@ userLocation", LOG_TAG);

    return self.locationManager ? self.locationManager.location : nil;
}*/

- (void)initShareLocation {
    DDLogVerbose(@"%@ initShareLocation", LOG_TAG);
    
    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        self.locationManager.distanceFilter = 1;
        
        if (self.locationManager.location) {
            self.userLocation = self.locationManager.location;
        }
    }

    CLAuthorizationStatus locationPermission = [CLLocationManager authorizationStatus];
    switch (locationPermission) {
        case kCLAuthorizationStatusNotDetermined:
            [self.locationManager requestAlwaysAuthorization];
            break;
            
        case kCLAuthorizationStatusDenied: {
            self.canShareLocation = NO;
            if (![CLLocationManager locationServicesEnabled]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:CallEventMessageLocationServicesDisabled object:nil];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:CallEventMessageSharedLocationRestricted object:nil];
            }
        }
        case kCLAuthorizationStatusRestricted:
            self.canShareLocation = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:CallEventMessageSharedLocationRestricted object:nil];
            break;
            
        case kCLAuthorizationStatusAuthorizedAlways:
            self.canShareLocation = YES;
            self.canShareBackgroundLocation = YES;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:CallEventMessageSharedLocationEnabled object:nil];
            [self.locationManager startUpdatingLocation];
            break;
            
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            self.canShareLocation = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:CallEventMessageSharedLocationEnabled object:nil];
            [self.locationManager startUpdatingLocation];
            break;
    }
}

- (void)startShareLocation:(double)mapLatitudeDelta mapLongitudeDelta:(double)mapLongitudeDelta {
    DDLogVerbose(@"%@ startShareLocation:%f mapLongitudeDelta:%f", LOG_TAG, mapLatitudeDelta, mapLongitudeDelta);

    self.isLocationShared = YES;
    self.mapLatitudeDelta = mapLatitudeDelta;
    self.mapLongitudeDelta = mapLongitudeDelta;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CallEventMessageSharedLocationEnabled object:nil];
}

- (BOOL)isExactLocation {
    DDLogVerbose(@"%@ isExactLocation", LOG_TAG);
    
    if (!self.locationManager) {
        return NO;
    }
    
    if (@available(iOS 14.0, *)) {
        switch ([self.locationManager accuracyAuthorization]) {
            case CLAccuracyAuthorizationReducedAccuracy:
                return NO;
                
            case CLAccuracyAuthorizationFullAccuracy:
            default:
                return YES;
                
        }
    } else {
        return YES;
    }
}

- (void)stopShareLocation:(BOOL)disableUpdateLocation {
    DDLogVerbose(@"%@ stopShareLocation", LOG_TAG);

    if (disableUpdateLocation) {
        [self.locationManager stopUpdatingLocation];
        self.locationManager = nil;
        self.userLocation = nil;
    }
    
    self.isLocationShared = NO;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CallEventMessageSharedLocationEnabled object:nil];
}

- (void)stopUpdatingLocation {
    DDLogVerbose(@"%@ stopUpdatingLocation", LOG_TAG);

    [self.locationManager stopUpdatingLocation];
    self.locationManager = nil;
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    DDLogVerbose(@"%@ locationManager: %@ didChangeAuthorizationStatus: %d", LOG_TAG, manager, status);
    
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
        self.canShareLocation = YES;
        if (status == kCLAuthorizationStatusAuthorizedAlways) {
            self.canShareBackgroundLocation = YES;
        }
        [self.locationManager startUpdatingLocation];
        [[NSNotificationCenter defaultCenter] postNotificationName:CallEventMessageSharedLocationEnabled object:nil];
    } else {
        self.canShareLocation = NO;
        self.userLocation = nil;
        [self.locationManager stopUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    DDLogVerbose(@"%@ locationManager: %@ didUpdateLocations: %@", LOG_TAG, manager, locations);
        
    if (locations.count > 0) {
        self.userLocation = [locations objectAtIndex:0];
        [[NSNotificationCenter defaultCenter] postNotificationName:CallEventMessageSharedLocationEnabled object:nil];
        if (self.isLocationShared && self.delegate) {
            [self.delegate onUpdateLocation];
        }
    }
}


@end
