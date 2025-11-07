/*
 *  Copyright (c) 2020-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLFilter.h>

#import <Twinme/TLTwinmeAttributes.h>
#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLSpace.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLCallReceiver.h>
#import <Twinme/TLGroup.h>

#import "CallsService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int MAX_OBJECTS = 30;

static const int GET_CURRENT_SPACE = 1 << 0;
static const int GET_CURRENT_SPACE_DONE = 1 << 1;
static const int GET_CONTACT_THUMBNAIL_IMAGE = 1 << 2;
static const int GET_CONTACT_THUMBNAIL_IMAGE_DONE = 1 << 3;
static const int GET_CONTACTS = 1 << 4;
static const int GET_CONTACTS_DONE = 1 << 5;
static const int GET_DESCRIPTORS = 1 << 6;
static const int GET_DESCRIPTORS_DONE = 1 << 7;
static const int DELETE_DESCRIPTOR = 1 << 8;
static const int GET_CONVERSATION = 1 << 9;
static const int GET_CALL_RECEIVERS = 1 << 10;
static const int GET_CALL_RECEIVERS_DONE = 1 << 11;
static const int GET_GROUPS = 1 << 12;
static const int GET_GROUPS_DONE = 1 << 13;
static const int DELETE_CALL_RECEIVER = 1 << 14;
static const int DELETE_CALL_RECEIVER_DONE = 1 << 15;
static const int GET_GROUP_MEMBERS = 1 << 16;
static const int GET_GROUP_MEMBERS_DONE = 1 << 17;
static const int COUNT_CALL_RECEIVERS = 1 << 18;
static const int COUNT_CALL_RECEIVERS_DONE = 1 << 19;

//
// Interface: CallsService ()
//

@class CallsServiceTwinmeContextDelegate;
@class CallsServiceConversationServiceDelegate;

@interface CallsService ()

@property(nonatomic) int work;
@property(nonatomic, nullable) TLCallReceiver *callReceiver;
@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) id<TLOriginator> originator;
@property (nonatomic, nullable) id<TLOriginator> group;
@property (nonatomic) int64_t beforeTimestamp;
@property (nonatomic) BOOL getDescriptorsDone;
@property (nonatomic, readonly, nonnull) NSMutableSet<NSUUID *> *originatorTwincodes;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSUUID *, id<TLOriginator>> *originators;
@property (nonatomic, nullable) id<TLConversation> conversation;
@property (nonatomic, nonnull) CallsServiceConversationServiceDelegate *conversationServiceDelegate;

- (void)onOperation;

- (void)onTwinlifeReady;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

- (void)onUpdateSpace:(nonnull TLSpace *)space;

- (void)onGetDescriptors:(nonnull NSArray *)descriptors;

- (void)onGetContacts:(nonnull NSArray<TLContact *> *)contacts;

- (void)onGetCallReceivers:(nonnull NSArray<TLCallReceiver *> *)callReceivers;

- (void)onCreateCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onUpdateCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onDeleteCallReceiver:(nonnull NSUUID *)callReceiverId;

- (void)onPushDescriptor:(nonnull TLCallDescriptor *)descriptor;

- (void)onPopDescriptor:(nonnull TLCallDescriptor *)descriptor;

- (void)onUpdateDescriptor:(nonnull TLCallDescriptor *)descriptor;

- (void)onDeleteDescriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors;

- (void)onCreateOriginator:(nonnull id<TLOriginator>)originator;

- (void)onUpdateOriginator:(nonnull id<TLOriginator>)originator;

- (void)onMoveOriginator:(nonnull id<TLOriginator>)originator;

- (void)onDeleteOriginator:(nonnull NSUUID *)originatorId;

- (void)onResetConversation:(nonnull id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode;

- (void)onGetGroupMembers:(nonnull NSMutableArray<id<TLGroupMemberConversation>> *)members;

@end


//
// Interface: CallsServiceTwinmeContextDelegate
//

@interface CallsServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull CallsService *)service;

@end

//
// Implementation: CallsServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"CallsServiceTwinmeContextDelegate"

@implementation CallsServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull CallsService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onSetCurrentSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(CallsService *)self.service onSetCurrentSpace:space];
}

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(CallsService *)self.service onUpdateSpace:space];
}

- (void)onCreateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onCreateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    [(CallsService *)self.service onCreateOriginator:contact];
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    [(CallsService *)self.service onUpdateOriginator:contact];
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact oldSpace:(nonnull TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld contact: %@ oldSpace: %@", LOG_TAG, requestId, contact, oldSpace);
    
    [(CallsService *)self.service onMoveOriginator:contact];
}

- (void)onDeleteContactWithRequestId:(int64_t)requestId contactId:(NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contactId);
    
    [(CallsService *)self.service onDeleteOriginator:contactId];
}

- (void)onCreateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onCreateCallReceiverWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);

    [(CallsService *) self.service onCreateCallReceiver:callReceiver];
}

- (void)onUpdateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onUpdateCallReceiverWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);

    [(CallsService *) self.service onUpdateCallReceiver:callReceiver];
}

- (void)onDeleteCallReceiverWithRequestId:(int64_t)requestId callReceiverId:(NSUUID *)callReceiverId {
    DDLogVerbose(@"%@ onDeleteCallReceiverWithRequestId: %lld callReceiverId: %@", LOG_TAG, requestId, callReceiverId);

    [(CallsService *) self.service onDeleteCallReceiver:callReceiverId];
}

- (void)onCreateGroupWithRequestId:(int64_t)requestId group:(TLGroup *)group conversation:(nonnull id<TLGroupConversation>)conversation {
    DDLogVerbose(@"%@ onCreateGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, group);

    [(CallsService *) self.service onCreateOriginator:group];
}

- (void)onDeleteGroupWithRequestId:(int64_t)requestId groupId:(NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, groupId);
    
    [(CallsService *)self.service onDeleteOriginator:groupId];
}

- (void)onUpdateGroupWithRequestId:(int64_t)requestId group:(TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, group);
    
    [(CallsService *)self.service onUpdateOriginator:group];
}

@end

//
// Interface: CallsServiceConversationServiceDelegate
//

@interface CallsServiceConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) CallsService *service;

- (nonnull instancetype)initWithService:(nonnull CallsService *)service;

@end

//
// Implementation: CallsServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"CallsServiceConversationServiceDelegate"

@implementation CallsServiceConversationServiceDelegate

- (nonnull instancetype)initWithService:(nonnull CallsService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onResetConversationWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode {
    DDLogVerbose(@"%@ onResetConversationWithRequestId: %lld conversation: %@ clearMode: %d", LOG_TAG, requestId, conversation, clearMode);
    
    [self.service onResetConversation:conversation clearMode:clearMode];
}

- (void)onPushDescriptorRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPushDescriptorRequestId: %lld conversation: %@ descriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    if ([descriptor getType] != TLDescriptorTypeCallDescriptor) {
        return;
    }
    
    [self.service onPushDescriptor:(TLCallDescriptor *)descriptor];
}

- (void)onPopDescriptorWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopDescriptorWithRequestId: %lld conversation: %@ descriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    if ([descriptor getType] != TLDescriptorTypeCallDescriptor) {
        return;
    }
    
    [self.service onPopDescriptor:(TLCallDescriptor *)descriptor];
}

- (void)onUpdateDescriptorWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType {
    DDLogVerbose(@"%@ onUpdateDescriptorWithRequestId: %lld conversation: %@ descriptor: %@ updateType: %u", LOG_TAG, requestId, conversation, descriptor, updateType);
    
    if ([descriptor getType] != TLDescriptorTypeCallDescriptor) {
        return;
    }
    
    [self.service onUpdateDescriptor:(TLCallDescriptor *)descriptor];
}

- (void)onDeleteDescriptorsWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors {
    DDLogVerbose(@"%@ onDeleteDescriptorsWithRequestId: %lld conversation: %@ descriptors: %@", LOG_TAG, requestId, conversation, descriptors);
    
    // We can delete the audio/video call descriptors but we want to be notified for any delete anyway.
    [self.service finishOperation:requestId];

    [self.service onDeleteDescriptors:descriptors];
}

@end

//
// Implementation: CallsService
//

#undef LOG_TAG
#define LOG_TAG @"CallsService"

@implementation CallsService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <CallsServiceDelegate>)delegate originator:(nullable id<TLOriginator>)originator {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@ originator: %@", LOG_TAG, twinmeContext, delegate, originator);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _beforeTimestamp = INT64_MAX;
        _getDescriptorsDone = NO;
        _conversationServiceDelegate = [[CallsServiceConversationServiceDelegate alloc] initWithService:self];
        _originators = [[NSMutableDictionary alloc] init];
        _originatorTwincodes = [[NSMutableSet alloc] init];
        _originator = originator;
        self.twinmeContextDelegate = [[CallsServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
        if (originator) {
            [self.originatorTwincodes addObject:originator.twincodeOutboundId];
            [self.originators setObject:originator forKey:originator.uuid];
        }
    }
    return self;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getConversationService] addDelegate:self.conversationServiceDelegate];
    [super onTwinlifeReady];
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];
    [super dispose];
}

- (void)countCallReceivers {
    DDLogVerbose(@"%@ countCallReceivers", LOG_TAG);
    
    self.work |= COUNT_CALL_RECEIVERS;
    self.state &= ~(COUNT_CALL_RECEIVERS | COUNT_CALL_RECEIVERS_DONE);
    
    [self startOperation];
}

- (void)getCallsDescriptors {
    DDLogVerbose(@"%@ getCallsDescriptors", LOG_TAG);

    self.getDescriptorsDone = NO;
    self.state &= ~(GET_CURRENT_SPACE | GET_CURRENT_SPACE_DONE);
    self.state &= ~(GET_CONTACTS | GET_CONTACTS_DONE);
    self.state &= ~(GET_CALL_RECEIVERS | GET_CALL_RECEIVERS_DONE);
    self.state &= ~(GET_GROUPS | GET_GROUPS_DONE);
    self.state &= ~(GET_DESCRIPTORS | GET_DESCRIPTORS_DONE);

    [self showProgressIndicator];
    [self startOperation];
}

- (void)getPreviousDescriptors {
    DDLogVerbose(@"%@ getPreviousDescriptors", LOG_TAG);
    
    if (self.getDescriptorsDone) {
        return;
    }
    
    self.state &= ~(GET_DESCRIPTORS | GET_DESCRIPTORS_DONE);
    [self startOperation];
}

- (void)deleteCallDescriptor:(nonnull TLCallDescriptor *)descriptor {
    DDLogVerbose(@"%@ deleteCallDescriptor: %@", LOG_TAG, descriptor);

    TLDescriptorId *descriptorId = descriptor.descriptorId;
    int64_t requestId = [self newOperation:DELETE_DESCRIPTOR];
    DDLogVerbose(@"%@ deleteCallDescriptor: %lld conversationId: %@", LOG_TAG, requestId, descriptorId);

    [self showProgressIndicator];
    [self.twinmeContext deleteDescriptorWithRequestId:requestId descriptorId:descriptorId];
}

- (BOOL)isGetDescriptorsDone {
    DDLogVerbose(@"%@ isGetDescriptorsDone", LOG_TAG);
    
    return self.getDescriptorsDone;
}

- (void)deleteCallReceiverWithCallReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ deleteCallReceiverWithCallReceiverId", LOG_TAG);

    self.work |= DELETE_CALL_RECEIVER;
    self.state &= ~(DELETE_CALL_RECEIVER | DELETE_CALL_RECEIVER_DONE);

    self.callReceiver = callReceiver;
    
    [self startOperation];
}

- (void)getGroupMembers:(nonnull id<TLOriginator>)group {
    DDLogVerbose(@"%@ getGroupMembers: %@", LOG_TAG, group);
    
    self.work |= GET_GROUP_MEMBERS;
    self.state &= ~(GET_GROUP_MEMBERS | GET_GROUP_MEMBERS_DONE);

    self.group = group;
    
    [self startOperation];
}

#pragma mark - Private methods

- (void)onSetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    if (self.space != space) {
        self.beforeTimestamp = INT64_MAX;
        self.getDescriptorsDone = NO;
        self.space = space;
        self.state &= ~(GET_CONTACTS | GET_CONTACTS_DONE);
        self.state &= ~(GET_CALL_RECEIVERS | GET_CALL_RECEIVERS_DONE);
        
        [self runOnSetCurrentSpace:space];
    }
    [self onOperation];
}

- (void)onUpdateSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpace: %@", LOG_TAG, space);
    
    [self runOnUpdateSpace:space];
    [self onOperation];
}

- (void)onGetDescriptors:(NSArray *)descriptors {
    DDLogVerbose(@"%@ onGetDescriptors: %@", LOG_TAG, descriptors);
    
    self.state |= GET_DESCRIPTORS_DONE;
    NSMutableArray *list = [[NSMutableArray alloc] init];
    for (TLDescriptor *descriptor in descriptors) {
        if (descriptor.createdTimestamp < self.beforeTimestamp) {
            self.beforeTimestamp = descriptor.createdTimestamp;
        }
        
        // Filter the calls to keep only the calls for the current space.
        if ([self.originatorTwincodes containsObject:descriptor.descriptorId.twincodeOutboundId]) {
            [list addObject:descriptor];
        }
    }
    
    if (descriptors.count < MAX_OBJECTS) {
        self.getDescriptorsDone = YES;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<CallsServiceDelegate>)self.delegate onGetDescriptors:list];
    });
}

- (void)onPushDescriptor:(TLCallDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPushDescriptor: %@", LOG_TAG, descriptor);

    if ([self.originatorTwincodes containsObject:descriptor.descriptorId.twincodeOutboundId]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CallsServiceDelegate>)self.delegate onAddDescriptor:descriptor];
        });
    }
    [self onOperation];
}

- (void)onPopDescriptor:(TLCallDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopDescriptor: %@", LOG_TAG, descriptor);
    
    if ([self.originatorTwincodes containsObject:descriptor.descriptorId.twincodeOutboundId]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CallsServiceDelegate>)self.delegate onAddDescriptor:descriptor];
        });
    }
}

- (void)onUpdateDescriptor:(TLCallDescriptor *)descriptor {
    DDLogVerbose(@"%@ onUpdateDescriptor: %@", LOG_TAG, descriptor);
    
    if ([self.originatorTwincodes containsObject:descriptor.descriptorId.twincodeOutboundId]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CallsServiceDelegate>)self.delegate onUpdateDescriptor:descriptor];
        });
    }
}

- (void)onDeleteDescriptors:(NSSet<TLDescriptorId *> *)descriptors {
    DDLogVerbose(@"%@ onDeleteDescriptors: %@", LOG_TAG, descriptors);
    
    NSMutableSet<TLDescriptorId *> *deleteList = nil;
    for (TLDescriptorId *descriptorId in descriptors) {
        if ([self.originatorTwincodes containsObject:descriptorId.twincodeOutboundId]) {
            if (!deleteList) {
                deleteList = [[NSMutableSet alloc] init];
            }
            [deleteList addObject:descriptorId];
        }
    }
    if (deleteList) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CallsServiceDelegate>)self.delegate onDeleteDescriptors:deleteList];
        });
    }
    
    [self onOperation];
}

- (void)onGetCallReceivers:(NSArray<TLCallReceiver *> *)callReceivers {
    DDLogVerbose(@"%@ onGetCallReceivers: %@", LOG_TAG, callReceivers);
    
    self.state |= GET_CALL_RECEIVERS_DONE;
    for (TLCallReceiver *callReceiver in callReceivers) {
        [self.originators setObject:callReceiver forKey:callReceiver.uuid];
        [self.originatorTwincodes addObject:callReceiver.twincodeOutboundId];
    }
    
    if (self.originators.count > 0) {
        self.state &= ~(GET_DESCRIPTORS | GET_DESCRIPTORS_DONE);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<CallsServiceDelegate>)self.delegate onGetCallReceivers:callReceivers];
    });
    [self onOperation];
}

- (void)onCreateCallReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onCreateCallReceiver: %@", LOG_TAG, callReceiver);

    if (!callReceiver.isTransfer) {
        [self.originators setObject:callReceiver forKey:callReceiver.uuid];
        [self.originatorTwincodes addObject:callReceiver.twincodeOutboundId];

        dispatch_async(dispatch_get_main_queue(), ^{
            [(id <CallsServiceDelegate>) self.delegate onCreateCallReceiver:callReceiver];
        });
    }
}

- (void)onUpdateCallReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onUpdateCallReceiver: %@", LOG_TAG, callReceiver);

    [self.originators setObject:callReceiver forKey:callReceiver.uuid];
    [self.originatorTwincodes addObject:callReceiver.twincodeOutboundId];

    dispatch_async(dispatch_get_main_queue(), ^{
        [(id <CallsServiceDelegate>) self.delegate onUpdateCallReceiver:callReceiver];
    });
}

- (void)onDeleteCallReceiver:(nonnull NSUUID *)callReceiverId {
    DDLogVerbose(@"%@ onDeleteCallReceiver: %@", LOG_TAG, callReceiverId);
    
    self.state |= DELETE_CALL_RECEIVER_DONE;
    
    TLCallReceiver *callReceiver = (TLCallReceiver *)self.originators[callReceiverId];
    
    if(callReceiver){
        [self.originators removeObjectForKey:callReceiverId];
        if (callReceiver.twincodeOutboundId) {
            [self.originatorTwincodes removeObject:callReceiver.twincodeOutboundId];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [(id <CallsServiceDelegate>) self.delegate onDeleteCallReceiver:callReceiverId];
        });
    }
}

- (void)onGetContacts:(NSArray<TLContact *> *)contacts {
    DDLogVerbose(@"%@ onGetContacts: %@", LOG_TAG, contacts);
    
    self.state |= GET_CONTACTS_DONE;
    [self.originators removeAllObjects];
    [self.originatorTwincodes removeAllObjects];
    for (TLContact *contact in contacts) {
        [self.originators setObject:contact forKey:contact.uuid];
        [self.originatorTwincodes addObject:contact.twincodeOutboundId];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<CallsServiceDelegate>)self.delegate onGetOriginators:contacts];
    });
    [self onOperation];
}

- (void)onGetGroups:(NSArray<TLGroup *> *)groups {
    DDLogVerbose(@"%@ onGetGroups: %@", LOG_TAG, groups);
    
    self.state |= GET_GROUPS_DONE;
    for (TLGroup *group in groups) {
        [self.originators setObject:group forKey:group.uuid];
        [self.originatorTwincodes addObject:group.twincodeOutboundId];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<CallsServiceDelegate>)self.delegate onGetOriginators:groups];
    });
    [self onOperation];
}

- (void)onCreateOriginator:(nonnull id<TLOriginator>)originator {
    DDLogVerbose(@"%@ onCreateContact: %@", LOG_TAG, originator);
    
    if (self.space == originator.space) {
        [self.originators setObject:originator forKey:originator.uuid];
        [self.originatorTwincodes addObject:originator.twincodeOutboundId];
        UIImage *avatar = [self getImageWithContact:originator];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CallsServiceDelegate>)self.delegate onCreateOriginator:originator avatar:avatar];
        });
    }
}

- (void)onUpdateOriginator:(nonnull id<TLOriginator>)originator {
    DDLogVerbose(@"%@ onUpdateOriginator: %@", LOG_TAG, originator);
    
    if (self.space == originator.space) {
        [self.originators setObject:originator forKey:originator.uuid];
        [self.originatorTwincodes addObject:originator.twincodeOutboundId];
        UIImage *avatar = [self getImageWithContact:originator];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CallsServiceDelegate>)self.delegate onUpdateOriginator:originator avatar:avatar];
        });
    }
}

- (void)onMoveOriginator:(nonnull id<TLOriginator>)originator {
    DDLogVerbose(@"%@ onMoveOriginator: %@", LOG_TAG, originator);
    
    if (self.space != originator.space) {
        [self.originators removeObjectForKey:originator.uuid];
        if (originator.twincodeOutboundId) {
            [self.originatorTwincodes removeObject:originator.twincodeOutboundId];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CallsServiceDelegate>)self.delegate onDeleteOriginator:originator];
        });
    }
}

- (void)onDeleteOriginator:(nonnull NSUUID *)originatorId {
    DDLogVerbose(@"%@ onDeleteOriginator: %@", LOG_TAG, originatorId);
    
    id<TLOriginator> originator = self.originators[originatorId];
    if (originator) {
        [self.originators removeObjectForKey:originatorId];
        if (originator.twincodeOutboundId) {
            [self.originatorTwincodes removeObject:originator.twincodeOutboundId];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CallsServiceDelegate>)self.delegate onDeleteOriginator:originator];
        });
    }
}

- (void)onResetConversation:(nonnull id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode {
    DDLogVerbose(@"%@ onResetConversation: %@ clearMode: %d", LOG_TAG, conversation, clearMode);
    
    TLContact *contact = (TLContact *)self.originators[conversation.contactId];
    if (contact) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CallsServiceDelegate>)self.delegate onResetConversation:conversation clearMode:clearMode];
        });
    }
    [self onOperation];
}

- (void)onGetGroupMembers:(nonnull NSMutableArray<id<TLGroupMemberConversation>> *)members {
    DDLogVerbose(@"%@ onGetGroupMembers: %@", LOG_TAG, members);
    
    self.state |= GET_GROUP_MEMBERS_DONE;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<CallsServiceDelegate>)self.delegate onGetGroupMembers:members];
    });
}

- (void)onGetCountCallReceivers:(int)countCallReceivers {
    DDLogVerbose(@"%@ onGetCountCallReceivers: %d", LOG_TAG, countCallReceivers);
    
    self.state |= COUNT_CALL_RECEIVERS_DONE;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<CallsServiceDelegate>)self.delegate onGetCountCallReceivers:countCallReceivers];
    });
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    //
    // Step 1: get the current space.
    //
    if ((self.state & GET_CURRENT_SPACE) == 0) {
        self.state |= GET_CURRENT_SPACE;

        [self.twinmeContext getCurrentSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
            self.state |= GET_CURRENT_SPACE_DONE;
            self.space = space;
            [self runOnGetSpace:space avatar:nil];
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_CURRENT_SPACE_DONE) == 0) {
        return;
    }
    
    //
    // Step 2: Get the list of contacts.
    //
    if (self.originator) {
        if ((self.state & GET_CONTACT_THUMBNAIL_IMAGE) == 0) {
            self.state |= GET_CONTACT_THUMBNAIL_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.originator.avatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                self.state |= GET_CONTACT_THUMBNAIL_IMAGE_DONE;
                if (status != TLBaseServiceErrorCodeSuccess || !image) {
                    if (self.originator.isGroup) {
                        image = [TLTwinmeAttributes DEFAULT_GROUP_AVATAR];
                    } else {
                        image = [TLContact ANONYMOUS_AVATAR];
                    }
                }
                [self runOnRefreshContactAvatar:image];
                [self onOperation];
            }];
            
            return;
        }
        
        if ((self.state & GET_CONTACT_THUMBNAIL_IMAGE_DONE) == 0) {
            return;
        }

        if ((self.state & GET_CONVERSATION) == 0) {
            self.state |= GET_CONVERSATION;
            self.conversation = [[self.twinmeContext getConversationService] getConversationWithSubject:self.originator];
        }
    } else {
        if ((self.state & GET_CONTACTS) == 0) {
            self.state |= GET_CONTACTS;
            
            [self.twinmeContext findContactsWithFilter:[self.twinmeContext createSpaceFilter] withBlock:^(NSMutableArray<TLContact *> *contacts) {
                [self onGetContacts:contacts];
            }];
            return;
        }
        if ((self.state & GET_CONTACTS_DONE) == 0) {
            return;
        }
        
        if ((self.state & GET_CALL_RECEIVERS) == 0) {
            self.state |= GET_CALL_RECEIVERS;
            
            TLFilter *filter = [self.twinmeContext createSpaceFilter];
            filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLCallReceiver *callReceiver = (TLCallReceiver *)object;
                return !callReceiver.isTransfer;
            };
            [self.twinmeContext findCallReceiversWithFilter:filter withBlock:^(NSMutableArray<TLCallReceiver *> *callReceivers) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self onGetCallReceivers:callReceivers];
                });
            }];
            return;
        }
        if ((self.state & GET_CALL_RECEIVERS_DONE) == 0) {
            return;
        }
        
        if ((self.state & GET_GROUPS) == 0) {
            self.state |= GET_GROUPS;
            
            [self.twinmeContext findGroupsWithFilter:[self.twinmeContext createSpaceFilter] withBlock:^(NSMutableArray<TLGroup *> *groups) {
                [self onGetGroups:groups];
            }];
            return;
        }
        if ((self.state & GET_GROUPS_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 3: Get the audio/video descriptors.
    //
    if ((self.state & GET_DESCRIPTORS) == 0) {
        self.state |= GET_DESCRIPTORS;
        
        NSArray<TLDescriptor *> *descriptors;
        
        if (self.conversation) {
            descriptors = [[self.twinmeContext getConversationService] getDescriptorsWithConversation:self.conversation descriptorType:TLDescriptorTypeCallDescriptor callsMode:TLDisplayCallsModeAll beforeTimestamp:self.beforeTimestamp maxDescriptors:MAX_OBJECTS];
        } else {
            descriptors = [[self.twinmeContext getConversationService] getDescriptorsWithDescriptorType:TLDescriptorTypeCallDescriptor callsMode:TLDisplayCallsModeAll beforeTimestamp:self.beforeTimestamp maxDescriptors:MAX_OBJECTS];
        }
        [self onGetDescriptors:descriptors];
        self.state |= GET_DESCRIPTORS_DONE;
    }
    
    //
    // Work step: delete a call receiver.
    //
    if ((self.work & DELETE_CALL_RECEIVER) != 0) {
        if ((self.state & DELETE_CALL_RECEIVER) == 0) {
            self.state |= DELETE_CALL_RECEIVER;
            
            int64_t requestId = [self newOperation:DELETE_CALL_RECEIVER];
            DDLogVerbose(@"%@ deleteCallReceiverWithRequestId: %lld", LOG_TAG, requestId);
            [self.twinmeContext deleteCallReceiverWithRequestId:requestId callReceiver:self.callReceiver];
            return;
        }
        if ((self.state & DELETE_CALL_RECEIVER_DONE) == 0) {
            return;
        }
    }
    
    //
    // Work step: get group member
    //
    if ((self.work & GET_GROUP_MEMBERS) != 0 && self.group) {
        if ((self.state & GET_GROUP_MEMBERS) == 0) {
            self.state |= GET_GROUP_MEMBERS;

            id<TLGroupConversation> groupConversation = (id<TLGroupConversation>)[[self.twinmeContext getConversationService] getConversationWithSubject:self.group];
            NSMutableArray<id<TLGroupMemberConversation>> *members = [groupConversation groupMembersWithFilter:TLGroupMemberFilterTypeJoinedMembers];
            [self onGetGroupMembers:members];
            return;
        }
        if ((self.state & GET_GROUP_MEMBERS_DONE) == 0) {
            return;
        }
    }
    
    //
    // Work step: count all call receivers
    //
    if ((self.work & COUNT_CALL_RECEIVERS) != 0) {
        if ((self.state & COUNT_CALL_RECEIVERS) == 0) {
            self.state |= COUNT_CALL_RECEIVERS;

            TLFilter *filter = [[TLFilter alloc]init];
            filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLCallReceiver *callReceiver = (TLCallReceiver *)object;
                return !callReceiver.isTransfer;
            };
            [self.twinmeContext findCallReceiversWithFilter:filter withBlock:^(NSMutableArray<TLCallReceiver *> *callReceivers) {
                [self onGetCountCallReceivers:(int)callReceivers.count];
            }];
            return;
        }
        if ((self.state & COUNT_CALL_RECEIVERS_DONE) == 0) {
            return;
        }
    }
    
    
    
    [self hideProgressIndicator];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // We can ignore the error if we try to delete a descriptor that does not exist.
    if (errorCode == TLBaseServiceErrorCodeItemNotFound && operationId == DELETE_DESCRIPTOR) {
        return;
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
