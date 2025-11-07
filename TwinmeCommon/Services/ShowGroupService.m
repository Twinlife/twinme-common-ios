/*
 *  Copyright (c) 2020-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLAccountService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLTwincodeOutboundService.h>

#import <Twinme/TLTwinmeContext.h>

#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLGroupMember.h>
#import "ShowGroupService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_GROUP = 1 << 0;
static const int GET_GROUP_DONE = 1 << 1;
static const int GET_GROUP_THUMBNAIL_IMAGE = 1 << 2;
static const int GET_GROUP_THUMBNAIL_IMAGE_DONE = 1 << 3;
static const int GET_GROUP_IMAGE = 1 << 4;
static const int GET_GROUP_IMAGE_DONE = 1 << 5;
static const int LIST_GROUP_MEMBER = 1 << 7;
static const int LIST_GROUP_MEMBER_DONE = 1 << 8;
static const int UPDATE_GROUP = 1 << 9;
static const int UPDATE_GROUP_DONE = 1 << 10;
static const int DELETE_GROUP = 1 << 11;
static const int DELETE_GROUP_DONE = 1 << 12;
static const int MEMBER_LEAVE_GROUP = 1 << 13;
static const int GET_TWINCODE = 1 << 14;
static const int GET_TWINCODE_DONE = 1 << 15;

//
// Interface: ShowGroupService ()
//

@class ShowGroupServiceTwinmeContextDelegate;
@class ShowGroupServiceConversationServiceDelegate;

@interface ShowGroupService ()

@property (nonatomic, nullable) TLGroup *group;
@property (nonatomic, nullable) NSUUID *twincodeOutboundId;
@property (nonatomic, nullable) NSString *groupName;
@property (nonatomic, nullable) TLImageId *avatarId;
@property (nonatomic, nullable) UIImage *avatar;
@property (nonatomic, nullable) NSUUID *groupId;
@property (nonatomic, nullable) NSMutableArray<TLGroupMember *> *groupMembers;
@property (nonatomic, nullable) id<TLGroupConversation> groupConversation;
@property (nonatomic) int work;
@property (nonatomic, readonly) ShowGroupServiceConversationServiceDelegate *conversationServiceDelegate;

- (void)onOperation;

- (void)onTwinlifeReady;

- (void)onJoinGroup:(id<TLGroupConversation>)group;

- (void)onLeaveGroup:(nonnull id<TLGroupConversation>)group memberTwincodeId:(nonnull NSUUID *)memberTwincodeId;

- (void)onGetGroup:(nonnull TLGroup*)group;

- (void)onUpdateGroup:(nonnull TLGroup *)group;

- (void)onDeleteGroup:(nonnull NSUUID *)groupId;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Interface: ShowGroupServiceTwinmeContextDelegate
//

@interface ShowGroupServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ShowGroupService *)service;

@end

//
// Implementation: ShowGroupServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ShowGroupServiceTwinmeContextDelegate"

@implementation ShowGroupServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ShowGroupService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onUpdateGroupWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, group);
    
    [(ShowGroupService*)self.service onUpdateGroup:group];
}

- (void)onDeleteGroupWithRequestId:(int64_t)requestId groupId:(nonnull NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroupWithRequestId: %lld groupId: %@", LOG_TAG, requestId, groupId);
    
    [(ShowGroupService *)self.service onDeleteGroup:groupId];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorcode errorParameter:(nullable NSString *)errorParameter {
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(ShowGroupService *)self.service onErrorWithOperationId:operationId errorCode:errorcode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Interface: ShowGroupServiceConversationServiceDelegate
//

@interface ShowGroupServiceConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) ShowGroupService *service;

- (instancetype)initWithService:(nonnull ShowGroupService *)service;

@end

//
// Implementation: ShowGroupServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ShowGroupServiceConversationServiceDelegate"

@implementation ShowGroupServiceConversationServiceDelegate

- (nonnull instancetype)initWithService:(nonnull ShowGroupService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onJoinGroupWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onJoinGroupWithRequestId: %lld group: %@ invitation: %@", LOG_TAG, requestId, group, invitation);
    
    // The GroupService does not make joinGroup() calls but wants to be informed about new members.
    [(ShowGroupService *)self.service onJoinGroup:group];
}

- (void)onJoinGroupRequestWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onJoinGroupRequestWithRequestId: %lld group: %@ invitation: %@ memberId: %@", LOG_TAG, requestId, group, invitation, memberId);
    
    [(ShowGroupService *)self.service onJoinGroup:group];
}

- (void)onJoinGroupResponseWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onJoinGroupResponseWithRequestId: %lld group: %@ invitation: %@", LOG_TAG, requestId, group, invitation);
    
    [(ShowGroupService *)self.service onJoinGroup:group];
}

- (void)onLeaveGroupWithRequestId:(int64_t)requestId group:(nonnull id <TLGroupConversation>)group memberId:(nonnull NSUUID *)memberId {
    DDLogVerbose(@"%@ onLeaveGroupWithRequestId: %lld group: %@ memberId: %@", LOG_TAG, requestId, group, memberId);
    
    [self.service finishOperation:requestId];
    
    [(ShowGroupService *)self.service onLeaveGroup:group memberTwincodeId:memberId];
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
// Implementation: ShowGroupService
//

#undef LOG_TAG
#define LOG_TAG @"ShowGroupService"

@implementation ShowGroupService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <ShowGroupServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _conversationServiceDelegate = [[ShowGroupServiceConversationServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[ShowGroupServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)initWithGroup:(nonnull TLGroup *)group {
    
    self.group = group;
    self.groupId = group.uuid;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];
    [super dispose];
}

- (void)getGroupWithGroupId:(nonnull NSUUID *)groupId {
    DDLogVerbose(@"%@ getGroupWithGroupId groupId: %@", LOG_TAG, groupId);
    
    [self showProgressIndicator];
    self.work |= GET_GROUP | GET_GROUP_IMAGE | LIST_GROUP_MEMBER;
    self.state &= ~(GET_GROUP | GET_GROUP_DONE | GET_GROUP_IMAGE | GET_GROUP_IMAGE_DONE | LIST_GROUP_MEMBER | LIST_GROUP_MEMBER_DONE);
    self.groupId = groupId;
    [self startOperation];
}

- (void)getTwincodeOutboundWithTwincodeOutboundId:(NSUUID *)twincodeOutboundId {
    DDLogVerbose(@"%@ getTwincodeOutboundWithTwincodeOutboundId: %@", LOG_TAG, twincodeOutboundId);
    
    self.work |= GET_TWINCODE;
    self.state &= ~(GET_TWINCODE | GET_TWINCODE_DONE);
    self.twincodeOutboundId = twincodeOutboundId;
    
    [self startOperation];
}

- (void)updatePermissions:(BOOL)allowInvitation allowMessage:(BOOL)allowMessage allowInviteMemberAsContact:(BOOL)allowInviteMemberAsContact {
    DDLogVerbose(@"%@ updatePermissions: %@ allowMessage: %@ allowInviteMemberAsContact: %@", LOG_TAG, allowInvitation ? @"YES":@"NO", allowMessage ? @"YES":@"NO", allowInviteMemberAsContact ? @"YES":@"NO");
    
    long permissions = ~0;
    permissions &= ~(1 << TLPermissionTypeUpdateMember);
    permissions &= ~(1 << TLPermissionTypeRemoveMember);
    permissions &= ~(1 << TLPermissionTypeResetConversation);
    if (!allowInvitation) {
        permissions &= ~(1 << TLPermissionTypeInviteMember);
    }
    if (!allowMessage) {
        permissions &= ~(1 << TLPermissionTypeSendMessage);
        permissions &= ~(1 << TLPermissionTypeSendAudio);
        permissions &= ~(1 << TLPermissionTypeSendVideo);
        permissions &= ~(1 << TLPermissionTypeSendImage);
        permissions &= ~(1 << TLPermissionTypeSendFile);
    }
    if (!allowInviteMemberAsContact) {
        permissions &= ~(1 << TLPermissionTypeSendTwincode);
    }
    
    [[self.twinmeContext getConversationService] setPermissionsWithSubject:self.group memberTwincodeId:nil permissions:permissions];
}

- (void)leaveGroupWithMemberTwincodeId:(nonnull NSUUID *)memberTwincodeId {
    DDLogVerbose(@"%@ leaveGroupWithMemberTwincodeId: %@", LOG_TAG, memberTwincodeId);
    
    [self showProgressIndicator];
    
    if ([memberTwincodeId isEqual:self.group.twincodeOutboundId]) {
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
            [(id<ShowGroupServiceDelegate>)self.delegate onLeaveGroup:self.group memberTwincodeId:memberTwincodeId];
        }
    }
    [self startOperation];
}

#pragma mark - Private methods

- (void)onGetGroup:(TLGroup *)group {
    DDLogVerbose(@"%@ onGetGroup group: %@", LOG_TAG, group);
    
    self.state |= GET_GROUP_DONE;
    self.group = group;
    self.avatarId = group.avatarId;
    self.avatar = [self getImageWithGroup:group];
    
    [self runOnUpdateGroup:group avatar:self.avatar];
    [self onOperation];
}

- (void)onListGroupMembers:(nullable NSMutableArray<TLGroupMember *> *)members errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onListGroupMembers: %@ errorCode: %d", LOG_TAG, members, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !members) {
        [self onErrorWithOperationId:LIST_GROUP_MEMBER errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= LIST_GROUP_MEMBER_DONE;
    self.groupMembers = members;
    if ([(id)self.delegate respondsToSelector:@selector(onGetGroup:groupMembers:conversation:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ShowGroupServiceDelegate>)self.delegate onGetGroup:self.group groupMembers:self.groupMembers conversation:self.groupConversation];
        });
    }
    [self onOperation];
}

- (void)onUpdateGroup:(TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroup group: %@", LOG_TAG, group);
    
    if (![group.uuid isEqual:self.groupId]) {
        return;
    }
    self.group = group;
    
    // Check if the image was modified.
    if ((!self.avatarId && group.avatarId) || (self.avatarId && ![self.avatarId isEqual:group.avatarId])) {
        self.avatarId = group.avatarId;
        self.avatar = [self getImageWithGroup:group];
        self.state &= ~(GET_GROUP_THUMBNAIL_IMAGE | GET_GROUP_THUMBNAIL_IMAGE_DONE | GET_GROUP_IMAGE | GET_GROUP_IMAGE_DONE);
    }
    [self runOnUpdateGroup:group avatar:self.avatar];
    [self onOperation];
}

- (void)onDeleteGroup:(NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroup: %@", LOG_TAG, groupId);
    
    if ([groupId isEqual:self.groupId]) {
        self.state |= DELETE_GROUP_DONE;
        
        [self runOnDeleteGroup:groupId];
    }
    [self onOperation];
}

- (void)onLeaveGroup:(id<TLGroupConversation>)group memberTwincodeId:(NSUUID*)memberTwincodeId {
    DDLogVerbose(@"%@ onLeaveGroup group: %@ memberTwincodeId: %@", LOG_TAG, group, memberTwincodeId);
    
    if (!self.group || ![self.group.uuid isEqual:group.contactId]) {
        return;
    }
    if ([(id)self.delegate respondsToSelector:@selector(onLeaveGroup:memberTwincodeId:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ShowGroupServiceDelegate>)self.delegate onLeaveGroup:self.group memberTwincodeId:memberTwincodeId];
        });
    }
}

- (void)onJoinGroup:(id<TLGroupConversation>)group {
    DDLogVerbose(@"%@ onJoinGroup: %@", LOG_TAG, group);
    
    // If this is our group, refresh the information about the group and its members.
    if (group && [self.groupId isEqual:group.contactId] && [group state] == TLGroupConversationStateJoined) {
        self.work |= GET_GROUP | GET_GROUP_IMAGE | LIST_GROUP_MEMBER;
        self.state &= ~(GET_GROUP | GET_GROUP_DONE | GET_GROUP_IMAGE | GET_GROUP_IMAGE_DONE | LIST_GROUP_MEMBER | LIST_GROUP_MEMBER_DONE);
        [self onOperation];
    }
}

- (void)onGetTwincode:(TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetTwincode: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeOutbound == nil) {
        
        [self onErrorWithOperationId:GET_TWINCODE errorCode:errorCode errorParameter:self.twincodeOutboundId.UUIDString];
        return;
    }

    self.state |= GET_TWINCODE_DONE;
    
    if ([(id)self.delegate respondsToSelector:@selector(onGetTwincode:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ShowGroupServiceDelegate>)self.delegate onGetTwincode:twincodeOutbound];
        });
    }
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
                [self onGetGroup:group];
            }];
            return;
        }
        if ((self.state & GET_GROUP_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 1: Get the group thumbnail image if we can.
    //
    if (self.avatarId && !self.avatar) {
        if ((self.work & GET_GROUP_THUMBNAIL_IMAGE) != 0) {
            if ((self.state & GET_GROUP_THUMBNAIL_IMAGE) == 0) {
                self.state |= GET_GROUP_THUMBNAIL_IMAGE;
                
                TLImageService *imageService = [self.twinmeContext getImageService];
                [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                    self.state |= GET_GROUP_THUMBNAIL_IMAGE_DONE;
                    if (status == TLBaseServiceErrorCodeSuccess && image) {
                        self.avatar = image;
                        [self runOnUpdateGroup:self.group avatar:image];
                    }
                    [self onOperation];
                }];
                return;
            }
        }
        if ((self.state & GET_GROUP_IMAGE_DONE) == 0) {
            return;
        }
    }

    //
    // Step 2: We must get the group conversation and group members (each of them, one by one until we are done).
    //
    if ((self.work & LIST_GROUP_MEMBER) != 0) {
        if ((self.state & LIST_GROUP_MEMBER) == 0) {
            self.state |= LIST_GROUP_MEMBER;

            self.groupConversation = (id<TLGroupConversation>)[[self.twinmeContext getConversationService] getConversationWithSubject:self.group];
            if (!self.groupConversation) {
                [self onErrorWithOperationId:LIST_GROUP_MEMBER errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
                return;
            }

            [self.twinmeContext listGroupMembersWithGroup:self.group filter:TLGroupMemberFilterTypeJoinedMembers withBlock:^(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> *members) {
                [self onListGroupMembers:members errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & LIST_GROUP_MEMBER_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 3: Get the group large image if we can.
    //
    if (self.avatarId) {
        if ((self.work & GET_GROUP_IMAGE) != 0) {
            if ((self.state & GET_GROUP_IMAGE) == 0) {
                self.state |= GET_GROUP_IMAGE;
                
                TLImageService *imageService = [self.twinmeContext getImageService];
                [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindLarge withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                    self.state |= GET_GROUP_IMAGE_DONE;
                    if (status == TLBaseServiceErrorCodeSuccess && image) {
                        self.avatar = image;
                        [self runOnUpdateGroup:self.group avatar:image];
                    }
                    [self onOperation];
                }];

                // Hide the progress indicator now so that it disappears even if we are still trying to fetch the large image.
                [self hideProgressIndicator];
                return;
            }
        }
        if ((self.state & GET_GROUP_IMAGE_DONE) == 0) {
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
        switch (operationId) {
            case GET_GROUP:
                self.state |= GET_GROUP_DONE;
                
                if ([(id)self.delegate respondsToSelector:@selector(onErrorGroupNotFound)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [(id<ShowGroupServiceDelegate>)self.delegate onErrorGroupNotFound];
                    });
                }
                return;
                
            case UPDATE_GROUP:
                self.state |= UPDATE_GROUP_DONE;
                
                if ([(id)self.delegate respondsToSelector:@selector(onErrorGroupNotFound)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [(id<ShowGroupServiceDelegate>)self.delegate onErrorGroupNotFound];
                    });
                }
                return;
                
            case LIST_GROUP_MEMBER:
                self.state |= LIST_GROUP_MEMBER_DONE;
                if ([(id)self.delegate respondsToSelector:@selector(onErrorGroupNotFound)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [(id<ShowGroupServiceDelegate>)self.delegate onErrorGroupNotFound];
                    });
                }
                return;
                
            default:
                break;
        }
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
