/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLAccountService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLFilter.h>

#import <Twinme/TLTwinmeContext.h>

#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLGroupMember.h>
#import <Twinme/TLSpace.h>
#import "GroupService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_GROUP = 1 << 0;
static const int GET_GROUP_DONE = 1 << 1;
static const int GET_CONTACT = 1 << 2;
static const int GET_CONTACT_DONE = 1 << 3;
static const int GET_CONTACTS = 1 << 4;
static const int GET_CONTACTS_DONE = 1 << 5;
static const int CREATE_GROUP = 1 << 6;
static const int CREATE_GROUP_DONE = 1 << 7;
static const int LIST_GROUP_MEMBER = 1 << 8;
static const int LIST_GROUP_MEMBER_DONE = 1 << 9;
static const int INVITE_GROUP_MEMBER = 1 << 10;
static const int INVITE_GROUP_MEMBER_DONE = 1 << 11;
static const int UPDATE_GROUP = 1 << 13;
static const int UPDATE_GROUP_DONE = 1 << 14;
static const int DELETE_GROUP = 1 << 15;
static const int DELETE_GROUP_DONE = 1 << 16;
static const int MEMBER_LEAVE_GROUP = 1 << 17;
static const int GET_PENDING_INVITATIONS = 1 << 18;
static const int GET_TWINCODE = 1 << 19;
static const int GET_TWINCODE_DONE = 1 << 20;
static const int WITHDRAWN_INVITATION = 1 << 21;
static const int CREATE_INVITATION = 1 << 22;
static const int CREATE_INVITATION_DONE = 1 << 23;
static const int FIND_CONTACTS = 1 << 24;
static const int FIND_CONTACTS_DONE = 1 << 25;
static const int SET_CURRENT_SPACE = 1 << 26;
static const int SET_CURRENT_SPACE_DONE = 1 << 27;
static const int GET_CURRENT_SPACE_DONE = 1 << 29;

//
// Interface: GroupService ()
//

@class GroupServiceTwinmeContextDelegate;
@class GroupServiceConversationServiceDelegate;

@interface GroupService ()

@property (nonatomic, nullable) TLGroup *group;
@property (nonatomic, nullable) NSUUID *twincodeOutboundId;
@property (nonatomic, nullable) NSString *groupName;
@property (nonatomic, nullable) NSString *groupDescription;
@property (nonatomic, nullable) TLCapabilities *groupCapabilities;
@property (nonatomic, nullable) UIImage *avatarImage;
@property (nonatomic, nullable) UIImage *avatarLargeImage;
@property (nonatomic, nullable) NSUUID *groupId;
@property (nonatomic, nullable) NSUUID *contactId;
@property (nonatomic, nullable) NSUUID *memberTwincodeId;
@property (nonatomic, nullable) NSMutableArray<TLContact *> *inviteContacts;
@property (nonatomic, nullable) NSMutableArray<TLGroupMember *> *groupMembers;
@property (nonatomic, nullable) TLContact *currentInvitedContact;
@property (nonatomic, nullable) id<TLGroupConversation> groupConversation;
@property (nonatomic, nullable) NSString *findName;
@property (nonatomic) int64_t joinPermissions;
@property (nonatomic) int work;
@property (nonatomic, readonly) GroupServiceConversationServiceDelegate *conversationServiceDelegate;
@property (nonatomic) TLGroupMember *groupMember;

- (void)onOperation;

- (void)onTwinlifeReady;

- (void)onUpdateInvitation:(nonnull id<TLConversation>)conversation invitation:(nonnull TLInvitationDescriptor *)invitation;

- (void)onInviteGroup:(id<TLConversation>)conversation invitation:(TLInvitationDescriptor *)invitation;

- (void)onLeaveGroup:(id<TLGroupConversation>)group memberTwincodeId:(NSUUID *)memberTwincodeId;

- (void)onCreateGroup:(TLGroup *)group conversation:(id<TLGroupConversation>)conversation;

- (void)onJoinGroup:(id<TLGroupConversation>)group;

