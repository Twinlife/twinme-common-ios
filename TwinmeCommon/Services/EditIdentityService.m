/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLCallReceiver.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLProfile.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLSpace.h>
#import <Twinlife/TLImageService.h>

#import "EditIdentityService.h"
#import "AbstractTwinmeService+Protected.h"

#import <Utils/NSString+Utils.h>

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int UPDATE_PROFILE = 1 << 0;
static const int UPDATE_PROFILE_DONE = 1 << 1;
static const int UPDATE_CONTACT = 1 << 2;
static const int UPDATE_CONTACT_DONE = 1 << 3;
static const int UPDATE_GROUP = 1 << 4;
static const int UPDATE_GROUP_DONE = 1 << 5;
static const int DELETE_PROFILE = 1 << 6;
static const int DELETE_PROFILE_DONE = 1 << 7;
static const int CREATE_PROFILE = 1 << 8;
static const int CREATE_PROFILE_DONE = 1 << 9;
static const int GET_IDENTITY_AVATAR = 1 << 10;
static const int GET_IDENTITY_AVATAR_DONE = 1 << 11;
static const int UPDATE_CALL_RECEIVER = 1 << 13;
static const int UPDATE_CALL_RECEIVER_DONE = 1 << 14;

//
// Interface: EditIdentityService ()
//

@class EditIdentityServiceTwinmeContextDelegate;

@interface EditIdentityService ()

@property (nonatomic, nullable) TLProfile *profile;
@property (nonatomic, nullable) TLContact *contact;
@property (nonatomic, nullable) TLCallReceiver *callReceiver;
@property (nonatomic, nullable) TLGroup *group;
@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) TLImageId *avatarId;
@property (nonatomic, nullable) NSString *name;
@property (nonatomic, nullable) NSString *identityDescription;
@property (nonatomic, nullable) UIImage *avatar;
@property (nonatomic, nullable) UIImage *largeAvatar;
@property (nonatomic, nullable) TLSpace *currentSpace;
@property (nonatomic) TLProfileUpdateMode profileUpdateMode;
@property (nonatomic) int work;

- (void)onOperation;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

- (void)onUpdateSpace:(TLSpace *)space;

- (void)onCreateProfile:(nonnull TLProfile *)profile;

- (void)onUpdateProfile:(nonnull TLProfile *)profile;

- (void)onUpdateContact:(nonnull TLContact *)contact;

- (void)onUpdateCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onUpdateGroup:(nonnull TLGroup *)group;

- (void)onDeleteProfile:(nonnull NSUUID *)profileId;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Interface: EditIdentityServiceTwinmeContextDelegate
//

@interface EditIdentityServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull EditIdentityService *)service;

@end

//
// Implementation: EditIdentityServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"EditIdentityServiceTwinmeContextDelegate"

@implementation EditIdentityServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull EditIdentityService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onCreateProfileWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ onCreateProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(EditIdentityService *)self.service onCreateProfile:profile];
}

- (void)onSetCurrentSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [self.service finishOperation:requestId];
    
    [(EditIdentityService *)self.service onSetCurrentSpace:space];
}

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(EditIdentityService *)self.service onUpdateSpace:space];
}

- (void)onUpdateProfileWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ onUpdateProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    [(EditIdentityService *)self.service onUpdateProfile:profile];
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(EditIdentityService *)self.service onUpdateContact:contact];
}

- (void)onUpdateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onUpdateCallReceiverWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(EditIdentityService *)self.service onUpdateCallReceiver:callReceiver];
}

- (void)onUpdateGroupWithRequestId:(int64_t)requestId group:(TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, group);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(EditIdentityService *)self.service onUpdateGroup:group];
}

