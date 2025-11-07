/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Utils/NSString+Utils.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLTwinmeAttributes.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLGroupMember.h>
#import <Twinme/TLProfile.h>
#import <Twinme/TLSpace.h>
#import <Twinme/TLCallReceiver.h>
#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeOutboundService.h>

#import "AbstractTwinmeService.h"
#import "AbstractTwinmeService+Protected.h"

#import "NotificationErrorView.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: AbstractTwinmeServiceTwinmeContextDelegate
//

@implementation ServicesAssertPoint

TL_CREATE_ASSERT_POINT(UNKNOWN_ERROR, 4000)
TL_CREATE_ASSERT_POINT(PARAMETER, 4001)
TL_CREATE_ASSERT_POINT(INVALID_TWINCODE, 4002)
TL_CREATE_ASSERT_POINT(INVALID_CONVERSATION_ID, 4003)

@end

//
// Implementation: AbstractTwinmeServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"AbstractTwinmeServiceTwinmeContextDelegate"

@implementation AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull AbstractTwinmeService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);

    [self.service onTwinlifeReady];
    [self.service onOperation];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    [self.service onTwinlifeOnline];
    [self.service onOperation];
}

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus {
    DDLogVerbose(@"%@ onConnectionStatusChange: %d", LOG_TAG, connectionStatus);
    
    [self.service onConnectionStatusChange:connectionStatus];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    NSNumber *operationId;
    @synchronized(self.service.requestIds) {
        operationId = self.service.requestIds[lRequestId];
        if (operationId == nil) {
            return;
        }
        [self.service.requestIds removeObjectForKey:lRequestId];
    }
    [self.service onErrorWithOperationId:operationId.intValue errorCode:errorCode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Implementation: AbstractTwinmeService
//

#undef LOG_TAG
#define LOG_TAG @"AbstractTwinmeService"

@implementation AbstractTwinmeService

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext tag:(nonnull NSString *)tag delegate:(id<AbstractTwinmeDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ tag: %@ delegate: %@", LOG_TAG, tag, twinmeContext, delegate);
    
    TWINLIFE_CHECK_MAIN_THREAD("Service must be called from main UI thread!");
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;
        _delegate = delegate;
        _tag = tag;
        
        _connected = [_twinmeContext isConnected];
        
        _isTwinlifeReady = NO;
        _state = 0;
        _requestIds = [[NSMutableDictionary alloc] init];
        _restarted = NO;
    }
    return self;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    TWINLIFE_CHECK_MAIN_THREAD("Service must be called from main UI thread!");

    if (self.twinmeContextDelegate) {
        [self.twinmeContext removeDelegate:self.twinmeContextDelegate];
        self.twinmeContextDelegate = nil;
    }
    self.delegate = nil;
}

- (void)showProgressIndicator {
    DDLogVerbose(@"%@ showProgressIndicator", LOG_TAG);
    
    TWINLIFE_CHECK_MAIN_THREAD("Service must be called from main UI thread!");

    if (self.delegate) {
        [self.delegate showProgressIndicator];
    }
}

- (void)hideProgressIndicator {
    DDLogVerbose(@"%@ hideProgressIndicator", LOG_TAG);

    // It can be called from twinlife executor thread but also from main UI thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate) {
            [self.delegate hideProgressIndicator];
        }
    });
}

- (void)getImageWithImageId:(nullable TLImageId *)imageId defaultImage:(nonnull UIImage *)defaultImage withBlock:(nonnull void (^)(UIImage *_Nonnull image))block {
    DDLogVerbose(@"%@ getImageWithImageId: %@", LOG_TAG, imageId);
    
    TWINLIFE_CHECK_MAIN_THREAD("getImageWithImageId:defaultImage:withBlock must be called from main UI thread!");

    if (!imageId) {
        block(defaultImage);
        return;
    }

    // Look in the image cache only and not in the database to avoid blocking the main UI thread.
    TLImageService *imageService = [self.twinmeContext getImageService];
    UIImage *image = [imageService getCachedImageIfPresentWithImageId:imageId kind:TLImageServiceKindThumbnail];
    if (image) {
        block(image);
        return;
    }

    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        // Look in the database and put in the image cache.
        UIImage *image = [imageService getCachedImageWithImageId:imageId kind:TLImageServiceKindThumbnail];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image) {
                block(defaultImage);
            } else {
                block(image);
            }
        });
    });
}

