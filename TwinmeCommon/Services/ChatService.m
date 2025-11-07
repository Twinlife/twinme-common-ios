/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLFilter.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLGroupMember.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLGroupMember.h>

#import "ChatService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int MAX_OBJECTS = 100;

static const int GET_CURRENT_SPACE = 1 << 0;
static const int GET_CURRENT_SPACE_DONE = 1 << 1;
static const int GET_CONTACTS = 1 << 2;
static const int GET_CONTACTS_DONE = 1 << 3;
static const int GET_GROUPS = 1 << 4;
static const int GET_GROUPS_DONE = 1 << 5;
static const int GET_CONVERSATIONS = 1 << 6;
static const int GET_CONVERSATIONS_DONE = 1 << 7;
static const int RESET_CONVERSATION = 1 << 8;
static const int GET_GROUP_MEMBER = 1 << 9;
static const int GET_GROUP_MEMBER_DONE = 1 << 10;
static const int FIND_CONVERSATIONS = 1 << 11;
static const int FIND_CONVERSATIONS_DONE = 1 << 12;

//
// Interface: ChatService ()
//

@class ChatServiceTwinmeContextDelegate;
@class ChatServiceConversationServiceDelegate;

@interface ChatService ()

@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic) int work;

@property (nonatomic, readonly, nonnull) NSMutableArray<id <TLConversation>> *conversations;
@property (nonatomic, readonly, nonnull) NSMutableArray<GroupMemberQuery *> *groupMemberConversations;
@property (nonatomic, readonly, nonnull) NSMutableSet<NSUUID *> *originatorIds;
@property (nonatomic, nullable) GroupMemberQuery *currentGroupMember;
@property (nonatomic, nullable) ChatServiceConversationServiceDelegate *conversationServiceDelegate;

@property (nonatomic) int64_t beforeTimestamp;
@property (nonatomic) BOOL getDescriptorsDone;
@property (nonatomic, nullable) NSString *findName;
@property (nonatomic) TLDisplayCallsMode callsMode;

- (void)onOperation;

- (void)onTwinlifeReady;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

- (void)onUpdateSpace:(nonnull TLSpace *)space;

- (void)onCreateContact:(nonnull TLContact *)contact;

- (void)onUpdateContact:(nonnull TLContact *)contact;

- (void)onMoveContact:(nonnull TLContact *)contact oldSpace:(nonnull TLSpace *)oldSpace;

- (void)onDeleteContact:(nonnull NSUUID *)contactId;

- (void)onGetGroupMember:(nonnull TLGroupMember *)member;

- (void)onCreateGroup:(nonnull TLGroup *)group conversation:(nonnull id<TLGroupConversation>)conversation;

- (void)onMoveGroup:(nonnull TLGroup *)group oldSpace:(nonnull TLSpace *)oldSpace;

- (void)onUpdateGroup:(nonnull TLGroup *)group;

- (void)onDeleteGroup:(nonnull NSUUID *)groupId;

- (void)onDeleteConversation:(nonnull NSUUID *)conversationId;

- (void)onDeleteGroupConversation:(nonnull NSUUID *)conversationId groupId:(nonnull NSUUID *)groupId;

- (void)onGetOrCreateConversation:(nonnull id <TLConversation>)conversation;

- (void)onJoinGroup:(nonnull id <TLGroupConversation>)group memberId:(nullable NSUUID *)memberId;

- (void)onLeaveGroup:(nonnull id <TLGroupConversation>)group memberId:(NSUUID *)memberId;

