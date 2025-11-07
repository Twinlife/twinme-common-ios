/*
 *  Copyright (c) 2022-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <WebRTC/RTCVideoTrack.h>

#import "CallParticipant.h"
#import "CallConnection.h"
#import "StreamPlayer.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: CallParticipant ()
//

@interface CallParticipant ()

@property (nonatomic, readonly, nullable, weak) CallConnection *callConnection;
@property (nonatomic, nullable) RTC_OBJC_TYPE(RTCVideoTrack) *currentRemoteVideoTrack;
@property (nonatomic, nullable) id<RTC_OBJC_TYPE(RTCVideoRenderer)> currentView;
@property (nonatomic, nullable) NSString *participantName;
@property (nonatomic, nullable) NSString *participantDescription;
@property (nonatomic, nullable) UIImage *participantAvatar;
@property (nonatomic, nullable) NSString *audioTrackId;
@property (nonatomic, nullable) NSString *videoTrackId;

@end

//
// Implementation: CallParticipant
//

#undef LOG_TAG
#define LOG_TAG @"CallParticipant"

@implementation CallParticipant

- (nonnull instancetype)initWithCallConnection:(nonnull CallConnection *)callConnection name:(nullable NSString *)name description:(nullable NSString *)description participantId:(int)participantId {
    DDLogVerbose(@"%@ initWithCallConnection: %@ name: %@ description: %@ participantId: %d", LOG_TAG, callConnection, name, description, participantId);
    
    self = [super init];
    if (self) {
        _participantId = participantId;
        _callConnection = callConnection;
        _currentRemoteVideoTrack = nil;
        _currentView = nil;
        _participantName = name;
        _participantDescription = description;
        _audioTrackId = nil;
        _videoTrackId = nil;
        _isAudioMute = YES;
        _isVideoMute = YES;
        _transferredToParticipantId = nil;
        _transferredFromParticipantId = nil;
        _isCallReceiver = NO;
    }

    return self;
}

- (nullable UIImage *)avatar {
    DDLogVerbose(@"%@ avatar", LOG_TAG);

    @synchronized (self) {
        return self.participantAvatar;
    }
}

- (nullable NSString *)name {
    DDLogVerbose(@"%@ name", LOG_TAG);

    @synchronized (self) {
        return self.participantName;
    }
}

- (nullable NSString *)description {
    DDLogVerbose(@"%@ description", LOG_TAG);

    @synchronized (self) {
        return self.participantDescription;
    }
}

- (nonnull NSUUID *)participantPeerTwincodeOutboundId {
    DDLogVerbose(@"%@ participantPeerTwincodeOutboundId", LOG_TAG);
    
    return self.callConnection.peerTwincodeOutboundId;
}

- (nullable NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ peerConnectionId", LOG_TAG);

    return self.callConnection.peerConnectionId;
}

- (nullable RTC_OBJC_TYPE(RTCVideoTrack) *)remoteVideoTrack {
    DDLogVerbose(@"%@ remoteVideoTrack", LOG_TAG);

    return self.currentRemoteVideoTrack;
}

- (CallGroupSupport)isGroupSupported {
    
    return [self.callConnection isGroupSupported];
}

- (CallMessageSupport)isMessageSupported {
    
    return [self.callConnection isMessageSupported];
}

- (CallGeolocationSupport)isGeolocationSupported {
    
    return [self.callConnection isGeolocationSupported];
}

- (StreamingStatus)streamingStatus {

    return [self.callConnection streamingStatus];
}

- (TLVideoZoomable)isZoomable {
    
    return [self.callConnection isZoomable];
}

- (CallStatus)callStatus {
    
    return self.callConnection.status;
}

- (nullable NSString *)memberId {
    return self.callConnection.callRoomMemberId;
}

- (nullable TLGeolocationDescriptor *)currentGeolocation {
    
    return self.callConnection.currentGeolocation;
}

- (BOOL)isRemoteCameraControl {
    
    return [self.callConnection isRemoteControlGranted] || self.remoteActiveCamera > 0;
}

- (nullable StreamPlayer *)streamPlayer {
    DDLogVerbose(@"%@ streamPlayer", LOG_TAG);

    return [self.callConnection streamPlayer];
}

- (void)attachWithRenderer:(nonnull id<RTC_OBJC_TYPE(RTCVideoRenderer)>)view {
    DDLogVerbose(@"%@ attachWithRenderer: %@", LOG_TAG, view);

    RTC_OBJC_TYPE(RTCVideoTrack) *video;
    id<RTC_OBJC_TYPE(RTCVideoRenderer)> oldView;
    @synchronized (self) {
        if (self.currentView == view) {
            return;
        }

        oldView = self.currentView;
        self.currentView = view;

        video = self.currentRemoteVideoTrack;
        if (!video) {
            return;
        }
    }

    // Avoid blocking the main UI thread (be careful: callConnection is a weak pointer).
    dispatch_queue_t dispatchQueue = [self.callConnection twinlifeQueue];
    if (dispatchQueue) {
        dispatch_async(dispatchQueue, ^{
            // Detach a previous view first if there was one.
            if (oldView) {
                [video removeRenderer:oldView];
            }
            [video addRenderer:view];
        });
    }
}

- (void)detachRenderer {
    DDLogVerbose(@"%@ detachWithRenderer", LOG_TAG);

    id<RTC_OBJC_TYPE(RTCVideoRenderer)> view;
    RTC_OBJC_TYPE(RTCVideoTrack) *video;
    @synchronized (self) {
        view = self.currentView;
        if (!view) {
            return;
        }

        self.currentView = nil;

        video = self.currentRemoteVideoTrack;
        if (!video) {
            return;
        }
    }

    // Avoid blocking the main UI thread (be careful: callConnection is a weak pointer).
    dispatch_queue_t dispatchQueue = [self.callConnection twinlifeQueue];
    if (dispatchQueue) {
        dispatch_async(dispatchQueue, ^{
            [video removeRenderer:view];
        });
    }
}

- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description avatar:(nullable UIImage *)avatar {
    DDLogVerbose(@"%@ updateWithName: %@ description: %@", LOG_TAG, name, description);

    @synchronized (self) {
        self.participantAvatar = avatar;
        self.participantName = name;
        self.participantDescription = description;
    }
}

- (CallTrackKind)addWithTrack:(nonnull RTC_OBJC_TYPE(RTCMediaStreamTrack) *)track {
    DDLogVerbose(@"%@ addWithTrack: %@", LOG_TAG, track);

    BOOL isAudio = [[track kind] isEqualToString:kRTCMediaStreamTrackKindAudio];
    NSString *trackId = [track trackId];
    id<RTC_OBJC_TYPE(RTCVideoRenderer)> view = nil;
    RTC_OBJC_TYPE(RTCVideoTrack) *video = nil;
    @synchronized (self) {
        if (isAudio) {
            self.audioTrackId = trackId;
        } else {
            self.videoTrackId = trackId;
            self.currentRemoteVideoTrack = (RTC_OBJC_TYPE(RTCVideoTrack) *)track;
            if (self.currentView) {
                view = self.currentView;
                video = self.currentRemoteVideoTrack;
            }
        }
    }

    if (view && video) {
        // We are not called from the main UI thread, it is safe to do the addRenderer now.
        [video addRenderer:view];
    }
    return isAudio ? CallTrackKindAudio : CallTrackKindVideo;
}

- (CallTrackKind)removeWithTrackId:(nonnull NSString *)trackId {
    DDLogVerbose(@"%@ removeWithTrackId: %@", LOG_TAG, trackId);

    CallTrackKind result;
    id<RTC_OBJC_TYPE(RTCVideoRenderer)> view = nil;
    RTC_OBJC_TYPE(RTCVideoTrack) *video = nil;
    @synchronized (self) {
        if ([trackId isEqualToString:self.audioTrackId]) {
            self.audioTrackId = nil;
            result = CallTrackKindAudio;
        } else if ([trackId isEqualToString:self.videoTrackId]) {
            self.videoTrackId = nil;
            if (self.currentRemoteVideoTrack && self.currentView) {
                view = self.currentView;
                video = self.currentRemoteVideoTrack;
            }
            self.currentRemoteVideoTrack = nil;
            result = CallTrackKindVideo;
        } else {
            result = CallTrackKindNone;
        }
    }

    if (view && video) {
        // We are not called from the main UI thread, it is safe to do the removeRenderer now.
        [video removeRenderer:view];
    }
    return result;
}

- (void) transferWithParticipant:(CallParticipant *)transferredParticipant {
    [self updateWithName:transferredParticipant.name description:transferredParticipant.participantDescription avatar:transferredParticipant.avatar];
    self.transferredFromParticipantId = [[NSNumber alloc] initWithInt:transferredParticipant.participantId];
    transferredParticipant.transferredToParticipantId = [[NSNumber alloc] initWithInt:self.participantId];
}

- (void)releaseParticipant {
    DDLogVerbose(@"%@ releaseParticipant: %@", LOG_TAG, self.participantName);

    id<RTC_OBJC_TYPE(RTCVideoRenderer)> view;
    RTC_OBJC_TYPE(RTCVideoTrack) *video;
    @synchronized (self) {
        view = self.currentView;
        video = self.currentRemoteVideoTrack;

        // Invalidate currentView and remove video track: we are releasing and don't want
        // a possible attachWithRenderer (executed by the main UI thread) to change things again.
        self.currentView = nil;
        self.currentRemoteVideoTrack = nil;
    }
    if (!view || !video) {
        return;
    }

    // Avoid blocking the main UI thread (be careful: callConnection is a weak pointer).
    dispatch_queue_t dispatchQueue = [self.callConnection twinlifeQueue];
    if (dispatchQueue) {
        dispatch_async(dispatchQueue, ^{
            [video removeRenderer:view];
        });
    }
}
/// Ask the peer to get the control of its camera.
- (void)remoteAskControl {
    
    [self.callConnection sendCameraControlWithMode:CameraControlModeCheck camera:0 scale:0];
}

/// Answer to GRANT/DENY access to our camera to the peer.
- (void)remoteAnswerControlWithGrant:(BOOL)grant {
    
    if (grant) {
        [self.callConnection sendCameraControlGrant];
    } else {
        [self.callConnection sendCameraResponseWithError:TLBaseServiceErrorCodeNoPermission cameraBitmap:0 activeCamera:0 minScale:0 maxScale:0];
    }
}

/// Stop controlling the peer camera.
- (void)remoteStopControl {

    // The STOP can be sent by both participants.
    [self.callConnection sendCameraStop];
}

/// Zoom on the peer camera.
- (void)remoteCameraSetWithZoom:(float)zoom {
    
    if (self.remoteActiveCamera > 0) {
        [self.callConnection sendCameraControlWithMode:CameraControlModeZoom camera:0 scale:(int)zoom];
    }
}

/// Switch the peer camera to the front or back camera if we are allowed.
- (void)remoteSwitchCameraWithFront:(BOOL)front {
    
    if (self.remoteActiveCamera > 0) {
        [self.callConnection sendCameraControlWithMode:CameraControlModeSelect camera:front ? 1 : 2 scale:0];
    }
}

/// Turn ON/OFF the camera of the peer if we are allowed to
- (void)remoteCameraWithMute:(BOOL)mute {
    
    if (self.remoteActiveCamera > 0) {
        [self.callConnection sendCameraControlWithMode:mute ? CameraControlModeOFF : CameraControlModeON camera:0 scale:0];
    }
}

@end
