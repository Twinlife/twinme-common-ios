/*
 *  Copyright (c) 2017-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import <CallKit/CallKit.h>
#import <CallKit/CXError.h>

#import <MapKit/MapKit.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLPeerConnectionService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLJobService.h>
#import <Twinlife/TLPeerCallService.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroupMember.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLCallReceiver.h>
#import <Twinme/TLNotificationCenter.h>
#import <Twinme/TLTwinmeAttributes.h>
#import <Twinme/TLSchedule.h>

#import <WebRTC/RTCAudioSession.h>
#import <WebRTC/RTCAudioSessionConfiguration.h>
#import <WebRTC/RTCDispatcher.h>
#import <WebRTC/RTCMediaStreamTrack.h>
#import <WebRTC/RTCVideoTrack.h>
#import <WebRTC/RTCAudioTrack.h>

#import <Utils/NSString+Utils.h>

#import "NotificationSound.h"

#import "NotificationCenter.h"
#import "TwinmeApplication.h"
#import "ApplicationDelegate.h"
#import "CallService.h"
#import "CallViewController.h"
#import "MainViewController.h"
#import "TwinmeNavigationController.h"
#import "UIViewController+Utils.h"
#import "CallParticipant.h"
#import "CallConnection.h"
#import "CallState.h"

#if 0
//static const int ddLogLevel = DDLogLevelVerbose;
static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define CONNECT_TIMEOUT 15.0 // After accepting a call, delay before we get the connection.

typedef void (^CallStartedAction) (BOOL success);

// An operation related to a connection in an Audio or Video call.
@interface ConnectionOperation : NSObject;

@property (nonatomic, readonly) int operation;
@property (nonatomic, nonnull, readonly) CallConnection *callConnection;
@property (nonatomic, nonnull, readonly) CallState *call;

- (nonnull instancetype)initWithConnection:(nonnull CallConnection *)connection operationId:(int)operationId;

@end

// An operation related to an Audio or Video call's CallState.
@interface CallStateOperation : NSObject;

@property (nonatomic, readonly) int operation;
@property (nonatomic, nonnull, readonly) CallState *call;

- (nonnull instancetype)initWithCallState:(nonnull CallState *)call operationId:(int)operationId;

@end


//
// Interface: CallService ()
//

@class CallServiceTwinmeContextDelegate;
@class CallServicePeerConnectionServiceDelegate;
@class CallServiceConversationServiceDelegate;
@class CallServicePeerCallServiceDelegate;
@class RTC_OBJC_TYPE(RTCMediaStream);
@class RTC_OBJC_TYPE(RTCVideoTrack);

/**
 * The CallService handes Audio and Video calls with CallKit when we are in background and foreground.  However, CallKit must not
 * be used in China where is it not allowed.
 *
 * The outgoing call is established as follows:
 * - A outgoing Audio/Video call is started by startCallWithOriginator() .
 *  We allow the call to proceed if there is no pending call (current state is CallNone or CallTerminated).
 * - The onOperationWithCallState() will then handle the creation of the CallDescriptor.
 * - Then onOperationWithConnection() will handle the creation of the P2P connection for the outgoing call.
 * - Once the outgoing call P2P connection is created, the CallKit startCallAction is invoked so that it triggers the CallKit work flow.
 *  At the same time, we call initSourcesWithPeerConnectionId() to setup the Audio/Video call for the outgoing call.
 * - CallKit will invoke performStartCallAction() and we initiate the CallKit call through the reportOutgoingCallWithUUID() with the
 *  P2P connection Id.
 * - When the call is accepted, we notify CallKit through reportOutgoingCallWithUUID() that the call was accepted.
 * - Once the call is connected, we update the CallDescriptor by calling acceptCallWithRequestId().
 *
 * The incoming call is established as follows:
 * - The incoming call is started by startCallWithPeerConnectionId(). If a call is already in progress, it is terminated with Busy,
 *   or the current call is put on hold.
 *   The call is created on CallKit side by calling reportNewIncomingCallWithUUID() with the P2P connection Id.
 * - The onOperationWithCallState() will then handle the creation of the CallDescriptor.
 * - When the user accepts the call through CallKit, the performAnswerCallAction() is called and we trigger the accept through acceptCall().
 * - The onOperationWithConnection() will then create the incoming P2P connection. At this step, we must wait for CallKit to call didActivateAudioSession().
 * - CallKit will call didActivateAudioSession() and we can enable the audio. The onOperationWithConnection() will then call initSourcesWithPeerConnectionId()
 *  to setup the audio/video call.
 * - Once the call is connected, we update the CallDescriptor by calling acceptCallWithRequestId().
 *
 * The termination of the call is almost similar for incoming and outgoing calls:
 * - If the call is terminated through CallKit, we are notified from the performEndCallAction() and we send the terminate reason by
 *  calling terminatePeerConnectionWithPeerConnectionId().
 * - The onTerminatePeerConnectionWithTerminateReason() is then explicitly called so that we cleanup the call, play the end-ringtone,
 *  and update the CallDescriptor by calling terminateCallWithRequestId().
 * - If the call is terminated through the UI, the view controller calls terminateCallWithTerminateReason() and we must terminate the
 *  call by using CallKit. This is done by calling the endCallAction() which will trigger a call to performEndCallAction().
 * - If the call is terminated by the peer, the onTerminatePeerConnectionWithTerminateReason() must handle the call termination to
 *  CallKit and we call reportCallWithUUID() to indicate the terminate status.
 *
 * Important notes:
 * - We don't have the constraint to run on the main thread.  The counter part is that some synchronization is necessary.
 *   It is critical to protect the following properties:
 *   * peers,
 *   * callsContacts,
 *   * callkitCalls,
 *   * activeCall, holdCall
 * - The `CallConnection`, `CallState` and `CallParticipant` MUST also handle and protect their own properties.
 * - An outgoing call must be made through CallKit so that we handle correctly the call if the user leaves the application.
 *  The outgoing ringtone is started by didActivateAudioSession() because this is the first place we are allowed to access and use the audio.
 * - When a call is received, we must wait for didActivateAudioSession() to be called before enabling the WebRTC audio.
 *  If we call initSourcesWithPeerConnectionId() before that call, the WebRTC audio setup will fail and we don't get the microphone.
 * - The termination of a call must be made through CallKit so that it is aware of the call termination.
 */
@interface CallService () <RTC_OBJC_TYPE(RTCAudioSessionDelegate), CXProviderDelegate, CXCallObserverDelegate, TLPeerConnectionDelegate, TLLocationManagerDelegate>

@property (nonatomic, readonly, nonnull) TwinmeApplication *twinmeApplication;
@property (nonatomic, nullable) CXProvider *cxProviderInstance;
@property (nonatomic, nullable) CXCallController *cxCallControllerInstance;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSUUID *, CallState *> *callkitCalls;
@property (nonatomic, readonly, nonnull) NotificationCenter *notificationCenter;
@property (nonatomic, readonly, nonnull) CallServiceTwinmeContextDelegate *twinmeContextDelegate;
@property (nonatomic, readonly, nonnull) CallServicePeerConnectionServiceDelegate *peerConnectionServiceDelegate;
@property (nonatomic, readonly, nonnull) CallServicePeerCallServiceDelegate *peerCallServiceDelegate;
@property (nonatomic, readonly, nonnull) CallServiceConversationServiceDelegate *conversationServiceDelegate;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSUUID *, CallConnection *> *peers;

@property (nonatomic) BOOL isTwinlifeReady;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSNumber *, ConnectionOperation *> *connectionRequestIds;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSNumber *, CallStateOperation *> *callStateRequestIds;
@property (nonatomic) BOOL restarted;

@property (nonatomic) BOOL connected;
@property (nonatomic) BOOL onHold;
@property (nonatomic) BOOL audioMuteOn;
@property (nonatomic) BOOL speakerOn;
@property (nonatomic) BOOL cameraMuteOn;
/// Used to track the current video call when the app enters to the background, to re-enable the video afterwards..
@property (nonatomic, weak, nullable) CallState *restartCameraCall;
@property (nonatomic) BOOL audioDeviceEnabled;
@property (nonatomic) BOOL inBackground;
@property (readonly, nonatomic) BOOL iosCallKitObligationFascism;
@property (nonatomic, nullable) IncomingCallNotification *notification;
@property (nonatomic, nullable) NotificationSound *notificationSound;
@property (nonatomic, weak) CallViewController *viewController;
@property (nonatomic, nullable) CallState *activeCall;
@property (nonatomic, nullable) CallState *holdCall;
@property (nonatomic, nullable) NSUUID *peerConnectionIdTerminated;
@property (nonatomic) int nextParticipantId;

@property (nonatomic) TLLocationManager *locationManager;

@property (nonatomic, nullable) KeyCheckSessionHandler *keyCheckSessionHandler;

// We must record only one local video track: it is connected to the video source which is shared by every P2P connection.
@property (nonatomic, nullable) RTC_OBJC_TYPE(RTCVideoTrack) *currentLocalVideoTrack;

- (int64_t)newOperationWithConnection:(nonnull CallConnection *)connection operationId:(int)operationId;

- (BOOL)isPeerConnection:(nonnull NSUUID *)peerConnectionId;

- (nullable CallConnection *)findConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (void)startRingtoneWithNotificationSoundType:(NotificationSoundType)type;

- (void)stopRingtone;

- (void)sendMessageWithCall:(nonnull CallState *)call message:(nonnull NSString *)message;

- (void)onOperationWithConnection:(nonnull CallConnection *)connection;

- (void)onOperationWithCallState:(nonnull CallState *)callState;

- (void)onTwinlifeReady;

- (void)onTwinlifeOnline;

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus;

- (void)onUpdateContactWithCall:(nonnull CallState *)call contact:(nonnull TLContact *)contact;

- (void)onIncomingPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerId:(nonnull NSString *)peerId version:(nonnull TLVersion *)version ;

- (void)onCreateIncomingPeerConnectionWithConnection:(nonnull CallConnection *)connection peerConnectionId:(nonnull NSUUID*)peerConnectionId;

- (void)onCreateOutgoingPeerConnectionWithConnection:(nonnull CallConnection *)connection errorCode:(TLBaseServiceErrorCode)errorCode peerConnectionId:(nonnull NSUUID*)peerConnectionId;

- (void)onAcceptPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId offer:(nonnull TLOffer *)offer;

- (void)onChangeConnectionStateWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId state:(TLPeerConnectionServiceConnectionState)state;

- (void)onCreateLocalVideoTrack:(nonnull RTC_OBJC_TYPE(RTCVideoTrack) *)videoTrack;

- (void)onRemoveLocalVideoTrack;

- (void)onAddRemoteTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId mediaTrack:(RTC_OBJC_TYPE(RTCMediaStreamTrack) *)mediaTrack;

- (void)onRemoveRemoteTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId trackId:(nonnull NSString *)trackId;

- (void)onCameraSwitchDone:(BOOL)isFrontCamera;

- (void)onErrorWithConnection:(nonnull CallConnection *)connection operationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

- (void)onErrorWithCall:(nonnull CallState *)call operationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

- (void)onCreateCallRoomWithCall:(nonnull CallState *)call callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId mode:(int)mode maxMemberCount:(int)maxMemberCount;

- (void)onInviteCallRoomWithCallRoomId:(nonnull NSUUID *)callRoomId twincodeInboundId:(nonnull NSUUID *)twincodeInboundId p2pSessionId:(nullable NSUUID *)p2pSessionId mode:(int)mode maxMemberCount:(int)maxMemberCount;

- (void)onJoinCallRoomWithCall:(nonnull CallState *)call callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId members:(nonnull NSArray<TLPeerCallMemberInfo *> *)members;

- (void)onMemberJoinCallRoomWithCallRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId p2pSessionId:(nullable NSUUID *)p2pSessionId status:(TLMemberStatus)status;

- (void)onTransferRequestWithConnectionId:(nonnull NSUUID *)peerConnectionId originator:(id<TLOriginator>)originator;
@end

//
// Interface: CallServiceTwinmeContextDelegate
//

@interface CallServiceTwinmeContextDelegate:NSObject <TLTwinmeContextDelegate>

@property (weak) CallService *service;

- (nonnull instancetype)initWithService:(nonnull CallService *)service;

@end

//
// Implementation: CallsAssertPoint
//

@implementation CallsAssertPoint

TL_CREATE_ASSERT_POINT(CALL_STATUS, 4100)
TL_CREATE_ASSERT_POINT(UNKNOWN_ERROR, 4101)
TL_CREATE_ASSERT_POINT(CALLKIT_END_ERROR, 4102);
TL_CREATE_ASSERT_POINT(CALLKIT_START_ERROR, 4103);
TL_CREATE_ASSERT_POINT(CALLKIT_HOLD_ERROR, 4104);
TL_CREATE_ASSERT_POINT(CALLKIT_RESUME_ERROR, 4105);
TL_CREATE_ASSERT_POINT(CALLKIT_TIMEOUT, 4107);
TL_CREATE_ASSERT_POINT(CALLKIT_INCONSISTENCY, 4108);

@end

//
// Implementation: ConnectionOperation
//

#undef LOG_TAG
#define LOG_TAG @"ConnectionOperation"

@implementation ConnectionOperation

- (nonnull instancetype)initWithConnection:(nonnull CallConnection *)connection operationId:(int)operationId {
    
    self = [super init];
    
    if (self) {
        _callConnection = connection;
        _call = connection.call;
        _operation = operationId;
    }
    return self;
}

@end


//
// Implementation: CallStateOperation
//

#undef LOG_TAG
#define LOG_TAG @"CallStateOperation"

@implementation CallStateOperation

- (nonnull instancetype)initWithCallState:(nonnull CallState *)call operationId:(int)operationId {
    
    self = [super init];
    
    if (self) {
        _call = call;
        _operation = operationId;
    }
    return self;
}

@end


//
// Implementation: CallEventMessage
//

#undef LOG_TAG
#define LOG_TAG @"CallEventMessage"

@implementation CallEventMessage

- (nonnull instancetype)initWithCallId:(nonnull NSUUID*)callId callStatus:(CallStatus)callStatus state:(TLPeerConnectionServiceConnectionState)state {

    self = [super init];
    
    if (self) {
        _callId = callId;
        _callStatus = callStatus;
        _state = state;
        _terminateReason = TLPeerConnectionServiceTerminateReasonUnknown;
    }
    return self;
}

- (nonnull instancetype)initWithCallId:(nonnull NSUUID*)callId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    
    self = [super init];
    
    if (self) {
        _callId = callId;
        _callStatus = CallStatusTerminated;
        _state = TLPeerConnectionServiceConnectionStateChecking;
        _terminateReason = terminateReason;
    }
    return self;
}

@end

@implementation AudioDevice

- (nonnull instancetype)initWithType:(AudioDeviceType)type name:(nullable NSString *)name {
    self = [super init];
    
    if (self) {
        _type = type;
        _name = name;
    }
    return self;
}

@end

//
// Implementation: CallServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"CallServiceTwinmeContextDelegate"

@implementation CallServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull CallService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [self.service onTwinlifeReady];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    [self.service onTwinlifeOnline];
}

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus {
    DDLogVerbose(@"%@ onConnectionStatusChange: %d", LOG_TAG, connectionStatus);
    
    [self.service onConnectionStatusChange:connectionStatus];
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);

    // Ignore the update contact if it has no private peer.
    if (![contact hasPrivatePeer]) {
        return;
    }

    CallState *call = [self.service activeCall];
    if (call) {
        [self.service onUpdateContactWithCall:call contact:contact];
    }
    call = [self.service holdCall];
    if (call) {
        [self.service onUpdateContactWithCall:call contact:contact];
    }
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    ConnectionOperation *request;
    @synchronized(self.service.connectionRequestIds) {
        request = self.service.connectionRequestIds[lRequestId];
        if (!request) {
            return;
        }
        [self.service.connectionRequestIds removeObjectForKey:lRequestId];
    }
    [self.service onErrorWithConnection:request.callConnection operationId:request.operation errorCode:errorCode errorParameter:errorParameter];
}

@end

//
// Interface: CallServicePeerConnectionServiceDelegate
//

@interface CallServicePeerConnectionServiceDelegate : NSObject <TLPeerConnectionServiceDelegate>

@property (weak) CallService *service;

- (nonnull instancetype)initWithService:(nonnull CallService *)service;

@end

//
// Implementation: CallServicePeerConnectionServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"CallServicePeerConnectionServiceDelegate"

@implementation CallServicePeerConnectionServiceDelegate

- (nonnull instancetype)initWithService:(nonnull CallService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onIncomingPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerId:(nonnull NSString *)peerId  offer:(nonnull TLOffer *)offer {
    DDLogVerbose(@"%@ onIncomingPeerConnectionWithPeerConnectionId: %@ peerId: %@ offer: %@", LOG_TAG, peerConnectionId, peerId, offer);

    CallState *call = [self.service currentCall];
    if (!call) {
        
        return;
    }
    
    //Send device ringing (if the incoming call is handled by callkit)
    [self.service onOperationWithCallState:call];

    [self.service onIncomingPeerConnectionWithPeerConnectionId:peerConnectionId peerId:peerId version:offer.version];
}

- (void)onCreateLocalVideoTrack:(nonnull RTC_OBJC_TYPE(RTCVideoTrack) *)videoTrack {
    DDLogVerbose(@"%@ onCreateLocalVideoTrack: %@", LOG_TAG, videoTrack);

    [self.service onCreateLocalVideoTrack:videoTrack];
}

- (void)onRemoveLocalVideoTrack {
    DDLogVerbose(@"%@ onRemoveLocalVideoTrack", LOG_TAG);

    [self.service onRemoveLocalVideoTrack];
}

- (void)onDeviceRinging:(NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ onDeviceRinging: peerConnectionId: %@", LOG_TAG, peerConnectionId);

    CallConnection *connection = [self.service findConnectionWithPeerConnectionId:peerConnectionId];
    if (!connection) {
        return;
    }
    
    if (!CALL_IS_ACTIVE(connection.call.status)) {
        [self.service startRingtoneWithNotificationSoundType:NotificationSoundTypeAudioRinging];
    }
    
    [connection setDeviceRinging];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    ConnectionOperation *request;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized(self.service.connectionRequestIds) {
        request = self.service.connectionRequestIds[lRequestId];
        if (!request) {
            return;
        }
        [self.service.connectionRequestIds removeObjectForKey:lRequestId];
    }
    
    [self.service onErrorWithConnection:request.callConnection operationId:request.operation errorCode:errorCode errorParameter:errorParameter];
}

@end

//
// Interface: CallServicePeerCallServiceDelegate
//

@interface CallServicePeerCallServiceDelegate : NSObject <TLPeerCallServiceDelegate>

@property (weak) CallService *service;

- (nonnull instancetype)initWithService:(nonnull CallService *)service;

- (void)onCreateCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId mode:(int)mode maxMemberCount:(int)maxMemberCount;

- (void)onInviteCallRoomWithCallRoomId:(nonnull NSUUID *)callRoomId twincodeInboundId:(nonnull NSUUID *)twincodeInboundId p2pSessionId:(nullable NSUUID *)p2pSessionId mode:(int)mode maxMemberCount:(int)maxMemberCount;

- (void)onJoinCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId members:(nonnull NSArray<TLPeerCallMemberInfo *> *)members;

- (void)onLeaveCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId;

- (void)onMemberJoinCallRoomWithCallRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId p2pSessionId:(nullable NSUUID *)p2pSessionId status:(TLMemberStatus)status;

- (void)onTransferDone;

@end

//
// Implementation: CallServicePeerCallServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"CallServicePeerCallServiceDelegate"

@implementation CallServicePeerCallServiceDelegate

- (nonnull instancetype)initWithService:(nonnull CallService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onCreateCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId mode:(int)mode maxMemberCount:(int)maxMemberCount {
    DDLogVerbose(@"%@ onCreateCallRoomWithRequestId: %lld callRoomId: %@ memberId: %@ mode: %d maxMemberCount: %d", LOG_TAG, requestId, callRoomId, memberId, mode, maxMemberCount);

    ConnectionOperation *request;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self.service.connectionRequestIds) {
        request = self.service.connectionRequestIds[lRequestId];
        if (!request) {
            return;
        }
        [self.service.connectionRequestIds removeObjectForKey:lRequestId];
    }

    [self.service onCreateCallRoomWithCall:request.call callRoomId:callRoomId memberId:memberId mode:mode maxMemberCount:maxMemberCount];
}

- (void)onInviteCallRoomWithCallRoomId:(nonnull NSUUID *)callRoomId twincodeInboundId:(nonnull NSUUID *)twincodeInboundId p2pSessionId:(nullable NSUUID *)p2pSessionId mode:(int)mode maxMemberCount:(int)maxMemberCount {
    DDLogVerbose(@"%@ onInviteCallRoomWithCallRoomId: %@ twincodeInboundId: %@ p2pSessionId: %@ mode: %d maxMemberCount: %d", LOG_TAG, callRoomId, twincodeInboundId, p2pSessionId, mode, maxMemberCount);

    [self.service onInviteCallRoomWithCallRoomId:callRoomId twincodeInboundId:twincodeInboundId p2pSessionId:p2pSessionId mode:mode maxMemberCount:maxMemberCount];
}

- (void)onJoinCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId members:(nonnull NSArray<TLPeerCallMemberInfo *> *)members {
    DDLogVerbose(@"%@ onJoinCallRoomWithRequestId: %lld callRoomId: %@ memberId: %@ members: %@", LOG_TAG, requestId, callRoomId, memberId, members);

    CallStateOperation *request;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self.service.callStateRequestIds) {
        request = self.service.callStateRequestIds[lRequestId];
        if (!request) {
            return;
        }
        [self.service.callStateRequestIds removeObjectForKey:lRequestId];
    }

    [self.service onJoinCallRoomWithCall:request.call callRoomId:callRoomId memberId:memberId members:members];
}

