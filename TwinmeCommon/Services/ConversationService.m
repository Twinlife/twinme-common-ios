/*
 *  Copyright (c) 2017-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLImageService.h>
#import <Twinlife/TLTwinlife.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLGroupMember.h>
#import <Twinme/TLMessage.h>
#import <Twinme/TLTyping.h>
#import <Twinme/TLTwinmeAttributes.h>

#import "ConversationService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int MAX_OBJECTS = 100;

static const int GET_OR_CREATE_CONVERSATION = 1 << 0;
static const int GET_OR_CREATE_CONVERSATION_DONE = 1 << 1;
static const int LIST_GROUP_MEMBERS = 1 << 2;
static const int LIST_GROUP_MEMBERS_DONE = 1 << 3;
static const int GET_DESCRIPTORS = 1 << 4;
static const int GET_DESCRIPTORS_DONE = 1 << 5;
static const int LIST_OTHER_MEMBERS = 1 << 6;
static const int LIST_OTHER_MEMBERS_DONE = 1 << 7;
static const int PUSH_OBJECT = 1 << 8;
static const int PUSH_FILE = 1 << 9;
static const int MARK_DESCRIPTOR_READ = 1 << 10;
static const int MARK_DESCRIPTOR_DELETED = 1 << 11;
static const int DELETE_DESCRIPTOR = 1 << 12;
static const int PUSH_TYPING = 1 << 13;
static const int TOGGLE_ANNOTATION = 1 << 14;
static const int PUSH_GEOLOCATION = 1 << 15;
static const int SAVE_GEOLOCATION_MAP = 1 << 16;
static const int UPDATE_DESCRIPTOR = 1 << 17;
//
// Interface: ConversationService ()
//

@class ConversationServiceTwinmeContextDelegate;
@class ConversationServiceConversationServiceDelegate;

@interface ConversationService ()

@property NSUUID *conversationId;
@property (nonatomic) id<TLOriginator> contact;
@property (nonatomic, nullable) TLDescriptorFilter descriptorFilter;
@property (nonatomic) NSUUID *twincodeOutboundId;
@property (nonatomic) NSUUID *peerTwincodeOutboundId;
@property (nonatomic) NSUUID *twincodeInboundId;
@property (nonatomic) id <TLConversation> conversation;
@property (nonatomic) id<TLGroupConversation> groupConversation;
@property (nonatomic) int64_t beforeTimestamp;
@property (nonatomic) int maxDescriptors;
@property (nonatomic) BOOL getDescriptorsDone;
@property (nonatomic) BOOL featureNotSupportedByPeerDone;
@property (nonatomic) BOOL isGroup;
@property (nonatomic) TLGroup *group;
@property (nonatomic, nullable) NSMutableArray<NSUUID *> *memberTwincodes;
@property (nonatomic) NSMutableDictionary<NSUUID *, TLGroupMember *> *groupMembers;
@property (nonatomic) NSArray<TLDescriptor *> *descriptors;
@property (nonatomic) TLDisplayCallsMode callsMode;

@property (nonatomic) ConversationServiceConversationServiceDelegate *conversationServiceDelegate;

- (void)onOperation;

- (void)onUpdateContact:(TLContact *)contact;

- (void)onGetOrCreateConversation:(id<TLConversation>)conversation;

- (void)onUpdateConversationPeerTwincodeOutboundId:(id<TLConversation>)conversation;

- (void)onResetConversation:(id<TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode;

- (void)onLeaveGroup:(nonnull id <TLGroupConversation>)group memberId:(NSUUID *)memberId;

- (void)onGetDescriptors:(NSArray *)descriptors;

- (void)onPushDescriptor:(TLDescriptor *)descriptor;

- (void)onPopDescriptor:(TLDescriptor *)descriptor;

- (void)onUpdateDescriptor:(TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType;

- (void)onMarkDescriptorRead:(TLDescriptor *)descriptor;

- (void)onMarkDescriptorDeleted:(TLDescriptor *)descriptor;

- (void)onDeleteDescriptors:(NSSet<TLDescriptorId *> *)descriptors;

- (void)onErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

@end

//
// Interface: ConversationServiceTwinmeContextDelegate
//

@interface ConversationServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ConversationService *)service;

@end

//
// Implementation: ConversationServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ConversationServiceTwinmeContextDelegate"

@implementation ConversationServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ConversationService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    [(ConversationService *)self.service onUpdateContact:contact];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);

    // If a storage error is raised, report it.
    if (requestId == [TLBaseService DEFAULT_REQUEST_ID]) {
        if (errorCode == TLBaseServiceErrorCodeNoStorageSpace) {
            [self.service onErrorWithOperationId:0 errorCode:errorCode errorParameter:errorParameter];
        }

        return;
    }

    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }

    [self.service onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Interface: ConversationServiceConversationServiceDelegate
//

@interface ConversationServiceConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) ConversationService *service;

- (instancetype)initWithService:(ConversationService *)service;

@end

//
// Implementation: ConversationServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ConversationServiceConversationServiceDelegate"

@implementation ConversationServiceConversationServiceDelegate

- (instancetype)initWithService:(ConversationService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onGetOrCreateConversationWithRequestId:(int64_t)requestId conversation:(id<TLConversation>)conversation {
    DDLogVerbose(@"%@ onGetOrCreateConversationWithRequestId: %lld conversation: %@", LOG_TAG, requestId, conversation);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }

    [self.service onGetOrCreateConversation:conversation];
}

- (void)onUpdateConversationPeerTwincodeOutboundIdWithRequestId:(int64_t)requestId conversation:(id<TLConversation>)conversation {
    DDLogVerbose(@"%@ onUpdateConversationPeerTwincodeOutboundIdWithRequestId: %lld conversation: %@", LOG_TAG, requestId, conversation);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }

    [self.service onUpdateConversationPeerTwincodeOutboundId:conversation];
}

- (void)onResetConversationWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode {
    DDLogVerbose(@"%@ onResetConversationWithRequestId: %lld conversation: %@ clearMode: %d", LOG_TAG, requestId, conversation, clearMode);
    
    if (![conversation isConversationWithUUID:self.service.conversationId]) {
        return;
    }
    
    [self.service onResetConversation:conversation clearMode:clearMode];
}

- (void)onPushDescriptorRequestId:(int64_t)requestId conversation:(id<TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPushDescriptorRequestId: %lld conversation: %@ objectDescriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    if (![conversation isConversationWithUUID:self.service.conversationId]) {
        return;
    }

    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }

    [self.service onPushDescriptor:descriptor];
}

- (void)onPopDescriptorWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopDescriptorWithRequestId: %lld conversation: %@ objectDescriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    if (![conversation isConversationWithUUID:self.service.conversationId]) {
        return;
    }
    
    [self.service onPopDescriptor:descriptor];
}

- (void)onUpdateDescriptorWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType {
    DDLogVerbose(@"%@ onUpdateDescriptorWithRequestId: %lld conversation: %@ objectDescriptor: %@ updateType: %u", LOG_TAG, requestId, conversation, descriptor, updateType);
    
    if (![conversation isConversationWithUUID:self.service.conversationId]) {
        return;
    }
    
    [self.service onUpdateDescriptor:descriptor updateType:updateType];
}

- (void)onUpdateAnnotationWithConversation:(id<TLConversation>)conversation descriptor:(TLDescriptor *)descriptor annotatingUser:(TLTwincodeOutbound *)annotatingUser {
    DDLogVerbose(@"%@ onUpdateAnnotationWithConversation: %@ descriptor: %@ annotatingUser: %@", LOG_TAG, conversation, descriptor, annotatingUser);
    
    if (![conversation isConversationWithUUID:self.service.conversationId]) {
        return;
    }
    
    [self.service onUpdateDescriptor:descriptor updateType:TLConversationServiceUpdateTypePeerAnnotations];
}

- (void)onMarkDescriptorReadWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onMarkDescriptorReadWithRequestId: %lld conversation: %@ descriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    if (![conversation.uuid isEqual:self.service.conversationId]) {
        return;
    }
    
    [self.service onMarkDescriptorRead:descriptor];
}

- (void)onMarkDescriptorDeletedWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onMarkDescriptorDeletedWithRequestId: %lld conversation: %@ descriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    if (![conversation.uuid isEqual:self.service.conversationId]) {
        return;
    }
    
    [self.service onMarkDescriptorDeleted:descriptor];
}

- (void)onDeleteDescriptorsWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation descriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors {
    DDLogVerbose(@"%@ onDeleteDescriptorsWithRequestId: %lld conversation: %@ descriptors: %@", LOG_TAG, requestId, conversation, descriptors);
    
    if (![conversation isConversationWithUUID:self.service.conversationId]) {
        return;
    }
    
    [self.service onDeleteDescriptors:descriptors];
}

- (void)onInviteGroupRequestWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onInviteGroupRequestWithRequestId: %lld conversation: %@ invitation: %@", LOG_TAG, requestId, conversation, invitation);
    
    // Ignore a peer invitation that is not for the current conversation.
    if (![conversation isConversationWithUUID:self.service.conversationId]) {
        return;
    }
    
    [self.service onPopDescriptor:invitation];
}

- (void)onJoinGroupWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onJoinGroupWithRequestId: %lld group: %@ invitation: %@", LOG_TAG, requestId, group, invitation);
    
    // Ignore a peer invitation that is not for the current conversation.
    if (![invitation isTwincodeOutbound:self.service.peerTwincodeOutboundId]) {
        return;
    }
    
    // Invitation we are accepting: update its status.
    [self.service onUpdateDescriptor:invitation updateType:TLConversationServiceUpdateTypeTimestamps];
}

- (void)onJoinGroupResponseWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onJoinGroupResponseWithRequestId: %lld group: %@ invitation: %@", LOG_TAG, requestId, group, invitation);
    
    // Ignore a peer invitation that is not for the current conversation.
    if (![invitation isTwincodeOutbound:self.service.peerTwincodeOutboundId]) {
        return;
    }
    
    // Invitation we are accepting: update its status.
    [self.service onUpdateDescriptor:invitation updateType:TLConversationServiceUpdateTypeTimestamps];
}

- (void)onJoinGroupRequestWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onJoinGroupResponseWithRequestId: %lld group: %@ invitation: %@ memberId: %@", LOG_TAG, requestId, group, invitation, memberId);
    
    // Ignore an invitation that is not from the current conversation.
    if (!invitation || ![invitation isTwincodeOutbound:self.service.peerTwincodeOutboundId]) {
        return;
    }
    
    // Invitation we have sent and is accepted or refused: update its status.
    [self.service onUpdateDescriptor:invitation updateType:TLConversationServiceUpdateTypeTimestamps];
}

- (void)onLeaveGroupWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onLeaveGroupWithRequestId: %lld group: %@ memberId: %@", LOG_TAG, requestId, group, memberId);
    
    if (![group isConversationWithUUID:self.service.conversationId]) {
        return;
    }
    
    [self.service onLeaveGroup:group memberId:memberId];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    if (requestId == [TLBaseService DEFAULT_REQUEST_ID]) {
        if (errorCode == TLBaseServiceErrorCodeFeatureNotSupportedByPeer) {
            NSUUID *conversationId = [[NSUUID alloc] initWithUUIDString:errorParameter];
            if (conversationId && [conversationId isEqual:self.service.conversationId]) {
                [self.service onErrorWithErrorCode:errorCode errorParameter:errorParameter];
            }
        } else if (errorCode == TLBaseServiceErrorCodeNoStorageSpace) {
            [self.service onErrorWithErrorCode:errorCode errorParameter:errorParameter];
        } else {
            [self.service.twinmeContext assertionWithAssertPoint:[ServicesAssertPoint UNKNOWN_ERROR], [TLAssertValue initWithLine:__LINE__], [TLAssertValue initWithErrorCode:errorCode], nil];
        }
    } else {
        int operationId = [self.service getOperation:requestId];
        if (!operationId) {
            return;
        }

        [self.service onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
        [self.service onOperation];
    }
}

@end

//
// Implementation: ConversationService
//

#undef LOG_TAG
#define LOG_TAG @"ConversationService"

@implementation ConversationService

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext delegate:(id<ConversationServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _beforeTimestamp = INT64_MAX;
        _getDescriptorsDone = NO;
        _maxDescriptors = MAX_OBJECTS;
        _featureNotSupportedByPeerDone = NO;
        _callsMode = TLDisplayCallsModeAll;
        
        _conversationServiceDelegate = [[ConversationServiceConversationServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[ConversationServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

#pragma mark - Public methods

- (nullable NSUUID *)debugGetTwincodeOutboundId {
    
    return self.twincodeOutboundId;
}

- (nullable NSUUID *)debugGetPeerTwincodeOutboundId {
    
    return self.peerTwincodeOutboundId;
}

- (void)initWithContact:(id<TLOriginator>)contact callsMode:(TLDisplayCallsMode)callsMode descriptorFilter:(nullable TLDescriptorFilter)descriptorFilter maxDescriptors:(int)maxDescriptors {
    DDLogVerbose(@"%@ initWithContact: %@", LOG_TAG, contact);
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, contact, [ServicesAssertPoint PARAMETER], nil);

    self.state = 0;
    self.beforeTimestamp = INT64_MAX;
    self.getDescriptorsDone = NO;
    self.contact = contact;
    self.descriptorFilter = descriptorFilter;
    self.twincodeOutboundId = contact.twincodeOutboundId;
    self.twincodeInboundId = contact.twincodeInboundId;
    self.callsMode = callsMode;
    
    self.maxDescriptors = maxDescriptors == 0 ? MAX_OBJECTS : maxDescriptors;
            
    if (![contact isGroup]) {
        TLContact *c = (TLContact *)contact;
        if ([c hasPrivatePeer]) {
            self.peerTwincodeOutboundId = c.peerTwincodeOutboundId;
        } else {
            self.peerTwincodeOutboundId = nil;
        }
        self.isGroup = [c isTwinroom];
    } else {
        self.group = (TLGroup *)contact;
        self.peerTwincodeOutboundId = self.group.groupTwincodeOutboundId;
        self.isGroup = YES;
    }
    if (self.isGroup) {
        self.groupMembers = [[NSMutableDictionary alloc] init];
        self.memberTwincodes = [[NSMutableArray alloc] init];
    }
    
    [self startOperation];
}

- (BOOL)isLocalDescriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ isLocalDescriptor: %@", LOG_TAG, descriptor);
    
    return [descriptor isTwincodeOutbound:self.twincodeOutboundId];
}

- (BOOL)isPeerDescriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ isPeerDescriptor: %@", LOG_TAG, descriptor);
    
    return [descriptor isTwincodeOutbound:self.peerTwincodeOutboundId] || self.isGroup;
}

- (void)setActiveConversation {
    DDLogVerbose(@"%@ setActiveConversation", LOG_TAG);
    
    if (self.conversation) {
        [self.twinmeContext setActiveConversationWithConversation:self.conversation];
    }
}

- (void)resetActiveConversation {
    DDLogVerbose(@"%@ resetActiveConversation", LOG_TAG);
    
    if (self.conversation) {
        [self.twinmeContext resetActiveConversationWithConversation:self.conversation];
    }
}

- (void)getPreviousDescriptors {
    DDLogVerbose(@"%@ getPreviousDescriptors", LOG_TAG);
    
    if (self.getDescriptorsDone) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ConversationServiceDelegate>)self.delegate onGetDescriptors:[NSArray array]];
        });

        return;
    }
    
    if ((self.state & GET_DESCRIPTORS) != 0 && (self.state & GET_DESCRIPTORS_DONE) != 0) {
        self.maxDescriptors = MAX_OBJECTS;
        self.state &= ~GET_DESCRIPTORS;
        self.state &= ~GET_DESCRIPTORS_DONE;
        
        [self startOperation];
    }
}

- (BOOL)isGetDescriptorDone {
    DDLogVerbose(@"%@ isGetDescriptorDone", LOG_TAG);
    
    return self.getDescriptorsDone;
}

- (void)markDescriptorReadWithDescriptorId:(TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ markDescriptorReadWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    int64_t requestId = [self newOperation:MARK_DESCRIPTOR_READ];
    DDLogVerbose(@"%@ markDescriptorReadWithRequestId: %lld descriptorId: %@", LOG_TAG, requestId, descriptorId);
    [self.twinmeContext markDescriptorReadWithRequestId:requestId descriptorId:descriptorId];
}

- (void)markDescriptorDeletedWithDescriptorId:(TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ markDescriptorDeletedWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    int64_t requestId = [self newOperation:MARK_DESCRIPTOR_DELETED];
    DDLogVerbose(@"%@ markDescriptorDeletedWithRequestId: %lld descriptorId: %@", LOG_TAG, requestId, descriptorId);
    [self.twinmeContext markDescriptorDeletedWithRequestId:requestId descriptorId:descriptorId];
}

- (void)updateDescriptorWithDescriptorId:(nonnull TLDescriptorId *)descriptorId content:(nonnull NSString *)message {
    DDLogVerbose(@"%@ updateDescriptorWithDescriptorId: %@ content: %@", LOG_TAG, descriptorId, message);
    
    int64_t requestId = [self newOperation:UPDATE_DESCRIPTOR];
    [[self.twinmeContext getConversationService] updateDescriptorWithRequestId:requestId descriptorId:descriptorId message:message copyAllowed:nil expireTimeout:nil];
}

- (void)deleteDescriptorWithDescriptorId:(TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ deleteDescriptorWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    int64_t requestId = [self newOperation:DELETE_DESCRIPTOR];
    DDLogVerbose(@"%@ deleteDescriptorWithDescriptorId: %lld descriptorId: %@", LOG_TAG, requestId, descriptorId);
    [self.twinmeContext deleteDescriptorWithRequestId:requestId descriptorId:descriptorId];
}

- (void)pushMessage:(NSString *)message copyAllowed:(BOOL)copyAllowed expiredTimeout:(int64_t)expiredTimeout sendTo:(NSUUID *)sendTo replyTo:(TLDescriptorId *)replyTo {
    DDLogVerbose(@"%@ pushMessage: %@ expiredTimeout: %lld sendTo: %@ replyTo: %@", LOG_TAG, message, expiredTimeout, sendTo, replyTo);
    
    int64_t requestId = [self newOperation:PUSH_OBJECT];
    DDLogVerbose(@"%@ pushObjectWithRequestId: %lld conversationId: %@ message: %@", LOG_TAG, requestId, self.conversationId, message);
    [self.twinmeContext pushObjectWithRequestId:requestId conversation:self.conversation sendTo:sendTo replyTo:replyTo message:message copyAllowed:copyAllowed expireTimeout:expiredTimeout * 1000L];
}

- (void)pushFileWithPath:(NSString *)path type:(TLDescriptorType)type toBeDeleted:(BOOL)toBeDeleted copyAllowed:(BOOL)copyAllowed expiredTimeout:(int64_t)expiredTimeout sendTo:(NSUUID *)sendTo replyTo:(TLDescriptorId *)replyTo {
    DDLogVerbose(@"%@ pushFileWithPath: %@ type: %u toBeDeleted: %@ expiredTimeout: %lld sendTo: %@ replyTo: %@", LOG_TAG, path, type, toBeDeleted ? @"YES" : @"NO", expiredTimeout, sendTo, replyTo);
    
    int64_t requestId = [self newOperation:PUSH_FILE];
    
    [self.twinmeContext pushFileWithRequestId:requestId conversation:self.conversation sendTo:sendTo replyTo:replyTo path:path type:type toBeDeleted:toBeDeleted copyAllowed:copyAllowed expireTimeout:expiredTimeout * 1000L];
}

- (void)pushGeolocationWithLatitude:(double)latitude longitude:(double)longitude altitude:(double)altitude  latitudeDelta:(double)latitudeDelta longitudeDelta:(double)longitudeDelta expiredTimeout:(int64_t)expiredTimeout sendTo:(NSUUID *)sendTo replyTo:(TLDescriptorId *)replyTo {
    DDLogVerbose(@"%@ pushGeolocationWithLatitude: %f longitude: %f altitude: %f latitudeDelta: %f longitudeDelta: %f expiredTimeout: %lld sendTo: %@ replyTo: %@", LOG_TAG, latitude, longitude, altitude, latitudeDelta, longitudeDelta, expiredTimeout, sendTo, replyTo);
    
    int64_t requestId = [self newOperation:PUSH_GEOLOCATION];
    [self.twinmeContext pushGeolocationWithRequestId:requestId conversation:self.conversation sendTo:nil replyTo:replyTo longitude:longitude latitude:latitude altitude:altitude mapLongitudeDelta:longitudeDelta mapLatitudeDelta:latitudeDelta localMapPath:NULL expireTimeout:expiredTimeout * 1000L];
}

- (void)saveGeolocationMapWithPath:(NSString *)path descriptorId:(TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ saveGeolocationMapWithPath: %@ descriptorId: %@", LOG_TAG, path, descriptorId);
    
    int64_t requestId = [self newOperation:SAVE_GEOLOCATION_MAP];
    [self.twinmeContext saveGeolocationMapWithRequestId:requestId conversation:self.conversation descriptorId:descriptorId path:path];
}

- (void)pushTyping:(TLTyping *)typing {
    DDLogVerbose(@"%@ pushTyping: %@", LOG_TAG, typing);
    
    int64_t requestId = [self newOperation:PUSH_TYPING];
    [self.twinmeContext pushTransientObjectWithRequestId:requestId conversation:self.conversation object:typing];
}

- (void)resetConversation {
    DDLogVerbose(@"%@ resetConversation", LOG_TAG);
    
    [[self.twinmeContext getConversationService] clearConversationWithConversation:self.conversation clearDate:0 clearMode:TLConversationServiceClearBoth];
}

- (void)clearMediaAndFile {
    DDLogVerbose(@"%@ clearMediaAndFile", LOG_TAG);
    
    self.beforeTimestamp = INT64_MAX;
    self.getDescriptorsDone = NO;
}

- (void)toggleAnnotationWithDescriptorId:(TLDescriptorId *)descriptorId type:(TLDescriptorAnnotationType)type value:(int)value {
    DDLogVerbose(@"%@ toggleAnnotationWithDescriptorId: %@ type: %u value: %d", LOG_TAG, descriptorId, type, value);
    
    [[self.twinmeContext getConversationService] toggleAnnotationWithDescriptorId:descriptorId type:type value:value];
}

- (nonnull UIImage *)getImageWithGroupMember:(nonnull TLGroupMember *)groupMember {
    DDLogVerbose(@"%@ getImageWithGroupMember: %@", LOG_TAG, groupMember);

    TLImageId *imageId = groupMember.memberAvatarId;
    if (!imageId) {
        return [TLTwinmeAttributes DEFAULT_AVATAR];
    }
    
    // Look in the image cache and load from database: we are running from twinlife executor and could
    // block while reading the database.
    TLImageService *imageService = [self.twinmeContext getImageService];
    UIImage *image = [imageService getCachedImageWithImageId:imageId kind:TLImageServiceKindThumbnail];
    if (!image) {
        return [TLTwinmeAttributes DEFAULT_AVATAR];
    }
    
    return image;
}

- (void)listAnnotationsWithDescriptorId:(nonnull TLDescriptorId *)descriptorId withBlock:(nonnull void (^)(NSMutableDictionary<NSUUID *, TLDescriptorAnnotationPair*> * _Nonnull list))block {
    DDLogVerbose(@"%@ listAnnotationsWithDescriptorId: %@", LOG_TAG, descriptorId);

    [self.twinmeContext listAnnotationsWithDescriptorId:descriptorId withBlock:block];
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];
    [self.twinmeContext removeDelegate:self.twinmeContextDelegate];
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    //
    // Step 1
    //

    if (self.group && self.twincodeOutboundId) {
        if ((self.state & GET_OR_CREATE_CONVERSATION) == 0) {
            self.state |= GET_OR_CREATE_CONVERSATION;
            
            // For a group, we must not create the conversation and the get can fail.
            id<TLConversation> conversation = [[self.twinmeContext getConversationService] getConversationWithSubject:self.group];
            if (conversation) {
                [self onGetOrCreateConversation:conversation];
            } else {
                DDLogError(@"%@ group conversation for twincode %@ does not exist", LOG_TAG, self.twincodeOutboundId);
            }
        }
        
    } else if (self.contact) {
        if ((self.state & GET_OR_CREATE_CONVERSATION) == 0) {
            self.state |= GET_OR_CREATE_CONVERSATION;
            
            DDLogVerbose(@"%@ getOrCreateConversationWithSubject: %@ peerTwincodeOutboundId: %@ twincodeInboundId: %@", LOG_TAG, self.twincodeOutboundId, self.peerTwincodeOutboundId, self.twincodeInboundId);
            id<TLConversation> conversation = [[self.twinmeContext getConversationService] getOrCreateConversationWithSubject:self.contact create:true];
            [self onGetOrCreateConversation:conversation];
        }
        if ((self.state & GET_OR_CREATE_CONVERSATION_DONE) == 0) {
            return;
        }
    }

    //
    // Step 2: get the group members
    //
    if (self.group) {
        
        // We must get the group members (each of them, one by one until we are done).
        if ((self.state & LIST_GROUP_MEMBERS) == 0) {
            self.state |= LIST_GROUP_MEMBERS;
            
            DDLogVerbose(@"%@ listGroupMembersWithGroup: %@", LOG_TAG, self.group);
            [self.twinmeContext listGroupMembersWithGroup:self.group filter:TLGroupMemberFilterTypeJoinedMembers withBlock:^(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> *members) {
                [self onListGroupMembers:errorCode members:members];
            }];
            return;
        }
        if ((self.state & LIST_GROUP_MEMBERS_DONE) == 0) {
            return;
        }
    }
    
    if (self.contact && self.memberTwincodes && self.memberTwincodes.count > 0 && ((self.state & LIST_OTHER_MEMBERS_DONE) == 0)) {
        return;
    }

    //
    // Step 3
    //

    if (self.conversationId) {
        if ((self.state & GET_DESCRIPTORS) == 0) {
            self.state |= GET_DESCRIPTORS;
            
            DDLogVerbose(@"%@ getDescriptorsWithConversation: %@ beforeSequence: %lld maxObjects: %d", LOG_TAG, self.conversationId, self.beforeTimestamp, MAX_OBJECTS);
            
            NSMutableArray<TLDescriptor *> *descriptors = [[NSMutableArray alloc] init];
            
            BOOL needMore = YES;
            while (needMore) {
                NSArray<TLDescriptor *> *page = [[self.twinmeContext getConversationService] getDescriptorsWithConversation:self.conversation callsMode:self.callsMode beforeTimestamp:self.beforeTimestamp maxDescriptors:self.maxDescriptors];
                
                if (page) {
                    for (TLDescriptor *d in page) {
                        if (d.createdTimestamp < self.beforeTimestamp) {
                            self.beforeTimestamp = d.createdTimestamp;
                        }
                        if (!self.descriptorFilter || self.descriptorFilter(d)) {
                            [descriptors addObject:d];
                            if (descriptors.count == self.maxDescriptors) {
                                break;
                            }
                        }
                    }
                    needMore = descriptors.count < self.maxDescriptors && page.count == self.maxDescriptors;
                } else {
                    needMore = NO;
                }
            }
            
            [self onGetDescriptors:descriptors];
        }
        if ((self.state & GET_DESCRIPTORS_DONE) == 0) {
            return;
        }
    }
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getConversationService] addDelegate:self.conversationServiceDelegate];
    [super onTwinlifeReady];
}

- (void)onUpdateContact:(TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContact: %@", LOG_TAG, contact);
    
    if (![self.contact.uuid isEqual:contact.uuid] || ![contact hasPrivatePeer]) {
        return;
    }
    
    self.contact = contact;
    self.peerTwincodeOutboundId = contact.peerTwincodeOutboundId;
}

- (void)onGetOrCreateConversation:(id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onGetOrCreateConversation: %@", LOG_TAG, conversation);

    self.state |= GET_OR_CREATE_CONVERSATION_DONE;
    
    self.conversation = conversation;
    self.conversationId = [self.conversation uuid];
    if ([conversation isGroup]) {
        self.groupConversation = (id<TLGroupConversation>)conversation;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ConversationServiceDelegate>)self.delegate onGetConversation:conversation];
    });
    [self onOperation];
}

- (void)onListGroupMembers:(TLBaseServiceErrorCode)errorCode members:(nullable NSMutableArray<TLGroupMember *> *)members {
    DDLogVerbose(@"%@ onListGroupMembers: %d groupMember: %@", LOG_TAG, errorCode, members);
    
    if (!self.memberTwincodes || self.memberTwincodes.count == 0) {
        self.state |= LIST_GROUP_MEMBERS_DONE;
    } else {
        self.state |= LIST_OTHER_MEMBERS_DONE;
    }

    if (errorCode != TLBaseServiceErrorCodeSuccess || !members) {
        
        [self onErrorWithOperationId:LIST_GROUP_MEMBERS errorCode:errorCode errorParameter:nil];
        return;
    }
    
    for (TLGroupMember *groupMember in members) {
        self.groupMembers[groupMember.memberTwincodeOutboundId] = groupMember;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.groupConversation) {
            [(id<ConversationServiceDelegate>)self.delegate onGetGroupConversation:(id<TLGroupConversation>)self.conversation groupMembers:self.groupMembers];
        } else {
            [(id<ConversationServiceDelegate>)self.delegate onGetGroupMembers:self.groupMembers];
        }
    });
    
    if (self.descriptors) {
        self.state |= GET_DESCRIPTORS_DONE;
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ConversationServiceDelegate>)self.delegate onGetDescriptors:self.descriptors];
        });
    }
    [self onOperation];
}

- (void)onLeaveGroup:(nonnull id <TLGroupConversation>)group memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onLeaveGroup: %@ memberId: %@", LOG_TAG, group, memberId);
    
    if (self.delegate && self.group) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ConversationServiceDelegate>)self.delegate onLeaveGroup:self.group memberTwincodeId:memberId];
        });
    }
}

- (void)onResetConversation:(id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode {
    DDLogVerbose(@"%@ onResetConversation: %@ clearMode: %d", LOG_TAG, conversation, clearMode);
    
    self.beforeTimestamp = INT64_MAX;
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ConversationServiceDelegate>)self.delegate onResetConversation:conversation clearMode:clearMode];
    });
}

- (void)onUpdateConversationPeerTwincodeOutboundId:(id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onUpdateConversationPeerTwincodeOutboundId: %@", LOG_TAG, conversation);
    
    if (self.conversationId) {
        TL_ASSERT_EQUAL(self.twinmeContext, conversation.uuid, self.conversationId, [ServicesAssertPoint INVALID_CONVERSATION_ID], TLAssertionParameterTwincodeId, [TLAssertValue initWithSubject:conversation.subject], nil);
    }
    
    self.conversation = conversation;
    self.conversationId = conversation.uuid;

    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ConversationServiceDelegate>)self.delegate onUpdateConversation:conversation];
    });
    [self onOperation];
}

- (void)onGetDescriptors:(NSArray *)descriptors {
    DDLogVerbose(@"%@ onGetDescriptors: %@", LOG_TAG, descriptors);
    
    if ((self.state & GET_DESCRIPTORS_DONE) != 0) {
        return;
    }
    
    [[self.twinmeContext getConversationService] getReplyTosWithDescriptors:descriptors];
    
    NSMutableSet<NSUUID *> *peerTwincodes = nil;
    for (TLDescriptor *descriptor in descriptors) {
        if (!self.isGroup) {
            continue;
        }
        NSUUID *twincodeOutboundId = descriptor.descriptorId.twincodeOutboundId;
        if ([twincodeOutboundId isEqual:self.contact.twincodeOutboundId]) {
            continue;
        }
        
        if (![self.groupMembers objectForKey:twincodeOutboundId]) {
            if (!peerTwincodes) {
                peerTwincodes = [[NSMutableSet alloc] init];
            }
            [peerTwincodes addObject:twincodeOutboundId];
        }
    }
    
    if (descriptors.count < self.maxDescriptors) {
        self.getDescriptorsDone = YES;
    }
    
    if (peerTwincodes) {
        self.descriptors = descriptors;
        self.memberTwincodes = [[NSMutableArray alloc] init];
        for (NSUUID *twincodeId in peerTwincodes) {
            [self.memberTwincodes addObject:twincodeId];
        }
        [self.twinmeContext listMembersWithOwner:self.contact memberTwincodeList:self.memberTwincodes withBlock:^(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> *members) {
            [self onListGroupMembers:errorCode members:members];
        }];
        [self onOperation];
    } else {
        self.state |= GET_DESCRIPTORS_DONE;
        self.memberTwincodes = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ConversationServiceDelegate>)self.delegate onGetDescriptors:descriptors];
        });
    }
}

- (void)onPushDescriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPushDescriptor: %@", LOG_TAG, descriptor);

    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ConversationServiceDelegate>)self.delegate onPushDescriptor:descriptor];
    });
    [self onOperation];
}

- (void)onPopDescriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopDescriptor: %@", LOG_TAG, descriptor);
    
    NSUUID *twincodeOutboundId = descriptor.descriptorId.twincodeOutboundId;
    if (self.isGroup && ![self.groupMembers objectForKey:twincodeOutboundId]) {
        [self.twinmeContext getGroupMemberWithOwner:self.contact memberTwincodeId:twincodeOutboundId withBlock:^(TLBaseServiceErrorCode errorCode, TLGroupMember *groupMember) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (errorCode == TLBaseServiceErrorCodeSuccess && groupMember) {
                    self.groupMembers[twincodeOutboundId] = groupMember;
                    [(id<ConversationServiceDelegate>)self.delegate onGetGroupMembers:self.groupMembers];
                }
            });
            [self getReplyWithDescriptor:descriptor withBlock:^(TLDescriptor * _Nullable d) {
                [(id<ConversationServiceDelegate>)self.delegate onPopDescriptor:d];
            }];
        }];
    } else {
        [self getReplyWithDescriptor:descriptor withBlock:^(TLDescriptor * _Nullable d) {
            [(id<ConversationServiceDelegate>)self.delegate onPopDescriptor:d];
        }];
    }
    [self onOperation];
}

- (void)onUpdateDescriptor:(TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType {
    DDLogVerbose(@"%@ onUpdateDescriptor: %@ updateType: %u", LOG_TAG, descriptor, updateType);

    [self getReplyWithDescriptor:descriptor withBlock:^(TLDescriptor * _Nullable d) {
        [(id<ConversationServiceDelegate>)self.delegate onUpdateDescriptor:d updateType:updateType];
    }];
    [self onOperation];
}

- (void)onMarkDescriptorRead:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onMarkReadDescriptorRead: %@", LOG_TAG, descriptor);

    [self getReplyWithDescriptor:descriptor withBlock:^(TLDescriptor * _Nullable d) {
        [(id<ConversationServiceDelegate>)self.delegate onMarkDescriptorRead:d];
    }];

    [self onOperation];
}

- (void)onMarkDescriptorDeleted:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onMarkDescriptorDeleted: %@", LOG_TAG, descriptor);

    [self getReplyWithDescriptor:descriptor withBlock:^(TLDescriptor * _Nullable d) {
        [(id<ConversationServiceDelegate>)self.delegate onMarkDescriptorDeleted:d];
    }];
    [self onOperation];
}

- (void)onDeleteDescriptors:(NSSet<TLDescriptorId *> *)descriptors {
    DDLogVerbose(@"%@ onDeleteDescriptors: %@", LOG_TAG, descriptors);

    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ConversationServiceDelegate>)self.delegate onDeleteDescriptors:descriptors];
    });
    [self onOperation];
}

- (void)onErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithErrorCode: %u errorParameter: %@", LOG_TAG, errorCode, errorParameter);
    
    [super onErrorWithOperationId:0 errorCode:errorCode errorParameter:errorParameter];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %u errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch (operationId) {
            case MARK_DESCRIPTOR_READ:
            case MARK_DESCRIPTOR_DELETED:
            case DELETE_DESCRIPTOR:
            case SAVE_GEOLOCATION_MAP:
            case TOGGLE_ANNOTATION:
                return;
                
            case LIST_GROUP_MEMBERS:
                self.state |= LIST_GROUP_MEMBERS_DONE;
                [self onOperation];
                return;
        }
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

- (void) getReplyWithDescriptor:(TLDescriptor *)descriptor withBlock:(nonnull void (^)(TLDescriptor * _Nullable d))block {
    if (descriptor.replyTo && !descriptor.replyToDescriptor) {
        [self.twinmeContext getDescriptorWithDescriptorId:descriptor.replyTo withBlock:^(TLDescriptor * _Nullable replyToDescriptor) {
            descriptor.replyToDescriptor = replyToDescriptor;
            dispatch_async(dispatch_get_main_queue(), ^{
                block(descriptor);
            });
        }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            block(descriptor);
        });
    }
}

@end
