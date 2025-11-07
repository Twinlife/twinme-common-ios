/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: SpaceAppearanceServiceDelegate
//

@protocol SpaceAppearanceServiceDelegate <AbstractTwinmeDelegate, SpaceTwinmeDelegate>

- (void)onUpdateSpaceDefaultSettings:(nonnull TLSpaceSettings *)spaceSettings;

@end

//
// Interface: SpaceAppearanceService
//

@interface SpaceAppearanceService : AbstractTwinmeService

/// Create the service to edit the space (default to the current selected space).
- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <SpaceAppearanceServiceDelegate>)delegate space:(nullable TLSpace *)space;

/// Update the space settings (name, avatar, theme).
- (void)updateSpace:(nonnull TLSpaceSettings *)spaceSettings;

- (void)updateSpace:(nonnull TLSpaceSettings *)spaceSettings conversationBackgroundLightImage:(nullable UIImage *)conversationBackgroundLightImage conversationBackgroundLightLargeImage:(nullable UIImage *)conversationBackgroundLightLargeImage conversationBackgroundDarkImage:(nullable UIImage *)conversationBackgroundDarkImage conversationBackgroundDarkLargeImage:(nullable UIImage *)conversationBackgroundDarkLargeImage updateConversationBackgroundLightColor:(BOOL)updateConversationBackgroundLightColor updateConversationBackgroundDarkColor:(BOOL)updateConversationBackgroundDarkColor;

@end