- (void)onLeaveCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId {
    DDLogVerbose(@"%@ onLeaveCallRoomWithRequestId: %lld callRoomId: %@", LOG_TAG, requestId, callRoomId);

}

- (void)onMemberJoinCallRoomWithCallRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId p2pSessionId:(nullable NSUUID *)p2pSessionId status:(TLMemberStatus)status {
    DDLogVerbose(@"%@ onMemberJoinCallRoomWithCallRoomId: %@ memberId: %@ p2pSessionId: %@ status: %u", LOG_TAG, callRoomId, memberId, p2pSessionId, status);

    [self.service onMemberJoinCallRoomWithCallRoomId:callRoomId memberId:memberId p2pSessionId:p2pSessionId status:status];
}

- (void)onTransferDone {
    DDLogVerbose(@"%@ onTransferDone", LOG_TAG);

    [self.service onTransferDone];
}

@end

//
// Interface: CallServiceConversationServiceDelegate
//

@interface CallServiceConversationServiceDelegate : NSObject <TLConversationServiceDelegate>

@property (weak) CallService *service;

- (nonnull instancetype)initWithService:(nonnull CallService *)service;

@end

//
// Implementation: CallServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"CallServiceConversationServiceDelegate"

@implementation CallServiceConversationServiceDelegate

- (nonnull instancetype)initWithService:(nonnull CallService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onPushDescriptorRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPushDescriptorRequestId: %lld conversation: %@ objectDescriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    CallStateOperation *request;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self.service.callStateRequestIds) {
        request = self.service.callStateRequestIds[lRequestId];
        if (!request) {
            return;
        }
        [self.service.callStateRequestIds removeObjectForKey:lRequestId];
    }
    
    request.call.descriptorId = descriptor.descriptorId;
    [request.call checkOperation:START_CALL_DONE];
    
    for(CallConnection *connection in [request.call getConnections]){
        [self.service onOperationWithConnection:connection];
    }
    [self.service onOperationWithCallState:request.call];
}

- (void)onPopDescriptorWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopDescriptorWithRequestId: %lld conversation: %@ objectDescriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    CallStateOperation *request;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self.service.callStateRequestIds) {
        request = self.service.callStateRequestIds[lRequestId];
        if (!request) {
            return;
        }
        [self.service.callStateRequestIds removeObjectForKey:lRequestId];
    }
    
    request.call.descriptorId = descriptor.descriptorId;
    [request.call checkOperation:START_CALL_DONE];

    for(CallConnection *connection in [request.call getConnections]){
        [self.service onOperationWithConnection:connection];
    }
    [self.service onOperationWithCallState:request.call];
}

- (void)onUpdateDescriptorWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType {
    DDLogVerbose(@"%@ onUpdateDescriptorWithRequestId: %lld conversation: %@ objectDescriptor: %@ updateType: %u", LOG_TAG, requestId, conversation, descriptor, updateType);
    
    CallStateOperation *request;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self.service.callStateRequestIds) {
        request = self.service.callStateRequestIds[lRequestId];
        if (!request) {
            return;
        }
        [self.service.callStateRequestIds removeObjectForKey:lRequestId];
    }
    
    if (request.operation == ACCEPTED_CALL) {
        [request.call checkOperation:ACCEPTED_CALL_DONE];

    } else if (request.operation == TERMINATE_CALL) {
        [request.call checkOperation:TERMINATE_CALL_DONE];
    }
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);

    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    
    ConnectionOperation *connectionRequest;
    @synchronized(self.service.connectionRequestIds) {
        connectionRequest = self.service.connectionRequestIds[lRequestId];
        if (connectionRequest) {
            [self.service.connectionRequestIds removeObjectForKey:lRequestId];
        }
    }
    if (connectionRequest) {
        [self.service onErrorWithConnection:connectionRequest.callConnection operationId:connectionRequest.operation errorCode:errorCode errorParameter:errorParameter];
    }
    
    CallStateOperation* callRequest;
    @synchronized(self.service.callStateRequestIds) {
        callRequest = self.service.callStateRequestIds[lRequestId];
        if (callRequest) {
            [self.service.callStateRequestIds removeObjectForKey:lRequestId];
        }
    }
    if (callRequest) {
        [self.service onErrorWithCall:callRequest.call operationId:connectionRequest.operation errorCode:errorCode errorParameter:errorParameter];
    }
}

@end

//
// Implementation: CallService
//

#undef LOG_TAG
#define LOG_TAG @"CallService"

@implementation CallService

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext twinmeApplication:(nonnull TwinmeApplication *)twinmeApplication enableCallkit:(BOOL)enableCallkit {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ twinmeApplication: %@ enableCallkit: %d", LOG_TAG, twinmeContext, twinmeApplication, enableCallkit);
    
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;
        _twinmeApplication = twinmeApplication;
        
        _connected = [_twinmeContext isConnected];
        _inBackground = YES;
        _isTwinlifeReady = NO;
        _connectionRequestIds = [[NSMutableDictionary alloc] init];
        _callStateRequestIds = [[NSMutableDictionary alloc] init];
        _restarted = NO;
        _callkitCalls = [[NSMutableDictionary alloc] init];
        _peers = [[NSMutableDictionary alloc] init];
        _twinmeContextDelegate = [[CallServiceTwinmeContextDelegate alloc] initWithService:self];
        _peerConnectionServiceDelegate = [[CallServicePeerConnectionServiceDelegate alloc] initWithService:self];
        _peerCallServiceDelegate = [[CallServicePeerCallServiceDelegate alloc] initWithService:self];
        _conversationServiceDelegate = [[CallServiceConversationServiceDelegate alloc] initWithService:self];
        _notificationCenter = twinmeApplication.notificationCenter;
        _nextParticipantId = 0;
        [_twinmeContext addDelegate:self.twinmeContextDelegate];

        // Setup default WebRTC audio session configuration (category is AVAudioSessionCategoryPlayAndRecord)
        RTC_OBJC_TYPE(RTCAudioSessionConfiguration) *webRTCConfiguration = [RTC_OBJC_TYPE(RTCAudioSessionConfiguration) webRTCConfiguration];
        webRTCConfiguration.category = AVAudioSessionCategoryPlayAndRecord;
        webRTCConfiguration.categoryOptions = AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionAllowBluetoothA2DP;
        webRTCConfiguration.mode = AVAudioSessionModeVoiceChat;

        RTC_OBJC_TYPE(RTCAudioSession) *audioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
        [audioSession addDelegate:self];
        audioSession.isAudioEnabled = NO;
        audioSession.useManualAudio = YES;
        
        if (enableCallkit) {
            if (@available(iOS 13.0, *)) {
                _iosCallKitObligationFascism = YES;
            } else {
                _iosCallKitObligationFascism = NO;
            }
        } else {
            _iosCallKitObligationFascism = NO;
        }
    }
    return self;
}

- (nullable CXProvider *)cxProvider {
    DDLogVerbose(@"%@ cxProvider", LOG_TAG);

    if (!self.iosCallKitObligationFascism) {
        return nil;
    }

    // Create the provider on the first call (cannot be done earlier).
    CXProvider *provider = self.cxProviderInstance;
    if (provider == nil) {
        CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:TwinmeLocalizedString(@"application_name", nil)];
        configuration.supportsVideo = YES;
        configuration.maximumCallsPerCallGroup = 1;
#if defined(SKRED) || defined(TWINME_PLUS)
        configuration.includesCallsInRecents = ![self.twinmeApplication isRecentCallsHidden];
#endif
        configuration.supportedHandleTypes = [NSSet setWithObject:@(CXHandleTypeGeneric)];
        configuration.iconTemplateImageData = UIImagePNGRepresentation([UIImage imageNamed:@"call_kit_icon.png"]);
        
        NotificationSound *notificationCallSound = [self.twinmeApplication getNotificationSoundWithType:NotificationSoundTypeAudioCall];
        configuration.ringtoneSound = notificationCallSound != nil ? notificationCallSound.soundPath : @"twinme_audio_call.caf";

        // Make sure to create one instance of the CXProvider (defer the synchronization and use a check-lock-check pattern).
        @synchronized (self) {
            provider = self.cxProviderInstance;
            if (provider == nil) {
                provider = [[CXProvider alloc] initWithConfiguration:configuration];
                [provider setDelegate:self queue:nil];
                self.cxProviderInstance = provider;
            }
        }
    }
    return provider;
}

- (nullable CXCallController *)cxCallController {
    DDLogVerbose(@"%@ cxCallController", LOG_TAG);

    if (!self.iosCallKitObligationFascism) {
        return nil;
    }

    // Create the call controller on the first call and after the cxProvider (otherwise, controller will not work).
    CXCallController *callController = self.cxCallControllerInstance;
    if (callController == nil) {
        [self cxProvider];
        callController = [[CXCallController alloc] init];

        // Set an observer to be notified when a CXCall state is changed.  This is necessary
        // to be notified when an external call has terminated when we have been put on hold.
        // We can them resume our call correctly (see callObserver:callChanged:).
        [[callController callObserver] setDelegate:self queue:nil];
        self.cxCallControllerInstance = callController;
    }
    return callController;

}

- (CXProviderConfiguration *)getCallkitConfiguration:(BOOL)video originator:(nullable id<TLOriginator>)originator {
    DDLogVerbose(@"%@ getCallkitConfiguration: %@", LOG_TAG, video ? @"YES" : @"NO");
    
    CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:TwinmeLocalizedString(@"application_name", nil)];
    configuration.maximumCallsPerCallGroup = 1;
    BOOL recentCallsHidden = NO;
    
#if defined(SKRED) || defined(TWINME_PLUS)
    recentCallsHidden = [self.twinmeApplication isRecentCallsHidden];
#endif
    
    configuration.includesCallsInRecents = !recentCallsHidden && (!originator || !originator.identityCapabilities.hasDiscreet);
    configuration.supportedHandleTypes = [NSSet setWithObject:@(CXHandleTypeGeneric)];
    configuration.iconTemplateImageData = UIImagePNGRepresentation([UIImage imageNamed:@"call_kit_icon.png"]);
    configuration.supportsVideo = YES;
    
    BOOL enable = [self.twinmeApplication hasSoundEnable] && [self.twinmeApplication hasNotificationSoundWithType:video ? NotificationSoundTypeVideoCall : NotificationSoundTypeAudioCall];
    
    NotificationSound *notificationCallSound = [self.twinmeApplication getNotificationSoundWithType:video ? NotificationSoundTypeVideoCall:NotificationSoundTypeAudioCall];
    
    NSString *soundPath = @"twinme_audio_call.caf";
    if (notificationCallSound) {
        soundPath = notificationCallSound.soundPath;
    }
    
    configuration.ringtoneSound = enable ? soundPath : @"silence.mp3";
    
    return configuration;
}

- (nonnull CXCallUpdate *)createCXCallUpdate:(nonnull id<TLOriginator>)originator video:(BOOL)video {
    DDLogInfo(@"%@ createCXHandle: %@", LOG_TAG, originator);

    NSString *handleId = [NSString stringWithFormat:@"%@:%@", [TLTwinmeContext APPLICATION_SCHEME], [NSUUID fromUUID:originator.uuid]];
    CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
    callUpdate.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:handleId];
    callUpdate.hasVideo = video;
    callUpdate.supportsDTMF = NO;
    callUpdate.supportsHolding = YES;
    callUpdate.supportsGrouping = YES;
    
    NSString *callerName = originator.name;
    if (originator.identityCapabilities.hasDiscreet || !callerName) {
        callerName = TwinmeLocalizedString(@"history_view_controller_incoming_call", nil);
    }
    callUpdate.localizedCallerName = callerName;
    return callUpdate;
}

- (void)startCallWithOriginator:(nonnull id<TLOriginator>)originator mode:(CallStatus)mode viewController:(nonnull CallViewController *)viewController {
    if ([originator class] == [TLContact class]){
        [self startCallWithContact:((TLContact *)originator) mode:mode viewController:viewController];
    } else if ([originator class] == [TLGroup class]){
        [self startCallWithGroup:((TLGroup *)originator) mode:mode viewController:viewController];
    }
}

- (void)startCallWithContact:(nonnull TLContact *)contact mode:(CallStatus)mode viewController:(nonnull CallViewController *)viewController{
    DDLogInfo(@"%@ startCallWithContact: %@ mode: %ld", LOG_TAG, contact.name, (long)mode);
    
    CallConnection *connection;
    CallState *call;
    @synchronized (self) {
        call = self.activeCall;

        // A call is already in progress or is being finished, send the current state so that the UI can be updated.
        if (call && [call status] != CallStatusTerminated) {

            return;
        }
        
        call = [[CallState alloc] initWithOriginator:contact callService:self peerCallService:[self.twinmeContext getPeerCallService] callKitUUID:nil];

        [call setAudioVideoStateWithCallStatus:mode];
        
        connection = [[CallConnection alloc] initWithCallService:self serializerFactory:[self.twinmeContext getSerializerFactory] call:call originator:contact mode:mode peerConnectionId:nil retryState:0 memberId:nil];

        [call addPeerWithConnection:connection];
        self.activeCall = call;
        
        TLSchedule *schedule = contact.capabilities.schedule;
        
        if (schedule && ![schedule isNowInRange]) {
            [self terminateCallWithTerminateReason:TLPeerConnectionServiceTerminateReasonSchedule];
            return;
        }

        // Discreet relation: do not create the CallDescriptor.
        if (contact.identityCapabilities.hasDiscreet) {
            [call checkOperation:START_CALL];
            [call checkOperation:START_CALL_DONE];
        }
        self.viewController = viewController;
        self.audioMuteOn = NO;
        self.cameraMuteOn = NO;
        self.onHold = NO;
        self.inBackground = NO; // This is an outgoing call, we are not in background.
    
        BOOL speaker = NO;
        if (CALL_IS_VIDEO(mode)) {
            RTC_OBJC_TYPE(RTCAudioSession) *rtcAudioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
            for (AVAudioSessionPortDescription *portDescription in rtcAudioSession.currentRoute.outputs) {
                if ([portDescription.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker] || [portDescription.portType isEqualToString:AVAudioSessionPortBuiltInReceiver]) {
                    speaker = YES;
                    break;
                }
            }
        }
        
        [self setSpeaker:speaker];
    }
    call.identityAvatar = [[self.twinmeContext getImageService] getCachedImageWithImageId:contact.identityAvatarId kind:TLImageServiceKindThumbnail];
    
    [self onOperationWithCallState:call];
    [self onOperationWithConnection:connection];
}

- (void)startCallWithGroup:(nonnull TLGroup *)group mode:(CallStatus)mode viewController:(nonnull CallViewController *)viewController{
    DDLogInfo(@"%@ startCallWithGroup: %@ mode: %ld", LOG_TAG, group.name, (long)mode);
    
    CallState *call;
    @synchronized (self) {
        call = self.activeCall;
        
        // A call is already in progress or is being finished, send the current state so that the UI can be updated.
        if (call && [call status] != CallStatusTerminated) {
            
            return;
        }
        
        call = [[CallState alloc] initWithOriginator:group callService:self peerCallService:[self.twinmeContext getPeerCallService] callKitUUID:nil];
        
        // Discreet relation: do not create the CallDescriptor (not activated for the group).
        if (group.identityCapabilities.hasDiscreet) {
            [call checkOperation:START_CALL];
            [call checkOperation:START_CALL_DONE];
        }
        [call setAudioVideoStateWithCallStatus:mode];
        self.activeCall = call;
        
        self.viewController = viewController;
        self.audioMuteOn = NO;
        self.cameraMuteOn = NO;
        self.onHold = NO;
        self.inBackground = NO; // This is an outgoing call, we are not in background.
        
        BOOL speaker = NO;
        if (CALL_IS_VIDEO(mode)) {
            RTC_OBJC_TYPE(RTCAudioSession) *rtcAudioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
            for (AVAudioSessionPortDescription *portDescription in rtcAudioSession.currentRoute.outputs) {
                if ([portDescription.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker] || [portDescription.portType isEqualToString:AVAudioSessionPortBuiltInReceiver]) {
                    speaker = YES;
                    break;
                }
            }
        }
        [self setSpeaker:speaker];
    }
    
    call.identityAvatar = [[self.twinmeContext getImageService] getCachedImageWithImageId:group.identityAvatarId kind:TLImageServiceKindThumbnail];
    call.groupAvatar = [[self.twinmeContext getImageService] getCachedImageWithImageId:group.groupAvatarId kind:TLImageServiceKindThumbnail];
    
    // Perform Step 1 (descriptor creation).
    // Once it's done onOperationWithConnection will be called for each of the call's current connections.
    [self onOperationWithCallState:call];

    [self.twinmeContext listGroupMembersWithGroup:group filter:TLGroupMemberFilterTypeJoinedMembers withBlock:^(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> *members) {
        if (errorCode == TLBaseServiceErrorCodeSuccess) {
            [self startCallWithGroupMembers:members mode:mode];
        } else {
            [self onErrorWithCall:call operationId:START_CALL errorCode:errorCode errorParameter:nil];
        }
    }];
}

- (void)startCallWithGroupMembers:(nonnull NSMutableArray<TLGroupMember *> *)members mode:(CallStatus)mode {
    DDLogInfo(@"%@ startCallWithMembers: %@ mode: %ld", LOG_TAG, members, (long)mode);
    
    CallState *call;
    @synchronized (self) {
        call = self.activeCall;
    }
    if (!call) {
        return;
    }

    // Create the CallConnection for each group member (according to its schedule).
    // Do not create the P2P connection yet until we have filled the CallState with every member.
    NSMutableArray<CallConnection *> *connections = [[NSMutableArray alloc] init];
    for (TLGroupMember *member in members) {
        TLSchedule *schedule = member.capabilities.schedule;
        if (schedule && ![schedule isNowInRange]) {
            continue;
        }

        CallConnection *connection = [[CallConnection alloc] initWithCallService:self serializerFactory:[self.twinmeContext getSerializerFactory] call:call originator:member mode:mode peerConnectionId:nil retryState:0 memberId:nil];
        DDLogVerbose(@"%@ startCallWithGroup: created connection with peerConnectionId: %@",LOG_TAG, connection.peerConnectionId);
        [call addPeerWithConnection:connection];
        [connections addObject:connection];
    }

    // Start the call connection once we know every member.
    if ([call isDoneOperation:START_CALL_DONE]) {
        for (CallConnection *connection in connections) {
            [self onOperationWithConnection: connection];
        }
    }
}