- (void)getImageWithContact:(nonnull id<TLOriginator>)originator withBlock:(nonnull void (^)(UIImage *_Nonnull image))block {
    DDLogVerbose(@"%@ getImageWithContact: %@", LOG_TAG, originator);
    
    TWINLIFE_CHECK_MAIN_THREAD("getImageWithContact:withBlock must be called from main UI thread!");

    if (!originator.avatarId) {
        block([TLTwinmeAttributes DEFAULT_AVATAR]);
        return;
    }

    // Look in the image cache only and not in the database to avoid blocking the main UI thread.
    TLImageService *imageService = [self.twinmeContext getImageService];
    UIImage *image = [imageService getCachedImageIfPresentWithImageId:originator.avatarId kind:TLImageServiceKindThumbnail];
    if (image) {
        block(image);
        return;
    }

    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        // Look in the database and put in the image cache.
        UIImage *image = [imageService getCachedImageWithImageId:originator.avatarId kind:TLImageServiceKindThumbnail];
        if (image != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(image);
            });
            return;
        }
        
        [imageService getImageWithImageId:originator.avatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (status == TLBaseServiceErrorCodeSuccess && image) {
                    block(image);
                } else {
                    block([TLTwinmeAttributes DEFAULT_AVATAR]);
                }
            });
        }];
    });
}

- (void)getImageWithCallReceiver:(nonnull TLCallReceiver *)callReceiver withBlock:(nonnull void (^)(UIImage *_Nonnull image))block {
    DDLogVerbose(@"%@ getImageWithCallReceiver: %@", LOG_TAG, callReceiver);

    [self getImageWithImageId:callReceiver.avatarId defaultImage:[TLTwinmeAttributes DEFAULT_AVATAR] withBlock:block];
}

- (void)getIdentityImageWithCallReceiver:(nonnull TLCallReceiver *)callReceiver withBlock:(nonnull void (^)(UIImage *_Nonnull image))block {
    DDLogVerbose(@"%@ getIdentityImageWithCallReceiver: %@", LOG_TAG, callReceiver);
    
    [self getImageWithImageId:callReceiver.identityAvatarId defaultImage:[TLTwinmeAttributes DEFAULT_AVATAR] withBlock:block];
}

- (void)getIdentityImageWithContact:(nonnull id<TLOriginator>)originator withBlock:(nonnull void (^)(UIImage *_Nonnull image))block {
    DDLogVerbose(@"%@ getIdentityImageWithContact: %@", LOG_TAG, originator);

    [self getImageWithImageId:originator.identityAvatarId defaultImage:[TLTwinmeAttributes DEFAULT_AVATAR] withBlock:block];
}

- (void)getImageWithProfile:(nonnull TLProfile *)profile withBlock:(nonnull void (^)(UIImage *_Nonnull image))block {
    DDLogVerbose(@"%@ getImageWithProfile: %@", LOG_TAG, profile);
    
    [self getImageWithImageId:profile.avatarId defaultImage:[TLTwinmeAttributes DEFAULT_AVATAR] withBlock:block];
}

- (void)getImageWithGroup:(nonnull TLGroup *)group withBlock:(nonnull void (^)(UIImage *_Nonnull image))block {
    DDLogVerbose(@"%@ getImageWithGroup: %@", LOG_TAG, group);
    
    [self getImageWithImageId:group.groupAvatarId defaultImage:[TLTwinmeAttributes DEFAULT_GROUP_AVATAR] withBlock:block];
}

