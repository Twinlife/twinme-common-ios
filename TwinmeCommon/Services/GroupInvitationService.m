/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLAccountService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLImageService.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLTwinmeAttributes.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLGroupMember.h>
#import <Twinme/TLSpace.h>
#import <Twinme/TLSpaceSettings.h>

#import "GroupInvitationService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_SPACE = 1 << 0;
static const int GET_SPACE_DONE = 1 << 1;
static const int GET_CONTACT = 1 << 2;
static const int GET_CONTACT_DONE = 1 << 3;
static const int GET_INVITATION = 1 << 4;
static const int GET_TWINCODE = 1 << 5;
static const int GET_TWINCODE_DONE = 1 << 6;
static const int GET_TWINCODE_IMAGE = 1 << 7;
static const int GET_TWINCODE_IMAGE_DONE = 1 << 8;
static const int ACCEPT_INVITATION = 1 << 12;
static const int ACCEPT_INVITATION_DONE = 1 << 13;
static const int DECLINE_INVITATION = 1 << 14;
static const int DECLINE_INVITATION_DONE = 1 << 15;
static const int DELETE_INVITATION = 1 << 16;
static const int DELETE_INVITATION_DONE = 1 << 17;
static const int SET_CURRENT_SPACE = 1 << 18;
static const int SET_CURRENT_SPACE_DONE = 1 << 19;
static const int MOVE_GROUP_SPACE = 1 << 20;
static const int MOVE_GROUP_SPACE_DONE = 1 << 21;

//
// Interface: GroupInvitationService ()
//

@class GroupInvitationServiceTwinmeContextDelegate;
@class GroupInvitationServiceConversationServiceDelegate;

@interface GroupInvitationService ()

@property (nonatomic, nullable) TLInvitationDescriptor *invitationDescriptor;
@property (nonatomic, nullable) NSUUID *conversationId;
@property (nonatomic, nullable) TLGroup *group;
@property (nonatomic, nullable) TLImageId *avatarId;
@property (nonatomic, nullable) UIImage *avatarImage;
@property (nonatomic, nullable) NSUUID *groupId;
@property (nonatomic, nullable) NSUUID *contactId;
@property (nonatomic, nullable) NSUUID *memberTwincodeId;
@property (nonatomic, nullable) NSMutableArray<TLContact*> *inviteContacts;
@property (nonatomic, nullable) NSMutableArray<TLGroupMember*> *groupMembers;
@property (nonatomic, nullable) NSMutableArray<id<TLGroupMemberConversation>> *groupMemberConversations;
@property (nonatomic, nullable) id<TLGroupMemberConversation> currentGroupMember;
@property (nonatomic, nullable) TLContact *currentInvitedContact;
@property (nonatomic, nullable) id<TLGroupConversation> groupConversation;
@property (nonatomic, nullable) TLTwincodeOutbound *twincodeOutbound;
@property (nonatomic, nullable) TLDescriptorId *descriptorId;
@property (nonatomic) int64_t joinPermissions;
@property (nonatomic) int work;
@property (nonatomic, readonly) GroupInvitationServiceConversationServiceDelegate *conversationServiceDelegate;

- (void)onOperation;

- (void)onTwinlifeReady;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

- (void)onCreateGroup:(nonnull TLGroup *)group conversation:(nonnull id<TLGroupConversation>)conversation;

- (void)onGetContact:(nullable TLContact *)contact errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onGetTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onJoinGroupWithOperationId:(int)operationId group:(nonnull id <TLGroupConversation>)group invitation:(nonnull TLInvitationDescriptor *)invitation twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId;

- (void)onMarkDescriptorDeletedWithConversation:(nonnull id<TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor;

- (void)onMoveGroupToSpace:(nonnull TLGroup *)group oldSpace:(nonnull TLSpace *)oldSpace;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Interface: GroupInvitationServiceTwinmeContextDelegate
//

@interface GroupInvitationServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull GroupInvitationService *)service;

@end

//
// Implementation: GroupInvitationServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"GroupInvitationServiceTwinmeContextDelegate"

@implementation GroupInvitationServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull GroupInvitationService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onCreateGroupWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group conversation:(id<TLGroupConversation>)conversation {
    DDLogVerbose(@"%@ onCreateGroupWithRequestId: %lld group: %@ conversation: %@", LOG_TAG, requestId, group, conversation);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(GroupInvitationService *)self.service onCreateGroup:group conversation:conversation];
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId group:(TLGroup *)group oldSpace:(TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld group: %@ oldSpace: %@", LOG_TAG, requestId, group, oldSpace);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(GroupInvitationService *)self.service onMoveGroupToSpace:group oldSpace:oldSpace];
}

