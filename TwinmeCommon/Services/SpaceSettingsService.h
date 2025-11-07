/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: SpaceSettingsServiceDelegate
//

@protocol SpaceSettingsServiceDelegate <AbstractTwinmeDelegate>

- (void)onUpdateSpaceDefaultSettings:(nonnull TLSpaceSettings *)spaceSettings;

@end

//
// Interface: SpaceSettingsService
//

@interface SpaceSettingsService : AbstractTwinmeService

/// Create the service to edit the space settings
- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <SpaceSettingsServiceDelegate>)delegate;

/// Update the default space settings
- (void)updateDefaultSpaceSettings:(nonnull TLSpaceSettings *)spaceSettings;

@end