- (void)startCallWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId originator:(nonnull id<TLOriginator>)originator offer:(nonnull TLOffer *)offer inBackground:(BOOL)inBackground fromPushKit:(BOOL)fromPushKit {
    DDLogInfo(@"%@ startCallWithPeerConnectionId: %@ originator: %@ offer: %@ inBackground: %@ fromPushKit: %@", LOG_TAG, peerConnectionId, originator.name, offer, inBackground ? @"YES" : @"NO", fromPushKit ? @"YES" : @"NO");
    
    CallStatus mode;
    if (offer.videoBell) {
        mode = CallStatusIncomingVideoBell;
    } else if (offer.video) {
        mode = CallStatusIncomingVideoCall;
    } else {
        mode = CallStatusIncomingCall;
    }

    BOOL mustTerminate = NO;
    TLPeerConnectionServiceTerminateReason reason = TLPeerConnectionServiceTerminateReasonUnknown;
    BOOL callIsKnown = NO;
    BOOL autoAccept = NO;
    BOOL video = CALL_IS_VIDEO(mode);
    CallConnection *connection;
    CallState *call;
    @synchronized (self) {
        connection = self.peers[peerConnectionId];
        call = self.activeCall;

        // For an incoming call, a first invocation is made due to the wakeup and notification handling
        // and a second call is made when the session-initiate is received.  Sometimes, we may also see
        // a third call 4-5 seconds after the first one due to the server batch processing.
        // Furthermore, sometimes the first call is made from PushKit followed by the call
        // from the session-initiate event, but in other cases this is the opposite!
        // When we are called from PushKit first, it could happen that the PeerConnectionService
        // does not yet know the P2P connection id and it will reject the createIncomingPeerConnection call!
        if (connection) {
            if (!fromPushKit && [connection isDoneOperation:CREATE_INCOMING_PEER_CONNECTION_DONE readyFor:CREATE_INCOMING_PEER_CONNECTION]) {
                return;
            }
            
            // It is critical that we make a call to CallKit API otherwise iOS 13 will kill us.
            // The call to reportNewIncomingCallWithUUID() could have been made before when
            // the session-initiate event was handled before the pushKit operation.
            callIsKnown = call && self.callkitCalls[call.callKitUUID];
            mustTerminate = call == nil;
            
        } else if (call && [call status] != CallStatusTerminated) {
            if ([call isCallWithGroupMember:originator]) {
                // We must not create the CallConnection if we have an incoming group call (see below)
                if (![originator isKindOfClass:[TLGroup class]] && !fromPushKit) {
                    connection = [[CallConnection alloc] initWithCallService:self serializerFactory:[self.twinmeContext getSerializerFactory] call:call originator:originator mode:mode peerConnectionId:peerConnectionId retryState:fromPushKit ? CREATE_INCOMING_PEER_CONNECTION : 0 memberId:nil];
                    [connection checkOperation:CREATE_OUTGOING_PEER_CONNECTION];
                    self.peers[peerConnectionId] = connection;
                    [call addPeerWithConnection:connection];
                    autoAccept = YES;
                }
                callIsKnown = self.callkitCalls[call.callKitUUID];

            } else if ([call autoAcceptNewParticipantWithOriginator:originator]) {
                // Create the call connection and proceed to honor PushKit+CallKit rules.
                connection = [[CallConnection alloc] initWithCallService:self serializerFactory:[self.twinmeContext getSerializerFactory] call:call originator:originator mode:mode peerConnectionId:peerConnectionId retryState:fromPushKit ? CREATE_INCOMING_PEER_CONNECTION : 0 memberId:nil];
                [connection checkOperation:CREATE_OUTGOING_PEER_CONNECTION];
                self.peers[peerConnectionId] = connection;
                [call addPeerWithConnection:connection];
                if (offer.transfer && [connection isTransferConnection] == TransferConnectionYes) {
                    call.transferDirection = TO_BROWSER;
                }
                callIsKnown = YES;
                autoAccept = YES;

            } else if (self.holdCall) {
                // We're already in a double call, reject the new one.
                mustTerminate = YES;
                reason = TLPeerConnectionServiceTerminateReasonBusy;
            }
        } else if (call && [call.callKitUUID isEqual:peerConnectionId]) {
            // This incoming call is matching our CallKit Id but we have no CallConnection yet.
            // This occurs if we got a first call to startCallWithPeerConnectionId from PushKit
            // from a TLGroup originator, the CallState was created without a CallConnection until
            // we identify the TLGroupMember that is calling it.  Now, we have it!
            connection = [[CallConnection alloc] initWithCallService:self serializerFactory:[self.twinmeContext getSerializerFactory] call:call originator:originator mode:mode peerConnectionId:peerConnectionId retryState:fromPushKit ? CREATE_INCOMING_PEER_CONNECTION : 0 memberId:nil];
            [connection checkOperation:CREATE_OUTGOING_PEER_CONNECTION];
            self.peers[peerConnectionId] = connection;
            [call addPeerWithConnection:connection];
            callIsKnown = YES;
        }
                
        if (!connection && !mustTerminate && !callIsKnown) {
            TLSchedule *schedule = originator.identityCapabilities.schedule;
        
            if (schedule && ![schedule isNowInRange]) {
                mustTerminate = YES;
                reason = TLPeerConnectionServiceTerminateReasonSchedule;
            } else {
                id<TLOriginator> conversationOwner = originator;
                
                if ([originator class] == [TLGroupMember class]) {
                    conversationOwner = ((TLGroupMember *)originator).group;
                }
                
                call = [[CallState alloc] initWithOriginator:conversationOwner callService:self peerCallService:[self.twinmeContext getPeerCallService] callKitUUID:peerConnectionId];

                // Discreet relation: do not create the CallDescriptor.
                if (originator.identityCapabilities.hasDiscreet) {
                    [call checkOperation:START_CALL];
                    [call checkOperation:START_CALL_DONE];
                }

                [call setAudioVideoStateWithCallStatus:mode];
                
                if (!self.activeCall) {
                    self.activeCall = call;
                } else {
                    self.holdCall = call;
                }

                // We must not create the CallConnection if we have an incoming group call
                // that comes from PushKit: we must wait for the second call to startCallWithPeerConnectionId
                // because it identifies the group member that is doing the call so that we have the correct
                // twincode keys and secrets to decrypt the SDPs.
                if (!fromPushKit || ![originator isKindOfClass:[TLGroup class]]) {
                    connection = [[CallConnection alloc] initWithCallService:self serializerFactory:[self.twinmeContext getSerializerFactory] call:call originator:originator mode:mode peerConnectionId:peerConnectionId retryState:fromPushKit ? CREATE_INCOMING_PEER_CONNECTION : 0 memberId:nil];
                    [connection checkOperation:CREATE_OUTGOING_PEER_CONNECTION];
                    self.peers[peerConnectionId] = connection;
                    [call addPeerWithConnection:connection];
                    
                    // Transfer to the browser is handled in handleIncomingCallDuringActiveCall
                    call.transferDirection = [connection isTransferConnection] == TransferConnectionYes ? TO_DEVICE : NONE;
                    
                } else {
                    DDLogError(@"%@ Skipped creation of CallConnection for group: %@", LOG_TAG, originator);
                }
                
                self.audioMuteOn = NO;
                self.cameraMuteOn = NO;
                self.onHold = NO;
                self.inBackground = inBackground;
                
                BOOL speaker = NO;
                if (video) {
                    RTC_OBJC_TYPE(RTCAudioSession) *rtcAudioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
                    for (AVAudioSessionPortDescription *portDescription in rtcAudioSession.currentRoute.outputs) {
                        if ([portDescription.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker] || [portDescription.portType isEqualToString:AVAudioSessionPortBuiltInReceiver]) {
                            speaker = YES;
                            break;
                        }
                    }
                }
                [self setSpeaker:speaker];
            }
        }
    }

    // Setup to listen for events on the peer connection in case it terminates before it is accepted.
    // If we fail to listen, the incoming connection is gone and we must terminate properly for PushKit+CallKit.
    if (!mustTerminate && [[self.twinmeContext getPeerConnectionService] listenWithPeerConnectionId:peerConnectionId delegate:self] != TLBaseServiceErrorCodeSuccess) {

        if (!fromPushKit) {
            @synchronized (self) {
                // Because we added a CallConnection that does not exist, we have to remove it.
                [self.peers removeObjectForKey:peerConnectionId];
             
                // And if we created a new CallState, we also have to clear its instance.
                if (CALL_IS_INCOMING(call.status)) {
                    if (call == self.activeCall) {
                        self.activeCall = nil;
                    } else if (call == self.holdCall) {
                        self.holdCall = nil;
                    }
                }
            }
        }

        // However, we MUST not terminate if we come from PushKit because sometimes the P2P incoming connection
        // is not yet known.
        mustTerminate = !fromPushKit;
        if (mustTerminate) {
            reason = TLPeerConnectionServiceTerminateReasonGone;
        }
    }
    
    if (mustTerminate) {
        [[self.twinmeContext getPeerConnectionService] terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:reason];
        
        // Honor the PushKit+CallKit invocation for iOS 13.
        if (self.cxProvider && fromPushKit) {
            CXCallUpdate *callUpdate = [self createCXCallUpdate:originator video:NO];

            // Report with the peerConnectionId because we have no call when this happens.
            [self.cxProvider reportNewIncomingCallWithUUID:peerConnectionId update:callUpdate completion:^(NSError * _Nullable error) {
                [self.cxProvider reportCallWithUUID:peerConnectionId endedAtDate:nil reason:CXCallEndedReasonRemoteEnded];
            }];
        }
        return;
    }

    // If this connection is auto-accepted, change to the ACCEPTED state and setup the corresponding timer.
    if (autoAccept && connection) {
        DDLogInfo(@"%@ auto accept %@ for call %@", LOG_TAG, peerConnectionId, call);

        [connection setTimerWithStatus:CALL_TO_ACCEPTED([connection status]) delay:CONNECT_TIMEOUT];
    }

    // Another corner case: we are called a second time after PushKit but now we are sure that the P2P
    // connection is known by the PeerConnectionService and we can proceed with the CREATE_INCOMING
    // operation may be for the second time.
    if (callIsKnown && !fromPushKit) {
        [self onOperationWithConnection:connection];
        return;
    }

    // Report the call by using CallKit even if we are in foreground because we have some cases
    // where a PushKit invocation is received and must be followed by a call to CallKit on iOS >= 13
    // (a kind of anti-democratic and fasist behavior).
    if (self.cxProvider && (self.iosCallKitObligationFascism || inBackground)) {
        CXCallUpdate *callUpdate = [self createCXCallUpdate:originator video:video];

        __weak CallService *weakSelf = self;
        self.cxProvider.configuration = [self getCallkitConfiguration:video originator:originator];
        [self.cxProvider reportNewIncomingCallWithUUID:call.callKitUUID update:callUpdate completion:^(NSError * _Nullable error) {
            if (weakSelf) {
                __strong CallService *strongSelf = weakSelf;
                if (error) {
                    // We may call reportNewIncomingCallWithUUID() two times for the same call.
                    // The DoNotDisturb may block the call.  The call is still processed so that
                    // it appears in the missed calls.
                    if (error.code != CXErrorCodeIncomingCallErrorCallUUIDAlreadyExists && error.code != CXErrorCodeIncomingCallErrorFilteredByBlockList && error.code != CXErrorCodeIncomingCallErrorFilteredByDoNotDisturb) {
                        NSLog(@"reportNewIncomingCallWithUUID error: %@ pushKit: %d", error, fromPushKit);
                        TL_ASSERTION(self.twinmeContext, [CallsAssertPoint CALLKIT_START_ERROR], [TLAssertValue initWithPeerConnectionId:peerConnectionId], [TLAssertValue initWithNSError:error], nil);
                        // [strongSelf terminateCallWithTerminateReason:TLPeerConnectionServiceTerminateReasonDecline];
                    }
                } else if (strongSelf) {
                    DDLogVerbose(@"%@ completion: reportNewIncomingCallWithUUID: %@", LOG_TAG, peerConnectionId);
                    
                    // Remember this was a successfull CallKit invocation so that we close it.
                    long callCount;
                    @synchronized (strongSelf) {
                        strongSelf.callkitCalls[call.callKitUUID] = call;
                        callCount = strongSelf.callkitCalls.count;
                    }
                    [[strongSelf.twinmeContext getJobService] reportActiveVoIPWithCallCount:callCount fetchCompletionHandler:nil];
                }
            }
        }];
    } else if (!callIsKnown) {
        // Even if we are in foreground, notify CallKit that a call is in progress but we want our own UI.
        // Calling reportNewIncomingCallWithUUID will display CallKit UI which is weird.
        if (self.cxCallController) {
            CXCallUpdate *callUpdate = [self createCXCallUpdate:originator video:video];
            
            DDLogVerbose(@"%@ calling CallKit requestTransaction: %@", LOG_TAG, peerConnectionId);
            
            CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:call.callKitUUID handle:callUpdate.remoteHandle];
            startCallAction.video = video;
            CXTransaction *transaction = [[CXTransaction alloc] init];
            [transaction addAction:startCallAction];
            __weak CallService *weakSelf = self;
            [self.cxCallController requestTransaction:transaction completion:^(NSError * _Nullable error) {
                CallService *strongSelf = weakSelf;
                if (error) {
                    NSLog(@"requestTransaction failed: %@", error.localizedDescription);
                    TL_ASSERTION(self.twinmeContext, [CallsAssertPoint CALLKIT_START_ERROR], [TLAssertValue initWithPeerConnectionId:peerConnectionId], [TLAssertValue initWithNSError:error], nil);

                } else if (strongSelf) {
                    
                    // Remember this was a successfull CallKit invocation so that we close it.
                    long callCount;
                    @synchronized (strongSelf) {
                        strongSelf.callkitCalls[call.callKitUUID] = call;
                        callCount = strongSelf.callkitCalls.count;
                    }
                    [[strongSelf.twinmeContext getJobService] reportActiveVoIPWithCallCount:callCount fetchCompletionHandler:nil];

                    [self.cxProvider reportCallWithUUID:call.callKitUUID updated:callUpdate];
                    // The activateAudio will be called through CallKit callback didActivateAudioSession.
                }
            }];
        } else {
            DDLogVerbose(@"%@ calling activateAudio without CallKit", LOG_TAG);
            
            long callCount;
            @synchronized (self) {
                self.callkitCalls[call.callKitUUID] = call;
                callCount = self.callkitCalls.count;
            }
            [[self.twinmeContext getJobService] reportActiveVoIPWithCallCount:callCount fetchCompletionHandler:nil];
            
            // Play the audio call ringtone after activating the audio.
            [self activateAudioWithCall:call];
        }
        
        if (mode != CallStatusIncomingVideoBell) {
            self.notification = [self.notificationCenter createIncomingCallNotificationWithOriginator:originator notificationId:call.callKitUUID audio:YES video:video videoBell:NO];
        } else {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                ApplicationDelegate *delegate = (ApplicationDelegate *)[[UIApplication sharedApplication] delegate];
                MainViewController *mainViewController = delegate.mainViewController;
                
                UIViewController *topViewController = [UIViewController topViewController];
                if (topViewController.presentingViewController) {
                    [topViewController dismissViewControllerAnimated:NO completion:^{
                    }];
                } else if (topViewController.presentedViewController) {
                    [topViewController.presentedViewController dismissViewControllerAnimated:NO completion:^{
                    }];
                }
                
                CallViewController *callViewController = (CallViewController *)[[UIStoryboard storyboardWithName:@"Call" bundle:nil] instantiateViewControllerWithIdentifier:@"CallViewController"];
                self.viewController = callViewController;
                [callViewController initCallWithOriginator:call.originator isVideoCall:CALL_IS_VIDEO(mode)];
                [mainViewController.selectedViewController pushViewController:callViewController animated:NO];
            });
        }
    }
    call.identityAvatar = [[self.twinmeContext getImageService] getCachedImageWithImageId:originator.identityAvatarId kind:TLImageServiceKindThumbnail];

    [self onOperationWithCallState:call];
    if (connection) {
        [self onOperationWithConnection:connection];
    }
}

- (void)onTransferRequestWithConnectionId:(nonnull NSUUID *)peerConnectionId originator:(id<TLOriginator>)originator {
    DDLogVerbose(@"%@ onTransferRequestWithConnectionId: %@ originator:%@", LOG_TAG, peerConnectionId, originator);

    if ([(NSObject *)originator class] != [TLCallReceiver class] || !((TLCallReceiver *)originator).capabilities.hasTransfer){
        DDLogVerbose(@"%@ Transfer request received on invalid CallReceiver: %@", LOG_TAG, originator);
        return;
    }

    //TODO: prompt the user to accept/deny the transfer
    [self acceptTransferWithConnectionId:peerConnectionId];
}


- (void)addCallParticipantWithOriginator:(nonnull id<TLOriginator>)originator {
    DDLogVerbose(@"%@ addCallParticipantWithOriginator: %@", LOG_TAG, originator);
    
    CallConnection *connection;
    @synchronized (self) {
        CallState *call = self.activeCall;

        // A call is already in progress or is being finished, send the current state so that the UI can be updated.
        if (!call || [call status] == CallStatusTerminated) {

            return;
        }

        CallStatus mode = call.videoSourceOn ? CallStatusOutgoingVideoCall : CallStatusOutgoingCall;
        connection = [[CallConnection alloc] initWithCallService:self serializerFactory:[self.twinmeContext getSerializerFactory] call:call originator:originator mode:mode peerConnectionId:nil retryState:0 memberId:nil];

        connection.peerTwincodeOutboundId = originator.peerTwincodeOutboundId;
        [call addPeerWithConnection:connection];
    }
    
    [self onOperationWithConnection:connection];
}

- (void)applicationDidEnterBackground:(nonnull UIApplication *)application {
    DDLogVerbose(@"%@ applicationDidEnterBackground: %@", LOG_TAG, application);

    // Mute the camera if we have an active call which is using it.
    // By muting the camera, the peer will display our avatar instead of a freezed image.
    @synchronized (self) {
        if (self.activeCall && !CALL_IS_ON_HOLD([self.activeCall status]) && self.activeCall.videoSourceOn) {
            [self setCameraMute:YES];
            self.restartCameraCall = self.activeCall;
        }
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    DDLogVerbose(@"%@ applicationWillEnterForeground: %@", LOG_TAG, application);
    
    // Check if an Audio/Video call is in progress and there is no view: it means CallKit has
    // setup the call and the application is now in the foreground to handle the call.
    // We must create the Audio/Video view controller only if necessary.
    CallStatus callStatus;
    CallState *call;
    CallState *restartCameraCall;
    BOOL hasViewController;
    @synchronized (self) {
        restartCameraCall = self.restartCameraCall;
        hasViewController = self.viewController != nil;
        self.restartCameraCall = nil;
        call = self.activeCall;
        if (!call) {
            return;
        }

        callStatus = [call status];
        if (CALL_IS_TERMINATED(callStatus)) {
            return;
        }
    }

    // The camera was muted while we are in background, restore it if the call is running and currently active, otherwise only restore the call's videoSourceOn
    if (restartCameraCall) {
        if (restartCameraCall == call && CALL_IS_ACTIVE(callStatus)) {
            [self setCameraMute:NO];
        } else {
            restartCameraCall.videoSourceOn = YES;
        }
    }
    if (hasViewController) {
        return;
    }
    
    // Note: we are running from the main thread.
    ApplicationDelegate *delegate = (ApplicationDelegate *)[application delegate];
    MainViewController *mainViewController = delegate.mainViewController;
    [mainViewController removeCallFloatingView];
    UIViewController *topViewController = [UIViewController topViewController];
    if (topViewController.presentingViewController) {
        [topViewController dismissViewControllerAnimated:NO completion:^{
        }];
    } else if (topViewController.presentedViewController) {
        [topViewController.presentedViewController dismissViewControllerAnimated:NO completion:^{
        }];
    }

    // If there is a previous CallViewController it is terminated and it's better to drop it and get a new
    // one with the new call, new contact and new state.
    if ([topViewController isKindOfClass:[CallViewController class]]) {
        [mainViewController.selectedViewController popViewControllerAnimated:NO];
    }
    
    CallViewController *callViewController = (CallViewController *)[[UIStoryboard storyboardWithName:@"Call" bundle:nil] instantiateViewControllerWithIdentifier:@"CallViewController"];
    [callViewController initCallWithOriginator:call.originator isVideoCall:CALL_IS_VIDEO(callStatus)];
    self.viewController = callViewController;
    [mainViewController.selectedViewController pushViewController:callViewController animated:NO];
}

- (BOOL)isCallkitCall:(nonnull NSUUID *)callkitUUID {
    DDLogVerbose(@"%@ isCallkitCall: %@", LOG_TAG, callkitUUID);
    
    @synchronized (self) {
        return self.callkitCalls[callkitUUID] != nil;
    }
}

- (BOOL)isPeerConnection:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ isPeerConnection: %@", LOG_TAG, peerConnectionId);
    
    @synchronized (self) {
        CallConnection *callConnection = self.peers[peerConnectionId];
        return callConnection != nil;
    }
}

