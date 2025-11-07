/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

@class TLGroup;
@class TLConversationDescriptorPair;

//
// Interface: GroupMemberQuery
//

@interface GroupMemberQuery : NSObject

@property (weak, nullable) TLGroup *group;
@property (weak, nullable) NSUUID *memberTwincodeOutboundId;

- (nonnull instancetype)initWithGroup:(nonnull TLGroup *)group memberTwincodeOutboundId:(nonnull NSUUID *)memberTwincodeOutboundId;

@end

//
// Protocol: ChatServiceDelegate
//

@protocol ChatServiceDelegate <AbstractTwinmeDelegate, ContactTwinmeDelegate, ContactListTwinmeDelegate, GroupTwinmeDelegate, GroupListTwinmeDelegate, CurrentSpaceTwinmeDelegate, SpaceTwinmeDelegate>

- (void)onCreateContact:(nonnull TLContact *)contact avatar:(nonnull UIImage *)avatar;

- (void)onGetGroupMember:(nonnull NSUUID *)groupMemberTwincodeId member:(nullable TLGroupMember *)member avatar:(nullable UIImage *)avatar;

- (void)onCreateGroup:(nonnull TLGroup *)group conversation:(nonnull id<TLGroupConversation>)conversation avatar:(nonnull UIImage *)avatar;

- (void)onJoinGroup:(nonnull id <TLGroupConversation>)group memberId:(nullable NSUUID *)memberId;

- (void)onLeaveGroup:(nonnull id <TLGroupConversation>)group memberId:(nonnull NSUUID *)memberId;

- (void)onGetConversations:(nonnull NSArray<TLConversationDescriptorPair *> *)conversations;

- (void)onFindConversationsbyName:(nonnull NSArray<TLConversationDescriptorPair *> *)conversations;

- (void)onGetOrCreateConversation:(nonnull id <TLConversation>)conversation;

- (void)onResetConversation:(nonnull id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode;

- (void)onDeleteConversation:(nonnull NSUUID *)conversationId;

- (void)onPushDescriptor:(nonnull TLDescriptor *)descriptor conversation:(nonnull id <TLConversation>)conversation;

- (void)onPopDescriptor:(nonnull TLDescriptor *)descriptor conversation:(nonnull id <TLConversation>)conversation;

- (void)onUpdateDescriptor:(nonnull TLDescriptor *)descriptor conversation:(nonnull id <TLConversation>)conversation;

- (void)onDeleteDescriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors conversation:(nonnull id <TLConversation>)conversation;

@end

//
// Interface: ChatService
//

@interface ChatService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext callsMode:(TLDisplayCallsMode)callsMode delegate:(nonnull id <ChatServiceDelegate>)delegate;

- (void)getConversationsWithCallsMode:(TLDisplayCallsMode)callsMode;

- (void)getGroupMembers:(nonnull TLGroup *)group members:(nonnull NSArray *)members;

- (void)resetConversation:(nonnull id<TLOriginator>)originator;

- (void)findConversationsByName:(nonnull NSString *)name;

- (void)searchDescriptorsByContent:(nonnull NSString *)content clearSearch:(BOOL)clearSearch withBlock:(nonnull void (^)(NSArray<TLConversationDescriptorPair *> *_Nullable descriptors))block;

- (BOOL)isGetDescriptorDone;

- (void)getLastDescriptorWithConversation:(nonnull id<TLConversation>)conversation withBlock:(nonnull void (^)(TLDescriptor *_Nullable descriptor))block;

@end

