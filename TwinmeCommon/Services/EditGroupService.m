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
#import <Twinlife/TLTwincodeOutboundService.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLCapabilities.h>
#import <Twinlife/TLImageService.h>

#import "EditGroupService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int UPDATE_GROUP = 1 << 0;
static const int UPDATE_GROUP_DONE = 1 << 1;
static const int MEMBER_LEAVE_GROUP = 1 << 2;
static const int DELETE_GROUP = 1 << 3;
static const int DELETE_GROUP_DONE = 1 << 4;
static const int GET_GROUP_AVATAR = 1 << 5;
static const int GET_GROUP_AVATAR_DONE = 1 << 6;

//
// Interface: EditGroupService ()
//

@class EditGroupServiceTwinmeContextDelegate;

@interface EditGroupService ()

@property (nonatomic, nullable) TLGroup *group;
@property (nonatomic, nullable) TLImageId *avatarId;
@property (nonatomic, nullable) NSString *name;
@property (nonatomic, nullable) NSString *groupDescription;
@property (nonatomic, nullable) UIImage *avatar;
@property (nonatomic, nullable) UIImage *largeAvatar;
@property (nonatomic, nullable) TLCapabilities *capabilities;
@property (nonatomic) int work;

- (void)onOperation;

- (void)onUpdateGroup:(nonnull TLGroup *)group;

- (void)onLeaveGroup:(id<TLGroupConversation>)group memberTwincodeId:(NSUUID *)memberTwincodeId;

- (void)onDeleteGroup:(NSUUID *)groupId;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Interface: EditGroupServiceTwinmeContextDelegate
//

@interface EditGroupServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull EditGroupService *)service;

@end

//
// Implementation: EditGroupServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"EditGroupServiceTwinmeContextDelegate"

@implementation EditGroupServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull EditGroupService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onUpdateGroupWithRequestId:(int64_t)requestId group:(TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, group);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(EditGroupService *)self.service onUpdateGroup:group];
}

- (void)onLeaveGroupWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onLeaveGroupWithRequestId: %lld group: %@ memberId: %@", LOG_TAG, requestId, group, memberId);
    
    [self.service finishOperation:requestId];
    
    [(EditGroupService *)self.service onLeaveGroup:group memberTwincodeId:memberId];
}

