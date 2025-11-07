/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLAccountService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLImageService.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLTwinmeAttributes.h>

#import "InvitationSubscriptionService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_TWINCODE = 1 << 0;
static const int GET_TWINCODE_DONE = 1 << 1;
static const int GET_TWINCODE_IMAGE = 1 << 2;
static const int GET_TWINCODE_IMAGE_DONE = 1 << 3;
static const int SUBSCRIBE_FEATURE = 1 << 4;
static const int SUBSCRIBE_FEATURE_DONE = 1 << 5;

//
// Interface: InvitationSubscriptionService ()
//

@class InvitationSubscriptionServiceTwinmeContextDelegate;
@class InvitationSubscriptionServiceAccountServiceDelegate;

@interface InvitationSubscriptionService ()

@property (nonatomic, nullable) NSUUID *twincodeOutboundId;
@property (nonatomic, nullable) TLTwincodeOutbound *twincodeOutbound;
@property (nonatomic, nullable) TLImageId *twincodeAvatarId;
@property (nonatomic, nullable) NSString *activationCode;
@property (nonatomic, nullable) NSString *twincodeId;
@property (nonatomic, nullable) NSString *profileTwincodeOutboundId;

@property (nonatomic) int work;

@property (nonatomic) InvitationSubscriptionServiceAccountServiceDelegate *accountServiceDelegate;

- (void)onOperation;

- (void)onGetTwincode:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onSubscribeUpdate:(TLBaseServiceErrorCode)errorCode done:(int)done;

@end

//
// Interface: InvitationSubscriptionServiceTwinmeContextDelegate
//

@interface InvitationSubscriptionServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (instancetype)initWithService:(InvitationSubscriptionService *)service;

@end

//
// Implementation: InvitationSubscriptionServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"InvitationSubscriptionServiceTwinmeContextDelegate"

@implementation InvitationSubscriptionServiceTwinmeContextDelegate

- (instancetype)initWithService:(InvitationSubscriptionService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

@end

//
// Interface: InvitationSubscriptionServiceAccountServiceDelegate
//

@interface InvitationSubscriptionServiceAccountServiceDelegate : NSObject <TLAccountServiceDelegate>

@property (weak) InvitationSubscriptionService *service;

- (instancetype)initWithService:(InvitationSubscriptionService *)service;

@end

//
// Implementation: InvitationSubscriptionServiceAccountServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"InvitationSubscriptionServiceAccountServiceDelegate"

@implementation InvitationSubscriptionServiceAccountServiceDelegate

- (instancetype)initWithService:(InvitationSubscriptionService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onSubscribeUpdateWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onSubscribeUpdateWithRequestId: %lld  errorCode: %d", LOG_TAG, requestId, errorCode);

    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [self.service onSubscribeUpdate:errorCode done:operationId == SUBSCRIBE_FEATURE_DONE];
}

@end

//
// Implementation: InvitationSubscriptionService
//

#undef LOG_TAG
#define LOG_TAG @"InvitationSubscriptionService"

@implementation InvitationSubscriptionService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <InvitationSubscriptionServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _accountServiceDelegate = [[InvitationSubscriptionServiceAccountServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[InvitationSubscriptionServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getAccountService] addDelegate:self.accountServiceDelegate];
    [super onTwinlifeReady];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        self.restarted = NO;
        
        if (((self.state & GET_TWINCODE) != 0 ) && ((self.state & GET_TWINCODE_DONE) == 0)) {
            self.state &= ~GET_TWINCODE;
        }
        if (((self.state & GET_TWINCODE_IMAGE) != 0 ) && ((self.state & GET_TWINCODE_IMAGE_DONE) == 0)) {
            self.state &= ~GET_TWINCODE_IMAGE;
        }
        
        if (((self.state & SUBSCRIBE_FEATURE) != 0 ) && ((self.state & SUBSCRIBE_FEATURE_DONE) == 0)) {
            self.state &= ~SUBSCRIBE_FEATURE;
        }
    }
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getAccountService] removeDelegate:self.accountServiceDelegate];
    [super dispose];
}

