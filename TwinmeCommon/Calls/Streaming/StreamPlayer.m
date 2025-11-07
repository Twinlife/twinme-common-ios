/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>
#include <AudioToolbox/AudioToolbox.h>
#import <WebRTC/RTCAudioSession.h>
#import <WebRTC/RTCDispatcher.h>

#import "CallState.h"
#import "CallConnection.h"
#import "StreamPlayer.h"
#import "Streamer.h"
#import "StreamingControlIQ.h"
#import "StreamingRequestIQ.h"
#import "StreamingDataIQ.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define AUDIO_QUEUE_BUFFER_COUNT     64

#define OUTPUT_BUFFER_SIZE           16384*4 // *4*4
#define STREAM_BUFFER_SIZE           8192 // *4*4
#define STREAM_BUFFER_QUEUE_SIZE     (128*1024)
#define STREAM_MIN_BUFFER_QUEUE_SIZE (128*1024)

#define MAX_RTT_TIME    10000

typedef struct AudioPacket {
    UInt64 identifier;
    AudioStreamPacketDescription desc;
    struct AudioPacket *next;
    char data[];
} AudioPacket_t;

/**
 * Stream player implementation notes:
 *
 * - Operations are called from the `processQueue` which serializes the operations.
 * - We create a audioFileStream by using `AudioFileStreamOpen` and providing 2 callbacks.
 *  The audioPropertyValueCallback is called when a property is found in the audio stream.
 *  The audioStreamDataWithNumberBytes is called with the data block.
 * - The stream data is passed to the audioFileStream by calling AudioFileStreamParseBytes.
 *  The audio stream parser will invoke either the audioPropertyValueCallback or the audioStreamDataWithNumberBytes.
 * -
 */

typedef enum {
    AudioQueueStateIdle,
    AudioQueueStateReady,
    AudioQueueStateRunning,
    AudioQueueStatePaused,
    AudioQueueStateCompleted,
    AudioQueueStateUnSupported,
    AudioQueueStateError,
    AudioQueueStateDeleted
} AudioQueueState;

//
// Interface: StreamPlayer
//

@interface StreamPlayer ()

@property (readonly) int64_t size;
@property (nonatomic, readonly) CallState *call;
@property (readonly, nonnull) void *processQueueTag;
@property (nonatomic, nullable) dispatch_queue_t processQueue;
@property (nonatomic) int64_t streamReadOffset;
@property (nonatomic) int64_t streamReadAckOffset;
@property (nonatomic) int lastRTT;
@property (nonatomic) int64_t lastStreamerPosition;
@property (nonatomic) int64_t lastStreamerPositionTime;
@property (nonatomic) BOOL endOfStream;
@property (nonatomic) AudioPacket_t *firstPacket;
@property (nonatomic) AudioPacket_t *lastPacket;
@property (nonatomic) AudioPacket_t *readPacket;
@property (nullable) AudioQueueRef audioQueue;
@property (nonatomic) UInt64 packetIdentifier;
@property (nonatomic) BOOL audioSessionActive;
@property (nonatomic) BOOL discontinuous;
@property (nonatomic) AudioFileStreamID audioFileStream;
@property (nonatomic) UInt32 bitRate;
@property (nonatomic) SInt64 dataOffset;
@property (nonatomic) UInt64 dataByteCount;
@property (nonatomic) UInt64 dataPacketCount;
@property (nonatomic) AudioStreamBasicDescription srcFormat;
@property (nonatomic) AudioStreamBasicDescription dstFormat;
@property (nonatomic) double packetDuration;
@property (nonatomic) AudioQueueState audioQueueState;
@property (nonatomic) AudioQueueBufferRef *audioQueueBuffer; // [AUDIO_QUEUE_BUFFER_COUNT];
@property (nonatomic) int audioQueueBufferIndex;
@property (nonatomic) int audioReadPendingSize;

/// Send the player streaming status or ask request to the peer.
- (void)sendStreamControlWithMode:(StreamingControlMode)mode offset:(int64_t)offset;

/// Called from the processQueue when we received a data block from the peer.
- (void)audioWriteWithData:(nonnull NSData *)data offset:(int64_t)offset;

/// Check if we have enough audio packet and request more to the peer if needed.
- (void)requestFillBuffers;

/// Called from audioWriteWithData through the call to AudioFileStreamParseBytes when some audio property is extracted from the stream.
- (void)audioPropertyValueWithPropertyID:(AudioFileStreamPropertyID)propertyID ioFlags:(UInt32 *)ioFlags;

/// Called from audioWriteWithData through the call to AudioFileStreamParseBytes when we get an audio packet.
- (void)audioStreamDataWithNumberBytes:(UInt32)numberBytes numberPackets:(UInt32)numberPackets inputData:(const void *)inputData packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions;

/// Called from audioQueueInit (through audioPropertyValueWithPropertyID) to setup the audio queue stream cookie.
- (void)audioQueueSetCookies;

/// Called from audioPropertyValueWithPropertyID to initialize the audio queue, prepare the audio buffers before we get the first audio packet.
- (void)audioQueueInit;

/// Must be called from the processQueue to pick a free buffer and handle the audio decode by calling audioDecodePacketWithBuffer if we have enough audio packets.
- (void)audioDecodePackets;

- (OSStatus)audioDecodePacketWithBuffer:(AudioQueueBufferRef)buffer;

- (void)audioQueueIsRunningWithProperty:(AudioQueuePropertyID)property;

- (OSStatus)encoderDataWithNumber:(nonnull UInt32 *)numberDataPackets data:(nonnull AudioBufferList *)data packetDescription:(AudioStreamPacketDescription **)packetDescription;

@end

