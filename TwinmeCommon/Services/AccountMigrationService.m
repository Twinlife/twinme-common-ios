/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <CocoaLumberjack.h>
#import <limits.h>

#import "AccountMigrationService.h"
#import <Twinlife/TLAccountMigrationService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLJobService.h>
#import <Twinme/TLAccountMigration.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLCallReceiver.h>
#import <Twinme/TLTwinmeAttributes.h>
#import <Twinme/TLTwinmeContext.h>
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_ACCOUNT_MIGRATION = 1;
static const int GET_ACCOUNT_MIGRATION_DONE = 1 << 1;
static const int QUERY_STAT = 1 << 4;
static const int QUERY_STAT_DONE = 1 << 5;
static const int OUTGOING_MIGRATION = 1 << 6;
static const int OUTGOING_MIGRATION_DONE = 1 << 7;
static const int ACCEPT_MIGRATION = 1 << 8;
static const int ACCEPT_MIGRATION_DONE = 1 << 9;
static const int START_MIGRATION = 1 << 10;
static const int TERMINATE_PHASE1 = 1 << 11;
static const int TERMINATE_PHASE1_DONE = 1 << 12;
static const int CANCEL_MIGRATION = 1 << 13;
static const int DELETE_MIGRATION = 1 << 14;
static const int DELETE_MIGRATION_DONE = 1 << 15;
static const int TERMINATE_PHASE2 = 1 << 16;
static const int TERMINATE_PHASE2_DONE = 1 << 17;
static const int FINAL_SHUTDOWN = 1 << 18;
static const int FINAL_SHUTDOWN_DONE = 1 << 19;
static const int STOP_SERVICE = 1 << 20;


//
// Interface: AccountMigrationService ()
//

@class AccountMigrationServiceTwinmeContextDelegate;
@class AccountMigrationServiceDelegate;

@interface AccountMigrationService ()

@property (nonatomic, readonly, nonnull) AccountMigrationServiceDelegate *accountMigrationServiceDelegate;

@property (nonatomic) int work;
@property (nonatomic, nullable) TLAccountMigrationVersion *peerVersion;
@property (nonatomic, nullable) TLAccountMigrationService *accountMigrationService;
@property (nonatomic, nullable) TLAccountMigration *accountMigration;
@property (nonatomic, nullable) TLAccountMigration *incomingAccountMigration;
@property (nonatomic, nullable) TLQueryInfo *peerQueryInfo;
@property (nonatomic, nullable) TLQueryInfo *localQueryInfo;
@property (nonatomic, nullable) NSUUID *accountMigrationId;
@property (nonatomic, nullable) NSUUID *incomingAccountMigrationId;
@property (nonatomic, nullable) NSUUID *incomingPeerConnectionId;
@property (nonatomic) TLAccountMigrationState migrationState;
@property (nonatomic, nullable) TLAccountMigrationStatus *status;
@property (nonatomic) int64_t terminateRequestId;
@property (nonatomic) BOOL commit;
@property (nonatomic) BOOL initiator;
@property (nonatomic) BOOL acceptAny;
@property (nonatomic) int64_t startTime;
@property (nullable) TLNetworkLock *networkLock;

- (void)onOperation;

- (void)onUpdateAccountMigrationWithAccountMigration:(nonnull TLAccountMigration *)accountMigration;
- (void)onDeleteAccountMigrationWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId;
- (void)onQueryStatsWithPeerInfo:(nonnull TLQueryInfo *)peerInfo localInfo:(nonnull TLQueryInfo *)localInfo;
- (BOOL)onStatusChangeWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId status:(TLAccountMigrationStatus *)status;
- (void)onTerminateMigrationWithRequestId:(int64_t)requestId operation:(nullable NSNumber *)operation commit:(BOOL)commit done:(BOOL)done;
@end

//
// Interface: AccountMigrationServiceTwinmeContextDelegate
//

@interface AccountMigrationServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull AccountMigrationService *)service;

@end