- (void)onResetConversation:(nonnull id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode;

- (void)onPushDescriptor:(TLDescriptor *)descriptor conversation:(nonnull id <TLConversation>)conversation;

- (void)onPopDescriptor:(TLDescriptor *)descriptor conversation:(nonnull id <TLConversation>)conversation;

- (void)onUpdateDescriptor:(TLDescriptor *)descriptor conversation:(nonnull id <TLConversation>)conversation;

- (void)onDeleteDescriptors:(NSSet<TLDescriptorId *> *)descriptors conversation:(nonnull id <TLConversation>)conversation;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Implementation: GroupMemberQuery
//

#undef LOG_TAG
#define LOG_TAG @"GroupMemberQuery"

@implementation GroupMemberQuery

- (instancetype)initWithGroup:(TLGroup *)group memberTwincodeOutboundId:(NSUUID *)memberTwincodeOutboundId {
    DDLogVerbose(@"%@ initWithGroup: %@ memberTwincodeOutboundId:%@", LOG_TAG, group, memberTwincodeOutboundId);
    
    self = [super init];
    
    if (self) {
        _group = group;
        _memberTwincodeOutboundId = memberTwincodeOutboundId;
    }
    return self;
}

@end

//
// Interface: ChatServiceTwinmeContextDelegate
//

@interface ChatServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ChatService *)service;

@end

//
// Implementation: ChatServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ChatServiceTwinmeContextDelegate"

@implementation ChatServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ChatService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onSetCurrentSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(ChatService *)self.service onSetCurrentSpace:space];
}

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(ChatService *)self.service onUpdateSpace:space];
}

- (void)onCreateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onCreateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    [(ChatService *)self.service onCreateContact:contact];
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    [(ChatService *)self.service onUpdateContact:contact];
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact oldSpace:(nonnull TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld contact: %@ oldSpace: %@", LOG_TAG, requestId, contact, oldSpace);
    
    [(ChatService *)self.service onMoveContact:contact oldSpace:oldSpace];
}

- (void)onDeleteContactWithRequestId:(int64_t)requestId contactId:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contactId);
    
    [(ChatService *)self.service onDeleteContact:contactId];
}

- (void)onCreateGroupWithRequestId:(int64_t)requestId group:(TLGroup *)group conversation:(id<TLGroupConversation>)conversation {
    DDLogVerbose(@"%@ onCreateGroupWithRequestId: %lld group: %@ conversation: %@", LOG_TAG, requestId, group, conversation);
    
    [(ChatService *)self.service onCreateGroup:group conversation:conversation];
}

- (void)onDeleteGroupWithRequestId:(int64_t)requestId groupId:(NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, groupId);
    
    [(ChatService *)self.service onDeleteGroup:groupId];
}

- (void)onUpdateGroupWithRequestId:(int64_t)requestId group:(TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, group);
    
    [(ChatService *)self.service onUpdateGroup:group];
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId group:(TLGroup *)group oldSpace:(TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld group: %@ oldSpace: %@", LOG_TAG, requestId, group, oldSpace);
    
    [(ChatService *)self.service onMoveGroup:group oldSpace:oldSpace];
}

- (void)onDeleteConversationWithRequestId:(int64_t)requestId conversationId:(NSUUID *)conversationId {
    DDLogVerbose(@"%@ onDeleteConversationWithRequestId: %lld conversationId: %@", LOG_TAG, requestId, conversationId);
    
    [(ChatService *)self.service onDeleteConversation:conversationId];
}

@end

//
// Interface: ChatServiceConversationServiceDelegate
//

@interface ChatServiceConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) ChatService *service;

- (nonnull instancetype)initWithService:(nonnull ChatService *)service;

@end

//
// Implementation: ChatServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ChatServiceConversationServiceDelegate"

@implementation ChatServiceConversationServiceDelegate

- (instancetype)initWithService:(ChatService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onGetOrCreateConversationWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onGetOrCreateConversationWithRequestId: %lld conversation: %@", LOG_TAG, requestId, conversation);
    
    [self.service onGetOrCreateConversation:conversation];
}

- (void)onPushDescriptorRequestId:(int64_t)requestId conversation:(id<TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPushDescriptorRequestId: %lld conversation: %@ descriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    [self.service onPushDescriptor:descriptor conversation:conversation];
}

- (void)onPopDescriptorWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopDescriptorWithRequestId: %lld conversation: %@ descriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    [self.service onPopDescriptor:descriptor conversation:conversation];
}

