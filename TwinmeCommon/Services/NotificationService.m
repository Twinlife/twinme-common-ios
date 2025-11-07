/*
 *  Copyright (c) 2017-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLSpace.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLTwinmeContext.h>
#import <Twinlife/TLFilter.h>

#import "NotificationService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_NOTIFICATIONS = 1 << 0;
static const int GET_NOTIFICATIONS_DONE = 1 << 1;
static const int GET_PENDING_NOTIFICATIONS = 1 << 2;
static const int GET_PENDING_NOTIFICATIONS_DONE = 1 << 3;
static const int ACKNOWLEDGE_NOTIFICATION = 1 << 4;

static const int MAX_NOTIFICATIONS = 64000;

//
// Interface: NotificationService ()
//

@class NotificationServiceTwinmeContextDelegate;

@interface NotificationService ()

@property int64_t beforeTimestamp;

- (void)onOperation;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

- (void)onUpdateSpace:(nonnull TLSpace *)space;

- (void)onAddNotification:(TLNotification *)notification;

- (void)onAcknowledgeNotification:(TLNotification *)notification;

- (void)onDeleteNotificationsWithList:(nonnull NSArray<NSUUID *> *)list;

- (void)onUpdatePendingNotifications:(BOOL)hasPendingNotifications;

@end

//
// Interface: NotificationServiceTwinmeContextDelegate
//

@interface NotificationServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull NotificationService *)service;

@end

//
// Implementation: NotificationServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"NotificationServiceTwinmeContextDelegate"

@implementation NotificationServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull NotificationService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onSetCurrentSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(NotificationService *)self.service onSetCurrentSpace:space];
}

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(NotificationService *)self.service onUpdateSpace:space];
}

- (void)onAddNotificationWithNotification:(nonnull TLNotification *)notification {
    DDLogVerbose(@"%@ onAddNotificationWithNotification: %@", LOG_TAG, notification);
    
    [(NotificationService *)self.service onAddNotification:notification];
}

- (void)onAcknowledgeNotificationWithRequestId:(int64_t)requestId notification:(TLNotification *)notification {
    DDLogVerbose(@"%@ onAcknowledgeNotificationWithRequestId: %lld notification: %@", LOG_TAG, requestId, notification);
    
    [(NotificationService *)self.service onAcknowledgeNotification:notification];
}

- (void)onDeleteNotificationsWithList:(nonnull NSArray<NSUUID *> *)list {
    DDLogVerbose(@"%@ onDeleteNotificationsWithList: %@", LOG_TAG, list);

    [(NotificationService *)self.service onDeleteNotificationsWithList:list];
}

- (void)onUpdatePendingNotificationsWithRequestId:(int64_t)requestId hasPendingNotifications:(BOOL)hasPendingNotifications {
    DDLogVerbose(@"%@ onUpdatePendingNotificationsWithRequestId: %lld hasPendingNotifications: %@", LOG_TAG, requestId, hasPendingNotifications ? @"YES" : @"NO");
    
    [(NotificationService *)self.service onUpdatePendingNotifications:hasPendingNotifications];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(NotificationService *)self.service onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Implementation: NotificationService
//

#undef LOG_TAG
#define LOG_TAG @"NotificationService"

@implementation NotificationService

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext delegate:(id<NotificationServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _beforeTimestamp = INT64_MAX;
        self.twinmeContextDelegate = [[NotificationServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)acknowledgeNotification:(TLNotification *)notification {
    DDLogVerbose(@"%@ acknowledgeNotification: %@", LOG_TAG, notification);
    
    int64_t requestId = [self newOperation:ACKNOWLEDGE_NOTIFICATION];
    DDLogVerbose(@"%@ acknowledgeNotificationWithRequestId: %lld notification: %@", LOG_TAG, requestId, notification);
    [self.twinmeContext acknowledgeNotificationWithRequestId:requestId notification:notification];
}

- (void)getNotifications {
    DDLogVerbose(@"%@ getNotifications", LOG_TAG);
    
    self.state &= ~(GET_NOTIFICATIONS | GET_NOTIFICATIONS_DONE);
    
    [self showProgressIndicator];
    [self startOperation];
}

- (void)deleteNotification:(TLNotification *)notification {
    DDLogVerbose(@"%@ deleteNotification: %@", LOG_TAG, notification);
    
    [self showProgressIndicator];
    [self.twinmeContext deleteWithNotification:notification];
}

- (void)getGroupMemberWithNotification:(nonnull TLNotification *)notification withBlock:(nullable void (^)(TLGroupMember *_Nonnull member, UIImage *_Nullable image))block {
    DDLogVerbose(@"%@ getGroupMemberWithNotification: %@", LOG_TAG, notification);

    TL_ASSERT_IS_A(self.twinmeContext, notification.subject, TLGroup, TLAssertionParameterSubject, nil);
    TL_ASSERT_NOT_NULL(self.twinmeContext, notification.descriptorId, [ServicesAssertPoint PARAMETER], nil);

    [self.twinmeContext getGroupMemberWithOwner:(TLGroup *)notification.subject memberTwincodeId:notification.descriptorId.twincodeOutboundId withBlock:^(TLBaseServiceErrorCode errorCode, TLGroupMember *groupMember) {
        if (groupMember) {
            if (NSThread.isMainThread) {
                [self getImageWithGroupMember:groupMember withBlock:^(UIImage *image) {
                    // Execute the code block immediately if we can.
                    if (NSThread.isMainThread) {
                        block(groupMember, image);
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            block(groupMember, image);
                        });
                    }
                }];
            } else {
                UIImage *image = [self getImageWithGroupMember:groupMember];
                dispatch_async(dispatch_get_main_queue(), ^{
                    block(groupMember, image);
                });
            }
        }
    }];
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

    if ((self.state & GET_NOTIFICATIONS) == 0) {
        self.state |= GET_NOTIFICATIONS;

        TLTwinmeContext *twinmeContext = self.twinmeContext;
        TLFilter *filter = [twinmeContext createSpaceFilter];
        filter.before = self.beforeTimestamp;
        [twinmeContext findNotificationsWithFilter:filter maxDescriptors:MAX_NOTIFICATIONS withBlock:^(NSMutableArray<TLNotification *> *list) {
            self.state |= GET_NOTIFICATIONS_DONE;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate) {
                    [(id<NotificationServiceDelegate>)self.delegate onGetNotifications:list];
                }
            });
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_NOTIFICATIONS_DONE) == 0) {
        return;
    }

    //
    // Step 2
    //

    if ((self.state & GET_PENDING_NOTIFICATIONS) == 0) {
        self.state |= GET_PENDING_NOTIFICATIONS;

        [self.twinmeContext getSpaceNotificationStatsWithBlock:^(TLBaseServiceErrorCode errorCode, TLNotificationServiceNotificationStat * _Nonnull stats) {
            self.state |= GET_PENDING_NOTIFICATIONS_DONE;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate) {
                    [(id<NotificationServiceDelegate>)self.delegate onUpdatePendingNotifications:stats.pendingCount > 0];
                }
            });
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_PENDING_NOTIFICATIONS_DONE) == 0) {
        return;
    }

    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

- (void)onSetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);

    [self runOnSetCurrentSpace:space];
}

- (void)onUpdateSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpace: %@", LOG_TAG, space);

    [self runOnUpdateSpace:space];
}

- (void)onAddNotification:(TLNotification *)notification {
    DDLogVerbose(@"%@ onAddNotification: %@", LOG_TAG, notification);

    if ([self.twinmeContext isCurrentSpace:(id<TLOriginator>)notification.subject]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate) {
                [(id<NotificationServiceDelegate>)self.delegate onAddNotification:notification];
            }
        });
    }
}

- (void)onAcknowledgeNotification:(TLNotification *)notification {
    DDLogVerbose(@"%@ onAcknowledgeNotification: %@", LOG_TAG, notification);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate) {
            [(id<NotificationServiceDelegate>)self.delegate onAcknowledgeNotification:notification];
        }
    });
}

- (void)onDeleteNotificationsWithList:(nonnull NSArray<NSUUID *> *)list {
    DDLogVerbose(@"%@ onDeleteNotificationsWithList: %@", LOG_TAG, list);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate) {
            [(id<NotificationServiceDelegate>)self.delegate onDeleteNotificationsWithList:list];
        }
    });
    [self onOperation];
}

- (void)onUpdatePendingNotifications:(BOOL)hasPendingNotifications {
    DDLogVerbose(@"%@ onUpdatePendingNotifications: %@", LOG_TAG, hasPendingNotifications ? @"YES" : @"NO");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate) {
            [(id<NotificationServiceDelegate>)self.delegate onUpdatePendingNotifications:hasPendingNotifications];
        }
    });
}

@end
