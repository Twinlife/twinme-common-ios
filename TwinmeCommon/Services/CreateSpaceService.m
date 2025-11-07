/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLImageService.h>

#import <Twinme/TLTwinmeContext.h>

#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLSpace.h>

#import "CreateSpaceService.h"
#import "AbstractTwinmeService+Protected.h"
#import "Design.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int CREATE_IMAGE = 1 << 0;
static const int CREATE_IMAGE_DONE = 1 << 1;
static const int CREATE_SPACE = 1 << 2;
static const int CREATE_SPACE_DONE = 1 << 3;
static const int CREATE_PROFILE = 1 << 4;
static const int CREATE_PROFILE_DONE = 1 << 5;
static const int MOVE_CONTACT_SPACE = 1 << 6;
static const int MOVE_CONTACT_SPACE_DONE = 1 << 7;

//
// Interface: CreateSpaceService ()
//

@protocol TLOriginator;
@class CreateSpaceServiceTwinmeContextDelegate;

@interface CreateSpaceService ()

@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) TLSpaceSettings *spaceSettings;
@property (nonatomic, nullable) UIImage *spaceAvatar;
@property (nonatomic, nullable) UIImage *spaceLargeAvatar;
@property (nonatomic, nullable) NSString *nameProfile;
@property (nonatomic, nullable) NSString *descriptionProfile;
@property (nonatomic, nullable) UIImage *avatar;
@property (nonatomic, nullable) UIImage *largeAvatar;
@property (nonatomic, nullable) NSMutableArray<id<TLOriginator>> *moveContacts;
@property (nonatomic, nullable) id<TLOriginator> currentMoveContact;
@property (nonatomic, nullable) UIImage *conversationBackgroundLightImage;
@property (nonatomic, nullable) UIImage *conversationBackgroundLightLargeImage;
@property (nonatomic, nullable) UIImage *conversationBackgroundDarkImage;
@property (nonatomic, nullable) UIImage *conversationBackgroundDarkLargeImage;
@property (nonatomic) BOOL isConversationBackgroundLightImage;
@property (nonatomic) int work;

- (void)onOperation;

- (void)onCreateImage:(TLBaseServiceErrorCode)errorCode imageId:(nonnull TLExportedImageId *)imageId;

- (void)onCreateSpace:(nonnull TLSpace *)space;

- (void)onMoveToSpace:(nonnull id<TLOriginator>)contact oldSpace:(nonnull TLSpace *)oldSpace;

- (void)onCreateProfile:(nonnull TLProfile *)profile;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Interface: CreateSpaceServiceTwinmeContextDelegate
//

@interface CreateSpaceServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull CreateSpaceService *)service;

@end

//
// Implementation: CreateSpaceServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"CreateSpaceServiceTwinmeContextDelegate"

