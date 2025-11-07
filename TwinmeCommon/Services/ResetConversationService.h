/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"
#import <Twinlife/TLConversationService.h>

//
// Protocol: ResetConversationServiceDelegate
//

@protocol ResetConversationServiceDelegate <AbstractTwinmeDelegate>

- (void)onResetConversation:(nonnull id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode;

@end

//
// Interface: ResetConversationService
//

@interface ResetConversationService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<ResetConversationServiceDelegate>)delegate;

- (void)initWithContact:(nonnull TLContact *)contact;

- (void)initWithGroup:(nonnull TLGroup *)group;

- (void)resetConversation;

@end
