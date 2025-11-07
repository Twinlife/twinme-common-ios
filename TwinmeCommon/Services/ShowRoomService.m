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

#import "ShowRoomService.h"
#import "AbstractTwinmeService+Protected.h"

static const int GET_ROOM_THUMBNAIL_IMAGE = 1 << 0;
static const int GET_ROOM_THUMBNAIL_IMAGE_DONE = 1 << 1;
static const int GET_ROOM_IMAGE = 1 << 2;
static const int GET_ROOM_IMAGE_DONE = 1 << 3;
static const int DELETE_ROOM = 1 << 4;
static const int DELETE_ROOM_DONE = 1 << 5;
static const int GET_ROOM_MEMBERS = 1 << 6;
static const int GET_ROOM_MEMBERS_DONE = 1 << 7;
static const int GET_ROOM_MEMBER = 1 << 8;
static const int GET_ROOM_MEMBER_DONE = 1 << 9;
static const int GET_ROOM_MEMBER_AVATAR = 1 << 10;
static const int GET_ROOM_MEMBER_AVATAR_DONE = 1 << 11;

static int MAX_ROOM_MEMBER = 5;

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: ShowRoomService ()
//

@class ShowRoomServiceTwinmeContextDelegate;
@class ShowRoomServiceConversationServiceDelegate;

@interface ShowRoomService ()

@property (nonatomic, nullable) TLContact *room;
@property (nonatomic, nullable) TLImageId *avatarId;
@property (nonatomic) int membersCount;
@property (nonatomic, nullable) UIImage *avatar;
@property (nonatomic, nullable) NSMutableArray<NSUUID *> *memberIds;
@property (nonatomic, nullable) NSUUID *currentRoomMemberId;
@property (nonatomic, nullable) TLTwincodeOutbound *currentTwincodeOutbound;
@property (nonatomic, nullable) NSMutableArray<TLTwincodeOutbound *> *roomMembers;
@property (nonatomic) int work;

@property (nonatomic, readonly, nonnull) ShowRoomServiceConversationServiceDelegate *conversationServiceDelegate;

- (void)onOperation;

- (void)onUpdateRoom:(nonnull TLContact *)room;

- (void)onDeleteRoom:(nonnull NSUUID *)roomId;

- (void)onGetRoomMembers:(TLRoomCommandResult *)roomCommandResult;

@end

//
// Interface: ShowRoomServiceTwinmeContextDelegate
//

@interface ShowRoomServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ShowRoomService *)service;

@end

//
// Implementation: ShowRoomServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ShowRoomServiceTwinmeContextDelegate"

@implementation ShowRoomServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ShowRoomService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    ShowRoomService *roomService = (ShowRoomService *)self.service;

    if (![contact.uuid isEqual:roomService.room.uuid]) {

        return;
    }

    [roomService onUpdateRoom:contact];

    // May be we have received the private peer twincode and we can proceed with other operations.
    [roomService onOperation];
}

- (void)onDeleteContactWithRequestId:(int64_t)requestId contactId:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contactId);

    ShowRoomService *roomService = (ShowRoomService *)self.service;

    if (![contactId isEqual:roomService.room.uuid]) {

        return;
    }

    [roomService finishOperation:requestId];
    
    [roomService onDeleteRoom:contactId];
}

@end

//
// Interface: ShowRoomServiceConversationServiceDelegate
//

@interface ShowRoomServiceConversationServiceDelegate : NSObject <TLConversationServiceDelegate>

@property (weak) ShowRoomService *service;

- (instancetype)initWithService:(ShowRoomService *)service;

@end

//
// Implementation: ShowRoomServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ShowRoomServiceConversationServiceDelegate"

@implementation ShowRoomServiceConversationServiceDelegate

- (instancetype)initWithService:(ShowRoomService *)service {
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

    if (operationId == GET_ROOM_MEMBERS) {
        [self.service onGetRoomMembers:result];
    }
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    [self.service finishOperation:requestId];
}

@end


//
// Implementation: ShowRoomService
//

#undef LOG_TAG
#define LOG_TAG @"ShowRoomService"

