/*
 *  Copyright (c) 2022-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLPeerConnectionService.h>
#import <Twinme/TLCapabilities.h>

#import "CallStatus.h"

@protocol RTC_OBJC_TYPE(RTCVideoRenderer);
@class CallConnection;
@class StreamPlayer;
@class TLDescriptor;
@class TLDescriptorId;
@class TLGeolocationDescriptor;

typedef enum {
    CallTrackKindNone,
    CallTrackKindAudio,
    CallTrackKindVideo
} CallTrackKind;

/**
 * A participant in an Audio or Video call.
 *
 * To support group calls in different architectures, a CallParticipant is separated from the CallConnection.
 *
 * We have to be careful that a participant can be one of our contact (in which case we know it) but it
 * can be a user that is not part of our contact list.  In that case, the name and avatar are not directly
 * known and they are provided by other means.
 *
 * The participant has:
 *
 * - a name, a description, an avatar,
 * - an internal RTCVideoTrack when the video is active and we receive the participant video stream,
 * - a RTCVideoRenderer view if we decide to display the video stream received from that participant,
 * - a set of audio/video status information
 *
 * The video track is attached and detached dynamically by two means:
 * - with attachWithRenderer and detachRenderer when the renderer view becomes visible or is destroyed,
 * - when addWithTrack or removeWithTrackId are called from WebRTC thread to indicate we receive a track or not.
 */
@interface CallParticipant : NSObject;

@property (readonly) int participantId;
/// If not null, indicates that this participant is the transfer target of the participant referenced by this ID.
@property (nonatomic, nullable) NSNumber *transferredFromParticipantId;
/// If not null, indicates that this participant has been transferred to the participant referenced by this ID.
@property (nonatomic, nullable) NSNumber *transferredToParticipantId;

/// Get the UUID that this participant is using to emit messages during the call.
@property (nonatomic, nullable) NSUUID *senderId;

/// Returns true if the participant has muted the microphone.
@property (nonatomic) BOOL isAudioMute;

/// Returns true if the participant has muted the camera.
@property (nonatomic) BOOL isVideoMute;

@property (nonatomic) BOOL isCallReceiver;

/// Returns true if the peer is sharing a screen or a window.
@property (nonatomic) BOOL isScreenSharing;

/// When > 0, the peer camera (1=FRONT, 2=BACK) that we control.
@property (nonatomic) int remoteActiveCamera;

/// Returns true if user ask for camera control and waiting for peer response.
@property (nonatomic) BOOL isWaitingForCameraControlAnswer;

- (nonnull instancetype)initWithCallConnection:(nonnull CallConnection *)callConnection name:(nullable NSString *)name description:(nullable NSString *)description participantId:(int)participantId;

/// Get the participant avatar (it could come from the Contact but also provided by other means for group calls).
- (nullable UIImage *)avatar;

/// Get the participant name (it could come from the Contact but also provided by other means for group calls).
- (nullable NSString *)name;

/// Get the participant description (it could come from the Contact but also provided by other means for group calls).
- (nullable NSString *)description;

/// Get the participant peertwincodeOutboundId from the callConnection
- (nonnull NSUUID *)participantPeerTwincodeOutboundId;

/// Get the peer connection id associated with this participant.
- (nullable NSUUID *)peerConnectionId;

/// Check if this participant supports P2P group calls.
- (CallGroupSupport)isGroupSupported;

/// Check if this participant supports receiving messages in P2P calls.
- (CallMessageSupport)isMessageSupported;

/// Check if this participant supports receiving geolocation in P2P calls.
- (CallGeolocationSupport)isGeolocationSupported;

/// Get the audio streaming status.
- (StreamingStatus)streamingStatus;

/// Check if this connection supports control camera by peer in P2P calls.
- (TLVideoZoomable)isZoomable;

/// Get the audio stream player
- (nullable StreamPlayer *)streamPlayer;

/// Attach a renderer to the video track.
- (void)attachWithRenderer:(nonnull id<RTC_OBJC_TYPE(RTCVideoRenderer)>)view;

/// Detach the renderer from the video track.
- (void)detachRenderer;

/// Update the participant with the name and avatar information.
- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description avatar:(nullable UIImage *)avatar;

/// Set the audio or video track used by this participant.
- (CallTrackKind)addWithTrack:(nonnull RTC_OBJC_TYPE(RTCMediaStreamTrack) *)track;

