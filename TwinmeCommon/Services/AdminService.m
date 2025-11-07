/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLNotificationCenter.h>
#import <Twinlife/TLTwinlifeContext.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLJobService.h>

#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import "AdminService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define UPDATE_SCORES_PREFERENCES @"TwinmeScores"
#define LAST_USAGE_SCORE_DATE_PREFERENCE @"lastUsageScoreDate"
#define MIN_UPDATE_SCORE_DELAY 24 * 3600 // 24 h in s

static const int GET_JOINED_GROUP = 1 << 1;
static const int GROUP_CONVERSATION_DELETED = 1 << 2;
static const int DELETE_GROUP = 1 << 3;
static const int UPDATE_SCORES = 1 << 4;

@interface GroupMemberOperation : NSObject

@property (nonatomic) NSUUID *conversationId;
@property (nonatomic) NSUUID *groupTwincodeId;
@property (nonatomic) NSUUID *memberTwincodeId;
@property (nonatomic) NSUUID *groupId;
@property (nonatomic) int operation;
@property (nonatomic) int64_t requestId;
@property (nonatomic) TLInvitationDescriptor *invitationDescriptor;

- (nullable instancetype)initWithRequestId:(int64_t)requestId operation:(int)operation conversationId:(NSUUID *)conversationId invitation:(TLInvitationDescriptor *)invitation;

- (nullable instancetype)initWithRequestId:(int64_t)requestId operation:(int)operation conversationId:(NSUUID *)conversationId groupId:(NSUUID *)groupId;

@end

#undef LOG_TAG
#define LOG_TAG @"GroupMemberOperation"

@implementation GroupMemberOperation

- (nullable instancetype)initWithRequestId:(int64_t)requestId operation:(int)operation conversationId:(NSUUID *)conversationId invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ initWithRequestId: %lld operation: %d conversationId: %@ invitation: %@", LOG_TAG, requestId, operation, conversationId, invitation);
    
    self = [super init];
    
    if (self) {
        _requestId = requestId;
        _operation = operation;
        _conversationId = conversationId;
        _invitationDescriptor = invitation;
        _groupTwincodeId = invitation.groupTwincodeId;
        _memberTwincodeId = invitation.memberTwincodeId;
    }
    return self;
}

- (nullable instancetype)initWithRequestId:(int64_t)requestId operation:(int)operation conversationId:(NSUUID *)conversationId groupId:(NSUUID *)groupId {
    
    DDLogVerbose(@"%@ initWithRequestId: %lld operation: %d conversationId: %@ groupId: %@", LOG_TAG, requestId, operation, conversationId, groupId);
    
    self = [super init];
    
    if (self) {
        _requestId = requestId;
        _operation = operation;
        _conversationId = conversationId;
        _invitationDescriptor = nil;
        _groupId = groupId;
    }
    return self;
}

@end

//
// Interface: AdminService ()
//

@class AdminServiceTwinmeContextDelegate;
@class AdminServiceConversationServiceDelegate;

@interface AdminService ()<TLJob>

@property (nonatomic, readonly, nonnull) TLTwinmeContext *twinmeContext;

@property (nonatomic) BOOL connected;

@property (nonatomic) BOOL isTwinlifeReady;
@property (nonatomic) int state;
@property (nonatomic, readonly, nonnull) NSMutableDictionary *requestIds;
@property (nonatomic, readonly, nonnull) NSMutableDictionary *pendingOperations;
@property (nonatomic) BOOL restarted;
@property (nonatomic) AdminServiceTwinmeContextDelegate *twinmeContextDelegate;
@property (nonatomic) AdminServiceConversationServiceDelegate *conversationServiceDelegate;
@property (nonatomic) int64_t newUpdateDate;
@property (nonatomic) TLJobId *updateScoreJob;

- (void)onTwinlifeReady;

- (void)onTwinlifeOnline;

- (void)onSignOut;

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus;

- (void)onGetGroup:(int64_t)requestId group:(TLGroup *)group;

- (void)onDeleteGroup:(int64_t)requestId groupId:(NSUUID *)groupId;

- (void)onDeleteGroupConversation:(NSUUID *)conversationId groupId:(NSUUID *)groupId;

- (void)onJoinGroupResponse:(id<TLGroupConversation>)conversation invitation:(TLInvitationDescriptor *)invitation;