- (void)getImageWithGroupMember:(nonnull TLGroupMember *)groupMember withBlock:(nonnull void (^)(UIImage *_Nonnull image))block {
    DDLogVerbose(@"%@ getImageWithGroupMember: %@", LOG_TAG, groupMember);
    
    [self getImageWithImageId:groupMember.memberAvatarId defaultImage:[TLTwinmeAttributes DEFAULT_AVATAR] withBlock:block];
}

- (void)getIdentityImageWithGroup:(nonnull TLGroup *)group withBlock:(nonnull void (^)(UIImage *_Nonnull image))block {
    DDLogVerbose(@"%@ getIdentityImageWithGroup: %@", LOG_TAG, group);
    
    [self getImageWithImageId:group.identityAvatarId defaultImage:[TLTwinmeAttributes DEFAULT_AVATAR] withBlock:block];
}

- (void)getImageWithImageId:(nonnull TLImageId *)imageId withBlock:(nonnull void (^)(UIImage *_Nonnull image))block {
    DDLogVerbose(@"%@ getIdentityImageWithImageId: %@", LOG_TAG, imageId);
    
    [self getImageWithImageId:imageId defaultImage:[TLTwinmeAttributes DEFAULT_AVATAR] withBlock:block];
}

- (void)getImageWithSpace:(nonnull TLSpace *)space withBlock:(nonnull void (^)(UIImage *_Nonnull image))block {
    DDLogVerbose(@"%@ getImageWithSpace: %@", LOG_TAG, space);
    
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        NSUUID *imageId = space.avatarId;
        if (imageId) {
            TLImageService *imageService = [self.twinmeContext getImageService];
            TLExportedImageId *exportedImageId = [imageService imageWithPublicId:imageId];
            if (exportedImageId) {
                UIImage *image = [imageService getCachedImageWithImageId:exportedImageId kind:TLImageServiceKindThumbnail];
                if (image) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        block(image);
                    });
                    return;
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            block([TLTwinmeAttributes DEFAULT_AVATAR]);
        });
    });
}

- (nonnull UIImage *)getImageWithImageId:(nullable TLImageId *)imageId defaultImage:(nonnull UIImage *)defaultImage {
    DDLogVerbose(@"%@ getImageWithImageId: %@", LOG_TAG, imageId);
    
    TWINLIFE_CHECK_THREAD("Must not run on main UI thread");

    if (!imageId) {
        return defaultImage;
    }
    
    // Look in the image cache and load from database: we are running from twinlife executor and could
    // block while reading the database.
    TLImageService *imageService = [self.twinmeContext getImageService];
    UIImage *image = [imageService getCachedImageWithImageId:imageId kind:TLImageServiceKindThumbnail];
    if (!image) {
        return defaultImage;
    }
    
    return image;
}

- (nonnull UIImage *)getImageWithContact:(nonnull id<TLOriginator>)originator {
    DDLogVerbose(@"%@ getImageWithContact: %@", LOG_TAG, originator);
    
    TWINLIFE_CHECK_THREAD("Must not run on main UI thread");

    if (!originator.avatarId) {
        return [TLTwinmeAttributes DEFAULT_AVATAR];
    }
    TLImageService *imageService = [self.twinmeContext getImageService];

    // Look in the image cache and load from database: we are running from twinlife executor and could
    // block while reading the database.    TLImageService *imageService = [self.twinmeContext getImageService];
    UIImage *image = [imageService getCachedImageWithImageId:originator.avatarId kind:TLImageServiceKindThumbnail];
    if (image != nil) {
        return image;
    }
    return [TLTwinmeAttributes DEFAULT_AVATAR];
}

- (nonnull UIImage *)getImageWithGroup:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ getImageWithGroup: %@", LOG_TAG, group);
    
    return [self getImageWithImageId:group.groupAvatarId defaultImage:[TLTwinmeAttributes DEFAULT_GROUP_AVATAR]];
}

