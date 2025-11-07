/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLTwincodeOutboundService.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLTwinmeAttributes.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLRoomCommand.h>
#import <Twinme/TLRoomCommandResult.h>

#import "RoomMemberService.h"
#import "AbstractTwinmeService+Protected.h"

static const int MAX_MEMBERS = 20;

static const int GET_ROOM_ADMIN = 1 << 0;
static const int GET_ROOM_ADMIN_DONE = 1 << 1;
static const int GET_ROOM_MEMBERS = 1 << 2;
static const int GET_ROOM_MEMBERS_DONE = 1 << 3;
static const int GET_ROOM_MEMBER = 1 << 4;
static const int GET_ROOM_MEMBER_DONE = 1 << 5;
static const int GET_ROOM_MEMBER_AVATAR = 1 << 6;
static const int GET_ROOM_MEMBER_AVATAR_DONE = 1 << 7;
static const int SET_ROOM_ADMINISTRATOR = 1 << 8;
static const int SET_ROOM_ADMINISTRATOR_DONE = 1 << 9;
static const int REMOVE_MEMBER = 1 << 10;
static const int REMOVE_MEMBER_DONE = 1 << 11;
static const int INVITE_MEMBER = 1 << 12;
static const int INVITE_MEMBER_DONE = 1 << 13;
static const int REMOVE_ROOM_ADMINISTRATOR = 1 << 14;
static const int REMOVE_ROOM_ADMINISTRATOR_DONE = 1 << 15;

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: RoomMemberService ()
//

@class RoomMemberServiceTwinmeContextDelegate;
@class RoomMemberServiceConversationServiceDelegate;

@interface RoomMemberService ()

@property (nonatomic, nullable) TLContact *room;
@property (nonatomic, nullable) TLImageId *avatarId;
@property (nonatomic, nullable) UIImage *avatar;
@property (nonatomic, nullable) NSMutableArray<NSUUID *> *allAdminIds;
@property (nonatomic, nullable) NSMutableArray<NSUUID *> *adminIds;
@property (nonatomic, nullable) NSMutableArray<NSUUID *> *memberIds;
@property (nonatomic, nullable) NSUUID *adminMemberId;
@property (nonatomic, nullable) NSUUID *currentRoomMemberId;
@property (nonatomic, nullable) NSUUID *removeMemberId;
@property (nonatomic, nullable) NSUUID *inviteMemberId;
@property (nonatomic, nullable) TLTwincodeOutbound *adminTwincodeOutbound;
@property (nonatomic, nullable) TLTwincodeOutbound *currentTwincodeOutbound;
@property (nonatomic, nullable) NSMutableArray<TLTwincodeOutbound *> *roomAdmins;
@property (nonatomic, nullable) NSMutableArray<TLTwincodeOutbound *> *roomMembers;
@property (nonatomic) int work;
@property (nonatomic) BOOL getAdminsDone;

@property (nonatomic, readonly, nonnull) RoomMemberServiceConversationServiceDelegate *conversationServiceDelegate;

- (void)onOperation;

- (void)onGetRoomAdmin:(TLRoomCommandResult *)roomCommandResult;

- (void)onGetRoomMembers:(TLRoomCommandResult *)roomCommandResult;

- (void)onSetRoomAdmin:(TLRoomCommandResult *)roomCommandResult;

- (void)onRemoveRoomAdmin:(TLRoomCommandResult *)roomCommandResult;

- (void)onRemoveMember:(TLRoomCommandResult *)roomCommandResult;

@end

//
// Interface: RoomMemberServiceTwinmeContextDelegate
//

@interface RoomMemberServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull RoomMemberService *)service;

@end

//
// Implementation: RoomMemberServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"RoomMemberServiceTwinmeContextDelegate"

@implementation RoomMemberServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull RoomMemberService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    RoomMemberService *roomService = (RoomMemberService *)self.service;

    if (![contact.uuid isEqual:roomService.room.uuid]) {

        return;
    }

    // May be we have received the private peer twincode and we can proceed with other operations.
    [roomService onOperation];
}

