/*
 *  Copyright (c) 2022-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>
#import <stdatomic.h>

#import <Twinlife/TLJobService.h>
#import <Twinlife/TLPeerCallService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLOriginator.h>
#import <Twinme/TLGroupMember.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLCallReceiver.h>

#import "CallService.h"
#import "CallState.h"
#import "CallConnection.h"
#import "CallParticipant.h"
#import "Streaming/Streamer.h"
#import "Streaming/StreamPlayer.h"

#if 0
static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define MAX_MEMBER_UI_SUPPORTED 8

//
// Interface: CallState ()
//

@interface CallState ()

@property (nonatomic) int state;
@property (nonatomic, readonly, nonnull) NSMutableArray<CallConnection *> *peers;
@property (nonatomic) int64_t lastStreamIdent;
@property (nonatomic) atomic_llong requestCounter;
/// Used for click-to-call group calls: if several participants start the call at the same time, the first one will be processed while the others will be added to this Set in handleIncomingCallDuringExistingCall().
/// If the call is accepted we resume them in onChangeConnectionState(). If the call is rejected they will be terminated.
@property (nonatomic, readonly, nonnull) NSMutableSet<CallConnection *> *incomingGroupCallConnections;
@property (nonatomic, readonly, nonnull) NSUUID *senderId;
@property (nonatomic) atomic_llong sequenceCounter;
@property (nonatomic, readonly, nonnull) NSMutableArray<TLDescriptor *> *descriptors;
@property (nonatomic) BOOL onHold;
@property (nonatomic, nullable) TLGeolocationDescriptor *geolocationDescriptor;
@property (nonatomic, nonnull) NSMutableSet<NSUUID *> *pendingPrepareTransfer;
///During a transfer, contains the new incoming connections initiated after receiving PrepareTransferIQ.
@property (nonatomic, nonnull) NSMutableSet<NSUUID *> *pendingCallRoomMembers;

@end

//
// Implementation: CallState
//

#undef LOG_TAG
#define LOG_TAG @"CallState"

@implementation CallState

- (nonnull instancetype)initWithOriginator:(nonnull id<TLOriginator>)originator callService:(nonnull CallService *)callService peerCallService:(nonnull TLPeerCallService *)peerCallService callKitUUID:(nullable NSUUID *)callKitUUID {
    DDLogInfo(@"%@ initWithOriginator: %@", LOG_TAG, originator);
    
    self = [super init];
    if (self) {
        _originator = originator;
        _originatorId = originator.uuid;
        _identityName = originator.identityName;
        _identityDescription = originator.identityDescription;
        _peers = [[NSMutableArray alloc] init];
        _peerCallService = peerCallService;
        _terminateReason = TLPeerConnectionServiceTerminateReasonUnknown;
        _zoomableByPeer = [originator.identityCapabilities zoomable];
        _state = 0;
        _maxMemberCount = MAX_MEMBER_UI_SUPPORTED;
        _callService = callService;
        _lastStreamIdent = 0;
        _requestCounter = 0;
        _sequenceCounter = 0;
        _callKitUUID = callKitUUID ? callKitUUID : [NSUUID UUID];
        _pendingCallRoomMembers = [[NSMutableSet alloc] init];
        _pendingPrepareTransfer = [[NSMutableSet alloc] init];
        _pendingChangeStateConnectionId = nil;
        _transferDirection = NONE;
        _incomingGroupCallConnections = [[NSMutableSet alloc] init];
        _senderId = [NSUUID UUID];
        _descriptors = [[NSMutableArray alloc] init];
        _onHold = NO;
        _audioSourceOn = YES;
        _videoSourceOn = NO;
        _frontCameraOn = YES;
        _uuid = [NSUUID UUID];
    }
    
    return self;
}

- (int)allocateParticipantId {
    return [self.callService allocateParticipantId];
}

- (int64_t)allocateRequestId {
    
    return atomic_fetch_add(&_requestCounter, 1);
}

- (nonnull TLDescriptorId *)newDescriptorId {
    
    int64_t sequenceId = atomic_fetch_add(&_sequenceCounter, 1);
    return [[TLDescriptorId alloc] initWithTwincodeOutboundId:self.senderId sequenceId:sequenceId];
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

- (nullable NSUUID *)twincodeOutboundId {
    DDLogVerbose(@"%@ twincodeOutboundId", LOG_TAG);

    return self.originator.twincodeOutboundId;
}

- (CallStatus)status {
    DDLogVerbose(@"%@ status", LOG_TAG);
    
    CallStatus result;
    @synchronized (self) {
        if (self.terminateReason != TLPeerConnectionServiceTerminateReasonUnknown) {
            result = CallStatusTerminated;
        } else if (self.peers.count == 0) {
            result = CallStatusTerminated;
        } else {
            BOOL allPeersOnHold = YES;
            CallStatus relevantStatus = [self.peers[0] callStatus];
            result = relevantStatus;
            for (CallConnection *connection in self.peers) {
                CallStatus status = [connection callStatus];
                if (CALL_IS_PEER_ON_HOLD(status)) {
                    continue;
                }
                allPeersOnHold = NO;
                if (CALL_IS_ACTIVE(status)) {
                    result = status;
                    break;
                }
                if (CALL_IS_ACCEPTED(status)) {
                    relevantStatus = status;
                }
            }
            if (allPeersOnHold) {
                result = relevantStatus | CALL_PEER_ON_HOLD;
            }
            if (self.onHold) {
                result |= CALL_ON_HOLD;
            }
        }
    }
    
    DDLogVerbose(@"%@ status: %d", LOG_TAG, result);
    
    return result;
}

- (void)setAudioVideoStateWithCallStatus:(CallStatus)status {
    switch (status) {
        case CallStatusOutgoingVideoBell:
            self.audioSourceOn = NO;
            self.videoSourceOn = YES;
            break;
            
        case CallStatusOutgoingCall:
        case CallStatusIncomingCall:
        case CallStatusAcceptedIncomingCall:
            self.audioSourceOn = YES;
            self.videoSourceOn = NO;
            break;
        
        case CallStatusOutgoingVideoCall:
        case CallStatusIncomingVideoCall:
        case CallStatusAcceptedIncomingVideoCall:
            self.audioSourceOn = YES;
            self.videoSourceOn = YES;
            break;
            
        case CallStatusIncomingVideoBell:
        default:
            self.audioSourceOn = NO;
            self.videoSourceOn = NO;
            break;
    }
}

- (BOOL)isVideo {
    
    return CALL_IS_VIDEO([self status]);
}


- (BOOL)isOneOnOneVideoCall {
    
    @synchronized (self) {
        return self.peers.count == 1 && self.videoSourceOn && !self.peers[0].mainParticipant.isVideoMute;
    }
}

- (BOOL)isGroupCall {
    
    BOOL result;
    @synchronized (self) {
        result = self.callRoomId != nil || self.peers.count > 1;
    }
    
    DDLogVerbose(@"%@ isGroupCall: %d", LOG_TAG, result);
    
    return result;
}

- (BOOL)isCallWithGroupMember:(nonnull id<TLOriginator>)originator {
    
    // If we receive the incoming call from PushKit, we get a TLGroup object.
    // But, if we receive it from the complete incoming P2P flow, we have identified the TLGroupMember.
    BOOL isGroup = (self.originator == originator
     || ([originator isKindOfClass:[TLGroupMember class]] && self.originator == ((TLGroupMember *)originator).group));
    return isGroup;
}

- (nonnull CallEventMessage *)eventMessage {
    
    CallStatus callStatus;
    TLPeerConnectionServiceConnectionState state;
    @synchronized (self) {
        if (self.peers.count == 0) {
            callStatus = CallStatusTerminated;
            state = TLPeerConnectionServiceConnectionStateChecking;
        } else {
            CallConnection *callConnection = self.peers[0];
            callStatus = self.status;
            state = callConnection.connectionState;
        }
    }
    
    return [[CallEventMessage alloc] initWithCallId:self.uuid callStatus:callStatus state:state];
}

- (BOOL)hasConnectionWithCallMemberId:(nonnull NSString *)callMemberId {
    DDLogVerbose(@"%@ getConnections", LOG_TAG);
    
    @synchronized (self) {
        for (CallConnection *connection in self.peers) {
            if ([callMemberId isEqual:connection.callRoomMemberId]) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (nonnull NSArray<CallConnection *> *)getConnections {
    DDLogVerbose(@"%@ getConnections", LOG_TAG);
    
    NSArray<CallConnection *> *result;
    @synchronized (self) {
        result = [[NSArray alloc] initWithArray:self.peers];
    }
    
    return result;
}

- (nonnull NSArray<TLPeerSessionInfo *> *)getConnectionIds {

    NSMutableArray<TLPeerSessionInfo *> *result;
    @synchronized (self) {
        result = [[NSMutableArray alloc] init];
        
        for (CallConnection *connection in self.peers) {
            NSUUID *peerConnectionId = connection.peerConnectionId;
            if (peerConnectionId) {
                NSString *peerId = connection.callRoomMemberId;
                if (!peerId) {
                    NSUUID *twincodeOut = connection.peerTwincodeOutboundId;
                    if (twincodeOut) {
                        peerId = [twincodeOut toString];
                    }
                }
                [result addObject:[[TLPeerSessionInfo alloc] initWithSessionId:peerConnectionId peerId:peerId]];
            }
        }
    }
    return result;
}

- (void)clearConnections {
    @synchronized (self) {
        [self.peers removeAllObjects];
    }
}

- (nonnull NSArray<CallParticipant *> *)getParticipants {
    DDLogVerbose(@"%@ getParticipants", LOG_TAG);
    
    NSMutableArray<CallParticipant *> *result = [[NSMutableArray alloc] init];
    @synchronized (self) {
        for (CallConnection *connection in self.peers) {
            // Connection in pendingPrepareTransfer => it's either the transfer target, or another participant who joined the call during the transfer process.
            // We don't want to display them until we know which connection is the transfer target
            // (otherwise we'll briefly see both the transferred participant and the transfer target as separate participants)
            if (![self.pendingCallRoomMembers containsObject:connection.peerConnectionId]) {
                [connection appendParticipantsWithList:result];
            }
        }
    }
    return result;
}

- (nullable CallConnection *)initialConnection {
    DDLogVerbose(@"%@ initialConnection", LOG_TAG);
    
    CallConnection *callConnection;
    @synchronized (self) {
        if (self.peers.count == 0) {
            callConnection = nil;
        } else {
            callConnection = self.peers[0];
        }
    }
    
    return callConnection;
}

- (nullable CallParticipant *)mainParticipant {
    DDLogVerbose(@"%@ mainParticipant", LOG_TAG);
    
    CallConnection *callConnection;
    @synchronized (self) {
        if (self.peers.count == 0) {
            return nil;
        } else {
            callConnection = self.peers[0];
            
            return [callConnection mainParticipant];
        }
    }
}

- (nullable TLGeolocationDescriptor *)currentGeolocation {
    
    return self.geolocationDescriptor;
}

- (void)addPeerWithConnection:(nonnull CallConnection *)connection {
    DDLogVerbose(@"%@ addPeerWithConnection: %@", LOG_TAG, connection);
    
    @synchronized (self) {
        [self.peers addObject:connection];
        
        if (self.transferFromConnection) {
            // We've received a PrepareTransferIQ from the transferred participant
            // => this new incoming connection is likely from the transfer target,
            // but it could also be a new participant joining the call at the same time.
            // We don't want to display the transfer target as a new participant, it should seamlessly replace the transferred participant.
            // So we have to wait until we receive the ParticipantTransferIQ (which identifies the transfer target) from the transferred participant.
            
            if (!self.transferToMemberId) {
                // We haven't received the ParticipantTransferIQ yet.
                // Connections in pendingCallRoomMembers are ignored by the ViewController (see CallState.getParticipants).
                [self.pendingCallRoomMembers addObject:connection.peerConnectionId];
            } else if ([self.transferToMemberId isEqualToString:connection.callRoomMemberId]) {
                // We've received a ParticipantTransferIQ from the transferred participant,
                // and this is the transfer target's connection => perform the transfer
                [self performTransferWithParticipant:connection.mainParticipant];
            }
        }
    }
}

- (BOOL)removeWithConnection:(nonnull CallConnection *)connection terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ removeWithConnection: %@", LOG_TAG, connection);
    
    @synchronized (self) {
        [self.peers removeObject:connection];
        if (self.peers.count == 0) {
            self.terminateReason = terminateReason;
        }
        return self.peers.count == 0;
    }
}

- (CallConnectionUpdateState)updateConnectionWithConnection:(nonnull CallConnection *)connection state:(TLPeerConnectionServiceConnectionState)state {
    DDLogVerbose(@"%@ updateConnectionWithConnection: %@ state: %ld", LOG_TAG, connection, (long)state);
    
    @synchronized (self) {
        // Keep the call status before updating the state because it may change.
        CallStatus status = [connection status];
        if (![connection updateConnectionWithState:state]) {
            
            return CallConnectionUpdateStateIgnore;
        }
        
        if (self.connectionStartTime != 0) {
            if (self.peers.count == 1) {
                
                return CallConnectionUpdateStateIgnore;
            }
            
            if (self.callRoomId == nil) {
                
                return CallConnectionUpdateStateFirstGroup;
            }
            
            return CallConnectionUpdateStateNewConnection;
        }
        
        if (!CALL_IS_ACCEPTED(status) && !CALL_IS_OUTGOING(status)) {
            
            return CallConnectionUpdateStateIgnore;
        }
        
        // Call is accepted and we are connected for the first time.
        self.connectionStartTime = connection.startTime;
        self.peerConnected = YES;
        return CallConnectionUpdateStateFirstConnection;
    }
}

- (void)createCallRoomWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ createCallRoomWithRequestId: %lld", LOG_TAG, requestId);
    
    NSMutableDictionary<NSString *, NSUUID *> *members = [[NSMutableDictionary alloc] init];
    @synchronized (self) {
        for (CallConnection *peer in self.peers) {
            NSUUID *peerTwincodeOutboundId = peer.peerTwincodeOutboundId;
            NSUUID *sessionId = peer.peerConnectionId;
            CallGroupSupport groupSupport = [peer isGroupSupported];
            
            if (sessionId && peerTwincodeOutboundId && groupSupport != CallGroupSupportNo) {
                [members setObject:sessionId forKey:peerTwincodeOutboundId.UUIDString];

                // This member is invited as part of the CallRoom creation (no need for a call to inviteCallRoom).
                peer.invited = YES;
            }
        }
    }
    
    [self.peerCallService createCallRoomWithRequestId:requestId twincodeOutboundId:self.twincodeOutboundId members:members];
}

- (void)inviteCallRoomWithRequestId:(int64_t)requestId connection:(nonnull CallConnection *)connection {
    DDLogVerbose(@"%@ createCallRoomWithRequestId: %lld", LOG_TAG, requestId);
    
    NSUUID *twincodeOutboundId = connection.peerTwincodeOutboundId;
    if (!twincodeOutboundId || !self.callRoomId || [connection isGroupSupported] != CallGroupSupportYes) {
        return;
    }
    
    [self.peerCallService inviteCallRoomWithRequestId:requestId callRoomId:self.callRoomId twincodeOutboundId:twincodeOutboundId p2pSessionId:connection.peerConnectionId];
    
}

- (void)joinCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId mode:(int)mode maxMemberCount:(int)maxMemberCount {
    DDLogVerbose(@"%@ joinCallRoomWithRequestId: %lld callRoomId: %@ mode: %d maxMemberCount: %d", LOG_TAG, requestId, callRoomId, mode, maxMemberCount);
    
    @synchronized (self) {
        self.state |= CREATE_CALL_ROOM | CREATE_CALL_ROOM_DONE;
        self.callRoomId = callRoomId;
        self.maxMemberCount = MIN(maxMemberCount, MAX_MEMBER_UI_SUPPORTED);
    }
    
    [self.peerCallService joinCallRoomWithRequestId:requestId callRoomId:callRoomId twincodeInboundId:self.originator.twincodeInboundId p2pSessionIds:[self getConnectionIds]];
}

- (void)joinWithCallRoomId:(nonnull NSUUID *)callRoomId maxMemberCount:(int)maxMemberCount {
    DDLogVerbose(@"%@ joinWithCallRoomId: %@ maxMemberCount: %d", LOG_TAG, callRoomId, maxMemberCount);

    @synchronized (self) {
        self.state |= CREATE_CALL_ROOM | CREATE_CALL_ROOM_DONE;
        self.callRoomId = callRoomId;
        self.maxMemberCount = MIN(maxMemberCount, MAX_MEMBER_UI_SUPPORTED);
    }
}

- (void)updateCallRoomWithId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId mode:(int)mode maxMemberCount:(int)maxMemberCount {
    DDLogVerbose(@"%@ updateCallRoomWithId: %@ memberId: %@ mode: %d maxMemberCount: %d", LOG_TAG, callRoomId, memberId, mode, maxMemberCount);
    
    @synchronized (self) {
        self.state |= CREATE_CALL_ROOM | CREATE_CALL_ROOM_DONE;
        self.callRoomId = callRoomId;
        self.callRoomMemberId = memberId;
        self.maxMemberCount = MIN(maxMemberCount, MAX_MEMBER_UI_SUPPORTED);
    }
}

- (void)leaveCallRoomWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ leaveCallRoomWithRequestId: %lld", LOG_TAG, requestId);
    
    [self.peerCallService leaveCallRoomWithRequestId:requestId callRoomId:self.callRoomId memberId:self.callRoomMemberId];
}

- (void)updateCallRoomWithMemberId:(nonnull NSString *)memberId {
    DDLogVerbose(@"%@ updateCallRoomWithMemberId: %@", LOG_TAG, memberId);
    
    @synchronized (self) {
        self.callRoomMemberId = memberId;
    }
}

- (void)sendMessage {
    
    [self.callService sendMessageWithCall:self message:CallEventMessageConnectionState];
}

- (BOOL)startStreamingWithMediaItem:(nonnull MPMediaItem *)mediaItem {
    DDLogVerbose(@"%@ startStreamingWithMediaItem: %@", LOG_TAG, mediaItem);
    
    Streamer *oldStreamer;
    Streamer *newStreamer;
    @synchronized (self) {
        self.lastStreamIdent++;
        oldStreamer = self.currentStreamer;
        self.currentStreamer = newStreamer = [[Streamer alloc] initWithCall:self ident:self.lastStreamIdent mediaItem:mediaItem];
    }
    if (oldStreamer) {
        [oldStreamer stopStreamingWithNotify:YES];
    }
    
    [newStreamer startStreaming];
    return YES;
}

- (void)stopStreaming {
    DDLogVerbose(@"%@ stopStreaming", LOG_TAG);
    
    if (self.currentStreamer) {
        [self.currentStreamer stopStreamingWithNotify:YES];
        self.currentStreamer = nil;
    }
}

- (void)onStreamingEventWithParticipant:(nullable CallParticipant *)participant event:(StreamingEvent)event {
    DDLogVerbose(@"%@ onStreamingEventWithParticipant: %@ event: %d", LOG_TAG, participant, event);
    
    id<CallParticipantDelegate> observer = [self.callService callParticipantDelegate];
    if (observer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [observer onStreamingEventWithParticipant:participant event:event];
        });
    }
}

- (void)onPopDescriptorWithParticipant:(nonnull CallParticipant *)participant descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopDescriptorWithParticipant: %@ descriptor: %@", LOG_TAG, participant, descriptor);
    
    id<CallParticipantDelegate> observer = [self.callService callParticipantDelegate];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.descriptors addObject:descriptor];
        if (observer) {
            [observer onPopDescriptorWithParticipant:participant descriptor:descriptor];
        }
    });
}

- (void)onUpdateGeolocationWithParticipant:(nonnull CallParticipant *)participant descriptor:(nonnull TLGeolocationDescriptor *)descriptor {
    DDLogVerbose(@"%@ onUpdateGeolocationWithParticipant: %@ descriptor: %@", LOG_TAG, participant, descriptor);
    
    id<CallParticipantDelegate> observer = [self.callService callParticipantDelegate];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (observer) {
            [observer onUpdateGeolocationWithParticipant:participant descriptor:descriptor];
        }
    });
}

- (void)onDeleteDescriptorWithParticipant:(nonnull CallParticipant *)participant descriptorId:(nonnull TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ onDeleteDescriptorWithParticipant: %@ descriptorId: %@", LOG_TAG, participant, descriptorId);
    
    id<CallParticipantDelegate> observer = [self.callService callParticipantDelegate];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (observer) {
            [observer onDeleteDescriptorWithParticipant:participant descriptorId:descriptorId];
        }
    });
}

- (void)sendPrepareTransfer {
    DDLogVerbose(@"%@ sendPrepareTransfer", LOG_TAG);

    // We're the participant which will be transferred,
    // and the connection with the transfer target is established ->
    // send PrepareTransferIQ to other participant(s)
    for (CallConnection *conn in [self getConnections]) {
        if ([conn isTransferConnection] != TransferConnectionYes) {
            [conn sendPrepareTransferIQ];
            @synchronized (self) {
                [self.pendingPrepareTransfer addObject:conn.peerConnectionId];
            }
        }
    }
}

- (BOOL)isTransferReady {
    
    @synchronized (self) {
        return self.pendingPrepareTransfer.count == 0;
    }
}

- (BOOL)performTransferWithParticipant:(CallParticipant *)transferTarget {
    DDLogVerbose(@"%@ performTransferWithParticipant: %@", LOG_TAG, transferTarget);
    
    if(!self.transferFromConnection){
        return NO;
    }

    NSString *transferToMemberId = self.transferFromConnection.transferToMemberId;
    
    if(transferToMemberId && [transferToMemberId isEqualToString:transferTarget.memberId]){
        [transferTarget transferWithParticipant: self.transferFromConnection.mainParticipant];
        self.transferFromConnection.transferToMemberId = nil;
        self.transferFromConnection = nil;
        self.transferToMemberId = nil;
        
        id<CallParticipantDelegate> observer = [self.callService callParticipantDelegate];
        if (observer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [observer onEventWithParticipant:transferTarget event:CallParticipantEventIdentity];
            });
        }
        
        return YES;
    }
    
    return NO;
}

- (void)onOnPrepareTransferWithConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ onOnPrepareTransferWithConnectionId: %@", LOG_TAG, peerConnectionId.UUIDString);
    
    bool allDone;
    @synchronized (self) {
        [self.pendingPrepareTransfer removeObject:peerConnectionId];
        allDone = self.pendingPrepareTransfer.count == 0;
    }

    if (allDone && self.pendingChangeStateConnectionId) {
        // onChangeConnectionStateWithConnection was already called once with state == Connected,
        // but we were still waiting on ACKs from existing call participants.
        // Now they're all aware a transfer is in progress, and they will handle the transfer target participant properly =>
        // invite the transfer target to the call room.

        CallConnection *connection = [self getConnectionWithId:self.pendingChangeStateConnectionId];
        if (!connection) {
            return;
        }

        [self.callService onChangeConnectionStateWithConnection:connection state:TLPeerConnectionServiceConnectionStateConnected];
        self.pendingChangeStateConnectionId = nil;
    }
}

- (void)onParticipantTransferWithMemberId:(nonnull NSString *)memberId {
    DDLogVerbose(@"%@ onParticipantTransferWithMemberId: %@", LOG_TAG, memberId);
    
    CallParticipant *transferTarget;
    @synchronized (self) {
        self.transferToMemberId = memberId;
        [self.pendingCallRoomMembers removeAllObjects];
        
        for (CallConnection *connection in self.peers) {
            if (connection.callRoomMemberId && [connection.callRoomMemberId isEqualToString:memberId]) {
                transferTarget = connection.mainParticipant;
                break;
            }
        }
    }
    
    [self performTransferWithParticipant:transferTarget];
}

- (void)onTransferDone {
    DDLogVerbose(@"%@ onTransferDone", LOG_TAG);

    [self.peerCallService transferDone];
}

- (void)onAudioPlayerDidFinishPlaying:(nonnull NSNotification *)notification {
    DDLogVerbose(@"%@ onAudioPlayerDidFinishPlaying", LOG_TAG);

    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"audioPlayerDidFinishPlaying" object:nil];

    [self.callService finishWithCall:self];
}

- (nullable CallConnection *)getConnectionWithId:(nonnull NSUUID *)connectionId {
    @synchronized (self) {
        for (CallConnection *connection in self.peers) {
            if ([connection.peerConnectionId isEqual:connectionId]) {
                return connection;
            }
        }
    }
    return nil;
}

- (TransferDirection)getTransferDirection {
    
    return self.transferDirection;
}

- (BOOL)sendWithDescriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ sendWithDescriptor: %@", LOG_TAG, descriptor);

    [self.descriptors addObject:descriptor];
    BOOL sent = false;
    BOOL isGeoloc = [descriptor getType] == TLDescriptorTypeGeolocationDescriptor;
    for (CallConnection *callConnection in [self getConnections]) {
        if (isGeoloc) {
            if ([callConnection isGeolocationSupported] == CallGeolocationSupportYes) {
                sent |= [callConnection sendWithDescriptor:descriptor];
            }
        } else {
            if ([callConnection isMessageSupported] == CallMessageSupportYes) {
                sent |= [callConnection sendWithDescriptor:descriptor];
            }
        }
    }
    return sent;
}

- (BOOL)sendGeolocation:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta {
    DDLogVerbose(@"%@ sendGeolocation: %f", LOG_TAG, longitude);

    if (!self.geolocationDescriptor) {
        self.geolocationDescriptor = [self createWithLongitude:longitude latitude:latitude altitude:altitude mapLongitudeDelta:mapLongitudeDelta mapLatitudeDelta:mapLatitudeDelta replyTo:nil copyAllowed:YES];
        return [self sendWithDescriptor:self.geolocationDescriptor];
    }

    BOOL sent = false;
    for (CallConnection *callConnection in [self getConnections]) {
        if ([callConnection isGeolocationSupported] == CallGeolocationSupportYes) {
            sent |= [callConnection updateWithDescriptor:self.geolocationDescriptor longitude:longitude latitude:latitude altitude:altitude mapLongitudeDelta:mapLongitudeDelta mapLatitudeDelta:mapLatitudeDelta];
        }
    }
    return sent;
}

- (BOOL)deleteGeolocation {
    DDLogVerbose(@"%@ deleteGeolocation", LOG_TAG);

    if (!self.geolocationDescriptor) {
        return NO;
    }

    BOOL sent = false;
    for (CallConnection *callConnection in [self getConnections]) {
        if ([callConnection isGeolocationSupported] == CallGeolocationSupportYes) {
            sent |= [callConnection deleteWithDescriptor:self.geolocationDescriptor];
        }
    }
    self.geolocationDescriptor = nil;
    return sent;
}

- (void)markReadWithDescriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ markReadWithDescriptor: %@", LOG_TAG, descriptor);

    [TLConversationHandler markReadWithDescriptor:descriptor];
}

- (nonnull NSArray<TLDescriptor *> *)getDescriptors {
    DDLogVerbose(@"%@ getDescriptors: %ld", LOG_TAG, self.descriptors.count);

    return self.descriptors;
}

- (BOOL)isPeerDescriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ isPeerDescriptor: %@", LOG_TAG, descriptor);
    
    return ![descriptor isTwincodeOutbound:self.senderId];
}

#pragma mark - Private

- (BOOL)isPeerTransferring {
    return self.transferFromConnection != nil;
}
/// true if the new participant is allowed to automatically join the active call.
- (BOOL)autoAcceptNewParticipantWithOriginator:(nonnull id<TLOriginator>)newParticipant {
    
    // This is an incoming call for a transfer.
    if ([newParticipant class] == [TLCallReceiver class]) {
        TLCallReceiver *callReceiver = (TLCallReceiver *)newParticipant;
        if (callReceiver.isTransfer) {
            return YES;
        }
    }

    id<TLOriginator> originator = self.originator;
    if (!originator) {
        return NO;
    }

    // We're in a Call Receiver call-room, and a new participant is (re-)joining
    if ([originator class] == [TLCallReceiver class]) {
        if ([originator isGroup] && [originator.uuid isEqual:newParticipant.uuid]) {
            return YES;
        }
        return NO;
    }
    
    // We're in a Group call-room, and a member is (re-)joining
    if ([originator class] == [TLGroup class]) {
        NSUUID *groupId = nil;
        
        if ([newParticipant class] == [TLGroupMember class]) {
            groupId = ((TLGroupMember *)newParticipant).group.uuid;
        }
        
        return [((TLGroup *)originator).uuid isEqual:groupId];
    }
    return NO;
}

- (void)addIncomingGroupCallConnectionWithConnection:(nonnull CallConnection *)connection {
    @synchronized (self.incomingGroupCallConnections) {
        [self.incomingGroupCallConnections addObject:connection];
    }
}

- (nonnull NSSet<CallConnection *> *)getIncomingGroupCallConnections {
    NSSet<CallConnection *> *res;
    @synchronized (self.incomingGroupCallConnections) {
        res = [[NSSet alloc] initWithSet:self.incomingGroupCallConnections];
        [self.incomingGroupCallConnections removeAllObjects];
    }
    return res;
}

- (void)putOnHold {
    @synchronized (self) {
        if (self.onHold) {
            return;
        }
        
        for (CallConnection *connection in self.peers) {
            [connection putOnHold];
            [connection sendHoldCallIQ];
        }
        
        if (self.currentStreamer.localPlayer && !self.currentStreamer.localPlayer.paused){
            [self.currentStreamer pauseStreaming];
        }
        
        self.onHold = YES;
    }
}

- (void)resume {
    @synchronized (self) {
        if (!self.onHold) {
            return;
        }
        
        for (CallConnection *connection in self.peers) {
            [connection resume];
            [connection sendResumeCallIQ];
        }
        
        self.onHold = NO;
    }
}

- (void)onPeerHoldCallWithConnectionId:(nonnull NSUUID *)connectionId {
    [self.callService onPeerHoldCallWithConnectionId:connectionId];
}

- (void)onPeerResumeCallWithConnectionId:(nonnull NSUUID *)connectionId {
    [self.callService onPeerResumeCallWithConnectionId:connectionId];
}

- (void)onPeerKeyCheckInitiateWithConnectionId:(nonnull NSUUID *)connectionId locale:(nonnull NSLocale *)locale {
    [self.callService onPeerKeyCheckInitiateWithConnectionId:connectionId locale:locale];
}

- (void)onOnKeyCheckInitiateWithConnectionId:(nonnull NSUUID *)connectionId errorCode:(TLBaseServiceErrorCode)errorCode {
    [self.callService onOnKeyCheckInitiateWithConnectionId:connectionId errorCode:errorCode];
}

- (void)onPeerWordCheckResultWithConnectionId:(nonnull NSUUID *)connectionId wordCheckResult:(nonnull WordCheckResult *)wordCheckResult {
    [self.callService onPeerWordCheckResultWithConnectionId:connectionId wordCheckResult:wordCheckResult];
}

- (void)onTerminateKeyCheckWithConnectionId:(nonnull NSUUID *)connectionId result:(BOOL)result {
    [self.callService onTerminateKeyCheckWithConnectionId:connectionId result:result];
}

- (void)onTwincodeURIWithConnectionId:(nonnull NSUUID *)connectionId uri:(nonnull NSString *)uri {
    [self.callService onTwincodeURIWithConnectionId:connectionId uri:uri];
}

@end