- (void)onUpdateDescriptorWithRequestId:(int64_t)requestId conversation:(id<TLConversation>)conversation descriptor:(TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType {
    DDLogVerbose(@"%@ onUpdateDescriptorWithRequestId: %lld conversation: %@ descriptor: %@ updateType: %u", LOG_TAG, requestId, conversation, descriptor, updateType);
    
    if (updateType == TLConversationServiceUpdateTypeContent && descriptor.getType != TLDescriptorTypeObjectDescriptor) {
        return;
    }
    
    [self.service onUpdateDescriptor:descriptor conversation:conversation];
}

- (void)onMarkDescriptorReadWithRequestId:(int64_t)requestId conversation:(id<TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onMarkDescriptorReadWithRequestId: %lld conversation: %@ descriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    [self.service onPopDescriptor:descriptor conversation:conversation];
}

- (void)onDeleteDescriptorsWithRequestId:(int64_t)requestId conversation:(id<TLConversation>)conversation descriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors {
    DDLogVerbose(@"%@ onDeleteDescriptorsWithRequestId: %lld conversation: %@ descriptors: %@", LOG_TAG, requestId, conversation, descriptors);
    
    [self.service onDeleteDescriptors:descriptors conversation:conversation];
}

- (void)onJoinGroupRequestWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onJoinGroupWithRequestId: %lld group: %@ invitation: %@ memberId: %@", LOG_TAG, requestId, group, invitation, memberId);
    
    [self.service onJoinGroup:group memberId:memberId];
}

- (void)onJoinGroupResponseWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onJoinGroupResponseWithRequestId: %lld group: %@ invitation: %@", LOG_TAG, requestId, group, invitation);
    
    [self.service onJoinGroup:group memberId:nil];
}

- (void)onLeaveGroupWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onLeaveGroupWithRequestId: %lld group: %@ memberId: %@", LOG_TAG, requestId, group, memberId);
    
    [self.service onLeaveGroup:group memberId:memberId];
}

- (void)onResetConversationWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode {
    DDLogVerbose(@"%@ onResetConversationWithRequestId: %lld conversation: %@ clearMode: %d", LOG_TAG, requestId, conversation, clearMode);
    
    [self.service onResetConversation:conversation clearMode:clearMode];
}

- (void)onDeleteGroupConversationWithRequestId:(int64_t)requestId conversationId:(NSUUID *)conversationId groupId:(NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroupConversationWithRequestId: %lld conversationId: %@ groupId: %@", LOG_TAG, requestId, conversationId, groupId);
    
    [self.service onDeleteGroupConversation:conversationId groupId:groupId];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [self.service onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Implementation: ChatService
//

#undef LOG_TAG
#define LOG_TAG @"ChatService"

@implementation ChatService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext callsMode:(TLDisplayCallsMode)callsMode delegate:(nonnull id <ChatServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _groupMemberConversations = [[NSMutableArray alloc]init];
        _conversations = [[NSMutableArray alloc]init];
        _conversationServiceDelegate = [[ChatServiceConversationServiceDelegate alloc] initWithService:self];
        _originatorIds = [[NSMutableSet alloc] init];
        _callsMode = callsMode;
        self.twinmeContextDelegate = [[ChatServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];
    
    [super dispose];
}

- (void)getConversationsWithCallsMode:(TLDisplayCallsMode)callsMode {
    DDLogVerbose(@"%@ getConversations", LOG_TAG);
    
    self.findName = nil;
    self.callsMode = callsMode;
    self.state &= ~(GET_CURRENT_SPACE | GET_CURRENT_SPACE_DONE);
    self.state &= ~(GET_CONTACTS | GET_CONTACTS_DONE);
    self.state &= ~(GET_GROUPS | GET_GROUPS_DONE);
    self.state &= ~(GET_CONVERSATIONS | GET_CONVERSATIONS_DONE);
    self.state &= ~(GET_GROUP_MEMBER | GET_GROUP_MEMBER_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)findConversationsByName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ findSpaceByName: %@", LOG_TAG, name);
    
    self.findName = [name.lowercaseString stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
    self.work = FIND_CONVERSATIONS;
    self.state &= ~(FIND_CONVERSATIONS | FIND_CONVERSATIONS_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)searchDescriptorsByContent:(nonnull NSString *)content clearSearch:(BOOL)clearSearch withBlock:(nonnull void (^)(NSArray<TLConversationDescriptorPair *> *_Nullable descriptors))block {
    DDLogVerbose(@"%@ searchDescriptorsByContent: %@", LOG_TAG, content);
            
    if (clearSearch) {
        self.beforeTimestamp = INT64_MAX;
        self.getDescriptorsDone = NO;
    }
    
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        NSArray<TLConversationDescriptorPair *> *descriptors = [[self.twinmeContext getConversationService] searchDescriptorsWithConversations:self.conversations searchText:content.lowercaseString beforeTimestamp:self.beforeTimestamp maxDescriptors:MAX_OBJECTS];
        
        if (!descriptors || descriptors.count < MAX_OBJECTS) {
            self.getDescriptorsDone = YES;
        }
        
        if (descriptors && descriptors.count > 0) {
            TLConversationDescriptorPair *descriptorPair = [descriptors lastObject];
            TLDescriptor *descriptor = descriptorPair.descriptor;
            self.beforeTimestamp = descriptor.createdTimestamp;
        }
       
        dispatch_async(dispatch_get_main_queue(), ^{
            block(descriptors);
        });
    });
}

- (BOOL)isGetDescriptorDone {
    DDLogVerbose(@"%@ isGetDescriptorDone", LOG_TAG);
    
    return self.getDescriptorsDone;
}

- (void)getLastDescriptorWithConversation:(nonnull id<TLConversation>)conversation withBlock:(nonnull void (^)(TLDescriptor *_Nullable descriptor))block {
    DDLogVerbose(@"%@ getLastDescriptorWithConversation: %@", LOG_TAG, conversation);

    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        NSArray<TLDescriptor *> *descriptors = [[self.twinmeContext getConversationService] getDescriptorsWithConversation:conversation callsMode:self.callsMode beforeTimestamp:INT64_MAX maxDescriptors:1];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (descriptors.count > 0) {
                block([descriptors objectAtIndex:0]);
            } else {
                block(nil);
            }
        });
    });
}