@end

//
// Interface: RoomMemberServiceConversationServiceDelegate
//

@interface RoomMemberServiceConversationServiceDelegate : NSObject <TLConversationServiceDelegate>

@property (weak) RoomMemberService *service;

- (instancetype)initWithService:(RoomMemberService *)service;

@end

//
// Implementation: RoomMemberServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"RoomMemberServiceConversationServiceDelegate"

@implementation RoomMemberServiceConversationServiceDelegate

- (instancetype)initWithService:(RoomMemberService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onPopDescriptorWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopDescriptorWithRequestId: %lld conversation: %@ objectDescriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    if ([descriptor getType] != TLDescriptorTypeTransientObjectDescriptor) {
        return;
    }
    
    TLTransientObjectDescriptor *command = (TLTransientObjectDescriptor *) descriptor;
    NSObject *object = command.object;
    
    if (![object isKindOfClass:[TLRoomCommandResult class]]) {
        return;
    }
    
    TLRoomCommandResult *result = (TLRoomCommandResult *) object;
    
    int operationId = [self.service getOperation:result.requestId];
    if (!operationId) {
        return;
    }

    if (operationId == GET_ROOM_ADMIN) {
        [self.service onGetRoomAdmin:result];
    } else if (operationId == GET_ROOM_MEMBERS) {
        [self.service onGetRoomMembers:result];
    } else if (operationId == SET_ROOM_ADMINISTRATOR) {
        [self.service onSetRoomAdmin:result];
    } else if (operationId == REMOVE_ROOM_ADMINISTRATOR) {
        [self.service onRemoveRoomAdmin:result];
    } else if (operationId == REMOVE_MEMBER) {
        [self.service onRemoveMember:result];
    }
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    [self.service finishOperation:requestId];
}

@end


//
// Implementation: RoomMemberService
//

#undef LOG_TAG
#define LOG_TAG @"RoomMemberService"

