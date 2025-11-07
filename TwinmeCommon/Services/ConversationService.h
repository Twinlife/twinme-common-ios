/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <Twinlife/TLConversationService.h>
#import "AbstractTwinmeService.h"

//
// Protocol: ConversationServiceDelegate
//

@class TLProfile;
@class TLContact;
@class TLGroup;
@protocol TLConversation;
@protocol TLGroupConversation;
@class TLTwinmeContext;
@class TLTyping;

typedef BOOL (^TLDescriptorFilter) (TLDescriptor *_Nonnull descriptor);

@protocol ConversationServiceDelegate <AbstractTwinmeDelegate>

- (void)onGetConversation:(nonnull id <TLConversation>)conversation;

- (void)onResetConversation:(nonnull id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode;

- (void)onUpdateConversation:(nonnull id <TLConversation>)conversation;

- (void)onGetGroupConversation:(nonnull id <TLGroupConversation>)group groupMembers:(nonnull NSMutableDictionary<NSUUID *, TLGroupMember *> *)groupMembers;

- (void)onGetGroupMembers:(nonnull NSMutableDictionary<NSUUID *, TLGroupMember *> *)groupMembers;

- (void)onGetDescriptors:(nonnull NSArray<TLDescriptor *> *)descriptors;

- (void)onLeaveGroup:(nonnull TLGroup *)group memberTwincodeId:(nonnull NSUUID *)memberId;

- (void)onPushDescriptor:(nonnull TLDescriptor *)descriptor;

- (void)onPopDescriptor:(nonnull TLDescriptor *)descriptor;

- (void)onUpdateDescriptor:(nonnull TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType;

- (void)onMarkDescriptorRead:(nonnull TLDescriptor *)descriptor;

- (void)onMarkDescriptorDeleted:(nonnull TLDescriptor *)descriptor;

- (void)onDeleteDescriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors;

- (void)onErrorFeatureNotSupportedByPeer;

@end

//
// Interface: ConversationService
//

@interface ConversationService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<ConversationServiceDelegate>)delegate;

- (void)initWithContact:(nonnull id<TLOriginator>)contact callsMode:(TLDisplayCallsMode)callsMode descriptorFilter:(nullable TLDescriptorFilter)descriptorFilter maxDescriptors:(int)maxDescriptors;

- (BOOL)isLocalDescriptor:(nonnull TLDescriptor *)descriptor;

- (BOOL)isPeerDescriptor:(nonnull TLDescriptor *)descriptor;

- (void)setActiveConversation;

- (void)resetActiveConversation;

- (void)getPreviousDescriptors;

- (BOOL)isGetDescriptorDone;

- (void)pushMessage:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed expiredTimeout:(int64_t)expiredTimeout sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo;

- (void)markDescriptorDeletedWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)markDescriptorReadWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)updateDescriptorWithDescriptorId:(nonnull TLDescriptorId *)descriptorId content:(nonnull NSString *)message;

- (void)deleteDescriptorWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)pushFileWithPath:(nonnull NSString *)path type:(TLDescriptorType)type toBeDeleted:(BOOL)toBeDeleted copyAllowed:(BOOL)copyAllowed expiredTimeout:(int64_t)expiredTimeout sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo;

- (void)pushGeolocationWithLatitude:(double)latitude longitude:(double)longitude altitude:(double)altitude  latitudeDelta:(double)latitudeDelta longitudeDelta:(double)longitudeDelta expiredTimeout:(int64_t)expiredTimeout sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo;

- (void)saveGeolocationMapWithPath:(nonnull NSString *)path descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)pushTyping:(nonnull TLTyping *)typing;

- (void)resetConversation;

- (void)clearMediaAndFile;

- (void)toggleAnnotationWithDescriptorId:(nonnull TLDescriptorId *)descriptorId type:(TLDescriptorAnnotationType)type value:(int)value;

/// Note: we should avoid using this method, for now it is too complex to remove from the ConversationViewController.
- (nonnull UIImage *)getImageWithGroupMember:(nonnull TLGroupMember *)groupMember;

- (void)listAnnotationsWithDescriptorId:(nonnull TLDescriptorId *)descriptorId withBlock:(nonnull void (^)(NSMutableDictionary<NSUUID *, TLDescriptorAnnotationPair*> * _Nonnull list))block;

- (nullable NSUUID *)debugGetTwincodeOutboundId;

- (nullable NSUUID *)debugGetPeerTwincodeOutboundId;

@end