- (nonnull UIImage *)getImageWithGroupMember:(nonnull TLGroupMember *)groupMember {
    DDLogVerbose(@"%@ getImageWithGroupMember: %@", LOG_TAG, groupMember);
    
    return [self getImageWithImageId:groupMember.memberAvatarId defaultImage:[TLTwinmeAttributes DEFAULT_AVATAR]];
}

- (nonnull UIImage *)getImageWithTwincode:(nonnull TLTwincodeOutbound *)twincode {
    DDLogVerbose(@"%@ getImageWithTwincode: %@", LOG_TAG, twincode);
    
    return [self getImageWithImageId:twincode.avatarId defaultImage:[TLTwinmeAttributes DEFAULT_AVATAR]];
}

- (void)getConversationImage:(nullable NSUUID *)imageId defaultImage:(nonnull UIImage *)defaultImage withBlock:(nonnull void (^)(UIImage *_Nonnull image))block {
    DDLogVerbose(@"%@ getConversationImage: %@", LOG_TAG, imageId);

    TWINLIFE_CHECK_MAIN_THREAD("getConversationImage:withBlock must be called from main UI thread!");

    if (!imageId) {
        block(defaultImage);
        return;
    }
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        TLImageService *imageService = [self.twinmeContext getImageService];
        TLExportedImageId *exportedImageId = [imageService imageWithPublicId:imageId];
        UIImage *image;
        if (exportedImageId) {
            image = [imageService getCachedImageWithImageId:exportedImageId kind:TLImageServiceKindLarge];
            if (!image) {
                [imageService getImageWithImageId:exportedImageId kind:TLImageServiceKindLarge withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                    if (status != TLBaseServiceErrorCodeSuccess || !image) {
                        image = defaultImage;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        block(image);
                    });
                }];
                return;
            }
        } else {
            image = defaultImage;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            block(image);
        });
    });
}

- (void)getImagesWithOriginators:(nonnull NSArray<id<TLOriginator>> *)list withBlock:(nonnull void (^)(NSMutableArray<UIImage *> *_Nonnull images))block {
    DDLogVerbose(@"%@ getImagesWithOriginators: %@", LOG_TAG, list);

    // Exception to the service implementation (we don't use the onOperation):
    // - get the images from the twinlife queue,
    // - then dispatch the result to the main UI thread
    // We must make a copy of the original list because it could be modified by the caller (ie, the ConversationViewController)
    // while we are iterating and get the images.
    NSArray<id<TLOriginator>> *originators = [[NSArray alloc] initWithArray:list];
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        NSMutableArray<UIImage *> *images = [[NSMutableArray alloc] initWithCapacity:originators.count];
        for (id<TLOriginator> originator in originators) {
            if ([originator isKindOfClass:[TLContact class]]) {
                [images addObject:[self getImageWithContact:(TLContact *)originator]];
            } else if ([originator isKindOfClass:[TLGroupMember class]]) {
                [images addObject:[self getImageWithGroupMember:(TLGroupMember *)originator]];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            block(images);
        });
    });
}

- (void)parseUriWithUri:(nonnull NSURL *)uri withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeURI *_Nullable twincodeUri))block {
    DDLogVerbose(@"%@ parseUriWithUri: %@", LOG_TAG, uri);
    
    dispatch_async(self.twinmeContext.twinlife.twinlifeQueue, ^{
        [[self.twinmeContext getTwincodeOutboundService] parseUriWithUri:uri withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI *uri) {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(errorCode, uri);
            });
        }];
    });
}

- (void)createUriWithKind:(TLTwincodeURIKind)kind twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeURI *_Nullable twincodeUri))block {
    DDLogVerbose(@"%@ createUriWithKind: %ld twincodeOutbound: %@", LOG_TAG, kind, twincodeOutbound);
    
    dispatch_async(self.twinmeContext.twinlife.twinlifeQueue, ^{
        [[self.twinmeContext getTwincodeOutboundService] createURIWithTwincodeKind:kind twincodeOutbound:twincodeOutbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI *uri) {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(errorCode, uri);
            });
        }];
    });
}

