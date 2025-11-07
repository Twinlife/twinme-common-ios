/*
 *  Copyright (c) 2017-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: NotificationServiceDelegate
//

@class TLSpace;
@class TLNotification;
@class TLTwinmeContext;

@protocol NotificationServiceDelegate <AbstractTwinmeDelegate, CurrentSpaceTwinmeDelegate, SpaceTwinmeDelegate>

- (void)onGetNotifications:(nonnull NSArray<TLNotification *> *)notifications;

- (void)onAddNotification:(nonnull TLNotification *)notification;

- (void)onAcknowledgeNotification:(nonnull TLNotification *)notification;

- (void)onDeleteNotificationsWithList:(nonnull NSArray<NSUUID *> *)list;

- (void)onUpdatePendingNotifications:(BOOL)hasPendingNotifications;

@end

//
// Interface: NotificationService
//

@interface NotificationService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<NotificationServiceDelegate>)delegate;

- (void)acknowledgeNotification:(nonnull TLNotification *)notification;

- (void)getNotifications;

- (void)deleteNotification:(nonnull TLNotification *)notification;

- (void)getGroupMemberWithNotification:(nonnull TLNotification *)notification withBlock:(nullable void (^)(TLGroupMember *_Nonnull member, UIImage *_Nullable image))block;

@end
