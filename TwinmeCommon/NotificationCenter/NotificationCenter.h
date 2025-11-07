/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <UserNotifications/UserNotifications.h>
#import <Twinme/TLNotificationCenter.h>
#import <Notification/NotificationTools.h>

//
// Interface: NotificationCenter
//

@class TwinmeApplication;
@class TLTwinmeContext;
@class TLContact;
@class TLGroup;
@class TLDescriptor;
@class CallService;
@class AccountMigrationService;

@interface SystemNotification : NSObject
@end

@interface IncomingCallNotification : SystemNotification

@property (readonly) BOOL audio;
@property (readonly) BOOL video;
@property (readonly) BOOL videoBell;
@property BOOL missed;

@end

@interface NotificationCenter : NotificationTools <TLNotificationCenter, UNUserNotificationCenterDelegate>

- (nonnull instancetype)initWithTwinmeApplication:(nonnull TwinmeApplication *)twinmeApplication twinmeContext:(nonnull TLTwinmeContext *)twinmeContext;

- (void)initWithCallService:(nonnull CallService *)callService accountMigrationService:(nonnull AccountMigrationService *)accountMigrationService;

- (void)applicationDidEnterBackground:(nonnull UIApplication *)application;

- (void)applicationDidBecomeActive:(nonnull UIApplication *)application;

- (void)cancelNotification:(nonnull SystemNotification *)notification;

/// Create a missed audio/video call notification for the contact.
- (void)missedCallNotificationWithOriginator:(nonnull id<TLOriginator>)originator video:(BOOL)video;

/// Create an incoming call notification for an audio/video call to the given contact.
- (nullable IncomingCallNotification *)createIncomingCallNotificationWithOriginator:(nonnull id<TLOriginator>)originator notificationId:(nonnull NSUUID *)peerConnectionId audio:(BOOL)audio video:(BOOL)video videoBell:(BOOL)videoBell;

@end
