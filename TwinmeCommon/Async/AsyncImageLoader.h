/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AsyncManager.h"

@class TLImageDescriptor;

//
// Interface: AsyncImageLoader
//

@interface AsyncImageLoader : NSObject <AsyncLoader>

@property (nullable) UIImage *image;

/// Create the image loader instance.
- (nonnull instancetype)initWithItem:(nonnull id<NSObject>)item imageDescriptor:(nonnull TLImageDescriptor *)imageDescriptor size:(CGSize)size;

/// Cancel loading the image thumbnail.
- (void)cancel;

/// Check if this loader was finished.
- (BOOL)isFinished;

@end
