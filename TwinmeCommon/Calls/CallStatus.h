/*
 *  Copyright (c) 2022-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#define CALL_INCOMING       0x01
#define CALL_OUTGOING       0x02
#define CALL_VIDEO          0x04
#define CALL_ACCEPTED       0x08
#define CALL_ACTIVE         0x10
#define CALL_BELL           0x20
#define CALL_TERMINATED     0x40
#define CALL_PEER_ON_HOLD   0x80
#define CALL_ON_HOLD        0x100

typedef enum {
    // No Audio/Video call (we are ready to make calls).
    CallStatusNone = 0,

    // An incoming Audio call (not yet accepted).
    CallStatusIncomingCall = CALL_INCOMING,

    // An incoming Video call (not yet accepted).
    CallStatusIncomingVideoCall = CALL_INCOMING | CALL_VIDEO,

    // Incoming video bell and we are receiving the video track.
    CallStatusIncomingVideoBell = CALL_INCOMING | CALL_BELL,

    // An outgoing Audio call (not yet accepted).
    CallStatusOutgoingCall = CALL_OUTGOING,

    // An outgoing Video call (not yet accepted).
    CallStatusOutgoingVideoCall = CALL_OUTGOING | CALL_VIDEO,

    // An outgoing Video bell (not yet accepted).
    CallStatusOutgoingVideoBell = CALL_OUTGOING | CALL_BELL,

    // An incoming Audio/Video call that was accepted (not established yet).
    CallStatusAcceptedIncomingCall = CALL_INCOMING | CALL_ACCEPTED,

    // Incoming video bell call was accepted and we are receiving the video track.
    CallStatusAcceptedIncomingVideoCall = CALL_INCOMING | CALL_ACCEPTED | CALL_VIDEO,

    // An outgoing Audio call that was accepted by the peer (not established yet).
    CallStatusAcceptedOutgoingCall = CALL_OUTGOING | CALL_ACCEPTED,

    // An outgoing Video call that was accepted by the peer (not established yet).
    CallStatusAcceptedOutgoingVideoCall = CALL_OUTGOING | CALL_ACCEPTED | CALL_VIDEO,

    // Outgoing video bell and we have setup the local video track.
    CallStatusInVideoBell = CALL_INCOMING | CALL_VIDEO | CALL_BELL,

    // Established Audio call (incoming or outgoing).
    CallStatusInCall = CALL_ACTIVE,

    // Established Audio call (incoming or outgoing).
    CallStatusInVideoCall = CALL_ACTIVE | CALL_VIDEO,

    // Audio/Video call that is terminated (transient mode until we go in CallStatusNone).
    CallStatusTerminated = CALL_TERMINATED
} CallStatus;

// Helper macros to test the call status.
// Call flow: IS_INCOMING => IS_ACCEPTED => IS_ACTIVE => CallStatusTerminated
//            IS_OUTGOING => IS_ACCEPTED => IS_ACTIVE => CallStatusTerminated
#define CALL_IS_INCOMING(S) ((S) & CALL_INCOMING)
#define CALL_IS_OUTGOING(S) ((S) & CALL_OUTGOING)
#define CALL_IS_ACCEPTED(S) ((S) & CALL_ACCEPTED)
#define CALL_IS_ACTIVE(S)   ((S) & CALL_ACTIVE)
#define CALL_IS_VIDEO(S)    ((S) & CALL_VIDEO)
#define CALL_IS_ON_HOLD(S)   ((S) & (CALL_ON_HOLD | CALL_PEER_ON_HOLD))
#define CALL_IS_PEER_ON_HOLD(S)  ((S) & CALL_PEER_ON_HOLD)
#define CALL_IS_PAUSED(S)        ((S) & CALL_ON_HOLD)
#define CALL_IS_TERMINATED(S)    ((S) & CALL_TERMINATED)

// Change call status to the accepted state.
#define CALL_TO_ACCEPTED(S) ((S) | CALL_ACCEPTED)

// Change call status to the active/connected state.
#define CALL_TO_ACTIVE(S)   ((S) | CALL_ACTIVE)

// Change call status to supporting video.
#define CALL_TO_VIDEO(S)    ((S) | CALL_VIDEO)

typedef enum {
    /// Ignore this update connection
    CallConnectionUpdateStateIgnore,

    /// the audio/video is now connected for the first time.
    CallConnectionUpdateStateFirstConnection,

    /// connected and not yet in a call room
    CallConnectionUpdateStateFirstGroup,

    /// new connection is active and we are in a call room
    CallConnectionUpdateStateNewConnection
} CallConnectionUpdateState;


typedef enum {
    CallGroupSupportUnknown,
    CallGroupSupportNo,
    CallGroupSupportYes
} CallGroupSupport;

typedef enum {
    TransferConnectionUnknown,
    TransferConnectionNo,
    TransferConnectionYes
} TransferConnection;

typedef enum {
    CallMessageSupportUnknown,
    CallMessageSupportNo,
    CallMessageSupportYes
} CallMessageSupport;

typedef enum {
    CallGeolocationSupportUnknown,
    CallGeolocationSupportNo,
    CallGeolocationSupportYes
} CallGeolocationSupport;

typedef enum {
    StreamingStatusUnknown,        // Status is not known (peer is not yet connected)
    StreamingStatusNotAvailable,   // Peer does not support streaming
    StreamingStatusReady,          // Peer is ready to receive streaming
    StreamingStatusPlaying,        // Peer is playing the stream we are sending
    StreamingStatusPaused,         // Peer's player is paused
    StreamingStatusUnSupported,    // Peer does not support the media we are sending
    StreamingStatusError           // Other error reported by the peer
} StreamingStatus;

#define IS_STREAMING_SUPPORTED(S) ((S) != StreamingStatusUnknown && (S) != StreamingStatusNotAvailable)

typedef enum {
    StreamingEventStart,       // A streaming has started.
    StreamingEventPlaying,     // Player associated with streaming is now playing.
    StreamingEventPaused,      // Player is now paused.
    StreamingEventCompleted,   // Player associated with streaming has completed playing.
    StreamingEventUnsupported, // Player does not support the local streamed content.
    StreamingEventError,       // Player had errors while playing streamed content.
    StreamingEventStop         // The streaming has stopped.
} StreamingEvent;
