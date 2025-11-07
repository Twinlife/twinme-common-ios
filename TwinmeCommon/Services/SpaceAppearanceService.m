/*
 *  Copyright (c) 2020-2024 twinlife SA.
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

#import "SpaceAppearanceService.h"
#import "AbstractTwinmeService+Protected.h"
#import "Design.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int UPDATE_SPACE = 1 << 0;
static const int UPDATE_SPACE_DONE = 1 << 1;
static const int CREATE_IMAGE = 1 << 2;
static const int CREATE_IMAGE_DONE = 1 << 3;
static const int DELETE_IMAGE = 1 << 4;
static const int DELETE_IMAGE_DONE = 1 << 5;
static const int UPDATE_DEFAULT_SPACE_SETTINGS = 1 << 6;
static const int UPDATE_DEFAULT_SPACE_SETTINGS_DONE = 1 << 7;

//
// Interface: SpaceAppearanceService ()
//

@class SpaceAppearanceServiceTwinmeContextDelegate;

@interface SpaceAppearanceService ()

@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) TLSpaceSettings *spaceSettings;
@property (nonatomic, nullable) UIImage *conversationBackgroundLightImage;
@property (nonatomic, nullable) UIImage *conversationBackgroundLightLargeImage;
@property (nonatomic, nullable) UIImage *conversationBackgroundDarkImage;
@property (nonatomic, nullable) UIImage *conversationBackgroundDarkLargeImage;
@property (nonatomic, nullable) TLImageId *removeImageId;

@property (nonatomic) int work;
@property (nonatomic) BOOL isConversationBackgroundLightImage;
@property (nonatomic) BOOL updateConversationBackgroundLightColor;
@property (nonatomic) BOOL updateConversationBackgroundDarkColor;
@property (nonatomic) BOOL cleanBackgroundImage;

- (void)onOperation;

- (void)onUpdateSpace:(nonnull TLSpace *)space;

- (void)onUpdateSpaceDefaultSettings:(nonnull TLSpaceSettings *)spaceSettings;

- (void)onCreateImage:(TLBaseServiceErrorCode)errorCode imageId:(nullable TLExportedImageId *)imageId;

- (void)onDeleteImage;

@end


//
// Interface: SpaceAppearanceServiceTwinmeContextDelegate
//

@interface SpaceAppearanceServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull SpaceAppearanceService *)service;

@end

//
// Implementation: SpaceAppearanceServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"SpaceAppearanceServiceTwinmeContextDelegate"

@implementation SpaceAppearanceServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull SpaceAppearanceService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(SpaceAppearanceService *)self.service onUpdateSpace:space];
}

@end

//
// Implementation: SpaceAppearanceService
//

#undef LOG_TAG
#define LOG_TAG @"SpaceAppearanceService"

@implementation SpaceAppearanceService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <SpaceAppearanceServiceDelegate>)delegate space:(nullable TLSpace *)space {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@ space: %@", LOG_TAG, twinmeContext, delegate, space);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _space = space;
        _isConversationBackgroundLightImage = NO;
        _updateConversationBackgroundLightColor = NO;
        _updateConversationBackgroundDarkColor = NO;
        _cleanBackgroundImage = NO;
        self.twinmeContextDelegate = [[SpaceAppearanceServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)updateSpace:(nonnull TLSpaceSettings *)spaceSettings {
    DDLogVerbose(@"%@ updateSpace: %@", LOG_TAG, spaceSettings);
    
    self.work |= UPDATE_SPACE;
    self.state &= ~(UPDATE_SPACE | UPDATE_SPACE_DONE);
    self.spaceSettings = spaceSettings;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateDefaultSpaceSettings:(nonnull TLSpaceSettings *)spaceSettings {
    DDLogVerbose(@"%@ updateDefaultSpaceSettings: %@", LOG_TAG, spaceSettings);
    
    self.spaceSettings = spaceSettings;
    
    self.work |= UPDATE_DEFAULT_SPACE_SETTINGS;
    self.state &= ~(UPDATE_DEFAULT_SPACE_SETTINGS | UPDATE_DEFAULT_SPACE_SETTINGS_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateSpace:(nonnull TLSpaceSettings *)spaceSettings conversationBackgroundLightImage:(nullable UIImage *)conversationBackgroundLightImage conversationBackgroundLightLargeImage:(nullable UIImage *)conversationBackgroundLightLargeImage conversationBackgroundDarkImage:(nullable UIImage *)conversationBackgroundDarkImage conversationBackgroundDarkLargeImage:(nullable UIImage *)conversationBackgroundDarkLargeImage updateConversationBackgroundLightColor:(BOOL)updateConversationBackgroundLightColor updateConversationBackgroundDarkColor:(BOOL)updateConversationBackgroundDarkColor {
    DDLogVerbose(@"%@ updateSpace: %@", LOG_TAG, spaceSettings);
    
    
    self.conversationBackgroundLightImage = conversationBackgroundLightImage;
    self.conversationBackgroundLightLargeImage = conversationBackgroundLightLargeImage;
    self.conversationBackgroundDarkImage = conversationBackgroundDarkImage;
    self.conversationBackgroundDarkLargeImage = conversationBackgroundDarkLargeImage;
    self.updateConversationBackgroundLightColor = updateConversationBackgroundLightColor;
    self.updateConversationBackgroundDarkColor = updateConversationBackgroundDarkColor;
    self.spaceSettings = spaceSettings;
    
    if (self.conversationBackgroundLightImage) {
        self.isConversationBackgroundLightImage = YES;
        self.work |= CREATE_IMAGE;
        self.state &= ~(CREATE_IMAGE | CREATE_IMAGE_DONE);
    } else if (self.conversationBackgroundDarkImage) {
        self.work |= CREATE_IMAGE;
        self.state &= ~(CREATE_IMAGE | CREATE_IMAGE_DONE);
    } else if (self.space) {
        self.work |= UPDATE_SPACE;
        self.state &= ~(UPDATE_SPACE | UPDATE_SPACE_DONE);
    } else {
        self.work |= UPDATE_DEFAULT_SPACE_SETTINGS;
        self.state &= ~(UPDATE_DEFAULT_SPACE_SETTINGS | UPDATE_DEFAULT_SPACE_SETTINGS_DONE);
    }
    
    [self showProgressIndicator];
    [self startOperation];
}


#pragma mark - Private methods

- (void)deleteWithImageId:(nonnull NSUUID *)imageId {
    DDLogVerbose(@"%@ deleteWithImageId: %@", LOG_TAG, imageId);

    TLImageService *imageService = [self.twinmeContext getImageService];
    self.removeImageId = [imageService imageWithPublicId:imageId];
    if (!self.removeImageId) {
        return;
    }

    self.work |= DELETE_IMAGE;
    self.state &= ~(DELETE_IMAGE | DELETE_IMAGE_DONE);
    [self onOperation];
}

- (void)onUpdateSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpace: %@", LOG_TAG, space);
    
    self.state |= UPDATE_SPACE_DONE;
    self.spaceSettings = space.settings;
    
    if (self.updateConversationBackgroundLightColor) {
        NSUUID *lightImageId = [self.spaceSettings getUUIDWithName:PROPERTY_CONVERSATION_BACKGROUND_IMAGE];
        [self.spaceSettings removeWithName:PROPERTY_CONVERSATION_BACKGROUND_IMAGE];
        if (lightImageId) {
            self.cleanBackgroundImage = YES;
            [self deleteWithImageId:lightImageId];
            return;
        }
    }
    
    if (self.updateConversationBackgroundDarkColor) {
        NSUUID *darkImageId = [self.spaceSettings getUUIDWithName:PROPERTY_DARK_CONVERSATION_BACKGROUND_IMAGE];
        [self.spaceSettings removeWithName:PROPERTY_DARK_CONVERSATION_BACKGROUND_IMAGE];
        if (darkImageId) {
            self.cleanBackgroundImage = YES;
            [self deleteWithImageId:darkImageId];
            return;
        }
    }
    [self runOnUpdateSpace:self.space];
    [self onOperation];
}

- (void)onCreateImage:(TLBaseServiceErrorCode)errorCode imageId:(nullable TLExportedImageId *)imageId {
    DDLogVerbose(@"%@ onCreateImage: %@", LOG_TAG, imageId);
    
    self.state |= CREATE_IMAGE_DONE;
    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:CREATE_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }

    if (self.isConversationBackgroundLightImage) {
        NSUUID *removeImageId = [self.spaceSettings getUUIDWithName:PROPERTY_CONVERSATION_BACKGROUND_IMAGE];
        [self.spaceSettings removeWithName:PROPERTY_CONVERSATION_BACKGROUND_COLOR];
        [self.spaceSettings setUUIDWithName:PROPERTY_CONVERSATION_BACKGROUND_IMAGE value:imageId.publicId];
        
        if (removeImageId) {
            [self deleteWithImageId:removeImageId];
            return;
        }
        
        if (self.conversationBackgroundDarkImage) {
            self.isConversationBackgroundLightImage = NO;
            self.work |= CREATE_IMAGE;
            self.state &= ~(CREATE_IMAGE | CREATE_IMAGE_DONE);
        } else if (self.space) {
            self.work |= UPDATE_SPACE;
            self.state &= ~(UPDATE_SPACE | UPDATE_SPACE_DONE);
        } else {
            self.work |= UPDATE_DEFAULT_SPACE_SETTINGS;
            self.state &= ~(UPDATE_DEFAULT_SPACE_SETTINGS | UPDATE_DEFAULT_SPACE_SETTINGS_DONE);
        }
    } else {
        NSUUID *removeImageId = [self.spaceSettings getUUIDWithName:PROPERTY_DARK_CONVERSATION_BACKGROUND_IMAGE];
        [self.spaceSettings removeWithName:PROPERTY_DARK_CONVERSATION_BACKGROUND_COLOR];
        [self.spaceSettings setUUIDWithName:PROPERTY_DARK_CONVERSATION_BACKGROUND_IMAGE value:imageId.publicId];
        
        if (removeImageId) {
            [self deleteWithImageId:removeImageId];
            return;
        }
        
        if (self.space) {
            self.work |= UPDATE_SPACE;
            self.state &= ~(UPDATE_SPACE | UPDATE_SPACE_DONE);
        } else {
            self.work |= UPDATE_DEFAULT_SPACE_SETTINGS;
            self.state &= ~(UPDATE_DEFAULT_SPACE_SETTINGS | UPDATE_DEFAULT_SPACE_SETTINGS_DONE);
        }
    }
    [self onOperation];
}

- (void)onDeleteImage {
    DDLogVerbose(@"%@ onDeleteImage", LOG_TAG);
    
    self.state |= DELETE_IMAGE_DONE;
    
    if (self.cleanBackgroundImage && self.updateConversationBackgroundDarkColor) {
        NSUUID *darkImageId = [self.spaceSettings getUUIDWithName:PROPERTY_DARK_CONVERSATION_BACKGROUND_IMAGE];
        [self.spaceSettings removeWithName:PROPERTY_DARK_CONVERSATION_BACKGROUND_IMAGE];
        if (darkImageId) {
            self.cleanBackgroundImage = NO;
            [self deleteWithImageId:darkImageId];
            return;
        }
    } else if (self.isConversationBackgroundLightImage) {
        if (self.conversationBackgroundDarkImage) {
            self.isConversationBackgroundLightImage = NO;
            self.work |= CREATE_IMAGE;
            self.state &= ~(CREATE_IMAGE | CREATE_IMAGE_DONE);
            [self onOperation];
            return;
        }
    }
    
    if (self.space) {
        self.work |= UPDATE_SPACE;
        self.state &= ~(UPDATE_SPACE | UPDATE_SPACE_DONE);
    } else {
        self.work |= UPDATE_DEFAULT_SPACE_SETTINGS;
        self.state &= ~(UPDATE_DEFAULT_SPACE_SETTINGS | UPDATE_DEFAULT_SPACE_SETTINGS_DONE);
    }
    [self onOperation];
}

- (void)onUpdateSpaceDefaultSettings:(nonnull TLSpaceSettings *)spaceSettings {
    DDLogVerbose(@"%@ onUpdateDefaultSpaceSettings: %@", LOG_TAG, spaceSettings);
    
    self.state |= UPDATE_DEFAULT_SPACE_SETTINGS_DONE;
            
    self.spaceSettings = spaceSettings;
    
    if (self.updateConversationBackgroundLightColor) {
        NSUUID *lightImageId = [self.spaceSettings getUUIDWithName:PROPERTY_CONVERSATION_BACKGROUND_IMAGE];
        [self.spaceSettings removeWithName:PROPERTY_CONVERSATION_BACKGROUND_IMAGE];
        if (lightImageId) {
            self.cleanBackgroundImage = YES;
            [self deleteWithImageId:lightImageId];
            return;
        }
    }
    
    if (self.updateConversationBackgroundDarkColor) {
        NSUUID *darkImageId = [self.spaceSettings getUUIDWithName:PROPERTY_DARK_CONVERSATION_BACKGROUND_IMAGE];
        [self.spaceSettings removeWithName:PROPERTY_DARK_CONVERSATION_BACKGROUND_IMAGE];
        if (darkImageId) {
            self.cleanBackgroundImage = YES;
            [self deleteWithImageId:darkImageId];
            return;
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<SpaceAppearanceServiceDelegate>)self.delegate onUpdateSpaceDefaultSettings:self.spaceSettings];
    });
    [self onOperation];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    // Update the space settings.
    if ((self.work & UPDATE_SPACE) != 0) {
        if ((self.state & UPDATE_SPACE) == 0) {
            self.state |= UPDATE_SPACE;
            
            int64_t requestId = [self newOperation:UPDATE_SPACE];
            DDLogVerbose(@"%@ updateSpaceWithRequestId: %lld space:%@ settings:%@", LOG_TAG, requestId, self.space, self.spaceSettings);
            [self.twinmeContext updateSpaceWithRequestId:requestId space:self.space settings:self.spaceSettings spaceAvatar:nil spaceLargeAvatar:nil];
            return;
        }
        
        if ((self.state & UPDATE_SPACE_DONE) == 0) {
            return;
        }
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
    
    if ((self.work & DELETE_IMAGE) != 0) {
        if ((self.state & DELETE_IMAGE) == 0) {
            self.state |= DELETE_IMAGE;
            
            [[self.twinmeContext getImageService] deleteImageWithImageId:self.removeImageId withBlock:^(TLBaseServiceErrorCode errorCode, TLImageId *imageId) {
                [self onDeleteImage];
            }];
            return;
        }
        
        if ((self.state & DELETE_IMAGE_DONE) == 0) {
            return;
        }
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
