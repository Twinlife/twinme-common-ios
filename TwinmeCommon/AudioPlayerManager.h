/*
*  Copyright (c) 2017-2023 twinlife SA.
*  SPDX-License-Identifier: AGPL-3.0-only
*
*  Contributors:
*   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
*   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
*   Stephane Carrez (Stephane.Carrez@twin.life)
*/

@class TLDescriptorId;

@interface AudioSessionManager : NSObject

- (nonnull instancetype) init;

/// Start the audio session before playing some audio and call the completion handler once the audio is enabled.
- (void)startAudioSessionWithCompletion:(nullable dispatch_block_t)completion;

/// Release the audio session (restore the previous CoreAudio player if necessary).
- (void)releaseAudioSession;

- (void)proximityChanged;

@end

@interface AudioPlayerManager : AudioSessionManager

@property (nullable) TLDescriptorId *descriptorId;

+ (nonnull AudioPlayerManager *)sharedInstance;

+ (void)stopPlaying;

- (void)playWithURL:(nonnull NSURL *)url currentTime:(float)currentTime startPlayingBlock:(nullable dispatch_block_t)startPlayingBlock;

- (BOOL)isPlaying;

- (void)pause;

- (void)stop;

- (float)currentPlaybackTime;

- (float)duration;

- (void)setCurrentTime:(float)currentTime;

@end