- (void)getGroupMembers:(nonnull TLGroup *)group members:(nonnull NSArray *)members {
    DDLogVerbose(@"%@ getGroupMembers %@ members:%@", LOG_TAG, group, members);

    // Run from the twinlife executor thread since we must update the groupMemberConversations dictionary.
    // (otherwise, there is a concurrency issue).
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        for (NSUUID *member in members) {
            [self.groupMemberConversations addObject:[[GroupMemberQuery alloc]initWithGroup:group memberTwincodeOutboundId:member]];
        }
        if ((self.state & GET_GROUP_MEMBER_DONE) != 0) {
            self.state &= ~(GET_GROUP_MEMBER | GET_GROUP_MEMBER_DONE);
        }
        if (!self.currentGroupMember) {
            [self nextGroupMember];
        }
        [self onOperation];
    });
}

- (void)resetConversation:(nonnull id<TLOriginator>)originator {
    DDLogVerbose(@"%@ resetConversation: %@", LOG_TAG, originator);
    
    id<TLConversation> conversation = [[self.twinmeContext getConversationService] getConversationWithSubject:originator];
    if (conversation) {
        [[self.twinmeContext getConversationService] clearConversationWithConversation:conversation clearDate:0 clearMode:TLConversationServiceClearBoth];
    }
}

#pragma mark - Private methods

- (void)onSetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    // Switching to a new space, fetch again the contacts, groups, conversations.
    if (self.space != space) {
        self.findName = nil;
        self.space = space;
        self.state &= ~(GET_CONTACTS | GET_CONTACTS_DONE);
        self.state &= ~(GET_GROUPS | GET_GROUPS_DONE);
        self.state &= ~(GET_CONVERSATIONS | GET_CONVERSATIONS_DONE);
        self.state &= ~(GET_GROUP_MEMBER | GET_GROUP_MEMBER_DONE);
        self.currentGroupMember = nil;
        [self.originatorIds removeAllObjects];
        [self.groupMemberConversations removeAllObjects];
    }
    [self runOnSetCurrentSpace:space];
    [self onOperation];
}

- (void)onUpdateSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpace: %@", LOG_TAG, space);
    
    [self runOnUpdateSpace:space];
    [self onOperation];
}