- (void)onGetGroup:(nullable TLGroup*)group errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onListGroupMembers:(nullable NSMutableArray<TLGroupMember *> *)members errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateGroup:(TLGroup *)group;

- (void)onDeleteGroup:(NSUUID *)groupId;

- (void)onGetContact:(nullable TLContact *)contact errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onCreateInvitation:(nonnull TLInvitation *)invitation;

- (void)onGetCurrentSpace:(nonnull TLSpace *)space;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

- (void)onGetTwincode:(TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

@end

//
// Interface: GroupServiceTwinmeContextDelegate
//

@interface GroupServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (instancetype)initWithService:(GroupService *)service;

@end

//
// Implementation: GroupServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"GroupServiceTwinmeContextDelegate"

@implementation GroupServiceTwinmeContextDelegate

- (instancetype)initWithService:(GroupService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onCreateGroupWithRequestId:(int64_t)requestId group:(TLGroup *)group conversation:(id<TLGroupConversation>)conversation {
    DDLogVerbose(@"%@ onCreateGroupWithRequestId: %lld group: %@ conversation: %@", LOG_TAG, requestId, group, conversation);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(GroupService*)self.service onCreateGroup:group conversation:conversation];
}

- (void)onUpdateGroupWithRequestId:(int64_t)requestId group:(TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, group);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(GroupService*)self.service onUpdateGroup:group];
}

- (void)onCreateInvitationWithRequestId:(int64_t)requestId invitation:(TLInvitation *)invitation {
    DDLogVerbose(@"%@ onCreateInvitationWithRequestId: %lld invitation: %@", LOG_TAG, requestId, invitation);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(GroupService *)self.service onCreateInvitation:invitation];
}

- (void)onDeleteGroupWithRequestId:(int64_t)requestId groupId:(NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroupWithRequestId: %lld groupId: %@", LOG_TAG, requestId, groupId);
    
    [(GroupService *)self.service onDeleteGroup:groupId];
}

- (void)onSetCurrentSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(GroupService *)self.service onSetCurrentSpace:space];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorcode errorParameter:(NSString *)errorParameter {
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(GroupService *)self.service onErrorWithOperationId:operationId errorCode:errorcode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Interface: GroupServiceConversationServiceDelegate
//

@interface GroupServiceConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) GroupService *service;

- (instancetype)initWithService:(GroupService *)service;

@end

//
// Implementation: GroupServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"GroupServiceConversationServiceDelegate"

@implementation GroupServiceConversationServiceDelegate

- (instancetype)initWithService:(GroupService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onUpdateDescriptorWithRequestId:(int64_t)requestId conversation:(id<TLConversation>)conversation descriptor:(TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType {
    DDLogVerbose(@"%@ onUpdateDescriptorWithRequestId: %lld conversation: %@ invitation: %@ updateType: %u", LOG_TAG, requestId, conversation, descriptor, updateType);
    
    if (descriptor.getType == TLDescriptorTypeInvitationDescriptor) {
        [(GroupService *)self.service onUpdateInvitation:conversation invitation:(TLInvitationDescriptor *)descriptor];
    }
}

- (void)onInviteGroupWithRequestId:(int64_t)requestId conversation:(id<TLConversation>)conversation descriptor:(TLInvitationDescriptor *)descriptor {
    DDLogVerbose(@"%@ onInviteGroupWithRequestId: %lld conversation: %@ invitation: %@", LOG_TAG, requestId, conversation, descriptor);
        
    [(GroupService *)self.service onInviteGroup:conversation invitation:descriptor];
}

- (void)onJoinGroupWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onJoinGroupWithRequestId: %lld group: %@ invitation: %@", LOG_TAG, requestId, group, invitation);
    
    // The GroupService does not make joinGroup() calls but wants to be informed about new members.
    [(GroupService *)self.service onJoinGroup:group];
}

- (void)onJoinGroupRequestWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onJoinGroupRequestWithRequestId: %lld group: %@ invitation: %@ memberId: %@", LOG_TAG, requestId, group, invitation, memberId);
    
    [(GroupService *)self.service onJoinGroup:group];
}

