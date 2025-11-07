/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AsyncManager.h"

@class TLVideoDescriptor;

//
// Interface: AsyncVideoLoader
//

@interface AsyncVideoLoader : NSObject <AsyncLoader>

@property (nullable) UIImage *image;

/// Create the video thumbnail loader instance.
- (nonnull instancetype)initWithItem:(nonnull id<NSObject>)item videoDescriptor:(nonnull TLVideoDescriptor *)videoDescriptor size:(CGSize)size;

/// Cancel loading the video thumbnail.
- (void)cancel;

/// Check if this loader was finished.
- (BOOL)isFinished;

@end
