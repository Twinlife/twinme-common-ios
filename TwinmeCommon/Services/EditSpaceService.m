/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinlife/TLImageService.h>

#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLProfile.h>
#import <Twinme/TLSpace.h>

#import "EditSpaceService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_CURRENT_SPACE = 1 << 0;
static const int GET_CURRENT_SPACE_DONE = 1 << 1;
static const int GET_CONTACTS = 1 << 2;
static const int GET_CONTACTS_DONE = 1 << 3;
static const int GET_GROUPS = 1 << 4;
static const int GET_GROUPS_DONE = 1 << 5;
static const int CREATE_PROFILE = 1 << 6;
static const int CREATE_PROFILE_DONE = 1 << 7;
static const int UPDATE_PROFILE = 1 << 8;
static const int UPDATE_PROFILE_DONE = 1 << 9;
static const int UPDATE_SPACE = 1 << 10;
static const int UPDATE_SPACE_DONE = 1 << 11;
static const int DELETE_SPACE = 1 << 12;
static const int DELETE_SPACE_DONE = 1 << 13;
static const int GET_SPACE_IMAGE = 1 << 14;
static const int GET_SPACE_IMAGE_DONE = 1 << 15;
static const int CREATE_SPACE =  1 << 16;
static const int CREATE_SPACE_DONE = 1 << 17;
static const int SET_CURRENT_SPACE = 1 << 18;

//
// Interface: EditSpaceService ()
//

@class EditSpaceServiceTwinmeContextDelegate;

@interface EditSpaceService ()

@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) TLSpaceSettings *spaceSettings;
@property (nonatomic, nullable) UIImage *spaceAvatar;
@property (nonatomic, nullable) UIImage *spaceLargeAvatar;
@property (nonatomic, nullable) NSString *nameProfile;
@property (nonatomic, nullable) NSString *nameSpace;
@property (nonatomic, nullable) NSString *descriptionSpace;
@property (nonatomic, nullable) UIImage *avatar;
@property (nonatomic, nullable) UIImage *largeAvatar;
@property (nonatomic, nullable) TLExportedImageId *avatarId;
@property (nonatomic) int work;
@property (nonatomic) BOOL isFirstSpace;

- (void)onOperation;

- (void)onCreateSpace:(nonnull TLSpace *)space;

- (void)onUpdateSpace:(nonnull TLSpace *)space;

- (void)onCreateProfile:(nonnull TLProfile *)profile;

- (void)onDeleteSpace:(nonnull NSUUID *)spaceId;

- (void)onGetCurrentSpace:(nonnull TLSpace *)space;

- (void)onUpdateProfile:(nonnull TLProfile *)profile;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end


//
// Interface: EditSpaceServiceTwinmeContextDelegate
//

@interface EditSpaceServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull EditSpaceService *)service;

@end

//
// Implementation: EditSpaceServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"EditSpaceServiceTwinmeContextDelegate"

@implementation EditSpaceServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull EditSpaceService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onCreateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onCreateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(EditSpaceService *)self.service onCreateSpace:space];
}

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(EditSpaceService *)self.service onUpdateSpace:space];
}

- (void)onDeleteSpaceWithRequestId:(int64_t)requestId spaceId:(nonnull NSUUID *)spaceId {
    DDLogVerbose(@"%@ onDeleteSpaceWithRequestId: %lld spaceId: %@", LOG_TAG, requestId, spaceId);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(EditSpaceService *)self.service onDeleteSpace:spaceId];
}

- (void)onCreateProfileWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ onCreateProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    [(EditSpaceService *)self.service onCreateProfile:profile];
}

- (void)onUpdateProfileWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ onUpdateProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    [(EditSpaceService *)self.service onUpdateProfile:profile];
}

@end

//
// Implementation: EditSpaceService
//

#undef LOG_TAG
#define LOG_TAG @"EditSpaceService"

