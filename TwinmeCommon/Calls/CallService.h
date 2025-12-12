/*
 *  Copyright (c) 2017-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <Twinlife/TLPeerConnectionService.h>
#import <Twinlife/TLAssertion.h>

#import "CallStatus.h"
#import "TLLocationManager.h"
#import "WordCheckResult.h"
#import "WordCheckChallenge.h"
#import "KeyCheckSessionHandler.h"

//
// Interface: CallsAssertPoint
//

@interface CallsAssertPoint : TLAssertPoint

+(nonnull TLAssertPoint *)CALL_STATUS;
+(nonnull TLAssertPoint *)UNKNOWN_ERROR;
+(nonnull TLAssertPoint *)CALLKIT_END_ERROR;
+(nonnull TLAssertPoint *)CALLKIT_START_ERROR;
+(nonnull TLAssertPoint *)CALLKIT_HOLD_ERROR;
+(nonnull TLAssertPoint *)CALLKIT_RESUME_ERROR;

@end

/*
typedef enum {
    CallModeNone,                  // No Audio/Video call (we are ready to make calls).
    CallModeIncomingCall,          // An incoming Audio/Video call (not yet accepted).
    CallModeIncomingVideoCall,     // Incoming video bell and we are receiving the video track.
    CallModeAcceptedIncomingCall,  // An incoming Audio/Video call that was accepted (not established yet).
    CallModeAcceptedIncomingVideoCall, // Incoming video bell call was accepted and we are receiving the video track.
    CallModeOutgoingCall,          // An outgoing Audio/Video call (not yet accepted).
    CallModeAcceptedOutgoingCall,  // An outgoing Audio/Video call that was accepted by the peer (not established yet).
    CallModeInVideoBell,           // Outgoing video bell and we have setup the local video track.
    CallModeInCall,                // Established Audio/Video call (incoming or outgoing).
    CallModeTerminated             // Audio/Video call that is terminated (transient mode until we go in CallModeNone).
} CallMode;
*/

typedef enum {
    AudioDeviceTypeSpeakerPhone,
    AudioDeviceTypeWiredHeadset,
    AudioDeviceTypeEarPiece,
    AudioDeviceTypeBluetooth,
    AudioDeviceTypeDefault,
    AudioDeviceTypeNone
} AudioDeviceType;

#define CallEventMessageConnectionState @"CallEventMessageConnectionState"
#define CallEventMessageTerminateCall @"CallEventMessageTerminateCall"
#define CallEventMessageCameraSwitch @"CallEventMessageCameraSwitch"
#define CallEventMessageVideoUpdate @"CallEventMessageVideoUpdate"
#define CallEventMessageAudioSinkUpdate @"CallEventMessageAudioSinkUpdate"
#define CallEventMessageCallOnHold @"CallEventMessageCallOnHold"
#define CallEventMessageCallResumed @"CallEventMessageCallResumed"
#define CallEventMessageCallsMerged @"CallEventMessageCallsMerged"
#define CallEventMessageError @"CallEventMessageCallsError"
#define CallEventMessageError @"CallEventMessageCallsError"
#define CallEventCameraControlZoomUpdate @"CallEventCameraControlZoomUpdate"

@class CallViewController;
@class CallService;
@class TLTwinmeContext;
@class TwinmeApplication;
@class CallParticipant;
@class CallConnection;
@class CallState;
@class MPMediaItem;
@class KeyCheckSessionHandler;
@class CLLocation;
@protocol CallParticipantDelegate;

@interface CallEventMessage : NSObject;

@property (nonnull, readonly) NSUUID *callId;
@property (readonly) CallStatus callStatus;
@property (readonly) TLPeerConnectionServiceTerminateReason terminateReason;
@property (readonly) TLPeerConnectionServiceConnectionState state;

- (nonnull instancetype)initWithCallId:(nonnull NSUUID *)callId callStatus:(CallStatus)callStatus state:(TLPeerConnectionServiceConnectionState)state;

- (nonnull instancetype)initWithCallId:(nonnull NSUUID *)callId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

@end

@interface AudioDevice : NSObject;

@property (readonly) AudioDeviceType type;
@property (nullable, readonly) NSString *name;

- (nonnull instancetype)initWithType:(AudioDeviceType)type name:(nullable NSString *)name;

@end

//
// Interface: CallService
//

@interface CallService : NSObject

@property (nonatomic, readonly, nonnull) TLTwinmeContext *twinmeContext;
@property (atomic, nullable, weak) id<CallParticipantDelegate> callParticipantDelegate;

/// Create the call service with the twinme context and application (only once during startup).
- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext twinmeApplication:(nonnull TwinmeApplication *)twinmeApplication enableCallkit:(BOOL)enableCallkit;

/// Start an outgoing call with the contact.
- (void)startCallWithOriginator:(nonnull id<TLOriginator>)originator mode:(CallStatus)mode viewController:(nonnull CallViewController *)viewController;

/// Start an incoming call with the peer connection Id for the contact.
- (void)startCallWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId originator:(nonnull id<TLOriginator>)originator offer:(nonnull TLOffer *)offer inBackground:(BOOL)inBackground fromPushKit:(BOOL)fromPushKit;

