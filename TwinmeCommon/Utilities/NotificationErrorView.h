/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

//
// Interface: NotificationErrorView
//

@interface NotificationErrorView : UIViewController

- (nonnull instancetype)initWithMessage:(nonnull NSString *)message;

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode;

- (void)showInView:(nonnull UIView *)view;

- (void)hideNotification;

@end
