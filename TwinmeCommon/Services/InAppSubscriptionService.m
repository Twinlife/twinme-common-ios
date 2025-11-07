/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLAccountService.h>
#import <Twinlife/TLTwincodeOutboundService.h>

#import <Twinme/TLTwinmeContext.h>

#import "InAppSubscriptionService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int CANCEL_FEATURE = 1 << 0;
static const int CANCEL_FEATURE_DONE = 1 << 1;
static const int SUBSCRIBE_FEATURE = 1 << 2;
static const int SUBSCRIBE_FEATURE_DONE = 1 << 3;
static const int GET_SUBSCRIPTION_TWINCODE = 1 << 4;
static const int GET_SUBSCRIPTION_TWINCODE_DONE = 1 << 5;
static const int GET_SUBSCRIPTION_IMAGE = 1 << 6;
static const int GET_SUBSCRIPTION_IMAGE_DONE = 1 << 7;

//
// Interface: InAppSubscriptionService ()
//

@class InAppSubscriptionServiceTwinmeContextDelegate;
@class InAppSubscriptionServiceAccountServiceDelegate;

@interface InAppSubscriptionService ()

@property (readonly, nullable) NSUUID *subscriptionTwincodeId;
@property (nullable) TLImageId *subscriptionImageId;
@property (nonatomic, nonnull) NSString *productId;
@property (nonatomic, nonnull) NSString *purchaseToken;
@property (nonatomic, nonnull) NSString *purchaseOrderId;
@property (nonatomic, nullable) TLTwincodeOutbound *subscriptionTwincode;

@property (nonatomic) int work;

@property (nonatomic) InAppSubscriptionServiceAccountServiceDelegate *accountServiceDelegate;

- (void)onOperation;

- (void)onSubscribeUpdate:(TLBaseServiceErrorCode)errorCode done:(int)done;

@end

//
// Interface: InAppSubscriptionServiceTwinmeContextDelegate
//

@interface InAppSubscriptionServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (instancetype)initWithService:(InAppSubscriptionService *)service;

@end

//
// Implementation: InAppSubscriptionServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"InAppSubscriptionServiceTwinmeContextDelegate"

@implementation InAppSubscriptionServiceTwinmeContextDelegate

- (instancetype)initWithService:(InAppSubscriptionService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

@end

//
// Interface: InAppSubscriptionServiceAccountServiceDelegate
//

@interface InAppSubscriptionServiceAccountServiceDelegate : NSObject <TLAccountServiceDelegate>

@property (weak) InAppSubscriptionService *service;

- (instancetype)initWithService:(InAppSubscriptionService *)service;

@end

//
// Implementation: InAppSubscriptionServiceAccountServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"InAppSubscriptionServiceAccountServiceDelegate"

@implementation InAppSubscriptionServiceAccountServiceDelegate

- (instancetype)initWithService:(InAppSubscriptionService *)service {
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
    
    [self.service onSubscribeUpdate:errorCode done:operationId == SUBSCRIBE_FEATURE ? SUBSCRIBE_FEATURE_DONE : CANCEL_FEATURE_DONE];
    [self.service onOperation];
}

@end

//
// Implementation: InAppSubscriptionService
//

#undef LOG_TAG
#define LOG_TAG @"InAppSubscriptionService"

@implementation InAppSubscriptionService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext subscriptionTwincodeId:(nullable NSUUID *)subscriptionTwincodeId delegate:(nonnull id <InAppSubscriptionServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _subscriptionTwincodeId = subscriptionTwincodeId;
        _accountServiceDelegate = [[InAppSubscriptionServiceAccountServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[InAppSubscriptionServiceTwinmeContextDelegate alloc] initWithService:self];
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
        
        if (((self.state & SUBSCRIBE_FEATURE) != 0 ) && ((self.state & SUBSCRIBE_FEATURE_DONE) == 0)) {
            self.state &= ~SUBSCRIBE_FEATURE;
        }
        if (((self.state & CANCEL_FEATURE) != 0 ) && ((self.state & CANCEL_FEATURE_DONE) == 0)) {
            self.state &= ~CANCEL_FEATURE;
        }
        if (((self.state & GET_SUBSCRIPTION_TWINCODE) != 0 ) && ((self.state & GET_SUBSCRIPTION_TWINCODE_DONE) == 0)) {
            self.state &= ~GET_SUBSCRIPTION_TWINCODE;
        }
        if (((self.state & GET_SUBSCRIPTION_IMAGE) != 0 ) && ((self.state & GET_SUBSCRIPTION_IMAGE_DONE) == 0)) {
            self.state &= ~GET_SUBSCRIPTION_IMAGE;
        }
    }
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getAccountService] removeDelegate:self.accountServiceDelegate];
    [super dispose];
}