//
// Implementation: AccountMigrationServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"AccountMigrationServiceTwinmeContextDelegate"

@implementation AccountMigrationServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull AccountMigrationService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [self.service onTwinlifeReady];
}

- (void)onConnect {
    DDLogVerbose(@"%@ onNetworkConnect", LOG_TAG);
    
    [self.service onConnectionStatusChange:TLConnectionStatusConnected];
}

- (void)onDisconnect {
    DDLogVerbose(@"%@ onNetworkDisconnect", LOG_TAG);
    
    [self.service onConnectionStatusChange:TLConnectionStatusNoService];
}

- (void)onNetworkConnect {
    DDLogVerbose(@"%@ onNetworkConnect", LOG_TAG);
    
    [self.service onConnectionStatusChange:TLConnectionStatusConnecting];
}

- (void)onNetworkDisconnect {
    DDLogVerbose(@"%@ onNetworkDisconnect", LOG_TAG);
    
    [self.service onConnectionStatusChange:TLConnectionStatusNoInternet];
}

- (void)onUpdateAccountMigrationWithRequestId:(int64_t)requestId accountMigration:(TLAccountMigration *)accountMigration {
    DDLogVerbose(@"%@ onUpdateAccountMigrationWithRequestId: %lld accountMigration:%@", LOG_TAG, requestId, accountMigration);
    
    NSUUID *accountMigrationId = accountMigration.uuid;
    AccountMigrationService *service = (AccountMigrationService *)self.service;
    if (![accountMigrationId isEqual:service.accountMigrationId] && ![accountMigrationId isEqual:service.incomingAccountMigrationId]) {
        return;
    }
    
    [service onUpdateAccountMigrationWithAccountMigration:accountMigration];
    [service onOperation];
}

- (void)onDeleteAccountMigrationWithRequestId:(int64_t)requestId accountMigrationId:(NSUUID *)accountMigrationId {
    DDLogVerbose(@"%@ onDeleteAccountMigrationWithRequestId: %lld accountMigration:%@", LOG_TAG, requestId, accountMigrationId.UUIDString);
    
    AccountMigrationService *service = (AccountMigrationService *)self.service;

    if (![accountMigrationId isEqual:service.accountMigrationId] && ![accountMigrationId isEqual:service.incomingAccountMigrationId]) {
        return;
    }
    
    [service onDeleteAccountMigrationWithAccountMigrationId:accountMigrationId];
    [service onOperation];
}

@end

@interface AccountMigrationServiceDelegate : NSObject<TLAccountMigrationServiceDelegate>

@property (nonatomic, readonly, nonnull) AccountMigrationService *service;

- (nonnull instancetype)initWithService:(nonnull AccountMigrationService *)service;

@end

@implementation AccountMigrationServiceDelegate

- (nonnull instancetype)initWithService:(nonnull AccountMigrationService *)service {
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}



- (void)onQueryStatsWithRequestId:(int64_t)requestId peerInfo:(nonnull TLQueryInfo *)peerInfo localInfo:(nonnull TLQueryInfo *)localInfo {
    DDLogVerbose(@"%@ onQueryStatsWithRequestId: %lld peerInfo:%@ localInfo:%@", LOG_TAG, requestId, peerInfo, localInfo);
    
    // onQueryStats can be called two times: once with our requestId and another time with DEFAULT_REQUEST_ID.
    if (requestId != TLBaseService.DEFAULT_REQUEST_ID) {
        @synchronized (self.service.requestIds) {
            NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
            NSNumber *operationId = self.service.requestIds[lRequestId];
            if (operationId == nil) {
                return;
            }
            
            [self.service.requestIds removeObjectForKey:lRequestId];
        }
        
    }

    [self.service onQueryStatsWithPeerInfo:peerInfo localInfo:localInfo];
    [self.service onOperation];
}