- (nullable CallConnection *)findConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ findConnectionWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);

    @synchronized (self) {
        return self.peers[peerConnectionId];
    }
}

- (BOOL)isConnected {
    DDLogVerbose(@"%@ isConnected", LOG_TAG);
    
    return self.connected;
}

- (BOOL)isAudioMuted {
    DDLogVerbose(@"%@ isAudioMuted", LOG_TAG);
    
    return self.audioMuteOn;
}

- (BOOL)isSpeakerOn {
    DDLogVerbose(@"%@ isSpeakerOn", LOG_TAG);
    
    return self.speakerOn;
}

- (BOOL)isCameraMuted {
    DDLogVerbose(@"%@ isCameraMuted", LOG_TAG);

    @synchronized (self) {
        // If there is no active call, the camera is muted.
        CallState *call = self.activeCall;
        if (!call) {
            return YES;
        }

        // If the current call does not use the video, the camera is muted.
        if (!call.videoSourceOn) {
            return YES;
        }
    }

    return self.cameraMuteOn;
}

- (BOOL)isFrontCamera {
    DDLogVerbose(@"%@ isFrontCamera", LOG_TAG);

    @synchronized (self) {
        if (self.activeCall) {
            return self.activeCall.frontCameraOn;
        }
        return YES;
    }
}

- (CallStatus)callStatus {
    DDLogVerbose(@"%@ callStatus", LOG_TAG);
    
    @synchronized (self) {
        CallState *call = self.activeCall;
        if (!call) {
            return CallStatusNone;
        }

        return [call status];
    }
}

- (NSTimeInterval)duration {
    
    NSTimeInterval startTime;
    @synchronized (self) {
        CallState *call = self.activeCall;
        if (!call) {
            return 0.0;
        }

        CallStatus callStatus = [call status];
        if (!CALL_IS_ACTIVE(callStatus) && !CALL_IS_ON_HOLD((callStatus))) {
            return 0.0;
        }
        startTime = call.connectionStartTime;
    }
    
    return [[NSDate date] timeIntervalSince1970] - startTime;
}

- (nullable CallState *)currentCall {
    DDLogVerbose(@"%@ currentCall", LOG_TAG);

    @synchronized (self) {
        
        return self.activeCall;
    }
}

- (nullable CallState *)currentHoldCall {
    DDLogVerbose(@"%@ currentHoldCall", LOG_TAG);

    @synchronized (self) {
        
        return self.holdCall;
    }
}

- (nullable RTC_OBJC_TYPE(RTCVideoTrack) *)localVideoTrack {
    DDLogVerbose(@"%@ localVideoTrack", LOG_TAG);
    
    @synchronized (self) {
        CallState *callState = self.activeCall;
        return callState ? self.currentLocalVideoTrack : nil;
    }
}

- (void)startRingtoneWithNotificationSoundType:(NotificationSoundType)type {
    DDLogInfo(@"%@ startRingtoneWithNotificationSoundType: %u", LOG_TAG, type);
    
    BOOL repeat;
    BOOL enable;
    NSString *category = AVAudioSessionCategoryPlayback;
    if (type == NotificationSoundTypeAudioCallEnd) {
        repeat = NO;
        category = AVAudioSessionCategoryPlayAndRecord;
        enable = YES;
    } else if (type == NotificationSoundTypeAudioCalling || type == NotificationSoundTypeVideoCalling || type == NotificationSoundTypeAudioRinging) {
        repeat = YES;
        category = AVAudioSessionCategoryPlayAndRecord;
        enable = YES;
    } else {
        repeat = YES;
        category = AVAudioSessionCategoryPlayback;
        enable = [self.twinmeApplication hasSoundEnable] && [self.twinmeApplication hasNotificationSoundWithType:type];
    }
    if (enable) {
        self.notificationSound = [self.twinmeApplication getNotificationSoundWithType:type];
        if (self.notificationSound) {
            [self.notificationSound playWithLoop:repeat audioSessionCategory:category];
        }
        [self setSpeaker:self.speakerOn];
    }
}

- (void)stopRingtone {
    DDLogInfo(@"%@ stopRingtone", LOG_TAG);
    
    if (self.notificationSound) {
        [self.notificationSound dispose];
        self.notificationSound = nil;
    }
}

- (void)acceptCall {
    [self acceptCallWithCall:[self currentCall]];
}

- (void)acceptCallWithCallkitUUID:(nonnull NSUUID *)callkitUUID {
    CallState *call;
    @synchronized (self) {
        call = self.callkitCalls[callkitUUID];
    }
    if (call) {
        [self acceptCallWithCall:call];
    }
}

- (void)acceptCallWithCall:(nonnull CallState *)call {
    DDLogVerbose(@"%@ acceptCall", LOG_TAG);
    
    CallConnection *connection;
    CallStatus status;
    BOOL switchCall;
    @synchronized (self) {
        if (!call) {
            return;
        }

        status = [call status];
        if (!CALL_IS_INCOMING(status)) {
            return;
        }
        
        connection = [call initialConnection];
        if (!connection) {
            return;
        }
        switchCall = call == self.holdCall;
    }

    if (status == CallStatusIncomingVideoBell) {
        [connection initSourcesAfterOperation:CREATED_PEER_CONNECTION];
        [self onChangeConnectionStateWithConnection:connection state:connection.connectionState];
    } else {
        [self stopRingtone];
        
        [connection setTimerWithStatus:CALL_TO_ACCEPTED(status) delay:CONNECT_TIMEOUT];

        [self onOperationWithConnection:connection];
    }
    
    if (switchCall) {
        [self switchCall];
    }
}

- (void)acceptTransferWithConnectionId:(NSUUID *)connectionId {
    DDLogVerbose(@"%@ acceptTransferWithConnectionId: %@", LOG_TAG, connectionId);

    CallConnection *connection;
    CallState *call;
    CallStatus status;
    @synchronized (self) {
        call = self.activeCall;
        if (!call) {
            return;
        }

        status = [call status];
        if (!CALL_IS_ACTIVE(status) && !CALL_IS_ON_HOLD(status)) {
            return;
        }
        
        connection = [call getConnectionWithId:connectionId];
        if (!connection) {
            return;
        }
        // Clear the possible CALL_OUTGOING flag because this is an incoming connection.
        status &= ~CALL_OUTGOING;
    }
    [connection setTimerWithStatus:CALL_TO_ACCEPTED(status) delay:CONNECT_TIMEOUT];

    [self onOperationWithConnection:connection];
}

- (BOOL)startStreamingWithMediaItem:(nonnull MPMediaItem *)mediaItem {
    DDLogVerbose(@"%@ startStreamingWithMediaItem: %@", LOG_TAG, mediaItem);

    CallState *call;
    @synchronized (self) {
        call = self.activeCall;
        if (!call) {
            return NO;
        }

        CallStatus status = [call status];
        if (!CALL_IS_ACTIVE(status)) {
            return NO;
        }
    }
    
    return [call startStreamingWithMediaItem:mediaItem];
}

- (void)stopStreaming {
    DDLogVerbose(@"%@ stopStreaming", LOG_TAG);

    CallState *call = [self currentCall];
    if (call) {
        [call stopStreaming];
    }
}

- (void)terminateCallWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    CallState *call = [self currentCall];
    if (call) {
        [self terminateCallWithCall:call terminateReason:terminateReason];
    }
}

- (void)terminateCallWithCall:(nonnull CallState *)call terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogInfo(@"%@ terminateCallWithCall: %@ terminateReason: %d", LOG_TAG, call, terminateReason);

    NSArray<CallConnection *> *connections;
    CallState *holdCall;
    @synchronized (self) {
        holdCall = self.holdCall;
        if (call.terminateReason == TLPeerConnectionServiceTerminateReasonUnknown) {
            call.terminateReason = terminateReason;
        }
        if (self.callkitCalls[call.callKitUUID] && self.cxCallController) {
            connections = nil;
        } else {
            connections = [call getConnections];

            // This should not happen but just in case: invalidate the active call if there is no P2P connection.
            if (connections.count == 0 && terminateReason != TLPeerConnectionServiceTerminateReasonMerge) {
                if (call == holdCall) {
                    self.holdCall = nil;
                } else {
                    self.activeCall = nil;
                    if (!holdCall) {
                        self.viewController = nil;
                    }
                }
            }
        }
    }

    if (call.callRoomId) {
        [call leaveCallRoomWithRequestId:[self.twinmeContext newRequestId]];
    }

    // This is a CallKit call, we have to terminate it through the performEndCallAction().
    if (connections) {
        for (CallConnection *connection in connections) {
            if ([connection status] != CallStatusTerminated) {
                [connection terminateWithTerminateReason:terminateReason];

                [self onTerminatePeerConnectionWithConnection:connection terminateReason:terminateReason];
            }
        }
    } else if (![call isDoneOperation:FINISH_CALLKIT]) {
        CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:call.callKitUUID];
        CXTransaction *transaction = [[CXTransaction alloc] init];
        [transaction addAction:endCallAction];
        [self.cxCallController requestTransaction:transaction completion:^(NSError * _Nullable error) {
            DDLogVerbose(@"%@ completion: CXEndCallAction: %@", LOG_TAG, call.callKitUUID);
            if (error) {
                [self finishCallkitWithCall:call];
                TL_ASSERTION(self.twinmeContext, [CallsAssertPoint CALLKIT_END_ERROR], [TLAssertValue initWithPeerConnectionId:call.callKitUUID], [TLAssertValue initWithNSError:error], nil);
            }
        }];
    }
}

- (void)terminateCallWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ terminateCallWithPeerConnectionId: %@ terminateReason: %d", LOG_TAG, peerConnectionId, terminateReason);

    CallConnection *callConnection = [self findConnectionWithPeerConnectionId:peerConnectionId];
    if (!callConnection) {

        return;
    }

    [callConnection terminateWithTerminateReason:terminateReason];
}

- (void)setAudioMute:(BOOL)mute {
    DDLogVerbose(@"%@ setAudioMute: %@", LOG_TAG, mute ? @"YES" : @"NO");
    
    CallState *call = [self currentCall];
    if (!call) {
        return;
    }

    self.audioMuteOn = mute;
    call.audioSourceOn = !mute;

    // Mute every active audio connection.
    NSArray<CallConnection *> *connections = [call getConnections];
    for (CallConnection *connection in connections) {
        [connection initSourcesAfterOperation:CREATED_PEER_CONNECTION];
    }
}

- (void)switchCamera {
    DDLogVerbose(@"%@ switchCamera", LOG_TAG);
    
    CallState *call = [self currentCall];
    if (call) {
        [[self.twinmeContext getPeerConnectionService] switchCameraWithFront:!call.frontCameraOn withBlock:^(TLBaseServiceErrorCode errorCode, BOOL isFrontCamera) {
            if (errorCode == TLBaseServiceErrorCodeSuccess) {
                [self onCameraSwitchDone:isFrontCamera];
            }
        }];
    }
}

- (void)setCameraMute:(BOOL)mute {
    DDLogVerbose(@"%@ setCameraMute: %@", LOG_TAG, mute ? @"YES" : @"NO");

    CallState *call = [self currentCall];
    if (!call) {
        return;
    }

    self.cameraMuteOn = mute;
    call.videoSourceOn = !mute;
    
    // Mute every active video connection.
    NSArray<CallConnection *> *connections = [call getConnections];
    for (CallConnection *connection in connections) {
        [connection initSourcesAfterOperation:CREATED_PEER_CONNECTION];
    }
}

- (void)updateCameraControlZoom:(int)zoomLevel {
    DDLogVerbose(@"%@ updateCameraControlZoom: %d", LOG_TAG, zoomLevel);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CallEventCameraControlZoomUpdate object:[NSNumber numberWithInt:zoomLevel]];
}

- (void)setSpeaker:(BOOL)speaker {
    DDLogVerbose(@"%@ setSpeaker: %d", LOG_TAG, speaker);
    
    self.speakerOn = speaker;
    if (self.speakerOn) {
        [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
            RTC_OBJC_TYPE(RTCAudioSession) *audioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
            [audioSession lockForConfiguration];
            NSError *error = nil;
            if (![audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error]) {
                DDLogError(@"Error overriding output port: %@", error.localizedDescription);
            }
            [audioSession unlockForConfiguration];
        }];
    } else {
        [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
            RTC_OBJC_TYPE(RTCAudioSession) *audioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
            [audioSession lockForConfiguration];
            NSError *error = nil;
            if (![audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error]) {
                DDLogError(@"Error overriding output port: %@", error.localizedDescription);
            }
            [audioSession unlockForConfiguration];
        }];
    }
}

- (AudioDevice *)getCurrentAudioDevice {
    DDLogVerbose(@"%@ getCurrentAudioDevice", LOG_TAG);
    
    AVAudioSessionRouteDescription *currentRoute = AVAudioSession.sharedInstance.currentRoute;
    
    AudioDeviceType type = AudioDeviceTypeNone;
    NSString *name = nil;
    
    if (currentRoute.outputs.count > 0) {
        AVAudioSessionPortDescription *port = currentRoute.outputs[0];
        
        name = port.portName;
        
        if ([port.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]) {
            type = AudioDeviceTypeSpeakerPhone;
        } else if ([port.portType isEqualToString:AVAudioSessionPortBuiltInReceiver]) {
            type = AudioDeviceTypeEarPiece;
        } else if ([port.portType isEqualToString:AVAudioSessionPortBluetoothLE]
                   || [port.portType isEqualToString:AVAudioSessionPortBluetoothHFP]
                   || [port.portType isEqualToString:AVAudioSessionPortBluetoothA2DP]) {
            type = AudioDeviceTypeBluetooth;
        } else if ([port.portType isEqualToString:AVAudioSessionPortHeadphones]
                   || [port.portType isEqualToString:AVAudioSessionPortUSBAudio]) {
            type = AudioDeviceTypeWiredHeadset;
        }
    }
    
    return [[AudioDevice alloc] initWithType:type name:name];
}

- (BOOL)isHeadsetAvailable {
    DDLogVerbose(@"%@ isHeadsetAvailable", LOG_TAG);

    if (AVAudioSession.sharedInstance.availableInputs.count > 1) {
        // We have the built-in mic + at least another one, so we can assume a headset is connected
        return YES;
    }
    
    // If we're connected to an external speaker without a mic it won't show up in the input list,
    // but chances are it is the currently active device.
    AudioDevice *currentDevice = self.getCurrentAudioDevice;
    return currentDevice.type == AudioDeviceTypeBluetooth || currentDevice.type == AudioDeviceTypeWiredHeadset;
}

- (void)finishWithCall:(nonnull CallState *)call {
    DDLogVerbose(@"%@ finishWithCall: %@", LOG_TAG, call);

    // We must finish the call with CallKit after playing the end ringtone
    // (otherwise the Audio device is disabled before finishing).
    [self finishCallkitWithCall:call];
}

- (void)sendCallQuality:(int)quality {
    DDLogVerbose(@"%@ sendCallQuality: %d", LOG_TAG, quality);
    
    if (self.peerConnectionIdTerminated) {
        [[self.twinmeContext getPeerConnectionService] sendCallQualityWithPeerConnectionId:self.peerConnectionIdTerminated quality:quality];
    }
    
    self.peerConnectionIdTerminated = nil;
}

- (void)sendGeolocation {
    DDLogVerbose(@"%@ sendGeolocation", LOG_TAG);
    
    CallState *call = [self currentCall];
    CLLocation *loc = self.locationManager.userLocation;
    
    if (call && !CALL_IS_ON_HOLD(call.status) && loc) {

        [call sendGeolocation:loc.coordinate.longitude latitude:loc.coordinate.latitude altitude:loc.altitude mapLongitudeDelta:self.locationManager.mapLongitudeDelta mapLatitudeDelta:self.locationManager.mapLatitudeDelta];
    }
}

- (void)sendGeolocationWithConnection:(nonnull CallConnection *)connection {
    CallState *call = connection.call;
    CLLocation *loc = self.locationManager.userLocation;

    if (!loc) {
        return;
    }
    
    [connection sendWithDescriptor:[call createWithLongitude:loc.coordinate.longitude latitude:loc.coordinate.latitude altitude:loc.altitude mapLongitudeDelta:self.locationManager.mapLongitudeDelta mapLatitudeDelta:self.locationManager.mapLatitudeDelta replyTo:nil copyAllowed:YES]];
}

- (BOOL)canDeviceShareLocation {
    DDLogVerbose(@"%@ canDeviceShareLocation", LOG_TAG);
    
    return self.locationManager.canShareLocation;
}

- (BOOL)canDeviceShareBackgroundLocation {
    DDLogVerbose(@"%@ canDeviceShareBackgroundLocation", LOG_TAG);
    
    return self.locationManager.canShareBackgroundLocation;
}

- (BOOL)isLocationStartShared {
    DDLogVerbose(@"%@ isLocationStartShared", LOG_TAG);
    
    return self.locationManager.isLocationShared;
}

- (BOOL)isExactLocation {
    DDLogVerbose(@"%@ isExactLocation", LOG_TAG);
    
    return [self.locationManager isExactLocation];
}

- (void)initShareLocation {
    DDLogVerbose(@"%@ initShareLocation", LOG_TAG);
    
    if (!self.locationManager) {
        self.locationManager = [[TLLocationManager alloc]initWithDelegate:self];
    }
    
    [self.locationManager initShareLocation];
}

- (void)startShareLocation:(double)mapLatitudeDelta mapLongitudeDelta:(double)mapLongitudeDelta {
    DDLogVerbose(@"%@ startShareLocation", LOG_TAG);
    
    [self.locationManager startShareLocation:mapLatitudeDelta mapLongitudeDelta:mapLongitudeDelta];
    
    [self sendGeolocation];
}

- (void)stopShareLocation:(BOOL)disableUpdateLocation {
    DDLogVerbose(@"%@ stopShareLocation", LOG_TAG);
        
    CallState *call = [self currentCall];
    if (call) {
        [call deleteGeolocation];
    }
    
    if (self.locationManager) {
        [self.locationManager stopShareLocation:disableUpdateLocation];
    }
}

- (nullable CLLocation *)getCurrentLocation {
    DDLogVerbose(@"%@ getCurrentLocation", LOG_TAG);
    
    return self.locationManager.userLocation;
}

- (BOOL)isKeyCheckRunning {
    DDLogVerbose(@"%@ isKeyCheckRunning", LOG_TAG);
    
    if (self.keyCheckSessionHandler) {
        [self.keyCheckSessionHandler setCallParticipantDelegateWithDelegate:self.callParticipantDelegate];
    }
    
    return self.keyCheckSessionHandler != nil && ![self isKeyCheckDone];
}

- (nullable WordCheckChallenge*)getKeyCheckCurrentWord {
    if (self.keyCheckSessionHandler) {
        return self.keyCheckSessionHandler.getCurrentWord;
    }
    
    return nil;
}

- (nullable WordCheckChallenge *)getKeyCheckPeerError {
    if (self.keyCheckSessionHandler) {
        return self.keyCheckSessionHandler.getPeerError;
    }
    
    return nil;
}

- (BOOL)isKeyCheckDone {
    if (self.keyCheckSessionHandler) {
        return self.keyCheckSessionHandler.isDone;
    }
    
    return NO;
}

- (KeyCheckResult)isKeyCheckOK {
    if (self.keyCheckSessionHandler) {
        return self.keyCheckSessionHandler.isOK;
    }
    
    return KeyCheckResultUnknown;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);

    if (self.cxProvider) {
        [self.cxProvider invalidate];
    }
    
    if (self.locationManager) {
        [self.locationManager stopUpdatingLocation];
        self.locationManager = nil;
    }
    
    [[self.twinmeContext getPeerCallService] removeDelegate:self.peerCallServiceDelegate];
    [[self.twinmeContext getPeerConnectionService] removeDelegate:self.peerConnectionServiceDelegate];
    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];
    [self.twinmeContext removeDelegate:self.twinmeContextDelegate];
}

#pragma mark - Private methods

