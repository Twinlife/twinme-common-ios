/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

@class CallConnection;
@class CallState;
@class Streamer;
@class StreamingDataIQ;
@class StreamingControlIQ;

//
// Interface: StreamPlayer
//

@interface StreamPlayer : NSObject

@property (nonatomic, readonly) int64_t ident;
@property (nonatomic, readonly) BOOL video;
@property (nonatomic, readonly) BOOL paused;
@property (nonatomic, readonly, nonnull) NSString *title;
@property (nonatomic, readonly, nullable) NSString *album;
@property (nonatomic, readonly, nullable) UIImage *artwork;
@property (nonatomic, readonly) int64_t duration;
@property (nonatomic, readonly, nullable) CallConnection *connection;
@property (nonatomic, readonly, nullable) Streamer *streamer;

- (nonnull instancetype)initWithIdent:(int64_t)ident size:(int64_t)size video:(BOOL)video call:(nonnull CallState *)call connection:(nullable CallConnection *)connection streamer:(nullable Streamer *)streamer;

/// Start the stream player.
- (void)start;

/// Pause the stream player (local only, internal operation).
- (void)pauseWithDelay:(dispatch_time_t)delay;

/// Resume the stream player (local only, internal operation).
- (void)resumeWithDelay:(dispatch_time_t)delay;

/// Seek the stream player to the given position (local only, internal operation).
- (void)seekWithPosition:(int64_t)position;

/// Send a request to ask pause on the streaming.
- (void)askPause;

/// Send a request to ask resume on the streaming.
- (void)askResume;

/// Send a request to ask seek at the given position on the streaming.
- (void)askSeekWithPosition:(int64_t)position;

/// Send a request to ask stopping the streaming.
- (void)askStop;

/// Get the current player position.
- (int64_t)playerPosition;

/// Stop the stream player.
- (void)stopWithNotify:(BOOL)notify;

/// Handle the StreamingControlIQ packet from the streamer to Pause/Resume.
- (void)onStreamingControlWithIQ:(nonnull StreamingControlIQ *)iq;

/// Receive a block of data from the peer.
- (void)onStreamingDataWithIQ:(nonnull StreamingDataIQ *)iq;

/// Set the information that describes what is being streamed.
- (void)setInformationWithTitle:(nonnull NSString *)title album:(nullable NSString *)album artist:(nullable NSString *)album artwork:(nullable UIImage *)artwork duration:(int64_t)duration;

@end
