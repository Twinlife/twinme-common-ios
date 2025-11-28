/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TwinmeApplication.h"

@class TLTwincodeURI;

//
// Interface: Utils
//

@interface Utils : NSObject

/// Compute the progress of `time` in the `duration` range.
/// Garantees to return a value in range 0 .. 100 even when the duration or time are invalid.
+ (CGFloat)progressWithTime:(double)time duration:(double)duration;

/// Compute the progress of `current` uploaded dlength in the total `length` range.
/// Garantees to return a value in range 0 .. 100 even when the lengths are invalid.
+ (CGFloat)uploadProgressWithPosition:(long)current length:(long)length;

/// Generate the QR-code image for the given twincode URI.
+ (nonnull UIImage *)makeQRCodeWithUri:(nonnull TLTwincodeURI *)uri scale:(CGFloat) scale;

/// Generate the QR-code image for the given string URI.
+ (nonnull UIImage *)makeQRCode:(nonnull NSString *)uri scale:(CGFloat)scale;

/// Play haptic feedback with given style and hapticFeedbackMode
+ (void)hapticFeedback:(UIImpactFeedbackStyle)style hapticFeedbackMode:(HapticFeedbackMode)mode;

@end