- (int64_t)newOperationWithCallState:(nonnull CallState *)call operationId:(int)operationId {
    DDLogVerbose(@"%@ newOperationWithCallState: %@ operationId: %d", LOG_TAG, call, operationId);
    
    int64_t requestId = [self.twinmeContext newRequestId];
    CallStateOperation *operation = [[CallStateOperation alloc] initWithCallState:call operationId:operationId];
    @synchronized (self.callStateRequestIds) {
        self.callStateRequestIds[[NSNumber numberWithLongLong:requestId]] = operation;
    }
    return requestId;
}

- (int64_t)newOperationWithConnection:(nonnull CallConnection *)connection operationId:(int)operationId {
    DDLogVerbose(@"%@ newOperationWithConnection: %@ operationId: %d", LOG_TAG, connection, operationId);
    
    int64_t requestId = [self.twinmeContext newRequestId];
    ConnectionOperation *operation = [[ConnectionOperation alloc] initWithConnection:connection operationId:operationId];
    @synchronized (self.connectionRequestIds) {
        self.connectionRequestIds[[NSNumber numberWithLongLong:requestId]] = operation;
    }
    return requestId;
}

- (void)onOperationWithCallState:(nonnull CallState *)call {
    DDLogVerbose(@"%@ onOperationWithCallState: %@", LOG_TAG, call);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    if (!self.connected) {
        return;
    }

    id<TLOriginator> originator = call.originator;
    NSUUID *peerTwincodeOutboundId = originator.peerTwincodeOutboundId;
    NSUUID *twincodeInboundId = originator.twincodeInboundId;
    if (!twincodeInboundId || (![originator isKindOfClass:[TLCallReceiver class]] && !peerTwincodeOutboundId)) {
        return;
    }

    // Get the call status only once due to multi-threading it may change.
    CallStatus callStatus = [call status];
    if (CALL_IS_INCOMING(callStatus) && [self isCallkitCall:call.callKitUUID] && [call checkOperation:SEND_DEVICE_RINGING]){
        // Incoming call from callkit => ringtone already playing
        [[self.twinmeContext getPeerConnectionService] sendDeviceRingingWithPeerConnectionId:call.initialConnection.peerConnectionId];
    }
    
    //
    // Step 1: create the audio/video call descriptor.
    //
    if ([call checkOperation:START_CALL]) {
        int64_t requestId = [self newOperationWithCallState:call operationId:START_CALL];

        [[self.twinmeContext getConversationService] startCallWithRequestId:requestId subject:originator video:CALL_IS_VIDEO(callStatus) incomingCall:CALL_IS_INCOMING(callStatus)];
    }
    
    if (![call isDoneOperation:START_CALL_DONE]) {
        return;
    }
    
    
    if (CALL_IS_OUTGOING(callStatus)) {
        if (![call isDoneOperation:CREATE_OUTGOING_PEER_CONNECTION_DONE]) {
            // This call has no accepted peer connection, nothing to do yet.
            return;
        }
        
        // Play the outgoing ringtone only when we got the audio session otherwise the establishment of
        // WebRTC audio session breaks the outgoing ringone.  Turn off the speaker for this ringtone.
        if (self.audioDeviceEnabled && [call checkOperation:START_OUTGOING_RINGTONE] && !CALL_IS_ACTIVE(call.status)) {
            [self startRingtoneWithNotificationSoundType:CALL_IS_VIDEO(callStatus) ? NotificationSoundTypeVideoCalling : NotificationSoundTypeAudioCalling];
        }
    } else {
        //Incoming call
        
        if ([call checkOperation:SEND_DEVICE_RINGING]){
            [[self.twinmeContext getPeerConnectionService] sendDeviceRingingWithPeerConnectionId:call.initialConnection.peerConnectionId];
        }
        
        if (![call isDoneOperation:CREATE_INCOMING_PEER_CONNECTION_DONE]) {
            // This call has no accepted peer connection, nothing to do yet.
            return;
        }
        
        // The NotificationService extension can create a notification for an incoming call.
        // If the call is accepted, we must remove the notification which has the same id as the P2P session.
        if ([call checkOperation:DELETE_INCOMING_NOTIFICATION]) {
            
            TLNotificationService *notificationService = [self.twinmeContext getNotificationService];
            TLNotification *notification = [notificationService getNotificationWithNotificationId:call.callKitUUID];
            if (notification) {
                [self.twinmeContext deleteWithNotification:notification];
            }
        }
    }
}


- (void)onOperationWithConnection:(nonnull CallConnection *)connection {
    DDLogVerbose(@"%@ onOperationWithConnection: %@", LOG_TAG, connection.peerConnectionId);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    if (!self.connected) {
        return;
    }
    
    CallState *call = connection.call;
    id<TLOriginator> originator = connection.originator;
    NSUUID *peerTwincodeOutboundId = connection.peerTwincodeOutboundId;
    NSUUID *twincodeInboundId = originator.twincodeInboundId;
    if (!twincodeInboundId || (![originator isKindOfClass:[TLCallReceiver class]] && !peerTwincodeOutboundId)) {
        return;
    }

    CallStatus callStatus = [connection status];
    
    if (![call isDoneOperation:START_CALL_DONE]) {
        // Wait for onOperationWithCallState to perform Step 1. onOperationWithConnection will be called again once it's done.
        return;
    }

    //
    // Step 2: start the outgoing call.
    //
    if (CALL_IS_OUTGOING(callStatus)) {
        if ([connection checkOperation:CREATE_OUTGOING_PEER_CONNECTION]) {
            TLTwincodeOutbound *peerTwincodeOutbound = originator.peerTwincodeOutbound;
                
            TLOffer *offer = [[TLOffer alloc] initWithAudio:YES video:CALL_IS_VIDEO(callStatus) videoBell:callStatus == CallStatusOutgoingVideoBell data:YES];
            if ([call isGroupCall]) {
                offer.group = YES;
            }
            TLOfferToReceive *offerToReceive = [[TLOfferToReceive alloc] initWithAudio:YES video:CALL_IS_VIDEO(callStatus) data:YES];
                
            TLNotificationContent* notification;
            if (!CALL_IS_VIDEO(callStatus)) {
                notification = [[TLNotificationContent alloc] initWithPriority:TLPeerConnectionServiceNotificationPriorityHigh operation:TLPeerConnectionServiceNotificationOperationAudioCall timeToLive:0];
            } else if (callStatus == CallStatusOutgoingVideoBell) {
                notification = [[TLNotificationContent alloc] initWithPriority:TLPeerConnectionServiceNotificationPriorityHigh operation:TLPeerConnectionServiceNotificationOperationVideoBell timeToLive:0];
            } else {
                notification = [[TLNotificationContent alloc] initWithPriority:TLPeerConnectionServiceNotificationPriorityHigh operation:TLPeerConnectionServiceNotificationOperationVideoCall timeToLive:0];
            }
            [[self.twinmeContext getPeerConnectionService] createOutgoingPeerConnectionWithSubject:originator peerTwincodeOutbound:peerTwincodeOutbound offer:offer offerToReceive:offerToReceive notificationContent:notification dataChannelDelegate:connection delegate:self withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *peerConnectionId) {
                [self onCreateOutgoingPeerConnectionWithConnection:connection errorCode:errorCode peerConnectionId:peerConnectionId];
            }];
        }
    }

    // We can call createIncomingPeerConnectionWithPeerConnectionId() only for an incoming call.
    // The call must be accepted (manually or automatically, see startCallWithPeerConnectionId).
    if (CALL_IS_INCOMING(callStatus) && CALL_IS_ACCEPTED(callStatus)) {
        if ([connection checkOperation:CREATE_INCOMING_PEER_CONNECTION]) {
            TLOffer *offer = [[self.twinmeContext getPeerConnectionService] getPeerOfferWithPeerConnectionId:connection.peerConnectionId];
            if (!offer) {
                offer = [[TLOffer alloc] initWithAudio:call.audioSourceOn video:call.videoSourceOn videoBell:callStatus == CallStatusIncomingVideoBell data:YES];
            } else {
                if ([connection isTransferConnection] == TransferConnectionYes) {
                    if (call.transferDirection == TO_BROWSER){
                        offer.video = call.videoSourceOn;
                        offer.audio = call.audioSourceOn;
                    } else {
                        call.videoSourceOn = offer.video;
                        call.audioSourceOn = offer.audio;
                    }
                }
                [connection setPeerVersionWithVersion:offer.version];
            }

            // For the group call to work with the WebApp, the WebApp has assigned a twincode for the Web client
            // and put it in the resource part.  This allows the group call invitation to be forwarded
            // to the WebApp through the proxy.  It is assigned temporarily to the connection.
            TLTwincodeOutbound *peerTwincode;
            if (originator == nil) {
                peerTwincode = nil;
            } else if ([(NSObject*)originator class] == [TLCallReceiver class]) {
                NSString *peerId = [[self.twinmeContext getPeerConnectionService] getPeerIdWithPeerConnectionId:connection.peerConnectionId];
                if (peerId) {
                    NSArray<NSString *> *items = [peerId componentsSeparatedByString:@"/"];
                    if (items.count == 2) {
                        NSUUID *peerTwincodeOutboundId = [[NSUUID alloc] initWithUUIDString:items[1]];
                        if (peerTwincodeOutboundId) {
                            connection.peerTwincodeOutboundId = peerTwincodeOutboundId;
                        }
                    }
                }
                peerTwincode = nil;
            } else {
                peerTwincode = originator.peerTwincodeOutbound;
            }

            TLOfferToReceive *offerToReceive = [[TLOfferToReceive alloc] initWithAudio:YES video:CALL_IS_VIDEO(callStatus) data:YES];
            if (originator && peerTwincode && !connection.invited) {
                [[self.twinmeContext getPeerConnectionService] createIncomingPeerConnectionWithPeerConnectionId:connection.peerConnectionId subject:originator peerTwincodeOutbound:peerTwincode offer:offer offerToReceive:offerToReceive dataChannelDelegate:connection delegate:self withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *uuid) {
                    if (errorCode == TLBaseServiceErrorCodeSuccess && uuid) {
                        [self onCreateIncomingPeerConnectionWithConnection:connection peerConnectionId:connection.peerConnectionId];
                    } else {
                        [self onTerminatePeerConnectionWithConnection:connection terminateReason:[TLPeerConnectionService toTerminateReason:errorCode]];
                    }
                }];
            } else {
                [[self.twinmeContext getPeerConnectionService] createIncomingPeerConnectionWithPeerConnectionId:connection.peerConnectionId offer:offer offerToReceive:offerToReceive dataChannelDelegate:connection delegate:self withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *uuid) {
                    if (errorCode == TLBaseServiceErrorCodeSuccess && uuid) {
                        [self onCreateIncomingPeerConnectionWithConnection:connection peerConnectionId:connection.peerConnectionId];
                    } else {
                        [self onTerminatePeerConnectionWithConnection:connection terminateReason:[TLPeerConnectionService toTerminateReason:errorCode]];
                    }
                }];
            }

            // If the call is in a callroom, we can join it now that the incoming call is accepted.
            NSUUID *callRoomId = call.callRoomId;
            if (callRoomId && twincodeInboundId) {
                
                int64_t requestId = [self newOperationWithCallState:call operationId:JOIN_CALL_ROOM];
                [[self.twinmeContext getPeerCallService] joinCallRoomWithRequestId:requestId callRoomId:callRoomId twincodeInboundId:twincodeInboundId p2pSessionIds:[call getConnectionIds]];
            }
        }

        if (![connection isDoneOperation:CREATE_INCOMING_PEER_CONNECTION_DONE]) {
            return;
        }
    }
    
    // For an incoming call, wait for the audio device to be enabled otherwise the audio stream will not be setup correctly.
    if (CALL_IS_ACCEPTED(callStatus) && self.audioDeviceEnabled) {

        // The initSources can be made only when the incoming peer connection is created.
        if (![connection isDoneOperation:CREATE_INCOMING_PEER_CONNECTION_DONE]) {
            return;
        }
        if ([connection checkOperation:INIT_AUDIO_CONNECTION]) {
            [connection initSourcesAfterOperation:CREATED_PEER_CONNECTION];
        }
    }

    if (self.audioDeviceEnabled && [connection isDoneOperation:CREATED_PEER_CONNECTION]) {
        if ([connection checkOperation:INIT_AUDIO_CONNECTION]) {
            DDLogInfo(@"%@ initSources: %@ audioEnabled: %d", LOG_TAG, connection.peerConnectionId, self.audioDeviceEnabled);

            [connection initSourcesAfterOperation:CREATED_PEER_CONNECTION];
        }
    }

    //
    // Get the participant avatar from the contact and image service.  For a P2P group call, we may retrieve
    // the avatar and image by other mechanisms such as an image/name sent through P2P data channel.
    //
    if ([connection checkOperation:GET_PARTICIPANT_AVATAR]) {
        TLImageService *imageService = [self.twinmeContext getImageService];
        
        CallParticipant *participant = [connection mainParticipant];
        TLImageId *imageId = [originator avatarId];
        if (!imageId) {
            [participant updateWithName:originator.name description:originator.peerDescription avatar:[TLTwinmeAttributes DEFAULT_AVATAR]];
            
            if (self.callParticipantDelegate) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.callParticipantDelegate onEventWithParticipant:participant event:CallParticipantEventIdentity];
                });
            }
        } else {
            [imageService getImageWithImageId:imageId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                if (image) {
                    [participant updateWithName:originator.name description:originator.peerDescription avatar:image];
                }
                
                if (self.callParticipantDelegate) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.callParticipantDelegate onEventWithParticipant:participant event:CallParticipantEventIdentity];
                    });
                }
                
                [imageService getImageWithImageId:imageId kind:TLImageServiceKindNormal withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                    if (image) {
                        [participant updateWithName:originator.name description:originator.peerDescription avatar:image];
                        
                        if (self.callParticipantDelegate) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.callParticipantDelegate onEventWithParticipant:participant event:CallParticipantEventIdentity];
                            });
                        }
                    }
                }];
            }];
        }
    }

    //
    // Last Step
    //
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getPeerCallService] addDelegate:self.peerCallServiceDelegate];
    [[self.twinmeContext getPeerConnectionService] addDelegate:self.peerConnectionServiceDelegate];
    [[self.twinmeContext getConversationService] addDelegate:self.conversationServiceDelegate];
    self.isTwinlifeReady = YES;
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    self.connected = YES;

    NSMutableArray<CallConnection *> *connections = [[NSMutableArray alloc] init];
    @synchronized (self) {
        // Look at the active call because we can have a pending outgoing call.
        if (self.activeCall) {
            [connections addObjectsFromArray:[self.activeCall getConnections]];
        }

        // Look at other P2P connections.
        for (NSUUID *peerConnectionId in self.peers) {
            CallConnection *connection = self.peers[peerConnectionId];
            if (![connections containsObject:connection]) {
                [connections addObject:connection];
            }
        }
    }

    for (CallConnection *connection in connections) {
        [self onOperationWithConnection:connection];
    }
}

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus {
    DDLogVerbose(@"%@ onConnectionStatusChange: %d", LOG_TAG, connectionStatus);
    
    self.connected = connectionStatus == TLConnectionStatusConnected;
}

- (void)onUpdateContactWithCall:(nonnull CallState *)call contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithCall: %@ contact: %@", LOG_TAG, call, contact);

    NSArray<CallConnection *> *connections = [call getConnections];
    for (CallConnection *connection in connections) {
        // We only need to trigger the onOperationWithConnection on the call connection that uses the updated contact.
        // The purpose is only to start the outgoing peer connection when the updated contact is finalized, when
        // we recieved the peer twincode.
        if (contact == connection.originator) {
            [self onOperationWithConnection:connection];
            break;
        }
    }
}

#pragma mark - TLLocationManagerDelegate
- (void)onUpdateLocation {
    [self sendGeolocation];
}

#pragma mark - RTCAudioSessionDelegate

- (void)audioSessionDidStartPlayOrRecord:(RTC_OBJC_TYPE(RTCAudioSession) *)session {
    DDLogVerbose(@"%@ audioSessionDidStartPlayOrRecord: %@", LOG_TAG, session);
    
    session.isAudioEnabled = YES;
}

- (void)audioSession:(RTC_OBJC_TYPE(RTCAudioSession) *)audioSession didSetActive:(BOOL)active {
    DDLogVerbose(@"%@ didSetActive: %@ active: %d", LOG_TAG, audioSession, active);
    
}

- (void)audioSessionDidStopPlayOrRecord:(RTC_OBJC_TYPE(RTCAudioSession) *)session {
    DDLogVerbose(@"%@ audioSessionDidStopPlayOrRecord: %@", LOG_TAG, session);
    
}

/// Called on a system notification thread when AVAudioSession changes the route.
- (void)audioSessionDidChangeRoute:(RTC_OBJC_TYPE(RTCAudioSession) *)session
                            reason:(AVAudioSessionRouteChangeReason)reason
                     previousRoute:(AVAudioSessionRouteDescription *)previousRoute {
    DDLogVerbose(@"%@ audioSessionDidChangeRoute: %@ reason: %ld previousRoute: %@", LOG_TAG, session, reason, previousRoute);

    [self sendMessageWithCall:self.currentCall message:CallEventMessageAudioSinkUpdate];
}

#pragma mark - PeerCallServiceDelegate

- (void)onCreateCallRoomWithCall:(nonnull CallState *)call callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId mode:(int)mode maxMemberCount:(int)maxMemberCount {
    DDLogVerbose(@"%@ onCreateCallRoomWithCall: %@ callRoomId: %@ memberId: %@ mode: %d maxMemberCount: %d", LOG_TAG, call, callRoomId, memberId, mode, maxMemberCount);

    [call updateCallRoomWithId:callRoomId memberId:memberId mode:mode maxMemberCount:maxMemberCount];
}
    
- (void)onInviteCallRoomWithCallRoomId:(nonnull NSUUID *)callRoomId twincodeInboundId:(nonnull NSUUID *)twincodeInboundId p2pSessionId:(nullable NSUUID *)p2pSessionId mode:(int)mode maxMemberCount:(int)maxMemberCount {
    DDLogVerbose(@"%@ onInviteCallRoomWithCallRoomId: %@ twincodeInboundId: %@ p2pSessionId: %@ mode: %d maxMemberCount: %d", LOG_TAG, callRoomId, twincodeInboundId, p2pSessionId, mode, maxMemberCount);

    if (!p2pSessionId) {
        
        return;
    }

    CallConnection *callConnection = [self findConnectionWithPeerConnectionId:p2pSessionId];
    if (!callConnection) {
        // Check with the active call if this is our call room and we can safely
        // indicate we are joining it again.  The server will send us the members
        // with our P2P sessions (again) and we will establish P2P connections if needed.
        CallState *activeCall = [self activeCall];
        if (activeCall && [callRoomId isEqual:activeCall.callRoomId]) {
            int64_t requestId = [self newOperationWithCallState:activeCall operationId:JOIN_CALL_ROOM];
            [activeCall joinCallRoomWithRequestId:requestId callRoomId:callRoomId mode:mode maxMemberCount:maxMemberCount];
        }
        return;
    }

    // Before joining the call room, check that the associated incoming call is accepted.
    // If not, keep the call room information for later.  We must not join the call room
    // immediately because other participants will connect and establish a P2P connection
    // with us that will be automatically accepted.
    CallState *call = callConnection.call;
    CallStatus callStatus = [call status];
    if (CALL_IS_INCOMING(callStatus) && !CALL_IS_ACCEPTED(callStatus)) {
        [call joinWithCallRoomId:callRoomId maxMemberCount:maxMemberCount];
        return;
    }

    callConnection.invited = YES;
    
    //Special case: reestablish the P2P connection between two members of a group call (see twinme-android-common#54).
    CallState *hold = [self currentHoldCall];
    
    if (hold && hold != call && [callRoomId isEqual:hold.callRoomId]) {
        //We're already in a call in the same callroom
        [self switchCall];
        [self mergeCall];
    }
    
    int64_t requestId = [self newOperationWithCallState:call operationId:JOIN_CALL_ROOM];
    [call joinCallRoomWithRequestId:requestId callRoomId:callRoomId mode:mode maxMemberCount:maxMemberCount];
}

