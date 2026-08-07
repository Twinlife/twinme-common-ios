/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractBottomSheetView.h"

//
// Interface: OnboardingConfirmView
//

@interface OnboardingConfirmView : AbstractBottomSheetView

- (void)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image action:(NSString *)action actionColor:(UIColor *)actionColor cancel:(NSString *)cancel;

- (void)hideCancelAction;

@end
