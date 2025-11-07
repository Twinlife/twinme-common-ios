/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: EditSpaceServiceDelegate
//

@protocol EditSpaceServiceDelegate <AbstractTwinmeDelegate, SpaceTwinmeDelegate, GroupListTwinmeDelegate, ContactListTwinmeDelegate>

- (void)onUpdateSpaceAvatar:(nonnull UIImage *)avatar;

- (void)onCreateProfile:(nonnull TLProfile *)profile;

- (void)onUpdateProfile:(nonnull TLProfile *)profile;

@optional

- (void)onCreateSpace:(nonnull TLSpace *)space;

@end

//
// Interface: EditSpaceService
//

@interface EditSpaceService : AbstractTwinmeService

/// Create the service to edit the space (default to the current selected space).
- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <EditSpaceServiceDelegate>)delegate space:(nullable TLSpace *)space;

/// Create a profile for the space (either the current one or the one initialized by initWithSpace:).
- (void)createProfile:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nonnull UIImage *)largeAvatar;

/// Update the space profile name and avatar.
- (void)updateProfile:(nonnull NSString*)name avatar:(nonnull UIImage *)avatar largeAvatar:(nonnull UIImage *)largeAvatar;

- (void)createSpace:(nonnull NSString *)nameSpace spaceAvatar:(nonnull UIImage *)spaceAvatar spaceLargeAvatar:(nonnull UIImage *)spaceLargeAvatar descriptionSpace:(nonnull NSString *)descriptionSpace spaceSettings:(nonnull TLSpaceSettings *)spaceSettings;

/// Update the space settings (name, avatar, theme).
- (void)updateSpace:(nonnull TLSpaceSettings *)spaceSettings avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar;

/// Delete the space.
- (void)deleteSpace;

/// Set default space
- (void)setDefaultSpace:(nonnull TLSpace *)space;

@end