- (void)onJoinGroupResponseWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onJoinGroupResponseWithRequestId: %lld group: %@ invitation: %@", LOG_TAG, requestId, group, invitation);
    
    [(GroupService *)self.service onJoinGroup:group];
}

- (void)onLeaveGroupWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onLeaveGroupWithRequestId: %lld group: %@ memberId: %@", LOG_TAG, requestId, group, memberId);
    
    [self.service finishOperation:requestId];
    
    [(GroupService *)self.service onLeaveGroup:group memberTwincodeId:memberId];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
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
// Implementation: GroupService
//

#undef LOG_TAG
#define LOG_TAG @"GroupService"

@implementation GroupService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <GroupServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _conversationServiceDelegate = [[GroupServiceConversationServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[GroupServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)initWithGroup:(nonnull TLGroup *)group {
    
    TL_ASSERT_IS_A(self.twinmeContext, group, TLGroup, TLAssertionParameterSubject, nil);

    self.group = group;
    self.groupId = group.uuid;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];
    [super dispose];
}

- (void)getContacts {
    DDLogVerbose(@"%@ getContacts", LOG_TAG);
    
    self.work |= GET_CONTACTS;
    self.state &= ~(GET_CONTACTS | GET_CONTACTS_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)getContactWithContactId:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ getContactWithContactId contactId: %@", LOG_TAG, contactId);
    
    self.work |= GET_CONTACT;
    self.state &= ~(GET_CONTACT | GET_CONTACT_DONE);
    self.contactId = contactId;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)getGroupWithGroupId:(nonnull NSUUID *)groupId {
    DDLogVerbose(@"%@ getGroupWithGroupId groupId: %@", LOG_TAG, groupId);
    
    self.work |= GET_GROUP | LIST_GROUP_MEMBER;
    self.state &= ~(GET_GROUP | GET_GROUP_DONE | LIST_GROUP_MEMBER | LIST_GROUP_MEMBER_DONE);
    self.groupId = groupId;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)createGroupWithName:(nonnull NSString *)name description:(nullable NSString *)description avatar:(nullable UIImage *)avatar avatarLarge:(nullable UIImage *)avatarLarge members:(nonnull NSMutableArray<TLContact *> *)members permissions:(int64_t)permissions {
    DDLogVerbose(@"%@ createGroupWithName name: %@", LOG_TAG, name);
    
    self.work |= CREATE_GROUP | INVITE_GROUP_MEMBER;
    self.state &= ~(CREATE_GROUP | CREATE_GROUP_DONE);
    self.groupName = name;
    self.groupDescription = description;
    self.avatarImage = avatar;
    self.avatarLargeImage = avatarLarge;
    self.joinPermissions = permissions;
    [self inviteGroupWithContacts:members];
}

- (void)inviteGroupWithContacts:(nonnull NSMutableArray<TLContact *> *)members {
    DDLogVerbose(@"%@ inviteGroupWithContacts members: %@", LOG_TAG, members);
    
    self.work |= INVITE_GROUP_MEMBER;
    self.state &= ~(INVITE_GROUP_MEMBER | INVITE_GROUP_MEMBER_DONE);
    self.inviteContacts = members;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)leaveGroupWithMemberTwincodeId:(nonnull NSUUID *)memberTwincodeId {
    DDLogVerbose(@"%@ leaveGroupWithMemberTwincodeId: %@", LOG_TAG, memberTwincodeId);
    
    [self showProgressIndicator];
    
    if ([memberTwincodeId isEqual:self.group.twincodeOutbound.uuid]) {
        // Mark the group as leaving and save it.
        self.work |= UPDATE_GROUP;
        self.state &= ~(UPDATE_GROUP | UPDATE_GROUP_DONE);
        self.group.isLeaving = true;
    }
    
    int64_t requestId = [self newOperation:MEMBER_LEAVE_GROUP];
    
    // Execute the leaveGroup operation first, don't wait for the network: the operation is queued.
    TLBaseServiceErrorCode result = [[self.twinmeContext getConversationService] leaveGroupWithRequestId:requestId group:self.group memberTwincodeId:memberTwincodeId];
    if (result != TLBaseServiceErrorCodeSuccess) {
        [self.requestIds removeObjectForKey:[NSNumber numberWithLongLong:requestId]];
        [self hideProgressIndicator];
        
        if ([(id)self.delegate respondsToSelector:@selector(onLeaveGroup:memberTwincodeId:)]) {
            [(id<GroupServiceDelegate>)self.delegate onLeaveGroup:self.group memberTwincodeId:memberTwincodeId];
        }
    }
    [self startOperation];
}

- (void)getTwincodeOutboundWithTwincodeOutboundId:(NSUUID *)twincodeOutboundId {
    DDLogVerbose(@"%@ getTwincodeOutboundWithTwincodeOutboundId: %@", LOG_TAG, twincodeOutboundId);
    
    self.work |= GET_TWINCODE;
    self.state &= ~(GET_TWINCODE | GET_TWINCODE_DONE);
    self.twincodeOutboundId = twincodeOutboundId;
    
    [self startOperation];
}

- (void)createInvitation:(nonnull TLGroupMember *)member {
    DDLogVerbose(@"%@ createInvitation: %@", LOG_TAG, member);
    
    self.work |= CREATE_INVITATION;
    self.state &= ~(CREATE_INVITATION | CREATE_INVITATION_DONE);
    self.groupMember = member;
    
    [self startOperation];
}

- (TLBaseServiceErrorCode)withdrawInvitation:(nonnull TLInvitationDescriptor *)invitationDescriptor {
    DDLogVerbose(@"%@ withdrawInvitation: %@", LOG_TAG, invitationDescriptor);
    
    int64_t requestId = [self newOperation:WITHDRAWN_INVITATION];
    return [[self.twinmeContext getConversationService] withdrawInviteGroupWithRequestId:requestId invitation:invitationDescriptor];
}

- (void)findContactsByName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ findContactsByName: %@", LOG_TAG, name);
    
    self.findName = [name.lowercaseString stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
    self.work = FIND_CONTACTS;
    self.state &= ~(FIND_CONTACTS | FIND_CONTACTS_DONE);
    [self startOperation];
}

- (void)getCurrentSpace {
    DDLogVerbose(@"%@ getCurrentSpace", LOG_TAG);
    
    [self.twinmeContext getCurrentSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
        DDLogVerbose(@"%@ getCurrentSpace fini", LOG_TAG);
        [self onGetCurrentSpace:space];
    }];
}

