/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVAssetExportSession.h>
#import <ImageIO/ImageIO.h>
#import <Photos/Photos.h>
#import <MediaPlayer/MPMediaItem.h>
#import <MediaPlayer/MediaPlayer.h>

#import "CallState.h"
#import "CallConnection.h"
#import "Streamer.h"
#import "StreamPlayer.h"
#import "StreamingControlIQ.h"
#import "StreamingRequestIQ.h"
#import "StreamingInfoIQ.h"
#import "StreamingDataIQ.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define STREAMER_IMAGE_SIZE          512
#define IMAGE_JPEG_QUALITY           0.8

// Maximum latency that we take into account for the pause/resume to synchronize the streamer and player.
// Above 1s, such latency is ignored as a protection as it could delay the pause/resume too much.
#define MAX_LATENCY  1000

//
// Interface: RemotePlayerInfo
//

@interface RemotePlayerInfo : NSObject

@property (nonatomic) int64_t position;
@property (nonatomic) int64_t lastDate;
@property (nonatomic) int latency;
@property (nonatomic) BOOL paused;

- (int64_t)positionWithTime:(int64_t)now;

@end

//
// Interface: Streamer
//

@interface Streamer ()

@property (nonatomic, readonly, nonnull) MPMediaItem *mediaItem;
@property (nonatomic, readonly, nonnull) NSString *temporaryFile;
@property (nonatomic, readonly, nonnull) dispatch_queue_t readQueue;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSUUID *, RemotePlayerInfo*> *remotePlayers;
@property (nonatomic, nullable) AVAssetExportSession *exportSession;
@property (nonatomic, nullable) NSFileHandle *fileHandle;
@property (nonatomic) int64_t position;
@property (nonatomic) int64_t lastPosition;
@property (nonatomic) int64_t startTime;

/// Start streaming with a local file path.
- (void)startStreamingWithPath:(nonnull NSString *)path;

/// Send a stream start IQ to each peer that is connected through the current call.
- (void)sendStreamStart;

/// Send a stream control IQ to each peer that is connected through the current call.
- (void)sendStreamControlWithMode:(StreamingControlMode)mode length:(int64_t)length timestamp:(int64_t)timestamp streamerPosition:(int64_t)streamerPosition;

/// Read the data block at the given offset (this method must be called from the readQueue).
- (nullable NSData *)readBlockWithOffset:(int64_t)offset length:(int64_t)length request:(int64_t)request;

@end

//
// Implementation: RemotePlayerInfo
//

#undef LOG_TAG
#define LOG_TAG @"RemotePlayerInfo"

@implementation RemotePlayerInfo

- (int64_t)positionWithTime:(int64_t)now {
    
    if (self.paused) {
        return self.position;
    } else {
        return self.position + (now - self.lastDate) + (int64_t)self.latency;
    }
}

@end

//
// Implementation: Streamer
//

#undef LOG_TAG
#define LOG_TAG @"Streamer"

@implementation Streamer

- (nonnull instancetype)initWithCall:(nonnull CallState *)call ident:(int64_t)ident mediaItem:(nonnull MPMediaItem *)mediaItem {
    DDLogVerbose(@"%@ initWithCall: %@ ident: %lld mediaItem: %@", LOG_TAG, call, ident, mediaItem);
    
    self = [super init];
    if (self) {
        _call = call;
        _mediaItem = mediaItem;
        _video = NO;
        _remotePlayers = [[NSMutableDictionary alloc] init];
        _temporaryFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"streaming.caf"];
        NSFileManager *fileMgr = [NSFileManager defaultManager];
        if ([fileMgr fileExistsAtPath:_temporaryFile]) {
            [fileMgr removeItemAtPath:self.temporaryFile error:nil];
        }
        _position = 0;
        _ident = ident;
        _readQueue = dispatch_queue_create("streamReadQueue", DISPATCH_QUEUE_SERIAL);
        _localPlayer = [[StreamPlayer alloc] initWithIdent:ident size:0 video:_video call:call connection:nil streamer:self];
        if (mediaItem) {
            UIImage *artworkImage = [mediaItem.artwork imageWithSize:CGSizeMake(STREAMER_IMAGE_SIZE, STREAMER_IMAGE_SIZE)];
            [_localPlayer setInformationWithTitle:mediaItem.title album:mediaItem.albumTitle artist:mediaItem.artist artwork:artworkImage duration:mediaItem.playbackDuration];
        }
        
    }
    return self;
}