@implementation RoomMemberService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<RoomMemberServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _work = 0;
        _getAdminsDone = NO;
        _conversationServiceDelegate = [[RoomMemberServiceConversationServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[RoomMemberServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)initWithRoom:(nonnull TLContact *)room {
    DDLogVerbose(@"%@ initWithRoom: %@", LOG_TAG, room);
    
    self.room = room;
    
    self.state &= ~(GET_ROOM_ADMIN | GET_ROOM_ADMIN_DONE);
    
    [self showProgressIndicator];
    [self startOperation];
}

- (void)nextMembers {
    DDLogVerbose(@"%@ nextMembers", LOG_TAG);
    
    if (self.memberIds.count == 0) {
        return;
    }
    
    self.work |= GET_ROOM_MEMBER;
    self.state &= ~(GET_ROOM_MEMBER | GET_ROOM_MEMBER_DONE);
    
    [self nextRoomMember];
    [self showProgressIndicator];
    [self startOperation];
}

- (void)setRoomAdministrator:(nonnull NSUUID *)memberId {
    DDLogVerbose(@"%@ setRoomAdministrator: %@", LOG_TAG, memberId);
    
    self.adminMemberId = memberId;
    self.work |= SET_ROOM_ADMINISTRATOR;
    self.state &= ~(SET_ROOM_ADMINISTRATOR | SET_ROOM_ADMINISTRATOR_DONE);
    [self startOperation];
}

- (void)removeAdministrator:(nonnull NSUUID *)memberId {
    DDLogVerbose(@"%@ removeAdministrator: %@", LOG_TAG, memberId);
    
    self.adminMemberId = memberId;
    self.work |= REMOVE_ROOM_ADMINISTRATOR;
    self.state &= ~(REMOVE_ROOM_ADMINISTRATOR | REMOVE_ROOM_ADMINISTRATOR_DONE);
    [self startOperation];
}

- (void)inviteMember:(nonnull NSUUID *)memberId {
    DDLogVerbose(@"%@ inviteMember: %@", LOG_TAG, memberId);
    
    self.inviteMemberId = memberId;
    self.work |= INVITE_MEMBER;
    self.state &= ~(INVITE_MEMBER | INVITE_MEMBER_DONE);
    [self startOperation];
}

- (void)removeMember:(nonnull NSUUID *)memberId {
    DDLogVerbose(@"%@ removeMember: %@", LOG_TAG, memberId);
    
    self.removeMemberId = memberId;
    self.work |= REMOVE_MEMBER;
    self.state &= ~(REMOVE_MEMBER | REMOVE_MEMBER_DONE);
    [self startOperation];
}

#pragma mark - Private methods

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    self.isTwinlifeReady = YES;
    
    [[self.twinmeContext getConversationService] addDelegate:self.conversationServiceDelegate];
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];
    
    [super dispose];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }

    // If the room has no private peer yet, we cannot make API requests on it.
    // Every step below requires a valid private peer.
    if (![self.room hasPrivatePeer]) {

        return;
    }

    //
    // Step 1: Get admin
    //
    if ((self.state & GET_ROOM_ADMIN) == 0) {
        self.state |= GET_ROOM_ADMIN;
        
        int64_t requestId = [self newOperation:GET_ROOM_ADMIN];
        DDLogVerbose(@"%@ roomListMembersWithRequestId: %lld contact: %@", LOG_TAG, requestId, self.room);
        [self.twinmeContext roomListMembersWithRequestId:requestId contact:self.room filter:TL_ROOM_COMMAND_LIST_ROLE_ADMINISTRATOR];
        return;
    }
    
    if ((self.state & GET_ROOM_ADMIN_DONE) == 0) {
        return;
    }
    
    //
    // Get members
    //
    if ((self.work & GET_ROOM_MEMBERS) != 0) {
        if ((self.state & GET_ROOM_MEMBERS) == 0) {
            self.state |= GET_ROOM_MEMBERS;
            
            int64_t requestId = [self newOperation:GET_ROOM_MEMBERS];
            DDLogVerbose(@"%@ roomListMembersWithRequestId: %lld contact: %@", LOG_TAG, requestId, self.room);
            [self.twinmeContext roomListMembersWithRequestId:requestId contact:self.room filter:TL_ROOM_COMMAND_LIST_ROLE_MEMBER];
            return;
        }
        
        if ((self.state & GET_ROOM_MEMBERS_DONE) == 0) {
            return;
        }
    }
    
    // We must get the room members (each of them, one by one until we are done).
    if ((self.work & GET_ROOM_MEMBER) != 0) {
        if ((self.state & GET_ROOM_MEMBER) == 0) {
            self.state |= GET_ROOM_MEMBER;

            [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.currentRoomMemberId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onGetRoomMember:twincodeOutbound];
            }];
            return;
        }
        if ((self.state & GET_ROOM_MEMBER_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & GET_ROOM_MEMBER_AVATAR) != 0) {
        if ((self.state & GET_ROOM_MEMBER_AVATAR) == 0) {
            self.state |= GET_ROOM_MEMBER_AVATAR;
            
            [[self.twinmeContext getImageService] getImageWithImageId:[self.currentTwincodeOutbound avatarId] kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                [self onGetRoomMemberAvatar:self.currentTwincodeOutbound avatar:image];
            }];
            return;
        }
        if ((self.state & GET_ROOM_MEMBER_AVATAR_DONE) == 0) {
            return;
        }
    }
    
    //
    // set administrator
    //
    if (self.adminMemberId && (self.work & SET_ROOM_ADMINISTRATOR) != 0) {
        if ((self.state & SET_ROOM_ADMINISTRATOR) == 0) {
            self.state |= SET_ROOM_ADMINISTRATOR;
            
            int64_t requestId = [self newOperation:SET_ROOM_ADMINISTRATOR];
            DDLogVerbose(@"%@ roomSetAdministratorWithRequestId: %lld contact: %@ memberTwincodeOutboundId: %@", LOG_TAG, requestId, self.room, self.adminMemberId);
            [self.twinmeContext roomSetRolesWithRequestId:requestId contact:self.room role:TL_ROOM_COMMAND_ROLE_ADMIN members:@[self.adminMemberId]];
            return;
        }
        
        if ((self.state & SET_ROOM_ADMINISTRATOR_DONE) == 0) {
            return;
        }
    }
    
    if (self.adminMemberId && (self.work & REMOVE_ROOM_ADMINISTRATOR) != 0) {
        if ((self.state & REMOVE_ROOM_ADMINISTRATOR) == 0) {
            self.state |= REMOVE_ROOM_ADMINISTRATOR;
            
            int64_t requestId = [self newOperation:REMOVE_ROOM_ADMINISTRATOR];
            DDLogVerbose(@"%@ roomSetAdministratorWithRequestId: %lld contact: %@ memberTwincodeOutboundId: %@", LOG_TAG, requestId, self.room, self.adminMemberId);
            [self.twinmeContext roomSetRolesWithRequestId:requestId contact:self.room role:TL_ROOM_COMMAND_ROLE_MEMBER members:@[self.adminMemberId]];
            return;
        }
        
        if ((self.state & REMOVE_ROOM_ADMINISTRATOR_DONE) == 0) {
            return;
        }
    }
    
    //
    // remove member
    //
    if (self.removeMemberId && (self.work & REMOVE_MEMBER) != 0) {
        if ((self.state & REMOVE_MEMBER) == 0) {
            self.state |= REMOVE_MEMBER;
            
            int64_t requestId = [self newOperation:REMOVE_MEMBER];
            DDLogVerbose(@"%@ roomDeleteMemberWithRequestId: %lld contact: %@ memberTwincodeOutboundId: %@", LOG_TAG, requestId, self.room, self.removeMemberId);
            [self.twinmeContext roomDeleteMemberWithRequestId:requestId contact:self.room memberTwincodeOutboundId:self.removeMemberId];
            return;
        }
        
        if ((self.state & REMOVE_MEMBER_DONE) == 0) {
            return;
        }
    }
    
    //
    // invite member
    //
    if (self.inviteMemberId && (self.work & INVITE_MEMBER) != 0) {
        if ((self.state & INVITE_MEMBER) == 0) {
            self.state |= INVITE_MEMBER;
            
            int64_t requestId = [self newOperation:INVITE_MEMBER];
            DDLogVerbose(@"%@ createInvitationWithRequestId: %lld contact: %@ sendTo: %@", LOG_TAG, requestId, self.room, self.inviteMemberId);
            [self.twinmeContext createInvitationWithRequestId:requestId contact:self.room sendTo:self.inviteMemberId];
            return;
        }
        
        if ((self.state & INVITE_MEMBER_DONE) == 0) {
            return;
        }
    }
    
    [self hideProgressIndicator];
}

