/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "StreamingControlIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * A streaming control operation.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"a080a7a6-59fe-4463-8ac4-61d897a2aa50",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"StreamingControlIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"ident", "type":"long"},
 *     {"name":"control", "type":"enum"},
 *     {"name":"length", "type":"long"},
 *     {"name":"timestamp", "type":"long"},
 *     {"name":"position", "type":"long"},
 *     {"name":"latency", "type":"int"}
 *  ]
 * }
 *
 * </pre>
 *
 * - Streaming starts either with a START_AUDIO_STREAMING or a START_VIDEO_STREAMING,
 * - The streaming can be paused with PAUSE_STREAMING and then resumed with RESUME_STREAMING,
 * - We can seek at a given position with SEEK_STREAMING,
 * - Peek can ask some operation on the streamer with the ASK_PAUSE_STREAMING, ASK_RESUME_STREAMING,
 *   ASK_SEEK_STREAMING and ASK_STOP_STREAMING
 * - Streaming is stopped with STOP_STREAMING
 *
 */

//
// Implementation: StreamingControlIQSerializer
//

@implementation StreamingControlIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[StreamingControlIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    StreamingControlIQ *streamingControlIQ = (StreamingControlIQ *)object;
    [encoder writeLong:streamingControlIQ.ident];
    switch (streamingControlIQ.mode) {
        case StreamingControlModeStartAudio:
            [encoder writeEnum:1];
            break;

        case StreamingControlModeStartVideo:
            [encoder writeEnum:2];
            break;

        case StreamingControlModePause:
            [encoder writeEnum:3];
            break;

        case StreamingControlModeResume:
            [encoder writeEnum:4];
            break;

        case StreamingControlModeSeek:
            [encoder writeEnum:5];
            break;

        case StreamingControlModeStop:
            [encoder writeEnum:6];
            break;

            // Queries operation range 11..20
        case StreamingControlModeAskPause:
            [encoder writeEnum:11];
            break;

        case StreamingControlModeAskResume:
            [encoder writeEnum:12];
            break;

        case StreamingControlModeAskSeek:
            [encoder writeEnum:13];
            break;

        case StreamingControlModeAskStop:
            [encoder writeEnum:14];
            break;

            // Status operations range 21..30
        case StreamingControlModeStatusPlaying:
            [encoder writeEnum:21];
            break;

        case StreamingControlModeStatusPaused:
            [encoder writeEnum:22];
            break;

        case StreamingControlModeStatusReady:
            [encoder writeEnum:23];
            break;

        case StreamingControlModeStatusUnSupported:
            [encoder writeEnum:24];
            break;

        case StreamingControlModeStatusError:
            [encoder writeEnum:25];
            break;

        case StreamingControlModeStatusStopped:
            [encoder writeEnum:26];
            break;

        case StreamingControlModeStatusCompleted:
            [encoder writeEnum:27];
            break;

        default:
            // When we serialize, we must know how to send the control command.
            // UNKNOWN is not used when sending but can be obtained when we deserialize.
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
    }
    [encoder writeLong:streamingControlIQ.length];
    [encoder writeLong:streamingControlIQ.timestamp];
    [encoder writeLong:streamingControlIQ.position];
    [encoder writeInt:streamingControlIQ.latency];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t ident = [decoder readLong];
    StreamingControlMode mode;
    switch ([decoder readEnum]) {
        case 1:
            mode = StreamingControlModeStartAudio;
            break;

        case 2:
            mode = StreamingControlModeStartVideo;
            break;

        case 3:
            mode = StreamingControlModePause;
            break;

        case 4:
            mode = StreamingControlModeResume;
            break;

        case 5:
            mode = StreamingControlModeSeek;
            break;

        case 6:
            mode = StreamingControlModeStop;
            break;

        case 11:
            mode = StreamingControlModeAskPause;
            break;

        case 12:
            mode = StreamingControlModeAskResume;
            break;

        case 13:
            mode = StreamingControlModeAskSeek;
            break;

        case 14:
            mode = StreamingControlModeAskStop;
            break;

        case 21:
            mode = StreamingControlModeStatusPlaying;
            break;

        case 22:
            mode = StreamingControlModeStatusPaused;
            break;

        case 23:
            mode = StreamingControlModeStatusReady;
            break;

        case 24:
            mode = StreamingControlModeStatusUnSupported;
            break;

        case 25:
            mode = StreamingControlModeStatusError;
            break;

        case 26:
            mode = StreamingControlModeStatusStopped;
            break;

        case 27:
            mode = StreamingControlModeStatusCompleted;
            break;

        default:
            mode = StreamingControlModeUnknown;
            break;
    }
    int64_t length = [decoder readLong];
    int64_t timestamp = [decoder readLong];
    int64_t position = [decoder readLong];
    int latency = [decoder readInt];

    return [[StreamingControlIQ alloc] initWithSerializer:self requestId:iq.requestId ident:ident mode:mode length:length timestamp:timestamp position:position latency:latency];
}

@end

//
// Implementation: StreamingControlIQ
//

@implementation StreamingControlIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId ident:(int64_t)ident mode:(StreamingControlMode)mode length:(int64_t)length timestamp:(int64_t)timestamp position:(int64_t)position latency:(int)latency {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _ident = ident;
        _mode = mode;
        _length = length;
        _timestamp = timestamp;
        _position = position;
        _latency = latency;
    }
    return self;
}

@end