- (void)onUpdateStatsWithRequestId:(int64_t)requestId contacts:(NSArray<TLContact *> *)contacts groups:(NSArray<TLGroup *> *)groups;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

- (void)cleanupTemporaryDirectory;

@end

//
// Interface: AdminServiceTwinmeContextDelegate
//

@interface AdminServiceTwinmeContextDelegate:NSObject <TLTwinmeContextDelegate>

@property (weak) AdminService *service;

- (instancetype)initWithService:(AdminService *)service;

@end

//
// Implementation: AdminServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"AdminServiceTwinmeContextDelegate"

@implementation AdminServiceTwinmeContextDelegate

- (instancetype)initWithService:(AdminService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [self.service onTwinlifeReady];
    
    // Remove possibly old temporary files that should have been removed.
    [self.service cleanupTemporaryDirectory];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    [self.service onTwinlifeOnline];
}

- (void)onSignOut {
    DDLogVerbose(@"%@ onSignOut", LOG_TAG);
    
    [self.service onSignOut];
}

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus {
    DDLogVerbose(@"%@ onConnectionStatusChange: %d", LOG_TAG, connectionStatus);
    
    [self.service onConnectionStatusChange:connectionStatus];
}

- (void)onDeleteGroupWithRequestId:(int64_t)requestId groupId:(NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, groupId);
    
    [self.service onDeleteGroup:requestId groupId:groupId];
}

- (void)onUpdateStatsWithRequestId:(int64_t)requestId contacts:(NSArray<TLContact *> *)contacts groups:(NSArray<TLGroup *> *)groups {
    DDLogVerbose(@"%@ onUpdateStatsWithRequestId: %lld contacts: %@ groups: %@", LOG_TAG, requestId, contacts, groups);
    
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    NSNumber *operationId;
    @synchronized(self.service.requestIds) {
        operationId = self.service.requestIds[lRequestId];
        if (operationId == nil) {
            return;
        }
        [self.service.requestIds removeObjectForKey:lRequestId];
    }
    [self.service onUpdateStatsWithRequestId:requestId contacts:contacts groups:groups];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    NSNumber *operationId;
    @synchronized(self.service.requestIds) {
        operationId = self.service.requestIds[lRequestId];
        if (operationId == nil) {
            return;
        }
        [self.service.requestIds removeObjectForKey:lRequestId];
    }
    [self.service onErrorWithOperationId:operationId.intValue errorCode:errorCode errorParameter:errorParameter];
}

@end

//
// Interface: AdminServiceConversationServiceDelegate
//

@interface AdminServiceConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) AdminService *service;

- (instancetype)initWithService:(AdminService *)service;

@end

//
// Implementation: AdminServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"AdminServiceConversationServiceDelegate"

@implementation AdminServiceConversationServiceDelegate

- (instancetype)initWithService:(AdminService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onJoinGroupResponseWithRequestId:(int64_t)requestId group:(id<TLGroupConversation>)group invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onJoinGroupResponseWithRequestId: %lld group: %@ invitation: %@", LOG_TAG, requestId, group, invitation);
    
    [self.service onJoinGroupResponse:group invitation:invitation];
}

- (void)onDeleteGroupConversationWithRequestId:(int64_t)requestId conversationId:(NSUUID *)conversationId groupId:(NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroupConversationWithRequestId: %lld conversationId: %@ groupId: %@", LOG_TAG, requestId, conversationId, groupId);
    
    [self.service onDeleteGroupConversation:conversationId groupId:groupId];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    if (requestId == [TLBaseService DEFAULT_REQUEST_ID]) {
        
    } else {
        NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
        NSNumber *operationId;
        @synchronized (self.service.requestIds) {
            operationId = self.service.requestIds[lRequestId];
            if (operationId == nil) {
                return;
            }
            [self.service.requestIds removeObjectForKey:lRequestId];
        }
        [self.service onErrorWithOperationId:operationId.intValue errorCode:errorCode errorParameter:errorParameter];
    }
}

@end

//
// Implementation: AdminService
//

#undef LOG_TAG
#define LOG_TAG @"AdminService"

