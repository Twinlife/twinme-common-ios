/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "AbstractTwinmeService.h"

@class TLInvitation;
@class TLTwincodeOutbound;
@class TLProfile;

//
// Protocol: InvitationCodeServiceDelegate
//

@protocol InvitationCodeServiceDelegate <AbstractTwinmeDelegate, TwincodeTwinmeDelegate>

- (void)onCreateInvitationWithCodeWithInvitation:(nullable TLInvitation *)invitation;

- (void)onGetInvitationCodeWithTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound avatar:(nullable UIImage *)avatar publicKey:(nullable NSString *)publicKey;

- (void)onGetInvitationCodeNotFound;

- (void)onGetLocalInvitationCode;

- (void)onGetInvitationsWithInvitations:(nullable NSArray<TLInvitation *> *)invitations;

- (void)onGetDefaultProfileWithProfile:(nonnull TLProfile *)profile;

- (void)onGetDefaultProfileNotFound;

- (void)onDeleteInvitationWithInvitationId:(nonnull NSUUID *)invitationId;

- (void)onCreateContact:(nonnull TLContact *)contact;

- (void)onInvitationCodeError:(TLBaseServiceErrorCode)errorCode;

@optional

- (void)onLimitInvitationCodeReach;

@end

//
// Interface: InvitationCodeService
//

@interface InvitationCodeService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <InvitationCodeServiceDelegate>)delegate;

- (void)createInvitationWithCode:(BOOL)isPremiumVersion;

- (void)getInvitationCodeWithCode:(nonnull NSString *)code;

- (void)getInvitations;

- (void)deleteInvitationWithInvitation:(nonnull TLInvitation *)invitation;

- (void)createContact:(nonnull TLTwincodeOutbound *)twincodeOutbound;

@end
