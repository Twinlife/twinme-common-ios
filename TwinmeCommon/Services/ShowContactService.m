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

#import <Twinlife/TLImageService.h>
#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLContact.h>

#import "ShowContactService.h"
#import "AbstractTwinmeService+Protected.h"

static const int GET_CONTACT_THUMBNAIL_IMAGE = 1 << 0;
static const int GET_CONTACT_THUMBNAIL_IMAGE_DONE = 1 << 1;
static const int GET_CONTACT_IMAGE = 1 << 2;
static const int GET_CONTACT_IMAGE_DONE = 1 << 3;
static const int DELETE_CONTACT = 1 << 4;
static const int DELETE_CONTACT_DONE = 1 << 5;

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: ShowContactService ()
//

@class ShowContactServiceTwinmeContextDelegate;

@interface ShowContactService ()

@property (nonatomic, nullable) TLImageId *avatarId;
@property (nonatomic, nullable) UIImage *avatar;

- (void)onOperation;

- (void)onUpdateContact:(nonnull TLContact *)contact;

- (void)onDeleteContact:(nonnull NSUUID *)contactId;

@end

//
// Interface: ShowContactServiceTwinmeContextDelegate
//

@interface ShowContactServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ShowContactService *)service;

@end

//
// Implementation: ShowContactServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ShowContactServiceTwinmeContextDelegate"

@implementation ShowContactServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ShowContactService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    [(ShowContactService *)self.service onUpdateContact:contact];
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact oldSpace:(nonnull TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld contact: %@ oldSpace: %@", LOG_TAG, requestId, contact, oldSpace);
    
    [(ShowContactService *)self.service onUpdateContact:contact];
}

- (void)onDeleteContactWithRequestId:(int64_t)requestId contactId:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contactId);
    
    [self.service finishOperation:requestId];

    [(ShowContactService *)self.service onDeleteContact:contactId];
}

@end

//
// Implementation: ShowContactService
//

#undef LOG_TAG
#define LOG_TAG @"ShowContactService"

@implementation ShowContactService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<ShowContactServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _work = 0;
        self.twinmeContextDelegate = [[ShowContactServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)initWithContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ initWithContact: %@", LOG_TAG, contact);
    
    self.contact = contact;
    self.avatarId = contact.avatarId;
    self.state = 0;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)deleteContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ deleteContact: %@", LOG_TAG, contact);
    
    self.contact = contact;
    self.work |= DELETE_CONTACT;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)createAuthenticateURIWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeURI *_Nullable twincodeUri))block {
    DDLogVerbose(@"%@ createAuthenticateURIWithBlock: %@", LOG_TAG, self.contact);

    if (self.contact && self.contact.twincodeOutbound) {
        [self createUriWithKind:TLTwincodeURIKindAuthenticate twincodeOutbound:self.contact.twincodeOutbound withBlock:block];
    } else {
        block(TLBaseServiceErrorCodeItemNotFound, nil);
    }
}

- (void)verifyAuthenticateWithURI:(nonnull NSURL *)uri withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLContact *_Nullable contact))block {
    DDLogVerbose(@"%@ verifyAuthenticateWithURI: %@", LOG_TAG, uri);

    [self parseUriWithUri:uri withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI *twincodeURI) {
        if (errorCode != TLBaseServiceErrorCodeSuccess) {
            block(errorCode, nil);
        } else {
            [self.twinmeContext verifyContactWithUri:twincodeURI trustMethod:TLTrustMethodQrCode withBlock:^(TLBaseServiceErrorCode errorCode, TLContact *contact) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    block(errorCode, contact);
                });
            }];
        }
    }];
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    //
    // Step 1: Get the contact thumbnail image if we can.
    //
    if (self.avatarId && !self.avatar) {
        if ((self.state & GET_CONTACT_THUMBNAIL_IMAGE) == 0) {
            self.state |= GET_CONTACT_THUMBNAIL_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                self.state |= GET_CONTACT_THUMBNAIL_IMAGE_DONE;
                if (status == TLBaseServiceErrorCodeSuccess && image) {
                    self.avatar = image;
                } else {
                    image = [TLContact ANONYMOUS_AVATAR];
                }
                [self runOnRefreshContactAvatar:image];
                [self onOperation];
            }];
            return;
        }
        
        if ((self.state & GET_CONTACT_THUMBNAIL_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 2: Get the contact large image if we can.
    //
    if (self.avatarId) {
        if ((self.state & GET_CONTACT_IMAGE) == 0) {
            self.state |= GET_CONTACT_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindNormal withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                self.state |= GET_CONTACT_IMAGE_DONE;
                if (status == TLBaseServiceErrorCodeSuccess && image) {
                    self.avatar = image;
                    [self runOnRefreshContactAvatar:image];
                }
                [self onOperation];
            }];
            return;
        }
        
        if ((self.state & GET_CONTACT_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Work step: delete the contact.
    //
    if (self.contact && (self.work & DELETE_CONTACT) != 0) {
        if ((self.state & DELETE_CONTACT) == 0) {
            self.state |= DELETE_CONTACT;

            int64_t requestId = [self newOperation:DELETE_CONTACT];
            DDLogVerbose(@"%@ deleteContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, self.contact);
            [self.twinmeContext deleteContactWithRequestId:requestId contact:self.contact];
            return;
        }
        
        if ((self.state & DELETE_CONTACT_DONE) == 0) {
            return;
        }
    }

    [self hideProgressIndicator];
}

- (void)onUpdateContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContact: %@", LOG_TAG, contact);
    
    if (![contact.uuid isEqual:self.contact.uuid]) {
        return;
    }
    
    self.contact = contact;

    // Check if the image was modified.
    if ((!self.avatarId && contact.avatarId) || (self.avatarId && [self.avatarId isEqual:contact.avatarId])) {
        self.avatarId = contact.avatarId;
        self.avatar = [self getImageWithContact:contact];
        self.state &= ~(GET_CONTACT_THUMBNAIL_IMAGE | GET_CONTACT_THUMBNAIL_IMAGE_DONE | GET_CONTACT_IMAGE | GET_CONTACT_IMAGE_DONE);
    }
    [self runOnUpdateContact:contact avatar:self.avatar];
}

- (void)onDeleteContact:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContact: %@", LOG_TAG, contactId);
    
    if (![contactId isEqual:self.contact.uuid]) {
        return;
    }
    
    self.state |= DELETE_CONTACT_DONE;
    [self runOnDeleteContact:contactId];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    if (operationId == DELETE_CONTACT && errorCode == TLBaseServiceErrorCodeItemNotFound) {
        [self onDeleteContact:self.contact.uuid];
        return;
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
