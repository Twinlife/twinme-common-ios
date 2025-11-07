/*
 *  Copyright (c) 2022-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Twinlife/TLPeerConnectionService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinme/TLCapabilities.h>

#import "CallStatus.h"

typedef enum {
    // No transfer is currently taking place.
    NONE=0,
    // The call is being transferred from this device to the browser.
    TO_BROWSER=1,
    // The call is being transferred from the browser to this device.
    TO_DEVICE=2
} TransferDirection;


@protocol RTC_OBJC_TYPE(RTCVideoRenderer);
@class TLPeerConnectionService;
@class TLPeerCallService;
@protocol TLOriginator;
@class CallService;
@class CallParticipant;
@class CallConnection;
@class CallEventMessage;
@class Streamer;
@class TLDescriptorId;
@class MPMediaItem;
@class TLGeolocationDescriptor;
@class WordCheckResult;
@class TLPeerSessionInfo;

#define CREATE_CALL_ROOM                   (1 << 10)
#define CREATE_CALL_ROOM_DONE              (1 << 11)

/**
 * The call state associated with an Audio or Video call:
 *
 * - the audio/video call can have one or several P2P connections (P2P group call)
 * - it can have one or several participants (group call)
 *
 * Each P2P connection and participant are maintained separately:
 *
 * - we could have a 1-1 mapping between P2P connection and Participant
 * - we could have a 1-N mapping when the P2P connection is using an SFU as the peer
 *   and we can get several participant for the same P2P connection.
 *
 * When the call is a group call, we have:
 *
 * - a call room identifier,
 * - a member identifier that identifies us within the call room,
 * - the call room configuration (max number of participants, call room options),
 * - a list of member identifiers that participate in the call room (each identifier is a String).
 */
@interface CallState : TLDescriptorFactory;

@property (nonatomic, readonly, nonnull) CallService *callService;
@property (nonatomic, readonly, nonnull) NSUUID *uuid;
@property (nonatomic, readonly, nonnull) NSUUID *originatorId;
@property (nonatomic, readonly, nonnull) id<TLOriginator> originator;
@property (nonatomic, readonly, nonnull) TLPeerCallService *peerCallService;
@property (nonatomic, readonly, nonnull) NSString *identityName;
@property (nonatomic, readonly, nullable) NSString *identityDescription;
@property (nonatomic, readonly) TLVideoZoomable zoomableByPeer;
@property (nonatomic, nullable) UIImage *identityAvatar;
@property (nonatomic, nullable) UIImage *groupAvatar;
@property (nonatomic, readonly, nonnull) NSUUID *callKitUUID;
@property (nonatomic, nullable) NSUUID *callRoomId;
@property (nonatomic, nullable) NSString *callRoomMemberId;
@property (nonatomic, nullable) TLDescriptorId *descriptorId;
@property (nonatomic) int64_t connectionStartTime;
@property (nonatomic) int maxMemberCount;
@property (nonatomic) BOOL peerConnected;
@property (nonatomic) TLPeerConnectionServiceTerminateReason terminateReason;
@property (nonatomic, nullable) Streamer *currentStreamer;

@property (nonatomic, nullable) CallConnection *transferFromConnection;
@property (nonatomic, nullable) NSString *transferToMemberId;
@property (nonatomic, nullable) NSUUID *pendingChangeStateConnectionId;
@property (nonatomic) TransferDirection transferDirection;
@property (nonatomic) BOOL audioSourceOn;
@property (nonatomic) BOOL videoSourceOn;
@property (nonatomic) BOOL frontCameraOn;

/// Create a new call with the originator.
- (nonnull instancetype)initWithOriginator:(nonnull id<TLOriginator>)originator callService:(nonnull CallService *)callService peerCallService:(nonnull TLPeerCallService *)peerCallService callKitUUID:(nullable NSUUID *)callKitUUID;

/// Allocate a unique participant id to identify a participant.
- (int)allocateParticipantId;

/// Allocate a unique requestId for an IQ.
- (int64_t)allocateRequestId;

/// Test and set the operation.  Returns YES if the operation must be performed.
- (BOOL)checkOperation:(int)operation;

/// Returns true if the operation was completed.
- (BOOL)isDoneOperation:(int)operation;

/// Get the twincode outbound id used to make the P2P connection.
- (nullable NSUUID *)twincodeOutboundId;

/// Get the current call status.
- (CallStatus)status;

- (void)setAudioVideoStateWithCallStatus:(CallStatus)status;

/// Returns YES if this call is a video call.
- (BOOL)isVideo;

/// Returns YES if this call is not a group call, and both participants have their video enabled.
- (BOOL)isOneOnOneVideoCall;

/// Returns YES if this call is a group call.  The call is changed to a group call when a first participant is added.
- (BOOL)isGroupCall;

/// Returns YES if the originator matches the current call for a group or for a group member.
- (BOOL)isCallWithGroupMember:(nonnull id<TLOriginator>)originator;

/// Build an event message with the call status.
- (nonnull CallEventMessage *)eventMessage;

/// The current primary call connection.
- (nullable CallConnection *)initialConnection;

/// Get the list of current P2P connections associated with this audio/video call.
- (nonnull NSArray<CallConnection *> *)getConnections;

/// Get the list of current P2P connection IDs associated with this audio/video call.
- (nonnull NSArray<TLPeerSessionInfo *> *)getConnectionIds;

/// Check if we already have a peer connection to the given call room member.
- (BOOL)hasConnectionWithCallMemberId:(nonnull NSString *)callMemberId;

/// Removes all P2P connections associated with this audio/video call. Used during call merging, to leave the P2P connections intact when terminating the merged call.
- (void)clearConnections;

/// Get the list of call participants.
- (nonnull NSArray<CallParticipant *> *)getParticipants;

