/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"

@class TLGroup;
@class TLTwinmeContext;

//
// Protocol: ShowGroupServiceDelegate
//

@protocol ShowGroupServiceDelegate <AbstractTwinmeDelegate>

- (void)onGetGroup:(nonnull TLGroup *)group groupMembers:(nonnull NSArray<TLGroupMember *> *)groupMembers conversation:(nonnull id<TLGroupConversation>)conversation;

- (void)onGetTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound;

- (void)onLeaveGroup:(nonnull TLGroup *)group memberTwincodeId:(nonnull NSUUID *)memberTwincodeId;

- (void)onUpdateGroup:(nonnull TLGroup *)group avatar:(nullable UIImage *)avatar;

- (void)onDeleteGroup:(nonnull NSUUID *)groupId;

- (void)onErrorGroupNotFound;

@end

//
// Interface: ShowGroupService
//

@interface ShowGroupService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <ShowGroupServiceDelegate>)delegate;

- (void)initWithGroup:(nonnull TLGroup *)group;

- (void)leaveGroupWithMemberTwincodeId:(nonnull NSUUID *)memberTwincodeId;

- (void)getGroupWithGroupId:(nonnull NSUUID *)groupId;

- (void)getTwincodeOutboundWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId;

- (void)updatePermissions:(BOOL)allowInvitation allowMessage:(BOOL)allowMessage allowInviteMemberAsContact:(BOOL)allowInviteMemberAsContact;

@end
