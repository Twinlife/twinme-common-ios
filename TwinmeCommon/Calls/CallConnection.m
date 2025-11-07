/*
 *  Copyright (c) 2022-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import <WebRTC/RTCVideoTrack.h>

#import <Twinlife/TLJobService.h>
#import <Twinlife/TLPeerConnectionService.h>
#import <Twinlife/TLVersion.h>
#import <Twinlife/TLBinaryCompactDecoder.h>
#import <Twinlife/TLSerializerFactory.h>
#import <Twinlife/TLTwinlife.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLOriginator.h>
#import <Twinme/TLCallReceiver.h>
#import <Twinme/TLGroup.h>

#import "CallService.h"
#import "CallConnection.h"
#import "CallParticipant.h"
#import "CallState.h"
#import "ParticipantInfoIQ.h"
#import "ParticipantTransferIQ.h"
#import "StreamingControlIQ.h"
#import "StreamingInfoIQ.h"
#import "StreamingRequestIQ.h"
#import "StreamingDataIQ.h"
#import "Streamer.h"
#import "StreamPlayer.h"

#import "KeyCheckInitiateIQ.h"
#import "OnKeyCheckInitiateIQ.h"
#import "TerminateKeyCheckIQ.h"
#import "TwincodeUriIQ.h"
#import "WordCheckIQ.h"

#import "CameraControlIQ.h"
#import "CameraResponseIQ.h"

#if 0
static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#if defined(SKRED)
# define DATA_VERSION                     @"CallService:1.5.0:stream,transfer,message,geoloc"
#else
# define DATA_VERSION                     @"CallService:1.5.0:stream,transfer,message"
#endif

#define CAP_STREAM                       @"stream"
#define CAP_TRANSFER                     @"transfer"
#define CAP_MESSAGE                      @"message"
#define CAP_GEOLOCATION                  @"geoloc"
#define CAP_ZOOMABLE                     @"zoomable"
#define CAP_ZOOM_ASK                     @"zoom-ask"

#define PARTICIPANT_INFO_SCHEMA_ID       @"a8aa7e0d-c495-4565-89bb-0c5462b54dd0"
#define PREPARE_TRANSFER_SCHEMA_ID       @"9eaa4ad1-3404-4bcc-875d-dc75c748e188"
#define ON_PREPARE_TRANSFER_SCHEMA_ID    @"a17516a2-4bd2-4284-9535-726b6eb1a211"
#define PARTICIPANT_TRANSFER_SCHEMA_ID   @"800fd629-83c4-4d42-8910-1b4256d19eb8"
#define TRANSFER_DONE_SCHEMA_ID          @"641bf1f6-ebbf-4501-9151-76abc1b9adad"
#define STREAMING_CONTROL_SCHEMA_ID      @"a080a7a6-59fe-4463-8ac4-61d897a2aa50"
#define STREAMING_INFO_SCHEMA_ID         @"30991309-e91f-4295-8a9c-995fcfaf042e"
#define STREAMING_REQUEST_SCHEMA_ID      @"4fab57a3-6c24-4318-b71d-22b60807cbc5"
#define STREAMING_DATA_SCHEMA_ID         @"5a5d0994-2ca3-4a62-9da3-9b7d5c4abdd4"
#define HOLD_CALL_SCHEMA_ID              @"f373eaf0-79ef-4091-8179-de622afce358"
#define RESUME_CALL_SCHEMA_ID            @"70ea071a-48f7-41e9-ace5-2c3616f8abf5"

#define KEY_CHECK_INITIATE_SCHEMA_ID     @"9c1a7c29-3402-4941-9480-0fd9258f5e5b"
#define ON_KEY_CHECK_INITIATE_SCHEMA_ID @"773743ea-2d2b-4b64-9ab5-e072571456d8"
#define WORD_CHECK_SCHEMA_ID             @"949a64db-deb4-4266-9a2a-b680c80ecc07"
#define TERMINATE_KEY_CHECK_SCHEMA_ID    @"f57606a3-9455-4efe-b375-38e1a142465f"
#define TWINCODE_URI_SCHEMA_ID           @"413c9c59-2b93-4010-8f6c-bd4f64ce5d9d"

#define SCREEN_SHARING_ON_SCHEMA_ID      @"c52596ad-23b4-45fe-bba1-5992e7aa872b"
#define SCREEN_SHARING_OFF_SCHEMA_ID     @"b35971e1-b4ae-45c1-a0a8-73cf2a78ee3c"

#define CAMERA_CONTROL_SCHEMA_ID         @"6512ff06-7c18-4de4-8760-61b87b9169a5"
#define CAMERA_RESPONSE_SCHEMA_ID        @"c9ba7001-c32d-4545-bdfb-e80ff0db21aa"

#define IMAGE_JPEG_QUALITY               0.8

static TLBinaryPacketIQSerializer *IQ_PARTICIPANT_INFO_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_PREPARE_TRANSFER_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_PREPARE_TRANSFER_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_PARTICIPANT_TRANSFER_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_TRANSFER_DONE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_STREAMING_CONTROL_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_STREAMING_INFO_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_STREAMING_REQUEST_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_STREAMING_DATA_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_HOLD_CALL_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_RESUME_CALL_SERIALIZER = nil;

static TLBinaryPacketIQSerializer *IQ_KEY_CHECK_INITIATE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_KEY_CHECK_INITIATE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_WORD_CHECK_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_TERMINATE_KEY_CHECK_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_TWINCODE_URI_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_SCREEN_SHARING_ON_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_SCREEN_SHARING_OFF_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_CAMERA_CONTROL_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_CAMERA_RESPONSE_SERIALIZER = nil;

//
// Interface: CallConnection ()
//

@interface CallConnection () <TLJob>

@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSUUID *, CallParticipant *> *participants;
@property (nonatomic, nullable) CallParticipant *mainParticipant;
@property (nonatomic) BOOL dataSourceOn;
@property (nonatomic) int retryState;
@property (nonatomic) int failState;
@property (nonatomic) int pendingState;
@property (nonatomic) int state;
@property (nonatomic) TLPeerConnectionServiceTerminateReason terminateReason;
@property (nonatomic, nullable) NSString *peerDataVersion;
@property (nonatomic, nullable) TLJobId *timerJobId;
@property (nonatomic, nullable) TLVersion *peerVersion;
@property (nonatomic, nullable) StreamPlayer *mediaStream;
@property (nonatomic) StreamingStatus peerStreamingStatus;
@property (nonatomic) CallMessageSupport peerMessageStatus;
@property (nonatomic) CallGeolocationSupport peerGeolocationStatus;
@property (nonatomic) TLVideoZoomable zoomable;
@property (nonatomic) BOOL remoteControlGranted;

- (void)postWithEvent:(CallParticipantEvent)event;

/// Update the peer streaming status and post an event if something was modified.
- (void)updatePeerWithStreamingStatus:(StreamingStatus)streamingStatus;

- (void)runJob;

- (long)newRequestId;

- (void)onPopWithDescriptor:(nonnull TLDescriptor *)descriptor;

- (void)onUpdateGeolocationWithDescriptor:(nonnull TLGeolocationDescriptor *)descriptor;

- (void)onReadWithDescriptorId:(nonnull TLDescriptorId *)descriptorId timestamp:(int64_t)timestamp;

- (void)onDeleteWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)onParticipantInfoIQWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onStreamingRequestIQWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onStreamingDataIQWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onStreamingControlIQWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onStreamingInfoIQWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onScreenSharingWithIQ:(nonnull TLBinaryPacketIQ *)iq state:(BOOL)state;

- (void)onCameraControlWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onCameraResponseWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onDataChannelOpenWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerVersion:(nonnull NSString *)peerVersion leadingPadding:(BOOL)leadingPadding;

@end

//
// Implementation: CallConnection
//

#undef LOG_TAG
#define LOG_TAG @"CallConnection"

@implementation CallConnection

@synthesize call = _call;

+ (void)initialize {
    
    IQ_PARTICIPANT_INFO_SERIALIZER = [[ParticipantInfoIQSerializer alloc] initWithSchema:PARTICIPANT_INFO_SCHEMA_ID schemaVersion:1];
    IQ_PREPARE_TRANSFER_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:PREPARE_TRANSFER_SCHEMA_ID schemaVersion:1];
    IQ_ON_PREPARE_TRANSFER_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_PREPARE_TRANSFER_SCHEMA_ID schemaVersion:1];
    IQ_PARTICIPANT_TRANSFER_SERIALIZER = [[ParticipantTransferIQSerializer alloc] initWithSchema:PARTICIPANT_TRANSFER_SCHEMA_ID schemaVersion:1];
    IQ_TRANSFER_DONE_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:TRANSFER_DONE_SCHEMA_ID schemaVersion:1];
    IQ_STREAMING_INFO_SERIALIZER = [[StreamingInfoIQSerializer alloc] initWithSchema:STREAMING_INFO_SCHEMA_ID schemaVersion:1];
    IQ_STREAMING_CONTROL_SERIALIZER = [[StreamingControlIQSerializer alloc] initWithSchema:STREAMING_CONTROL_SCHEMA_ID schemaVersion:1];
    IQ_STREAMING_REQUEST_SERIALIZER = [[StreamingRequestIQSerializer alloc] initWithSchema:STREAMING_REQUEST_SCHEMA_ID schemaVersion:1];
    IQ_STREAMING_DATA_SERIALIZER = [[StreamingDataIQSerializer alloc] initWithSchema:STREAMING_DATA_SCHEMA_ID schemaVersion:1];
    IQ_HOLD_CALL_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:HOLD_CALL_SCHEMA_ID schemaVersion:1];
    IQ_RESUME_CALL_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:RESUME_CALL_SCHEMA_ID schemaVersion:1];
    
    IQ_KEY_CHECK_INITIATE_SERIALIZER = [[KeyCheckInitiateIQSerializer alloc] initWithSchema:KEY_CHECK_INITIATE_SCHEMA_ID schemaVersion:1];
    IQ_ON_KEY_CHECK_INITIATE_SERIALIZER = [[OnKeyCheckInitiateIQSerializer alloc] initWithSchema:ON_KEY_CHECK_INITIATE_SCHEMA_ID schemaVersion:1];
    IQ_WORD_CHECK_SERIALIZER = [[WordCheckIQSerializer alloc] initWithSchema:WORD_CHECK_SCHEMA_ID schemaVersion:1];
    IQ_TERMINATE_KEY_CHECK_SERIALIZER = [[TerminateKeyCheckIQSerializer alloc] initWithSchema:TERMINATE_KEY_CHECK_SCHEMA_ID schemaVersion:1];
    IQ_TWINCODE_URI_SERIALIZER = [[TwincodeUriIQSerializer alloc] initWithSchema:TWINCODE_URI_SCHEMA_ID schemaVersion:1];
    
    IQ_SCREEN_SHARING_ON_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:SCREEN_SHARING_ON_SCHEMA_ID schemaVersion:1];
    IQ_SCREEN_SHARING_OFF_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:SCREEN_SHARING_OFF_SCHEMA_ID schemaVersion:1];

    IQ_CAMERA_CONTROL_SERIALIZER = [[CameraControlIQSerializer alloc] initWithSchema:CAMERA_CONTROL_SCHEMA_ID schemaVersion:1];
    IQ_CAMERA_RESPONSE_SERIALIZER = [[CameraResponseIQSerializer alloc] initWithSchema:CAMERA_RESPONSE_SCHEMA_ID schemaVersion:1];
}

+ (nonnull TLBinaryPacketIQSerializer *)STREAMING_CONTROL_SERIALIZER {
    
    return IQ_STREAMING_CONTROL_SERIALIZER;
}

+ (nonnull TLBinaryPacketIQSerializer *)STREAMING_INFO_SERIALIZER {
    
    return IQ_STREAMING_INFO_SERIALIZER;
}

+ (nonnull TLBinaryPacketIQSerializer *)STREAMING_REQUEST_SERIALIZER {
    
    return IQ_STREAMING_REQUEST_SERIALIZER;
}

+ (nonnull TLBinaryPacketIQSerializer *)STREAMING_DATA_SERIALIZER {
    
    return IQ_STREAMING_DATA_SERIALIZER;
}

- (nonnull instancetype)initWithCallService:(nonnull CallService *)callService serializerFactory:(nonnull TLSerializerFactory *)serializerFactory call:(nonnull CallState *)call originator:(nonnull id<TLOriginator>)originator mode:(CallStatus)mode peerConnectionId:(nullable NSUUID *)peerConnectionId retryState:(int)retryState memberId:(nullable NSString *)memberId {
    DDLogVerbose(@"%@ initWithCallService: %@ callService: %@ originator:%@ mode: %ld peerConnectionId: %@ retryState: %d memberId: %@", LOG_TAG, callService, call, originator, (long)mode, peerConnectionId, retryState, memberId);
    DDLogInfo(@"%@ call %@ new connection %@ from %@ mode: %ld retryState: %d memberId: %@", LOG_TAG, call, peerConnectionId, originator.name, (long)mode, retryState, memberId);

    self = [super initWithPeerConnectionService:[callService.twinmeContext getPeerConnectionService]];
    if (self) {
        _callService = callService;
        _participants = [[NSMutableDictionary alloc] init];
        _originator = originator;
        if ([originator isKindOfClass:[TLGroup class]]) {
            // Don't assign the group's name to the participant.
            _mainParticipant = [[CallParticipant alloc] initWithCallConnection:self name:nil description:nil participantId:[call allocateParticipantId]];
        } else {
            _mainParticipant = [[CallParticipant alloc] initWithCallConnection:self name:originator.name description:originator.identityDescription participantId:[call allocateParticipantId]];
            _mainParticipant.isCallReceiver = [originator isKindOfClass:[TLCallReceiver class]];
        }
        _callStatus = mode;
        _call = call;
        _timerJobId = nil;
        _dataSourceOn = NO;
        _terminateReason = TLPeerConnectionServiceTerminateReasonUnknown;
        _retryState = retryState;
        _failState = 0;
        _pendingState = 0;
        _callRoomMemberId = memberId;
        _transferToMemberId = nil;
        _peerStreamingStatus = StreamingStatusUnknown;
        _peerMessageStatus = CallMessageSupportUnknown;
        _peerGeolocationStatus = CallGeolocationSupportUnknown;
        _peerTwincodeOutboundId = originator.peerTwincodeOutboundId;
        _zoomable = TLVideoZoomableNever;
        if (peerConnectionId) {
            _participants[peerConnectionId] = _mainParticipant;
            self.peerConnectionId = peerConnectionId;
        }

        TLJobService *jobService = [callService.twinmeContext getJobService];
        _timerJobId = [jobService scheduleWithJob:self delay:CALL_IS_INCOMING(mode) ? INCOMING_CALL_TIMEOUT : OUTGOING_CALL_TIMEOUT priority:TLJobPriorityMessage];

        // Register the binary IQ handlers for the responses.
        __weak CallConnection *handler = self;
        [self addPacketListener:IQ_PARTICIPANT_TRANSFER_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onParticipantTransferIq:iq];
        }];
        [self addPacketListener:IQ_PREPARE_TRANSFER_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onPrepareTransferIQWithIQ:iq];
        }];
        [self addPacketListener:IQ_ON_PREPARE_TRANSFER_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onOnPrepareTransferIQWithIQ:iq];
        }];
        [self addPacketListener:IQ_PARTICIPANT_INFO_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onParticipantInfoIQWithIQ:iq];
        }];
        [self addPacketListener:IQ_PARTICIPANT_TRANSFER_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onParticipantTransferIq:iq];
        }];
        [self addPacketListener:IQ_TRANSFER_DONE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onTransferDoneWithIq:iq];
        }];
        [self addPacketListener:IQ_STREAMING_REQUEST_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onStreamingRequestIQWithIQ:iq];
        }];
        [self addPacketListener:IQ_STREAMING_DATA_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onStreamingDataIQWithIQ:iq];
        }];
        [self addPacketListener:IQ_STREAMING_CONTROL_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onStreamingControlIQWithIQ:iq];
        }];
        [self addPacketListener:IQ_STREAMING_INFO_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onStreamingInfoIQWithIQ:iq];
        }];
        [self addPacketListener:IQ_HOLD_CALL_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onHoldCallIQWithIQ:iq];
        }];
        [self addPacketListener:IQ_RESUME_CALL_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onResumeCallIQWithIQ:iq];
        }];
        
        [self addPacketListener:IQ_KEY_CHECK_INITIATE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onKeyCheckInitiateIQWithIQ:iq];
        }];
        [self addPacketListener:IQ_ON_KEY_CHECK_INITIATE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onOnKeyCheckInitiateIQWithIQ:iq];
        }];
        [self addPacketListener:IQ_WORD_CHECK_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onWordCheckIQWithIQ:iq];
        }];
        [self addPacketListener:IQ_TERMINATE_KEY_CHECK_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onTerminateKeyCheckIQWithIQ:iq];
        }];
        [self addPacketListener:IQ_TWINCODE_URI_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onTwincodeUriIQWithIQ:iq];
        }];

        [self addPacketListener:IQ_SCREEN_SHARING_ON_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onScreenSharingWithIQ:iq state:YES];
        }];
        [self addPacketListener:IQ_SCREEN_SHARING_OFF_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onScreenSharingWithIQ:iq state:NO];
        }];

        [self addPacketListener:IQ_CAMERA_CONTROL_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onCameraControlWithIQ:iq];
        }];
        [self addPacketListener:IQ_CAMERA_RESPONSE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [handler onCameraResponseWithIQ:iq];
        }];
    }

    return self;
}

- (void)setCall:(CallState *)call {
    _call = call;
    [_call addPeerWithConnection:self];
}

- (CallStatus)status {

    CallStatus result;
    @synchronized (self) {
        result = self.callStatus;
    }

    // DDLogVerbose(@"%@ status: %d", LOG_TAG, result);

    return result;
}

- (BOOL)videoEnabled {
    DDLogVerbose(@"%@ videoEnabled", LOG_TAG);

    @synchronized (self) {
        return self.call.videoSourceOn;
    }
}

- (BOOL)isRemoteControlGranted {
    DDLogVerbose(@"%@ isRemoteControlGranted", LOG_TAG);
    
    @synchronized (self) {
        return self.remoteControlGranted;
    }
}

- (CallGroupSupport)isGroupSupported {
    DDLogVerbose(@"%@ isGroupSupported", LOG_TAG);

    @synchronized (self) {
        if (self.peerVersion) {
            return self.peerVersion.major >= 2 ? CallGroupSupportYes : CallGroupSupportNo;
        } else {
            return CallGroupSupportUnknown;
        }
    }
}

- (CallMessageSupport)isMessageSupported {
    DDLogVerbose(@"%@ isMessageSupported", LOG_TAG);

    @synchronized (self) {
        return self.peerMessageStatus;
    }
}

- (CallGeolocationSupport)isGeolocationSupported {
    DDLogVerbose(@"%@ isGeolocationSupported", LOG_TAG);

    @synchronized (self) {
        return self.peerGeolocationStatus;
    }
}

- (TransferConnection)isTransferConnection {
    if (!self.originator) {
        return TransferConnectionUnknown;
    }
    
    if ([(NSObject*)self.originator respondsToSelector:@selector(isTransfer)] && [(TLCallReceiver *)self.originator isTransfer]) {
        return TransferConnectionYes;
    }
    
    return TransferConnectionNo;
}

- (TLVideoZoomable)isZoomable {
    DDLogVerbose(@"%@ isZoomable", LOG_TAG);
    
    @synchronized (self) {
        return self.zoomable;
    }
}

- (StreamingStatus)streamingStatus {
    DDLogVerbose(@"%@ streamingStatus", LOG_TAG);

    return _peerStreamingStatus;
}

- (nullable StreamPlayer *)streamPlayer {
    DDLogVerbose(@"%@ streamPlayer", LOG_TAG);
    
    return _mediaStream;
}

- (nullable CallParticipant *)mainParticipant {
    DDLogVerbose(@"%@ mainParticipant", LOG_TAG);

    return _mainParticipant;
}

- (void)appendParticipantsWithList:(nonnull NSMutableArray<CallParticipant *>*)list {
    DDLogVerbose(@"%@ appendParticipantsWithList", LOG_TAG);

    @synchronized (self) {
        for (NSUUID *uuid in self.participants) {
            [list addObject:self.participants[uuid]];
        }
    }
}

- (BOOL)checkOperation:(int)operation {

    BOOL result;
    @synchronized (self) {
        if ((self.state & operation) == 0) {
            self.state |= operation;
            result = YES;
        } else {
            result = NO;
        }
    }

    DDLogVerbose(@"%@ checkOperation: 0x%x => %@", LOG_TAG, operation, result ? @"YES" : @"NO");

    return result;
}

- (BOOL)isDoneOperation:(int)operation {

    BOOL result;
    @synchronized (self) {
        result = (self.state & operation) != 0;
    }

    DDLogVerbose(@"%@ isDoneOperation: 0x%x => %@", LOG_TAG, operation, result ? @"YES" : @"NO");

    return result;
}

- (BOOL)retryOperation:(int)operation {

    // The retryState defines the operations that could be retried if they failed.
    // The operation can be retried only once.
    BOOL result;
    @synchronized (self) {
        result = (self.retryState & self.state & operation) != 0;
        if (result) {
            self.retryState &= ~operation;
            self.failState |= operation;
            
            // If the operation is ready, retry it.
            if (operation & self.pendingState) {
                self.state &= ~operation;
                self.pendingState &= ~operation;
            }
        }
    }

    DDLogVerbose(@"%@ retryOperation: 0x%x => %@ state: 0x%x", LOG_TAG, operation, result ? @"YES" : @"NO", self.state);

    return result;
}

- (BOOL)isDoneOperation:(int)operation readyFor:(int)readyFor {

    // The retryState defines the operations that could be retried if they failed.
    // The operation can be retried only once.
    BOOL result;
    @synchronized (self) {
        result = (self.state & operation) != 0;
        if (!result) {
            self.pendingState |= readyFor;
            result = (self.failState & readyFor) != 0;

            // Operation failed and we are now ready to try it again.
            if (result) {
                self.state &= ~readyFor;
            }
        }
    }

    DDLogVerbose(@"%@ retryOperation: 0x%x => %@ state: 0x%x", LOG_TAG, operation, result ? @"YES" : @"NO", self.state);

    return result;
}

- (nonnull dispatch_queue_t)twinlifeQueue {
    DDLogVerbose(@"%@ twinlifeQueue", LOG_TAG);

    return [self.callService.twinmeContext.twinlife twinlifeQueue];
}

- (void)setTimerWithStatus:(CallStatus)status delay:(NSTimeInterval)delay {
    DDLogVerbose(@"%@ setTimerWithStatus: %ld delay: %f", LOG_TAG, (long)status, delay);

    TLJobService *jobService = [self.callService.twinmeContext getJobService];
    @synchronized (self) {
        if (self.timerJobId) {
            [self.timerJobId cancel];
        }

        self.callStatus = status;
        self.timerJobId = [jobService scheduleWithJob:self delay:delay priority:TLJobPriorityMessage];
    }
}

- (BOOL)updateConnectionWithState:(TLPeerConnectionServiceConnectionState)state {
    DDLogVerbose(@"%@ updateConnectionWithState: %ld", LOG_TAG, (long)state);

    @synchronized (self) {
        self.connectionState = state;
        if (state != TLPeerConnectionServiceConnectionStateConnected) {
            return NO;
        }
        
        if (self.timerJobId) {
            [self.timerJobId cancel];
            self.timerJobId = nil;
        }

        if (self.startTime == 0) {
            self.startTime = [[NSDate date] timeIntervalSince1970];
        }

        self.peerConnected = YES;
        self.callStatus = CALL_TO_ACTIVE(self.callStatus);

        return YES;
    }
}

- (void)setPeerVersionWithVersion:(nullable TLVersion *)version {
    DDLogVerbose(@"%@ setPeerVersionWithVersion: %@", LOG_TAG, version);

    @synchronized (self) {
        self.peerVersion = version;
    }
}

- (void)setAudioDirectionWithDirection:(RTCRtpTransceiverDirection)direction {
    DDLogVerbose(@"%@ setAudioDirectionWithDirection: %ld", LOG_TAG, (long)direction);

    if (self.peerConnectionId) {
        [self.peerConnectionService setAudioDirectionWithPeerConnectionId:self.peerConnectionId direction:direction];
    }
}

- (void)setVideoDirectionWithDirection:(RTCRtpTransceiverDirection)direction {
    DDLogVerbose(@"%@ setVideoDirectionWithDirection: %ld", LOG_TAG, (long)direction);

    if (self.peerConnectionId) {
        [self.peerConnectionService setVideoDirectionWithPeerConnectionId:self.peerConnectionId direction:direction];
    }
}

- (void)initSourcesAfterOperation:(int)operation {
    DDLogVerbose(@"%@ initSourcesAfterOperation", LOG_TAG);

    self.callStatus = self.call.status;
    // The initSources can be made only when the incoming peer connection is created.
    if (self.peerConnectionId && [self isDoneOperation:operation]) {
        [self.peerConnectionService initSourcesWithPeerConnectionId:self.peerConnectionId audioOn:self.call.audioSourceOn videoOn:self.call.videoSourceOn];
    }
}

- (void)onCreateOutgoingPeerConnectionWithPeerConnectionId:(nonnull NSUUID*)peerConnectionId {
    DDLogVerbose(@"%@ onCreateOutgoingPeerConnectionWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);

    CallParticipant *participant;
    @synchronized (self) {
        participant = self.mainParticipant;
        self.peerConnectionId = peerConnectionId;
        self.participants[peerConnectionId] = participant;
    }

    id<CallParticipantDelegate> observer = [self.callService callParticipantDelegate];
    if (observer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [observer onAddWithParticipant:participant];
        });
    }

    // A race can occur while we are creating the outgoing peer connection and the call is terminated.
    // In that case, we could have called `terminate()` but the peer connection id was not known
    // and the terminate for that CallConnection is ignored and remains, then the P2P connection
    // establishes and we have a live P2P that is not attached to any valid CallState.
    if ([self.call status] == CallStatusTerminated) {
        [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonCancel];
    }
}

- (void)terminateWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogInfo(@"%@ terminateWithTerminateReason: %ld", LOG_TAG, (long)terminateReason);

    if (self.peerConnectionId) {
        [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:self.peerConnectionId terminateReason:terminateReason];
    }
}

- (nullable NSString *)onAddRemoteTrackWithTrack:(RTC_OBJC_TYPE(RTCMediaStreamTrack) *)track {
    DDLogVerbose(@"%@ onAddRemoteTrackWithTrack: %@", LOG_TAG, track);
    
    CallTrackKind trackKind;
    CallParticipant *participant;
    @synchronized (self) {
        participant = self.mainParticipant;
        if (participant) {
            trackKind = [participant addWithTrack:track];
            if (trackKind == CallTrackKindVideo) {
                if (self.callStatus == CallStatusIncomingVideoBell) {
                    self.callStatus = CallStatusIncomingVideoCall;
                }
                participant.isVideoMute = NO;
            } else if (trackKind == CallTrackKindAudio) {
                participant.isAudioMute = NO;
            }
        } else {
            DDLogVerbose(@"%@ onAddRemoteTrackWithTrack: CallConnection has no mainParticipant", LOG_TAG);
            trackKind = CallTrackKindNone;
        }
    }

    id<CallParticipantDelegate> observer = [self.callService callParticipantDelegate];
    if (observer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [observer onEventWithParticipant:participant event:trackKind == CallTrackKindAudio ? CallParticipantEventAudioOn : CallParticipantEventVideoOn];
        });
    }
    return trackKind == CallTrackKindAudio ? nil : CallEventMessageVideoUpdate;
}

- (nullable NSString *)onRemoveRemoteTrackWithTrackId:(nonnull NSString *)trackId {
    DDLogVerbose(@"%@ onRemoveRemoteTrackWithTrackId: %@", LOG_TAG, trackId);

    CallTrackKind trackKind;
    CallParticipant *participant;
    @synchronized (self) {
        participant = self.mainParticipant;
        if (participant) {
            trackKind = [self.mainParticipant removeWithTrackId:trackId];
            if (trackKind == CallTrackKindVideo) {
                participant.isVideoMute = YES;
            } else if (trackKind == CallTrackKindAudio) {
                participant.isAudioMute = YES;
            }
        } else {
            trackKind = CallTrackKindNone;
        }
    }
    if (participant && trackKind != CallTrackKindNone) {
        id<CallParticipantDelegate> observer = [self.callService callParticipantDelegate];
        if (observer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [observer onEventWithParticipant:participant event:trackKind == CallTrackKindAudio ? CallParticipantEventAudioOff : CallParticipantEventVideoOff];
            });
        }
    }
    switch (trackKind) {
        case CallTrackKindAudio:
            return nil;

        case CallTrackKindVideo:
            return CallEventMessageVideoUpdate;

        case CallTrackKindNone:
            return nil;
    }
}

- (void)setDeviceRinging {
    self.connectionState = TLPeerConnectionServiceConnectionStateRinging;

    id<CallParticipantDelegate> observer = [self.callService callParticipantDelegate];
    if (observer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [observer onEventWithParticipant:self.mainParticipant event:CallParticipantEventRinging];
        });
    }
}

#pragma mark - TLJob

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);
    
    @synchronized (self) {
        if (!self.timerJobId) {
            return;
        }

        self.timerJobId = nil;

        if (self.connectionState == TLPeerConnectionServiceConnectionStateConnected) {
            DDLogVerbose(@"%@ we're actually connected! aborting terminate", LOG_TAG);
            return;
        }
    }

    [self terminateWithTerminateReason:TLPeerConnectionServiceTerminateReasonTimeout];

}

#pragma mark - TLConversationHandler

- (long)newRequestId {
    DDLogVerbose(@"%@ newRequestId", LOG_TAG);
    
    return [self.call allocateRequestId];
}

- (void)onPopWithDescriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopWithDescriptor: %@", LOG_TAG, descriptor);
    
    if (!self.mainParticipant.senderId) {
        self.mainParticipant.senderId = descriptor.descriptorId.twincodeOutboundId;
    }
    [self.call onPopDescriptorWithParticipant:self.mainParticipant descriptor:descriptor];
}

- (void)onUpdateGeolocationWithDescriptor:(nonnull TLGeolocationDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopWithDescriptor: %@", LOG_TAG, descriptor);

    [self.call onUpdateGeolocationWithParticipant:self.mainParticipant descriptor:descriptor];
}

- (void)onReadWithDescriptorId:(nonnull TLDescriptorId *)descriptorId timestamp:(int64_t)timestamp {
    DDLogVerbose(@"%@ onReadWithDescriptorId: %@ timestamp: %lld", LOG_TAG, descriptorId, timestamp);

}

- (void)onDeleteWithDescriptorId:(nonnull TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ onDeleteWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    [self.call onDeleteDescriptorWithParticipant:self.mainParticipant descriptorId:descriptorId];
}

- (nonnull TLPeerConnectionDataChannelConfiguration *)configurationWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sdpEncryptionStatus:(TLPeerConnectionServiceSdpEncryptionStatus)sdpEncryptionStatus {
    DDLogVerbose(@"%@ configurationWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);

    TLVideoZoomable zoomable = [self.call zoomableByPeer];
    switch (zoomable) {
        case TLVideoZoomableNever:
            return [[TLPeerConnectionDataChannelConfiguration alloc] initWithVersion:DATA_VERSION leadingPadding:NO];

        case TLVideoZoomableAllow:
            return [[TLPeerConnectionDataChannelConfiguration alloc] initWithVersion:DATA_VERSION "," CAP_ZOOMABLE leadingPadding:NO];

        case TLVideoZoomableAsk:
            return [[TLPeerConnectionDataChannelConfiguration alloc] initWithVersion:DATA_VERSION "," CAP_ZOOM_ASK leadingPadding:NO];
    }
}

- (void)onDataChannelOpenWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerVersion:(nonnull NSString *)peerVersion leadingPadding:(BOOL)leadingPadding {
    DDLogVerbose(@"%@ onDataChannelOpenWithPeerConnectionId: %@ peerVersion: %@", LOG_TAG, peerConnectionId, peerVersion);

    self.peerDataVersion = peerVersion;

    // CallService:<version>:<capability>,...,<capability>.
    NSArray<NSString *> *list = [peerVersion componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":,"]];
    if (list.count >= 3) {
        StreamingStatus status = StreamingStatusNotAvailable;
        CallMessageSupport messageStatus = CallMessageSupportNo;
        CallGeolocationSupport geolocationStatus = CallGeolocationSupportNo;
        TLVideoZoomable zoomable = TLVideoZoomableNever;

        for (NSUInteger i = list.count; --i >= 1; ) {
            if ([list[i] isEqualToString:CAP_STREAM]) {
                status = StreamingStatusReady;
            } else if ([list[i] isEqualToString:CAP_MESSAGE]) {
                messageStatus = CallMessageSupportYes;
            } else if ([list[i] isEqualToString:CAP_GEOLOCATION]) {
                geolocationStatus = CallGeolocationSupportYes;
            } else if ([list[i] isEqualToString:CAP_ZOOMABLE]) {
                zoomable = TLVideoZoomableAllow;
            } else if ([list[i] isEqualToString:CAP_ZOOM_ASK]) {
                zoomable = TLVideoZoomableAsk;
            }
        }
        self.peerStreamingStatus = status;
        self.peerMessageStatus = messageStatus;
        self.peerGeolocationStatus = geolocationStatus;
        self.zoomable = zoomable;
    }

    // If this is a P2P within a call room, send the peer our identification.
    if (self.call.callRoomId || [self isTransferConnection] == TransferConnectionYes) {
        [self sendParticipantInfo];
    }

    if (self.callService.isLocationStartShared && self.peerGeolocationStatus == CallGeolocationSupportYes) {
        [self.callService sendGeolocationWithConnection:self];
    }
    
    // Once the data-channel is connected, we know the peer capabilities may be updated the UI.
    id<CallParticipantDelegate> observer = [self.callService callParticipantDelegate];
    if (observer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [observer onEventWithParticipant:self.mainParticipant event:CallParticipantEventConnected];
        });
    }
}

- (void)updatePeerWithStreamingStatus:(StreamingStatus)streamingStatus {
    DDLogVerbose(@"%@ updatePeerWithStreamingStatus: %d", LOG_TAG, streamingStatus);

    @synchronized (self) {
        if (self.peerStreamingStatus == streamingStatus) {
            return;
        }
        
        self.peerStreamingStatus = streamingStatus;
    }

    [self postWithEvent:CallParticipantEventStreamStatus];
}

#pragma mark - Private

- (void)postWithEvent:(CallParticipantEvent)event {
    DDLogVerbose(@"%@ postWithEvent: %d", LOG_TAG, event);

    id<CallParticipantDelegate> observer = [self.callService callParticipantDelegate];
    if (observer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [observer onEventWithParticipant:self.mainParticipant event:event];
        });
    }
}

- (BOOL)releaseWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ releaseWithTerminateReason: %d", LOG_TAG, (int)terminateReason);

    NSMutableArray<CallParticipant *> *participants = nil;
    StreamPlayer *mediaStream;
    @synchronized (self) {
        if (self.timerJobId) {
            [self.timerJobId cancel];
            self.timerJobId = nil;
        }
        mediaStream = self.mediaStream;
        self.mediaStream = nil;

        for (NSUUID *uuid in self.participants) {
            CallParticipant *participant = self.participants[uuid];
            [participant releaseParticipant];
            if (!participants) {
                participants = [[NSMutableArray alloc] init];
            }
            [participants addObject:participant];
        }

        [self.participants removeAllObjects];
    }
    
    if (mediaStream) {
        [mediaStream stopWithNotify:NO];
    }

    id<CallParticipantDelegate> delegate = self.callService.callParticipantDelegate;
    if (delegate && participants) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate onRemoveWithParticipants:participants];
        });
    }
    return [self.call removeWithConnection:self terminateReason:terminateReason];
}

- (void)sendParticipantInfo {
    DDLogVerbose(@"%@ sendParticipantInfo", LOG_TAG);

    CallState *call = self.call;
    NSString *name = call.identityName;
    NSString *description = call.identityDescription;
    UIImage *avatar = call.identityAvatar;

    NSData *thumbnail;
    if (avatar) {
        thumbnail = UIImageJPEGRepresentation(avatar, IMAGE_JPEG_QUALITY);
    } else {
        thumbnail = nil;
    }

    NSString *memberId = (self.call.callRoomMemberId) ? self.call.callRoomMemberId : @"";
    
    ParticipantInfoIQ *participantInfoIQ = [[ParticipantInfoIQ alloc] initWithSerializer:IQ_PARTICIPANT_INFO_SERIALIZER requestId:1 memberId:memberId name:name memberDescription:description thumbnail:thumbnail];

    [self sendMessageWithIQ:participantInfoIQ statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
}

- (void)onParticipantInfoIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onParticipantInfoIQWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[ParticipantInfoIQ class]]) {
        return;
    }

    if (self.mainParticipant.transferredFromParticipantId != nil) {
        // The participant is a transfer target, ignore the info
        // because we already copied it from the transferred participant.
        return;
    }
    
    ParticipantInfoIQ *participantInfoIQ = (ParticipantInfoIQ *)iq;
    UIImage *avatar = nil;
    if (participantInfoIQ.thumbnail) {
        avatar = [UIImage imageWithData:participantInfoIQ.thumbnail];
    }
    
    // Click-to-call callers can set an avatar but it's not mandatory,
    // so we use the CallReceiver's avatar if we didn't receive one from the caller.
    if (!avatar && self.call.originator && [(NSObject *) self.call.originator class] == [TLCallReceiver class]) {
        avatar = self.call.identityAvatar;
    }
    
    CallParticipant *participant = self.mainParticipant;
    [participant updateWithName:participantInfoIQ.name description:participantInfoIQ.memberDescription avatar:avatar];

    [self postWithEvent:CallParticipantEventIdentity];
    [self.call sendMessage];
}

#pragma mark - Streaming IQ

- (void)onStreamingRequestIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onStreamingRequestIQWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[StreamingRequestIQ class]]) {
        return;
    }

    StreamingRequestIQ *streamingRequestIQ = (StreamingRequestIQ *)iq;
    Streamer *streamer = [self.call currentStreamer];
    if (streamer && streamingRequestIQ.ident == streamer.ident) {
        [streamer onStreamingRequestWithConnection:self iq:streamingRequestIQ];
    }
}

- (void)onStreamingDataIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onStreamingDataIQWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[StreamingDataIQ class]]) {
        return;
    }

    StreamingDataIQ *streamingDataIQ = (StreamingDataIQ *)iq;
    StreamPlayer *streamPlayer;
    @synchronized (self) {
        streamPlayer = self.mediaStream;
    }
    if (streamPlayer && streamingDataIQ.ident == streamPlayer.ident) {
        [streamPlayer onStreamingDataWithIQ:streamingDataIQ];
    }
}

- (void)onStreamingControlIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onStreamingControlIQWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[StreamingControlIQ class]]) {
        return;
    }

    StreamingControlIQ *streamingControlIQ = (StreamingControlIQ *)iq;
    StreamPlayer *stopMediaStream = nil;
    StreamPlayer *mediaStream;
    switch (streamingControlIQ.mode) {
        case StreamingControlModeStartAudio:
            mediaStream = [[StreamPlayer alloc] initWithIdent:streamingControlIQ.ident size:streamingControlIQ.length video:NO call:self.call connection:self streamer:nil];
            @synchronized (self) {
                stopMediaStream = self.mediaStream;
                self.mediaStream = mediaStream;
            }
            [mediaStream start];
            [self postWithEvent:CallParticipantEventStreamStart];
            break;

        case StreamingControlModeStartVideo:
            mediaStream = [[StreamPlayer alloc] initWithIdent:streamingControlIQ.ident size:streamingControlIQ.length video:YES call:self.call connection:self streamer:nil];
            @synchronized (self) {
                stopMediaStream = self.mediaStream;
                self.mediaStream = mediaStream;
            }
            [mediaStream start];
            [self postWithEvent:CallParticipantEventStreamStart];
            break;

        case StreamingControlModePause:
            @synchronized (self) {
                mediaStream = self.mediaStream;
            }
            if (mediaStream) {
                [mediaStream onStreamingControlWithIQ:streamingControlIQ];
                [self postWithEvent:CallParticipantEventStreamPause];
            }
            break;

        case StreamingControlModeResume:
            @synchronized (self) {
                mediaStream = self.mediaStream;
            }
            if (mediaStream) {
                [mediaStream onStreamingControlWithIQ:streamingControlIQ];
                [self postWithEvent:CallParticipantEventStreamResume];
            }
            break;

        case StreamingControlModeSeek:
            @synchronized (self) {
                mediaStream = self.mediaStream;
            }
            if (mediaStream && streamingControlIQ.length >= 0 && mediaStream.ident == streamingControlIQ.ident) {
                [mediaStream seekWithPosition:streamingControlIQ.length];
            }
            break;

        case StreamingControlModeStop:
            @synchronized (self) {
                stopMediaStream = self.mediaStream;
                self.mediaStream = nil;
            }
            if (stopMediaStream) {
                [self postWithEvent:CallParticipantEventStreamStop];
            }
            break;

        case StreamingControlModeAskPause:
        case StreamingControlModeAskResume:
        case StreamingControlModeAskSeek:
        case StreamingControlModeAskStop:
        case StreamingControlModeStatusPlaying:
        case StreamingControlModeStatusPaused:
        case StreamingControlModeStatusError:
        case StreamingControlModeStatusUnSupported:
        case StreamingControlModeStatusReady:
        case StreamingControlModeStatusCompleted: {
            Streamer *streamer = [self.call currentStreamer];
            if (streamer) {
                [streamer onStreamingControlWithConnection:self iq:streamingControlIQ];
            }
            break;
        }

        default:
            break;
    }

    if (stopMediaStream) {
        [stopMediaStream stopWithNotify:YES];
    }
}

- (void)onStreamingInfoIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onStreamingInfoIQWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[StreamingInfoIQ class]]) {
        return;
    }

    StreamingInfoIQ *streamingInfoIQ = (StreamingInfoIQ *)iq;
    StreamPlayer *streamPlayer;
    @synchronized (self) {
        streamPlayer = self.mediaStream;
    }
    if (!streamPlayer || streamPlayer.ident != streamingInfoIQ.ident) {
        return;
    }

    UIImage *image = nil;
    if (streamingInfoIQ.artwork) {
        image = [UIImage imageWithData:streamingInfoIQ.artwork];
    }
    [streamPlayer setInformationWithTitle:streamingInfoIQ.title album:streamingInfoIQ.album artist:streamingInfoIQ.artist artwork:image duration:streamingInfoIQ.duration];
    
    [self postWithEvent:CallParticipantEventStreamInfo];
}

#pragma mark - Transfer IQ

- (void)sendParticipantTransferIQWithMemberId:(nonnull NSString *) memberId{
    DDLogVerbose(@"%@ sendParticipantTransferIQWithMemberId: %@", LOG_TAG, memberId);

    id<TLOriginator> originator = self.call.originator;
    
    if (!originator || !self.peerConnectionId) {
        return;
    }
    
    ParticipantTransferIQ *iq = [[ParticipantTransferIQ alloc] initWithSerializer:IQ_PARTICIPANT_TRANSFER_SERIALIZER requestId:[self.call allocateRequestId] memberId:memberId];
    
    [self sendMessageWithIQ:iq statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
}

- (void)onParticipantTransferIq:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onParticipantTransferIq: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[ParticipantTransferIQ class]]) {
        return;
    }

    ParticipantTransferIQ *participantTransferIQ = (ParticipantTransferIQ *)iq;
    
    self.transferToMemberId = participantTransferIQ.memberId;
    [self.call onParticipantTransferWithMemberId:participantTransferIQ.memberId];
}

- (void)sendPrepareTransferIQ {
    DDLogVerbose(@"%@ sendPrepareTransferIQ", LOG_TAG);
    
    if (!self.peerConnectionId) {
        return;
    }

    TLBinaryPacketIQ *iq = [[TLBinaryPacketIQ alloc] initWithSerializer:IQ_PREPARE_TRANSFER_SERIALIZER requestId:[self.call allocateRequestId]];
    
    [self sendMessageWithIQ:iq statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
}

- (void)sendTransferDoneIQ {
    DDLogVerbose(@"%@ sendTransferDoneIQ", LOG_TAG);
    
    if (!self.peerConnectionId) {
        return;
    }

    TLBinaryPacketIQ *iq = [[TLBinaryPacketIQ alloc] initWithSerializer:IQ_TRANSFER_DONE_SERIALIZER requestId:[self.call allocateRequestId]];
    
    [self sendMessageWithIQ:iq statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
}

- (void)onPrepareTransferIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onPrepareTransferIq: %@", LOG_TAG, iq);
    
    if (!self.peerConnectionId) {
        return;
    }
    
    self.call.transferFromConnection = self;
    
    TLBinaryPacketIQ *ack = [[TLBinaryPacketIQ alloc] initWithSerializer:IQ_ON_PREPARE_TRANSFER_SERIALIZER iq:iq];
    
    [self sendMessageWithIQ:ack statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
}

- (void)onOnPrepareTransferIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onOnPrepareTransferIq: %@", LOG_TAG, iq);
    
    if (!self.peerConnectionId) {
        return;
    }

    [self.call onOnPrepareTransferWithConnectionId:self.peerConnectionId];
}

- (void)onTransferDoneWithIq:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onTransferDoneWithIq: %@", LOG_TAG, iq);

    if ([self isTransferConnection] != TransferConnectionYes) {
        return;
    }
    
    [self.call onTransferDone];
}

#pragma mark - Screen-Sharing IQ

- (void)onScreenSharingWithIQ:(TLBinaryPacketIQ *)iq state:(BOOL)state {
    DDLogVerbose(@"%@ onScreenSharingWithIQ: %@ state: %d", LOG_TAG, iq, state);

    CallParticipant *participant;
    @synchronized (self) {
        participant = self.mainParticipant;
    }

    participant.isScreenSharing = state;
    id<CallParticipantDelegate> observer = [self.callService callParticipantDelegate];
    if (observer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [observer onEventWithParticipant:participant event:state ? CallParticipantEventScreenSharingOn : CallParticipantEventScreenSharingOff];
        });
    }
}

#pragma mark - Hold-Resume IQ

- (void)sendHoldCallIQ {
    DDLogVerbose(@"%@ sendHoldCallIQ", LOG_TAG);
    
    if (!self.peerConnectionId) {
        return;
    }

    TLBinaryPacketIQ *iq = [[TLBinaryPacketIQ alloc] initWithSerializer:IQ_HOLD_CALL_SERIALIZER requestId:[self.call allocateRequestId]];
    
    [self sendMessageWithIQ:iq statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
}

- (void)sendResumeCallIQ {
    DDLogVerbose(@"%@ sendResumeCallIQ", LOG_TAG);
    
    if (!self.peerConnectionId) {
        return;
    }

    TLBinaryPacketIQ *iq = [[TLBinaryPacketIQ alloc] initWithSerializer:IQ_RESUME_CALL_SERIALIZER requestId:[self.call allocateRequestId]];
    
    [self sendMessageWithIQ:iq statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
}

- (void)onHoldCallIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onHoldCallIQ: %@", LOG_TAG, iq);
    
    @synchronized (self) {
        if (!self.peerConnectionId || CALL_IS_PEER_ON_HOLD(self.callStatus)) {
            return;
        }
        
        self.callStatus |= CALL_PEER_ON_HOLD;
    }
    [self.call onPeerHoldCallWithConnectionId: self.peerConnectionId];
}

- (void)onResumeCallIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onResumeCallIQ: %@", LOG_TAG, iq);
    
    @synchronized (self) {
        if (!self.peerConnectionId || !CALL_IS_PEER_ON_HOLD(self.callStatus)) {
            return;
        }
        
        self.callStatus &= ~CALL_PEER_ON_HOLD;
    }
    [self.call onPeerResumeCallWithConnectionId:self.peerConnectionId];
}

- (void)putOnHold {
    DDLogVerbose(@"%@ putOnHold", LOG_TAG);

    if (self.remoteControlGranted) {
        [self sendCameraStop];
    }
    
    // The initSources can be made only when the incoming peer connection is created.
    if (self.peerConnectionId && [self isDoneOperation:CREATED_PEER_CONNECTION]) {
        [self.peerConnectionService initSourcesWithPeerConnectionId:self.peerConnectionId audioOn:NO videoOn:NO];
    }
}

- (void) resume {
    DDLogVerbose(@"%@ resume", LOG_TAG);

    [self resumeWithAudio:self.call.audioSourceOn video:self.call.videoSourceOn];
}

- (void) resumeWithAudio:(BOOL)audio video:(BOOL)video {
    DDLogVerbose(@"%@ resumeWithAudio: %@ video: %@", LOG_TAG, audio? @"YES":@"NO", video? @"YES":@"NO");

    if (self.peerConnectionId) {
        [self.peerConnectionService initSourcesWithPeerConnectionId:self.peerConnectionId audioOn:audio videoOn:video];
    }
}

#pragma mark - Key check IQ

- (void)onKeyCheckInitiateIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onKeyCheckInitiateIQWithIQ: %@", LOG_TAG, iq);
    
    if (!self.peerConnectionId) {
        return;
    }
    
    KeyCheckInitiateIQ *keyCheckInitiateIQ = (KeyCheckInitiateIQ *)iq;
    
    [self.call onPeerKeyCheckInitiateWithConnectionId:self.peerConnectionId locale:keyCheckInitiateIQ.locale];
}

- (void)onOnKeyCheckInitiateIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onOnKeyCheckInitiateIQWithIQ: %@", LOG_TAG, iq);
    
    if (!self.peerConnectionId) {
        return;
    }
    
    OnKeyCheckInitiateIQ *onKeyCheckInitiateIQ = (OnKeyCheckInitiateIQ *)iq;
    
    [self.call onOnKeyCheckInitiateWithConnectionId:self.peerConnectionId errorCode:onKeyCheckInitiateIQ.errorCode];
}

- (void)onWordCheckIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onWordCheckIQWithIQ: %@", LOG_TAG, iq);
    
    if (!self.peerConnectionId) {
        return;
    }
    
    WordCheckIQ *wordCheckIQ = (WordCheckIQ *)iq;
    
    [self.call onPeerWordCheckResultWithConnectionId:self.peerConnectionId wordCheckResult:wordCheckIQ.result];
}

- (void)onTerminateKeyCheckIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onTerminateKeyCheckIQWithIQ: %@", LOG_TAG, iq);
    
    if (!self.peerConnectionId) {
        return;
    }
    
    TerminateKeyCheckIQ *terminateKeyCheckIQ = (TerminateKeyCheckIQ *)iq;
    
    [self.call onTerminateKeyCheckWithConnectionId:self.peerConnectionId result:terminateKeyCheckIQ.result];
}

- (void)onTwincodeUriIQWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onTwincodeUriIQWithIQ: %@", LOG_TAG, iq);
    
    if (!self.peerConnectionId) {
        return;
    }
    
    TwincodeUriIQ *twincodeUriIQ = (TwincodeUriIQ *)iq;
    
    [self.call onTwincodeURIWithConnectionId:self.peerConnectionId uri:twincodeUriIQ.uri];
}


/// Key check

- (void)sendKeyCheckInitiateIQWithLanguage:(nonnull NSLocale *)language {
    DDLogVerbose(@"%@ sendKeyCheckInitiateIQWithLanguage: %@", LOG_TAG, language.languageCode);

    if (self.peerConnectionId) {
        KeyCheckInitiateIQ *iq = [[KeyCheckInitiateIQ alloc] initWithSerializer:IQ_KEY_CHECK_INITIATE_SERIALIZER requestId:[self.call allocateRequestId] locale:language];
        [self sendMessageWithIQ:iq statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
    }
}

- (void)sendOnKeyCheckInitiateIQWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ sendOnKeyCheckInitiateIQWithErrorCode: %d", LOG_TAG, errorCode);

    if (self.peerConnectionId) {
        OnKeyCheckInitiateIQ *iq = [[OnKeyCheckInitiateIQ alloc] initWithSerializer:IQ_ON_KEY_CHECK_INITIATE_SERIALIZER requestId:[self.call allocateRequestId] errorCode:errorCode];
        [self sendMessageWithIQ:iq statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
    }
}

- (void)sendWordCheckResultIQWithResult:(nonnull WordCheckResult *)result {
    DDLogVerbose(@"%@ sendWordCheckResultIQWithResult: %@", LOG_TAG, result);

    if (self.peerConnectionId) {
        WordCheckIQ *iq = [[WordCheckIQ alloc] initWithSerializer:IQ_WORD_CHECK_SERIALIZER requestId:[self.call allocateRequestId] wordCheckResult:result];
        [self sendMessageWithIQ:iq statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
    }
}

- (void)sendTerminateKeyCheckIQWithResult:(BOOL)result {
    DDLogVerbose(@"%@ sendTerminateKeyCheckIQWithResult: %@", LOG_TAG, result ? @"YES" : @"NO");

    if (self.peerConnectionId) {
        TerminateKeyCheckIQ *iq = [[TerminateKeyCheckIQ alloc] initWithSerializer:IQ_TERMINATE_KEY_CHECK_SERIALIZER requestId:[self.call allocateRequestId] result:result];
        [self sendMessageWithIQ:iq statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
    }
}

- (void)sendTwincodeUriIQWithUri:(nonnull NSString *)uri {
    DDLogVerbose(@"%@ sendTwincodeUriIQWithUri: %@", LOG_TAG, uri);

    if (self.peerConnectionId) {
        TwincodeUriIQ *iq = [[TwincodeUriIQ alloc] initWithSerializer:IQ_TWINCODE_URI_SERIALIZER requestId:[self.call allocateRequestId] uri:uri];
        [self sendMessageWithIQ:iq statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
    }
}

#pragma mark - Camera control IQ

/// Send a camera control IQ command
- (void)sendCameraControlWithMode:(CameraControlMode)mode camera:(int)camera scale:(int)scale {
    DDLogVerbose(@"%@ sendCameraControlWithMode: %lu mode: %d scale: %d", LOG_TAG, mode, camera, scale);
    
    // If this is disabled on the relation (or not supported), don't send the camera control IQ.
    if (self.zoomable == TLVideoZoomableNever) {
        return;
    }

    CameraControlIQ *cameraControlIQ = [[CameraControlIQ alloc] initWithSerializer:IQ_CAMERA_CONTROL_SERIALIZER requestId:[self.call allocateRequestId] mode:mode camera:camera scale:scale];
    [self sendMessageWithIQ:cameraControlIQ statType:TLPeerConnectionServiceStatTypeIqSetPushTransient];
}

- (void)sendCameraControlGrant {
    DDLogVerbose(@"%@ sendCameraControlGrant", LOG_TAG);

    self.remoteControlGranted = YES;
    int activeCamera = [self.call frontCameraOn] ? 1 : 2;
    [self sendCameraResponseWithError:TLBaseServiceErrorCodeSuccess cameraBitmap:0x03 activeCamera:activeCamera minScale:1 maxScale:100];
}

- (void)sendCameraStop {
    DDLogVerbose(@"%@ sendCameraStop", LOG_TAG);

    if (self.remoteControlGranted) {
        self.remoteControlGranted = NO;
        [self sendCameraResponseWithError:TLBaseServiceErrorCodeSuccess cameraBitmap:0 activeCamera:0 minScale:0 maxScale:0];
        self.mainParticipant.remoteActiveCamera = 0;
        [self postWithEvent:CallParticipantEventCameraControlDone];
    } else {
        [self sendCameraControlWithMode:CameraControlModeStop camera:0 scale:0];
    }
}

- (void)sendCameraResponseWithError:(TLBaseServiceErrorCode)errorCode cameraBitmap:(int64_t)cameraBitmap activeCamera:(int)activeCamera minScale:(int)minScale maxScale:(int)maxScale {
    DDLogVerbose(@"%@ sendCameraResponseWithError: %u cameraBitmap: %lld activeCamera: %d minScale: %d maxScale: %d", LOG_TAG, errorCode, cameraBitmap, activeCamera, minScale, maxScale);

    // Even if the relation disabled camera control we must answer.
    CameraResponseIQ *cameraResponseIQ = [[CameraResponseIQ alloc] initWithSerializer:IQ_CAMERA_RESPONSE_SERIALIZER requestId:[self.call allocateRequestId] errorCode:errorCode cameraBitmap:cameraBitmap activeCamera:activeCamera minScale:minScale maxScale:maxScale];
    [self sendMessageWithIQ:cameraResponseIQ statType:TLPeerConnectionServiceStatTypeIqSetPushFile];
}

- (void)onCameraControlWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onCameraControlWithIQ: %@", LOG_TAG, iq);
    
    if (!self.peerConnectionId) {
        return;
    }
    
    TLVideoZoomable zoomable = [self.call zoomableByPeer];
    if (zoomable == TLVideoZoomableNever || CALL_IS_PAUSED(self.call.status)) {
        [self sendCameraResponseWithError:TLBaseServiceErrorCodeNoPermission cameraBitmap:0 activeCamera:0 minScale:0 maxScale:0];
        return;
    }

    CameraControlIQ *cameraControlIQ = (CameraControlIQ *)iq;
    if (zoomable == TLVideoZoomableAsk && !self.remoteControlGranted && cameraControlIQ.mode != CameraControlModeStop) {
        [self postWithEvent:CallParticipantEventAskCameraControl];
        return;
    }

    switch (cameraControlIQ.mode) {
        case CameraControlModeCheck:
            // We are either in Zoomable.ALLOW or mRemoteControlGranted is set: remote camera control is granted.
            [self sendCameraControlGrant];
            break;

        case CameraControlModeON:
        case CameraControlModeOFF:
            [self.call.callService setCameraMute:cameraControlIQ.mode == CameraControlModeOFF];
            break;

        case CameraControlModeSelect:
            // Switch camera can be made directly: the UI will update as a result of a WebRTC callback.
            [self remoteSwitchCamera:cameraControlIQ.camera];
            break;

        case CameraControlModeZoom:
            [self.call.callService updateCameraControlZoom:cameraControlIQ.scale];
            break;

        case CameraControlModeStop:
            self.remoteControlGranted = NO;
            [self postWithEvent:CallParticipantEventCameraControlDone];
            [self sendCameraResponseWithError:TLBaseServiceErrorCodeSuccess cameraBitmap:0 activeCamera:0 minScale:0 maxScale:0];
            break;
    }
}

- (void)remoteSwitchCamera:(int)camera {
    DDLogVerbose(@"%@ remoteSwitchCamera: %d", LOG_TAG, camera);

    [self.peerConnectionService switchCameraWithFront:(camera == 1) withBlock:^(TLBaseServiceErrorCode errorCode, BOOL isFrontCamera) {
        if (errorCode != TLBaseServiceErrorCodeSuccess || !self.remoteControlGranted || CALL_IS_TERMINATED([self.call status])) {
            return;
        }

        [self.call.callService onCameraSwitchDone:isFrontCamera];
        int activeCamera = [self.call frontCameraOn] ? 1 : 2;
        [self sendCameraResponseWithError:TLBaseServiceErrorCodeSuccess cameraBitmap:0x03 activeCamera:activeCamera minScale:1 maxScale:100];
    }];
}

- (void)onCameraResponseWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onCameraResponseWithIQ: %@", LOG_TAG, iq);
    
    if (!self.peerConnectionId) {
        return;
    }
    
    CameraResponseIQ *cameraResponseIQ = (CameraResponseIQ *)iq;
    if (cameraResponseIQ.errorCode != TLBaseServiceErrorCodeSuccess) {
        self.mainParticipant.remoteActiveCamera = 0;
        [self postWithEvent:CallParticipantEventCameraControlDenied];
        return;
    }

    if (cameraResponseIQ.cameraBitmap == 0) {
        self.mainParticipant.remoteActiveCamera = 0;
        [self postWithEvent:CallParticipantEventCameraControlDone];
        return;
    }
    self.mainParticipant.remoteActiveCamera = cameraResponseIQ.activeCamera;
    [self postWithEvent:CallParticipantEventCameraControlGranted];
}

@end