- (void)onStatusChangeWithDeviceMigrationId:(nonnull NSUUID *)deviceMigrationId status:( nonnull TLAccountMigrationStatus *)status {
    DDLogVerbose(@"%@ onStatusChangeWithDeviceMigrationId: %@ status:%@", LOG_TAG, deviceMigrationId, status);

    if (![deviceMigrationId isEqual:self.service.accountMigrationId] && ![deviceMigrationId isEqual:self.service.incomingAccountMigrationId]) {
        return;
    }
    
    if ([self.service onStatusChangeWithAccountMigrationId:deviceMigrationId status:status]) {
        [self.service onOperation];
    }
}

- (void)onTerminateMigrationWithRequestId:(int64_t)requestId deviceMigrationId:(nonnull NSUUID *)deviceMigrationId commit:(BOOL)commit done:(BOOL)done {
    DDLogVerbose(@"%@ onTerminateMigrationWithRequestId:%lld deviceMigrationId:%@ commit:%@ done:%@", LOG_TAG, requestId, deviceMigrationId.UUIDString, commit ? @"YES":@"NO", done ? @"YES":@"NO");
    
    if (![deviceMigrationId isEqual:self.service.accountMigrationId] && ![deviceMigrationId isEqual:self.service.incomingAccountMigrationId]) {
        return;
    }

    NSNumber *operationId;
    
    @synchronized (self.service.requestIds) {
        NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
        operationId = self.service.requestIds[lRequestId];
        [self.service.requestIds removeObjectForKey:lRequestId];
    }
    
    [self.service onTerminateMigrationWithRequestId:requestId operation:operationId commit:commit done:done];
    [self.service onOperation];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorcode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId:%lld errorCode:%d errorParameter:%@", LOG_TAG, requestId, errorcode, errorParameter);
    
    NSNumber *operationId;
    
    @synchronized (self.service.requestIds) {
        NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
        operationId = self.service.requestIds[lRequestId];
        if (operationId == nil) {
            return;
        }
        [self.service.requestIds removeObjectForKey:lRequestId];
    }

    [self.service onErrorWithOperationId:operationId.intValue errorCode:errorcode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Implementation: AccountMigrationService
//

#undef LOG_TAG
#define LOG_TAG @"AccountMigrationService"

@implementation AccountMigrationService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@", LOG_TAG, twinmeContext);
    
    //TODOAM refactor because we shouldn't extend AbstractTwinmeService?
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:nil];
    
    if (self) {
        _work = 0;
        _acceptAny = NO;
        _migrationState = TLAccountMigrationStateStarting;
        _commit = NO;
        _initiator = NO;
        _startTime = 0;
        
        _accountMigrationServiceDelegate = [[AccountMigrationServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[AccountMigrationServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    
    return self;
}

- (void)incomingMigrationWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId accountMigration:(nonnull TLAccountMigration *)accountMigration {
    DDLogVerbose(@"%@ incomingMigrationWithPeerConnectionId: %@ accountMigration: %@", LOG_TAG, peerConnectionId, accountMigration);

    self.work |= ACCEPT_MIGRATION;
    if (!self.twinmeContextDelegate) {
        self.twinmeContextDelegate = [[AccountMigrationServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    
    self.state &= ~ACCEPT_MIGRATION;
    self.incomingPeerConnectionId = peerConnectionId;
    self.incomingAccountMigration = accountMigration;
    self.incomingAccountMigrationId = accountMigration.uuid;
    
    [self onOperation];
}

- (void)acceptMigration {
    DDLogVerbose(@"%@ acceptMigration", LOG_TAG);

    self.acceptAny = YES;
}

- (void)outgoingMigrationWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId {
    DDLogVerbose(@"%@ outgoingMigrationWithAccountMigrationId: %@", LOG_TAG, accountMigrationId);

    self.work |= OUTGOING_MIGRATION;
    if (!self.twinmeContextDelegate) {
        self.twinmeContextDelegate = [[AccountMigrationServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    
    self.accountMigrationId = accountMigrationId;
    
    [self startOperation];
}

- (void)startMigration {
    DDLogVerbose(@"%@ startMigration", LOG_TAG);

    if (!self.accountMigration) {
        return;
    }
    
    self.work |= START_MIGRATION;
    self.initiator = YES;
    
    [self startOperation];
}

- (void)cancelMigration {
    DDLogVerbose(@"%@ cancelMigration", LOG_TAG);
    
    self.work |= CANCEL_MIGRATION | DELETE_MIGRATION | STOP_SERVICE;
    self.work &= ~(OUTGOING_MIGRATION | ACCEPT_MIGRATION);
    self.state &= ~(CANCEL_MIGRATION);
    self.migrationState = TLAccountMigrationStateCanceled;
    [self dispatchUpdateMigrationState];
    [self startOperation];
}

- (void)getMigrationState {
    
    [self dispatchUpdateMigrationState];
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);

    self.isTwinlifeReady = YES;
    self.accountMigrationService = self.twinmeContext.getAccountMigrationService;
    [self.accountMigrationService addDelegate:self.accountMigrationServiceDelegate];
    self.accountMigrationId = [self.accountMigrationService getActiveDeviceMigrationId];

    // If a migration was active, proceed with it.
    if (self.accountMigrationId) {
        [self onOperation];
    } else if (self.work == 0) {
        [self.twinmeContext removeDelegate:self.twinmeContextDelegate];
        self.twinmeContextDelegate = nil;
    }
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    if (self.isTwinlifeReady) {
        [self.accountMigrationService removeDelegate:self.accountMigrationServiceDelegate];
    }
    if (self.twinmeContextDelegate) {
        [self.twinmeContext removeDelegate:self.twinmeContextDelegate];
        self.twinmeContextDelegate = nil;
    }
    if (self.networkLock) {
        [self.networkLock releaseLock];
        self.networkLock = nil;
    }
    
    [self.accountMigrationService cleanup];
}

#pragma mark - Private methods

- (BOOL)isConnected {
    
    return self.status && self.status.isConnected;
}

- (BOOL)canAcceptIncomingMigration {
    DDLogVerbose(@"%@ canAcceptIncomingMigration peerVersion: %@", LOG_TAG, self.peerVersion);

    if (!self.peerVersion) {
        return NO;
    }
    
    if (self.acceptAny) {
        return YES;
    }
    
    // Look if we have some contacts, or groups, or click-to-call.
    // We don't care for Space, Profile and other objects.
    TLRepositoryService *repositoryService = self.twinmeContext.getRepositoryService;
    
    BOOL hasRelations = [repositoryService hasObjectsWithSchemaId:[TLContact SCHEMA_ID]]
                         || [repositoryService hasObjectsWithSchemaId:[TLGroup SCHEMA_ID]]
                         || [repositoryService hasObjectsWithSchemaId:[TLCallReceiver SCHEMA_ID]];
    // If the peer version is too old, there is a strong risk to loose data: if we send our database
    // it has a new format that is not compatible with the peer device application.
    // - if version match, we can proceed,
    // - if our version is newer and there is no relation, we can proceed,
    // - if our version is older and the peer has no relation, we can proceed.
    TLVersion *supportedVersion = [[TLVersion alloc] initWithVersion:TLAccountMigrationService.VERSION];
    
    TLVersion *peerVersion = self.peerVersion.version;
    BOOL peerHasRelations = self.peerVersion.hasRelations;
    
    return (peerVersion.major == supportedVersion.major)
        || (peerVersion.major < supportedVersion.major && !hasRelations)
        || (peerVersion.major > supportedVersion.major && !peerHasRelations);
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);

    if (!self.isTwinlifeReady) {
        return;
    }
    
    DDLogVerbose(@"%@ onOperation state=%d migrationState=%ld work=%d init=%@ ", LOG_TAG, self.state, (long)self.migrationState, self.work, self.initiator ? @"YES":@"NO");
    
    if ((self.work & CANCEL_MIGRATION) != 0) {
        if ((self.state & CANCEL_MIGRATION) == 0) {
            self.state |= CANCEL_MIGRATION;
            
            if (self.accountMigrationId) {
                [self.accountMigrationService cancelMigrationWithDeviceMigrationId:self.accountMigrationId];
            }
            
            if (self.incomingAccountMigrationId) {
                [self.accountMigrationService cancelMigrationWithDeviceMigrationId:self.incomingAccountMigrationId];
            }
        }
    }
    
    //
    // Step 1a: get the account migration object (outgoing mode).
    //

    if (self.accountMigrationId) {
        
        if ((self.state & GET_ACCOUNT_MIGRATION) == 0) {
            self.state |= GET_ACCOUNT_MIGRATION;
            
            [self.twinmeContext getAccountMigrationWithAccountMigrationId:self.accountMigrationId withBlock:^(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable accountMigration) {
                self.accountMigration = accountMigration;
                if (errorCode != TLBaseServiceErrorCodeSuccess || !self.accountMigration) {
                    [self.accountMigrationService cancelMigrationWithDeviceMigrationId:self.accountMigrationId];
                    
                    // Send an error to inform the AccountMigrationViewController before stopping.
                    [self dispatchErrorWithErrorCode:TLAccountMigrationErrorCodeInternalError];
                    self.work |= STOP_SERVICE;
                } else {
                    TLTwincodeOutbound *peerTwincode = accountMigration.peerTwincodeOutbound;
                    if (peerTwincode) {
                        self.peerVersion = [TLTwinmeAttributes getTwincodeAttributeAccountMigrationWithTwincode:peerTwincode];
                    }
                }
                self.state |= GET_ACCOUNT_MIGRATION_DONE;
                [self onOperation];
            }];
        }
        
        if ((self.state & GET_ACCOUNT_MIGRATION_DONE) == 0) {
            return;
        }
    }
    
    //
    // Work action: start the outgoing migration P2P connection.
    //
    if (self.accountMigration && (self.work & OUTGOING_MIGRATION) != 0) {
        // Wait for the peer device to receive the invocation and send us back an invocation.
        
        NSUUID *peerTwincodeOutboundId = self.accountMigration.peerTwincodeOutboundId;
        NSUUID *twincodeOutboundId = self.accountMigration.twincodeOutbound.uuid;
        
        if (!self.accountMigration.isBound || !peerTwincodeOutboundId || !twincodeOutboundId) {
            return;
        }
        
        if ((self.state & OUTGOING_MIGRATION) == 0) {
            self.state |= OUTGOING_MIGRATION;
            
            // We need the network for the duration of the migration
            self.networkLock = [self.twinmeContext.getJobService allocateNetworkLock];
            
            int64_t requestId = [self newOperation:OUTGOING_MIGRATION];
            DDLogVerbose(@"%@ accountMigrationService outgoingStartMigrationWithRequestId: %lld accountMigration:%@", LOG_TAG, requestId, self.accountMigration);
            
            [self.accountMigrationService outgoingStartMigrationWithRequestId:requestId accountMigrationId:self.accountMigration.uuid peerTwincodeOutboundId:peerTwincodeOutboundId twincodeOutboundId:twincodeOutboundId];
        }
    }

    //
    // Step 1b: get the account migration object (incoming mode).
    //
    if (self.incomingAccountMigration) {
  
        //
        // Work action: accept the incoming P2P connection for the account migration.
        //
        if ((self.work & ACCEPT_MIGRATION) != 0 && self.incomingPeerConnectionId) {
            if ((self.state & ACCEPT_MIGRATION) == 0) {
                self.state |= ACCEPT_MIGRATION;

                TLTwincodeOutbound *peerTwincode = self.incomingAccountMigration.peerTwincodeOutbound;
                if (peerTwincode) {
                    self.peerVersion = [TLTwinmeAttributes getTwincodeAttributeAccountMigrationWithTwincode:peerTwincode];
                }

                if (peerTwincode && [self canAcceptIncomingMigration]) {
                    // We need the network for the duration of the migration
                    self.networkLock = [self.twinmeContext.getJobService allocateNetworkLock];

                    [self.accountMigrationService incomingStartMigrationWithPeerConnectionId:self.incomingPeerConnectionId accountMigrationId:self.incomingAccountMigration.uuid peerTwincodeOutboundId:peerTwincode.uuid twincodeOutboundId:self.incomingAccountMigration.twincodeOutbound.uuid];
                } else {
                        //TODOAM ask for confirmation? On Android we send MESSAGE_INCOMING to AccountMigrationScannerActivity, which starts the AccountMigration service/activity, but this doesn't seem needed on iOS. Keeping this comment in case we encounter issues on the incoming device.
                }
            }
        }
    }
        
    //
    // Work action: query the peer's device stats.
    //
    if (self.accountMigration && [self isConnected] && (self.work & QUERY_STAT) != 0) {
        if ((self.state & QUERY_STAT) == 0) {
            self.state |= QUERY_STAT;
                
            int64_t requestId = [self newOperation:QUERY_STAT];
            [self.accountMigrationService queryStatsWithRequestId:requestId maxFileSize:LONG_MAX];
        }
        if ((self.state & QUERY_STAT_DONE) == 0) {
            return;
        }
    }
        
    //
    // Work action: start the migration.
    //
    if (self.accountMigration && [self isConnected] && (self.work & START_MIGRATION) != 0) {
        if ((self.state & START_MIGRATION) == 0) {
            self.state |= START_MIGRATION;
                
            int64_t requestId = [self newOperation:START_MIGRATION];
            [self.accountMigrationService startMigrationWithRequestId:requestId maxFileSize:LONG_MAX];
        }
    }
        
    //
    // Work step: send the terminate-migration message to proceed to termination phase1: we ask the peer to delete its twincode.
    //
    if (self.accountMigration && [self isConnected] && (self.work & TERMINATE_PHASE1) != 0) {
        if ((self.state & TERMINATE_PHASE1) == 0) {
            self.state |= TERMINATE_PHASE1;
                
            int64_t requestId = [self newOperation:TERMINATE_PHASE1];
            [self.accountMigrationService terminateMigrationWithRequestId:requestId commit:self.commit done:NO];
            return;
        }
            
        if ((self.state & TERMINATE_PHASE1_DONE) == 0) {
            return;
        }
    }
        
    //
    // Work step: delete the device migration object.
    //
    if (self.accountMigration && (self.work & DELETE_MIGRATION) != 0) {
        if ((self.state & DELETE_MIGRATION) == 0) {
            self.state |= DELETE_MIGRATION;
            
            [self.twinmeContext deleteAccountMigrationWithAccountMigration:self.accountMigration withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable uuid) {
                self.state |= DELETE_MIGRATION_DONE;
                [self onOperation];
            }];
            return;
        }
        
        if ((self.state & DELETE_MIGRATION_DONE) == 0) {
            return;
        }
    }
    
    //
    // Work step: send the terminate-migration message to proceed to termination phase2: tell the peer we have done it.
    //
    if (self.accountMigration && [self isConnected] && (self.work & TERMINATE_PHASE2) != 0) {
        if ((self.state & TERMINATE_PHASE2) == 0) {
            self.state |= TERMINATE_PHASE2;
            
            [self.accountMigrationService terminateMigrationWithRequestId:self.terminateRequestId commit:self.commit done:YES];
            return;
        }
        
        if ((self.state & TERMINATE_PHASE2_DONE) == 0) {
            return;
        }
    }

    //
    // Work step: send the terminate-migration message to proceed to termination phase2: tell the peer we have done it.
    //
    if (self.accountMigration && [self isConnected] && (self.work & FINAL_SHUTDOWN) != 0) {
        if ((self.state & FINAL_SHUTDOWN) == 0) {
            self.state |= FINAL_SHUTDOWN;
                
            int64_t requestId = [self newOperation:FINAL_SHUTDOWN];
            [self.accountMigrationService shutdownMigrationWithRequestId:requestId];
        }
        if ((self.state & FINAL_SHUTDOWN_DONE) == 0) {
            return;
        }
    }
        
    //
    // Work step: stop the service when all the above is done (it must be last and callable even if mDeviceMigration is null).
    //
    if ((self.work & STOP_SERVICE) != 0) {
        if ((self.state & STOP_SERVICE) == 0) {
            self.state |= STOP_SERVICE;
            [self dispose];
        }
    }
}

- (void)onUpdateAccountMigrationWithAccountMigration:(nonnull TLAccountMigration *)accountMigration {
    DDLogVerbose(@"%@ onUpdateAccountMigrationWithAccountMigration: %@", LOG_TAG, accountMigration);
    
    self.accountMigration = accountMigration;
}

- (void)onDeleteAccountMigrationWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId {
    DDLogVerbose(@"%@ onDeleteAccountMigrationWithAccountMigrationId: %@", LOG_TAG, accountMigrationId.UUIDString);

    // If this is an expected delete, we are done.
    if ((self.state & DELETE_MIGRATION) != 0) {
        return;
    }
    
    // This is an unexpected deleted, we must cancel the migration.
    if (![self.accountMigrationService cancelMigrationWithDeviceMigrationId:accountMigrationId]) {
        return;
    }
    
    self.state |= STOP_SERVICE;
    self.work |= STOP_SERVICE;
    
    // And send a new state with canceled state so that the activity is aware of the cancel.
    self.migrationState = TLAccountMigrationStateCanceled;
    [self dispatchUpdateMigrationState];
}

- (void)onQueryStatsWithPeerInfo:(nonnull TLQueryInfo *)peerInfo localInfo:(nonnull TLQueryInfo *)localInfo {
    DDLogVerbose(@"%@ onQueryStatsWithPeerInfo: %@ localInfo: %@", LOG_TAG, peerInfo, localInfo);
    
    self.state |= QUERY_STAT_DONE;
    self.peerQueryInfo = peerInfo;
    self.localQueryInfo = localInfo;
    
    [self dispatchUpdateMigrationState];
}

- (BOOL)onStatusChangeWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId status:(TLAccountMigrationStatus *)status {
    DDLogVerbose(@"%@ onStatusChangeWithAccountMigrationId: %@ status: %@", LOG_TAG, accountMigrationId.UUIDString, status);
    
    TLAccountMigrationState state = status.state;
    if (state == TLAccountMigrationStateListFiles && self.startTime == 0) {
        self.startTime = [[NSDate date] timeIntervalSince1970] * 1000L;
    }
    
    // The service was started due to an incoming migration request, update the information once we are connected.
    // Update the state since the GET_ACCOUNT_MIGRATION operation is not necessary.
    if (!self.accountMigration && [accountMigrationId isEqual:self.incomingAccountMigrationId]) {
        self.state |= GET_ACCOUNT_MIGRATION | GET_ACCOUNT_MIGRATION_DONE;
        self.accountMigration = self.incomingAccountMigration;
        self.accountMigrationId = self.incomingAccountMigrationId;
    }
    if (!self.accountMigration && state == TLAccountMigrationStateNegociate) {
        DDLogError(@"%@ No accountMigration object:%@", LOG_TAG, [self.incomingAccountMigrationId.UUIDString stringByAppendingFormat:@" %@", accountMigrationId]);
    }
    
    // Detect when the P2P connection was restarted: we must cleanup our state
    // so that we can proceed with the new P2P connection.
    BOOL needRestart = self.migrationState != state && state == TLAccountMigrationStateListFiles && self.migrationState > state;
    
    self.migrationState = state;
    self.status = status;
    [self dispatchUpdateMigrationState];

    if (state == TLAccountMigrationStateNegociate || needRestart) {
        // Starting a new P2P connection and we are now connected.
        self.state |= ACCEPT_MIGRATION_DONE | OUTGOING_MIGRATION_DONE;
        self.state &= ~(QUERY_STAT | QUERY_STAT_DONE);
        self.state &= ~(TERMINATE_PHASE1 | TERMINATE_PHASE1_DONE);
        self.state &= ~(DELETE_MIGRATION | DELETE_MIGRATION_DONE);
        self.state &= ~(TERMINATE_PHASE2 | TERMINATE_PHASE2_DONE);
        self.state &= ~(FINAL_SHUTDOWN | FINAL_SHUTDOWN_DONE);
        self.work &= ~(TERMINATE_PHASE1 | TERMINATE_PHASE2 | DELETE_MIGRATION | FINAL_SHUTDOWN);
        self.work |= QUERY_STAT;

        return YES;
    } else if (state == TLAccountMigrationStateCanceled) {
        
        // P2P connection canceled or migration canceled: delete the migration object.
        self.state &= ~(DELETE_MIGRATION | DELETE_MIGRATION_DONE);
        self.work |= DELETE_MIGRATION | DELETE_MIGRATION_DONE;
        return YES;
    } else if (state == TLAccountMigrationStateTerminate && (self.work & TERMINATE_PHASE1) == 0 && self.initiator) {
        
        // Start the terminate phase 1
        self.work |= TERMINATE_PHASE1;
        self.commit = YES;
        return YES;
    } else if (state == TLAccountMigrationStateStopped) {
        self.work |= STOP_SERVICE;
        return YES;
    }
    
    // No state change!
    return NO;
}

- (void)onTerminateMigrationWithRequestId:(int64_t)requestId operation:(nullable NSNumber *)operation commit:(BOOL)commit done:(BOOL)done {
    DDLogVerbose(@"%@ onTerminateMigrationWithRequestId: %lld operation:%d commit: %@ done: %@", LOG_TAG, requestId, operation.intValue, commit ? @"YES":@"NO", done ? @"YES":@"NO");
        
    if (operation == nil && !done) {
        self.state |= TERMINATE_PHASE1 | TERMINATE_PHASE1_DONE;
        self.work |= FINAL_SHUTDOWN | STOP_SERVICE;
        self.terminateRequestId = requestId;

   } else if (operation == nil && !self.initiator) {
        self.state |= TERMINATE_PHASE2 | TERMINATE_PHASE2_DONE;
        self.terminateRequestId = requestId;

   } else if (operation.intValue == TERMINATE_PHASE1) {
        self.state |= TERMINATE_PHASE1_DONE;
        self.terminateRequestId = requestId;

   } else if (operation.intValue == TERMINATE_PHASE2) {
        self.state |= TERMINATE_PHASE2_DONE;
        self.terminateRequestId = requestId;

   }

   self.commit = commit;
   self.work |= DELETE_MIGRATION | TERMINATE_PHASE2;
}

- (void) onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter:%@", LOG_TAG, operationId, errorCode, errorParameter);
    
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        return;
    }
    
    if (errorCode == TLBaseServiceErrorCodeBadRequest) {
        [self dispatchErrorWithErrorCode:TLAccountMigrationErrorCodeInternalError];
        self.work |= STOP_SERVICE;
    }
}

- (void)dispatchUpdateMigrationState {
    if (!self.accountMigrationId) {
        self.accountMigrationId = [self.accountMigrationService getActiveDeviceMigrationId];
    }
    
    id<AccountMigrationServiceDelegate> observer = self.migrationObserver;
    if (observer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [observer onUpdateMigrationStateWithMigrationId:self.accountMigrationId startTime:self.startTime state:self.migrationState status:self.status peerInfo:self.peerQueryInfo localInfo:self.localQueryInfo peerVersion:self.peerVersion];
        });
    }
}

- (void)dispatchErrorWithErrorCode:(TLAccountMigrationErrorCode)errorCode {
    id<AccountMigrationServiceDelegate> observer = self.migrationObserver;
    if (observer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [observer onErrorWithErrorCode:errorCode];
        });
    }
}

@end
