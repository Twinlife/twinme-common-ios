/*
 *  Copyright (c) 2022-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinme/TLCapabilities.h>

#import <Twinlife/TLPeerConnectionService.h>
#import <Twinlife/TLConversationService.h>

#import "CallStatus.h"

typedef NS_OPTIONS(NSInteger, CameraControlMode) {
    CameraControlModeCheck,
    CameraControlModeON,
    CameraControlModeOFF,
    CameraControlModeSelect,
    CameraControlModeZoom,
    CameraControlModeStop
};

#define INCOMING_CALL_TIMEOUT 30.0 // 30s
#define OUTGOING_CALL_TIMEOUT (INCOMING_CALL_TIMEOUT+15.0) // Give 15s more to deliver the push and wakeup the device.


// Operations on the CallConnection (note: they can override the operations on the CallState
// but we try to avoid that and start at 16).
#define CREATE_OUTGOING_PEER_CONNECTION          (1 << 16)
#define CREATE_OUTGOING_PEER_CONNECTION_DONE     (1 << 17)
#define CREATE_INCOMING_PEER_CONNECTION          (1 << 18)
#define CREATE_INCOMING_PEER_CONNECTION_DONE     (1 << 19)
#define INIT_AUDIO_CONNECTION                    (1 << 20)
#define CREATED_PEER_CONNECTION                  (1 << 21)
#define JOIN_CALL_ROOM                           (1 << 22)
#define INVITE_CALL_ROOM                         (1 << 23)
#define GET_PARTICIPANT_AVATAR                   (1 << 24)

@protocol RTC_OBJC_TYPE(RTCVideoRenderer);
@protocol TLOriginator;
@class CallService;
@class CallParticipant;
@class CallState;
@class StreamPlayer;
@class TLVersion;
@class TLSerializerFactory;
@class TLBinaryPacketIQSerializer;
@class WordCheckResult;

/**
 * A P2P call connection in an Audio or Video call.
 *
 * The call connection can have one or several participant depending on the target it is connected to.
 * If it is connected to another device, there is only one participant.  If it is connected to a SFU,
 * there could be several participants.
 *
 * Calls are associated with a callId which allow to accept/hold/terminate the call.
 * The callId can be associated with one or several peer connection when the call is a meshed P2P group call.
 */
@interface CallConnection : TLConversationHandler;

@property (nonatomic, readonly, nonnull) CallService *callService;
@property (nonatomic, nullable, weak) CallState *call;
@property (nonatomic, readonly, nonnull) id<TLOriginator> originator;
@property (nonatomic, nullable) NSUUID *peerTwincodeOutboundId;
@property (nonatomic) BOOL peerConnected;
@property (nonatomic) TLPeerConnectionServiceConnectionState connectionState;
@property (nonatomic) int64_t startTime;
@property (nonatomic) CallStatus callStatus;
@property (nonatomic, nullable) NSString *callRoomMemberId;
@property (nonatomic, nullable) NSString *transferToMemberId;
/**
 * Set to true when we receive a invite-call-room IQ.
 * When re-joining a group call, we'll receive this IQ before the session-accept IQ.
 * <p>
 * Used to check whether we're the one creating the call room: if true, we're joining an existing
 * call room and we must not create a new call room, nor invite this peer (since it's already in the call room).
 */
@property (nonatomic) BOOL invited;

+ (nonnull TLBinaryPacketIQSerializer *)STREAMING_CONTROL_SERIALIZER;

+ (nonnull TLBinaryPacketIQSerializer *)STREAMING_INFO_SERIALIZER;

+ (nonnull TLBinaryPacketIQSerializer *)STREAMING_REQUEST_SERIALIZER;

+ (nonnull TLBinaryPacketIQSerializer *)STREAMING_DATA_SERIALIZER;

/// Create the call connection at begining of an incoming or outgoing P2P setup.
- (nonnull instancetype)initWithCallService:(nonnull CallService *)callService serializerFactory:(nonnull TLSerializerFactory *)serializerFactory call:(nonnull CallState *)call originator:(nonnull id<TLOriginator>)originator mode:(CallStatus)mode peerConnectionId:(nullable NSUUID *)peerConnectionId retryState:(int)retryState memberId:(nullable NSString *)memberId;

/// Append in the list the participants that use this P2P connection.
- (void)appendParticipantsWithList:(nonnull NSMutableArray<CallParticipant *>*)list;

/// Get the current call connection status.
- (CallStatus)status;

/// Returns true if video is enabled on the P2P connection.
- (BOOL)videoEnabled;