- (void)onDeleteProfileWithRequestId:(int64_t)requestId profileId:(nonnull NSUUID *)profileId {
    DDLogVerbose(@"%@ onDeleteProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profileId);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(EditIdentityService *)self.service onDeleteProfile:profileId];
}

@end

//
// Implementation: EditIdentityService
//

#undef LOG_TAG
#define LOG_TAG @"EditIdentityService"

@implementation EditIdentityService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<EditIdentityServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[EditIdentityServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)refreshWithProfile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ refreshWithProfile: %@", LOG_TAG, profile);
    
    self.profile = profile;
    self.avatarId = profile.avatarId;
    
    self.work = GET_IDENTITY_AVATAR;
    self.state &= ~(GET_IDENTITY_AVATAR | GET_IDENTITY_AVATAR_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)refreshWithContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ refreshWithContact: %@", LOG_TAG, contact);
    
    self.contact = contact;
    self.avatarId = contact.identityAvatarId;
    
    self.work = GET_IDENTITY_AVATAR;
    self.state &= ~(GET_IDENTITY_AVATAR | GET_IDENTITY_AVATAR_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)refreshWithGroup:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ refreshWithGroup: %@", LOG_TAG, group);
    
    self.group = group;
    self.avatarId = group.identityAvatarId;
    
    self.work = GET_IDENTITY_AVATAR;
    self.state &= ~(GET_IDENTITY_AVATAR | GET_IDENTITY_AVATAR_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)refreshWithCallReceiver:(nonnull TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ refreshWithCallReceiver: %@", LOG_TAG, callReceiver);
    
    self.callReceiver = callReceiver;
    self.avatarId = callReceiver.identityAvatarId;
    
    self.work = GET_IDENTITY_AVATAR;
    self.state &= ~(GET_IDENTITY_AVATAR | GET_IDENTITY_AVATAR_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)createProfile:(nonnull NSString *)identityName identityDescription:(nullable NSString *)identityDescription identityAvatar:(nonnull UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ createProfile: %@ identityAvatar: %@ identityDescription: %@ identityLargeAvatar: %@ space: %@", LOG_TAG, identityName, identityDescription, identityAvatar, identityLargeAvatar, space);
    
    self.name = identityName;
    self.identityDescription = identityDescription;
    self.avatar = identityAvatar;
    self.largeAvatar = identityLargeAvatar;
    self.space = space;
    
    self.work |= CREATE_PROFILE;
    self.state &= ~(CREATE_PROFILE | CREATE_PROFILE_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateIdentityWithProfile:(nonnull TLProfile *)profile identityName:(nonnull NSString *)identityName identityDescription:(nullable NSString *)identityDescription identityAvatar:(nonnull UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar profileUpdateMode:(TLProfileUpdateMode)profileUpdateMode {
    DDLogVerbose(@"%@ updateIdentityWithProfile: %@ identityName: %@ identityDescription: %@  identityAvatar: %@ profileUpdateMode: %d", LOG_TAG, profile, identityName, identityDescription, identityAvatar, profileUpdateMode);
    
    self.profile = profile;
    self.name = identityName;
    self.identityDescription = identityDescription;
    self.avatar = identityAvatar;
    self.largeAvatar = identityLargeAvatar;
    self.profileUpdateMode = profileUpdateMode;
    
    self.work |= UPDATE_PROFILE;
    self.state &= ~(UPDATE_PROFILE | UPDATE_PROFILE_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateIdentityWithContact:(nonnull TLContact *)contact identityName:(nonnull NSString *)identityName identityDescription:(nullable NSString *)identityDescription identityAvatar:(nonnull UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar {
    DDLogVerbose(@"%@ updateIdentityWithContact: %@ name: %@ identityDescription: %@  avatar: %@", LOG_TAG, contact, identityName, identityDescription, identityAvatar);
    
    self.contact = contact;
    self.name = identityName;
    self.identityDescription = identityDescription;
    self.avatar = identityAvatar;
    self.largeAvatar = identityLargeAvatar;
    
    self.work |= UPDATE_CONTACT;
    self.state &= ~(UPDATE_CONTACT | UPDATE_CONTACT_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateIdentityWithGroup:(nonnull TLGroup *)group identityName:(nonnull NSString *)identityName identityAvatar:(nonnull UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar {
    DDLogVerbose(@"%@ updateIdentityWithGroup: %@ name: %@ avatar: %@", LOG_TAG, group, identityName, identityAvatar);
    
    self.group = group;
    self.name = identityName;
    self.avatar = identityAvatar;
    self.largeAvatar = identityLargeAvatar;
    
    self.work |= UPDATE_GROUP;
    self.state &= ~(UPDATE_GROUP | UPDATE_GROUP_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateIdentityWithCallReceiver:(nonnull TLCallReceiver *)callReceiver identityName:(nonnull NSString *)identityName identityDescription:(nullable NSString *)identityDescription identityAvatar:(nonnull UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar {
    DDLogVerbose(@"%@ updateIdentityWithCallReceiver: %@ name: %@ identityDescription: %@  avatar: %@", LOG_TAG, callReceiver, identityName, identityDescription, identityAvatar);
    
    self.callReceiver = callReceiver;
    self.name = identityName;
    self.identityDescription = identityDescription;
    self.avatar = identityAvatar;
    self.largeAvatar = identityLargeAvatar;
    
    self.work |= UPDATE_CALL_RECEIVER;
    self.state &= ~(UPDATE_CALL_RECEIVER | UPDATE_CALL_RECEIVER_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)deleteProfile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ deleteProfile: %@", LOG_TAG, profile);
    
    self.profile = profile;
    
    self.work = DELETE_PROFILE;
    self.state &= ~(DELETE_PROFILE | DELETE_PROFILE_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    // Create the space profile.
    if ((self.work & CREATE_PROFILE) != 0) {
        if ((self.state & CREATE_PROFILE) == 0) {
            self.state |= CREATE_PROFILE;
            
            int64_t requestId = [self newOperation:CREATE_PROFILE];
            DDLogVerbose(@"%@ createProfileWithRequestId: %lld name:%@ avatar:%@ space:%@", LOG_TAG, requestId, self.name, self.avatar, self.space);
            
            [self.twinmeContext createProfileWithRequestId:requestId name:self.name avatar:self.avatar largeAvatar:self.largeAvatar description:nil capabilities:nil space:self.space];
            return;
        }
        
        if ((self.state & CREATE_PROFILE_DONE) == 0) {
            return;
        }
    }
    
    // We must update the current profile.
    if ((self.work & UPDATE_PROFILE) != 0) {
        if ((self.state & UPDATE_PROFILE) == 0) {
            self.state |= UPDATE_PROFILE;
            
            int64_t requestId = [self newOperation:UPDATE_PROFILE];
            DDLogVerbose(@"%@ updateProfileWithRequestId: %lld profile: %@ name: %@ avatar: %@", LOG_TAG, requestId, self.profile, self.name, self.avatar);
            
            [self.twinmeContext updateProfileWithRequestId:requestId profile:self.profile updateMode:self.profileUpdateMode name:self.name avatar:self.avatar largeAvatar:self.largeAvatar description:self.identityDescription capabilities:self.profile.identityCapabilities];
            return;
        }
        
        if ((self.state & UPDATE_PROFILE_DONE) == 0) {
            return;
        }
    }
    
    // We must update identity for contact.
    if ((self.work & UPDATE_CONTACT) != 0) {
        if ((self.state & UPDATE_CONTACT) == 0) {
            self.state |= UPDATE_CONTACT;
            
            int64_t requestId = [self newOperation:UPDATE_CONTACT];
            DDLogVerbose(@"%@ updateContactWithRequestId: %lld contact: %@ contactName: %@ identityName: %@ identityAvatar: %@", LOG_TAG, requestId, self.contact, self.contact.name, self.name, self.avatar);
            
            [self.twinmeContext updateContactIdentityWithRequestId:requestId contact:self.contact identityName:self.name identityAvatar:self.avatar identityLargeAvatar:self.largeAvatar description:self.identityDescription capabilities:self.contact.identityCapabilities];
            return;
        }
        
        if ((self.state & UPDATE_CONTACT_DONE) == 0) {
            return;
        }
    }
    
    // We must update the user's profile in the group.
    if ((self.work & UPDATE_GROUP) != 0) {
        if ((self.state & UPDATE_GROUP) == 0) {
            self.state |= UPDATE_GROUP;
            
            int64_t requestId = [self newOperation:UPDATE_GROUP];
            DDLogVerbose(@"%@ updateGroupProfileWithRequestId: %lld group: %@ name: %@ profileAvatar: %@", LOG_TAG, requestId, self.group, self.name, self.avatar);
            [self.twinmeContext updateGroupProfileWithRequestId:requestId group:self.group name:self.name profileAvatar:self.avatar profileLargeAvatar:self.largeAvatar];
            return;
        }
        if ((self.state & UPDATE_GROUP_DONE) == 0) {
            return;
        }
    }
    
    // We must update identity for call receiver.
    if ((self.work & UPDATE_CALL_RECEIVER) != 0) {
        if ((self.state & UPDATE_CALL_RECEIVER) == 0) {
            self.state |= UPDATE_CALL_RECEIVER;
            
            int64_t requestId = [self newOperation:UPDATE_CALL_RECEIVER];
            DDLogVerbose(@"%@ updateContactWithRequestId: %lld contact: %@ contactName: %@ identityName: %@ identityAvatar: %@", LOG_TAG, requestId, self.contact, self.contact.name, self.name, self.avatar);
            
            NSString *callReceiverName = self.callReceiver.name;
            NSString *callReceiverDescription = self.callReceiver.objectDescription;
            
            if (self.callReceiver.isTransfer) {
                callReceiverName = self.name;
                callReceiverDescription = self.identityDescription;
            }
            
            [self.twinmeContext updateCallReceiverWithRequestId:requestId callReceiver:self.callReceiver name:callReceiverName description:callReceiverDescription identityName:self.name identityDescription:self.identityDescription avatar:self.avatar largeAvatar:self.largeAvatar capabilities:nil];
            return;
        }
        
        if ((self.state & UPDATE_CALL_RECEIVER_DONE) == 0) {
            return;
        }
    }
    
    // We must delete the current profile.
    if ((self.work & DELETE_PROFILE) != 0) {
        if ((self.state & DELETE_PROFILE) == 0) {
            self.state |= DELETE_PROFILE;
            
            int64_t requestId = [self newOperation:DELETE_PROFILE];
            DDLogVerbose(@"%@ deleteProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, self.profile);
            [self.twinmeContext deleteProfileWithRequestId:requestId profile:self.profile];
            return;
        }
        
        if ((self.state & DELETE_PROFILE_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & GET_IDENTITY_AVATAR) != 0) {
        if ((self.state & GET_IDENTITY_AVATAR) == 0) {
            self.state |= GET_IDENTITY_AVATAR;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindLarge withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                self.state |= GET_IDENTITY_AVATAR_DONE;
                if (status == TLBaseServiceErrorCodeSuccess && image) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.delegate) {
                            [(id<EditIdentityServiceDelegate>)self.delegate onUpdateIdentityAvatar:image];
                        }
                    });
                }
                [self onOperation];
            }];
            return;
        }
        
        if ((self.state & GET_IDENTITY_AVATAR_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step: everything done, we can hide the progress indicator.
    //
    
    [self hideProgressIndicator];
}

- (void)onCreateProfile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ onCreateProfile: %@", LOG_TAG, profile);
    
    self.state |= CREATE_PROFILE_DONE;
    if ([profile.space.uuid isEqual:self.space.uuid]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<EditIdentityServiceDelegate>)self.delegate onCreateProfile:profile];
        });
    }
    [self onOperation];
}

- (void)onUpdateProfile:(TLProfile *)profile {
    DDLogVerbose(@"%@ onUpdateProfile: %@", LOG_TAG, profile);
    
    self.state |= UPDATE_PROFILE_DONE;
    
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<EditIdentityServiceDelegate>)self.delegate onUpdateProfile:profile];
        });
    }
    [self onOperation];
}

- (void)onSetCurrentSpace:(TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    [self runOnSetCurrentSpace:space];
}

- (void)onUpdateSpace:(TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    [self runOnUpdateSpace:space];
}

- (void)onUpdateContact:(TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContact: %@", LOG_TAG, contact);
    
    self.state |= UPDATE_CONTACT_DONE;
    [self runOnUpdateContact:contact avatar:nil];
    [self onOperation];
}

- (void)onUpdateGroup:(TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroup: %@", LOG_TAG, group);
    
    self.state |= UPDATE_GROUP_DONE;
    [self runOnUpdateGroup:group avatar:nil];
    [self onOperation];
}

- (void)onUpdateCallReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onUpdateCallReceiver: %@", LOG_TAG, callReceiver);
    
    self.state |= UPDATE_CALL_RECEIVER;
    
    if (self.delegate) {
        [(id<EditIdentityServiceDelegate>)self.delegate onUpdateCallReceiver:callReceiver];
    }
    [self onOperation];
}

- (void)onDeleteProfile:(NSUUID *)profileId {
    DDLogVerbose(@"%@ onDeleteProfile: %@", LOG_TAG, profileId);
    
    self.state |= DELETE_PROFILE_DONE;
    
    if (self.delegate) {
        [(id<EditIdentityServiceDelegate>)self.delegate onDeleteProfile:profileId];
    }
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %i errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch (operationId) {
            case UPDATE_PROFILE:
                self.state |= UPDATE_PROFILE_DONE;
                
                [(id<EditIdentityServiceDelegate>)self.delegate onUpdateProfile:self.profile];
                return;
                
            case UPDATE_CONTACT:
                self.state |= UPDATE_CONTACT_DONE;
                [self runOnDeleteContact:self.contact.uuid];
                return;
                
            case UPDATE_GROUP:
                self.state |= UPDATE_GROUP_DONE;
                [self runOnDeleteGroup:self.group.uuid];
                return;
                
            default:
                break;
        }
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