# pragma mark Delegate runners

- (void)runOnSetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ runOnSetCurrentSpace: %@", LOG_TAG, space);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onSetCurrentSpace:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CurrentSpaceTwinmeDelegate>)delegate onSetCurrentSpace:space];
        });
    }
}

- (void)runOnUpdateSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ runOnUpdateSpace: %@", LOG_TAG, space);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onUpdateSpace:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<SpaceTwinmeDelegate>)delegate onUpdateSpace:space];
        });
    }
}

- (void)runOnDeleteSpace:(nonnull NSUUID *)spaceId {
    DDLogVerbose(@"%@ runOnDeleteSpace: %@", LOG_TAG, spaceId);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onDeleteSpace:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<SpaceTwinmeDelegate>)delegate onDeleteSpace:spaceId];
        });
    }
}

- (void)runOnGetSpace:(nonnull TLSpace *)space avatar:(nullable UIImage *)avatar {
    DDLogVerbose(@"%@ runOnGetSpace: %@", LOG_TAG, space);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onGetSpace:avatar:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<SpaceTwinmeDelegate>)delegate onGetSpace:space avatar:avatar];
        });
    }
}

- (void)runOnGetSpaceNotFound {
    DDLogVerbose(@"%@ runOnGetSpaceNotFound", LOG_TAG);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onGetSpaceNotFound)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<SpaceTwinmeDelegate>)delegate onGetSpaceNotFound];
        });
    }
}

- (void)runOnUpdateContact:(nonnull TLContact *)contact avatar:(nullable UIImage *)avatar {
    DDLogVerbose(@"%@ runOnUpdateContact: %@", LOG_TAG, contact);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onUpdateContact:avatar:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ContactTwinmeDelegate>)delegate onUpdateContact:contact avatar:avatar];
        });
    }
}

- (void)runOnRefreshContactAvatar:(nullable UIImage *)avatar {
    DDLogVerbose(@"%@ runOnRefreshContactAvatar: %@", LOG_TAG, avatar);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onRefreshContactAvatar:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ContactTwinmeDelegate>)delegate onRefreshContactAvatar:avatar];
        });
    }
}

- (void)runOnDeleteContact:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ runOnDeleteContact: %@", LOG_TAG, contactId);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onDeleteContact:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ContactTwinmeDelegate>)delegate onDeleteContact:contactId];
        });
    }
}

- (void)runOnGetContacts:(nonnull NSArray<TLContact *> *)contacts {
    DDLogVerbose(@"%@ runOnGetContacts: %@", LOG_TAG, contacts);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onGetContacts:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ContactListTwinmeDelegate>)delegate onGetContacts:contacts];
        });
    }
}

- (void)runOnGetGroups:(nonnull NSArray<TLGroup *> *)groups {
    DDLogVerbose(@"%@ runOnGetGroups: %@", LOG_TAG, groups);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onGetGroups:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupListTwinmeDelegate>)delegate onGetGroups:groups];
        });
    }
}

- (void)runOnGetSpaces:(nonnull NSArray<TLSpace *> *)spaces {
    DDLogVerbose(@"%@ runOnGetSpaces: %@", LOG_TAG, spaces);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onGetSpaces:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<SpaceListTwinmeDelegate>)delegate onGetSpaces:spaces];
        });
    }
}

- (void)runOnUpdateGroup:(nonnull TLGroup *)group avatar:(nullable UIImage *)avatar {
    DDLogVerbose(@"%@ runOnUpdateGroup: %@", LOG_TAG, group);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onUpdateGroup:avatar:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupTwinmeDelegate>)delegate onUpdateGroup:group avatar:avatar];
        });
    }
}

- (void)runOnDeleteGroup:(nonnull NSUUID *)groupId {
    DDLogVerbose(@"%@ runOnDeleteGroup: %@", LOG_TAG, groupId);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onDeleteGroup:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupTwinmeDelegate>)delegate onDeleteGroup:groupId];
        });
    }
}