- (void)startStreaming {
    DDLogVerbose(@"%@ startStreaming", LOG_TAG);
    
    [self.call onStreamingEventWithParticipant:nil event:StreamingEventStart];
    NSURL *assetURL = [self.mediaItem assetURL];
    if ([assetURL isFileURL]) {
        [self startStreamingWithPath:[assetURL path]];
    } else {
        AVAsset *asset = [AVAsset assetWithURL:assetURL];
        self.exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetPassthrough];
        self.exportSession.outputURL = [NSURL fileURLWithPath:self.temporaryFile];
        self.exportSession.outputFileType = AVFileTypeCoreAudioFormat;
        self.exportSession.shouldOptimizeForNetworkUse = YES;
        [self.exportSession exportAsynchronouslyWithCompletionHandler:^{
            switch ([self.exportSession status]) {
                case AVAssetExportSessionStatusCompleted:
                    [self startStreamingWithPath:self.temporaryFile];
                    break;
                    
                case AVAssetExportSessionStatusCancelled:
                    break;
                    
                default: {
                    NSError *error = [self.exportSession error];
                    DDLogError(@"%@ startStreaming export failed: %@", LOG_TAG, error);
                    [self.call onStreamingEventWithParticipant:nil event:StreamingEventError];
                    break;
                }
            }
            self.exportSession = nil;
        }];
    }
}

- (void)startStreamingWithPath:(nonnull NSString *)path {
    DDLogVerbose(@"%@ startStreamingWithPath: %@", LOG_TAG, path);

    self.fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    [self.fileHandle seekToEndOfFile];
    self.lastPosition = [self.fileHandle offsetInFile];
    self.position = self.lastPosition;
    
    [self sendStreamStart];
}

- (void)pauseStreaming {
    DDLogVerbose(@"%@ pauseStreaming", LOG_TAG);

    // Compute the max current position for all players and our local player.
    int64_t streamerPosition = (self.localPlayer ? [self.localPlayer playerPosition] : 0);
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    int64_t maxPosition = streamerPosition;
    int minLatency = INT_MAX;

    DDLogVerbose(@"%@ pauseStreaming currentPosition=%lld time=%lld", LOG_TAG, streamerPosition, now - self.startTime);
    @synchronized (self) {
        for (NSUUID *peerId in self.remotePlayers) {
            RemotePlayerInfo *remotePlayerInfo = self.remotePlayers[peerId];
            if (remotePlayerInfo) {
                // Guess the position of the remote player when it will receive the pause request.
                // Hence, we add its latency for the time to receive the IQ.
                int64_t position = [remotePlayerInfo positionWithTime:now];
                DDLogVerbose(@"%@ pauseStreaming remotePosition=%lld computedPosition=%lld at time=%lld", LOG_TAG, remotePlayerInfo.position, position, remotePlayerInfo.lastDate - self.startTime);
                if (maxPosition < position) {
                    maxPosition = position;
                }
                if (remotePlayerInfo.latency > 0 && minLatency > remotePlayerInfo.latency) {
                    minLatency = remotePlayerInfo.latency;
                }
            }
        }
    }
    if (minLatency > MAX_LATENCY) {
        minLatency = 0;
    }

    [self sendStreamControlWithMode:StreamingControlModePause length:maxPosition timestamp:now streamerPosition:streamerPosition];
    [self.call onStreamingEventWithParticipant:nil event:StreamingEventPaused];
    if (self.localPlayer) {
        int64_t delay = maxPosition + (int64_t)minLatency - streamerPosition;
        if (delay < 0) {
            delay = 0;
        }
        DDLogVerbose(@"%@ pauseStreaming must delay=%lld (ms) local player", LOG_TAG, delay);
        [self.localPlayer pauseWithDelay:dispatch_time(DISPATCH_TIME_NOW, delay * 1000000LL)];
    }
}