static void audioPropertyValueCallback(void *inUserData, AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, UInt32 *ioFlags) {

    StreamPlayer *player = (__bridge StreamPlayer *)inUserData;
    [player audioPropertyValueWithPropertyID:inPropertyID ioFlags:ioFlags];
}

static void audioStreamDataCallback(void *inUserData, UInt32 inNumberBytes, UInt32 inNumberPackets, const void *inInputData, AudioStreamPacketDescription *inPacketDescriptions) {
    StreamPlayer *player = (__bridge StreamPlayer *)inUserData;

    [player audioStreamDataWithNumberBytes:inNumberBytes numberPackets:inNumberPackets inputData:inInputData packetDescriptions:inPacketDescriptions];
}

static void audioQueueIsRunningCallback(void *inClientData, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
    StreamPlayer *player = (__bridge StreamPlayer *)inClientData;

    [player audioQueueIsRunningWithProperty:inID];
}

static void audioQueueInputCallback(void *inClientData, AudioQueueRef inAQ, AudioQueueBufferRef buffer) {
    StreamPlayer *player = (__bridge StreamPlayer *)inClientData;

    dispatch_async(player.processQueue, ^{
        [player audioDecodePacketWithBuffer:buffer];
    });
}

//
// Implementation: StreamPlayer
//

#undef LOG_TAG
#define LOG_TAG @"StreamPlayer"

@implementation StreamPlayer

- (nonnull instancetype)initWithIdent:(int64_t)ident size:(int64_t)size video:(BOOL)video call:(nonnull CallState *)call connection:(nullable CallConnection *)connection streamer:(nullable Streamer *)streamer {
    DDLogVerbose(@"%@ initWithIdent: %lld size: %lld video: %d connection: %@ streamer: %@", LOG_TAG, ident, size, video, connection, streamer);

    self = [super init];
    if (self) {
        _ident = ident;
        _call = call;
        _processQueueTag = &_processQueueTag;
        dispatch_queue_attr_t attr;
        attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
        _processQueue = dispatch_queue_create("streamQueue", attr);
        dispatch_queue_set_specific(_processQueue, _processQueueTag, _processQueueTag, NULL);
        _size = size;
        _video = video;
        _connection = connection;
        _streamer = streamer;
        _streamReadOffset = 0;
        _streamReadAckOffset = 0;
        _lastRTT = 0;
        _lastStreamerPosition = 0;
        _lastStreamerPositionTime = 0;
        _audioReadPendingSize = 0;
        _endOfStream = NO;
        _discontinuous = NO;
        _audioQueueBufferIndex = 0;
        _audioQueueState = AudioQueueStateIdle;
        _audioSessionActive = NO;
        _audioQueueBuffer = (AudioQueueBufferRef *)calloc(AUDIO_QUEUE_BUFFER_COUNT, sizeof(AudioQueueBufferRef));
        _dstFormat.mSampleRate = 44100; // Use same WebRTC sample rate ?
        _dstFormat.mFormatID = kAudioFormatLinearPCM;
        _dstFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        _dstFormat.mBytesPerPacket = 4;
        _dstFormat.mFramesPerPacket = 1;
        _dstFormat.mBytesPerFrame = 4;
        _dstFormat.mChannelsPerFrame = 2;
        _dstFormat.mBitsPerChannel = 16;
    }
    return self;
}

- (void)start {
    DDLogVerbose(@"%@ start", LOG_TAG);

    AudioFileStreamID audioFileStream = 0;
    OSStatus result = AudioFileStreamOpen((__bridge void *)self, audioPropertyValueCallback, audioStreamDataCallback, 0, &audioFileStream);

    DDLogVerbose(@"%@ opened audio file stream: %d", LOG_TAG, result);
    self.audioFileStream = audioFileStream;
    self.streamReadOffset = 0;
    self.streamReadAckOffset = 0;
    self.endOfStream = NO;

    // Ask the first buffers to the peer.
    dispatch_async(self.processQueue, ^{
        int64_t offset = 0;
        while (offset < STREAM_BUFFER_QUEUE_SIZE) {
            [self sendStreamRequestWithOffset:offset length:STREAM_BUFFER_SIZE];
            offset += STREAM_BUFFER_SIZE;
        }
        self.streamReadOffset = offset;
    });
}

- (void)sendStreamRequestWithOffset:(int64_t)offset length:(int64_t)length {
    DDLogVerbose(@"%@ sendStreamRequestWithOffset: %lld", LOG_TAG, offset);

    if (self.connection) {
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
        int64_t playerPosition = [self playerPosition];

        int64_t deltaPosition;
        int64_t dt = now - self.lastStreamerPositionTime;
        if (self.lastStreamerPositionTime > 0) {
            deltaPosition = playerPosition - (self.lastStreamerPosition + dt);
        } else {
            deltaPosition = 0;
        }
        DDLogVerbose(@"%@ sendStreamRequest: offset: %lld pos: %lld streamer: %lld delta: %lldd", LOG_TAG, offset, playerPosition, self.lastStreamerPosition, deltaPosition);

        StreamingRequestIQ *requestIQ = [[StreamingRequestIQ alloc] initWithSerializer:[CallConnection STREAMING_REQUEST_SERIALIZER] requestId:[self.call allocateRequestId] ident:self.ident offset:offset length:length playerPosition:playerPosition timestamp:now lastRTT:self.lastRTT];
        
        [self.connection sendMessageWithIQ:requestIQ statType:TLPeerConnectionServiceStatTypeIqSetPushObject];

    } else if (self.streamer) {
        [self.streamer readAsyncBlockWithOffset:offset length:length withBlock:^(NSData *data) {
            [self writeWithData:data offset:offset];
        }];
    }
}