/// Remove the track id from this participant.
- (CallTrackKind)removeWithTrackId:(nonnull NSString *)trackId;

/// Get the call status from CallConnection.
- (CallStatus)callStatus;

/// Returns true if we control peer's camera or if peer control our camera
- (BOOL)isRemoteCameraControl;

/// Get the memberId from CallConnection;
- (nullable NSString *)memberId;

- (nullable TLGeolocationDescriptor *)currentGeolocation;

- (void)transferWithParticipant:(nonnull CallParticipant *)transferredParticipant;

/// Internal method to detach the renderer when we release the call connection.
- (void)releaseParticipant;

/// Ask the peer to get the control of its camera.
- (void)remoteAskControl;

/// Answer to GRANT/DENY access to our camera to the peer.
- (void)remoteAnswerControlWithGrant:(BOOL)grant;

/// Stop controlling the peer camera.
- (void)remoteStopControl;

/// Zoom on the peer camera.
- (void)remoteCameraSetWithZoom:(float)zoom;

/// Switch the peer camera to the front or back camera if we are allowed.
- (void)remoteSwitchCameraWithFront:(BOOL)front;

/// Turn ON/OFF the camera of the peer if we are allowed to
- (void)remoteCameraWithMute:(BOOL)mute;

@end

typedef enum {
    CallParticipantEventConnected,
    CallParticipantEventIdentity,
    CallParticipantEventAudioOn,
    CallParticipantEventAudioOff,
    CallParticipantEventVideoOn,
    CallParticipantEventVideoOff,
    CallParticipantEventRinging,
    CallParticipantEventStreamStart,    // Participant started to stream some content
    CallParticipantEventStreamInfo,     // Received information for streamed content
    CallParticipantEventStreamStop,     // Streaming is stopped
    CallParticipantEventStreamPause,    // Streaming is paused
    CallParticipantEventStreamResume,   // Streaming is resumed
    CallParticipantEventStreamStatus,   // Participant streaming status is updated
    CallParticipantEventHold,           // Participant has put the call on hold
    CallParticipantEventResume,          // Participant has resumed the call
    CallParticipantEventKeyCheckInitiate,          // Participant has started a key check
    CallParticipantEventOnKeyCheckInitiate,          // Participant has answered our key check request
    CallParticipantEventCurrentWordChanged,          // A word was confirmed by us or the peer
    CallParticipantEventWordCheckResultKO,          // Participant's current word is incorrect
    CallParticipantEventTerminateKeyCheck,          // Participant and us have both finished the key check
    CallParticipantEventScreenSharingOn,            // Participant started to share its screen or window
    CallParticipantEventScreenSharingOff,           // Participant stopped the sharing
    CallParticipantEventAskCameraControl,           // The remote participant is asking to take control of the camera
    CallParticipantEventCameraControlDenied,        // The camera control is denied.
    CallParticipantEventCameraControlGranted,       // The peer grant access to its camera.
    CallParticipantEventCameraControlDone           // The camera control by the peer is stopped.
} CallParticipantEvent;

@protocol CallParticipantDelegate

/// A new audio/video call participant is added to the current call.
- (void)onAddWithParticipant:(nonnull CallParticipant *)participant;

/// One or several audio/video call participant are now removed from the call.
- (void)onRemoveWithParticipants:(nonnull NSArray<CallParticipant *> *)participants;

/// An event occurred for the participant.
- (void)onEventWithParticipant:(nonnull CallParticipant *)participant event:(CallParticipantEvent)event;

/// A streaming event occurred.  When the participant is null, the event is associated with
/// the local player for the streamed content we are sending.  Otherwise, it is associated with the
/// player for a streaming sent by the participant.
- (void)onStreamingEventWithParticipant:(nullable CallParticipant *)participant event:(StreamingEvent)event;

/// The participant has sent us a descriptor.
- (void)onPopDescriptorWithParticipant:(nonnull CallParticipant *)participant descriptor:(nonnull TLDescriptor *)descriptor;

/// The participant has updated its geolocation.
- (void)onUpdateGeolocationWithParticipant:(nonnull CallParticipant *)participant descriptor:(nonnull TLGeolocationDescriptor *)descriptor;

/// The participant has deleted its descriptor.
- (void)onDeleteDescriptorWithParticipant:(nonnull CallParticipant *)participant descriptorId:(nonnull TLDescriptorId *)descriptorId;

@end