/// Get the main participant.
- (nullable CallParticipant *)mainParticipant;

- (nullable TLGeolocationDescriptor *)currentGeolocation;

/// Add a new peer connection to the call.
- (void)addPeerWithConnection:(nonnull CallConnection *)connection;

/// Update the connection state.  Returns the update state of this connection.
- (CallConnectionUpdateState)updateConnectionWithConnection:(nonnull CallConnection *)connection state:(TLPeerConnectionServiceConnectionState)state;

/// Remove the peer connection and release the resources allocated for it (remote renderer).
/// Returns YES if the call has no peer connection.
- (BOOL)removeWithConnection:(nonnull CallConnection *)connection terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

/// Create the call room by using the PeerCallService and sending to the server the list of members with their current P2P session ids.
- (void)createCallRoomWithRequestId:(int64_t)requestId;

/// Invite the member for which we have a new call connection to participate in the call group.
/// This sends an invitation to join and when the peer accepts the invitation it will get other
/// member information to setup P2P sessions with them.
- (void)inviteCallRoomWithRequestId:(int64_t)requestId connection:(nonnull CallConnection *)connection;

/// Join the call room after we have received an invitation.
- (void)joinCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId mode:(int)mode maxMemberCount:(int)maxMemberCount;

/// Prepare to join the call room.  We only record the call room id so that we can join the call room when the incoming call is accepted.
- (void)joinWithCallRoomId:(nonnull NSUUID *)callRoomId maxMemberCount:(int)maxMemberCount;

/// Prepare the call when the call room id is created and given by the server.
- (void)updateCallRoomWithId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId mode:(int)mode maxMemberCount:(int)maxMemberCount;

/// Leave the call room by sending a leave request on the server.
- (void)leaveCallRoomWithRequestId:(int64_t)requestId;

/// Update the call room setup to indicate our member id once we have joined the call room.
- (void)updateCallRoomWithMemberId:(nonnull NSString *)memberId;

- (void)sendMessage;

/// Start streaming a content defined by the media item.
/// Returns YES if the streaming started and NO if there was some problem.
- (BOOL)startStreamingWithMediaItem:(nonnull MPMediaItem *)mediaItem;

/// Stop streaming content, notify the peers to stop their player and release all resources.
- (void)stopStreaming;

/// An event occurred on the streamer.
- (void)onStreamingEventWithParticipant:(nullable CallParticipant *)participent event:(StreamingEvent)event;

- (void)onPopDescriptorWithParticipant:(nonnull CallParticipant *)participant descriptor:(nonnull TLDescriptor *)descriptor;

- (void)onUpdateGeolocationWithParticipant:(nonnull CallParticipant *)participant descriptor:(nonnull TLGeolocationDescriptor *)descriptor;

- (void)onDeleteDescriptorWithParticipant:(nonnull CallParticipant *)participant descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (BOOL)performTransferWithParticipant:(nonnull CallParticipant *)transferTarget;

- (void)onOnPrepareTransferWithConnectionId:(nonnull NSUUID *)peerConnectionId;

- (void)onParticipantTransferWithMemberId:(nonnull NSString *) memberId;

/// Send the prepare transfer IQ to connected members to initiate the transfer.
- (void)sendPrepareTransfer;

- (BOOL)isTransferReady;

- (void)onTransferDone;

- (void)onAudioPlayerDidFinishPlaying:(nonnull NSNotification *)notification;

- (nullable CallConnection *)getConnectionWithId:(nonnull NSUUID *)connectionId;

- (BOOL)isPeerTransferring;

- (TransferDirection)getTransferDirection;

- (BOOL)autoAcceptNewParticipantWithOriginator:(nonnull id<TLOriginator>)newParticipant;

- (void)addIncomingGroupCallConnectionWithConnection:(nonnull CallConnection *)connection;

- (nonnull NSSet<CallConnection *> *)getIncomingGroupCallConnections;

/// Send the descriptor to the connected participants if they support receiving a descriptor.
/// It must be called from the main UI thread only.
- (BOOL)sendWithDescriptor:(nonnull TLDescriptor *)descriptor;

/// Send the geolocation to the connected participants if they support receiving a geolocation.
/// It must be called from the main UI thread only.  The first call creates the Geolocation description
/// and other calls will update it until deleteGeolocation() is called.
- (BOOL)sendGeolocation:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta;

/// Delete the geolocation if there was one.
- (BOOL)deleteGeolocation;

/// Mark the descriptor read.
- (void)markReadWithDescriptor:(nonnull TLDescriptor *)descriptor;

/// Get the list of descriptors received and sent.
/// It must be called from the main UI thread only.
- (nonnull NSArray<TLDescriptor *> *)getDescriptors;

- (BOOL)isPeerDescriptor:(nonnull TLDescriptor *)descriptor;

- (void)putOnHold;

- (void)resume;

- (void)onPeerHoldCallWithConnectionId:(nonnull NSUUID *)connectionId;

- (void)onPeerResumeCallWithConnectionId:(nonnull NSUUID *)connectionId;

/// Key check
- (void)onPeerKeyCheckInitiateWithConnectionId:(nonnull NSUUID *)connectionId locale:(nonnull NSLocale *)locale;

- (void)onOnKeyCheckInitiateWithConnectionId:(nonnull NSUUID *)connectionId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onPeerWordCheckResultWithConnectionId:(nonnull NSUUID *)connectionId wordCheckResult:(nonnull WordCheckResult *)wordCheckResult;

- (void)onTerminateKeyCheckWithConnectionId:(nonnull NSUUID *)connectionId result:(BOOL)result;

- (void)onTwincodeURIWithConnectionId:(nonnull NSUUID *)connectionId uri:(nonnull NSString *)uri;

@end