- (void)sendStreamControlWithMode:(StreamingControlMode)mode offset:(int64_t)offset {
    DDLogVerbose(@"%@ sendStreamControlWithMode: %d offset: %lld", LOG_TAG, mode, offset);

    if (self.connection) {
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
        int64_t position = [self playerPosition];
        int latency = self.lastRTT / 2;
        StreamingControlIQ *requestIQ = [[StreamingControlIQ alloc] initWithSerializer:[CallConnection STREAMING_CONTROL_SERIALIZER] requestId:[self.call allocateRequestId] ident:self.ident mode:mode length:offset timestamp:now position:position latency:latency];
        
        [self.connection sendMessageWithIQ:requestIQ statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
        switch (mode) {
            case StreamingControlModeStatusPlaying:
                [self.call onStreamingEventWithParticipant:[self.connection mainParticipant] event:StreamingEventPlaying];
                break;

            case StreamingControlModeStatusReady:
                [self.call onStreamingEventWithParticipant:[self.connection mainParticipant] event:StreamingEventStart];
                break;

            case StreamingControlModeStatusUnSupported:
                [self.call onStreamingEventWithParticipant:[self.connection mainParticipant] event:StreamingEventUnsupported];
                break;

            case StreamingControlModeStatusError:
                [self.call onStreamingEventWithParticipant:[self.connection mainParticipant] event:StreamingEventError];
                break;

            case StreamingControlModeStatusStopped:
                [self.call onStreamingEventWithParticipant:[self.connection mainParticipant] event:StreamingEventStop];
                break;

            case StreamingControlModeStatusCompleted:
                [self.call onStreamingEventWithParticipant:[self.connection mainParticipant] event:StreamingEventCompleted];
                break;

            default:
                break;
        }
    } else if (self.streamer) {
        [self.streamer updateLocalPlayerWithMode:mode offset:offset];
    }
}

/// Pause the stream player.
- (void)pauseWithDelay:(dispatch_time_t)delay {
    DDLogVerbose(@"%@ pauseWithDelay: %lld", LOG_TAG, delay);

    @synchronized (self) {
        if (self.paused) {
            return;
        }
        _paused = YES;
    }

    dispatch_after(delay, self.processQueue, ^{
        // Check the audioQueue still exist because it could have been deleted while we wait.
        if (self.audioQueue) {
            DDLogVerbose(@"%@ calling AudioQueuePause", LOG_TAG);
            AudioQueuePause(self.audioQueue);
            if (self.connection) {
                [self.call onStreamingEventWithParticipant:[self.connection mainParticipant] event:StreamingEventPaused];
                [self sendStreamControlWithMode:StreamingControlModeStatusPaused offset:0];
            }
        }
    });
}

/// Resume the stream player.
- (void)resumeWithDelay:(dispatch_time_t)delay {
    DDLogVerbose(@"%@ resumeWithDelay: %lld", LOG_TAG, delay);

    @synchronized (self) {
        if (!self.paused) {
            return;
        }
        _paused = NO;
    }

    dispatch_after(delay, self.processQueue, ^{
        // Check the audioQueue still exist because it could have been deleted while we wait.
        if (self.audioQueue) {
            DDLogVerbose(@"%@ calling AudioQueueStart", LOG_TAG);
            AudioQueueStart(self.audioQueue, NULL);
            if (self.connection) {
                [self.call onStreamingEventWithParticipant:[self.connection mainParticipant] event:StreamingEventPlaying];
                [self sendStreamControlWithMode:StreamingControlModeStatusPlaying offset:0];
            }
        }
    });
}

- (void)seekWithPosition:(int64_t)position {
    
}

- (void)askPause {
    DDLogVerbose(@"%@ askPause", LOG_TAG);

    [self sendStreamControlWithMode:StreamingControlModeAskPause offset:0];
}

- (void)askResume {
    DDLogVerbose(@"%@ askResume", LOG_TAG);

    [self sendStreamControlWithMode:StreamingControlModeAskResume offset:0];
}

- (void)askSeekWithPosition:(int64_t)position {
    DDLogVerbose(@"%@ askSeekWithPosition: %lld", LOG_TAG, position);

    [self sendStreamControlWithMode:StreamingControlModeAskSeek offset:position];
}

- (void)askStop {
    DDLogVerbose(@"%@ askStop", LOG_TAG);

    [self sendStreamControlWithMode:StreamingControlModeAskStop offset:0];
}

- (int64_t)playerPosition {
    DDLogVerbose(@"%@ playerPosition", LOG_TAG);

    // The position is computed by using the source sample rate and the AudioQueue gives the
    // sample time from the source point of view (ie, 44100).  The AudioQueue itself can run
    // at a different output rate (48000).
    // Make sure we have a valid sample rate.
    Float64 sampleRate = self.srcFormat.mSampleRate;
    if (sampleRate <= 1.0) {
        return 0;
    }

    AudioTimeStamp queueTime;
    Boolean discontinuity;

    memset(&queueTime, 0, sizeof queueTime);

    OSStatus err = AudioQueueGetCurrentTime(self.audioQueue, NULL, &queueTime, &discontinuity);
    if (err) {
        return 0;
    }

    return (int64_t) (queueTime.mSampleTime / sampleRate * 1000.0);
}

- (void)updateQueueWithState:(AudioQueueState)state notify:(BOOL)notify {
    DDLogVerbose(@"%@ updateQueueWithState: %d notify: %d", LOG_TAG, state, notify);

    if (self.audioQueueState == state) {
        return;
    }

    self.audioQueueState = state;

    if (notify) {
        StreamingControlMode status;
        switch (state) {
            case AudioQueueStateIdle:
            case AudioQueueStateReady:
            case AudioQueueStateDeleted:
                return;

            case AudioQueueStatePaused:
                status = StreamingControlModeStatusStopped;
                break;

            case AudioQueueStateCompleted:
                status = StreamingControlModeStatusCompleted;
                break;

            case AudioQueueStateRunning:
                status = StreamingControlModeStatusPlaying;
                break;

            case AudioQueueStateError:
                status = StreamingControlModeStatusError;
                break;

            case AudioQueueStateUnSupported:
                status = StreamingControlModeStatusUnSupported;
                break;
        }
        [self sendStreamControlWithMode:status offset:0];
    }
}

- (void)stopWithNotify:(BOOL)notify {
    DDLogVerbose(@"%@ stopWithNotify: %d", LOG_TAG, notify);

    if (self.audioSessionActive) {
        self.audioSessionActive = NO;

        [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
            
            RTC_OBJC_TYPE(RTCAudioSession) *audioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
            [audioSession lockForConfiguration];
            NSError *error;
            if (![audioSession setActive:NO error:&error]) {
                DDLogError(@"set active: %@", error.localizedDescription);
            }
            [audioSession unlockForConfiguration];
        }];
    }

    dispatch_async(self.processQueue, ^{
        self.audioQueueState = AudioQueueStateDeleted;
        AudioQueueFlush(self.audioQueue);
        AudioQueueRemovePropertyListener(self.audioQueue, kAudioQueueProperty_IsRunning, audioQueueIsRunningCallback, (__bridge void *)self);
        AudioQueueStop(self.audioQueue, YES);
        if (self.audioFileStream) {
            AudioFileStreamClose(self.audioFileStream);
            self.audioFileStream = 0;
        }

        // Free what is allocated with malloc/calloc.
        free(self.audioQueueBuffer);

        // Free the audio packets if they are not consumed.
        AudioPacket_t *packet = self.firstPacket;
        while (packet) {
            AudioPacket_t *next = packet->next;
            free(packet);
            packet = next;
        }

        self.firstPacket = 0;
        self.audioQueueBuffer = 0;
        self.processQueue = nil;

        AudioQueueDispose(self.audioQueue, YES);
        self.audioQueue = 0;
    });

    [self updateQueueWithState:AudioQueueStateIdle notify:notify];
}

