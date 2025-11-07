/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: EditIdentityServiceDelegate
//

@class TLProfile;
@class TLContact;
@class TLGroup;
@class TLSpace;
@class TLCallReceiver;
@class TLTwinmeContext;

@protocol EditIdentityServiceDelegate <AbstractTwinmeDelegate, CurrentSpaceTwinmeDelegate, ContactTwinmeDelegate, GroupTwinmeDelegate>

- (void)onCreateProfile:(nonnull TLProfile *)profile;

- (void)onUpdateProfile:(nonnull TLProfile *)profile;

- (void)onUpdateCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onDeleteProfile:(nonnull NSUUID *)profileId;

- (void)onUpdateIdentityAvatar:(nonnull UIImage *)avatar;

@end

//
// Interface: EditIdentityService
//

@interface EditIdentityService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<EditIdentityServiceDelegate>)delegate;

- (void)refreshWithProfile:(nonnull TLProfile *)profile;

- (void)refreshWithContact:(nonnull TLContact *)contact;

- (void)refreshWithGroup:(nonnull TLGroup *)group;

- (void)refreshWithCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)createProfile:(nonnull NSString *)identityName identityDescription:(nullable NSString *)identityDescription identityAvatar:(nonnull UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar space:(nonnull TLSpace *)space;

- (void)updateIdentityWithProfile:(nonnull TLProfile *)profile identityName:(nonnull NSString *)identityName identityDescription:(nullable NSString *)identityDescription identityAvatar:(nonnull UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar profileUpdateMode:(TLProfileUpdateMode)profileUpdateMode;

- (void)updateIdentityWithContact:(nonnull TLContact *)contact identityName:(nonnull NSString *)identityName identityDescription:(nullable NSString *)identityDescription identityAvatar:(nonnull UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar;

- (void)updateIdentityWithCallReceiver:(nonnull TLCallReceiver *)callReceiver identityName:(nonnull NSString *)identityName identityDescription:(nullable NSString *)identityDescription identityAvatar:(nonnull UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar;

- (void)updateIdentityWithGroup:(nonnull TLGroup *)group identityName:(nonnull NSString *)identityName identityAvatar:(nonnull UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar;

- (void)deleteProfile:(nonnull TLProfile *)profile;

@end
