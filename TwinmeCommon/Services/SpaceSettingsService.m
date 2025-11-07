/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>

#import <Twinme/TLSpace.h>

#import "SpaceSettingsService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int UPDATE_DEFAULT_SPACE_SETTINGS = 1 << 0;
static const int UPDATE_DEFAULT_SPACE_SETTINGS_DONE = 1 << 1;

//
// Interface: SpaceSettingsService ()
//

@class SpaceSettingsServiceTwinmeContextDelegate;

@interface SpaceSettingsService ()

@property (nonatomic, nullable) TLSpaceSettings *spaceSettings;
@property (nonatomic) int work;

- (void)onOperation;

- (void)onUpdateSpaceDefaultSettings:(nonnull TLSpaceSettings *)spaceSettings;

@end


//
// Interface: SpaceSettingsServiceTwinmeContextDelegate
//

@interface SpaceSettingsServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull SpaceSettingsService *)service;

@end

//
// Implementation: SpaceSettingsServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"SpaceSettingsServiceTwinmeContextDelegate"

@implementation SpaceSettingsServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull SpaceSettingsService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

@end

//
// Implementation: SpaceSettingsService
//

#undef LOG_TAG
#define LOG_TAG @"SpaceSettingsService"

@implementation SpaceSettingsService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <SpaceSettingsServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[SpaceSettingsServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)updateDefaultSpaceSettings:(nonnull TLSpaceSettings *)spaceSettings {
    DDLogVerbose(@"%@ updateDefaultSpaceSettings: %@", LOG_TAG, spaceSettings);
    
    self.spaceSettings = spaceSettings;
    
    self.work |= UPDATE_DEFAULT_SPACE_SETTINGS;
    self.state &= ~(UPDATE_DEFAULT_SPACE_SETTINGS | UPDATE_DEFAULT_SPACE_SETTINGS_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

#pragma mark - Private methods

- (void)onUpdateSpaceDefaultSettings:(nonnull TLSpaceSettings *)spaceSettings {
    DDLogVerbose(@"%@ onUpdateDefaultSpaceSettings: %@", LOG_TAG, spaceSettings);
    
    self.state |= UPDATE_DEFAULT_SPACE_SETTINGS_DONE;
        
    self.spaceSettings = spaceSettings;
    
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<SpaceSettingsServiceDelegate>)self.delegate onUpdateSpaceDefaultSettings:self.spaceSettings];
        });
    }
    [self onOperation];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    // Update the default space settings.
    if ((self.work & UPDATE_DEFAULT_SPACE_SETTINGS) != 0) {
        if ((self.state & UPDATE_DEFAULT_SPACE_SETTINGS) == 0) {
            self.state |= UPDATE_DEFAULT_SPACE_SETTINGS;
            
            DDLogVerbose(@"%@ saveDefaultSpaceSettings: %@", LOG_TAG, self.spaceSettings);
            [self.twinmeContext saveDefaultSpaceSettings:self.spaceSettings withBlock:^(TLBaseServiceErrorCode errorCode, TLSpaceSettings *settings) {
                [self onUpdateSpaceDefaultSettings:settings];
            }];
            return;
        }
        
        if ((self.state & UPDATE_DEFAULT_SPACE_SETTINGS_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

@end