- (void)onStreamingControlWithIQ:(nonnull StreamingControlIQ *)iq {
    DDLogVerbose(@"%@ onStreamingControlWithIQ: %@", LOG_TAG, iq);
    
    if (iq.ident != self.ident) {
        return;
    }

    switch (iq.mode) {
        case StreamingControlModePause: {
            int64_t position = [self playerPosition];
            int64_t delay = iq.length - position;
            if (delay < 0) {
                delay = 0;
            }
            [self pauseWithDelay:dispatch_time(DISPATCH_TIME_NOW, delay * 1000000LL)];
            break;
        }

        case StreamingControlModeResume: {
            int64_t position = [self playerPosition];
            int64_t delay = position - iq.length;
            if (delay < 0) {
                delay = 0;
            }
            [self resumeWithDelay:dispatch_time(DISPATCH_TIME_NOW, delay * 1000000LL)];
            break;
        }

        default:
            break;
    }
}

/// Receive a block of data from the peer.
- (void)onStreamingDataWithIQ:(nonnull StreamingDataIQ *)iq {
    DDLogVerbose(@"%@ onStreamingDataWithIQ: %@ offset: %lld", LOG_TAG, iq, iq.offset);
    
    // Compute RTT for the StreamingRequestDataIQ+StreamingDataIQ
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    int64_t requestTime = now - iq.timestamp;
    if (requestTime > 0 && requestTime - (int64_t)iq.streamerLatency < MAX_RTT_TIME) {
        self.lastRTT = (int) requestTime - iq.streamerLatency;
    }
    
    self.lastStreamerPosition = iq.streamerPosition;
    self.lastStreamerPositionTime = now;
    
    [self writeWithData:iq.data offset:iq.offset];
}

- (void)writeWithData:(nullable NSData *)data offset:(int64_t)offset {
    DDLogVerbose(@"%@ writeWithData: offset: %lld", LOG_TAG, offset);

    self.endOfStream = data.length < STREAM_BUFFER_SIZE;
    if (data.length > 0) {
        // Take into account the new data block from the process queue
        // (current thread is the WebRTC signaling thread).
        dispatch_async(self.processQueue, ^{
            [self audioWriteWithData:data offset:offset];
        });
    }
}

- (void)setInformationWithTitle:(nonnull NSString *)title album:(nullable NSString *)album artist:(nullable NSString *)artist artwork:(nullable UIImage *)artwork duration:(int64_t)duration {
    DDLogVerbose(@"%@ setInformationWithTitle: %@ album: %@ artist: %@ duration: %lld", LOG_TAG, title, album, artist, duration);
    
    _title = title;
    _album = album;
    _artwork = artwork;
    _duration = duration;
}

#pragma mark - Internal

- (void)audioWriteWithData:(nonnull NSData *)data offset:(int64_t)offset {
    DDLogVerbose(@"%@ audioWriteWithData: offset: %lld length: %lu", LOG_TAG, offset, data.length);

    NSAssert(dispatch_get_specific(self.processQueueTag), @"Invoked on incorrect queue");

    if (self.streamReadAckOffset < offset + data.length) {
        self.streamReadAckOffset = offset + data.length;
    }

    OSStatus result = AudioFileStreamParseBytes(self.audioFileStream, (UInt32) data.length, data.bytes, self.discontinuous ? kAudioFileStreamParseFlag_Discontinuity : 0);
    if (result) {
        DDLogError(@"%@ AudioFileStreamParseBytes: %d", LOG_TAG, result);
        [self updateQueueWithState:AudioQueueStateError notify:true];
        return;
    }

    if (self.audioQueueState != AudioQueueStatePaused) {
        [self requestFillBuffers];
    }
}