/// Add a participant to the current call by calling the given contact and adding it to the current call once it has accepted.
- (void)addCallParticipantWithOriginator:(nonnull id<TLOriginator>)originator;

- (void)onCreateIncomingPeerConnectionWithConnection:(nonnull CallConnection *)connection peerConnectionId:(nonnull NSUUID*)peerConnectionId;

- (void)onChangeConnectionStateWithConnection:(nonnull CallConnection *)connection state:(TLPeerConnectionServiceConnectionState)state;

- (void)onTerminatePeerConnectionWithConnection:(nonnull CallConnection *)connection terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

- (void)onCameraSwitchDone:(BOOL)isFrontCamera;

- (BOOL)isConnected;

- (BOOL)isAudioMuted;

- (BOOL)isSpeakerOn;

- (BOOL)isCameraMuted;

- (BOOL)isFrontCamera;

- (CallStatus)callStatus;

- (NSTimeInterval)duration;

/// Get the current call instance with its state.
- (nullable CallState *)currentCall;

/// Get the current held call instance with its state.
- (nullable CallState *)currentHoldCall;

- (nullable RTC_OBJC_TYPE(RTCVideoTrack) *)localVideoTrack;

- (void)acceptCall;

- (void)acceptCallWithCallkitUUID:(nonnull NSUUID *)callkitUUID;

- (void)acceptTransferWithConnectionId:(nonnull NSUUID *) connectionId;

/// Start streaming the music described by the media item.
/// Returns YES if the streaming started and NO if there was some problem (call terminated, ...).
- (BOOL)startStreamingWithMediaItem:(nonnull MPMediaItem *)mediaItem;

/// Stop streaming content, notify the peers to stop their player and release all resources.
- (void)stopStreaming;

/// Terminate the call closing all active peer connection id associated with that call.
- (void)terminateCallWithCall:(nonnull CallState *)call terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

/// Terminate the active call closing all active peer connection id associated with that call.
- (void)terminateCallWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

/// Terminate the call with a specific peer connection id.
- (void)terminateCallWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

- (void)setAudioMute:(BOOL)mute;

- (void)setSpeaker:(BOOL)speaker;

- (nonnull AudioDevice *)getCurrentAudioDevice;

- (BOOL)isHeadsetAvailable;

- (void)switchCamera;

- (BOOL)canDeviceShareLocation;

- (BOOL)canDeviceShareBackgroundLocation;

- (BOOL)isLocationStartShared;

- (BOOL)isExactLocation;

- (void)initShareLocation;

- (void)startShareLocation:(double)mapLatitudeDelta mapLongitudeDelta:(double)mapLongitudeDelta;

- (void)stopShareLocation:(BOOL)disableUpdateLocation;
 
- (nullable CLLocation *)getCurrentLocation;

/// Enable the video call or disable the video call.
- (void)setCameraMute:(BOOL)mute;

- (void)updateCameraControlZoom:(int)zoomLevel;

- (void)onUnknownIncomingCall;

- (void)applicationDidEnterBackground:(nonnull UIApplication *)application;

- (void)applicationWillEnterForeground:(nonnull UIApplication *)application;

- (void)sendMessageWithCall:(nonnull CallState *)call message:(nonnull NSString *)message;

- (void)sendCallQuality:(int)quality;

- (void)onTransferDone;

- (void)putCallOnHold;

- (void)resumeCall;

- (void)switchCall;

- (void)mergeCall;

- (void)onPeerHoldCallWithConnectionId:(nonnull NSUUID *)connectionId;

- (void)onPeerResumeCallWithConnectionId:(nonnull NSUUID *)connectionId;

- (int)allocateParticipantId;

/// Terminate the call when the CallState was informed that the end ringtone sound has finished playing.
- (void)finishWithCall:(nonnull CallState *)call;

- (void)sendGeolocationWithConnection:(nonnull CallConnection *)connection;

/// Key check

- (void)startKeyCheckWithLanguage:(nullable NSLocale *)language;

- (void)addWordCheckResultWithWordIndex:(int)wordIndex result:(BOOL)result;

- (BOOL)isKeyCheckRunning;

- (nullable WordCheckChallenge*)getKeyCheckCurrentWord;

- (nullable WordCheckChallenge *)getKeyCheckPeerError;

- (KeyCheckResult)isKeyCheckOK;

- (void)onPeerKeyCheckInitiateWithConnectionId:(nonnull NSUUID *)connectionId locale:(nonnull NSLocale *)locale;

- (void)onOnKeyCheckInitiateWithConnectionId:(nonnull NSUUID *)connectionId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onPeerWordCheckResultWithConnectionId:(nonnull NSUUID *)connectionId wordCheckResult:(nonnull WordCheckResult *)wordCheckResult;

- (void)onTerminateKeyCheckWithConnectionId:(nonnull NSUUID *)connectionId result:(BOOL)result;

- (void)onTwincodeURIWithConnectionId:(nonnull NSUUID *)connectionId uri:(nonnull NSString *)uri;

@end