- (void)setCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ setCuurentSpace: %@", LOG_TAG, space);
    
    [self showProgressIndicator];
    int64_t requestId = [self newOperation:SET_CURRENT_SPACE];
    [self.twinmeContext setCurrentSpaceWithRequestId:requestId space:space];
    
    if (!space.settings.isSecret) {
        [self.twinmeContext setDefaultSpace:space];
    }
}

#pragma mark - Private methods

- (void)onGetContact:(nullable TLContact *)contact errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ getContact contact: %@ errorCode: %d", LOG_TAG, contact, errorCode);
    
    self.state |= GET_CONTACT_DONE;
    if (contact) {
        if ([(id)self.delegate respondsToSelector:@selector(onGetContact:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<GroupServiceDelegate>)self.delegate onGetContact:contact];
            });
        }
    } else {
        [self onErrorWithOperationId:GET_CONTACT errorCode:errorCode errorParameter:nil];
    }
    [self onOperation];
}

- (void)onGetGroup:(nullable TLGroup *)group errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetGroup group: %@ errorCode: %d", LOG_TAG, group, errorCode);
    
    self.state |= GET_GROUP_DONE;
    self.group = group;
    
    if (!group) {
        [self onErrorWithOperationId:GET_GROUP errorCode:errorCode errorParameter:nil];
        [self hideProgressIndicator];
    }
    
    [self onOperation];
}