- (void)nextGroupMember {
    DDLogVerbose(@"%@ nextGroupMember", LOG_TAG);
    
    if (self.groupMemberConversations.count == 0) {
        self.state |= GET_GROUP_MEMBER | GET_GROUP_MEMBER_DONE;
    } else {
        self.currentGroupMember = [self.groupMemberConversations objectAtIndex:0];
        [self.groupMemberConversations removeObjectAtIndex:0];
        self.state &= ~(GET_GROUP_MEMBER | GET_GROUP_MEMBER_DONE);
    }
}

- (void)onGetGroupMember:(TLGroupMember *)member {
    DDLogVerbose(@"%@ onGetGroupMember: %@", LOG_TAG, member);
    
    self.state |= GET_GROUP_MEMBER_DONE;
    if (member) {
        UIImage *avatar = [self getImageWithGroupMember:member];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ChatServiceDelegate>)self.delegate onGetGroupMember:member.peerTwincodeOutboundId member:member avatar:avatar];
        });
    }
    [self nextGroupMember];
    [self onOperation];
}

- (void)onCreateContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onCreateContact: %@", LOG_TAG, contact);
    
    if (self.space == contact.space) {
        [self.originatorIds addObject:contact.uuid];
        
        UIImage *avatar = [self getImageWithContact:contact];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ChatServiceDelegate>)self.delegate onCreateContact:contact avatar:avatar];
        });
    }
}

- (void)onUpdateContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContact: %@", LOG_TAG, contact);
    
    if (self.space == contact.space) {
        
        UIImage *avatar = [self getImageWithContact:contact];
        [self runOnUpdateContact:contact avatar:avatar];
    }
}

- (void)onMoveContact:(nonnull TLContact *)contact oldSpace:(nonnull TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveContact: %@ oldSpace: %@", LOG_TAG, contact, oldSpace);
    
    if (self.space != contact.space) {
        [self onDeleteContact:contact.uuid];
    }
}

- (void)onDeleteContact:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContact: %@", LOG_TAG, contactId);
    
    [self.originatorIds removeObject:contactId];
    [self runOnDeleteContact:contactId];
}

- (void)onCreateGroup:(TLGroup *)group conversation:(nonnull id<TLGroupConversation>)conversation {
    DDLogVerbose(@"%@ onCreateGroup: %@ conversation: %@", LOG_TAG, group, conversation);
    
    if (self.space == group.space) {
        
        if (![self.conversations containsObject:conversation]) {
            [self.conversations addObject:conversation];
        }
        
        [self.originatorIds addObject:group.uuid];
        
        UIImage *avatar = [self getImageWithGroup:group];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ChatServiceDelegate>)self.delegate onCreateGroup:group conversation:conversation avatar:avatar];
        });
    }
}

- (void)onUpdateGroup:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroup: %@", LOG_TAG, group);
    
    if (self.space == group.space) {
        UIImage *avatar = [self getImageWithGroup:group];
        [self runOnUpdateGroup:group avatar:avatar];
    }
}

- (void)onMoveGroup:(nonnull TLGroup *)group oldSpace:(nonnull TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveGroup: %@ oldSpace: %@", LOG_TAG, group, oldSpace);
    
    if (self.space != group.space) {
        [self onDeleteGroup:group.uuid];
    }
}

- (void)onDeleteGroup:(nonnull NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroup: %@", LOG_TAG, groupId);
    
    [self.originatorIds removeObject:groupId];
    [self runOnDeleteGroup:groupId];
}

- (void)onDeleteConversation:(nonnull NSUUID *)conversationId {
    DDLogVerbose(@"%@ onDeleteConversation: %@", LOG_TAG, conversationId);

    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ChatServiceDelegate>)self.delegate onDeleteConversation:conversationId];
    });
}

- (void)onDeleteGroupConversation:(nonnull NSUUID *)conversationId groupId:(nonnull NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroupConversation: %@ groupId: %@", LOG_TAG, conversationId, groupId);

    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ChatServiceDelegate>)self.delegate onDeleteConversation:conversationId];
    });
}

