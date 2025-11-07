/*
 *  Copyright (c) 2024-2025 twinlife SA.
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

/// NOOP implementation, for Twinme
#undef LOG_TAG
#define LOG_TAG @"TLLocationManager"

@implementation TLLocationManager

- (nonnull instancetype)initWithDelegate:(nullable id<TLLocationManagerDelegate>)delegate {
    DDLogVerbose(@"%@ initWithDelegate:%@", LOG_TAG, delegate);

    self = [super init];
    
    if (self) {
        _userLocation = nil;
        _canShareLocation = NO;
        _canShareBackgroundLocation = NO;
        _isLocationShared = NO;
        _mapLongitudeDelta = 0;
        _mapLatitudeDelta = 0;
    }
    
    return self;
}

- (void)initShareLocation {
    DDLogVerbose(@"%@ initShareLocation", LOG_TAG);

    //NOOP
}

- (void)startShareLocation:(double)mapLatitudeDelta mapLongitudeDelta:(double)mapLongitudeDelta {
    DDLogVerbose(@"%@ startShareLocation:%f mapLongitudeDelta:%f", LOG_TAG, mapLatitudeDelta, mapLongitudeDelta);
    
    //NOOP
}

- (void)stopShareLocation:(BOOL)disableUpdateLocation {
    DDLogVerbose(@"%@ stopShareLocation", LOG_TAG);

   //NOOP
}

- (void)stopUpdatingLocation {
    DDLogVerbose(@"%@ stopUpdatingLocation", LOG_TAG);

    //NOOP
}

- (BOOL)isExactLocation {

    return NO;
}

@end
