/*
 *  Copyright (c) 2014-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Zhuoyu Ma (Zhuoyu.Ma@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <UIKit/UIKit.h>
#import <Twinlife/TLApplication.h>

#define CONVERSATION_ACTION [NSString stringWithFormat:@"conversation.%@",[TLTwinlife TWINLIFE_DOMAIN]]
#define NotificationsRequestAuthorizationFinish @"NotificationsRequestAuthorizationFinish"

//
// Interface: ApplicationDelegate
//

@class TwinmeApplication;
@class TLTwinmeContext;
@class MainViewController;
@class AdminService;
@class CallService;
@class AccountMigrationService;

@interface ApplicationDelegate : UIResponder <TLApplication>

@property (nonatomic, readonly, nonnull) TwinmeApplication *twinmeApplication;
@property (nonatomic, readonly, nonnull) TLTwinmeContext *twinmeContext;
@property (nonatomic, nullable) MainViewController *mainViewController;
@property (nonatomic, readonly, nonnull) AdminService *adminService;
@property (nonatomic, readonly, nonnull) CallService *callService;
@property (nonatomic, readonly, nullable) AccountMigrationService *accountMigrationService;
@property (nonatomic, nullable) UIWindow *window;

- (void)registerNotification:(nonnull UIApplication *)application;

@end