- (void)onListGroupMembers:(nullable NSMutableArray<TLGroupMember *> *)members errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onListGroupMembers", LOG_TAG);

    self.state |= LIST_GROUP_MEMBER_DONE;
    if (errorCode != TLBaseServiceErrorCodeSuccess || !members) {
        [self onErrorWithOperationId:LIST_GROUP_MEMBER errorCode:errorCode errorParameter:nil];
    } else {
        self.groupMembers = members;
        if ([(id)self.delegate respondsToSelector:@selector(onGetGroup:groupMembers:conversation:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<GroupServiceDelegate>)self.delegate onGetGroup:self.group groupMembers:self.groupMembers conversation:self.groupConversation];
            });
        }
    }
    [self onOperation];
}

- (void)onCreateGroup:(TLGroup *)group conversation:(id<TLGroupConversation>)conversation {
    DDLogVerbose(@"%@ onCreateGroup: %@", LOG_TAG, group);
    
    TL_ASSERT_IS_A(self.twinmeContext, group, TLGroup, TLAssertionParameterSubject, nil);

    self.state |= CREATE_GROUP_DONE;
    self.group = group;
    self.groupId = group.uuid;
    self.groupConversation = conversation;
    [[self.twinmeContext getConversationService] setPermissionsWithSubject:group memberTwincodeId:nil permissions:self.joinPermissions];
    [self nextInviteMember];
    [self onOperation];
}

- (void)onUpdateInvitation:(nonnull id<TLConversation>)conversation invitation:(nonnull TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onUpdateInvitation: %@ invitation: %@", LOG_TAG, conversation, invitation);
    
    if (![self.groupId isEqual:conversation.contactId]) {
        
        return;
    }
    
    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onInviteGroup:invitation:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupServiceDelegate>)delegate onInviteGroup:conversation invitation:invitation];
        });
    }
}

- (void)onInviteGroup:(id<TLConversation>)conversation invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onInviteGroup: %@ invitation: %@", LOG_TAG, conversation, invitation);
    
    self.state |= INVITE_GROUP_MEMBER_DONE;
    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(onInviteGroup:invitation:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupServiceDelegate>)delegate onInviteGroup:conversation invitation:invitation];
        });
    }
    [self nextInviteMember];
    [self onOperation];
}

- (void)nextInviteMember {
    DDLogVerbose(@"%@ nextInviteMember", LOG_TAG);
    
    if (self.inviteContacts) {
        while (self.inviteContacts.count > 0) {
            self.currentInvitedContact = [self.inviteContacts objectAtIndex:0];
            [self.inviteContacts removeObjectAtIndex:0];
            if (self.currentInvitedContact) {
                self.state &= ~(INVITE_GROUP_MEMBER | INVITE_GROUP_MEMBER_DONE);
                return;
            }
        }
        self.currentInvitedContact = nil;
    }
    self.inviteContacts = nil;
    self.state |= INVITE_GROUP_MEMBER | INVITE_GROUP_MEMBER_DONE;
    if ((self.work & CREATE_GROUP) != 0) {
        if ([(id)self.delegate respondsToSelector:@selector(onCreateGroup:conversation:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<GroupServiceDelegate>)self.delegate onCreateGroup:self.group conversation:self.groupConversation];
            });
        }
    }
}

- (void)onUpdateGroup:(TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroup group: %@", LOG_TAG, group);
    
    self.state |= UPDATE_GROUP_DONE;
    if ([(id)self.delegate respondsToSelector:@selector(onUpdateGroup:avatar:)]) {
        UIImage *avatar = [self getImageWithGroup:group];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupServiceDelegate>)self.delegate onUpdateGroup:group avatar:avatar];
        });
    }
    [self onOperation];
}

- (void)onDeleteGroup:(NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroup: %@", LOG_TAG, groupId);
    
    if ([groupId isEqual:self.groupId]) {
        self.state |= DELETE_GROUP_DONE;
        
        [self hideProgressIndicator];
        if ([(id)self.delegate respondsToSelector:@selector(onDeleteGroup:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<GroupServiceDelegate>)self.delegate onDeleteGroup:groupId];
            });
        }
        
        [self onOperation];
    }
}

