/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"

@class TLTwincodeOutbound;

//
// Protocol: InAppSubscriptionService
//

@protocol InAppSubscriptionServiceDelegate <AbstractTwinmeDelegate>

- (void)onSubscribeSuccess;

- (void)onSubscribeCancel;

- (void)onSubscribeFailed:(TLBaseServiceErrorCode)errorCode;

- (void)onSubscriptionTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound image:(nonnull UIImage *)image;

@end

//
// Interface: InAppSubscriptionService
//

@interface InAppSubscriptionService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext subscriptionTwincodeId:(nullable NSUUID *)subscriptionTwincodeId delegate:(nonnull id <InAppSubscriptionServiceDelegate>)delegate;

- (void)subscribeFeature:(nonnull NSString*)productId purchaseToken:(nonnull NSString *)purchaseToken purchaseOrderId:(nonnull NSString *)purchaseOrderId;

- (void)cancelFeature:(nonnull NSString *)purchaseToken;

@end
