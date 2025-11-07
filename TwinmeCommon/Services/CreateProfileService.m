/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLSpace.h>

#import <Utils/NSString+Utils.h>

#import "CreateProfileService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_CURRENT_SPACE = 1 << 0;
static const int GET_CURRENT_SPACE_DONE = 1 << 1;
static const int CREATE_SPACE =  1 << 2;
static const int CREATE_SPACE_DONE = 1 << 3;
static const int CREATE_PROFILE =  1 << 4;
static const int CREATE_PROFILE_DONE = 1 << 5;
static const int SET_CURRENT_SPACE = 1 << 6;
static const int SET_LEVEL = 1 << 7;

//
// Interface: CreateProfileService ()
//

@class CreateProfileServiceTwinmeContextDelegate;

@interface CreateProfileService ()

@property (nonatomic, nullable) TLProfile *profile;
@property (nonatomic, nullable) NSString *name;
@property (nonatomic, nullable) NSString *profileDescription;
@property (nonatomic, nullable) UIImage *avatar;
@property (nonatomic, nullable) UIImage *largeAvatar;
@property (nonatomic, nullable) NSString *nameSpace;
@property (nonatomic) int work;
@property (nonatomic, nullable) TLSpace *space;

- (void)onOperation;

- (void)onCreateProfile:(nonnull TLProfile *)profile;

- (void)onCreateSpace:(nonnull TLSpace *)space;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

@end

//
// Interface: CreateProfileServiceTwinmeContextDelegate
//

@interface CreateProfileServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull CreateProfileService *)service;

@end

//
// Implementation: CreateProfileServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"CreateProfileServiceTwinmeContextDelegate"

@implementation CreateProfileServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull CreateProfileService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onCreateSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onCreateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(CreateProfileService *)self.service onCreateSpace:space];
}

- (void)onCreateProfileWithRequestId:(int64_t)requestId profile:(TLProfile *)profile {
    DDLogVerbose(@"%@ onCreateProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(CreateProfileService *)self.service onCreateProfile:profile];
}

- (void)onSetCurrentSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [self.service finishOperation:requestId];
    
    [(CreateProfileService *)self.service onSetCurrentSpace:space];
}

@end

//
// Implementation: CreateProfileService
//

#undef LOG_TAG
#define LOG_TAG @"CreateProfileService"

@implementation CreateProfileService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<CreateProfileServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[CreateProfileServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)createProfile:(nonnull NSString *)name profileDescription:(nullable NSString *)profileDescription avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar nameSpace:(nullable NSString *)nameSpace createSpace:(BOOL)createSpace {
    DDLogVerbose(@"%@ createProfile: name: %@ profileDescription: %@ avatar: %@ largeAvatar: %@ nameSpace: %@", LOG_TAG, name, profileDescription, avatar, largeAvatar, nameSpace);
    
    self.name = name;
    self.nameSpace = nameSpace;
    self.profileDescription = profileDescription;
    self.avatar = avatar;
    self.largeAvatar = largeAvatar;
    
    self.work = CREATE_PROFILE;
    if (!self.space || createSpace) {
        self.work |= CREATE_SPACE;
        self.state &= ~(CREATE_SPACE | CREATE_SPACE_DONE);
    }
    self.state &= ~(CREATE_PROFILE | CREATE_PROFILE_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)setCurrentSpace {
    DDLogVerbose(@"%@ setCurrentSpace", LOG_TAG);

    [self.twinmeContext setLevelWithRequestId:[self newOperation:SET_LEVEL] name:@"0"];
}

- (void)setLevel:(nonnull NSString *)name {
    DDLogVerbose(@"%@ setLevel: %@", LOG_TAG, name);

    [self.twinmeContext setLevelWithRequestId:[self newOperation:SET_LEVEL] name:name];
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    //
    // Step 1: get the current space.
    //
    if ((self.state & GET_CURRENT_SPACE) == 0) {
        self.state |= GET_CURRENT_SPACE;

        [self.twinmeContext getCurrentSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
            self.state |= GET_CURRENT_SPACE_DONE;
            self.space = space;
            [self onOperation];
        }];
        return;
    }
    
    if ((self.state & GET_CURRENT_SPACE_DONE) == 0) {
        return;
    }
    
    //
    // Work step: create a space.
    //
    if ((self.work & CREATE_SPACE) != 0) {
        if ((self.state & CREATE_SPACE) == 0) {
            self.state |= CREATE_SPACE;
            
            int64_t requestId = [self newOperation:CREATE_SPACE];
            TLSpaceSettings *defaultSettings = [self.twinmeContext defaultSpaceSettings];
            TLSpaceSettings *settings = [[TLSpaceSettings alloc] initWithName:self.nameSpace settings:defaultSettings];
            
            DDLogVerbose(@"%@ createSpaceWithRequestId: %lld settings: %@ spaceAvatar: nil spaceLargeAvatar: nil", LOG_TAG, requestId, settings);
            
            [self.twinmeContext createSpaceWithRequestId:requestId settings:settings spaceAvatar:nil spaceLargeAvatar:nil];
            return;
        }
        
        if ((self.state & CREATE_SPACE_DONE) == 0) {
            return;
        }
    }
    
    //
    // We must create a profile for the current space.
    //
    if (self.space && (self.work & CREATE_PROFILE) != 0) {
        if ((self.state & CREATE_PROFILE) == 0) {
            self.state |= CREATE_PROFILE;
            
            int64_t requestId = [self newOperation:CREATE_PROFILE];
            DDLogVerbose(@"%@ createProfileWithRequestId: %lld name: %@ avatar: %@ space: %@", LOG_TAG, requestId, self.name, self.avatar, self.space);
            [self.twinmeContext createProfileWithRequestId:requestId name:self.name avatar:self.avatar largeAvatar:self.largeAvatar description:self.profileDescription capabilities:nil space:self.space];
            return;
        }
        
        if ((self.state & CREATE_PROFILE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step: everything done, we can hide the progress indicator.
    //
    
    [self hideProgressIndicator];
}

- (void)onCreateSpace:(TLSpace *)space {
    DDLogVerbose(@"%@ onCreateSpace: %@", LOG_TAG, space);
    
    self.state |= CREATE_SPACE_DONE;
    
    if (!self.space) {
        [self.twinmeContext setDefaultSpace:space];
    }
    
    self.space = space;
    
    int64_t requestId = [self newOperation:SET_CURRENT_SPACE];
    [self.twinmeContext setCurrentSpaceWithRequestId:requestId space:space];
    [self onOperation];
}

- (void)onCreateProfile:(TLProfile *)profile {
    DDLogVerbose(@"%@ onCreateProfile: %@", LOG_TAG, profile);
    
    self.state |= CREATE_PROFILE_DONE;
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<CreateProfileServiceDelegate>)self.delegate onCreateProfile:profile];
    });
    [self onOperation];
}

- (void)onSetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    self.space = space;
}

@end
