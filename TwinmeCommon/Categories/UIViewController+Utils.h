/*
 *  Copyright (c) 2018-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

//
// Interface: UIViewController (Utils)
//

@interface UIViewController (Utils)

+ (UIViewController *)topViewController;

+ (UIWindow *)currentWindow;

- (BOOL)hasLandscapeMode;

- (void)clearBottomSheetViews;

@end