- (void)onGetRoomAdmin:(TLRoomCommandResult *)roomCommandResult{
    DDLogVerbose(@"%@ onGetRoomAdmin: %@", LOG_TAG, roomCommandResult);
    
    self.state |= GET_ROOM_ADMIN_DONE;
    
    if (roomCommandResult.memberIds) {
        self.work |= GET_ROOM_MEMBER;
        self.state &= ~(GET_ROOM_MEMBER | GET_ROOM_MEMBER_DONE);
        
        self.adminIds = [NSMutableArray arrayWithArray:roomCommandResult.memberIds];
        self.roomAdmins = [[NSMutableArray alloc] init];
        [self nextRoomAdmin];
    } else {
        self.getAdminsDone = YES;
        self.roomAdmins = [[NSMutableArray alloc] init];
        if (self.delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<RoomMemberServiceDelegate>)self.delegate onGetRoomAdmins:self.roomAdmins];
            });
        }
        
        self.work |= GET_ROOM_MEMBERS;
        self.state &= ~(GET_ROOM_MEMBERS | GET_ROOM_MEMBERS_DONE);
    }
    
    [self onOperation];
}

- (void)onGetRoomMembers:(TLRoomCommandResult *)roomCommandResult{
    DDLogVerbose(@"%@ onGetRoomMembers: %@", LOG_TAG, roomCommandResult);
    
    self.state |= GET_ROOM_MEMBERS_DONE;
    
    if (roomCommandResult.memberIds) {
        self.memberIds = [NSMutableArray arrayWithArray:roomCommandResult.memberIds];
        self.roomMembers = [[NSMutableArray alloc] init];
        [self nextRoomMember];
    }
    
    [self onOperation];
}

