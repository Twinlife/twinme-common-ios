/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (fabrice.trescartes@twin.life)
 */

#import "AsyncManager.h"

//
// Interface: AsyncLinkLoader
//

@interface AsyncLinkLoader : NSObject <AsyncLoader>

@property (nullable) UIImage *image;
@property (nullable) NSString *title;
@property (nullable) NSURL *url;

/// Create the link loader instance.
- (nonnull instancetype)initWithItem:(nonnull id<NSObject>)item objectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor;

/// Cancel loading the link metadata.
- (void)cancel;

/// Check if this loader was finished.
- (BOOL)isFinished;

@end
