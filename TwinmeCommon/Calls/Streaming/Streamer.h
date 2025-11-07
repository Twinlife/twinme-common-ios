/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "StreamingControlIQ.h"

@class CallConnection;
@class StreamPlayer;
@class CallState;
@class StreamingRequestIQ;
@class StreamingControlIQ;
@class MPMediaItem;

//
// Interface: Streamer
//

@interface Streamer : NSObject

@property (nonatomic, readonly) int64_t ident;
@property (nonatomic, readonly) BOOL video;
@property (nonatomic, readonly, nonnull) CallState *call;
@property (nonatomic, nullable) StreamPlayer *localPlayer;

- (nonnull instancetype)initWithCall:(nonnull CallState *)call ident:(int64_t)ident mediaItem:(nonnull MPMediaItem *)mediaItem;

/// Start streaming to the connected peers.
- (void)startStreaming;

/// Pause the streaming by sending a PAUSE_STREAMING message to each call participant.
- (void)pauseStreaming;

/// Resume the streaming by sending a RESUME_STREAMING message to each call participant.
- (void)resumeStreaming;

/// Seek the streaming by sending a SEEK_STREAMING message with the position to each call participant.
- (void)seekStreamingWithPosition:(long)position;

/// Stop streaming the media to the peers and optionally notify them.
- (void)stopStreamingWithNotify:(BOOL)notify;

/// Local player has changed its status.  If this is an error, stop the streaming.
/// We also post a StreamerEvent for the UI to update its state.
- (void)updateLocalPlayerWithMode:(StreamingControlMode)mode offset:(int64_t)offset;

/// Handle the StreamingControlIQ packet for the StreamingControlModeAskXXX operations requested by the peer.
- (void)onStreamingControlWithConnection:(nonnull CallConnection *)connection iq:(nonnull StreamingControlIQ *)iq;

/// Handle the StreamingRequestIQ packet.
- (void)onStreamingRequestWithConnection:(nonnull CallConnection *)connection iq:(nonnull StreamingRequestIQ *)iq;

/// Local player is requesting a given data block.
- (void)readAsyncBlockWithOffset:(int64_t)offset length:(int64_t)length withBlock:(nonnull void (^)(NSData *_Nullable data))block;

@end