- (void)onSetCurrentSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(GroupInvitationService *)self.service onSetCurrentSpace:space];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorcode errorParameter:(nullable NSString *)errorParameter {
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(GroupInvitationService *)self.service onErrorWithOperationId:operationId errorCode:errorcode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Interface: GroupInvitationServiceConversationServiceDelegate
//

@interface GroupInvitationServiceConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) GroupInvitationService *service;

- (nonnull instancetype)initWithService:(nonnull GroupInvitationService *)service;

@end

//
// Implementation: GroupInvitationServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"GroupInvitationServiceConversationServiceDelegate"

@implementation GroupInvitationServiceConversationServiceDelegate

- (nonnull instancetype)initWithService:(nonnull GroupInvitationService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onJoinGroupWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group invitation:(nullable TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onJoinGroupWithRequestId: %lld group: %@ invitation: %@", LOG_TAG, requestId, group, invitation);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    [(GroupInvitationService *)self.service onJoinGroupWithOperationId:operationId group:group invitation:invitation twincodeOutboundId:invitation.descriptorId.twincodeOutboundId];
}

- (void)onMarkDescriptorDeletedWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onMarkDescriptorDeletedWithRequestId: %lld conversation: %@ descriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(GroupInvitationService *)self.service onMarkDescriptorDeletedWithConversation:conversation descriptor:descriptor];
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
// Implementation: GroupInvitationService
//

#undef LOG_TAG
#define LOG_TAG @"GroupInvitationService"

@implementation GroupInvitationService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <GroupInvitationServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _conversationServiceDelegate = [[GroupInvitationServiceConversationServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[GroupInvitationServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];
    [super dispose];
}

- (void)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId contactId:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ contactId: %@", LOG_TAG, descriptorId, contactId);
    
    self.work |= GET_TWINCODE;
    self.descriptorId = descriptorId;
    self.contactId = contactId;
    [self startOperation];
}

- (void)acceptInvitation {
    DDLogVerbose(@"%@ acceptInvitation", LOG_TAG);

    self.work |= ACCEPT_INVITATION;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)declineInvitation {
    DDLogVerbose(@"%@ declineInvitation", LOG_TAG);
    
    self.work |= DECLINE_INVITATION;
    self.state &= ~(DECLINE_INVITATION | DECLINE_INVITATION_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)moveGroupToSpace:(nonnull TLSpace *)space group:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ moveGroupToSpace: %@ group: %@", LOG_TAG, space, group);

    int64_t requestId = [self newOperation:MOVE_GROUP_SPACE];
    [self showProgressIndicator];
    [self.twinmeContext moveToSpaceWithRequestId:requestId group:group space:space];
}

- (void)setCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ setCuurentSpace: %@", LOG_TAG, space);
    
    int64_t requestId = [self newOperation:SET_CURRENT_SPACE];
    [self showProgressIndicator];
    [self.twinmeContext setCurrentSpaceWithRequestId:requestId space:space];
    
    if (!space.settings.isSecret) {
        [self.twinmeContext setDefaultSpace:space];
    }
}

#pragma mark - Private methods

- (void)onGetSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onGetSpace: %@", LOG_TAG, space);
    
    self.state |= GET_SPACE_DONE;
    [self runOnGetSpace:space avatar:nil];
    [self onOperation];
}

- (void)onSetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    self.state |= SET_CURRENT_SPACE_DONE;
    [self runOnSetCurrentSpace:space];
    [self onOperation];
}

- (void)onCreateGroup:(TLGroup *)group conversation:(id<TLGroupConversation>)conversation {
    DDLogVerbose(@"%@ onCreateGroup: %@ conversation: %@", LOG_TAG, group, conversation);
    
    self.state |= ACCEPT_INVITATION_DONE;
    self.group = group;
    if ([(id)self.delegate respondsToSelector:@selector(onAcceptedInvitationWithInvitationDescriptor:group:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupInvitationServiceDelegate>)self.delegate onAcceptedInvitationWithInvitationDescriptor:self.invitationDescriptor group:self.group];
        });
    }
    [self onOperation];
}

- (void)onGetContact:(nullable TLContact *)contact errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetContact: %@ errorCode: %d", LOG_TAG, contact, errorCode);
    
    self.state |= GET_CONTACT_DONE;
    if (contact) {
        UIImage *image = [self getImageWithContact:contact];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupInvitationServiceDelegate>)self.delegate onGetContact:contact avatar:image];
        });
    }
    [self onOperation];
}

