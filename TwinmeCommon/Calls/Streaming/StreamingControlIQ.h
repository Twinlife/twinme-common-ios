/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLBinaryPacketIQ.h>

typedef enum {
    StreamingControlModeUnknown,

    // Start, stop and other operations for the streaming (values 1..10).
    StreamingControlModeStartAudio,
    StreamingControlModeStartVideo,
    StreamingControlModePause,
    StreamingControlModeResume,
    StreamingControlModeSeek,
    StreamingControlModeStop,

    // Queries from the peer to operate on the streamer (values 11..20).
    StreamingControlModeAskPause,
    StreamingControlModeAskResume,
    StreamingControlModeAskSeek,
    StreamingControlModeAskStop,

    // Streaming status feedback
    StreamingControlModeStatusPlaying,
    StreamingControlModeStatusPaused,
    StreamingControlModeStatusReady,
    StreamingControlModeStatusUnSupported,
    StreamingControlModeStatusError,
    StreamingControlModeStatusStopped,
    StreamingControlModeStatusCompleted
} StreamingControlMode;

//
// Interface: StreamingControlIQSerializer
//

@interface StreamingControlIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: StreamingControlIQ
//

@interface StreamingControlIQ : TLBinaryPacketIQ

@property (readonly) int64_t ident;
@property (readonly) StreamingControlMode mode;
@property (readonly) int64_t length;
@property (readonly) int64_t timestamp;
@property (readonly) int64_t position;
@property (readonly) int latency;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId ident:(int64_t)ident mode:(StreamingControlMode)mode length:(int64_t)length timestamp:(int64_t)timestamp position:(int64_t)position latency:(int)latency;

@end