- (void)onJoinCallRoomWithCall:(nonnull CallState *)call callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId members:(nonnull NSArray<TLPeerCallMemberInfo *> *)members {
    DDLogVerbose(@"%@ onJoinCallRoomWithCall: %@ callRoomId: %@ memberId: %@ members: %@", LOG_TAG, call, callRoomId, memberId, members);

    [call updateCallRoomWithMemberId:memberId];

    CallStatus callStatus = call.videoSourceOn ? CallStatusOutgoingVideoCall : CallStatusOutgoingCall;
    for (TLPeerCallMemberInfo *member in members) {
        if (member.status != TLMemberStatusNewNeedSession) {
            CallConnection *callConnection = [self findConnectionWithPeerConnectionId:member.p2pSessionId];
            if (callConnection) {
                // We have a P2P connection with this member, make sure we don't invite it again.
                callConnection.callRoomMemberId = member.memberId;
                [callConnection checkOperation:INVITE_CALL_ROOM];
            }
            
            // Cleanup: sometimes 2 peers in a group call will establish several P2P connections between themselves,
            // for example when re-joining a group call.
            // As a workaround, we check if we have other connections with the member and cancel them.
            
            @synchronized (self) {
                for(NSUUID *connectionId in self.peers){
                    CallConnection *connection = self.peers[connectionId];
                    if ([member.memberId isEqualToString:connection.callRoomMemberId] && ![connection.peerConnectionId isEqual:callConnection.peerConnectionId]) {
                        [connection terminateWithTerminateReason:TLPeerConnectionServiceTerminateReasonCancel];
                    }
                }
            }
            
            continue;
        }

        // If we already have a P2P session with the new member, do nothing (it is probably starting).
        if ([call hasConnectionWithCallMemberId:member.memberId]) {
            continue;
        }

        CallConnection* callConnection = [[CallConnection alloc] initWithCallService:self serializerFactory:[self.twinmeContext getSerializerFactory] call:call originator:call.originator mode:callStatus peerConnectionId:nil retryState:0 memberId:member.memberId];
        // This new participant is not call.originator, so use empty/default values until we receive its ParticipantInfoIQ.
        [callConnection.mainParticipant updateWithName:nil description:nil avatar:[TLTwinmeAttributes DEFAULT_AVATAR]];
        [call addPeerWithConnection:callConnection];
        [callConnection checkOperation:GET_PARTICIPANT_AVATAR];
        [call checkOperation:START_OUTGOING_RINGTONE];

        if (![callConnection checkOperation:CREATE_OUTGOING_PEER_CONNECTION]) {
            
            continue;
        }

        TLOffer *offer = [[TLOffer alloc] initWithAudio:YES video:CALL_IS_VIDEO(callStatus) videoBell:NO data:YES];
        offer.group = YES;
        TLOfferToReceive *offerToReceive = [[TLOfferToReceive alloc] initWithAudio:YES video:CALL_IS_VIDEO(callStatus) data:YES];
        
        TLNotificationContent* notification;
        if (!CALL_IS_VIDEO(callStatus)) {
            notification = [[TLNotificationContent alloc] initWithPriority:TLPeerConnectionServiceNotificationPriorityHigh operation:TLPeerConnectionServiceNotificationOperationAudioCall timeToLive:0];
        } else if (callStatus == CallStatusOutgoingVideoBell) {
            notification = [[TLNotificationContent alloc] initWithPriority:TLPeerConnectionServiceNotificationPriorityHigh operation:TLPeerConnectionServiceNotificationOperationVideoBell timeToLive:0];
        } else {
            notification = [[TLNotificationContent alloc] initWithPriority:TLPeerConnectionServiceNotificationPriorityHigh operation:TLPeerConnectionServiceNotificationOperationVideoCall timeToLive:0];
        }
        notification.timeToLive = OUTGOING_CALL_TIMEOUT * 1000L;

        [[self.twinmeContext getPeerConnectionService] createOutgoingPeerConnectionWithPeerId:member.memberId offer:offer offerToReceive:offerToReceive notificationContent:notification dataChannelDelegate:callConnection delegate:self withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *peerConnectionId) {
            [self onCreateOutgoingPeerConnectionWithConnection:callConnection errorCode:errorCode peerConnectionId:peerConnectionId];
        }];
    }
}

- (void)onMemberJoinCallRoomWithCallRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId p2pSessionId:(nullable NSUUID *)p2pSessionId status:(TLMemberStatus)status {
    DDLogVerbose(@"%@ onMemberJoinCallRoomWithCallRoomId: %@ memberId: %@ p2pSessionId: %@ status: %u", LOG_TAG, callRoomId, memberId, p2pSessionId, status);

    CallConnection *callConnection = [self findConnectionWithPeerConnectionId:p2pSessionId];
    
    if (!callConnection) {
        return;
    }
    
    if ([callConnection isTransferConnection] == TransferConnectionYes && callConnection.call.transferDirection == TO_BROWSER) {
        // We're transferring our call, and the transfer target has joined the call room.
        callConnection.transferToMemberId = memberId;

        // Get a safe list of connections.
        NSMutableArray<CallConnection *> *connections = [[NSMutableArray alloc] init];
        @synchronized (self) {
            for (NSUUID *peerConnectionId in self.peers) {
                CallConnection* connection = self.peers[peerConnectionId];
                if (connection && connection.peerConnectionId && ![connection.peerConnectionId isEqual:p2pSessionId]){
                    [connections addObject:connection];
                }
            }
        }

        // Tell the other participants that they need to transfer us.
        for (CallConnection *connection in connections) {
            [connection sendParticipantTransferIQWithMemberId:memberId];
        }
    }
}

#pragma mark - PeerConnectionServiceDelegate

- (void)onIncomingPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerId:(nonnull NSString *)peerId version:(nonnull TLVersion *)version {
    DDLogVerbose(@"%@ onIncomingPeerConnectionWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);
    
    NSArray<NSString *> *items = [peerId componentsSeparatedByString:@"@"];
    if (items.count != 2) {
        return;
    }

    items = [items[1] componentsSeparatedByString:@"."];
    if (items.count <= 2 || ![items[1] isEqual:@"callroom"]) {
        return;
    }

    CallConnection *callConnection;
    CallState* call;
    @synchronized (self) {
        call = self.activeCall;
        if (!call) {
            return;
        }

        NSUUID *callRoomId = [[NSUUID alloc] initWithUUIDString:items[0]];
        if (!callRoomId || ![callRoomId isEqual:call.callRoomId]) {

            return;
        }
        
        if (![callRoomId isEqual:call.callRoomId]) {
            return;
        }

        CallStatus callStatus = [call isVideo] ? CallStatusAcceptedIncomingVideoCall : CallStatusAcceptedIncomingCall;
        callConnection = [[CallConnection alloc] initWithCallService:self serializerFactory:[self.twinmeContext getSerializerFactory] call:call originator:call.originator mode:callStatus peerConnectionId:peerConnectionId retryState:0 memberId:peerId];
        [callConnection checkOperation:CREATE_OUTGOING_PEER_CONNECTION];
        [callConnection setPeerVersionWithVersion:version];
        callConnection.invited = YES;
        
        if (call.callRoomId) {
            // We're in a call room, so this new participant is not call.originator, so use empty/default values until we receive its ParticipantInfoIQ.
            [callConnection.mainParticipant updateWithName:nil description:nil avatar:[TLTwinmeAttributes DEFAULT_AVATAR]];
            [callConnection checkOperation:GET_PARTICIPANT_AVATAR];
        }

        [self.peers setObject:callConnection forKey:peerConnectionId];
        [call addPeerWithConnection:callConnection];
    }

    [self onOperationWithConnection:callConnection];
    [self onOperationWithCallState:call];
}

- (void)onCreateIncomingPeerConnectionWithConnection:(nonnull CallConnection *)connection peerConnectionId:(nonnull NSUUID*)peerConnectionId {
    DDLogVerbose(@"%@ onCreateIncomingPeerConnectionWithConnection: %@", LOG_TAG, peerConnectionId);
    
    [connection checkOperation:CREATE_INCOMING_PEER_CONNECTION_DONE];
    [connection checkOperation:CREATED_PEER_CONNECTION];
    [connection.call checkOperation:CREATE_INCOMING_PEER_CONNECTION_DONE];
    
    if (connection.call.transferDirection == TO_BROWSER && connection.isTransferConnection == TransferConnectionYes) {
        [connection.call sendPrepareTransfer];
    }
    
    [self onOperationWithConnection:connection];
    [self onOperationWithCallState:connection.call];
}

- (void)initCallKitWithCallState:(CallState *)call {
    DDLogVerbose(@"%@ initCallKitWithCallState: %@", LOG_TAG, call);

    BOOL video = CALL_IS_VIDEO([call status]);
    CXCallUpdate *callUpdate = [self createCXCallUpdate:call.originator video:video];
    CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:call.callKitUUID handle:callUpdate.remoteHandle];
    startCallAction.video = video;
    CXTransaction *transaction = [[CXTransaction alloc] init];
    [transaction addAction:startCallAction];
    __weak CallService *weakSelf = self;
    [self.cxCallController requestTransaction:transaction completion:^(NSError * _Nullable error) {
        CallService *strongSelf = weakSelf;
        if (error && error.code != CXErrorCodeRequestTransactionErrorCallUUIDAlreadyExists) {
            TL_ASSERTION(self.twinmeContext, [CallsAssertPoint CALLKIT_START_ERROR], [TLAssertValue initWithPeerConnectionId:call.callKitUUID], [TLAssertValue initWithNSError:error], nil);
        } else if (strongSelf) {
            
            // Remember this was a successfull CallKit invocation so that we close it.
            long callCount;
            @synchronized (strongSelf) {
                strongSelf.callkitCalls[call.callKitUUID] = call;
                callCount = strongSelf.callkitCalls.count;
            }
            [[strongSelf.twinmeContext getJobService] reportActiveVoIPWithCallCount:callCount fetchCompletionHandler:nil];
        }
    }];
}

- (void)onCreateOutgoingPeerConnectionWithConnection:(nonnull CallConnection *)connection errorCode:(TLBaseServiceErrorCode)errorCode peerConnectionId:(nonnull NSUUID*)peerConnectionId {
    DDLogVerbose(@"%@ onCreateOutgoingPeerConnectionWithConnection: %@ errorCode: %d", LOG_TAG, peerConnectionId, errorCode);
    
    CallState *call = connection.call;
    [connection checkOperation:CREATE_OUTGOING_PEER_CONNECTION_DONE];
    [connection checkOperation:CREATED_PEER_CONNECTION];
    BOOL firstOutgoing = [call checkOperation:CREATE_OUTGOING_PEER_CONNECTION_DONE];

    if (errorCode == TLBaseServiceErrorCodeSuccess && peerConnectionId) {
        BOOL isCallkitCall;
        @synchronized (self) {
            self.peers[peerConnectionId] = connection;
            isCallkitCall = self.callkitCalls[call.callKitUUID] != nil;
        }
        
        // Start the call through CallKit so that it is aware of the outgoing call and it knows the peer connection ID.
        // We must do this only for the first P2P connection of a group call.
        if (self.cxCallController && !isCallkitCall && firstOutgoing) {
            [self initCallKitWithCallState:call];
        } else {
            long callCount;
            @synchronized (self) {
                callCount = self.activeCall ? 1 : 0;
                callCount += self.holdCall ? 1 : 0;
            }
            [[self.twinmeContext getJobService] reportActiveVoIPWithCallCount:callCount fetchCompletionHandler:nil];
        }
        [connection onCreateOutgoingPeerConnectionWithPeerConnectionId:peerConnectionId];
        [self onOperationWithConnection:connection];
        
        // Trigger the outgoing ringtone
        [self onOperationWithCallState:call];
    } else {
        [call removeWithConnection:connection terminateReason:[TLPeerConnectionService toTerminateReason:errorCode]];
        [self sendMessageWithCall:call message:CallEventMessageError];
    }
}

#pragma mark - PeerConnectionDelegate

- (void)onAcceptPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId offer:(nonnull TLOffer *)offer {
    DDLogVerbose(@"%@ onAcceptPeerConnectionWithPeerConnectionId: %@ offer: %@", LOG_TAG, peerConnectionId, offer);
    
    CallConnection *callConnection = [self findConnectionWithPeerConnectionId:peerConnectionId];
    if (!callConnection) {
        return;
    }
    
    [callConnection setPeerVersionWithVersion:offer.version];
    [callConnection setTimerWithStatus:CALL_TO_ACCEPTED([callConnection status]) delay:CONNECT_TIMEOUT];
}

- (void)onChangeConnectionStateWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId state:(TLPeerConnectionServiceConnectionState)state{
    DDLogVerbose(@"%@ onChangeConnectionStateWithPeerConnectionId: %@ state: %d", LOG_TAG, peerConnectionId, state);
    
    CallConnection *connection = [self findConnectionWithPeerConnectionId:peerConnectionId];
    if (!connection) {
        return;
    }

    [self onChangeConnectionStateWithConnection:connection state:state];
}

- (void)onChangeConnectionStateWithConnection:(nonnull CallConnection *)connection state:(TLPeerConnectionServiceConnectionState)state{
    DDLogInfo(@"%@ onChangeConnectionStateWithConnection: %@ state: %d", LOG_TAG, connection.peerConnectionId, state);

    NSSet<CallConnection *> *incomingGroupCallConnections = nil;
    
    CallState *call = connection.call;

    if ([connection isTransferConnection] == TransferConnectionYes) {
        if (![call isTransferReady]) {
            // Still waiting on PrepareTransfer ACKs,
            // we'll call onChangeConnectionState once all ACKs have been received.
            // Ignore other states (i.e. CHECKING), because onChangeConnectionState
            // does nothing if state is not CONNECTED.
            if (state == TLPeerConnectionServiceConnectionStateConnected) {
                call.pendingChangeStateConnectionId = connection.peerConnectionId;
            }
            return;
        }
    }
    
    if (state == TLPeerConnectionServiceConnectionStateConnected && call.transferDirection == TO_DEVICE && call.isGroupCall) {
        // This call was initiated by a Transfer CallReceiver,
        // which means we're transferring the call to this device.
        // We're now connected with the other participant, so we tell the CallReceiver
        // it can now leave the call.
        // NB: we check for groupCall to prevent sending the IQ when the initial CallReceiver
        // connection is created.
        [call.initialConnection sendTransferDoneIQ];
    }
    
    CallConnectionUpdateState updateState = [call updateConnectionWithConnection:connection state:state];

    // Report to CallKit that the outgoing call is now connected.
    CallStatus callStatus = [connection status];
    if (updateState == CallConnectionUpdateStateFirstConnection && CALL_IS_OUTGOING(callStatus) && self.cxProvider && [self isCallkitCall:call.callKitUUID]) {

        self.cxProvider.configuration = [self getCallkitConfiguration:CALL_IS_VIDEO(callStatus) originator:call.originator];
        [self.cxProvider reportOutgoingCallWithUUID:call.callKitUUID connectedAtDate:nil];
    }
    
    if (updateState == CallConnectionUpdateStateFirstConnection) {
        NSUUID *twincodeOutboundId = [call twincodeOutboundId];
        if (twincodeOutboundId && call.descriptorId) {
            int64_t requestId = [self newOperationWithCallState:call operationId:ACCEPTED_CALL];
            
            [[self.twinmeContext getConversationService] acceptCallWithRequestId:requestId twincodeOutboundId:twincodeOutboundId descriptorId:call.descriptorId];
        }
        [self stopRingtone];
        [self setSpeaker:self.speakerOn];

        // Call is now accepted => check for other group call connections.
        incomingGroupCallConnections = [call getIncomingGroupCallConnections];
    } else if (updateState == CallConnectionUpdateStateFirstGroup) {
        [self stopRingtone];
        
        if (!connection.invited && [call checkOperation:CREATE_CALL_ROOM]) {
            int64_t requestId = [self newOperationWithConnection:connection operationId:CREATE_CALL_ROOM];
            [call createCallRoomWithRequestId:requestId];
        }

    } else if (updateState == CallConnectionUpdateStateNewConnection && !connection.callRoomMemberId) {
        [self stopRingtone];

        // This new member is not yet part of the call group, send it an invitation to join
        // (no need to record the operation with newOperationWithConnection).
        if (!connection.invited && [connection checkOperation:INVITE_CALL_ROOM]) {
            int64_t requestId = [self.twinmeContext newRequestId];
            [call inviteCallRoomWithRequestId:requestId connection:connection];
        }
    }
    
    [self sendMessageWithCall:call message:CallEventMessageConnectionState];
    
    if (incomingGroupCallConnections) {
        for (CallConnection *connection in incomingGroupCallConnections) {
            [self onOperationWithConnection:connection];
        }
    }
}

- (void)onTerminatePeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ onTerminatePeerConnectionWithPeerConnectionId: %@ terminateReason: %d", LOG_TAG, peerConnectionId, terminateReason);
    
    CallConnection *connection = [self findConnectionWithPeerConnectionId:peerConnectionId];
    if (!connection) {
        return;
    }

    self.peerConnectionIdTerminated = peerConnectionId;
    
    [self onTerminatePeerConnectionWithConnection:connection terminateReason:terminateReason];
}

- (void)onTerminatePeerConnectionWithConnection:(nonnull CallConnection *)connection terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogInfo(@"%@ onTerminatePeerConnectionWithConnection: %@ terminateReason: %d", LOG_TAG, connection.peerConnectionId, terminateReason);

    CallState *call = connection.call;
    CallStatus callStatus = [connection status];
    BOOL onHold = CALL_IS_ON_HOLD(call.status);

    if (CALL_IS_INCOMING(callStatus) && !CALL_IS_ACTIVE(callStatus) && terminateReason != TLPeerConnectionServiceTerminateReasonDecline && terminateReason != TLPeerConnectionServiceTerminateReasonTransferDone) {
        [self.notificationCenter missedCallNotificationWithOriginator:call.originator video:CALL_IS_VIDEO(callStatus)];
    }
    
    IncomingCallNotification *notification;
    TLDescriptorId *callDescriptor;
    NSUUID *twincodeOutboundId;
    BOOL release;
    @synchronized (self) {
        if (connection.peerConnectionId) {
            [self.peers removeObjectForKey:connection.peerConnectionId];
        }
        
        release = [connection releaseWithTerminateReason:terminateReason];
        if (release) {
            callDescriptor = call.descriptorId;
            twincodeOutboundId = call.originator.twincodeOutboundId;
            notification = self.notification;
            self.notification = nil;
            // call.currentLocalVideoTrack = nil;
            self.keyCheckSessionHandler = nil;

            // If this is the last active call, mark the audio as disabled to make sure we don't call the initSources() before
            // we get a full sequence of didDeactivateAudioSession and didActivateAudioSession.  If we don't wait, a next call
            // can execute the initSources(), some P2P connections may have the audio, but some others may not because
            // the didDeactivateAudioSession was called due to a previous call that is terminated.  The WebRTC audioSession
            // is disabled only from finishCallkitWithCall, and it will be re-enabled from didActivateAudioSession.
            if ((self.activeCall == call && !self.holdCall) || (self.holdCall == call && !self.activeCall)) {
                self.audioDeviceEnabled = NO;
            }
        }
    }

    // Stop the ringtone in case it is still ringing.
    [self stopRingtone];

    // Call is still running, notify an update in its state.
    if (!release) {
        [self sendMessageWithCall:call message:CallEventMessageConnectionState];
        return;
    }

    // Update the call descriptor to record the terminate reason.
    if (callDescriptor && twincodeOutboundId) {
        int64_t requestId = [self newOperationWithCallState:call operationId:TERMINATE_CALL];
        
        [[self.twinmeContext getConversationService] terminateCallWithRequestId:requestId twincodeOutboundId:twincodeOutboundId descriptorId:callDescriptor terminateReason:terminateReason];
    }
    
    // Cancel the system notification.
    if (notification) {
        [self.notificationCenter cancelNotification:notification];
    }
    
    // Play the audio call end ringtone if the call was successful (and not on hold).
    if (!self.holdCall && CALL_IS_ACTIVE(callStatus) && !onHold && terminateReason != TLPeerConnectionServiceTerminateReasonTransferDone) {
        [[NSNotificationCenter defaultCenter] addObserver:call selector:@selector(onAudioPlayerDidFinishPlaying:) name:@"audioPlayerDidFinishPlaying" object:nil];
        [self startRingtoneWithNotificationSoundType:NotificationSoundTypeAudioCallEnd];
        
        // We will finish CallKit call once the end sound is played.
        // The audioPlayerDidFinishPlaying is not reliable, setup a timer to make sure we terminate
        // the CallKit call but we have to verify that it was not terminated first.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            [self finishCallkitWithCall:call];
        });
    } else {
        // No ending sound, finish CallKit call now.
        [self finishCallkitWithCall:call];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        CallEventMessage *eventMessage = [[CallEventMessage alloc] initWithCallId:call.uuid terminateReason:terminateReason];
        [[NSNotificationCenter defaultCenter] postNotificationName:CallEventMessageTerminateCall object:eventMessage];
    });
}

