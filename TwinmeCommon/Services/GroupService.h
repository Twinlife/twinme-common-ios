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
// Protocol: GroupServiceDelegate
//

@protocol GroupServiceDelegate <AbstractTwinmeDelegate, ContactTwinmeDelegate, CurrentSpaceTwinmeDelegate>
@optional

- (void)onCreateGroup:(nonnull TLGroup *)group conversation:(nonnull id<TLGroupConversation>)conversation;

- (void)onGetGroup:(nonnull TLGroup *)group groupMembers:(nonnull NSArray<TLGroupMember *> *)groupMembers conversation:(nonnull id<TLGroupConversation>)conversation;

- (void)onInviteGroup:(nonnull id<TLConversation>)conversation invitation:(nonnull TLInvitationDescriptor *)invitation;

- (void)onListPendingInvitations:(nonnull NSMutableDictionary<NSUUID *, TLInvitationDescriptor *> *)list;

- (void)onLeaveGroup:(nonnull TLGroup *)group memberTwincodeId:(nonnull NSUUID *)memberTwincodeId;

- (void)onUpdateGroup:(nonnull TLGroup *)group avatar:(nonnull UIImage *)avatar;

- (void)onMoveGroup:(nonnull TLGroup *)group;

- (void)onDeleteGroup:(nonnull NSUUID *)groupId;

- (void)onGetContacts:(nonnull NSArray *)contacts;

- (void)onGetContact:(nonnull TLContact *)contact;

- (void)onGetTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound;

- (void)onCreateInvitation:(nonnull TLInvitation *)invitation;

- (void)onGetCurrentSpace:(nonnull TLSpace *)space;

- (void)onErrorGroupNotFound;

- (void)onErrorContactNotFound;

- (void)onErrorLimitReached;

@end

//
// Interface: GroupService
//

@interface GroupService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <GroupServiceDelegate>)delegate;

- (void)initWithGroup:(nonnull TLGroup *)group;

- (void)getContacts;

- (void)getContactWithContactId:(nonnull NSUUID *)contactId;

- (void)getGroupWithGroupId:(nonnull NSUUID *)groupId;

- (void)createGroupWithName:(nonnull NSString *)name description:(nullable NSString *)description avatar:(nullable UIImage *)avatar avatarLarge:(nullable UIImage *)avatarLarge members:(nonnull NSMutableArray<TLContact *> *)members permissions:(int64_t)permissions;

- (void)inviteGroupWithContacts:(nonnull NSMutableArray<TLContact *> *)members;

- (void)leaveGroupWithMemberTwincodeId:(nonnull NSUUID *)memberTwincodeId;

- (void)getTwincodeOutboundWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId;

- (void)createInvitation:(nonnull TLGroupMember *)member;

- (TLBaseServiceErrorCode)withdrawInvitation:(nonnull TLInvitationDescriptor *)invitationDescriptor;

- (void)getCurrentSpace;

- (void)setCurrentSpace:(nonnull TLSpace *)space;

- (void)findContactsByName:(nonnull NSString *)name;

@end
