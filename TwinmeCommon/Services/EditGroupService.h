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
// Protocol: EditGroupServiceDelegate
//

@class TLGroup;
@class TLCapabilities;
@class TLTwinmeContext;

@protocol EditGroupServiceDelegate <AbstractTwinmeDelegate, GroupTwinmeDelegate>

- (void)onLeaveGroup:(nonnull TLGroup *)group memberTwincodeId:(nonnull NSUUID *)memberTwincodeId;

@optional

- (void)onUpdateGroupAvatar:(nonnull UIImage *)avatar;

- (void)onUpdateGroupAvatarNotFound;

@end

//
// Interface: EditGroupService
//

@interface EditGroupService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<EditGroupServiceDelegate>)delegate;

- (void)refreshWithGroup:(nonnull TLGroup *)group;

- (void)updateGroupWithName:(nonnull TLGroup *)group name:(nonnull NSString *)name description:(nullable NSString *)description;

- (void)updateGroupWithName:(nonnull TLGroup *)group name:(nonnull NSString *)name description:(nullable NSString *)description avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar permissions:(int64_t)permissions capabilities:(nullable TLCapabilities *)capabilities;

- (void)updateGroupWithName:(nonnull TLGroup *)group name:(nonnull NSString *)name description:(nullable NSString *)description avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar;

- (void)updateGroupWithCapabilities:(nonnull TLGroup *)group capabilities:(nullable TLCapabilities *)capabilities;

- (void)leaveGroupWithMemberTwincodeId:(nonnull TLGroup *)group memberTwincodeId:(nonnull NSUUID *)memberTwincodeId;

- (void)deleteGroup:(nonnull TLGroup *)group;

@end