- (void)onLeaveGroup:(id<TLGroupConversation>)group memberTwincodeId:(NSUUID*)memberTwincodeId {
    DDLogVerbose(@"%@ onLeaveGroup group: %@ memberTwincodeId: %@", LOG_TAG, group, memberTwincodeId);
    
    if (!self.group || ![self.group.uuid isEqual:group.contactId]) {
        return;
    }
    if ([(id)self.delegate respondsToSelector:@selector(onLeaveGroup:memberTwincodeId:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupServiceDelegate>)self.delegate onLeaveGroup:self.group memberTwincodeId:memberTwincodeId];
        });
    }
}

- (void)onJoinGroup:(id<TLGroupConversation>)group {
    DDLogVerbose(@"%@ onJoinGroup: %@", LOG_TAG, group);
    
    // If this is our group, refresh the information about the group and its members.
    if (group && [self.groupId isEqual:group.contactId] && [group state] == TLGroupConversationStateJoined) {
        self.work |= GET_GROUP | LIST_GROUP_MEMBER;
        self.state &= ~(GET_GROUP | GET_GROUP_DONE | LIST_GROUP_MEMBER | LIST_GROUP_MEMBER_DONE | GET_PENDING_INVITATIONS);
        [self onOperation];
    }
}

- (void)onCreateInvitation:(TLInvitation *)invitation {
    DDLogVerbose(@"%@ onCreateInvitation: %@", LOG_TAG, invitation);
    
    self.state |= CREATE_INVITATION_DONE;
    if ([(id)self.delegate respondsToSelector:@selector(onCreateInvitation:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupServiceDelegate>)self.delegate onCreateInvitation:invitation];
        });
    }
    [self onOperation];
}

- (void)onGetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onGetCurrentSpace: %@", LOG_TAG, space);

    self.state |= GET_CURRENT_SPACE_DONE;
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<GroupServiceDelegate>)self.delegate onGetCurrentSpace:space];
    });
    [self onOperation];
}