- (void)getTwincodeOutboundWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId {
    DDLogVerbose(@"%@ setUrl: %@", LOG_TAG, twincodeOutboundId);
    
    self.twincodeOutboundId = twincodeOutboundId;
    self.state &= ~(GET_TWINCODE | GET_TWINCODE_DONE | GET_TWINCODE_IMAGE | GET_TWINCODE_DONE);
    [self showProgressIndicator];
    [self startOperation]; // Wait for reconnection
}

- (void)subscribeFeature:(nonnull NSString*)twincodeId activationCode:(nonnull NSString *)activationCode profileTwincodeOutboundId:(nonnull NSString *)profileTwincodeOutboundId {
    DDLogVerbose(@"%@ subscribeFeature: %@ activationCode: %@ profileTwincodeOutboundId: %@", LOG_TAG, twincodeId, activationCode, profileTwincodeOutboundId);
    
    self.twincodeId = twincodeId;
    self.activationCode = activationCode;
    self.profileTwincodeOutboundId = profileTwincodeOutboundId;

    self.work |= SUBSCRIBE_FEATURE;
    self.state &= ~(SUBSCRIBE_FEATURE | SUBSCRIBE_FEATURE_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

#pragma mark - Private methods

- (void)onSubscribeUpdate:(TLBaseServiceErrorCode)errorCode done:(int)done {
    DDLogVerbose(@"%@ onSubscribeUpdate: %d operationMask: %d", LOG_TAG, errorCode, done);
    
    // When we are offline or failed to send the request, we must retry.
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {

        self.restarted = YES;
        return;
    }

    self.state |= done;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (errorCode == TLBaseServiceErrorCodeSuccess) {
            [(id<InvitationSubscriptionServiceDelegate>)self.delegate onSubscribeSuccess];
        } else {
            [(id<InvitationSubscriptionServiceDelegate>)self.delegate onSubscribeFailed:errorCode];
        }
    });
    [self onOperation];
}

- (void)onGetTwincode:(TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetTwincode: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);

    self.state |= GET_TWINCODE_DONE;
    if (twincodeOutbound) {
        TL_ASSERT_EQUAL(self.twinmeContext, twincodeOutbound.uuid, self.twincodeOutboundId, [ServicesAssertPoint INVALID_TWINCODE], TLAssertionParameterTwincodeId, [TLAssertValue initWithTwincodeOutbound:twincodeOutbound], nil);

        self.twincodeOutbound = twincodeOutbound;
        
        self.twincodeAvatarId = twincodeOutbound.avatarId;
        [self runOnGetTwincodeWithTwincode:twincodeOutbound avatar:nil];
    } else if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        [self runOnGetTwincodeNotFound];
    } else {
        [self onErrorWithOperationId:GET_TWINCODE errorCode:errorCode errorParameter:self.twincodeOutboundId.UUIDString];
    }
    [self onOperation];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    if (self.twincodeOutboundId) {
        
        if ((self.state & GET_TWINCODE) == 0) {
            self.state |= GET_TWINCODE;
            
            [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.twincodeOutboundId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onGetTwincode:twincodeOutbound errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & GET_TWINCODE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 3: get the twincode avatar image.
    //
    if (self.twincodeAvatarId) {
        if ((self.state & GET_TWINCODE_IMAGE) == 0) {
            self.state |= GET_TWINCODE_IMAGE;
            
            DDLogVerbose(@"%@ getImageWithImageId: %@", LOG_TAG, self.twincodeAvatarId);
            [[self.twinmeContext getImageService] getImageWithImageId:self.twincodeAvatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                if (errorCode == TLBaseServiceErrorCodeSuccess && image) {
                    [self runOnGetTwincodeWithTwincode:self.twincodeOutbound avatar:image];
                }
                self.state |= GET_TWINCODE_IMAGE_DONE;
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_TWINCODE_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & SUBSCRIBE_FEATURE) != 0) {
        if ((self.state & SUBSCRIBE_FEATURE) == 0) {
            self.state |= SUBSCRIBE_FEATURE;
            
            int64_t requestId = [self newOperation:SUBSCRIBE_FEATURE];
            [[self.twinmeContext getAccountService] subscribeFeatureWithRequestId:requestId merchantId:TLMerchantIdentificationTypeExternal purchaseProductId:self.twincodeId purchaseToken:self.activationCode purchaseOrderId:self.profileTwincodeOutboundId];
            return;
        }
        if ((self.state & SUBSCRIBE_FEATURE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

@end