- (void)onAddLocalAudioTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sender:(nonnull RTC_OBJC_TYPE(RTCRtpSender) *)sender audioTrack:(nonnull RTC_OBJC_TYPE(RTCAudioTrack) *)audioTrack {

}

- (void)onCreateLocalVideoTrack:(nonnull RTC_OBJC_TYPE(RTCVideoTrack) *)videoTrack {
    DDLogVerbose(@"%@ onCreateLocalVideoTrack: %@", LOG_TAG, videoTrack);

    // Note: the local video source is shared by every video track used by the P2P connection.
    // We don't get the video source but a video track that is connected to it.  We must keep it globally and not in the CallState.
    CallState *call;
    @synchronized (self) {
        call = self.activeCall;
        self.currentLocalVideoTrack = videoTrack;
    }
    if (call) {
        [[self.twinmeContext getPeerConnectionService] switchCameraWithFront:call.frontCameraOn withBlock:^(TLBaseServiceErrorCode errorCode, BOOL isFrontCamera) {
            if (errorCode == TLBaseServiceErrorCodeSuccess) {
                [self onCameraSwitchDone:isFrontCamera];
            }
        }];
        [self sendMessageWithCall:call message:CallEventMessageVideoUpdate];
    }
}

- (void)onRemoveLocalVideoTrack {
    DDLogVerbose(@"%@ onRemoveLocalVideoTrack", LOG_TAG);

    // When the video source is released, the onRemoveLocalVideoTrack is called and we know that the camera is now released.
    CallState *call;
    @synchronized (self) {
        call = self.activeCall;
        self.currentLocalVideoTrack = nil;
    }
    if (call) {
        [self sendMessageWithCall:call message:CallEventMessageVideoUpdate];
    }
}

- (void)onAddRemoteTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId mediaTrack:(nonnull RTC_OBJC_TYPE(RTCMediaStreamTrack) *)mediaTrack {
    DDLogVerbose(@"%@ onAddRemoteTrackWithPeerConnectionId: %@ mediaTrack: %@", LOG_TAG, peerConnectionId, mediaTrack);

    CallConnection *connection = [self findConnectionWithPeerConnectionId:peerConnectionId];
    if (!connection) {
        return;
    }
    
    NSString *event = [connection onAddRemoteTrackWithTrack:mediaTrack];
    if (event) {
        [self sendMessageWithCall:connection.call message:event];
    }
}

- (void)onRemoveRemoteTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId trackId:(nonnull NSString *)trackId {
    DDLogVerbose(@"%@ onRemoveRemoteTrackWithPeerConnectionId: %@ trackId: %@", LOG_TAG, peerConnectionId, trackId);
    
    CallConnection *connection = [self findConnectionWithPeerConnectionId:peerConnectionId];
    if (!connection) {
        return;
    }
    
    NSString *event = [connection onRemoveRemoteTrackWithTrackId:trackId];
    if (event) {
        [self sendMessageWithCall:connection.call message:event];
    }
}

- (void)onRemoveLocalSenderWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sender:(nonnull RTC_OBJC_TYPE(RTCRtpSender) *)sender {
    DDLogVerbose(@"%@ onRemoveLocalSenderWithPeerConnectionId: %@ sender: %@", LOG_TAG, peerConnectionId, sender);

}

- (void)onPeerHoldCallWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ onPeerHoldCallWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);

}

- (void)onPeerResumeCallWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ onPeerResumeCallWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);

}

- (void)onPeerKeyCheckInitiateWithConnectionId:(nonnull NSUUID *)connectionId locale:(nonnull NSLocale *)locale{
    DDLogVerbose(@"%@ onPeerKeyCheckInitiateWithConnectionId: %@", LOG_TAG, connectionId);
    
    CallState *call = self.activeCall;
    CallConnection *connection = [self findConnectionWithPeerConnectionId:connectionId];
    if (!connection || !call) {
        return;
    }
    
    self.keyCheckSessionHandler = [[KeyCheckSessionHandler alloc] initWithTwinmeContext:self.twinmeContext callParticipantDelegate:self.callParticipantDelegate call:call language:locale];
    
    BOOL initOK = [self.keyCheckSessionHandler initSessionWithCallConnection:connection];
    
    if (!initOK) {
        DDLogError(@"%@ Error initiation key check session", LOG_TAG);
        self.keyCheckSessionHandler = nil;
    }
}

- (void)onOnKeyCheckInitiateWithConnectionId:(nonnull NSUUID *)connectionId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onOnKeyCheckInitiateWithConnectionId: %@ errorCode: %d", LOG_TAG, connectionId, errorCode);
    
    CallConnection *connection = [self findConnectionWithPeerConnectionId:connectionId];
    if (!connection || !self.keyCheckSessionHandler) {
        return;
    }
    
    if (errorCode != TLBaseServiceErrorCodeSuccess) {
        DDLogVerbose(@"%@ Peer rejected key check, aborting", LOG_TAG);
        //TODO: send event to activity?
        self.keyCheckSessionHandler = nil;
        return;
    }
    
    [self.keyCheckSessionHandler onOnKeyCheckInitiate];
}

- (void)onPeerWordCheckResultWithConnectionId:(nonnull NSUUID *)connectionId wordCheckResult:(nonnull WordCheckResult *)wordCheckResult {
    DDLogVerbose(@"%@ onPeerWordCheckResultWithConnectionId: %@ wordCheckResult: %@", LOG_TAG, connectionId, wordCheckResult);
    
    CallConnection *connection = [self findConnectionWithPeerConnectionId:connectionId];
    if (!connection || !self.keyCheckSessionHandler) {
        return;
    }

    [self.keyCheckSessionHandler onPeerWordCheckResultWithResult:wordCheckResult];
}

- (void)onTerminateKeyCheckWithConnectionId:(nonnull NSUUID *)connectionId result:(BOOL)result {
    DDLogVerbose(@"%@ onTerminateKeyCheckWithConnectionId: %@ result: %@", LOG_TAG, connectionId, result ? @"YES": @"NO");
    
    CallConnection *connection = [self findConnectionWithPeerConnectionId:connectionId];
    if (!connection || !self.keyCheckSessionHandler) {
        return;
    }
    
    [self.keyCheckSessionHandler onTerminateKeyCheckWithResult:result];
}

- (void)onTwincodeURIWithConnectionId:(nonnull NSUUID *)connectionId uri:(nonnull NSString *)uri {
    DDLogVerbose(@"%@ onTwincodeURIWithConnectionId: %@ uri: %@", LOG_TAG, connectionId, uri);

    CallConnection *connection = [self findConnectionWithPeerConnectionId:connectionId];
    if (!connection || !self.keyCheckSessionHandler) {
        return;
    }
    
    [self.keyCheckSessionHandler onTwincodeUriIQWithUri:uri];

}


- (void)onCameraSwitchDone:(BOOL)isFrontCamera {
    DDLogVerbose(@"%@ onCameraSwitchDone: %@", LOG_TAG, isFrontCamera ? @"YES":@"NO");
    
    CallState *call = [self currentCall];
    if (call) {
        call.frontCameraOn = isFrontCamera;
        [self sendMessageWithCall:call message:CallEventMessageCameraSwitch];
    }
}

- (void)onDeviceRingingWithConnection:(nonnull CallConnection *)connection {
    DDLogVerbose(@"%@ onDeviceRingingWithConnection: %@", LOG_TAG, connection);

}

- (void)onErrorWithConnection:(nonnull CallConnection *)connection operationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogInfo(@"%@ onErrorWithConnection: %@ operationId: %d errorCode: %d errorParameter: %@", LOG_TAG, connection, operationId, errorCode, errorParameter);
    
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = true;
        return;
    }
    
    TLPeerConnectionServiceTerminateReason terminateReason = TLPeerConnectionServiceTerminateReasonSuccess;
    switch (operationId) {
        case CREATE_INCOMING_PEER_CONNECTION:
            switch (errorCode) {
                case TLBaseServiceErrorCodeItemNotFound:
                    // Sometimes the createIncomingPeerConnectionWithRequestId() fails when the incoming
                    // call was initiated from PushKit.  We have to wait that the PeerConnectionService
                    // is aware of the P2P connection, mark the connection and retry if we are in this case
                    // (See startCallWithPeerConnectionId).
                    if ([connection retryOperation:CREATE_INCOMING_PEER_CONNECTION]) {
                        [self onOperationWithConnection:connection];
                        return;
                    }
                    terminateReason = TLPeerConnectionServiceTerminateReasonGone;
                    break;

                case TLBaseServiceErrorCodeNoPrivateKey:
                    terminateReason = TLPeerConnectionServiceTerminateReasonNoPrivateKey;
                    break;

                case TLBaseServiceErrorCodeDecryptError:
                case TLBaseServiceErrorCodeBadEncryptionFormat:
                    terminateReason = TLPeerConnectionServiceTerminateReasonDecryptError;
                    break;

                default:
                    break;
            }
            break;
            
        case CREATE_OUTGOING_PEER_CONNECTION:
            if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
                terminateReason = TLPeerConnectionServiceTerminateReasonGone;
            }
            return;
    }
    if (terminateReason != TLPeerConnectionServiceTerminateReasonSuccess) {
        [connection terminateWithTerminateReason:terminateReason];
        [self onTerminatePeerConnectionWithConnection:connection terminateReason:terminateReason];

    } else {
        [self.twinmeContext assertionWithAssertPoint:[CallsAssertPoint UNKNOWN_ERROR], [TLAssertValue initWithLine:__LINE__], [TLAssertValue initWithOperationId:operationId], [TLAssertValue initWithErrorCode:errorCode], nil];
        
        [self onTerminatePeerConnectionWithConnection:connection terminateReason:TLPeerConnectionServiceTerminateReasonGeneralError];
    }
    [self onOperationWithConnection:connection];
}

- (void)onErrorWithCall:(nonnull CallState *)call operationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = true;
        return;
    }
    
    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch(operationId){
                // Ignore the error in case startCall(), acceptCall(), terminateCall() fail.
                // It could happen if the call descriptor is removed during the call.
            case START_CALL:
                [call checkOperation:START_CALL_DONE];
                return;
                
            case ACCEPTED_CALL:
                [call checkOperation:ACCEPTED_CALL_DONE];
                return;
                
            case TERMINATE_CALL:
                [call checkOperation:TERMINATE_CALL_DONE];
                return;
                
            case DELETE_INCOMING_NOTIFICATION:
                [call checkOperation:DELETE_INCOMING_NOTIFICATION_DONE];
                return;
        }
    }
    
    [self onOperationWithCallState:call];
}

- (void) onTransferDone {
    DDLogVerbose(@"%@ onTransferDone", LOG_TAG);

    [self terminateCallWithTerminateReason:TLPeerConnectionServiceTerminateReasonTransferDone];
}

- (void)putCallOnHold {
    CallState *call = [self currentCall];
    if (call) {
        [self putCallOnHoldWithCall:call];
    }
}

- (void)putCallOnHoldWithCall:(nonnull CallState *)call {
    DDLogVerbose(@"%@ putCallOnHoldWithCall:%@", LOG_TAG, call);
    
    CallStatus status = call.status;
    if (CALL_IS_PAUSED(status) || CALL_IS_TERMINATED(status)) {
        return;
    }
    
    // The real on-hold must be made from the CallKit performSetHeldCallAction callback.
    CXSetHeldCallAction *setHeldCallAction = [[CXSetHeldCallAction alloc] initWithCallUUID:call.callKitUUID onHold:YES];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:setHeldCallAction];
    [self.cxCallController requestTransaction:transaction completion:^(NSError *error) {
        //NOOP
        if (error) {
            TL_ASSERTION(self.twinmeContext, [CallsAssertPoint CALLKIT_HOLD_ERROR], [TLAssertValue initWithPeerConnectionId:call.callKitUUID], [TLAssertValue initWithNSError:error], nil);
        }
    }];
}

- (void)resumeCall {
    CallState *call = [self currentCall];
    if (call) {
        [self resumeCallWithCall:call];
    }
}

- (void)resumeCallWithCall:(nonnull CallState *)call {
    DDLogVerbose(@"%@ resumeCallWithCall: %@", LOG_TAG, call);
    DDLogInfo(@"%@ resume call: %@", LOG_TAG, call.callKitUUID);
    
    CallStatus status = call.status;
    if (!CALL_IS_PAUSED(status) || CALL_IS_TERMINATED(status)) {
        return;
    }

    // The real resume must be made from the CallKit performSetHeldCallAction callback.
    CXSetHeldCallAction *setHeldCallAction = [[CXSetHeldCallAction alloc] initWithCallUUID:call.callKitUUID onHold:NO];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:setHeldCallAction];
    [self.cxCallController requestTransaction:transaction completion:^(NSError *error) {
        //NOOP
        if (error) {
            TL_ASSERTION(self.twinmeContext, [CallsAssertPoint CALLKIT_RESUME_ERROR], [TLAssertValue initWithPeerConnectionId:call.callKitUUID], [TLAssertValue initWithNSError:error], nil);
        }
    }];
}

- (void)switchCall {
    DDLogVerbose(@"%@ switchCall", LOG_TAG);
        
    // active and hold calls must be switched atomically and it is also possible
    // that the current call is terminated before/while switchCall is executed.
    CallState *call;
    CallState *hold;
    @synchronized (self) {
        call = self.activeCall;
        hold = self.holdCall;
        if (hold) {
            self.activeCall = hold;
            self.holdCall = call;
        }
    }

    [self stopShareLocation:YES];
    
    if (!hold) {
        return;
    }
    if (call) {
        int status = call.status;

        // Check activeCall is active.
        TL_ASSERT_TRUE(self.twinmeContext, CALL_IS_ACTIVE(status) || CALL_IS_TERMINATED(status), [CallsAssertPoint CALL_STATUS], [TLAssertValue initWithNumber:status]);

        // Check holdCall is accepted.
        status = hold.status;
        TL_ASSERT_TRUE(self.twinmeContext, CALL_IS_ACCEPTED(status), [CallsAssertPoint CALL_STATUS], [TLAssertValue initWithNumber:status]);

        // Check holdCall is not terminated.
        TL_ASSERT_TRUE(self.twinmeContext, !CALL_IS_TERMINATED(status), [CallsAssertPoint CALL_STATUS], [TLAssertValue initWithNumber:status]);
        
        [self putCallOnHoldWithCall:call];
    }

    [self resumeCallWithCall:hold];
}

- (void)mergeCall {
    DDLogVerbose(@"%@ mergeCall", LOG_TAG);

    CallState *call;
    CallState *hold;
    @synchronized (self) {
        call = self.activeCall;
        hold = self.holdCall;
    }
    if (!call || !hold) {
        return;
    }
    
    for (CallConnection *connection in [hold getConnections]) {
        connection.call = call;
        [self onChangeConnectionStateWithConnection:connection state:connection.connectionState];
        [connection initSourcesAfterOperation:CREATED_PEER_CONNECTION];
        [connection sendResumeCallIQ];
    }
    
    [hold clearConnections];
    
    [self terminateCallWithCall:hold terminateReason:TLPeerConnectionServiceTerminateReasonMerge];
    
    [self sendMessageWithCall:call message:CallEventMessageCallsMerged];
}

- (void)onPeerHoldCallWithConnectionId:(nonnull NSUUID *)connectionId {
    DDLogVerbose(@"%@ onPeerHoldCallWithConnectionId:%@", LOG_TAG, connectionId);

    CallConnection *callConnection = [self findConnectionWithPeerConnectionId:connectionId];
    
    if (!callConnection) {
        return;
    }
    
    [callConnection putOnHold];
    
    id<CallParticipantDelegate> observer = self.callParticipantDelegate;
    if (observer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [observer onEventWithParticipant:callConnection.mainParticipant event:CallParticipantEventHold];
        });
    }
}

- (void)onPeerResumeCallWithConnectionId:(nonnull NSUUID *)connectionId {
    DDLogVerbose(@"%@ onPeerResumeCallWithConnectionId:%@", LOG_TAG, connectionId);

    CallConnection *callConnection = [self findConnectionWithPeerConnectionId:connectionId];
    
    if (!callConnection) {
        return;
    }
    
    [callConnection resume];
    
    id<CallParticipantDelegate> observer = self.callParticipantDelegate;
    if (observer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [observer onEventWithParticipant:callConnection.mainParticipant event:CallParticipantEventResume];
        });
    }
}


/// Key check UI actions

- (void)startKeyCheckWithLanguage:(nullable NSLocale *)language {
    DDLogVerbose(@"%@ startKeyCheckWithLanguage:%@", LOG_TAG, language);

    CallState *call = self.activeCall;
    
    if (!call) {
        DDLogVerbose(@"%@ No active call, aborting", LOG_TAG);
        return;
    }
    
    if (!language) {
        language = NSLocale.currentLocale;
    }
    
    self.keyCheckSessionHandler = [[KeyCheckSessionHandler alloc] initWithTwinmeContext:self.twinmeContext callParticipantDelegate:self.callParticipantDelegate call:call language:language];
    
    [self.keyCheckSessionHandler initSession];
}

- (void)stopKeyCheck {
    DDLogVerbose(@"%@ stopKeyCheck", LOG_TAG);

    self.keyCheckSessionHandler = nil;
}

- (void)addWordCheckResultWithWordIndex:(int)wordIndex result:(BOOL)result {
    DDLogVerbose(@"%@ addWordCheckResultWithWordIndex:%d result:%@", LOG_TAG, wordIndex, result ? @"YES" : @"NO");
    
    if (!self.keyCheckSessionHandler) {
        DDLogVerbose(@"%@ Key check session not started yet, aborting", LOG_TAG);
    }
    
    [self.keyCheckSessionHandler processLocalWordCheckResultWithResult:[[WordCheckResult alloc] initWithWordIndex:wordIndex ok:result]];
}

- (int)allocateParticipantId {
    
    @synchronized (self) {
        return self.nextParticipantId++;
    }
}

- (void)setActiveCall:(CallState *)activeCall {
    DDLogVerbose(@"%@ setActiveCall: %@", LOG_TAG, activeCall);

    if (activeCall != _activeCall) {
        _activeCall = activeCall;
        
        if (activeCall) {
            self.audioMuteOn = !activeCall.audioSourceOn;
            self.cameraMuteOn = !activeCall.videoSourceOn;
        }
    }
}

#pragma mark - Private methods

- (void)sendMessageWithCall:(nonnull CallState *)call message:(nonnull NSString *)message {
    DDLogVerbose(@"%@ sendMessageWithCall: %@ message: %@", LOG_TAG, call, message);
    
    CallEventMessage *eventMessage = [call eventMessage];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:message object:eventMessage];
    });
}

