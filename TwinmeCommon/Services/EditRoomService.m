/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "EditRoomService.h"

#import <CocoaLumberjack.h>

#import <Twinlife/TLConversationService.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLRoomCommand.h>
#import <Twinme/TLRoomCommandResult.h>
#import <Twinme/TLRoomConfigResult.h>
#import <Twinme/TLRoomConfig.h>

#import "EditRoomService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int UPDATE_ROOM_NAME = 1 << 0;
static const int UPDATE_ROOM_NAME_DONE = 1 << 1;
static const int UPDATE_ROOM_AVATAR = 1 << 2;
static const int UPDATE_ROOM_AVATAR_DONE = 1 << 3;
static const int UPDATE_ROOM_WELCOME_MESSAGE = 1 << 4;
static const int UPDATE_ROOM_WELCOME_MESSAGE_DONE = 1 << 5;
static const int DELETE_ROOM = 1 << 6;
static const int DELETE_ROOM_DONE = 1 << 7;
static const int ROOM_GET_CONFIG = 1 << 8;
static const int ROOM_GET_CONFIG_DONE = 1 << 9;
static const int ROOM_SET_CONFIG = 1 << 10;
static const int ROOM_SET_CONFIG_DONE = 1 << 11;

//
// Interface: EditRoomService ()
//

@class EditRoomServiceTwinmeContextDelegate;
@class EditRoomServiceConversationServiceDelegate;

@interface EditRoomService ()

@property (nonatomic, nullable) TLContact *room;
@property (nonatomic, nullable) TLRoomConfig *roomConfig;
@property (nonatomic, nullable) NSString *name;
@property (nonatomic, nullable) UIImage *avatar;
@property (nonatomic, nullable) UIImage *largeAvatar;
@property (nonatomic, nullable) NSString *welcomeMessage;
@property (nonatomic) int work;

@property (nonatomic, readonly, nonnull) EditRoomServiceConversationServiceDelegate *conversationServiceDelegate;

- (void)onOperation;

- (void)onDeleteRoom:(NSUUID *)groupId;

- (void)onRoomCommandResult:(TLRoomCommandResult *)roomCommandResult operationId:(int)operationId;

@end

//
// Interface: EditRoomServiceTwinmeContextDelegate
//

@interface EditRoomServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull EditRoomService *)service;

@end

//
// Implementation: EditRoomServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"EditRoomServiceTwinmeContextDelegate"

@implementation EditRoomServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull EditRoomService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    EditRoomService *roomService = (EditRoomService *)self.service;

    if (![contact.uuid isEqual:roomService.room.uuid]) {

        return;
    }                                                                                                                                                                                                          

    // May be we have received the private peer twincode and we can proceed with other operations.
    [roomService onOperation];
}

- (void)onDeleteContactWithRequestId:(int64_t)requestId contactId:(NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContactWithRequestId: %lld groupId: %@", LOG_TAG, requestId, contactId);

    EditRoomService *roomService = (EditRoomService *)self.service;

    if (![contactId isEqual:roomService.room.uuid]) {

        return;
    }

    [roomService finishOperation:requestId];
    [roomService onDeleteRoom:contactId];
}

@end

//
// Interface: EditRoomServiceConversationServiceDelegate
//

@interface EditRoomServiceConversationServiceDelegate : NSObject <TLConversationServiceDelegate>

@property (weak) EditRoomService *service;

- (instancetype)initWithService:(EditRoomService *)service;

@end

//
// Implementation: EditRoomServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"EditRoomServiceConversationServiceDelegate"

@implementation EditRoomServiceConversationServiceDelegate

- (instancetype)initWithService:(EditRoomService *)service {
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

    [self.service onRoomCommandResult:result operationId:operationId];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
}

@end

//
// Implementation: EditRoomService
//

#undef LOG_TAG
#define LOG_TAG @"EditRoomService"