@implementation ShowRoomService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<ShowRoomServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _work = 0;
        _conversationServiceDelegate = [[ShowRoomServiceConversationServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[ShowRoomServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)initWithRoom:(nonnull TLContact *)room {
    DDLogVerbose(@"%@ initWithRoom: %@", LOG_TAG, room);
    
    self.room = room;
    self.avatarId = room.avatarId;
    
    self.state &= ~(GET_ROOM_MEMBERS | GET_ROOM_MEMBERS_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)deleteRoom:(nonnull TLContact *)room {
    DDLogVerbose(@"%@ deleteRoom: %@", LOG_TAG, room);
    
    self.room = room;
    self.work |= DELETE_ROOM;
    [self showProgressIndicator];
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
    
    //
    // Step 1: Get the contact thumbnail image if we can.
    //
    if (self.avatarId && !self.avatar) {
        if ((self.state & GET_ROOM_THUMBNAIL_IMAGE) == 0) {
            self.state |= GET_ROOM_THUMBNAIL_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                self.state |= GET_ROOM_THUMBNAIL_IMAGE_DONE;
                self.avatar = image;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [(id<ShowRoomServiceDelegate>)self.delegate onUpdateRoom:self.room avatar:image];
                });
                [self onOperation];
            }];
            return;
        }
        
        if ((self.state & GET_ROOM_THUMBNAIL_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 2: Get the room large image if we can.
    //
    if (self.avatarId) {
        if ((self.state & GET_ROOM_IMAGE) == 0) {
            self.state |= GET_ROOM_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindLarge withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                self.state |= GET_ROOM_IMAGE_DONE;
                self.avatar = image;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [(id<ShowRoomServiceDelegate>)self.delegate onUpdateRoom:self.room avatar:image];
                });
                [self onOperation];
            }];
            return;
        }
        
        if ((self.state & GET_ROOM_IMAGE_DONE) == 0) {
            return;
        }
    }

    //
    // Work step: we must delete the room (it must be possible even if we don't have the private peer!).
    //
    if (self.room && (self.work & DELETE_ROOM) != 0) {
        if ((self.state & DELETE_ROOM) == 0) {
            self.state |= DELETE_ROOM;
            
            int64_t requestId = [self newOperation:DELETE_ROOM];
            DDLogVerbose(@"%@ deleteContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, self.room);
            [self.twinmeContext deleteContactWithRequestId:requestId contact:self.room];
            return;
        }
        
        if ((self.state & DELETE_ROOM_DONE) == 0) {
            return;
        }
    }

    // If the room has no private peer yet, we cannot make API requests on it.
    // Every step below requires a valid private peer.
    if (![self.room hasPrivatePeer]) {

        return;
    }

    //
    // Step 3: Get members list
    //
    if ((self.state & GET_ROOM_MEMBERS) == 0) {
        self.state |= GET_ROOM_MEMBERS;
        
        int64_t requestId = [self newOperation:GET_ROOM_MEMBERS];
        DDLogVerbose(@"%@ roomListMembersWithRequestId: %lld contact: %@", LOG_TAG, requestId, self.room);
        [self.twinmeContext roomListMembersWithRequestId:requestId contact:self.room filter:TL_ROOM_COMMAND_LIST_ALL];
        return;
    }
    
    if ((self.state & GET_ROOM_MEMBERS_DONE) == 0) {
        return;
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
    
    [self hideProgressIndicator];
}

- (void)onUpdateRoom:(nonnull TLContact *)room {
    DDLogVerbose(@"%@ onUpdateRoom: %@", LOG_TAG, room);

    self.room = room;
    
    // Check if the image was modified.
    if ((!self.avatarId && room.avatarId) || (self.avatarId && [self.avatarId isEqual:room.avatarId])) {
        self.avatarId = room.avatarId;
        self.avatar = [self getImageWithContact:room];
        self.state &= ~(GET_ROOM_THUMBNAIL_IMAGE | GET_ROOM_THUMBNAIL_IMAGE_DONE | GET_ROOM_IMAGE | GET_ROOM_IMAGE_DONE);
    }
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ShowRoomServiceDelegate>)self.delegate onUpdateRoom:room avatar:self.avatar];
        });
    }
}

- (void)onDeleteRoom:(nonnull NSUUID *)roomId {
    DDLogVerbose(@"%@ onDeleteRoom: %@", LOG_TAG, roomId);

    self.state |= DELETE_ROOM_DONE;
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ShowRoomServiceDelegate>)self.delegate onDeleteRoom:roomId];
        });
    }
    [self onOperation];
}

- (void)onGetRoomMembers:(TLRoomCommandResult *)roomCommandResult{
    DDLogVerbose(@"%@ onGetRoomMembers: %@", LOG_TAG, roomCommandResult);
    
    self.state |= GET_ROOM_MEMBERS_DONE;
    
    if (roomCommandResult.memberIds) {
        self.work |= GET_ROOM_MEMBER;
        self.state &= ~(GET_ROOM_MEMBER | GET_ROOM_MEMBER_DONE);
        
        self.memberIds = [NSMutableArray arrayWithArray:roomCommandResult.memberIds];
        self.roomMembers = [[NSMutableArray alloc] init];
        self.membersCount = (int) self.memberIds.count;
        [self nextRoomMember];
    }
    
    [self onOperation];
}

- (void)onGetRoomMember:(TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@ onGetRoomMember: %@", LOG_TAG, twincodeOutbound);
    
    self.state |= GET_ROOM_MEMBER_DONE;
    
    if (twincodeOutbound) {
        [self.roomMembers addObject:twincodeOutbound];
    }
    [self nextRoomMember];
    [self onOperation];
}

- (void)nextRoomMember {
    DDLogVerbose(@"%@ nextRoomMember", LOG_TAG);
    
    while (self.memberIds.count > 0 && self.roomMembers.count < MAX_ROOM_MEMBER) {
        self.currentRoomMemberId = [self.memberIds objectAtIndex:0];
        [self.memberIds removeObjectAtIndex:0];
        if (self.currentRoomMemberId) {
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
            [(id<ShowRoomServiceDelegate>)self.delegate onGetRoomMembers:roomMembers memberCount:self.membersCount];
        });
        
        self.work |= GET_ROOM_MEMBER_AVATAR;
        [self nextRoomMemberAvatar];
    }
}

- (void)onGetRoomMemberAvatar:(TLTwincodeOutbound *)twincodeOutbound avatar:(UIImage *)avatar {
    DDLogVerbose(@"%@ onGetRoomMember: %@ avatar: %@", LOG_TAG, twincodeOutbound, avatar);
    
    self.state |= GET_ROOM_MEMBER_AVATAR_DONE;
    
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ShowRoomServiceDelegate>)self.delegate onGetRoomMemberAvatar:twincodeOutbound avatar:avatar];
        });
    }
    
    [self nextRoomMemberAvatar];
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

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    if (operationId == DELETE_ROOM) {
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            self.state |= DELETE_ROOM_DONE;
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<ShowRoomServiceDelegate>)self.delegate onDeleteRoom:self.room.uuid];
            });
            return;
        }
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
