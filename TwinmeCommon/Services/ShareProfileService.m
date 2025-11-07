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
#import <Twinme/TLSpace.h>
#import <Twinlife/TLTwincodeOutboundService.h>

#import "ShareProfileService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_CURRENT_SPACE = 1 << 0;
static const int GET_CURRENT_SPACE_DONE = 1 << 1;
static const int CHANGE_PROFILE_TWINCODE = 1 << 2;
static const int CHANGE_PROFILE_TWINCODE_DONE = 1 << 3;
static const int CREATE_PRIVATE_KEY = 1 << 10;
static const int CREATE_PRIVATE_KEY_DONE = 1 << 11;
static const int GET_INVITATION_LINK = 1 << 12;
static const int GET_INVITATION_LINK_DONE = 1 << 13;

//
// Interface: ShareProfileService ()
//

@class ShareProfileServiceTwinmeContextDelegate;

@interface ShareProfileService ()

@property (nonatomic, nullable) TLProfile *profile;
@property (nonatomic, nullable) TLTwincodeOutbound *twincodeOutbound;
@property (nonatomic, nullable) TLTwincodeInbound *twincodeInbound;
@property (nonatomic, nullable) NSString *name;
@property (nonatomic, nullable) UIImage *avatar;
@property (nonatomic) int work;
@property (nonatomic, nullable) TLSpace *currentSpace;

- (void)onOperation;

- (void)onGetCurrentSpace:(nullable TLSpace *)space;

- (void)onChangeProfileTwincode:(nonnull TLProfile *)profile;

- (void)onCreateContact:(nonnull TLContact *)contact;

@end

//
// Interface: ShareProfileServiceTwinmeContextDelegate
//

@interface ShareProfileServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ShareProfileService *)service;

@end

//
// Implementation: ShareProfileServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ShareProfileServiceTwinmeContextDelegate"

@implementation ShareProfileServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ShareProfileService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onCreateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onCreateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);

    [(ShareProfileService *)self.service onCreateContact:contact];
}

- (void)onChangeProfileTwincodeWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ onChangeProfileTwincodeWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(ShareProfileService *)self.service onChangeProfileTwincode:profile];
}

@end

//
// Implementation: ShareProfileService
//

#undef LOG_TAG
#define LOG_TAG @"ShareProfileService"