- (void)onGetRoomMember:(TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@ onGetRoomMember: %@", LOG_TAG, twincodeOutbound);
    
    self.state |= GET_ROOM_MEMBER_DONE;
    
    if (!self.getAdminsDone) {
        if (twincodeOutbound) {
            [self.roomAdmins addObject:twincodeOutbound];
        }
        [self nextRoomAdmin];
    } else {
        if (twincodeOutbound) {
            [self.roomMembers addObject:twincodeOutbound];
        }
        [self nextRoomMember];
    }
    [self onOperation];
}

- (void)nextRoomMember {
    DDLogVerbose(@"%@ nextRoomMember", LOG_TAG);
    
    while (self.memberIds.count > 0 && self.roomMembers.count < MAX_MEMBERS) {
        self.currentRoomMemberId = [self.memberIds objectAtIndex:0];
        [self.memberIds removeObjectAtIndex:0];
        if (self.currentRoomMemberId) {
            self.work |= GET_ROOM_MEMBER;
            self.state &= ~(GET_ROOM_MEMBER | GET_ROOM_MEMBER_DONE);
            return;
        }
    }
    
    self.currentRoomMemberId = nil;
    self.state |= GET_ROOM_MEMBER | GET_ROOM_MEMBER_DONE;
    if (self.delegate) {
        // Make a copy of the list of room members because `nextRoomMemberAvatar` iteration will
        // remove entries while it fetches avatars.
        NSArray<TLTwincodeOutbound *> *roomMembers = [[NSArray alloc] initWithArray:self.roomMembers];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<RoomMemberServiceDelegate>)self.delegate onGetRoomMembers:roomMembers];
        });
        self.work |= GET_ROOM_MEMBER_AVATAR;
        [self nextRoomMemberAvatar];
    }
}

- (void)nextRoomAdmin {
    DDLogVerbose(@"%@ nextRoomAdmin", LOG_TAG);
    
    while (self.adminIds.count > 0) {
        self.currentRoomMemberId = [self.adminIds objectAtIndex:0];
        [self.adminIds removeObjectAtIndex:0];
        if (self.currentRoomMemberId) {
            self.work |= GET_ROOM_MEMBER;
            self.state &= ~(GET_ROOM_MEMBER | GET_ROOM_MEMBER_DONE);
            return;
        }
    }
    
    if (self.adminIds.count == 0) {
        self.getAdminsDone = YES;
    }
    
    self.currentRoomMemberId = nil;
    self.state |= GET_ROOM_MEMBER | GET_ROOM_MEMBER_DONE;
    if (self.delegate) {
        // Make a copy of the list of room members because `nextRoomMemberAvatar` iteration will
        // remove entries while it fetches avatars.
        NSArray<TLTwincodeOutbound *> *roomAdmins = [[NSArray alloc] initWithArray:self.roomAdmins];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<RoomMemberServiceDelegate>)self.delegate onGetRoomAdmins:roomAdmins];
        });
        self.work |= GET_ROOM_MEMBER_AVATAR;
        [self nextRoomAdminAvatar];
    }
}