- (void)finishCallkitWithCall:(nullable CallState *)call {
    DDLogInfo(@"%@ finishCallkitWithCall: %@", LOG_TAG, call);

    // Due to async behavior of call termination, finishCallkitWithCall() can be called two
    // times when the peer terminate the call.  Make sure we only process this only once.
    if (![call checkOperation:FINISH_CALLKIT]) {
        return;
    }

    BOOL isCallKitCall;
    TLPeerConnectionServiceTerminateReason terminateReason;
    BOOL inBackground;
    BOOL stopRingtone = NO;
    BOOL disableAudio;
    long callCount;
    @synchronized (self) {
        inBackground = self.inBackground;
        terminateReason = call.terminateReason;
        if (call) {
            isCallKitCall = self.callkitCalls[call.callKitUUID];
            [self.callkitCalls removeObjectForKey:call.callKitUUID];
        } else {
            isCallKitCall = NO;
        }
        callCount = self.callkitCalls.count;
        if (call == self.activeCall) {
            self.activeCall = nil;
            if (!self.holdCall) {
                self.viewController = nil;
                stopRingtone = YES;
            }
        } else if (call == self.holdCall) {
            self.holdCall = nil;
        }
        disableAudio = !self.activeCall && !self.holdCall;
    }

    // Stop the ringtone if we terminated the current call (otherwise, leave unchange in case of new incoming call).
    if (stopRingtone) {
        [self stopRingtone];
    }

    if (disableAudio) {
        RTC_OBJC_TYPE(RTCAudioSession) *session = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
        session.isAudioEnabled = NO;

        // If the callCount is not 0, we have some inconsistency between activeCall, holdCall and the callkitCalls dictionary.
        if (callCount != 0) {
            TL_ASSERTION(self.twinmeContext, [CallsAssertPoint CALLKIT_INCONSISTENCY], [TLAssertValue initWithPeerConnectionId:call.callKitUUID], [TLAssertValue initWithNumber:(int)callCount], nil);
        }

        callCount = 0;
    }

    // This is a CallKit call, we have to terminated it through the reportCallWithUUID().
    // If we call reportCallWithUUID:endedAtDate immediately and we are in background,
    // we may not have enough time to finish posting a notification or updating the database.
    // The fetchCompletionHandler will be called when we are sure it is safe for us to
    // suspend the application in case we are in background.
    if (self.cxProvider && isCallKitCall) {
        [[self.twinmeContext getJobService] reportActiveVoIPWithCallCount:callCount fetchCompletionHandler:^(TLBaseServiceErrorCode errorCode) {
            DDLogInfo(@"%@ report end-call to CallKit: %@", LOG_TAG, call.callKitUUID);

            switch (terminateReason) {
                case TLPeerConnectionServiceTerminateReasonSuccess:
                case TLPeerConnectionServiceTerminateReasonDecline:
                case TLPeerConnectionServiceTerminateReasonGone:
                case TLPeerConnectionServiceTerminateReasonBusy:
                case TLPeerConnectionServiceTerminateReasonRevoked:
                case TLPeerConnectionServiceTerminateReasonNotAuthorized:
                case TLPeerConnectionServiceTerminateReasonCancel:
                case TLPeerConnectionServiceTerminateReasonTransferDone:
                    // On iOS 12, if the outgoing call is declined, we must terminate with RemoteEnded otherwise
                    // the CallKit UI is displayed briefly.  iOS 13 does not have this issue.
                    [self.cxProvider reportCallWithUUID:call.callKitUUID endedAtDate:nil reason:CXCallEndedReasonRemoteEnded];
                    break;
                    
                case TLPeerConnectionServiceTerminateReasonTimeout:
                    [self.cxProvider reportCallWithUUID:call.callKitUUID endedAtDate:nil reason:CXCallEndedReasonUnanswered];
                    break;
                    
                default:
                    [self.cxProvider reportCallWithUUID:call.callKitUUID endedAtDate:nil reason:CXCallEndedReasonFailed];
                    break;
            }
        }];
    } else {
        [[self.twinmeContext getJobService] reportActiveVoIPWithCallCount:callCount fetchCompletionHandler:^(TLBaseServiceErrorCode errorCode) {
            if (terminateReason == TLPeerConnectionServiceTerminateReasonDecline) {
                [self.cxProvider reportCallWithUUID:call.callKitUUID endedAtDate:nil reason:CXCallEndedReasonDeclinedElsewhere];
            }
        }];
    }
    
    CallState *hold = nil;
    @synchronized (self) {
        if (!self.activeCall && self.holdCall) {
            hold = self.holdCall;
            self.activeCall = self.holdCall;
            self.holdCall = nil;
        }
    }
   
    if (hold) {
        [self resumeCallWithCall:hold];
    }
}

#pragma mark - TLNotificationCenter iOSHack

- (void)onUnknownIncomingCall {
    DDLogVerbose(@"%@ onUnknownIncomingCall", LOG_TAG);
    
    // Start a new call with CallKit and terminate it because we don't know how to handle it.
    // This is necessary on iOS 13 otherwise the system will kill the application.
    // See https://forums.developer.apple.com/thread/117939.
    if (self.cxProvider) {
        NSUUID *unknownPeerConnectionId = [[NSUUID alloc] init];
        CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
        callUpdate.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:TwinmeLocalizedString(@"history_view_controller_incoming_call", nil)];
        callUpdate.hasVideo = NO;
        
        [self.cxProvider reportNewIncomingCallWithUUID:unknownPeerConnectionId update:callUpdate completion:^(NSError * _Nullable error) {
            [self.cxProvider reportCallWithUUID:unknownPeerConnectionId endedAtDate:nil reason:CXCallEndedReasonFailed];
        }];
    }
}

- (void)activateAudioWithCall:(nonnull CallState *)call {
    DDLogVerbose(@"%@ activateAudioWithCall: %@", LOG_TAG, call);
    
    [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
        RTC_OBJC_TYPE(RTCAudioSession) *audioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
        RTC_OBJC_TYPE(RTCAudioSessionConfiguration) *currentConfiguration = [RTC_OBJC_TYPE(RTCAudioSessionConfiguration) currentConfiguration];
        RTC_OBJC_TYPE(RTCAudioSessionConfiguration) *webRTCConfiguration = [RTC_OBJC_TYPE(RTCAudioSessionConfiguration) webRTCConfiguration];
        if (![currentConfiguration isEqual:webRTCConfiguration] && !self.notificationSound) {
            NSError *error = nil;
            audioSession.ignoresPreferredAttributeConfigurationErrors = YES;
            [audioSession lockForConfiguration];
            [audioSession setConfiguration:webRTCConfiguration error:&error];
            [audioSession unlockForConfiguration];
            
            if (error) {
                // Note, we sometimes get the following error which can be ignored by setting the
                // ignoresPreferredAttributeConfigurationErrors property:
                // - Failed to set preferred input number of channels: (OSStatus -50 = AVAudioSessionErrorCodeBadParam)
                NSLog(@"RTCAudioSession setConfiguration: %@ error: %@", webRTCConfiguration, error);
            }
        }
        
        // Setup to use the speaker unless some headset is plugged.
        // If the call was accepted from CallKit, we also don't want to turn on the speaker.
        CallStatus callStatus = [call status];
        if (CALL_IS_INCOMING(callStatus) && !CALL_IS_ACCEPTED(callStatus) && !self.notificationSound) {
            NSError *error = nil;

            [audioSession lockForConfiguration];
            
            AVAudioSessionPortOverride mode = AVAudioSessionPortOverrideNone;
            for (AVAudioSessionPortDescription *portDescription in audioSession.currentRoute.outputs) {
                if ([portDescription.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker] || [portDescription.portType isEqualToString:AVAudioSessionPortBuiltInReceiver]) {
                    mode = AVAudioSessionPortOverrideSpeaker;
                    break;
                }
            }
            
            if (![audioSession overrideOutputAudioPort:mode error:&error]) {
                DDLogError(@"Error overriding output port: %@", error.localizedDescription);
            }
            [audioSession unlockForConfiguration];
            
            if (!self.notificationSound) {
                [self startRingtoneWithNotificationSoundType:CALL_IS_VIDEO(callStatus) ? NotificationSoundTypeVideoCall : NotificationSoundTypeAudioCall];
            }
        }
        
        dispatch_async(self.twinmeContext.twinlife.twinlifeQueue, ^{
            self.audioDeviceEnabled = YES;

            // The audio is now enabled, execute the onOperation on each connection because
            // we are now ready for the initSourcesAfterOperation().
            NSArray<CallConnection *> *connections  = [call getConnections];
            for (CallConnection *connection in connections) {
                [self onOperationWithConnection:connection];
            }

            // Trigger the operations because we enabled the audio device and we are allowed to call initSourcesWithPeerConnectionId().
            // This will send device ringing (if the incoming call is handled by the app itself)
            [self onOperationWithCallState:call];
        });
    }];
}

#pragma mark - CXProviderDelegate

- (void)providerDidReset:(CXProvider *)provider {
    DDLogInfo(@"%@ providerDidReset: %@", LOG_TAG, provider);
}

- (void)providerDidBegin:(CXProvider *)provider {
    DDLogInfo(@"%@ providerDidBegin: %@", LOG_TAG, provider);
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    DDLogVerbose(@"%@ provider: %@ performStartCallAction: %@", LOG_TAG, provider, action);
    DDLogInfo(@"%@ CallKit start-call: %@", LOG_TAG, action.callUUID);
    
    // Audio session configuration can only be made after performAnswerCallAction() or performStartCallAction().
    // Always configure the Audio session because we have lost it.
    // The didActivateAudioSession is not systematically called.
    [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
        RTC_OBJC_TYPE(RTCAudioSession) *rtcAudioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
        RTC_OBJC_TYPE(RTCAudioSessionConfiguration) *webRTCConfiguration = [RTC_OBJC_TYPE(RTCAudioSessionConfiguration) webRTCConfiguration];
        
        NSError *error = nil;
        rtcAudioSession.ignoresPreferredAttributeConfigurationErrors = YES;
        [rtcAudioSession lockForConfiguration];
        [rtcAudioSession setConfiguration:webRTCConfiguration error:&error];
        [rtcAudioSession unlockForConfiguration];
        if (error) {
            // Note, we sometimes get the following error which can be ignored by setting the
            // ignoresPreferredAttributeConfigurationErrors property:
            // - Failed to set preferred input number of channels: (OSStatus -50 = AVAudioSessionErrorCodeBadParam)
            NSLog(@"RTCAudioSession setConfiguration: %@ error: %@", webRTCConfiguration, error);
        }
    }];
    
    CallState *call;
    @synchronized (self) {
        call = self.callkitCalls[action.callUUID];
    }
    if (call) {
        CXCallUpdate *callUpdate = [self createCXCallUpdate:call.originator video:action.video];

        self.cxProvider.configuration = [self getCallkitConfiguration:action.video originator:call.originator];
        [self.cxProvider reportOutgoingCallWithUUID:action.callUUID startedConnectingAtDate:nil];
        [self.cxProvider reportCallWithUUID:call.callKitUUID updated:callUpdate];
        [action fulfill];
    } else {
        [action fail];
    }
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action {
    DDLogVerbose(@"%@ provider: %@ performAnswerCallAction: %@", LOG_TAG, provider, action);
    DDLogInfo(@"%@ CallKit answer-call: %@", LOG_TAG, action.callUUID);

    // Audio session configuration can only be made after performAnswerCallAction() or performStartCallAction().
    // Always configure the Audio session because we have lost it.
    // The didActivateAudioSession is not systematically called.
    [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
        RTC_OBJC_TYPE(RTCAudioSession) *rtcAudioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
        RTC_OBJC_TYPE(RTCAudioSessionConfiguration) *webRTCConfiguration = [RTC_OBJC_TYPE(RTCAudioSessionConfiguration) webRTCConfiguration];
        
        NSError *error = nil;
        rtcAudioSession.ignoresPreferredAttributeConfigurationErrors = YES;
        [rtcAudioSession lockForConfiguration];
        [rtcAudioSession setConfiguration:webRTCConfiguration error:&error];
        [rtcAudioSession unlockForConfiguration];
        if (error) {
            // Note, we sometimes get the following error which can be ignored by setting the
            // ignoresPreferredAttributeConfigurationErrors property:
            // - Failed to set preferred input number of channels: (OSStatus -50 = AVAudioSessionErrorCodeBadParam)
            NSLog(@"RTCAudioSession setConfiguration: %@ error: %@", webRTCConfiguration, error);
        }
    }];
    CallState *call;
    @synchronized (self) {
        call = self.callkitCalls[action.callUUID];
    }
    if (call) {
        [self acceptCallWithCall:call];
        [action fulfill];
    } else {
        [action fail];
    }
    
    // We are in foreground and the call was accepted from CallKit: display the audio/video view controller.
    if (!self.inBackground) {
        [self applicationWillEnterForeground:[UIApplication sharedApplication]];
    }
}

- (void)provider:(CXProvider *)provider performEndCallAction:(nonnull CXEndCallAction *)action {
    DDLogVerbose(@"%@ provider: %@ performEndCallAction: %@", LOG_TAG, provider, action);
    DDLogInfo(@"%@ CallKit end-call: %@", LOG_TAG, action.callUUID);

    CallState *call;
    long callCount;
    CallStatus callStatus;
    BOOL disableAudio;
    TLPeerConnectionServiceTerminateReason terminateReason;
    @synchronized (self) {
        call = self.callkitCalls[action.callUUID];
        if (call) {
            [self.callkitCalls removeObjectForKey:action.callUUID];
            
            callStatus = [call status];
            terminateReason = call.terminateReason;
            if (terminateReason == TLPeerConnectionServiceTerminateReasonUnknown) {
                if (CALL_IS_ACTIVE(callStatus) || CALL_IS_ON_HOLD(callStatus)) {
                    terminateReason = TLPeerConnectionServiceTerminateReasonSuccess;
                } else if (CALL_IS_ACCEPTED(callStatus)) {
                    terminateReason = TLPeerConnectionServiceTerminateReasonTimeout;
                } else if (CALL_IS_INCOMING(callStatus)) {
                    terminateReason = TLPeerConnectionServiceTerminateReasonDecline;
                } else if (CALL_IS_OUTGOING(callStatus)) {
                    terminateReason = TLPeerConnectionServiceTerminateReasonCancel;
                } else {
                    terminateReason = TLPeerConnectionServiceTerminateReasonGeneralError;
                }

                call.terminateReason = terminateReason;
            }

        } else {
            terminateReason = TLPeerConnectionServiceTerminateReasonGeneralError;
        }
        
        callCount = self.callkitCalls.count;
        if (self.activeCall == call) {
            self.activeCall = nil;
            if (!self.holdCall) {
                self.viewController = nil;
            }
        } else {
            self.holdCall = nil;
        }
        
        disableAudio = !self.activeCall && !self.holdCall;
    }

    if (call) {
        // Leave the call room before terminating.
        if (call.callRoomId) {
            [call leaveCallRoomWithRequestId:[self.twinmeContext newRequestId]];
        }

        NSArray<CallConnection *> *connections = [call getConnections];
        
        if (connections.count > 0) {
            for (CallConnection *connection in connections) {
                if ([connection status] != CallStatusTerminated) {
                    [connection terminateWithTerminateReason:terminateReason];
                    
                    [self onTerminatePeerConnectionWithConnection:connection terminateReason:terminateReason];
                }
            }
        } else if (terminateReason == TLPeerConnectionServiceTerminateReasonMerge) {
            // When the merged call reaches this point it won't have any CallConnections, so we need to explicitely send the CallEventMessageTerminateCall
            dispatch_async(dispatch_get_main_queue(), ^{
                CallEventMessage *eventMessage = [[CallEventMessage alloc] initWithCallId:call.uuid terminateReason:terminateReason];
                [[NSNotificationCenter defaultCenter] postNotificationName:CallEventMessageTerminateCall object:eventMessage];
            });
        }
    }

    if (disableAudio) {
        RTC_OBJC_TYPE(RTCAudioSession) *session = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
        session.isAudioEnabled = NO;

        // If the callCount is not 0, we have some inconsistency between activeCall, holdCall and the callkitCalls dictionary.
        if (callCount != 0) {
            TL_ASSERTION(self.twinmeContext, [CallsAssertPoint CALLKIT_INCONSISTENCY], [TLAssertValue initWithPeerConnectionId:call.callKitUUID], [TLAssertValue initWithNumber:(int)callCount], nil);
        }

        callCount = 0;
    }
    
    [[self.twinmeContext getJobService] reportActiveVoIPWithCallCount:callCount fetchCompletionHandler:^(TLBaseServiceErrorCode errorCode) {
        DDLogInfo(@"%@ acknowledge CallKit end-call: %@", LOG_TAG, action.callUUID);

        [action fulfill];
    }];
}

- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action {
    DDLogVerbose(@"%@ provider: %@ performSetHeldCallAction: %@", LOG_TAG, provider, action);
    DDLogInfo(@"%@ CallKit hold call %@ onHold: %d", LOG_TAG, action.callUUID, action.onHold);
    
    BOOL isValid;
    CallState *call;
    CallStatus callStatus;
    @synchronized (self) {
        call = self.callkitCalls[action.callUUID];
        if (!call) {
            isValid = NO;
            callStatus = 0;
        } else {
            isValid = YES;
            callStatus = [call status];
        }
    }
    
    if (!isValid) {
        [action fail];
    } else {
        if (action.onHold && !CALL_IS_PAUSED(callStatus)) {
            [call putOnHold];
            [self sendMessageWithCall:call message:CallEventMessageCallOnHold];
        }
        if (!action.onHold && CALL_IS_PAUSED(callStatus)) {
            [call resume];
            [self sendMessageWithCall:call message:CallEventMessageCallResumed];
        }

        [action fulfill];
    }
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action {
    DDLogVerbose(@"%@ provider: %@ performSetMutedCallAction: %@", LOG_TAG, provider, action);
    
    [self setAudioMute:action.muted];
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetGroupCallAction:(CXSetGroupCallAction *)action {
    DDLogVerbose(@"%@ provider: %@ performSetGroupCallAction: %@", LOG_TAG, provider, action);
    
    [action fail];
}

- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action {
    DDLogVerbose(@"%@ provider: %@ performPlayDTMFCallAction: %@", LOG_TAG, provider, action);
    
    [action fail];
}

- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action {
    DDLogVerbose(@"%@ provider: %@ timedOutPerformingAction: %@", LOG_TAG, provider, action);
    
    if (![action isKindOfClass:[CXCallAction class]]) {
        return;
    }

    CXCallAction *callAction = (CXCallAction *)action;

    // Remove connection from callUUIDs: we must not call CallKit again.
    long callCount;
    CallState *call;
    @synchronized (self) {
        call = self.callkitCalls[callAction.callUUID];
        if (!call) {
            return;
        }

        [self.callkitCalls removeObjectForKey:callAction.callUUID];
        callCount = self.callkitCalls.count;
    }

    TL_ASSERTION(self.twinmeContext, [CallsAssertPoint CALLKIT_TIMEOUT], [TLAssertValue initWithPeerConnectionId:callAction.callUUID], [TLAssertValue initWithNumber:(int)callCount], nil);

    // Terminate the call because something was wrong from CallKit side.
    [self terminateCallWithCall:call terminateReason:TLPeerConnectionServiceTerminateReasonTimeout];
    [[self.twinmeContext getJobService] reportActiveVoIPWithCallCount:callCount fetchCompletionHandler:nil];
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    DDLogVerbose(@"%@ provider: %@ didActivateAudioSession: %@", LOG_TAG, provider, audioSession);
    DDLogInfo(@"%@ CallKit audio session activated", LOG_TAG);
    
    BOOL speaker = NO;
    RTC_OBJC_TYPE(RTCAudioSession) *rtcAudioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
    for (AVAudioSessionPortDescription *portDescription in rtcAudioSession.currentRoute.outputs) {
        if ([portDescription.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]) {
            speaker = YES;
            break;
        }
    }
    
    [[RTC_OBJC_TYPE(RTCAudioSession) sharedInstance] audioSessionDidActivate:audioSession];
    [[RTC_OBJC_TYPE(RTCAudioSession) sharedInstance] setIsAudioEnabled:YES];

    if (speaker) {
        [self setSpeaker:speaker];
    }
    
    CallState *call = [self currentCall];
    if (call) {
        [self activateAudioWithCall:call];
    }
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {
    DDLogVerbose(@"%@ provider: %@ didDeactivateAudioSession: %@", LOG_TAG, provider, audioSession);
    DDLogInfo(@"%@ CallKit audio session deactivated", LOG_TAG);

    [[RTC_OBJC_TYPE(RTCAudioSession) sharedInstance] audioSessionDidDeactivate:audioSession];
    [[RTC_OBJC_TYPE(RTCAudioSession) sharedInstance] setIsAudioEnabled:NO];

    // Clear the state to make sure we will wait for the didActivateAudioSession to be called before
    // we try to create the incoming P2P audio session (if not, the receiver will not hear us!).
    self.audioDeviceEnabled = NO;
}

#pragma mark - CXCallObserverDelegate

- (void)callObserver:(nonnull CXCallObserver *)callObserver callChanged:(nonnull CXCall *)call {
    DDLogVerbose(@"%@ callObserver: %@ call: %@ ", LOG_TAG, callObserver, call);
    DDLogInfo(@"%@ call changed: %@ onHold: %d ended: %d", LOG_TAG, call.UUID, call.onHold, call.hasEnded);

    CallState *activeCall = [self currentCall];
    if (activeCall && ![activeCall.callKitUUID isEqual:call.UUID] && callObserver.calls.count == 1
        && CALL_IS_PAUSED(activeCall.status)) {
        [self resumeCallWithCall:activeCall];
    }
}

@end