@implementation EditSpaceService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <EditSpaceServiceDelegate>)delegate space:(nullable TLSpace *)space {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@ space: %@", LOG_TAG, twinmeContext, delegate, space);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _space = space;
        _isFirstSpace = space == nil;
        self.twinmeContextDelegate = [[EditSpaceServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)createProfile:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nonnull UIImage *)largeAvatar {
    DDLogVerbose(@"%@ createProfile: %@ avatar: %@", LOG_TAG, name, avatar);
    
    self.nameProfile = name;
    self.avatar = avatar;
    self.largeAvatar = largeAvatar;
    self.work |= CREATE_PROFILE;
    self.state &= ~(CREATE_PROFILE | CREATE_PROFILE_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateProfile:(nonnull NSString*)name avatar:(nonnull UIImage *)avatar largeAvatar:(nonnull UIImage *)largeAvatar {
    DDLogVerbose(@"%@ updateProfile: %@ avatar: %@", LOG_TAG, name, avatar);
    
    self.work |= UPDATE_PROFILE;
    self.state &= ~(UPDATE_PROFILE | UPDATE_PROFILE_DONE);
    self.nameProfile = name;
    self.avatar = avatar;
    self.largeAvatar = largeAvatar;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)createSpace:(nonnull NSString *)nameSpace spaceAvatar:(nonnull UIImage *)spaceAvatar spaceLargeAvatar:(nonnull UIImage *)spaceLargeAvatar descriptionSpace:(nonnull NSString *)descriptionSpace spaceSettings:(nonnull TLSpaceSettings *)spaceSettings {
    DDLogVerbose(@"%@ createSpace: %@", LOG_TAG, nameSpace);
    
    self.nameSpace = nameSpace;
    self.descriptionSpace = descriptionSpace;
    self.spaceAvatar = spaceAvatar;
    self.spaceLargeAvatar = spaceLargeAvatar;
    self.spaceSettings = spaceSettings;
    self.work |= CREATE_SPACE;
    self.state &= ~(CREATE_SPACE | CREATE_SPACE_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateSpace:(nonnull TLSpaceSettings *)spaceSettings avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar {
    DDLogVerbose(@"%@ updateSpace: %@", LOG_TAG, spaceSettings);
    
    self.spaceAvatar = avatar;
    self.spaceLargeAvatar = largeAvatar;
    self.work |= UPDATE_SPACE;
    self.state &= ~(UPDATE_SPACE | UPDATE_SPACE_DONE);
    self.spaceSettings = spaceSettings;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)deleteSpace {
    DDLogVerbose(@"%@ deleteSpace", LOG_TAG);
    
    self.work |= DELETE_SPACE;
    self.state &= ~(DELETE_SPACE | DELETE_SPACE_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)setDefaultSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ setDefaultSpace: %@", LOG_TAG, space);
    
    [self.twinmeContext setDefaultSpace:space];
}

#pragma mark - Private methods

- (void)onCreateSpace:(TLSpace *)space {
    DDLogVerbose(@"%@ onCreateSpace: %@", LOG_TAG, space);
    
    self.state |= CREATE_SPACE_DONE;
    
    if (!self.space && self.isFirstSpace) {
        [self.twinmeContext setDefaultSpace:space];
        self.space = space;
    }
    
    if (self.isFirstSpace) {
        int64_t requestId = [self newOperation:SET_CURRENT_SPACE];
        [self.twinmeContext setCurrentSpaceWithRequestId:requestId space:space];
    }
    
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<EditSpaceServiceDelegate>)self.delegate onCreateSpace:space];
        });
    }
    [self onOperation];
}


- (void)onUpdateSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpace: %@", LOG_TAG, space);
    
    self.state |= UPDATE_SPACE_DONE;
    [self onUpdateImage];
    [self runOnUpdateSpace:space];
    [self onOperation];
}

- (void)onUpdateSpaceAvatar:(nonnull UIImage *)avatar {
    DDLogVerbose(@"%@ onUpdateSpace: %@", LOG_TAG, avatar);
    
    self.state |= GET_SPACE_IMAGE_DONE;
    self.avatar = avatar;
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<EditSpaceServiceDelegate>)self.delegate onUpdateSpaceAvatar:avatar];
        });
    }
    
    [self onOperation];
}