- (void)onGetRoomMemberAvatar:(TLTwincodeOutbound *)twincodeOutbound avatar:(UIImage *)avatar {
    DDLogVerbose(@"%@ onGetRoomMember: %@ avatar: %@", LOG_TAG, twincodeOutbound, avatar);
    
    self.state |= GET_ROOM_MEMBER_AVATAR_DONE;
    if (self.delegate) {
        if (self.roomAdmins.count > 0 || !self.roomMembers) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<RoomMemberServiceDelegate>)self.delegate onGetRoomAdminAvatar:twincodeOutbound avatar:avatar];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<RoomMemberServiceDelegate>)self.delegate onGetRoomMemberAvatar:twincodeOutbound avatar:avatar];
            });
        }
    }
    
    if ((self.roomAdmins.count > 0)) {
        [self nextRoomAdminAvatar];
    } else if ((self.roomMembers.count > 0)) {
        [self nextRoomMemberAvatar];
    } else if (!self.roomMembers) {
        self.work |= GET_ROOM_MEMBERS;
        self.state &= ~(GET_ROOM_MEMBERS | GET_ROOM_MEMBERS_DONE);
    }
    [self onOperation];
}

- (void)nextRoomMemberAvatar {
    DDLogVerbose(@"%@ nextRoomMemberAvatar", LOG_TAG);
    
    while (self.roomMembers.count > 0) {
        self.currentTwincodeOutbound = [self.roomMembers objectAtIndex:0];
        [self.roomMembers removeObjectAtIndex:0];
        if (self.currentTwincodeOutbound) {
            self.state &= ~(GET_ROOM_MEMBER_AVATAR | GET_ROOM_MEMBER_AVATAR_DONE);
            return;
        }
    }
    self.currentTwincodeOutbound = nil;
    self.state |= GET_ROOM_MEMBER_AVATAR | GET_ROOM_MEMBER_AVATAR_DONE;
}

- (void)nextRoomAdminAvatar {
    DDLogVerbose(@"%@ nextRoomAdminAvatar", LOG_TAG);
    
    while (self.roomAdmins.count > 0) {
        self.currentTwincodeOutbound = [self.roomAdmins objectAtIndex:0];
        [self.roomAdmins removeObjectAtIndex:0];
        if (self.currentTwincodeOutbound) {
            self.state &= ~(GET_ROOM_MEMBER_AVATAR | GET_ROOM_MEMBER_AVATAR_DONE);
            return;
        }
    }
    self.currentTwincodeOutbound = nil;
    self.state |= GET_ROOM_MEMBER_AVATAR | GET_ROOM_MEMBER_AVATAR_DONE;
}

- (void)onSetRoomAdmin:(TLRoomCommandResult *)roomCommandResult {
    DDLogVerbose(@"%@ onSetRoomAdmin: %@", LOG_TAG, roomCommandResult);
    
    self.state |= SET_ROOM_ADMINISTRATOR_DONE;
    
    if (roomCommandResult.status == TLRoomCommandStatusSuccess) {
        if (self.delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<RoomMemberServiceDelegate>)self.delegate onSetAdministrator:self.adminMemberId];
            });
        }
    }
    
    [self onOperation];
}

- (void)onRemoveRoomAdmin:(TLRoomCommandResult *)roomCommandResult {
    DDLogVerbose(@"%@ onRemoveRoomAdmin: %@", LOG_TAG, roomCommandResult);
    
    self.state |= REMOVE_ROOM_ADMINISTRATOR_DONE;
    
    if (roomCommandResult.status == TLRoomCommandStatusSuccess) {
        if (self.delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<RoomMemberServiceDelegate>)self.delegate onRemoveAdministrator:self.adminMemberId];
            });
        }
    }
    
    [self onOperation];
}

- (void)onRemoveMember:(TLRoomCommandResult *)roomCommandResult {
    DDLogVerbose(@"%@ onRemoveMember: %@", LOG_TAG, roomCommandResult);
    
    self.state |= REMOVE_MEMBER_DONE;
    
    if (roomCommandResult.status == TLRoomCommandStatusSuccess) {
        if (self.delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<RoomMemberServiceDelegate>)self.delegate onRemoveMember:self.removeMemberId];
            });
        }
    }
    
    [self onOperation];
}

@end
