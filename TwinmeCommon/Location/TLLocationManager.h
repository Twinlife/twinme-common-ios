/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <CoreLocation/CoreLocation.h>

#define CallEventMessageSharedLocationEnabled @"CallEventMessageSharedLocationEnabled"
#define CallEventMessageSharedLocationRestricted @"CallEventMessageSharedLocationRestricted"
#define CallEventMessageLocationServicesDisabled @"CallEventMessageLocationServicesDisabled"

@protocol TLLocationManagerDelegate
- (void)onUpdateLocation;
@end

@interface TLLocationManager : NSObject

@property (nonatomic, nullable, readonly) CLLocation *userLocation;
@property (nonatomic, readonly) BOOL canShareLocation;
@property (nonatomic, readonly) BOOL canShareBackgroundLocation;
@property (nonatomic, readonly) BOOL isLocationShared;
@property (nonatomic, readonly) double mapLongitudeDelta;
@property (nonatomic, readonly) double mapLatitudeDelta;


- (nonnull instancetype)initWithDelegate:(nullable id<TLLocationManagerDelegate>)delegate;

- (void)initShareLocation;

- (void)startShareLocation:(double)mapLatitudeDelta mapLongitudeDelta:(double)mapLongitudeDelta;

- (void)stopShareLocation:(BOOL)disableUpdateLocation;

- (void)stopUpdatingLocation;

- (BOOL)isExactLocation;

@end
