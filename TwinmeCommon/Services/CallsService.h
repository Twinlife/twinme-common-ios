/*
 *  Copyright (c) 2020-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "AbstractTwinmeService.h"

@class TLCallDescriptor;
@class TLContact;
@class TLSpace;
@class TLCallReceiver;

//
// Protocol: CallsServiceDelegate
//

@protocol CallsServiceDelegate <AbstractTwinmeDelegate, ContactTwinmeDelegate, CurrentSpaceTwinmeDelegate, SpaceTwinmeDelegate>

- (void)onCreateOriginator:(nonnull id<TLOriginator>)originator avatar:(nonnull UIImage *)avatar;

- (void)onUpdateOriginator:(nonnull id<TLOriginator>)originator avatar:(nonnull UIImage *)avatar;

- (void)onDeleteOriginator:(nonnull id<TLOriginator>)originator;

- (void)onGetOriginators:(nonnull NSArray<id<TLOriginator>> *)originators;

- (void)onGetDescriptors:(nonnull NSArray<TLCallDescriptor *> *)descriptors;

- (void)onAddDescriptor:(nonnull TLCallDescriptor *)descriptor;

- (void)onUpdateDescriptor:(nonnull TLCallDescriptor *)descriptor;

- (void)onDeleteDescriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors;

- (void)onResetConversation:(nonnull id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode;

- (void)onGetCallReceivers:(nonnull NSArray<TLCallReceiver *> *)callReceivers;

- (void)onCreateCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onUpdateCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onDeleteCallReceiver:(nonnull NSUUID *)callReceiverId;

- (void)onGetGroupMembers:(nonnull NSMutableArray<id<TLGroupMemberConversation>> *)members;

@optional

- (void)onGetCountCallReceivers:(int)countCallReceivers;

@end

//
// Interface: CallsService
//

@interface CallsService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <CallsServiceDelegate>)delegate originator:(nullable id<TLOriginator>)originator;

- (void)getCallsDescriptors;

- (void)getPreviousDescriptors;

- (void)deleteCallDescriptor:(nonnull TLCallDescriptor *)descriptor;

- (void)deleteCallReceiverWithCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (BOOL)isGetDescriptorsDone;

- (void)getGroupMembers:(nonnull id<TLOriginator>)group;

- (void)countCallReceivers;

@end