@implementation EditRoomService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<EditRoomServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _conversationServiceDelegate = [[EditRoomServiceConversationServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[EditRoomServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)getRoomConfig:(nonnull TLContact *)room {
    DDLogVerbose(@"%@ getRoomConfig room: %@", LOG_TAG, room);
    
    self.work |= ROOM_GET_CONFIG;
    self.state &= ~(ROOM_GET_CONFIG | ROOM_GET_CONFIG_DONE);
    self.room = room;
    
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateRoomWithName:(nonnull TLContact *)room name:(nonnull NSString *)name {
    DDLogVerbose(@"%@ updateRoomWithName room: %@ name: %@", LOG_TAG, room, name);
    
    self.work |= UPDATE_ROOM_NAME;
    self.state &= ~(UPDATE_ROOM_NAME | UPDATE_ROOM_NAME_DONE);
    self.room = room;
    self.name = name;
    self.avatar = nil;
    self.welcomeMessage = nil;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateRoomWithName:(nonnull TLContact *)room name:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar welcomeMessage:(nullable NSString *)welcomeMessage {
    DDLogVerbose(@"%@ updateRoomWithName room: %@ name: %@ avatar: %@ largeAvatar: %@ welcomeMessage: %@", LOG_TAG, room, name, avatar, largeAvatar, welcomeMessage);
    
    self.room = room;
    self.name = name;
    self.avatar = avatar;
    self.largeAvatar = largeAvatar;
    self.welcomeMessage = welcomeMessage;
    
    if (self.name && ![self.name isEqual:room.name]) {
        self.work |= UPDATE_ROOM_NAME;
        self.state &= ~(UPDATE_ROOM_NAME | UPDATE_ROOM_NAME_DONE);
    } else if (self.avatar && self.largeAvatar) {
        self.work |= UPDATE_ROOM_AVATAR;
        self.state &= ~(UPDATE_ROOM_AVATAR | UPDATE_ROOM_AVATAR_DONE);
    }  else if (self.welcomeMessage) {
        self.work |= UPDATE_ROOM_WELCOME_MESSAGE;
        self.state &= ~(UPDATE_ROOM_WELCOME_MESSAGE | UPDATE_ROOM_WELCOME_MESSAGE_DONE);
    }
    
    [self showProgressIndicator];
    [self startOperation];
}

- (void)deleteRoom:(nonnull TLContact *)room {
    DDLogVerbose(@"%@ deleteRoom room: %@", LOG_TAG, room);
    
    self.work |= DELETE_ROOM;
    self.state &= ~(DELETE_ROOM | DELETE_ROOM_DONE);
    self.room = room;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateRoomConfig:(nonnull TLContact *)room roomConfig:(TLRoomConfig *)roomConfig  {
    DDLogVerbose(@"%@ updateRoomConfig room: %@ roomConfig: %@", LOG_TAG, room, roomConfig);
    
    self.work |= ROOM_SET_CONFIG;
    self.state &= ~(ROOM_SET_CONFIG | ROOM_SET_CONFIG_DONE);
    self.room = room;
    self.roomConfig = roomConfig;
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
    // Work step: we must delete the room (it must be possible even if we don't have the private peer!).
    //
    if ((self.work & DELETE_ROOM) != 0) {
        if ((self.state & DELETE_ROOM) == 0) {
            self.state |= DELETE_ROOM;
            
            int64_t requestId = [self newOperation:DELETE_ROOM];
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

    if ((self.work & ROOM_GET_CONFIG) != 0) {
        if ((self.state & ROOM_GET_CONFIG) == 0) {
            self.state |= ROOM_GET_CONFIG;
            
            int64_t requestId = [self newOperation:ROOM_GET_CONFIG];
            DDLogVerbose(@"%@ roomGetConfigWithRequestId: %lld contact: %@", LOG_TAG, requestId, self.room);
            [self.twinmeContext roomGetConfigWithRequestId:requestId contact:self.room];
            return;
        }
        if ((self.state & ROOM_GET_CONFIG_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & UPDATE_ROOM_NAME) != 0) {
        if ((self.state & UPDATE_ROOM_NAME) == 0) {
            self.state |= UPDATE_ROOM_NAME;
            
            int64_t requestId = [self newOperation:UPDATE_ROOM_NAME];
            DDLogVerbose(@"%@ roomSetNameWithRequestId: %lld contact: %@ name: %@", LOG_TAG, requestId, self.room, self.name);
            [self.twinmeContext roomSetNameWithRequestId:requestId contact:self.room name:self.name];
            return;
        }
        if ((self.state & UPDATE_ROOM_NAME_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & UPDATE_ROOM_AVATAR) != 0) {
        if ((self.state & UPDATE_ROOM_AVATAR) == 0) {
            self.state |= UPDATE_ROOM_AVATAR;
            
            int64_t requestId = [self newOperation:UPDATE_ROOM_AVATAR];
            DDLogVerbose(@"%@ roomSetImageWithRequestId: %lld contact: %@ avatar: %@", LOG_TAG, requestId, self.room, self.avatar);
            [self.twinmeContext roomSetImageWithRequestId:requestId contact:self.room image:self.avatar];
            return;
        }
        if ((self.state & UPDATE_ROOM_AVATAR_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & UPDATE_ROOM_WELCOME_MESSAGE) != 0) {
        if ((self.state & UPDATE_ROOM_WELCOME_MESSAGE) == 0) {
            self.state |= UPDATE_ROOM_WELCOME_MESSAGE;
            
            int64_t requestId = [self newOperation:UPDATE_ROOM_WELCOME_MESSAGE];
            DDLogVerbose(@"%@ roomSetWelcomeWithRequestId: %lld contact: %@ welcomeMessage: %@", LOG_TAG, requestId, self.room, self.welcomeMessage);
            [self.twinmeContext roomSetWelcomeWithRequestId:requestId contact:self.room message:self.welcomeMessage];
            return;
        }
        if ((self.state & UPDATE_ROOM_WELCOME_MESSAGE_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & ROOM_SET_CONFIG) != 0) {
        if ((self.state & ROOM_SET_CONFIG) == 0) {
            self.state |= ROOM_SET_CONFIG;
            
            int64_t requestId = [self newOperation:ROOM_SET_CONFIG];
            DDLogVerbose(@"%@ roomSetConfigWithRequestId: %lld contact: %@ roomConfig: %@", LOG_TAG, requestId, self.room, self.roomConfig);
            [self.twinmeContext roomSetConfigWithRequestId:(int64_t)requestId contact:self.room config:self.roomConfig];
            return;
        }
        if ((self.state & ROOM_SET_CONFIG_DONE) == 0) {
            return;
        }
    }

    //
    // Last Step: everything done, we can hide the progress indicator.
    //
    
    [self hideProgressIndicator];
}

- (void)onDeleteRoom:(NSUUID *)roomId {
    DDLogVerbose(@"%@ onDeleteRoom: %@", LOG_TAG, roomId);
    
    if ([roomId isEqual:self.room.uuid]) {
        self.state |= DELETE_ROOM_DONE;
        
        if ([(id)self.delegate respondsToSelector:@selector(onDeleteRoom:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<EditRoomServiceDelegate>)self.delegate onDeleteRoom:roomId];
            });
        }
        
        [self onOperation];
    }
}

- (void)onRoomCommandResult:(TLRoomCommandResult *)roomCommandResult operationId:(int)operationId {
    DDLogVerbose(@"%@ onRoomCommandResult: %@", LOG_TAG, roomCommandResult);
    
    if (operationId == ROOM_GET_CONFIG) {
        self.state |= ROOM_GET_CONFIG_DONE;
        
        if ([roomCommandResult isKindOfClass:[TLRoomConfigResult class]]) {
            TLRoomConfigResult *roomConfigResult = (TLRoomConfigResult *)roomCommandResult;
            if (roomConfigResult.roomConfig && [(id)self.delegate respondsToSelector:@selector(onGetRoomConfig:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [(id<EditRoomServiceDelegate>)self.delegate onGetRoomConfig:roomConfigResult.roomConfig];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [(id<EditRoomServiceDelegate>)self.delegate onGetRoomConfigNotFound];
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<EditRoomServiceDelegate>)self.delegate onGetRoomConfigNotFound];
            });
        }
        
        [self onOperation];
        return;
    }
    
    BOOL isRoomUpdated = NO;
    
    if (operationId == UPDATE_ROOM_NAME) {
        self.state |= UPDATE_ROOM_NAME_DONE;
        
        if (self.avatar && self.largeAvatar) {
            self.work |= UPDATE_ROOM_AVATAR;
            self.state &= ~(UPDATE_ROOM_AVATAR | UPDATE_ROOM_AVATAR_DONE);
        } else if (self.welcomeMessage) {
            self.work |= UPDATE_ROOM_WELCOME_MESSAGE;
            self.state &= ~(UPDATE_ROOM_WELCOME_MESSAGE | UPDATE_ROOM_WELCOME_MESSAGE_DONE);
        } else {
            isRoomUpdated = YES;
        }
    } else if (operationId == UPDATE_ROOM_AVATAR) {
        self.state |= UPDATE_ROOM_AVATAR_DONE;
        
        if (self.welcomeMessage) {
            self.work |= UPDATE_ROOM_WELCOME_MESSAGE;
            self.state &= ~(UPDATE_ROOM_WELCOME_MESSAGE | UPDATE_ROOM_WELCOME_MESSAGE_DONE);
        } else {
            isRoomUpdated = YES;
        }
    } else if (operationId == UPDATE_ROOM_WELCOME_MESSAGE) {
        self.state |= UPDATE_ROOM_WELCOME_MESSAGE_DONE;
        isRoomUpdated = YES;
    } else if (operationId == ROOM_SET_CONFIG) {
        self.state |= ROOM_SET_CONFIG_DONE;
        isRoomUpdated = YES;
    }
    
    if (isRoomUpdated && [(id)self.delegate respondsToSelector:@selector(onUpdateRoom:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<EditRoomServiceDelegate>)self.delegate onUpdateRoom:self.room];
        });
    }
    [self onOperation];
}

@end
