/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

@class TLSpace;
@class TLTwinmeContext;

//
// Protocol: ShowSpaceServiceDelegate
//

@protocol ShowSpaceServiceDelegate <AbstractTwinmeDelegate, SpaceTwinmeDelegate>

- (void)onCreateSpace:(nonnull TLSpace *)space;

- (void)onUpdateSpaceAvatar:(nonnull UIImage *)avatar;

@end

//
// Interface: ShowSpaceService
//

@interface ShowSpaceService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <ShowSpaceServiceDelegate>)delegate createSpace:(BOOL)createSpace;

- (void)initWithSpace:(nonnull TLSpace *)space;

- (void)getSpace:(nonnull NSUUID *)spaceId;

/// Update the space settings (secret space).
- (void)updateSpace:(nonnull TLSpaceSettings *)spaceSettings;

- (void)setDefaultSpace:(nonnull TLSpace *)space;

@end