@implementation ShareProfileService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<ShareProfileServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[ShareProfileServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)changeProfileTwincode:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ changeProfileTwincode: %@", LOG_TAG, profile);
    
    self.profile = profile;
    
    self.work = CHANGE_PROFILE_TWINCODE;
    self.state &= ~(CHANGE_PROFILE_TWINCODE | CHANGE_PROFILE_TWINCODE_DONE);
    [self showProgressIndicator];
    [self startOperation];
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

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        self.restarted = NO;
        
        if (((self.state & CREATE_PRIVATE_KEY) != 0) && ((self.state & CREATE_PRIVATE_KEY_DONE) == 0)) {
            self.state &= ~CREATE_PRIVATE_KEY;
        }
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
        
        [self.twinmeContext getCurrentSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
            [self onGetCurrentSpace:space];
        }];
        return;
    }
    
    if ((self.state & GET_CURRENT_SPACE_DONE) == 0) {
        return;
    }
    
    //
    // We must change the current profile twincode.
    //
    if (self.profile && (self.work & CHANGE_PROFILE_TWINCODE) != 0) {
        if ((self.state & CHANGE_PROFILE_TWINCODE) == 0) {
            self.state |= CHANGE_PROFILE_TWINCODE;
            
            int64_t requestId = [self newOperation:CHANGE_PROFILE_TWINCODE];
            DDLogVerbose(@"%@ changeProfileTwincodeWithRequestId: %lld profile: %@", LOG_TAG, requestId, self.profile);
            
            [self.twinmeContext changeProfileTwincodeWithRequestId:requestId profile:self.profile];
            return;
        }
        
        if ((self.state & CHANGE_PROFILE_TWINCODE_DONE) == 0) {
            return;
        }
    }
    
    if (self.twincodeInbound && ((self.work & CREATE_PRIVATE_KEY) != 0)) {
        if ((self.state & CREATE_PRIVATE_KEY) == 0) {
            self.state |= CREATE_PRIVATE_KEY;
            [[self.twinmeContext getTwincodeOutboundService] createPrivateKeyWithTwincode:self.twincodeInbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onCreatePrivateKey:errorCode twincodeOutbound:twincodeOutbound];
            }];
            return;
        }
        if ((self.state & CREATE_PRIVATE_KEY_DONE) == 0) {
            return;
        }
    }

    if (self.twincodeOutbound && ((self.work & GET_INVITATION_LINK) != 0)) {
        if ((self.state & GET_INVITATION_LINK) == 0) {
            self.state |= GET_INVITATION_LINK;
            [[self.twinmeContext getTwincodeOutboundService] createURIWithTwincodeKind:TLTwincodeURIKindInvitation twincodeOutbound:self.twincodeOutbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI *uri) {
                [self onCreateURI:errorCode uri:uri];
            }];
            return;
        }
        if ((self.state & GET_INVITATION_LINK_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step: everything done, we can hide the progress indicator.
    //
    
    [self hideProgressIndicator];
}

- (void)onGetCurrentSpace:(nullable TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    self.state |= GET_CURRENT_SPACE_DONE;
    
    self.currentSpace = space;
    if (space && space.profile) {
        self.profile = space.profile;
        self.twincodeOutbound = self.profile.twincodeOutbound;
        if (self.twincodeOutbound && ![self.twincodeOutbound isSigned]) {
            self.twincodeInbound = self.profile.twincodeInbound;
            self.work |= CREATE_PRIVATE_KEY;
            self.state &= ~(CREATE_PRIVATE_KEY | CREATE_PRIVATE_KEY_DONE);
        }
        self.work |= GET_INVITATION_LINK;
        self.state &= ~(GET_INVITATION_LINK | GET_INVITATION_LINK_DONE);
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ShareProfileServiceDelegate>)self.delegate onGetDefaultProfile:space.profile];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ShareProfileServiceDelegate>)self.delegate onGetDefaultProfileNotFound];
        });
    }
    [self onOperation];
}

- (void)onCreateContact:(TLContact *)contact {
    DDLogVerbose(@"%@ onCreateContact: %@", LOG_TAG, contact);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ShareProfileServiceDelegate>)self.delegate onCreateContact:contact];
    });
}

- (void)onChangeProfileTwincode:(TLProfile *)profile {
    DDLogVerbose(@"%@ onChangeProfileTwincode: %@", LOG_TAG, profile);
    
    self.state |= CHANGE_PROFILE_TWINCODE_DONE;
    self.twincodeOutbound = profile.twincodeOutbound;
    if (self.twincodeOutbound) {
        self.work |= GET_INVITATION_LINK;
        self.state &= ~(GET_INVITATION_LINK | GET_INVITATION_LINK_DONE);
    }
    [self onOperation];
}

- (void)onCreateURI:(TLBaseServiceErrorCode)errorCode uri:(nullable TLTwincodeURI *)uri {
    DDLogVerbose(@"%@ onCreateURI: %d uri: %@", LOG_TAG, errorCode, uri);

    self.state |= GET_INVITATION_LINK_DONE;
    if (uri) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ShareProfileServiceDelegate>)self.delegate onGetTwincodeURI:uri];
        });
    }
    [self onOperation];
}

- (void)onCreatePrivateKey:(TLBaseServiceErrorCode)errorCode twincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@ onCreatePrivateKey: %d twincodeOutbound: %@", LOG_TAG, errorCode, twincodeOutbound);

    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }

    self.state |= CREATE_PRIVATE_KEY_DONE;
    [self onOperation];
}

@end