- (void)requestFillBuffers {
    DDLogVerbose(@"%@ requestFillBuffers: %d stream: %lld", LOG_TAG, self.audioReadPendingSize, self.streamReadOffset - self.streamReadAckOffset);

    NSAssert(dispatch_get_specific(self.processQueueTag), @"Invoked on incorrect queue");

    // Ask for more data blocks before we run out of packets for the AudioQueue.
    long pendingRead = self.audioReadPendingSize - STREAM_MIN_BUFFER_QUEUE_SIZE;
    int64_t offset = self.streamReadOffset;
    pendingRead += offset - self.streamReadAckOffset;
    while (pendingRead < 0) {
        [self sendStreamRequestWithOffset:offset length:STREAM_BUFFER_SIZE];
        pendingRead += STREAM_BUFFER_SIZE;
        offset = offset + STREAM_BUFFER_SIZE;
        self.streamReadOffset = offset;
    }
}

- (void)audioPropertyValueWithPropertyID:(AudioFileStreamPropertyID)propertyID ioFlags:(UInt32 *)ioFlags {
    DDLogVerbose(@"%@ audioPropertyValueWithPropertyID: %u", LOG_TAG, propertyID);

    switch (propertyID) {
        case kAudioFileStreamProperty_FileFormat: {
            DDLogVerbose(@"%@ got file format property", LOG_TAG);
            break;
        }

        case kAudioFileStreamProperty_DataFormat: {
            AudioStreamBasicDescription inputFormat;
            UInt32 inputFormatSize = sizeof(inputFormat);

            OSStatus err = AudioFileStreamGetProperty(self.audioFileStream, kAudioFileStreamProperty_DataFormat, &inputFormatSize, &inputFormat);
            if (err) {
                [self updateQueueWithState:AudioQueueStateError notify:true];
                return;
            }
            self.srcFormat = inputFormat;

            DDLogVerbose(@"%@ got data format property sampleRate: %f formatId: %d", LOG_TAG, inputFormat.mSampleRate, inputFormat.mFormatID);
            break;
        }
        case kAudioFileStreamProperty_RestrictsRandomAccess: {
            
            DDLogVerbose(@"%@ got restricts random access property", LOG_TAG);
            break;
        }

        case kAudioFileStreamProperty_MaximumPacketSize: {
            DDLogVerbose(@"%@ got audio max packet size property", LOG_TAG);
            break;
        }

        case kAudioFileStreamProperty_BitRate: {
            UInt32 bitRate;
            UInt32 bitRateSize = sizeof(bitRate);
            OSStatus err = AudioFileStreamGetProperty(self.audioFileStream, kAudioFileStreamProperty_BitRate, &bitRateSize, &bitRate);
            if (err) {
                self.bitRate = 0;
            } else {
                self.bitRate = bitRate;
            }
            DDLogVerbose(@"%@ got bitrate: %u", LOG_TAG, self.bitRate);
            break;
        }

        case kAudioFileStreamProperty_DataOffset: {
            SInt64 offset;
            UInt32 offsetSize = sizeof(offset);
            OSStatus err = AudioFileStreamGetProperty(self.audioFileStream, kAudioFileStreamProperty_DataOffset, &offsetSize, &offset);
            if (err) {
                DDLogVerbose(@"%@: reading kAudioFileStreamProperty_DataOffset property failed: %d", LOG_TAG, err);
            } else {
                self.dataOffset = offset;
            }
            DDLogVerbose(@"%@ got dataOffset: %lld", LOG_TAG, self.dataOffset);
            break;
        }

        case kAudioFileStreamProperty_AudioDataByteCount: {
            UInt64 dataByteCount;
            UInt32 byteCountSize = sizeof(dataByteCount);
            OSStatus err = AudioFileStreamGetProperty(self.audioFileStream, kAudioFileStreamProperty_AudioDataByteCount, &byteCountSize, &dataByteCount);
            if (err) {
                self.dataByteCount = 0;
            } else {
                self.dataByteCount = dataByteCount;
            }
            DDLogVerbose(@"%@ got dataByteCount: %lld", LOG_TAG, self.dataByteCount);
            break;
        }

        case kAudioFileStreamProperty_AudioDataPacketCount: {
            UInt64 dataPacketCount;
            UInt32 packetCountSize = sizeof(dataPacketCount);
            OSStatus err = AudioFileStreamGetProperty(self.audioFileStream, kAudioFileStreamProperty_AudioDataPacketCount, &packetCountSize, &dataPacketCount);
            DDLogVerbose(@"%@ got dataPacketCount error: %d", LOG_TAG, err);
            if (err) {
                self.dataPacketCount = 0;
            } else {
                self.dataPacketCount = dataPacketCount;
            }
            DDLogVerbose(@"%@ got dataPacketCount: %lld", LOG_TAG, self.dataPacketCount);
            break;
        }

        case kAudioFileStreamProperty_MagicCookieData: {
            UInt32 cookieSize = 0;
            Boolean writable;

            OSStatus err = AudioFileStreamGetPropertyInfo(self.audioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
            DDLogVerbose(@"%@ got MagicCookieData size: %u err: %d", LOG_TAG, cookieSize, err);
            break;
        }

        case kAudioFileStreamProperty_FormatList: {
            UInt32 formatListSize = 0;
            Boolean writable;
            DDLogVerbose(@"%@ found formatList property", LOG_TAG);
            if (!AudioFileStreamGetPropertyInfo(self.audioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, &writable)) {
                void *formatListData = calloc(1, formatListSize);
                if (!AudioFileStreamGetProperty(self.audioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, formatListData)) {
                    for (int i = 0; i < formatListSize; i += sizeof(AudioFormatListItem)) {
                        AudioStreamBasicDescription *pasbd = (AudioStreamBasicDescription *)formatListData + i;

                        DDLogVerbose(@"%@ found format %d", LOG_TAG, pasbd->mFormatID);
                        // self.srcFormat = *pasbd;
                        if (pasbd->mFormatID == kAudioFormatMPEG4AAC_HE ||
                            pasbd->mFormatID == kAudioFormatMPEG4AAC_HE_V2) {
                            self.srcFormat = *pasbd;
                            break;
                        }
                    }
                }

                free(formatListData);
            }
            // self.packetDuration = self.srcFormat.mFramesPerPacket / self.srcFormat.mSampleRate;
            break;
        }

        case kAudioFileStreamProperty_ReadyToProducePackets: {
            DDLogVerbose(@"%@ got ReadyToProducePackets property", LOG_TAG);

            UInt32 formatListSize = 0;
            Boolean writable;
            if (!AudioFileStreamGetPropertyInfo(self.audioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, &writable)) {
                void *formatListData = calloc(1, formatListSize);
                if (!AudioFileStreamGetProperty(self.audioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, formatListData)) {
                    for (int i = 0; i < formatListSize; i += sizeof(AudioFormatListItem)) {
                        AudioStreamBasicDescription *pasbd = (AudioStreamBasicDescription *)formatListData + i;

                        DDLogVerbose(@"%@ found format %d", LOG_TAG, pasbd->mFormatID);
                        // self.srcFormat = *pasbd;
                        if (pasbd->mFormatID == kAudioFormatMPEG4AAC_HE ||
                            pasbd->mFormatID == kAudioFormatMPEG4AAC_HE_V2) {
                            self.srcFormat = *pasbd;
                            break;
                        }
                    }
                }

                free(formatListData);
            }
            if (self.srcFormat.mSampleRate > 0) {
                self.packetDuration = self.srcFormat.mFramesPerPacket / self.srcFormat.mSampleRate;
            } else {
                self.packetDuration = 0;
            }

            DDLogVerbose(@"%@ srcFormat.sampleRate: %f bits: %d format: %d", LOG_TAG, self.srcFormat.mSampleRate,
                       self.srcFormat.mBitsPerChannel, self.srcFormat.mFormatID);
            DDLogVerbose(@"%@: srcFormat, bytes per packet %d", LOG_TAG, (unsigned int)self.srcFormat.mBytesPerPacket);

            self.discontinuous = YES;
            [self audioQueueInit];
            break;
        }

        default:
            DDLogVerbose(@"%@ audio property: %u unknown", LOG_TAG, propertyID);
            break;
    }
}

- (void)audioQueueSetCookies {
    DDLogVerbose(@"%@ audioQueueSetCookies", LOG_TAG);

    UInt32 cookieSize;
    Boolean writable;

    OSStatus err = AudioFileStreamGetPropertyInfo(self.audioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
    if (err) {
        return;
    }

    void* cookieData = calloc(1, cookieSize);
    err = AudioFileStreamGetProperty(self.audioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
    if (err) {
        free(cookieData);
        return;
    }

    AudioQueueSetProperty(self.audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);

    free(cookieData);
}

- (void)audioQueueInit {
    DDLogVerbose(@"%@ audioQueueInit", LOG_TAG);
    
    OSStatus err = noErr;
    err = AudioQueueNewOutput(&_srcFormat, audioQueueInputCallback, (__bridge void *)self, NULL, kCFRunLoopCommonModes, 0, &_audioQueue);
    if (err) {
        DDLogError(@"%@ AudioQueueNewOutput failed: %d", LOG_TAG, err);
        [self updateQueueWithState:AudioQueueStateError notify:true];
        return;
    }
    
    [self audioQueueSetCookies];

    AudioChannelLayout* channelLayout = nil;
    UInt32 size = sizeof(UInt32);
    err = AudioFileStreamGetProperty(self.audioFileStream, kAudioFilePropertyChannelLayout, &size, &size);
    if (err == noErr && size > 0) {
        channelLayout = (AudioChannelLayout *)malloc(size);
        err = AudioFileStreamGetProperty(self.audioFileStream, kAudioFilePropertyChannelLayout, &size, channelLayout);
        if (err) {
            DDLogError(@"%@: AudioFileStreamGetProperty error: %d", LOG_TAG, err);
        }
        err = AudioQueueSetProperty(self.audioQueue, kAudioQueueProperty_ChannelLayout, channelLayout, size);
        if (err) {
            DDLogError(@"%@: AudioQueueSetProperty error: %d", LOG_TAG, err);
        }
    }

    int maxPacketDescriptionCount = 32;
    for (unsigned int i = 0; i < AUDIO_QUEUE_BUFFER_COUNT; ++i) {
        err = AudioQueueAllocateBufferWithPacketDescriptions(self.audioQueue, OUTPUT_BUFFER_SIZE, maxPacketDescriptionCount, &self.audioQueueBuffer[i]);
        if (err) {
            (void)AudioQueueDispose(self.audioQueue, true);
            self.audioQueue = 0;
            [self updateQueueWithState:AudioQueueStateError notify:true];
            return;
        }
    }
    
    err = AudioQueueAddPropertyListener(self.audioQueue, kAudioQueueProperty_IsRunning, audioQueueIsRunningCallback, (__bridge void *)self);
    if (err) {
        DDLogError(@"%@error in AudioQueueAddPropertyListener: %d", LOG_TAG, err);
        [self updateQueueWithState:AudioQueueStateError notify:true];
        return;
    }

    Float64 sampleRate = 48000.0;
    UInt32 output = sizeof(sampleRate);
    err = AudioQueueGetProperty(self.audioQueue, kAudioQueueDeviceProperty_SampleRate, &sampleRate, &output);
    if (err) {
        DDLogError(@"%@: AudioQueueGetProperty error in kAudioQueueDeviceProperty_SampleRate: %d", LOG_TAG, err);
    }
    _dstFormat.mSampleRate = sampleRate;
    DDLogVerbose(@"%@: Audio Queue sample rate: %f", LOG_TAG, sampleRate);

    UInt32 packetSize;
    output = sizeof(packetSize);
    err = AudioQueueGetProperty(self.audioQueue, kAudioQueueProperty_MaximumOutputPacketSize, &packetSize, &output);
    if (err) {
        DDLogError(@"%@: AudioQueueGetProperty error in kAudioQueueDeviceProperty_SampleRate: %d", LOG_TAG, err);
    }
    DDLogVerbose(@"%@: Audio Queue max packet size: %u", LOG_TAG, packetSize);

    UInt32 numberChannels;
    output = sizeof(numberChannels);
    err = AudioQueueGetProperty(self.audioQueue, kAudioQueueDeviceProperty_NumberChannels, &numberChannels, &output);
    if (err) {
        DDLogError(@"%@: AudioQueueGetProperty error in kAudioQueueDeviceProperty_SampleRate: %d", LOG_TAG, err);
    }
    DDLogVerbose(@"%@: Audio Queue number channels: %u", LOG_TAG, numberChannels);

    // We are ready to process audio packets.  The audioStreamDataWithNumberBytes will be called
    // and this will trigger audioDecodePackets.
    self.audioQueueBufferIndex = AUDIO_QUEUE_BUFFER_COUNT - 1;
    [self updateQueueWithState:AudioQueueStateReady notify:true];

    // Activate the audio session (this is necessary since WebRTC can turn OFF the AudioSession
    // if both participants put their microphone OFF: the audio_device is not used and turned OFF)
    self.audioSessionActive = YES;

    [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
        
        RTC_OBJC_TYPE(RTCAudioSession) *audioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
        [audioSession lockForConfiguration];
        NSError *error;
        if (![audioSession setActive:YES error:&error]) {
            DDLogError(@"set active: %@", error.localizedDescription);
        }
        [audioSession unlockForConfiguration];
    }];
}

- (void)audioStreamDataWithNumberBytes:(UInt32)numberBytes numberPackets:(UInt32)numberPackets inputData:(const void *)inputData packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions {
    DDLogVerbose(@"%@ audioStreamDataWithNumberBytes: %u numberPackets: %u", LOG_TAG, numberBytes, numberPackets);

    self.discontinuous = NO;

    UInt32 total = 0;
    AudioStreamPacketDescription desc;
    if (!packetDescriptions) {
        packetDescriptions = &desc;
        numberPackets = 1;
        desc.mDataByteSize = numberBytes;
        desc.mVariableFramesInPacket = 0;
        desc.mStartOffset = 0;
    }
    for (int i = 0; i < numberPackets; i++) {
        UInt32 size = packetDescriptions[i].mDataByteSize;
        AudioPacket_t *packet = (AudioPacket_t *) malloc(sizeof(AudioPacket_t) + size);

        packet->identifier = self.packetIdentifier;
        self.packetIdentifier++;

        /* Prepare the packet */
        packet->next = NULL;
        packet->desc = packetDescriptions[i];
        packet->desc.mStartOffset = 0;
        memcpy(packet->data, (const char *)inputData + packetDescriptions[i].mStartOffset, size);

        total += size;
        if (_firstPacket) {
            _lastPacket->next = packet;
            _lastPacket = packet;
        } else {
            _firstPacket = packet;
            _readPacket = packet;
            _lastPacket = packet;
        }
    }

    self.audioReadPendingSize += total;
    DDLogVerbose(@"%@ Pending size: %d", LOG_TAG, self.audioReadPendingSize);

    if (self.audioReadPendingSize > OUTPUT_BUFFER_SIZE) {
        dispatch_async(self.processQueue, ^{
            [self audioDecodePackets];
        });
    }
}

- (void)audioDecodePackets {
    DDLogVerbose(@"%@ audioDecodePackets", LOG_TAG);

    if (self.audioQueueState == AudioQueueStatePaused) {
        return;
    }

    int queued = 0;
    while (self.audioQueueBufferIndex > 0) {
        self.audioQueueBufferIndex--;
        AudioQueueBufferRef buffer = self.audioQueueBuffer[self.audioQueueBufferIndex];
        self.audioQueueBuffer[self.audioQueueBufferIndex] = 0;
        if ([self audioDecodePacketWithBuffer:buffer]) {
            break;
        }
        queued++;
    }

    // If the audio queue is ready but not started and we added some audio data,
    // start the audio queue.
    if (self.audioQueueState == AudioQueueStateReady && queued > 0) {
        
        OSStatus err = AudioQueueStart(self.audioQueue, nil);
        DDLogVerbose(@"%@AudioQueueStart result: %d", LOG_TAG, err);
        if (err) {
            [self updateQueueWithState:AudioQueueStateError notify:true];
        } else {
            [self updateQueueWithState:AudioQueueStateRunning notify:true];
        }
    }

    [self requestFillBuffers];
}

- (void)audioQueueIsRunningWithProperty:(AudioQueuePropertyID)property {
    DDLogVerbose(@"%@ audioQueueIsRunningWithProperty: %d", LOG_TAG, property);

    if (self.audioQueueState == AudioQueueStateDeleted) {
        return;
    }

    UInt32 running;
    UInt32 output = sizeof(running);
    OSStatus err = AudioQueueGetProperty(self.audioQueue, kAudioQueueProperty_IsRunning, &running, &output);
    if (err) {
        DDLogError(@"%@: error in kAudioQueueProperty_IsRunning: %d", LOG_TAG, err);
        [self updateQueueWithState:AudioQueueStateError notify:true];
        return;
    }

    if (running) {
        [self updateQueueWithState:AudioQueueStateRunning notify:true];
    } else {
        [self updateQueueWithState:AudioQueueStateIdle notify:true];
    }
}

- (OSStatus)encoderDataWithNumber:(nonnull UInt32 *)numberDataPackets data:(nonnull AudioBufferList *)data packetDescription:(AudioStreamPacketDescription **)packetDescription {
    // DDLogVerbose(@"%@ encoderDataWithNumber", LOG_TAG);

    AudioPacket_t *audioPacket = self.readPacket;
    if (audioPacket) {
        self.readPacket = audioPacket->next;
        self.audioReadPendingSize -= audioPacket->desc.mDataByteSize;
        *numberDataPackets = 1;
        data->mBuffers[0].mData = audioPacket->data;
        data->mBuffers[0].mDataByteSize = audioPacket->desc.mDataByteSize;
        data->mBuffers[0].mNumberChannels = self.srcFormat.mChannelsPerFrame;
        DDLogVerbose(@"%@ encoderDataWithNumber return packet with size %d", LOG_TAG, audioPacket->desc.mDataByteSize);

        if (packetDescription) {
            *packetDescription = &audioPacket->desc;
        }
    } else {
        *numberDataPackets = 0;
        DDLogVerbose(@"%@ encoderDataWithNumber last packet found", LOG_TAG);
    }

    AudioPacket_t *freePacket = self.firstPacket;
    if (freePacket) {
        if (freePacket != audioPacket) {
            self.firstPacket = freePacket->next;

            // Release a previous packet which is not used now.
            free((void*)freePacket);
        }
    }

    return noErr;
}

- (void)audioReleaseWithBuffer:(AudioQueueBufferRef)buffer {
    DDLogVerbose(@"%@ audioReleaseWithBuffer", LOG_TAG);

    if (self.audioQueueBuffer) {
        self.audioQueueBuffer[self.audioQueueBufferIndex] = buffer;
        self.audioQueueBufferIndex++;
        DDLogVerbose(@"%@ audioReleaseWithBuffer count: %d state: %d", LOG_TAG, self.audioQueueBufferIndex, self.audioQueueState);
        if (self.audioQueueBufferIndex == AUDIO_QUEUE_BUFFER_COUNT - 1 && self.endOfStream) {
            [self updateQueueWithState:AudioQueueStateCompleted notify:true];
        }

        if (!self.endOfStream) {
            [self requestFillBuffers];
        }
    }
}

- (OSStatus)audioDecodePacketWithBuffer:(AudioQueueBufferRef)buffer {
    DDLogVerbose(@"%@ audioDecodePacketWithBuffer %p", LOG_TAG, buffer);

    if (self.audioQueueState != AudioQueueStateRunning && self.audioQueueState != AudioQueueStateReady) {
        DDLogVerbose(@"%@ audioDecodePacket stopping", LOG_TAG);

        // Put back this buffer in the free list.
        [self audioReleaseWithBuffer:buffer];
        return -1;
    }

    if (self.audioReadPendingSize < OUTPUT_BUFFER_SIZE && !self.endOfStream) {
        DDLogVerbose(@"%@ audioDecodePacket waiting more data (current: %d)", LOG_TAG, self.audioReadPendingSize);

        [self audioReleaseWithBuffer:buffer];
        return -1;
    }

    AudioBufferList outputBufferList;
    outputBufferList.mNumberBuffers = 1;
    outputBufferList.mBuffers[0].mNumberChannels = self.dstFormat.mChannelsPerFrame;
    outputBufferList.mBuffers[0].mDataByteSize = OUTPUT_BUFFER_SIZE;
    outputBufferList.mBuffers[0].mData = buffer->mAudioData;

    void* audioData = buffer->mAudioData;
    UInt32 audioSize = 0;
    UInt32 count = 0;
    while (audioSize < STREAM_BUFFER_SIZE - 500 && count < 32) {
        UInt32 numberDataPackets;
        [self encoderDataWithNumber:&numberDataPackets data:&outputBufferList packetDescription:nil];
        if (numberDataPackets > 0) {
            memcpy(audioData, outputBufferList.mBuffers[0].mData, outputBufferList.mBuffers[0].mDataByteSize);
            buffer->mPacketDescriptions[count].mStartOffset = audioSize;
            buffer->mPacketDescriptions[count].mDataByteSize = outputBufferList.mBuffers[0].mDataByteSize;
            buffer->mPacketDescriptions[count].mVariableFramesInPacket = 0;
            audioData = audioData + outputBufferList.mBuffers[0].mDataByteSize;
            audioSize += outputBufferList.mBuffers[0].mDataByteSize;
            count++;
        } else {
            break;
        }
    }

    if (audioSize == 0) {
        DDLogVerbose(@"%@ audioDecodePacket produced no data", LOG_TAG);

        [self audioReleaseWithBuffer:buffer];
        return -1;
    }

    buffer->mPacketDescriptionCount = count;
    buffer->mAudioDataByteSize = audioSize; // ioOutputDataPackets * self.dstFormat.mBytesPerPacket;
    DDLogVerbose(@"%@ AudioQueueEnqueueBuffer buffer size: %d packetCount: %d pendingSize: %d", LOG_TAG, buffer->mAudioDataByteSize, count, self.audioReadPendingSize);
    OSStatus err = AudioQueueEnqueueBuffer(self.audioQueue, buffer, 0, nil);
    if (err) {
        DDLogError(@"%@ AudioQueueEnqueueBuffer result: %d", LOG_TAG, err);
        [self audioReleaseWithBuffer:buffer];
    }

    if (!self.endOfStream) {
        [self requestFillBuffers];
    }
    return err;
}

@end
