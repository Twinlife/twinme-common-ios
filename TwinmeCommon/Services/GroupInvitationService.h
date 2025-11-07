/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"

@class TLGroup;
@class TLGroupMember;
@class TLInvitationDescriptor;
@protocol TLGroupConversation;

//
// Protocol: GroupInvitationServiceDelegate
//

@protocol GroupInvitationServiceDelegate <AbstractTwinmeDelegate, ContactTwinmeDelegate, CurrentSpaceTwinmeDelegate>
@optional

- (void)onGetContact:(nonnull TLContact *)contact avatar:(nullable UIImage *)avatar;

- (void)onGetInvitationWithInvitationDescriptor:(nonnull TLInvitationDescriptor *)invitationDescriptor avatar:(nullable UIImage *)avatar;

- (void)onDeclinedInvitationWithInvitationDescriptor:(nonnull TLInvitationDescriptor *)invitationDescriptor;

- (void)onAcceptedInvitationWithInvitationDescriptor:(nonnull TLInvitationDescriptor *)invitationDescriptor group:(nonnull TLGroup *)group;

- (void)onDeletedInvitation;

- (void)onMoveGroup:(nonnull TLGroup *)group;

@end

//
// Interface: GroupInvitationService
//

@interface GroupInvitationService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <GroupInvitationServiceDelegate>)delegate;

- (void)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId contactId:(nonnull NSUUID *)contactId;

- (void)acceptInvitation;

- (void)declineInvitation;

- (void)moveGroupToSpace:(nonnull TLSpace *)space group:(nonnull TLGroup *)group;

- (void)setCurrentSpace:(nonnull TLSpace *)space;

@end