@implementation AdminService

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@", LOG_TAG, twinmeContext);
    
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;
        
        _connected = [_twinmeContext isConnected];
        
        _isTwinlifeReady = NO;
        _state = 0;
        _requestIds = [[NSMutableDictionary alloc] init];
        _pendingOperations = [[NSMutableDictionary alloc] init];
        _restarted = NO;
        _conversationServiceDelegate = [[AdminServiceConversationServiceDelegate alloc] initWithService:self];
        _twinmeContextDelegate = [[AdminServiceTwinmeContextDelegate alloc] initWithService:self];
        [_twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [self.twinmeContext removeDelegate:self.twinmeContextDelegate];
}

#pragma mark - Private methods

- (int64_t)newOperation:(int)operationId {
    DDLogVerbose(@"%@ newOperation: %d", LOG_TAG, operationId);
    
    int64_t requestId = [self.twinmeContext newRequestId];
    @synchronized (self.requestIds) {
        self.requestIds[[NSNumber numberWithLongLong:requestId]] = [NSNumber numberWithInt:operationId];
    }
    return requestId;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getConversationService] addDelegate:self.conversationServiceDelegate];
    self.isTwinlifeReady = YES;
    
    // Build and setup the group weight table to update the group usage score.
    //  - points are added when a contact/group is used,
    //  - scale factor is applied on other contact/groups to reduce their points.
    // We should have:
    //    1.0 >= scale  > 0.0
    //           points > 0.0
    TLRepositoryService *repositoryService = [self.twinmeContext getRepositoryService];
    NSMutableArray<TLObjectWeight *> *groupWeight = [[NSMutableArray alloc] init];
    for (TLRepositoryServiceStatType statType = TLRepositoryServiceStatTypeNbMessageSent; statType < TLRepositoryServiceStatTypeLast; statType++) {
        [groupWeight addObject:[[TLObjectWeight alloc] initWithScale:0.97 points:0.5]];
    }
    [repositoryService setWeightTableWithSchemaId:[TLGroup SCHEMA_ID] weights:groupWeight];
    
    // Build and setup the contact weight table to update the group usage score.
    NSMutableArray<TLObjectWeight *> *contactWeight = [[NSMutableArray alloc] init];
    for (TLRepositoryServiceStatType statType = TLRepositoryServiceStatTypeNbMessageSent; statType < TLRepositoryServiceStatTypeLast; statType++) {
        [contactWeight addObject:[[TLObjectWeight alloc] initWithScale:0.98 points:1.0]];
    }
    
    [repositoryService setWeightTableWithSchemaId:[TLContact SCHEMA_ID] weights:contactWeight];
    
    // Schedule the update score once per day.
    id object = [[NSUserDefaults standardUserDefaults] objectForKey:LAST_USAGE_SCORE_DATE_PREFERENCE];
    NSTimeInterval delay;
    if (object) {
        int64_t nextReportDate = [object longLongValue] + MIN_UPDATE_SCORE_DELAY * 1000;
        delay = (nextReportDate - [[NSDate date] timeIntervalSince1970] * 1000) / 1000.0;
    } else {
        delay = MIN_UPDATE_SCORE_DELAY;
    }
    
    self.updateScoreJob = [[self.twinmeContext getJobService] scheduleWithJob:self delay:delay priority:TLJobPriorityReport];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        self.restarted = NO;
    }
}

- (void)onSignOut {
    DDLogVerbose(@"%@ onSignOut", LOG_TAG);

    if (self.updateScoreJob) {
        [self.updateScoreJob cancel];
        self.updateScoreJob = nil;
    }
}

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus {
    DDLogVerbose(@"%@ onConnectionStatusChange: %d", LOG_TAG, connectionStatus);
    
    self.connected = connectionStatus == TLConnectionStatusConnected;
}

- (void)onJoinGroupResponse:(id<TLGroupConversation>)conversation invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ onJoinGroupResponse: %@ invitation: %@", LOG_TAG, conversation, invitation);
    
    NSNumber *requestId = [NSNumber numberWithLongLong:[self newOperation:GET_JOINED_GROUP]];
    GroupMemberOperation *operation = [[GroupMemberOperation alloc] initWithRequestId:requestId.intValue operation:GET_JOINED_GROUP conversationId:conversation.uuid invitation:invitation];
    
    @synchronized (self) {
        self.pendingOperations[requestId] = operation;
    }
    [self.twinmeContext getGroupWithGroupId:conversation.contactId withBlock:^(TLBaseServiceErrorCode errorCode, TLGroup *group) {
        [self onGetGroup:requestId.intValue group:group];
    }];
}

