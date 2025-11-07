/*
 *  Copyright (c) 2020-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: EditRoomServiceDelegate
//

@class TLContact;
@class TLTwinmeContext;

@protocol EditRoomServiceDelegate <AbstractTwinmeDelegate>

- (void)onGetRoomConfig:(nonnull TLRoomConfig *)roomConfig;

- (void)onGetRoomConfigNotFound;

- (void)onUpdateRoom:(nonnull TLContact *)room;

- (void)onDeleteRoom:(nonnull NSUUID *)roomId;

@end

//
// Interface: EditRoomService
//

@interface EditRoomService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<EditRoomServiceDelegate>)delegate;

- (void)updateRoomWithName:(nonnull TLContact *)room name:(nonnull NSString *)name;

- (void)updateRoomWithName:(nonnull TLContact *)room name:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar welcomeMessage:(nullable NSString *)welcomeMessage;

- (void)deleteRoom:(nonnull TLContact *)room;

- (void)getRoomConfig:(nonnull TLContact *)room;

- (void)updateRoomConfig:(nonnull TLContact *)room roomConfig:(nonnull TLRoomConfig *)roomConfig;

@end