- (void)onSetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    self.state |= SET_CURRENT_SPACE_DONE;
    [self runOnSetCurrentSpace:space];
    [self onOperation];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    // We must get the group object.
    if ((self.work & GET_GROUP) != 0) {
        if ((self.state & GET_GROUP) == 0) {
            self.state |= GET_GROUP;
            
            [self.twinmeContext getGroupWithGroupId:self.groupId withBlock:^(TLBaseServiceErrorCode errorCode, TLGroup *group) {
                [self onGetGroup:group errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & GET_GROUP_DONE) == 0) {
            return;
        }

        // Get the list of pending invitations if the delegate implements the onListPendingInvitations method.
        if (self.group && (self.state & GET_PENDING_INVITATIONS) == 0) {
            self.state |= GET_PENDING_INVITATIONS;
            if ([(id)self.delegate respondsToSelector:@selector(onListPendingInvitations:)]) {
                NSMutableDictionary<NSUUID *, TLInvitationDescriptor *> * pendingInvitations = [[self.twinmeContext getConversationService] listPendingInvitationsWithGroup:self.group];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [(id<GroupServiceDelegate>)self.delegate onListPendingInvitations:pendingInvitations];
                });
            }
        }
    }
    
    // We must get the contact object.
    if ((self.work & GET_CONTACT) != 0) {
        if ((self.state & GET_CONTACT) == 0) {
            self.state |= GET_CONTACT;
            
            [self.twinmeContext getContactWithContactId:self.contactId withBlock:^(TLBaseServiceErrorCode errorCode, TLContact *contact) {
                [self onGetContact:contact errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & GET_CONTACT_DONE) == 0) {
            return;
        }
    }
    
    // We must get the list of contacts.
    if ((self.work & GET_CONTACTS) != 0) {
        if ((self.state & GET_CONTACTS) == 0) {
            self.state |= GET_CONTACTS;
            
            TLFilter *filter = [self.twinmeContext createSpaceFilter];
            filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLContact *contact = (TLContact *)object;
                return !contact.isTwinroom && contact.hasPeer;
            };
            [self.twinmeContext findContactsWithFilter:filter withBlock:^(NSMutableArray<TLContact *> *contacts) {
                self.state |= GET_CONTACTS_DONE;
                if ([(id)self.delegate respondsToSelector:@selector(onGetContacts:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [(id<GroupServiceDelegate>)self.delegate onGetContacts:contacts];
                    });
                }
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_CONTACTS_DONE) == 0) {
            return;
        }
    }
    
    // We must get the group conversation.
    if ((self.work & LIST_GROUP_MEMBER) != 0 && self.group) {
        if ((self.state & LIST_GROUP_MEMBER) == 0) {
            self.state |= LIST_GROUP_MEMBER;
            self.groupConversation = (id<TLGroupConversation>)[[self.twinmeContext getConversationService] getConversationWithSubject:self.group];
            
            [self.twinmeContext listGroupMembersWithGroup:self.group filter:TLGroupMemberFilterTypeJoinedMembers withBlock:^(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> *members) {
                [self onListGroupMembers:members errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & LIST_GROUP_MEMBER_DONE) == 0) {
            return;
        }
    }

    // We must create a group and we have not done it yet.
    if ((self.work & CREATE_GROUP) != 0) {
        if ((self.state & CREATE_GROUP) == 0) {
            self.state |= CREATE_GROUP;
            
            int64_t requestId = [self newOperation:CREATE_GROUP];
            [self.twinmeContext createGroupWithRequestId:requestId name:self.groupName description:self.groupDescription avatar:self.avatarImage largeAvatar:self.avatarLargeImage];
            return;
        }
        if ((self.state & CREATE_GROUP_DONE) == 0) {
            return;
        }
    }
    
    // We must invite the contacts stored in mInviteMembers after the group is created.
    if ((self.work & INVITE_GROUP_MEMBER) != 0) {
        if ((self.state & INVITE_GROUP_MEMBER) == 0) {
            if (!self.currentInvitedContact) {
                [self nextInviteMember];
            }
            
            // nextInviteMember can clear the INVITE_GROUP_MEMBER state, mark it after its possible call.
            self.state |= INVITE_GROUP_MEMBER;
            if (!self.currentInvitedContact) {
                self.state |= INVITE_GROUP_MEMBER_DONE;
            } else if ((self.state & INVITE_GROUP_MEMBER_DONE) == 0) {
                id<TLConversation> conversation = [[self.twinmeContext getConversationService] getOrCreateConversationWithSubject:self.currentInvitedContact create:YES];
                
                int64_t requestId = [self newOperation:INVITE_GROUP_MEMBER];
                TLBaseServiceErrorCode errorCode = [[self.twinmeContext getConversationService] inviteGroupWithRequestId:requestId conversation:conversation group:self.group name:self.group.groupPublicName];
                if (errorCode != TLBaseServiceErrorCodeSuccess) {
                    [self onErrorWithOperationId:INVITE_GROUP_MEMBER errorCode:errorCode errorParameter:nil];
                }
            }
        }
        if ((self.state & INVITE_GROUP_MEMBER_DONE) == 0) {
            return;
        }
    }
    
    // We must update the group.
    if ((self.work & UPDATE_GROUP) != 0) {
        if ((self.state & UPDATE_GROUP) == 0) {
            self.state |= UPDATE_GROUP;
            
            int64_t requestId = [self newOperation:UPDATE_GROUP];
            [self.twinmeContext updateGroupWithRequestId:requestId group:self.group name:self.groupName description:self.groupDescription groupAvatar:self.avatarImage groupLargeAvatar:self.avatarLargeImage capabilities:self.groupCapabilities];
            return;
        }
        if ((self.state & UPDATE_GROUP_DONE) == 0) {
            return;
        }
    }
    
    // We must delete the group.
    if ((self.work & DELETE_GROUP) != 0) {
        if ((self.state & DELETE_GROUP) == 0) {
            self.state |= DELETE_GROUP;
            
            int64_t requestId = [self newOperation:DELETE_GROUP];
            [self.twinmeContext deleteGroupWithRequestId:requestId group:self.group];
            return;
        }
        if ((self.state & DELETE_GROUP_DONE) == 0) {
            return;
        }
    }
    
    // We must get the group twincode information
    if ((self.work & GET_TWINCODE) != 0 && self.twincodeOutboundId) {
        if ((self.state & GET_TWINCODE) == 0) {
            self.state |= GET_TWINCODE;
            
            [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.twincodeOutboundId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onGetTwincode:twincodeOutbound errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & GET_TWINCODE_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & CREATE_INVITATION) != 0 && self.groupMember) {
        if ((self.state & CREATE_INVITATION) == 0) {
            self.state |= CREATE_INVITATION;
            
            int64_t requestId = [self newOperation:CREATE_INVITATION];
            [self.twinmeContext createInvitationWithRequestId:requestId groupMember:self.groupMember];
            return;
        }
        if ((self.state & CREATE_INVITATION_DONE) == 0) {
            return;
        }
    }
    
    // We must search for a contact with some name.
    if ((self.work & FIND_CONTACTS) != 0) {
        if ((self.state & FIND_CONTACTS) == 0) {
            self.state |= FIND_CONTACTS;
            
            TLFilter *filter = [self.twinmeContext createSpaceFilter];
            filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLContact *contact = (TLContact *)object;
                NSString *contactName = [contact.name stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
                return [contactName.lowercaseString containsString:self.findName] && !contact.isTwinroom && contact.hasPeer;
            };
            
            [self.twinmeContext findContactsWithFilter:filter withBlock:^(NSMutableArray<TLContact *> *contacts) {
                self.state |= FIND_CONTACTS_DONE;
                if ([(id)self.delegate respondsToSelector:@selector(onGetContacts:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [(id<GroupServiceDelegate>)self.delegate onGetContacts:contacts];
                    });
                }
                [self onOperation];
            }];
            return;
        }
        if ((self.state & FIND_CONTACTS_DONE) == 0) {
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
    
    [[self.twinmeContext getConversationService] addDelegate:self.conversationServiceDelegate];
    [super onTwinlifeReady];
}

- (void)onGetTwincode:(TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetTwincode: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeOutbound == nil) {
        
        [self onErrorWithOperationId:GET_TWINCODE errorCode:errorCode errorParameter:self.twincodeOutboundId.UUIDString];
        return;
    }

    self.state |= GET_TWINCODE_DONE;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([(id)self.delegate respondsToSelector:@selector(onGetTwincode:)]) {
            [(id<GroupServiceDelegate>)self.delegate onGetTwincode:twincodeOutbound];
        }
    });
    [self onOperation];
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
            case GET_GROUP:
            case UPDATE_GROUP:
            case LIST_GROUP_MEMBER:
                if ([(id)self.delegate respondsToSelector:@selector(onErrorGroupNotFound)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [(id<GroupServiceDelegate>)self.delegate onErrorGroupNotFound];
                    });
                }
                [self hideProgressIndicator];
                return;
                
            case GET_CONTACT:
                if ([(id)self.delegate respondsToSelector:@selector(onErrorContactNotFound)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [(id<GroupServiceDelegate>)self.delegate onErrorContactNotFound];
                    });
                }
                [self hideProgressIndicator];
                return;
                
            case INVITE_GROUP_MEMBER:
                self.state |= INVITE_GROUP_MEMBER_DONE;
                [self nextInviteMember];
                [self onOperation];
                return;

            default:
                break;
        }
    }
    if (errorCode == TLBaseServiceErrorCodeLimitReached) {
        if ([(id)self.delegate respondsToSelector:@selector(onErrorLimitReached)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<GroupServiceDelegate>)self.delegate onErrorLimitReached];
            });
        }
        return;
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