- (void)onDeleteGroupWithRequestId:(int64_t)requestId groupId:(NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroupWithRequestId: %lld groupId: %@", LOG_TAG, requestId, groupId);
    
    [self.service finishOperation:requestId];
    
    [(EditGroupService *)self.service onDeleteGroup:groupId];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorcode errorParameter:(nullable NSString *)errorParameter {
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(EditGroupService *)self.service onErrorWithOperationId:operationId errorCode:errorcode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Implementation: EditGroupService
//

#undef LOG_TAG
#define LOG_TAG @"EditGroupService"

@implementation EditGroupService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<EditGroupServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[EditGroupServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)refreshWithGroup:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ refreshWithGroup: %@", LOG_TAG, group);
    
    self.work = GET_GROUP_AVATAR;
    self.state &= ~(GET_GROUP_AVATAR | GET_GROUP_AVATAR_DONE);
    self.group = group;
    self.avatarId = group.avatarId;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateGroupWithName:(nonnull TLGroup *)group name:(nonnull NSString *)name description:(nullable NSString *)description {
    DDLogVerbose(@"%@ updateGroupWithName group: %@ name: %@", LOG_TAG, group, name);
    
    self.work |= UPDATE_GROUP;
    self.state &= ~(UPDATE_GROUP | UPDATE_GROUP_DONE);
    self.group = group;
    self.name = name;
    self.groupDescription = description;
    self.avatar = nil;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateGroupWithCapabilities:(nonnull TLGroup *)group capabilities:(nullable TLCapabilities *)capabilities {
    DDLogVerbose(@"%@ updateGroupWithCapabilities group: %@ capabilities: %@", LOG_TAG, group, capabilities);
    
    self.work |= UPDATE_GROUP;
    self.state &= ~(UPDATE_GROUP | UPDATE_GROUP_DONE);
    self.group = group;
    self.name = self.group.name;
    self.capabilities = capabilities;
    self.avatar = nil;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateGroupWithName:(nonnull TLGroup *)group name:(nonnull NSString *)name description:(nullable NSString *)description avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar permissions:(int64_t)permissions capabilities:(nullable TLCapabilities *)capabilities{
    DDLogVerbose(@"%@ updateGroupWithName group: %@ name: %@ avatar:%@ largeAvatar: %@ permissions: %lld", LOG_TAG, group, name, avatar, largeAvatar, permissions);
    
    self.work |= UPDATE_GROUP;
    self.state &= ~(UPDATE_GROUP | UPDATE_GROUP_DONE);
    self.group = group;
    self.name = name;
    self.groupDescription = description;
    self.avatar = avatar;
    self.largeAvatar = largeAvatar;
    self.capabilities = capabilities;
    [[self.twinmeContext getConversationService] setPermissionsWithSubject:self.group memberTwincodeId:nil permissions:permissions];
    [self showProgressIndicator];
    [self startOperation];
}

- (void)updateGroupWithName:(nonnull TLGroup *)group name:(nonnull NSString *)name description:(nullable NSString *)description avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar {
    DDLogVerbose(@"%@ updateGroupWithName group: %@ name: %@ avatar:%@ largeAvatar: %@", LOG_TAG, group, name, avatar, largeAvatar);
    
    self.work |= UPDATE_GROUP;
    self.state &= ~(UPDATE_GROUP | UPDATE_GROUP_DONE);
    self.group = group;
    self.name = name;
    self.groupDescription = description;
    self.avatar = avatar;
    self.largeAvatar = largeAvatar;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)leaveGroupWithMemberTwincodeId:(nonnull TLGroup *)group memberTwincodeId:(nonnull NSUUID *)memberTwincodeId {
    DDLogVerbose(@"%@ leaveGroupWithMemberTwincodeId: %@ memberTwincodeId: %@", LOG_TAG, group, memberTwincodeId);
    
    [self showProgressIndicator];
    
    self.group = group;
    
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
        [self.delegate hideProgressIndicator];
        
        if ([(id)self.delegate respondsToSelector:@selector(onLeaveGroup:memberTwincodeId:)]) {
            [(id<EditGroupServiceDelegate>)self.delegate onLeaveGroup:self.group memberTwincodeId:memberTwincodeId];
        }
    }
    [self startOperation];
}

- (void)deleteGroup:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ deleteGroup %@", LOG_TAG, group);
    
    self.work |= DELETE_GROUP;
    self.state &= ~(DELETE_GROUP | DELETE_GROUP_DONE);
    self.group = group;
    [self showProgressIndicator];
    [self startOperation];
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    //
    // Get the group large image if we can.
    //
    if (self.avatarId) {
        if ((self.work & GET_GROUP_AVATAR) != 0) {
            if ((self.state & GET_GROUP_AVATAR) == 0) {
                self.state |= GET_GROUP_AVATAR;
                
                TLImageService *imageService = [self.twinmeContext getImageService];
                [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindLarge withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                    self.state |= GET_GROUP_AVATAR_DONE;
                    if (status == TLBaseServiceErrorCodeSuccess && image) {
                        self.avatar = image;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (self.delegate) {
                                [(id<EditGroupServiceDelegate>)self.delegate onUpdateGroupAvatar:self.avatar];
                            }
                        });
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (self.delegate) {
                                [(id<EditGroupServiceDelegate>)self.delegate onUpdateGroupAvatarNotFound];
                            }
                        });
                    }
                    [self onOperation];
                }];
                return;
            }
        }
        if ((self.state & GET_GROUP_AVATAR_DONE) == 0) {
            return;
        }
    }
    
    // We must update the user's profile in the group.
    if ((self.work & UPDATE_GROUP) != 0) {
        if ((self.state & UPDATE_GROUP) == 0) {
            self.state |= UPDATE_GROUP;
            
            int64_t requestId = [self newOperation:UPDATE_GROUP];
            DDLogVerbose(@"%@ updateGroupProfileWithRequestId: %lld group: %@ name: %@ profileAvatar: %@", LOG_TAG, requestId, self.group, self.name, self.avatar);
            [self.twinmeContext updateGroupWithRequestId:requestId group:self.group name:self.name description:self.groupDescription groupAvatar:self.avatar groupLargeAvatar:self.largeAvatar capabilities:self.capabilities];
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
    
    //
    // Last Step: everything done, we can hide the progress indicator.
    //
    
    [self hideProgressIndicator];
}

- (void)onUpdateGroup:(TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroup: %@", LOG_TAG, group);
    
    self.state |= UPDATE_GROUP_DONE;
    
    [self runOnUpdateGroup:self.group avatar:self.avatar];
    [self onOperation];
}

- (void)onLeaveGroup:(id<TLGroupConversation>)group memberTwincodeId:(NSUUID *)memberTwincodeId {
    DDLogVerbose(@"%@ onLeaveGroup group: %@ memberTwincodeId: %@", LOG_TAG, group, memberTwincodeId);
    
    if (!self.group || ![self.group.uuid isEqual:group.contactId]) {
        return;
    }
    if ([(id)self.delegate respondsToSelector:@selector(onLeaveGroup:memberTwincodeId:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<EditGroupServiceDelegate>)self.delegate onLeaveGroup:self.group memberTwincodeId:memberTwincodeId];
        });
    }
    [self onOperation];
}

- (void)onDeleteGroup:(NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroup: %@", LOG_TAG, groupId);
    
    if ([groupId isEqual:self.group.uuid]) {
        self.state |= DELETE_GROUP_DONE;
        
        [self runOnDeleteGroup:groupId];
    }
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
            case UPDATE_GROUP:
                self.state |= UPDATE_GROUP_DONE;
                [self runOnDeleteGroup:self.group.uuid];
                return;
                
            case DELETE_GROUP:
                [self onDeleteGroup:self.group.uuid];
                return;
                
            default:
                break;
        }
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