- (void)onGetOrCreateConversation:(nonnull id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onGetOrCreateConversation: %@", LOG_TAG, conversation);

    if (!conversation.contactId) {
        return;
    }
        
    if ([self.originatorIds containsObject:conversation.contactId]) {
        [self.conversations addObject:conversation];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ChatServiceDelegate>)self.delegate onGetOrCreateConversation:conversation];
        });
    }
}

- (void)onGetConversations:(NSArray<TLConversationDescriptorPair *>*)conversations {
    DDLogVerbose(@"%@ onGetConversations: %@", LOG_TAG, conversations);
    
    [self.conversations removeAllObjects];
    
    for (TLConversationDescriptorPair *conversationDescriptorPair in conversations) {
        [self.conversations addObject:conversationDescriptorPair.conversation];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ChatServiceDelegate>)self.delegate onGetConversations:conversations];
    });
}

- (void)onJoinGroup:(id <TLGroupConversation>)group memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onJoinGroup: %@ memberId: %@", LOG_TAG, group, memberId);
    
    if ([self.originatorIds containsObject:group.contactId] ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ChatServiceDelegate>)self.delegate onJoinGroup:group memberId:memberId];
        });
    }
}

- (void)onLeaveGroup:(id <TLGroupConversation>)group memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onLeaveGroup: %@ memberId: %@", LOG_TAG, group, memberId);
    
    if ([self.originatorIds containsObject:group.contactId]) {
        // The user has left the group, remove it from the UI.
        if ([group state] != TLGroupConversationStateJoined) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<ChatServiceDelegate>)self.delegate onDeleteConversation:group.uuid];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<ChatServiceDelegate>)self.delegate onLeaveGroup:group memberId:memberId];
            });
        }
    }
}

- (void)onResetConversation:(id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode {
    DDLogVerbose(@"%@ onResetConversation: %@ clearMode:%d", LOG_TAG, conversation, clearMode);
    
    if ([self.originatorIds containsObject:conversation.contactId]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ChatServiceDelegate>)self.delegate onResetConversation:conversation clearMode:clearMode];
        });
    }
}

- (void)onPushDescriptor:(TLDescriptor *)descriptor conversation:(id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onPushDescriptor: %@ conversation: %@", LOG_TAG, descriptor, conversation);
    
    if ([self.originatorIds containsObject:conversation.contactId]) {
        
        if (![self.conversations containsObject:conversation]) {
            [self.conversations addObject:conversation];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ChatServiceDelegate>)self.delegate onPushDescriptor:descriptor conversation:conversation];
        });
    }
}

- (void)onPopDescriptor:(TLDescriptor *)descriptor conversation:(id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onPopDescriptor: %@ conversation: %@", LOG_TAG, descriptor, conversation);
    
    if ([self.originatorIds containsObject:conversation.contactId]) {
        
        if (![self.conversations containsObject:conversation]) {
            [self.conversations addObject:conversation];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ChatServiceDelegate>)self.delegate onPopDescriptor:descriptor conversation:conversation];
        });
    }
}

- (void)onUpdateDescriptor:(TLDescriptor *)descriptor conversation:(id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onUpdateDescriptor: %@ conversation: %@", LOG_TAG, descriptor, conversation);
    
    if ([self.originatorIds containsObject:conversation.contactId]) {
        
        if (![self.conversations containsObject:conversation]) {
            [self.conversations addObject:conversation];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ChatServiceDelegate>)self.delegate onUpdateDescriptor:descriptor conversation:conversation];
        });
    }
}

