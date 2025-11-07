/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"
#import <Twinme/TLExportExecutor.h>

//
// Protocol: CleanUpServiceDelegate
//

@protocol CleanUpServiceDelegate <AbstractTwinmeDelegate, TLExportDelegate>

- (void)onClearConversation;

@end

//
// Interface: CleanUpService
//

@interface CleanUpService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<CleanUpServiceDelegate>)delegate space:(nullable TLSpace *)space contact:(nullable TLContact *)contact group:(nullable TLGroup *)group;

- (void)setDateFilter:(int64_t)dateFilter;

- (void)startCleanUpFrom:(int64_t)clearDate clearMode:(TLConversationServiceClearMode)clearMode;

@end