- (void)onGetTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetTwincodeOutbound: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);

    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.state &= ~(GET_TWINCODE | GET_TWINCODE_DONE | GET_TWINCODE_IMAGE | GET_TWINCODE_IMAGE_DONE);
        [self onErrorWithOperationId:GET_TWINCODE errorCode:errorCode errorParameter:self.invitationDescriptor.groupTwincodeId.UUIDString];
        return;
    }
    
    self.state |= GET_TWINCODE_DONE;
    if (twincodeOutbound) {
        TL_ASSERT_EQUAL(self.twinmeContext, twincodeOutbound.uuid, self.invitationDescriptor.groupTwincodeId, [ServicesAssertPoint INVALID_TWINCODE], TLAssertionParameterTwincodeId, [TLAssertValue initWithTwincodeOutbound:twincodeOutbound], nil);

        self.avatarId = [twincodeOutbound avatarId];
        self.twincodeOutbound = twincodeOutbound;
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupInvitationServiceDelegate>)self.delegate onGetInvitationWithInvitationDescriptor:self.invitationDescriptor avatar:nil];
        });
    } else if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        [self onInvitationDeleted];
    } else {
        [self onErrorWithOperationId:GET_TWINCODE errorCode:errorCode errorParameter:self.invitationDescriptor.groupTwincodeId.UUIDString];
    }
    
    [self onOperation];
}

- (void)onJoinGroupWithOperationId:(int)operationId group:(id <TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation twincodeOutboundId:(NSUUID *)twincodeOutboundId {
    DDLogVerbose(@"%@ onJoinGroupWithOperationId: %d group: %@ invitation: %@ twincodeOutboundId: %@", LOG_TAG, operationId, group, invitation, twincodeOutboundId);
    
    switch (operationId) {
        case ACCEPT_INVITATION:
            self.state |= ACCEPT_INVITATION_DONE;
            if ([(id)self.delegate respondsToSelector:@selector(onAcceptedInvitationWithInvitationDescriptor:group:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [(id<GroupInvitationServiceDelegate>)self.delegate onAcceptedInvitationWithInvitationDescriptor:invitation group:self.group];
                });
            }
            break;
            
        case DECLINE_INVITATION:
            self.state |= DECLINE_INVITATION_DONE;
            if ([(id)self.delegate respondsToSelector:@selector(onDeclinedInvitationWithInvitationDescriptor:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [(id<GroupInvitationServiceDelegate>)self.delegate onDeclinedInvitationWithInvitationDescriptor:invitation];
                });
            }
            break;
    }
    [self onOperation];
}

- (void)onMarkDescriptorDeletedWithConversation:(id<TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onMarkDescriptorDeletedWithConversation: %@ descriptor: %@", LOG_TAG, conversation, descriptor);

    self.state |= DELETE_INVITATION_DONE;
    
    if ([(id)self.delegate respondsToSelector:@selector(onDeletedInvitation)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupInvitationServiceDelegate>)self.delegate onDeletedInvitation];
        });
    }
    [self onOperation];
}

- (void)onMoveGroupToSpace:(TLGroup *)group oldSpace:(TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveGroupToSpace group: %@ oldSpace: %@", LOG_TAG, group, oldSpace);
    
    self.state |= MOVE_GROUP_SPACE_DONE;
    
    if ([(id)self.delegate respondsToSelector:@selector(onMoveGroup:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<GroupInvitationServiceDelegate>)self.delegate onMoveGroup:group];
        });
    }
    [self onOperation];
}

