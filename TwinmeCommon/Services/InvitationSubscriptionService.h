/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: InvitationSubscriptionService
//

@protocol InvitationSubscriptionServiceDelegate <AbstractTwinmeDelegate, TwincodeTwinmeDelegate>

- (void)onSubscribeSuccess;

- (void)onSubscribeFailed:(TLBaseServiceErrorCode)errorCode;

@end

//
// Interface: InvitationSubscriptionService
//

@interface InvitationSubscriptionService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <InvitationSubscriptionServiceDelegate>)delegate;

- (void)getTwincodeOutboundWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId;

- (void)subscribeFeature:(nonnull NSString*)twincodeId activationCode:(nonnull NSString *)activationCode profileTwincodeOutboundId:(nonnull NSString *)profileTwincodeOutboundId;

@end
