/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AsyncManager.h"

@class AudioTrack;
@class TLAudioDescriptor;

//
// Interface: AsyncAudioTrackLoader
//

@interface AsyncAudioTrackLoader : NSObject <AsyncLoader>

@property (nullable) AudioTrack *audioTrack;

/// Create the audio track loader instance.
- (nonnull instancetype)initWithItem:(nonnull id<NSObject>)item audioDescriptor:(nonnull TLAudioDescriptor *)audioDescriptor nbLines:(int)nbLines;

/// Cancel loading the audio trackl.
- (void)cancel;

/// Check if this loader was finished.
- (BOOL)isFinished;

@end