- (void)runOnGetTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincode avatar:(nullable UIImage *)avatar {
    DDLogVerbose(@"%@ runOnGetTwincodeWithTwincode: %@", LOG_TAG, twincode);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onGetTwincodeWithTwincode:avatar:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<TwincodeTwinmeDelegate>)delegate onGetTwincodeWithTwincode:twincode avatar:avatar];
        });
    }
}

- (void)runOnGetTwincodeNotFound {
    DDLogVerbose(@"%@ runOnGetTwincodeNotFound", LOG_TAG);

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onGetTwincodeNotFound)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<TwincodeTwinmeDelegate>)delegate onGetTwincodeNotFound];
        });
    }
}

#pragma mark - Private methods

- (int64_t)newOperation:(int)operationId {
    DDLogVerbose(@"%@ newOperation: %d", LOG_TAG, operationId);
    
    int64_t requestId = [self.twinmeContext newRequestId];
    @synchronized (self.requestIds) {
        self.requestIds[[NSNumber numberWithLongLong:requestId]] = [NSNumber numberWithInt:operationId];
    }
    return requestId;
}

- (int)getOperation:(int64_t)requestId {
    DDLogVerbose(@"%@ getOperation: %lld", LOG_TAG, requestId);
    
    TWINLIFE_CHECK_THREAD("Must not run on main UI thread");

    NSNumber *operationId;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized(self.requestIds) {
        operationId = self.requestIds[lRequestId];
        if (operationId != nil) {
            [self.requestIds removeObjectForKey:lRequestId];
        }
    }
    return operationId == nil ? 0 : operationId.intValue;
}

- (void)startOperation {
    DDLogVerbose(@"%@ startOperation", LOG_TAG);
    
    TWINLIFE_CHECK_MAIN_THREAD("Must run from main UI thread");

    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        [self onOperation];
    });
}

- (void)finishOperation:(int64_t)requestId {
    DDLogVerbose(@"%@ finishOperation: %lld", LOG_TAG, requestId);
    
    TWINLIFE_CHECK_THREAD("Must not run on main UI thread");

    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized(self.requestIds) {
        [self.requestIds removeObjectForKey:lRequestId];
    }
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    TWINLIFE_CHECK_THREAD("Must not run on main UI thread");

    if (!self.isTwinlifeReady) {
        return;
    }
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    TWINLIFE_CHECK_THREAD("Must not run on main UI thread");

    self.isTwinlifeReady = YES;

    // Trigger the onConnectionStatusChange() observer if we are not connected.
    if (!self.connected) {
        [self onConnectionStatusChange:[self.twinmeContext connectionStatus]];
    }
    [self.twinmeContext connect];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    TWINLIFE_CHECK_THREAD("Must not run on main UI thread");

    if (self.restarted) {
        self.restarted = NO;
    }
}

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus {
    DDLogVerbose(@"%@ onConnectionStatusChange: %d", LOG_TAG, connectionStatus);
    
    TWINLIFE_CHECK_THREAD("Must not run on main UI thread");

    if (connectionStatus == TLConnectionStatusConnected) {
        if (!self.connected) {
            self.connected = YES;
            if ([(id)self.delegate respondsToSelector:@selector(onConnectionStatusChange:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate onConnectionStatusChange:connectionStatus];
                });
            }
        }
    } else {
        self.connected = NO;
        if ([(id)self.delegate respondsToSelector:@selector(onConnectionStatusChange:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate onConnectionStatusChange:connectionStatus];
            });
        }
    }
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    TWINLIFE_CHECK_THREAD("Must not run on main UI thread");

    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            NotificationErrorView *notificationView = [[NotificationErrorView alloc] initWithErrorCode:errorCode];
            [notificationView showInView:[[[UIApplication sharedApplication] delegate] window]];
            [self.delegate hideProgressIndicator];
        });
        return;
    }
}

@end
