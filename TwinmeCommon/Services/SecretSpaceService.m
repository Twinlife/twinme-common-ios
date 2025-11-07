/*
 *  Copyright (c) 2021-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>

#import <Twinme/TLSpace.h>

#import "SecretSpaceService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int SET_CURRENT_SPACE = 1;
static const int SET_CURRENT_SPACE_DONE = 1 << 1;

//
// Interface: SecretSpaceService ()
//

@class SecretSpaceServiceTwinmeContextDelegate;

@interface SecretSpaceService ()

- (void)onOperation;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

@end


//
// Interface: SecretSpaceServiceTwinmeContextDelegate
//

@interface SecretSpaceServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull SecretSpaceService *)service;

@end

//
// Implementation: SecretSpaceServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"SecretSpaceServiceTwinmeContextDelegate"

@implementation SecretSpaceServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull SecretSpaceService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onSetCurrentSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(SecretSpaceService *)self.service onSetCurrentSpace:space];
}

@end

//
// Implementation: SecretSpaceService
//

#undef LOG_TAG
#define LOG_TAG @"SecretSpaceService"

@implementation SecretSpaceService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <SecretSpaceServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[SecretSpaceServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [super dispose];
}

- (void)findSecretSpaceByName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ findSecretSpaceByName: %@", LOG_TAG, name);

    [self.twinmeContext findSpacesWithPredicate:^BOOL(TLSpace *space) {
        if ([name isEqualToString:space.settings.name]) {
            return YES;
        }
        return NO;
    } withBlock:^(NSMutableArray<TLSpace *> *spaces) {
        [self runOnGetSpaces:spaces];
        [self onOperation];
    }];
}

- (void)setCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ setCuurentSpace: %@", LOG_TAG, space);
    
    int64_t requestId = [self newOperation:SET_CURRENT_SPACE];
    [self showProgressIndicator];
    [self.twinmeContext setCurrentSpaceWithRequestId:requestId space:space];
    
    if (!space.settings.isSecret) {
        [self.twinmeContext setDefaultSpace:space];
    }
}

- (void)onSetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    self.state |= SET_CURRENT_SPACE_DONE;
    [self runOnSetCurrentSpace:space];
    [self onOperation];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

@end
