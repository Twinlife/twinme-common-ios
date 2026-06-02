/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreImage/CIFilterBuiltins.h>

#import "Utils.h"

#import "ApplicationDelegate.h"
#import "TwinmeApplication.h"

#import <Twinlife/TLTwincodeURI.h>

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"Utils"

//
// Implementation: Utils
//

@implementation Utils

+ (CGFloat)progressWithTime:(double)time duration:(double)duration {

    CGFloat progress = (CGFloat) (time / duration);
    if (progress < 0.0 || isnan(progress)) {
        progress = 0.0;
    } else if (progress > 1.0 || isinf(progress)) {
        progress = 1.0;
    }
    return progress;
}

+ (CGFloat)uploadProgressWithPosition:(long)current length:(long)length {
    if (length <= 0) {
        return 1.0;
    }
    CGFloat progress = (CGFloat) (current) / (CGFloat) (length);
    if (progress < 0.0 || isnan(progress)) {
        progress = 0.0;
    } else if (progress > 1.0 || isinf(progress)) {
        progress = 1.0;
    }
    return progress;
}

+ (nonnull UIImage *)makeQRCodeWithUri:(nonnull TLTwincodeURI *)uri scale:(CGFloat)scale {
    DDLogVerbose(@"%@ makeQRCodeWithUri: %@", LOG_TAG, uri);
    
    if (uri.uri) {
        return [self makeQRCode:uri.uri scale:scale];
    }
    
    return [UIImage new];
}

+ (nonnull UIImage *)makeQRCode:(nonnull NSString *)uri scale:(CGFloat)scale {
    DDLogVerbose(@"%@ makeQRCode: %@", LOG_TAG, uri);
    
    CIFilter<CIQRCodeGenerator> *filter = [CIFilter QRCodeGenerator];
    
    filter.message = [uri dataUsingEncoding:NSUTF8StringEncoding];;
    filter.correctionLevel = @"M";
    
    CIImage *outputImage = filter.outputImage;
    
    UIImage *preImage = [[UIImage alloc] initWithCIImage:outputImage];
    
    CGSize size = CGSizeMake([outputImage extent].size.width * scale, outputImage.extent.size.width * scale);
    
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    UIImage *resizedImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [preImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
    }];
    
    return resizedImage;
}

+ (void)hapticFeedback:(UIImpactFeedbackStyle)style {
    DDLogVerbose(@"%@ hapticFeedback: %ld", LOG_TAG, (long)style);
    
    ApplicationDelegate *delegate = (ApplicationDelegate *)[[UIApplication sharedApplication] delegate];
    TwinmeApplication *twinmeApplication = [delegate twinmeApplication];
    
    if ([twinmeApplication allowHapticFeedback]) {
        UIImpactFeedbackGenerator *impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [impactFeedbackGenerator prepare];
        [impactFeedbackGenerator impactOccurred];
    }
}

@end