- (void)resumeStreaming {
    DDLogVerbose(@"%@ resumeStreaming", LOG_TAG);

    // Compute the min current position for all players and our local player.
    // This indicates the time we have to wait for the player that is stopped too early.
    int64_t streamerPosition = (self.localPlayer ? [self.localPlayer playerPosition] : 0);
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    int64_t minPosition = streamerPosition;
    int minLatency = INT_MAX;

    DDLogVerbose(@"%@ resumeStreaming currentPosition=%lld time=%lld", LOG_TAG, streamerPosition, now - self.startTime);
    @synchronized (self) {
        for (NSUUID *peerId in self.remotePlayers) {
            RemotePlayerInfo *remotePlayerInfo = self.remotePlayers[peerId];
            if (remotePlayerInfo) {
                int64_t position = [remotePlayerInfo positionWithTime:now];
                DDLogVerbose(@"%@ resumeStreaming remotePosition=%lld at time=%lld", LOG_TAG, position, remotePlayerInfo.lastDate - self.startTime);
                if (minPosition > position) {
                    minPosition = position;
                }
                if (remotePlayerInfo.latency > 0 && minLatency > remotePlayerInfo.latency) {
                    minLatency = remotePlayerInfo.latency;
                }
            }
        }
    }
    if (minLatency > MAX_LATENCY) {
        minLatency = 0;
    }

    [self sendStreamControlWithMode:StreamingControlModeResume length:minPosition timestamp:now streamerPosition:streamerPosition];
    [self.call onStreamingEventWithParticipant:nil event:StreamingEventPlaying];
    if (self.localPlayer) {
        int64_t delay = streamerPosition - minPosition + (int64_t)minLatency;
        if (delay < 0) {
            delay = 0;
        }
        DDLogVerbose(@"%@ resumeStreaming must delay=%lld (ms) local player", LOG_TAG, delay);

        [self.localPlayer resumeWithDelay:dispatch_time(DISPATCH_TIME_NOW, delay * 1000000LL)];
    }
}

- (void)seekStreamingWithPosition:(long)position {
    DDLogVerbose(@"%@ seekStreamingWithPosition: %ld", LOG_TAG, position);

    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    [self sendStreamControlWithMode:StreamingControlModeSeek length:position timestamp:now streamerPosition:position];
    if (self.localPlayer) {
        [self.localPlayer seekWithPosition:position];
    }
}

- (void)stopStreamingWithNotify:(BOOL)notify {
    DDLogVerbose(@"%@ stopStreamingWithNotify: %d", LOG_TAG, notify);

    if (self.exportSession) {
        [self.exportSession cancelExport];
    }

    if (notify) {
        [self sendStreamControlWithMode:StreamingControlModeStop length:0 timestamp:0 streamerPosition:0];
    }

    if (self.localPlayer) {
        [self.localPlayer stopWithNotify:NO];
        self.localPlayer = nil;
    }

    if (self.fileHandle) {
        [self.fileHandle closeFile];
        self.fileHandle = nil;
    }

    [self.call onStreamingEventWithParticipant:nil event:StreamingEventStop];

    NSFileManager *fileMgr = [NSFileManager defaultManager];
    [fileMgr removeItemAtPath:self.temporaryFile error:nil];
}

- (void)updateLocalPlayerWithMode:(StreamingControlMode)mode offset:(int64_t)offset {
    DDLogVerbose(@"%@ updateLocalPlayerWithMode: %d offset: %lld", LOG_TAG, mode, offset);

    StreamingEvent event;
    BOOL mustStop = NO;
    switch (mode) {
        case StreamingControlModeStatusPlaying:
            event = StreamingEventPlaying;
            break;

        case StreamingControlModeStatusReady:
            event = StreamingEventStart;
            break;

        case StreamingControlModeStatusUnSupported:
            event = StreamingEventUnsupported;
            mustStop = YES;
            break;

        case StreamingControlModeStatusError:
            event = StreamingEventError;
            mustStop = YES;
            break;

        case StreamingControlModeStatusStopped:
            event = StreamingEventStop;
            break;

        case StreamingControlModeStatusCompleted:
            event = StreamingEventCompleted;
            break;

        default:
            return;
    }
    [self.call onStreamingEventWithParticipant:nil event:event];
    if (mustStop) {
        [self.call stopStreaming];
    }
}

