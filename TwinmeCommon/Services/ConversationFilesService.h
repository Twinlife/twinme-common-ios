/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <Twinlife/TLConversationService.h>
#import "AbstractTwinmeService.h"

//
// Protocol: ConversationFilesServiceDelegate
//

@class TLContact;
@protocol TLConversation;
@class TLTwinmeContext;

@protocol ConversationFilesServiceDelegate <AbstractTwinmeDelegate>

- (void)onGetConversation:(nonnull id <TLConversation>)conversation;

- (void)onGetDescriptors:(nonnull NSArray<TLDescriptor *> *)descriptors;

- (void)onMarkDescriptorDeleted:(nonnull TLDescriptor *)descriptor;

- (void)onDeleteDescriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors;

@end

//
// Interface: ConversationFilesService
//

@interface ConversationFilesService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<ConversationFilesServiceDelegate>)delegate;

- (void)initWithOriginator:(nonnull id<TLOriginator>)contact;

- (void)initWithConversationId:(nonnull nonnull NSUUID *)conversationId;

- (BOOL)isLocalDescriptor:(nonnull TLDescriptor *)descriptor;

- (BOOL)isPeerDescriptor:(nonnull TLDescriptor *)descriptor;

- (void)markDescriptorDeletedWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)deleteDescriptorWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)getPreviousDescriptors;

- (BOOL)isGetDescriptorDone;



@end
