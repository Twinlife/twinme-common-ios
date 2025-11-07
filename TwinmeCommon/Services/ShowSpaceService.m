/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLImageService.h>
#import <Twinlife/TLTwincodeOutboundService.h>

#import <Twinme/TLTwinmeContext.h>

#import <Twinme/TLProfile.h>
#import <Twinme/TLSpace.h>
#import "ShowSpaceService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_SPACE = 1 << 0;
static const int GET_SPACE_DONE = 1 << 1;
static const int GET_SPACE_IMAGE = 1 << 2;
static const int GET_SPACE_IMAGE_DONE = 1 << 3;
static const int UPDATE_SPACE = 1 << 4;
static const int UPDATE_SPACE_DONE = 1 << 5;

//
// Interface: ShowSpaceService ()
//

@class ShowSpaceServiceTwinmeContextDelegate;
@class ShowSpaceServiceConversationServiceDelegate;

@interface ShowSpaceService ()

@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) TLSpaceSettings *spaceSettings;
@property (nonatomic, nullable) NSUUID *spaceId;
@property (nonatomic, nullable) NSUUID *twincodeOutboundId;
@property (nonatomic, nullable) TLExportedImageId *avatarId;
@property (nonatomic, nullable) UIImage *avatar;
@property (nonatomic) int work;
@property (nonatomic) BOOL createSpace;

- (void)onOperation;

- (void)onTwinlifeReady;

- (void)onGetSpace:(TLSpace*)space;

- (void)onCreateSpace:(TLSpace*)space;

- (void)onUpdateSpace:(TLSpace *)space;

- (void)onDeleteSpace:(NSUUID *)spaceId;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

@end

//
// Interface: ShowSpaceServiceTwinmeContextDelegate
//

@interface ShowSpaceServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (instancetype)initWithService:(ShowSpaceService *)service;

@end

//
// Implementation: ShowSpaceServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ShowSpaceServiceTwinmeContextDelegate"

@implementation ShowSpaceServiceTwinmeContextDelegate

- (instancetype)initWithService:(ShowSpaceService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onCreateProfileWithRequestId:(int64_t)requestId profile:(TLProfile *)profile {
    DDLogVerbose(@"%@ onCreateProfileWithRequestId: %lld space: %@", LOG_TAG, requestId, profile);
    
    [(ShowSpaceService *)self.service onUpdateSpace:profile.space];
}

- (void)onCreateSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onCreateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(ShowSpaceService *)self.service onCreateSpace:space];
}

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(ShowSpaceService *)self.service onUpdateSpace:space];
}