- (void)onCreateProfile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ onCreateProfile: %@", LOG_TAG, profile);
    
    if ([profile.space.uuid isEqual:self.space.uuid]) {
        self.state |= CREATE_PROFILE_DONE;
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<EditSpaceServiceDelegate>)self.delegate onCreateProfile:profile];
        });
    }
    [self onOperation];
}

- (void)onDeleteSpace:(nonnull NSUUID *)spaceId {
    DDLogVerbose(@"%@ onDeleteSpace: %@", LOG_TAG, spaceId);
    
    self.state |= DELETE_SPACE_DONE;
    [self runOnDeleteSpace:spaceId];
    [self onOperation];
}

- (void)onGetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onGetCurrentSpace: %@", LOG_TAG, space);
    
    self.state |= GET_CURRENT_SPACE_DONE;
    self.space = space;
    [self onUpdateImage];
    [self runOnGetSpace:space avatar:self.avatar];
    [self onOperation];
}

- (void)onUpdateProfile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ onUpdateProfile: %@", LOG_TAG, profile);
    
    if ([profile.space.uuid isEqual:self.space.uuid]) {
        self.state |= UPDATE_PROFILE_DONE;
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<EditSpaceServiceDelegate>)self.delegate onUpdateProfile:profile];
        });
    }
}

- (void)onGetContacts:(nonnull NSArray<TLContact *> *)contacts {
    DDLogVerbose(@"%@ onGetContacts: %@", LOG_TAG, contacts);
    
    self.state |= GET_CONTACTS_DONE;
    [self runOnGetContacts:contacts];
    [self onOperation];
}

- (void)onGetGroups:(nonnull NSArray<TLGroup *> *)groups {
    DDLogVerbose(@"%@ onGetGroups: %@", LOG_TAG, groups);
    
    self.state |= GET_GROUPS_DONE;
    [self runOnGetGroups:groups];
    [self onOperation];
}