@implementation CreateSpaceServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull CreateSpaceService *)service {
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
    
    [(CreateSpaceService *)self.service onCreateSpace:space];
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId contact:(TLContact *)contact oldSpace:(TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld contact: %@ oldSpace: %@", LOG_TAG, requestId, contact, oldSpace);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(CreateSpaceService *)self.service onMoveToSpace:contact oldSpace:oldSpace];
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId group:(TLGroup *)group oldSpace:(TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld group: %@ oldSpace: %@", LOG_TAG, requestId, group, oldSpace);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(CreateSpaceService *)self.service onMoveToSpace:group oldSpace:oldSpace];
}

- (void)onCreateProfileWithRequestId:(int64_t)requestId profile:(TLProfile *)profile {
    DDLogVerbose(@"%@ onCreateProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(CreateSpaceService *)self.service onCreateProfile:profile];
}

@end

//
// Implementation: CreateSpaceService
//

#undef LOG_TAG
#define LOG_TAG @"CreateSpaceService"

@implementation CreateSpaceService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <CreateSpaceServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _isConversationBackgroundLightImage = NO;
        self.twinmeContextDelegate = [[CreateSpaceServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)createSpace:(nonnull TLSpaceSettings *)spaceSettings spaceAvatar:(nonnull UIImage *)spaceAvatar spaceLargeAvatar:(nonnull UIImage *)spaceLargeAvatar nameProfile:(nonnull NSString *)nameProfile descriptionProfile:(nullable NSString *)descriptionProfile avatar:(nonnull UIImage *)avatar largeAvatar:(nonnull UIImage *)largeAvatar contacts:(nonnull NSMutableArray<id<TLOriginator>> *)contacts conversationBackgroundLightImage:(nullable UIImage *)conversationBackgroundLightImage conversationBackgroundLightLargeImage:(nullable UIImage *)conversationBackgroundLightLargeImage conversationBackgroundDarkImage:(nullable UIImage *)conversationBackgroundDarkImage conversationBackgroundDarkLargeImage:(nullable UIImage *)conversationBackgroundDarkLargeImage {
    DDLogVerbose(@"%@ createSpace: %@ name: %@ descriptionProfile: %@ avatar: %@ contacts: %@", LOG_TAG, spaceSettings, nameProfile, descriptionProfile, avatar, contacts);
    
    [self showProgressIndicator];
    self.spaceAvatar = spaceAvatar;
    self.spaceLargeAvatar = spaceLargeAvatar;
    self.nameProfile = nameProfile;
    self.descriptionProfile = descriptionProfile;
    self.avatar = avatar;
    self.largeAvatar = largeAvatar;
    self.spaceSettings = spaceSettings;
    self.moveContacts = contacts;
    self.conversationBackgroundLightImage = conversationBackgroundLightImage;
    self.conversationBackgroundLightLargeImage = conversationBackgroundLightLargeImage;
    self.conversationBackgroundDarkImage = conversationBackgroundDarkImage;
    self.conversationBackgroundDarkLargeImage = conversationBackgroundDarkLargeImage;
    
    if (self.conversationBackgroundLightImage) {
        self.isConversationBackgroundLightImage = YES;
        self.work |= CREATE_IMAGE;
        self.state &= ~(CREATE_IMAGE | CREATE_IMAGE_DONE);
    } else if (self.conversationBackgroundDarkImage) {
        self.work |= CREATE_IMAGE;
        self.state &= ~(CREATE_IMAGE | CREATE_IMAGE_DONE);
    } else {
        self.work |= CREATE_SPACE;
        self.state &= ~(CREATE_SPACE | CREATE_SPACE_DONE);
    }
    
    [self startOperation];
}

#pragma mark - Private methods

- (void)onCreateSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onCreateSpace: %@", LOG_TAG, space);
    
    self.state |= CREATE_SPACE_DONE;
    self.space = space;
    
    if (self.nameProfile && self.avatar) {
        self.work |= CREATE_PROFILE;
        self.state &= ~(CREATE_PROFILE | CREATE_PROFILE_DONE);
    } else {
        self.work |= MOVE_CONTACT_SPACE;
        self.state &= ~(MOVE_CONTACT_SPACE | MOVE_CONTACT_SPACE_DONE);
        [self nextMoveContact];
    }
    
    [self onOperation];
}

- (void)onCreateProfile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ onCreateProfile: %@", LOG_TAG, profile);
    
    self.state |= CREATE_PROFILE_DONE;
    
    self.work |= MOVE_CONTACT_SPACE;
    self.state &= ~(MOVE_CONTACT_SPACE | MOVE_CONTACT_SPACE_DONE);
    [self nextMoveContact];
    [self onOperation];
}

- (void)onMoveToSpace:(nonnull id<TLOriginator>)contact oldSpace:(nonnull TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpace: %@ oldSpace: %@", LOG_TAG, contact, oldSpace);
    
    self.state |= MOVE_CONTACT_SPACE_DONE;
    
    [self nextMoveContact];
    [self onOperation];
}

- (void)onCreateImage:(TLBaseServiceErrorCode)errorCode imageId:(nonnull TLExportedImageId *)imageId {
    DDLogVerbose(@"%@ onCreateImage: %@", LOG_TAG, imageId);
    
    self.state |= CREATE_IMAGE_DONE;
    
    if (self.isConversationBackgroundLightImage) {
        [self.spaceSettings removeWithName:PROPERTY_CONVERSATION_BACKGROUND_COLOR];
        if (imageId) {
            [self.spaceSettings setUUIDWithName:PROPERTY_CONVERSATION_BACKGROUND_IMAGE value:imageId.publicId];
        }
        
        if (self.conversationBackgroundDarkImage) {
            self.isConversationBackgroundLightImage = NO;
            self.work |= CREATE_IMAGE;
            self.state &= ~(CREATE_IMAGE | CREATE_IMAGE_DONE);
        } else {
            self.work |= CREATE_SPACE;
            self.state &= ~(CREATE_SPACE | CREATE_SPACE_DONE);
        }
    } else {
        [self.spaceSettings removeWithName:PROPERTY_DARK_CONVERSATION_BACKGROUND_COLOR];
        if (imageId) {
            [self.spaceSettings setUUIDWithName:PROPERTY_DARK_CONVERSATION_BACKGROUND_IMAGE value:imageId.publicId];
        }
        
        self.work |= CREATE_SPACE;
        self.state &= ~(CREATE_SPACE | CREATE_SPACE_DONE);
    }
    
    [self onOperation];
}


- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    if ((self.work & CREATE_IMAGE) != 0) {
        if ((self.state & CREATE_IMAGE) == 0) {
            self.state |= CREATE_IMAGE;
            
            UIImage *largeImage = self.conversationBackgroundLightLargeImage;
            UIImage *thumbnailImage = self.conversationBackgroundLightImage;
            
            if (!self.isConversationBackgroundLightImage) {
                largeImage = self.conversationBackgroundDarkLargeImage;
                thumbnailImage = self.conversationBackgroundDarkImage;
            }
            
            [[self.twinmeContext getImageService] createLocalImageWithImage:largeImage thumbnail:thumbnailImage withBlock:^(TLBaseServiceErrorCode errorCode, TLExportedImageId *imageId) {
                [self onCreateImage:errorCode imageId:imageId];
            }];
            return;
        }
        
        if ((self.state & CREATE_IMAGE_DONE) == 0) {
            return;
        }
    }

    // Create the space.
    if ((self.work & CREATE_SPACE) != 0) {
        if ((self.state & CREATE_SPACE) == 0) {
            self.state |= CREATE_SPACE;
            
            int64_t requestId = [self newOperation:CREATE_SPACE];
            DDLogVerbose(@"%@ createSpaceWithRequestId: %lld settings:%@ nameProfile:%@ avatar:%@", LOG_TAG, requestId, self.spaceSettings, self.nameProfile, self.avatar);
            
            [self.twinmeContext createSpaceWithRequestId:requestId settings:self.spaceSettings spaceAvatar:self.spaceAvatar spaceLargeAvatar:self.spaceLargeAvatar];
            return;
        }
        
        if ((self.state & CREATE_SPACE_DONE) == 0) {
            return;
        }
    }
    
    // Create profile for space.
    if ((self.work & CREATE_PROFILE) != 0 && self.space) {
        if ((self.state & CREATE_PROFILE) == 0) {
            self.state |= CREATE_PROFILE;
            
            int64_t requestId = [self newOperation:CREATE_PROFILE];
            DDLogVerbose(@"%@ createProfileWithRequestId: %lld name:%@ avatar:%@ largeAvatar:%@ space:%@", LOG_TAG, requestId, self.nameProfile, self.avatar, self.largeAvatar, self.space);
            
            [self.twinmeContext createProfileWithRequestId:requestId name:self.nameProfile avatar:self.avatar largeAvatar:self.largeAvatar description:self.descriptionProfile capabilities:nil space:self.space];
            return;
        }
        
        if ((self.state & CREATE_PROFILE_DONE) == 0) {
            return;
        }
    }
    
    // Move the selected contacts to the new space.
    if ((self.work & MOVE_CONTACT_SPACE) != 0 && self.space) {
        if ((self.state & MOVE_CONTACT_SPACE) == 0) {
            
            if (!self.currentMoveContact) {
                [self nextMoveContact];
            }
            
            self.state |= MOVE_CONTACT_SPACE;
            
            if (self.currentMoveContact) {
                int64_t requestId = [self newOperation:MOVE_CONTACT_SPACE];
                DDLogVerbose(@"%@ moveToSpaceWithRequestId: %lld contact:%@ space:%@", LOG_TAG, requestId, self.currentMoveContact, self.space);
                if ([(id)self.currentMoveContact isKindOfClass:[TLContact class]]) {
                    [self.twinmeContext moveToSpaceWithRequestId:requestId contact:(TLContact *)self.currentMoveContact space:self.space];
                } else {
                    [self.twinmeContext moveToSpaceWithRequestId:requestId group:(TLGroup *)self.currentMoveContact space:self.space];
                }
                return;
            }
        }
        
        if ((self.state & MOVE_CONTACT_SPACE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    [self hideProgressIndicator];
}

- (void)nextMoveContact {
    DDLogVerbose(@"%@ nextMoveContact", LOG_TAG);
    
    if (self.moveContacts && self.moveContacts.count > 0) {
        if (self.currentMoveContact) {
            [self.moveContacts removeObjectAtIndex:0];
        }
        
        if (self.moveContacts.count > 0) {
            self.currentMoveContact = [self.moveContacts objectAtIndex:0];
            self.state &= ~(MOVE_CONTACT_SPACE | MOVE_CONTACT_SPACE_DONE);
        } else {
            self.currentMoveContact = nil;
        }
    }
    if (!self.currentMoveContact) {
        self.currentMoveContact = nil;
        
        self.state |= MOVE_CONTACT_SPACE | MOVE_CONTACT_SPACE_DONE;
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CreateSpaceServiceDelegate>)self.delegate onCreateSpace:self.space];
        });
    }
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    // If a contact/group was not found, ignore it and proceed with the next move.
    if (operationId == MOVE_CONTACT_SPACE && errorCode == TLBaseServiceErrorCodeItemNotFound) {
        [self nextMoveContact];
        return;
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