/// Returns true if we allow the peer to take control of our camera.
- (BOOL)isRemoteControlGranted;

/// Check if this connection supports P2P group calls.
- (CallGroupSupport)isGroupSupported;

/// Check if this connection supports receiving messages in P2P calls.
- (CallMessageSupport)isMessageSupported;

/// Check if this connection supports receiving geolocation in P2P calls.
- (CallGeolocationSupport)isGeolocationSupported;

/// Get the audio streaming status.
- (StreamingStatus)streamingStatus;

/// Check if this connection supports control camera by peer in P2P calls.
- (TLVideoZoomable)isZoomable;

/// Get the audio stream player
- (nullable StreamPlayer *)streamPlayer;

/// Get the main participant.
- (nullable CallParticipant *)mainParticipant;

/// Test and set the operation.  Returns YES if the operation must be performed.
- (BOOL)checkOperation:(int)operation;

/// Returns true if the operation was completed.
- (BOOL)isDoneOperation:(int)operation;

/// Returns true if the operation was completed and we are done and if not mark that we are ready to perform the readyFor operation.
- (BOOL)isDoneOperation:(int)operation readyFor:(int)readyFor;

/// Report a failed operation and check if we must retry it.  Returns YES if the operation must be performed again.
- (BOOL)retryOperation:(int)operation;

/// Get the twinlife dispatching queue.
- (nonnull dispatch_queue_t)twinlifeQueue;

/// Set the connection to the given possibly new state and setup a new timer that represents a timeout for the state.
- (void)setTimerWithStatus:(CallStatus)status delay:(NSTimeInterval)delay;

/// Update the connection state.  Returns YES if we are now connected.
- (BOOL)updateConnectionWithState:(TLPeerConnectionServiceConnectionState)state;

/// Set the P2P conversation service version used by the peer.
- (void)setPeerVersionWithVersion:(nullable TLVersion *)version;

/// Set the audio direction for this peer connection.
- (void)setAudioDirectionWithDirection:(RTCRtpTransceiverDirection)direction;

/// Set the video direction for this peer connection.
- (void)setVideoDirectionWithDirection:(RTCRtpTransceiverDirection)direction;

/// Setup the P2P connection to prepare for audio and video streaming.
/// Check that the given operation has been executed!!!!
- (void)initSourcesAfterOperation:(int)operation;

- (void)onCreateOutgoingPeerConnectionWithPeerConnectionId:(nonnull NSUUID*)peerConnectionId;

- (nullable NSString *)onAddRemoteTrackWithTrack:(nonnull RTC_OBJC_TYPE(RTCMediaStreamTrack) *)track;

- (nullable NSString *)onRemoveRemoteTrackWithTrackId:(nonnull NSString *)trackId;

/// Terminate the P2P connection with the given terminate reason.
- (void)terminateWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

/// Release the resources after the P2P connection has been terminated.
- (BOOL)releaseWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

- (void)setDeviceRinging;

/// Internal method to update the peer streaming status.
- (void)updatePeerWithStreamingStatus:(StreamingStatus)streamingStatus;

/// Check if this connection was created to perform a call transfer.
- (TransferConnection)isTransferConnection;

- (void)sendParticipantTransferIQWithMemberId:(nonnull NSString *)memberId;

- (void)sendPrepareTransferIQ;

- (void)sendTransferDoneIQ;

- (void)sendHoldCallIQ;

- (void)sendResumeCallIQ;

- (void)putOnHold;

- (void)resume;

- (void)resumeWithAudio:(BOOL)audio video:(BOOL)video;

/// Key check

- (void)sendKeyCheckInitiateIQWithLanguage:(nonnull NSLocale *)language;

- (void)sendOnKeyCheckInitiateIQWithErrorCode:(TLBaseServiceErrorCode)errorCode;

- (void)sendWordCheckResultIQWithResult:(nonnull WordCheckResult *)result;

- (void)sendTerminateKeyCheckIQWithResult:(BOOL)result;

- (void)sendTwincodeUriIQWithUri:(nonnull NSString *)uri;

/// Send a camera control IQ command
- (void)sendCameraControlWithMode:(CameraControlMode)mode camera:(int)camera scale:(int)scale;

- (void)sendCameraControlGrant;

- (void)sendCameraStop;

- (void)sendCameraResponseWithError:(TLBaseServiceErrorCode)errorCode cameraBitmap:(int64_t)cameraBitmap activeCamera:(int)activeCamera minScale:(int)minScale maxScale:(int)maxScale;

@end