- (void)sendStreamStart {
    DDLogVerbose(@"%@ sendStreamStart", LOG_TAG);

    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    self.startTime = now;
    StreamingControlIQ *streamingControlIQ = [[StreamingControlIQ alloc] initWithSerializer:[CallConnection STREAMING_CONTROL_SERIALIZER] requestId:[self.call allocateRequestId] ident:self.ident mode:self.video ? StreamingControlModeStartVideo : StreamingControlModeStartAudio length:0 timestamp:now position:0 latency:0];
    
    StreamingInfoIQ *streamingInfoIQ = nil;
    if (self.mediaItem.title) {
        NSData *artwork = nil;
        MPMediaItemArtwork *artworkItem = [self.mediaItem valueForProperty: MPMediaItemPropertyArtwork];
        UIImage *artworkImage = [artworkItem imageWithSize:CGSizeMake(STREAMER_IMAGE_SIZE, STREAMER_IMAGE_SIZE)];
        if (artworkImage) {
            artwork = UIImageJPEGRepresentation(artworkImage, IMAGE_JPEG_QUALITY);
        }
        
        streamingInfoIQ = [[StreamingInfoIQ alloc] initWithSerializer:[CallConnection STREAMING_INFO_SERIALIZER] requestId:[self.call allocateRequestId] ident:self.ident title:self.mediaItem.title album:self.mediaItem.albumTitle artist:self.mediaItem.artist artwork:artwork duration:(int64_t)self.mediaItem.playbackDuration];
    }
    
    NSArray<CallConnection *> *connections = [self.call getConnections];
    for (CallConnection *connection in connections) {
        StreamingStatus status = [connection streamingStatus];
        if (IS_STREAMING_SUPPORTED(status)) {
            NSUUID *peerConnectionId = [connection peerConnectionId];
            if (peerConnectionId) {
                [self.remotePlayers setObject:[[RemotePlayerInfo alloc] init] forKey:peerConnectionId];
                [connection sendMessageWithIQ:streamingControlIQ statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
                if (streamingInfoIQ) {
                    [connection sendMessageWithIQ:streamingInfoIQ statType:(TLPeerConnectionServiceStatType)TLPeerConnectionServiceStatTypeIqSetPushObject];
                }
                
                [connection updatePeerWithStreamingStatus:StreamingStatusReady];
            }
        }
    }

    if (self.localPlayer) {
        [self.localPlayer start];
    }
}

- (void)sendStreamControlWithMode:(StreamingControlMode)mode length:(int64_t)length timestamp:(int64_t)timestamp streamerPosition:(int64_t)streamerPosition {
    DDLogVerbose(@"%@ sendStreamControlWithMode: %d length: %lld timestamp: %lld streamerPosition: %lld", LOG_TAG, mode, length, timestamp - self.startTime, streamerPosition);

    StreamingControlIQ *streamingControlIQ = [[StreamingControlIQ alloc] initWithSerializer:[CallConnection STREAMING_CONTROL_SERIALIZER] requestId:[self.call allocateRequestId] ident:self.ident mode:mode length:length timestamp:timestamp position:streamerPosition latency:0];
    NSArray<CallConnection *> *connections = [self.call getConnections];
    for (CallConnection *connection in connections) {
        StreamingStatus status = [connection streamingStatus];
        if (IS_STREAMING_SUPPORTED(status)) {
            [connection sendMessageWithIQ:streamingControlIQ statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
        }
    }
}

- (void)onStreamingControlWithConnection:(nonnull CallConnection *)connection iq:(nonnull StreamingControlIQ *)iq {
    DDLogVerbose(@"%@ onStreamingControlWithConnection: %@", LOG_TAG, iq);
    
    if (iq.ident != self.ident) {
        return;
    }

    int64_t receiveTime = [[NSDate date] timeIntervalSince1970] * 1000;
    NSUUID *peerConnectionId = [connection peerConnectionId];
    if (!peerConnectionId) {
        return;
    }

    RemotePlayerInfo *playerInfo = self.remotePlayers[peerConnectionId];
    if (!playerInfo) {
        return;
    }
    playerInfo.lastDate = receiveTime;
    if (iq.latency < MAX_LATENCY) {
        playerInfo.latency = iq.latency;

    }
    // The peer's player real position is now ahead of at least the latency.
    if (iq.mode != StreamingControlModeStatusPaused) {
        playerInfo.position = iq.position + iq.latency;
    } else {
        playerInfo.position = iq.position;
    }

    int64_t streamerPosition = (self.localPlayer ? [self.localPlayer playerPosition] : 0);

    DDLogVerbose(@"%@ player %@ position=%lld streamerPos=%lld dt=%lld time=%lld", LOG_TAG, peerConnectionId, iq.position, streamerPosition, streamerPosition - iq.position, receiveTime - self.startTime);

    switch (iq.mode) {
        case StreamingControlModeAskPause:
            [self pauseStreaming];
            break;

        case StreamingControlModeAskResume:
            [self resumeStreaming];
            break;

        case StreamingControlModeAskSeek:
            [self seekStreamingWithPosition:(long)iq.length];
            break;

        case StreamingControlModeAskStop:
            [self stopStreamingWithNotify:YES];
            break;

        case StreamingControlModeStatusPlaying:
            playerInfo.paused = NO;
            [connection updatePeerWithStreamingStatus:StreamingStatusPlaying];
            break;

        case StreamingControlModeStatusPaused:
            playerInfo.paused = YES;
            [connection updatePeerWithStreamingStatus:StreamingStatusPaused];
            break;

        case StreamingControlModeStatusError:
            [connection updatePeerWithStreamingStatus:StreamingStatusError];
            break;

        case StreamingControlModeStatusUnSupported:
            [connection updatePeerWithStreamingStatus:StreamingStatusUnSupported];
            break;

        case StreamingControlModeStatusReady:
        case StreamingControlModeStatusCompleted:
            playerInfo.paused = YES;
            [connection updatePeerWithStreamingStatus:StreamingStatusReady];
            break;

        default:
            break;
    }
}

- (void)onStreamingRequestWithConnection:(nonnull CallConnection *)connection iq:(nonnull StreamingRequestIQ *)iq {
    DDLogVerbose(@"%@ onStreamingRequestWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    int64_t receiveTime = [[NSDate date] timeIntervalSince1970] * 1000;
    NSUUID *peerConnectionId = [connection peerConnectionId];
    if (!peerConnectionId) {
        return;
    }

    RemotePlayerInfo *playerInfo = self.remotePlayers[peerConnectionId];
    if (!playerInfo) {
        return;
    }
    playerInfo.lastDate = receiveTime;
    if (iq.lastRTT < MAX_LATENCY) {
        playerInfo.latency = iq.lastRTT;
    }
    if (playerInfo.paused) {
        playerInfo.position = iq.playerPosition;
    } else {
        playerInfo.position = iq.playerPosition + playerInfo.latency;
    }

    int64_t streamerPosition = (self.localPlayer ? [self.localPlayer playerPosition] : 0);
    DDLogVerbose(@"%@ player %@ position=%lld streamerPosition=%lld dt=%lld time=%lld", LOG_TAG, peerConnectionId, iq.playerPosition, streamerPosition, streamerPosition - iq.playerPosition, receiveTime - self.startTime);

    dispatch_async(self.readQueue, ^{
        NSData *data = [self readBlockWithOffset:iq.offset length:iq.length request:iq.requestId];

        int64_t streamerPosition = self.localPlayer ? [self.localPlayer playerPosition] : 0;
        int streamerLatency = (int) ([[NSDate date] timeIntervalSince1970] * 1000 - receiveTime);
        StreamingDataIQ *streamingDataIQ = [[StreamingDataIQ alloc] initWithSerializer:[CallConnection STREAMING_DATA_SERIALIZER] requestId:iq.requestId ident:self.ident offset:iq.offset streamerPosition:streamerPosition timestamp:iq.timestamp streamerLatency:streamerLatency data:data start:0 length:(int32_t)data.length];
        [connection sendMessageWithIQ:streamingDataIQ statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
    });
}

- (void)readAsyncBlockWithOffset:(int64_t)offset length:(int64_t)length withBlock:(nonnull void (^)(NSData *_Nullable data))block {
    DDLogVerbose(@"%@ readAsyncBlockWithOffset: %lld length: %lld", LOG_TAG, offset, length);

    dispatch_async(self.readQueue, ^{
        NSData *data = [self readBlockWithOffset:offset length:length request:0];
        
        block(data);
    });
}

- (nullable NSData *)readBlockWithOffset:(int64_t)offset length:(int64_t)length  request:(int64_t)request {
    DDLogVerbose(@"%@ readBlockWithOffset: %lld length: %lld", LOG_TAG, offset, length);

    NSData *data = nil;
    if (offset < self.lastPosition) {
        if (self.position != offset) {
            [self.fileHandle seekToFileOffset:offset];
        }
        data = [self.fileHandle readDataOfLength:length];
        self.position = offset + data.length;
    }
    // DDLogError(@"%@ readBlockWithOffset: %lld length: %lld position: %lld request: %lld", LOG_TAG, offset, (int64_t)data.length, self.position, request);

    return data;
}

@end