- (void)onInvitationDeleted {
    DDLogVerbose(@"%@ onInvitationDeleted", LOG_TAG);

    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<GroupInvitationServiceDelegate>)self.delegate onDeletedInvitation];
    });
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    if ((self.state & GET_SPACE) == 0) {
        self.state |= GET_SPACE;
        [self.twinmeContext getCurrentSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
            [self onGetSpace:space];
        }];
        return;
    }
    if ((self.state & GET_SPACE_DONE) == 0) {
        return;
    }

    if (self.contactId) {
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

    if (self.descriptorId) {
        if ((self.state & GET_INVITATION) == 0) {
            self.state |= GET_INVITATION;
            self.invitationDescriptor = [[self.twinmeContext getConversationService] getInvitationWithDescriptorId:self.descriptorId];
            if (!self.invitationDescriptor) {
                [self onInvitationDeleted];
            }
        }
    }

    // We must get the group twincode information
    if (self.invitationDescriptor) {
        if ((self.state & GET_TWINCODE) == 0) {
            self.state |= GET_TWINCODE;
            
            DDLogVerbose(@"%@ getTwincodeWithTwincodeId: %@", LOG_TAG, self.invitationDescriptor.groupTwincodeId);
            [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.invitationDescriptor.groupTwincodeId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onGetTwincodeOutbound:twincodeOutbound errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & GET_TWINCODE_DONE) == 0) {
            return;
        }
    }
    
    if (self.avatarId) {
        if ((self.state & GET_TWINCODE_IMAGE) == 0) {
            self.state |= GET_TWINCODE_IMAGE;
            
            DDLogVerbose(@"%@ getImageWithImageId: %@", LOG_TAG, self.avatarId);
            [[self.twinmeContext getImageService] getImageWithImageId:self.avatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                self.state |= GET_TWINCODE_IMAGE_DONE;
                if (errorCode == TLBaseServiceErrorCodeSuccess && image) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [(id<GroupInvitationServiceDelegate>)self.delegate onGetInvitationWithInvitationDescriptor:self.invitationDescriptor avatar:image];
                    });
                }
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_TWINCODE_IMAGE_DONE) == 0) {
            return;
        }
    }

    // We must accept the group invitation and we have not done it yet.
    if ((self.work & ACCEPT_INVITATION) != 0 && self.invitationDescriptor) {
        if ((self.state & ACCEPT_INVITATION) == 0) {
            self.state |= ACCEPT_INVITATION;
            
            int64_t requestId = [self newOperation:ACCEPT_INVITATION];
            [self.twinmeContext createGroupWithRequestId:requestId invitation:self.invitationDescriptor];
            return;
        }
        if ((self.state & ACCEPT_INVITATION_DONE) == 0) {
            return;
        }
    }
    
    // We must decline the group invitation
    if ((self.work & DECLINE_INVITATION) != 0 && self.invitationDescriptor) {
        if ((self.state & DECLINE_INVITATION) == 0) {
            self.state |= DECLINE_INVITATION;
            
            int64_t requestId = [self newOperation:DECLINE_INVITATION];
            TLBaseServiceErrorCode errorCode = [[self.twinmeContext getConversationService] joinGroupWithRequestId:requestId descriptorId:self.invitationDescriptor.descriptorId group:nil];
            if (errorCode != TLBaseServiceErrorCodeSuccess) {
                [self onErrorWithOperationId:DECLINE_INVITATION errorCode:errorCode errorParameter:nil];
            }
        }
        if ((self.state & DECLINE_INVITATION_DONE) == 0) {
            return;
        }
    }
    
    // Invitation is no longer valid and must be removed.
    if ((self.work & DELETE_INVITATION) != 0 && self.invitationDescriptor) {
        if ((self.state & DELETE_INVITATION) == 0) {
            self.state |= DELETE_INVITATION;
            int64_t requestId = [self newOperation:DELETE_INVITATION];
            [[self.twinmeContext getConversationService] markDescriptorDeletedWithRequestId:requestId descriptorId:self.invitationDescriptor.descriptorId];
            return;
        }
        if ((self.state & DELETE_INVITATION_DONE) == 0) {
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

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        // The invitation descriptor can be valid but the group has been removed.
        // Trigger the delete invitation locally through the markDescriptorDeleted()
        // and notify the activity through the onDeleteInvitation() callback when markDescriptorDeleted has finished.
        
        switch (operationId) {
            case ACCEPT_INVITATION:
                self.state |= ACCEPT_INVITATION_DONE;
                self.state &= ~(DELETE_INVITATION | DELETE_INVITATION_DONE);
                self.work |= DELETE_INVITATION;
                return;
                
            case DECLINE_INVITATION:
                self.state |= DECLINE_INVITATION_DONE;
                self.state &= ~(DELETE_INVITATION | DELETE_INVITATION_DONE);
                self.work |= DELETE_INVITATION;
                return;
                
            case GET_TWINCODE:
                self.state |= GET_TWINCODE_DONE;
                self.state &= ~(DELETE_INVITATION | DELETE_INVITATION_DONE);
                self.work |= DELETE_INVITATION;
                return;
                
            case DELETE_INVITATION:
                self.state |= DELETE_INVITATION_DONE;
                if ([(id)self.delegate respondsToSelector:@selector(onDeletedInvitation)]) {
                    [(id<GroupInvitationServiceDelegate>)self.delegate onDeletedInvitation];
                }
                return;
        }
    } else if (errorCode == TLBaseServiceErrorCodeNoPermission) {
        
        // joinGroup() can return NO_PERMISSION which means the invitation has already been accepted or declined.
        switch (operationId) {

            case ACCEPT_INVITATION:
                self.state |= ACCEPT_INVITATION_DONE;
                self.state &= ~(DELETE_INVITATION | DELETE_INVITATION_DONE);
                self.work |= DELETE_INVITATION;
                return;
                
            case DECLINE_INVITATION:
                self.state |= DECLINE_INVITATION_DONE;
                self.state &= ~(DELETE_INVITATION | DELETE_INVITATION_DONE);
                self.work |= DELETE_INVITATION;
                return;
  
            default:
                break;
        }
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
