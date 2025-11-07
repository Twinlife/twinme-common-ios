/*
 *  Copyright (c) 2020-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */
#import "AbstractTwinmeService.h"

@class TLContact;
@class TLTwinmeContext;

//
// Protocol: RoomMemberServiceDelegate
//

@protocol RoomMemberServiceDelegate <AbstractTwinmeDelegate>

- (void)onGetRoomAdmins:(nonnull NSArray *)roomAdmins;

- (void)onGetRoomMembers:(nonnull NSArray *)roomMembers;

- (void)onGetRoomAdminAvatar:(nonnull TLTwincodeOutbound *)twincodeOutbound avatar:(nonnull UIImage *)avatar;

- (void)onGetRoomMemberAvatar:(nonnull TLTwincodeOutbound *)twincodeOutbound avatar:(nonnull UIImage *)avatar;

- (void)onSetAdministrator:(nonnull NSUUID *)adminId;

- (void)onRemoveAdministrator:(nonnull NSUUID *)adminId;

- (void)onRemoveMember:(nonnull NSUUID *)memberId;

@end

//
// Interface: RoomMemberService
//

@interface RoomMemberService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<RoomMemberServiceDelegate>)delegate;

- (void)initWithRoom:(nonnull TLContact *)room;

- (void)setRoomAdministrator:(nonnull NSUUID *)memberId;

- (void)removeAdministrator:(nonnull NSUUID *)memberId;

- (void)inviteMember:(nonnull NSUUID *)memberId;

- (void)removeMember:(nonnull NSUUID *)memberId;

- (void)nextMembers;

@end