- (void)subscribeFeature:(nonnull NSString*)productId purchaseToken:(nonnull NSString *)purchaseToken purchaseOrderId:(nonnull NSString *)purchaseOrderId {
    DDLogVerbose(@"%@ subscribeFeature: %@ purchaseToken: %@ purchaseOrderId: %@", LOG_TAG, productId, purchaseToken, purchaseOrderId);
    
    self.productId = productId;
    self.purchaseToken = purchaseToken;
    self.purchaseOrderId = purchaseOrderId;
    
    self.work |= SUBSCRIBE_FEATURE;
    self.state &= ~(SUBSCRIBE_FEATURE | SUBSCRIBE_FEATURE_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)cancelFeature:(nonnull NSString *)purchaseToken {
    DDLogVerbose(@"%@ cancelFeature: %@", LOG_TAG, purchaseToken);
    
    self.purchaseToken = purchaseToken;
    
    self.work |= CANCEL_FEATURE;
    self.state &= ~(CANCEL_FEATURE | CANCEL_FEATURE_DONE);
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
            if ([[self.twinmeContext getAccountService] isFeatureSubscribedWithName:@"group-call"]) {
                [(id<InAppSubscriptionServiceDelegate>)self.delegate onSubscribeSuccess];
            } else {
                [(id<InAppSubscriptionServiceDelegate>)self.delegate onSubscribeCancel];
            }
        } else {
            [(id<InAppSubscriptionServiceDelegate>)self.delegate onSubscribeFailed:errorCode];
        }
    });

    // When we cancel a subscription PRO, remove the twincode and its image from the local cache.
    if (done == CANCEL_FEATURE_DONE && self.subscriptionTwincode) {
        [[self.twinmeContext getTwincodeOutboundService] evictWithTwincode:self.subscriptionTwincode];
    }
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    // If there is a subscription twincode  get that twincode to get the thumbnail and use it if we have it.
    if (self.subscriptionTwincodeId) {
        if ((self.state & GET_SUBSCRIPTION_TWINCODE) == 0) {
            self.state |= GET_SUBSCRIPTION_TWINCODE;
            
            [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.subscriptionTwincodeId refreshPeriod:0 withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onGetTwincode:twincodeOutbound errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & GET_SUBSCRIPTION_TWINCODE_DONE) == 0) {
            return;
        }
    }

    //
    // Optional step to get the subscription image from the server.
    //
    if (self.subscriptionImageId) {
        if ((self.state & GET_SUBSCRIPTION_IMAGE) == 0) {
            self.state |= GET_SUBSCRIPTION_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.subscriptionImageId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                [self onGetImage:image errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & GET_SUBSCRIPTION_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & SUBSCRIBE_FEATURE) != 0) {
        if ((self.state & SUBSCRIBE_FEATURE) == 0) {
            self.state |= SUBSCRIBE_FEATURE;
            
            int64_t requestId = [self newOperation:SUBSCRIBE_FEATURE];
            [[self.twinmeContext getAccountService] subscribeFeatureWithRequestId:requestId merchantId:TLMerchantIdentificationTypeApple purchaseProductId:self.productId purchaseToken:self.purchaseToken purchaseOrderId:self.purchaseOrderId];
            return;
        }
        if ((self.state & SUBSCRIBE_FEATURE_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & CANCEL_FEATURE) != 0) {
        if ((self.state & CANCEL_FEATURE) == 0) {
            self.state |= CANCEL_FEATURE;
            
            int64_t requestId = [self newOperation:CANCEL_FEATURE];
            [[self.twinmeContext getAccountService] cancelFeatureWithRequestId:requestId merchantId:TLMerchantIdentificationTypeExternal purchaseToken:self.purchaseToken purchaseOrderId:@""];
            return;
        }
        if ((self.state & CANCEL_FEATURE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

- (void)onGetTwincode:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetTwincode: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);
    
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    // Look in the image cache and load from database: we are running from twinlife executor and could
    // block while reading the database.
    self.state |= GET_SUBSCRIPTION_TWINCODE_DONE;
    self.subscriptionTwincode = twincodeOutbound;
    if (twincodeOutbound && errorCode == TLBaseServiceErrorCodeSuccess && self.delegate) {
        TLImageId *imageId = twincodeOutbound.avatarId;
        if (imageId) {
            TLImageService *imageService = [self.twinmeContext getImageService];
            UIImage *image = [imageService getCachedImageWithImageId:imageId kind:TLImageServiceKindThumbnail];
            if (image) {
                self.state |= GET_SUBSCRIPTION_IMAGE | GET_SUBSCRIPTION_IMAGE_DONE;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.delegate && [(id)self.delegate respondsToSelector:@selector(onSubscriptionTwincode:image:)]) {
                        [(id<InAppSubscriptionServiceDelegate>)self.delegate onSubscriptionTwincode:twincodeOutbound image:image];
                    }
                });
            } else {
                self.subscriptionImageId = imageId;
            }
        }
    }
    [self onOperation];
}

- (void)onGetImage:(nullable UIImage *)image errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetImage: %@ errorCode: %d", LOG_TAG, image, errorCode);
    
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    self.state |= GET_SUBSCRIPTION_IMAGE_DONE;
    if (image) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [(id)self.delegate respondsToSelector:@selector(onSubscriptionTwincode:image:)]) {
                [(id<InAppSubscriptionServiceDelegate>)self.delegate onSubscriptionTwincode:self.subscriptionTwincode image:image];
            }
        });
    }
}

@end