- (void)onDeleteGroupConversation:(NSUUID*)conversationId groupId:(NSUUID*)groupId {
    DDLogVerbose(@"%@ onDeleteGroupConversation: %@ groupId: %@", LOG_TAG, conversationId, groupId);
    
    // Get the group to proceed to the final group cleanup.
    NSNumber *requestId = [NSNumber numberWithLongLong:[self newOperation:GROUP_CONVERSATION_DELETED]];
    GroupMemberOperation *operation = [[GroupMemberOperation alloc] initWithRequestId:requestId.intValue operation:GROUP_CONVERSATION_DELETED conversationId:conversationId groupId:groupId];

    @synchronized (self) {
        self.pendingOperations[requestId] = operation;
    }
    [self.twinmeContext getGroupWithGroupId:groupId withBlock:^(TLBaseServiceErrorCode errorCode, TLGroup *group) {
        [self onGetGroup:requestId.intValue group:group];
    }];
}

- (void)onGetGroup:(int64_t)requestId group:(TLGroup*)group {

    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    GroupMemberOperation *operation;
    @synchronized (self) {
        operation = self.pendingOperations[lRequestId];
        if (!operation) {
            return;
        }
        [self.pendingOperations removeObjectForKey:lRequestId];
    }
    switch (operation.operation) {
        case GET_JOINED_GROUP:
            if ([group.twincodeOutboundId isEqual:operation.memberTwincodeId]) {
                [[self.twinmeContext notificationCenter] onJoinGroupWithGroup:group conversationId:operation.conversationId];
            }
            break;
            
        case GROUP_CONVERSATION_DELETED:
            // The group conversation was deleted, delete the group object and group member twincode.
            if ([group.uuid isEqual:operation.groupId] && !group.isDeleted) {
                lRequestId = [NSNumber numberWithLongLong:[self newOperation:DELETE_GROUP]];
                
                operation.operation = DELETE_GROUP;
                @synchronized (self) {
                    self.pendingOperations[lRequestId] = operation;
                }
                [self.twinmeContext deleteGroupWithRequestId:lRequestId.intValue group:group];
            }
            break;
            
        default:
            break;
    }
}

- (void)onDeleteGroup:(int64_t)requestId groupId:(NSUUID*)groupId {
    DDLogVerbose(@"%@ onDeleteGroup: %lld groupId: %@", LOG_TAG, requestId, groupId);
    
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self) {
        [self.pendingOperations removeObjectForKey:lRequestId];
    }
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);
    
    self.updateScoreJob = nil;
    self.newUpdateDate = [[NSDate date] timeIntervalSince1970] * 1000;
    int64_t requestId = [self newOperation:UPDATE_SCORES];
    [self.twinmeContext updateStatsWithRequestId:requestId updateScore:YES];
}

- (void)onUpdateStatsWithRequestId:(int64_t)requestId contacts:(NSArray<TLContact *>*)contacts groups:(NSArray<TLGroup *> *)groups {
    DDLogVerbose(@"%@ onUpdateStatsWithRequestId: %lld contacts: %@ groups: %@", LOG_TAG, requestId, contacts, groups);
    
    [[NSUserDefaults standardUserDefaults] setObject:[[NSNumber alloc] initWithLongLong:self.newUpdateDate] forKey:LAST_USAGE_SCORE_DATE_PREFERENCE];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSTimeInterval delay = MIN_UPDATE_SCORE_DELAY;
    TLJobService *jobService = [self.twinmeContext getJobService];
    self.updateScoreJob = [jobService scheduleWithJob:self delay:delay priority:TLJobPriorityReport];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    //    [self.twinmeContext sendProblemReportWithTag:LOG_TAG operationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

- (void)cleanupTemporaryDirectory {
    DDLogVerbose(@"%@ cleanupTemporaryDirectory", LOG_TAG);
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSString *directory = NSTemporaryDirectory();
    NSArray<NSString *> *fileArray = [fileMgr contentsOfDirectoryAtPath:directory error:nil];
    for (NSString *filename in fileArray)  {
        
        if ([filename hasSuffix:@".mp4"] || [filename hasSuffix:@".jpg"] || [filename hasSuffix:@".m4a"] || [filename hasSuffix:@".mov"]) {
            [fileMgr removeItemAtPath:[directory stringByAppendingPathComponent:filename] error:nil];
        }
    }
}

@end