- (void)onDeleteDescriptors:(NSSet<TLDescriptorId *> *)descriptors conversation:(id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onDeleteDescriptors: %@ conversation: %@", LOG_TAG, descriptors, conversation);
    
    if ([self.originatorIds containsObject:conversation.contactId]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ChatServiceDelegate>)self.delegate onDeleteDescriptors:descriptors conversation:conversation];
        });
    }
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    TWINLIFE_CHECK_THREAD("Must not run on main UI thread");

    //
    // Step 1: get the current space.
    //
    if ((self.state & GET_CURRENT_SPACE) == 0) {
        self.state |= GET_CURRENT_SPACE;

        [self.twinmeContext getCurrentSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
            self.state |= GET_CURRENT_SPACE_DONE;
            self.space = space;
            [self.originatorIds removeAllObjects];
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
    if ((self.state & GET_CONTACTS) == 0) {
        self.state |= GET_CONTACTS;

        [self.twinmeContext findContactsWithFilter:[self.twinmeContext createSpaceFilter] withBlock:^(NSMutableArray<TLContact *> *list) {
            self.state |= GET_CONTACTS_DONE;
            for (TLContact *contact in list) {
                [self.originatorIds addObject:contact.uuid];
            }
            [self runOnGetContacts:list];
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_CONTACTS_DONE) == 0) {
        return;
    }
    
    //
    // Step 3: get the list of groups before the conversations.
    //
    if ((self.state & GET_GROUPS) == 0) {
        self.state |= GET_GROUPS;

        [self.groupMemberConversations removeAllObjects];
        self.currentGroupMember = nil;
        [self.twinmeContext findGroupsWithFilter:[self.twinmeContext createSpaceFilter] withBlock:^(NSMutableArray<TLGroup *> *groups) {
            self.state |= GET_GROUPS_DONE;
            for (TLGroup *group in groups) {
                [self.originatorIds addObject:group.uuid];
            }
            [self runOnGetGroups:groups];
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_GROUPS_DONE) == 0) {
        return;
    }
    
    //
    // Step 4: get the list of conversation (will be sorted on object's usage).
    //
    if ((self.state & GET_CONVERSATIONS) == 0) {
        self.state |= GET_CONVERSATIONS;

        TLFilter *filter = [self.twinmeContext createSpaceFilter];
        [self.twinmeContext findConversationDescriptorsWithFilter:filter callsMode:self.callsMode withBlock:^(NSArray<TLConversationDescriptorPair *> *conversations) {
            self.state |= GET_CONVERSATIONS_DONE;
            
            [self onGetConversations:conversations];
            
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_CONVERSATIONS_DONE) == 0) {
        return;
    }
    
        
    //
    // Step 5: get the group members (each of them, one by one until we are done).
    //
    if (self.currentGroupMember) {
        if ((self.state & GET_GROUP_MEMBER) == 0) {
            self.state |= GET_GROUP_MEMBER;
            
            DDLogVerbose(@"%@ getGroupMemberWithOwner:%@ groupMemberTwincodeId:%@", LOG_TAG,  self.currentGroupMember.group, self.currentGroupMember.memberTwincodeOutboundId);
            [self.twinmeContext getGroupMemberWithOwner:self.currentGroupMember.group memberTwincodeId:self.currentGroupMember.memberTwincodeOutboundId withBlock:^(TLBaseServiceErrorCode errorCode, TLGroupMember *groupMember) {
                [self onGetGroupMember:groupMember];
            }];
            return;
        }
        if ((self.state & GET_GROUP_MEMBER_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 6: get the list of conversation filter by name
    //
    
    if ((self.work & FIND_CONVERSATIONS) != 0 && self.findName) {
        if ((self.state & FIND_CONVERSATIONS) == 0) {
            self.state |= FIND_CONVERSATIONS;

            TLFilter *filter = [self.twinmeContext createSpaceFilter];
            NSString *findName = self.findName;
            if (findName) {
                filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                    id<TLConversation> conversation = (id<TLConversation>)object;
                    NSString *contactName = [conversation.subject.name stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
                    return [contactName.lowercaseString containsString:findName];
                };
            }
            [self.twinmeContext findConversationDescriptorsWithFilter:filter callsMode:self.callsMode withBlock:^(NSArray<TLConversationDescriptorPair *> *conversations) {
                self.state |= FIND_CONVERSATIONS_DONE;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [(id<ChatServiceDelegate>)self.delegate onFindConversationsbyName:conversations];
                });
                [self onOperation];
            }];
            return;
        }
        if ((self.state & FIND_CONVERSATIONS_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [super onTwinlifeReady];
    
    [[self.twinmeContext getConversationService] addDelegate:self.conversationServiceDelegate];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }

    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch (operationId) {
            case GET_GROUP_MEMBER:
                [self nextGroupMember];
                return;

            case RESET_CONVERSATION:
                // Nothing to do, ignore the conversation does not exist.
                return;
                
            default:
                break;
        }
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
