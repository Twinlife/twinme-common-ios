/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */
#import "AbstractTwinmeService.h"

@class TLContact;
@class TLTwinmeContext;

//
// Protocol: ShowRoomServiceDelegate
//

@protocol ShowRoomServiceDelegate <AbstractTwinmeDelegate, ContactTwinmeDelegate>

- (void)onUpdateRoom:(nonnull TLContact *)room avatar:(nullable UIImage *)avatar;

- (void)onDeleteRoom:(nonnull NSUUID *)roomId;

- (void)onGetRoomMembers:(nonnull NSArray *)roomMembers memberCount:(int)memberCount;

- (void)onGetRoomMemberAvatar:(nonnull TLTwincodeOutbound *)twincodeOutbound avatar:(nonnull UIImage *)avatar;

@end

//
// Interface: ShowRoomService
//

@interface ShowRoomService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<ShowRoomServiceDelegate>)delegate;

- (void)initWithRoom:(nonnull TLContact *)room;

- (void)deleteRoom:(nonnull TLContact *)room;

@end