- (void)onUpdateImage {
    DDLogVerbose(@"%@ onUpdateImage", LOG_TAG);

    NSUUID *avatarId = self.space.avatarId;
    if (avatarId) {
        TLImageService *imageService = [self.twinmeContext getImageService];
        self.avatarId = [imageService imageWithPublicId:avatarId];
        if (self.avatarId) {
            self.avatar = [imageService getCachedImageWithImageId:self.avatarId kind:TLImageServiceKindThumbnail];
            self.state &= ~(GET_SPACE_IMAGE | GET_SPACE_IMAGE_DONE);
        }
    } else {
        self.avatarId = nil;
    }
}

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
        
        if (self.space) {
            [self.twinmeContext getSpaceWithSpaceId:self.space.uuid withBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
                [self onGetCurrentSpace:space];
            }];
        } else {
            [self.twinmeContext getCurrentSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
                [self onGetCurrentSpace:space];
            }];
        }
        return;
    }
    if ((self.state & GET_CURRENT_SPACE_DONE) == 0) {
        return;
    }
    
    if (self.avatarId) {
        if ((self.state & GET_SPACE_IMAGE) == 0) {
            self.state |= GET_SPACE_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindLarge withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                    [self onUpdateSpaceAvatar:image];
                }];
            return;
        }
        
        if ((self.state & GET_SPACE_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    
    //
    // Step 2: get the contacts.
    //
    if ((self.state & GET_CONTACTS) == 0) {
        self.state |= GET_CONTACTS;

        [self.twinmeContext findContactsWithFilter:[self.twinmeContext createSpaceFilter] withBlock:^(NSMutableArray<TLContact *> *list) {
            [self onGetContacts:list];
        }];
        return;
    }
    if ((self.state & GET_GROUPS) == 0) {
        self.state |= GET_GROUPS;

        [self.twinmeContext findGroupsWithFilter:[self.twinmeContext createSpaceFilter] withBlock:^(NSMutableArray<TLGroup *> *list) {
            [self onGetGroups:list];
        }];
        return;
    }
    
    if ((self.state & GET_CONTACTS_DONE) == 0) {
        return;
    }
    if ((self.state & GET_GROUPS_DONE) == 0) {
        return;
    }
    
    //
    // Work step: create a space.
    //
    if ((self.work & CREATE_SPACE) != 0) {
        if ((self.state & CREATE_SPACE) == 0) {
            self.state |= CREATE_SPACE;
            
            int64_t requestId = [self newOperation:CREATE_SPACE];
            if (self.descriptionSpace) {
                self.spaceSettings.objectDescription = self.descriptionSpace;
            }
            
            DDLogVerbose(@"%@ createSpaceWithRequestId: %lld settings: %@ spaceAvatar: nil spaceLargeAvatar: nil", LOG_TAG, requestId, self.spaceSettings);
            
            [self.twinmeContext createSpaceWithRequestId:requestId settings:self.spaceSettings spaceAvatar:self.spaceAvatar spaceLargeAvatar:self.spaceLargeAvatar];
            return;
        }
        
        if ((self.state & CREATE_SPACE_DONE) == 0) {
            return;
        }
    }
    
    
    // Create the space profile.
    if ((self.work & CREATE_PROFILE) != 0) {
        if ((self.state & CREATE_PROFILE) == 0) {
            self.state |= CREATE_PROFILE;
            
            int64_t requestId = [self newOperation:CREATE_PROFILE];
            DDLogVerbose(@"%@ createProfileWithRequestId: %lld name:%@ avatar:%@ space:%@", LOG_TAG, requestId, self.nameProfile, self.avatar, self.space);
            
            [self.twinmeContext createProfileWithRequestId:requestId name:self.nameProfile avatar:self.avatar largeAvatar:self.largeAvatar description:nil capabilities:nil space:self.space];
            return;
        }
        
        if ((self.state & CREATE_PROFILE_DONE) == 0) {
            return;
        }
    }
    
    // Update the profile.
    if ((self.work & UPDATE_PROFILE) != 0) {
        if ((self.state & UPDATE_PROFILE) == 0) {
            self.state |= UPDATE_PROFILE;
            
            int64_t requestId = [self newOperation:UPDATE_SPACE];
            DDLogVerbose(@"%@ updateProfileWithRequestId: %lld profile:%@ name:%@ avatar:%@", LOG_TAG, requestId, self.space.profile, self.nameProfile, self.avatar);
            [self.twinmeContext updateProfileWithRequestId:requestId profile:self.space.profile updateMode:TLProfileUpdateModeDefault name:self.nameProfile avatar:self.avatar largeAvatar:self.largeAvatar description:self.space.profile.objectDescription capabilities:self.space.profile.identityCapabilities];
            return;
        }
        
        if ((self.state & UPDATE_PROFILE_DONE) == 0) {
            return;
        }
    }
    
    // Update the space settings.
    if ((self.work & UPDATE_SPACE) != 0) {
        if ((self.state & UPDATE_SPACE) == 0) {
            self.state |= UPDATE_SPACE;
            
            int64_t requestId = [self newOperation:UPDATE_SPACE];
            DDLogVerbose(@"%@ updateSpaceWithRequestId: %lld space:%@ settings:%@", LOG_TAG, requestId, self.space, self.spaceSettings);
            [self.twinmeContext updateSpaceWithRequestId:requestId space:self.space settings:self.spaceSettings spaceAvatar:self.spaceAvatar spaceLargeAvatar:self.spaceLargeAvatar];
            return;
        }
        
        if ((self.state & UPDATE_SPACE_DONE) == 0) {
            return;
        }
    }
    
    // Delete the space.
    if ((self.work & DELETE_SPACE) != 0) {
        if ((self.state & DELETE_SPACE) == 0) {
            self.state |= DELETE_SPACE;
            
            int64_t requestId = [self newOperation:DELETE_SPACE];
            DDLogVerbose(@"%@ deleteSpaceWithRequestId: %lld space:%@", LOG_TAG, requestId, self.space);
            [self.twinmeContext deleteSpaceWithRequestId:requestId space:self.space];
            return;
        }
        
        if ((self.state & DELETE_SPACE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    if (operationId == DELETE_SPACE && errorCode == TLBaseServiceErrorCodeItemNotFound) {
        self.state |= DELETE_SPACE_DONE;
        [self onOperation];
        return;
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