- (void)onDeleteSpaceWithRequestId:(int64_t)requestId spaceId:(NSUUID *)spaceId {
    DDLogVerbose(@"%@ onDeleteSpaceWithRequestId: %lld spaceId: %@", LOG_TAG, requestId, spaceId);
    
    [(ShowSpaceService *)self.service onDeleteSpace:spaceId];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorcode errorParameter:(NSString *)errorParameter {
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(ShowSpaceService *)self.service onErrorWithOperationId:operationId errorCode:errorcode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Implementation: ShowSpaceService
//

#undef LOG_TAG
#define LOG_TAG @"ShowSpaceService"

@implementation ShowSpaceService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <ShowSpaceServiceDelegate>)delegate createSpace:(BOOL)createSpace {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@ createSpace: %@", LOG_TAG, twinmeContext, delegate, createSpace ? @"YES" : @"NO");
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.createSpace = createSpace;
        self.twinmeContextDelegate = [[ShowSpaceServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)initWithSpace:(nonnull TLSpace *)space {
    
    self.space = space;
    self.spaceId = space.uuid;
}

- (void)getSpace:(nonnull NSUUID *)spaceId {
    DDLogVerbose(@"%@ getSpace spaceId: %@", LOG_TAG, spaceId);
    
    self.work |= GET_SPACE | GET_SPACE_IMAGE;
    self.state &= ~(GET_SPACE | GET_SPACE_DONE | GET_SPACE_IMAGE | GET_SPACE_IMAGE_DONE);
    self.spaceId = spaceId;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateSpace:(nonnull TLSpaceSettings *)spaceSettings {
    DDLogVerbose(@"%@ updateSpace: %@", LOG_TAG, spaceSettings);
    
    self.work |= UPDATE_SPACE;
    self.state &= ~(UPDATE_SPACE | UPDATE_SPACE_DONE);
    self.spaceSettings = spaceSettings;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)setDefaultSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ setDefaultSpace: %@", LOG_TAG, space);
    
    [self.twinmeContext setDefaultSpace:space];
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [super dispose];
}

#pragma mark - Private methods

- (void)onGetSpace:(TLSpace *)space {
    DDLogVerbose(@"%@ onGetSpace space: %@", LOG_TAG, space);
    
    self.state |= GET_SPACE_DONE;
    self.space = space;
    self.spaceId = space.uuid;
    [self onUpdateImage];
    [self runOnGetSpace:space avatar:self.avatar];
    [self onOperation];
}

- (void)onCreateSpace:(TLSpace *)space {
    DDLogVerbose(@"%@ onCreateSpace space: %@", LOG_TAG, space);
        
    if (self.delegate && self.createSpace) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ShowSpaceServiceDelegate>)self.delegate onCreateSpace:space];
        });
    }
}

- (void)onUpdateSpace:(TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpace space: %@", LOG_TAG, space);
    
    if (![space.uuid isEqual:self.spaceId]) {
        return;
    }
    
    self.state |= UPDATE_SPACE_DONE;
    
    self.space = space;
    [self onUpdateImage];
    [self runOnUpdateSpace:self.space];
    [self onOperation];
}

- (void)onDeleteSpace:(NSUUID *)spaceId {
    DDLogVerbose(@"%@ onDeleteSpace spaceId: %@", LOG_TAG, spaceId);
    
    if (![spaceId isEqual:self.spaceId]) {
        return;
    }
    
    [self runOnDeleteSpace:spaceId];
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

- (void)onUpdateSpaceAvatar:(nonnull UIImage *)avatar {
    DDLogVerbose(@"%@ onUpdateSpaceAvatar: %@", LOG_TAG, avatar);
    
    self.state |= GET_SPACE_IMAGE_DONE;
    self.avatar = avatar;
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ShowSpaceServiceDelegate>)self.delegate onUpdateSpaceAvatar:avatar];
        });
    }
    
    [self onOperation];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    // We must get the group object.
    if ((self.work & GET_SPACE) != 0) {
        if ((self.state & GET_SPACE) == 0) {
            self.state |= GET_SPACE;
            
            if (self.space) {
                [self.twinmeContext getSpaceWithSpaceId:self.spaceId withBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
                    [self onGetSpace:space];
                }];
            } else {
                [self.twinmeContext getCurrentSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
                    [self onGetSpace:space];
                }];
            }
            return;
        }
        if ((self.state & GET_SPACE_DONE) == 0) {
            return;
        }
    }
    
    if (self.avatarId) {
        if ((self.work & GET_SPACE_IMAGE) != 0) {
            if ((self.state & GET_SPACE_IMAGE) == 0) {
                self.state |= GET_SPACE_IMAGE;

                TLImageService *imageService = [self.twinmeContext getImageService];
                [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindLarge withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                        [self onUpdateSpaceAvatar:image];
                    }];
                return;
            }
        }
        if ((self.state & GET_SPACE_IMAGE_DONE) == 0) {
            return;
        }
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
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [super onTwinlifeReady];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch (operationId) {
            case GET_SPACE:
                [self runOnGetSpaceNotFound];
                return;
                
            case GET_SPACE_IMAGE:
                [self runOnGetSpace:self.space avatar:self.avatar];
                return;
                
            default:
                break;
        }
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
