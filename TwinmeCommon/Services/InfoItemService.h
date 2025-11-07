/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: InfoItemServiceDelegate
//

@class TLContact;
@class TLGroup;
@class TLDescriptorAnnotationPair;
@protocol TLGroupConversation;

@protocol InfoItemServiceDelegate <AbstractTwinmeDelegate>

- (void)onUpdateDescriptor:(nonnull TLDescriptor *)descriptor;

@end

//
// Interface: InfoItemService
//

@interface InfoItemService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<InfoItemServiceDelegate>)delegate;

- (void)initWithContact:(nonnull id<TLOriginator>)contact;

- (void)listAnnotationsWithDescriptorId:(nonnull TLDescriptorId *)descriptorId withBlock:(nonnull void (^)(NSMutableDictionary<NSUUID *, TLDescriptorAnnotationPair*> * _Nonnull list))block;

- (void)updateDescriptor:(nonnull TLDescriptorId *)descriptorId allowCopy:(BOOL)allowCopy;

@end
