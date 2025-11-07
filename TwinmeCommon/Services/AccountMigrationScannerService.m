/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLAccountMigrationService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLFilter.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLTwinmeAttributes.h>
#import <Twinme/TLSpace.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLCallReceiver.h>
#import <Twinme/TLAccountMigration.h>

#import "AccountMigrationScannerService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_CURRENT_SPACE = 1 << 0;
static const int GET_CURRENT_SPACE_DONE = 1 << 1;
static const int CREATE_ACCOUNT_MIGRATION = 1 << 2;
static const int CREATE_ACCOUNT_MIGRATION_DONE = 1 << 3;
static const int GET_TWINCODE = 1 << 4;
static const int GET_TWINCODE_DONE = 1 << 5;
static const int BIND_ACCOUNT_MIGRATION = 1 << 6;
static const int BIND_ACCOUNT_MIGRATION_DONE = 1 << 7;

//
// Interface: A ()
//

@class ScannerAccountMigrationServiceDelegate;

@interface AccountMigrationScannerService ()
@property (nonatomic, nullable) NSUUID *twincodeOutboundId;
@property (nonatomic, nullable) TLTwincodeOutbound *twincodeOutbound;
@property BOOL hasRelations;
@property (nonatomic, nullable) TLAccountMigration *accountMigration;

@property (nonatomic, nonnull, readonly) ScannerAccountMigrationServiceDelegate *accountMigrationServiceDelegate;

@property (nonatomic) int work;

- (void)onOperation;

- (void)onUpdateAccountMigrationWithAccountMigration:(nonnull TLAccountMigration *)accountMigration;

- (void)onDeleteAccountMigrationWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

- (void)onStatusChangeWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId status:(nonnull TLAccountMigrationStatus *)status;

@end

//
// Interface: AccountMigrationScannerServiceTwinmeContextDelegate
//

@interface AccountMigrationScannerServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull AccountMigrationScannerService *)service;

@end

//
// Implementation: AccountMigrationScannerServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"AccountMigrationScannerServiceTwinmeContextDelegate"

@implementation AccountMigrationScannerServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull AccountMigrationScannerService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onUpdateAccountMigrationWithRequestId:(int64_t)requestId accountMigration:(TLAccountMigration *)accountMigration {
    DDLogVerbose(@"%@ onUpdateAccountMigrationWithRequestId: %lld accountMigration: %@", LOG_TAG, requestId, accountMigration);
    
    AccountMigrationScannerService *service = (AccountMigrationScannerService *)self.service;
    [service onUpdateAccountMigrationWithAccountMigration:accountMigration];
    [service onOperation];
}

- (void)onDeleteAccountMigrationWithRequestId:(int64_t)requestId accountMigrationId:(nonnull NSUUID *)accountMigrationId {
    DDLogVerbose(@"%@ onDeleteAccountMigrationWithRequestId: %lld accountMigrationId: %@", LOG_TAG, requestId, accountMigrationId);

    AccountMigrationScannerService *service = (AccountMigrationScannerService *)self.service;
    [service onDeleteAccountMigrationWithAccountMigrationId:accountMigrationId];
    [service onOperation];
}

@end

//
// Interface: AccountMigrationServiceDelegate
//

@interface ScannerAccountMigrationServiceDelegate: NSObject <TLAccountMigrationServiceDelegate>

@property (weak) AccountMigrationScannerService *service;

- (nonnull instancetype)initWithService:(nonnull AccountMigrationScannerService *)service;

@end

//
// Implementation: AccountMigrationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"AccountMigrationServiceDelegate"

@implementation ScannerAccountMigrationServiceDelegate

- (nonnull instancetype)initWithService:(nonnull AccountMigrationScannerService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onStatusChangeWithDeviceMigrationId:(nonnull NSUUID *)deviceMigrationId status:( nonnull TLAccountMigrationStatus *)status {
    DDLogVerbose(@"%@ onStatusChangeWithDeviceMigrationId: %@ status: %@", LOG_TAG, [deviceMigrationId toString], status);
    
    [self.service onStatusChangeWithAccountMigrationId:deviceMigrationId status:status];
}

@end

//
// Implementation: AccountMigrationScannerService
//

#undef LOG_TAG
#define LOG_TAG @"AccountMigrationScannerService"

@implementation AccountMigrationScannerService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<AccountMigrationScannerServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[AccountMigrationScannerServiceTwinmeContextDelegate alloc] initWithService:self];
        _accountMigrationServiceDelegate = [[ScannerAccountMigrationServiceDelegate alloc] initWithService:self];
        _work = CREATE_ACCOUNT_MIGRATION;
        _hasRelations = NO;
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
        [self showProgressIndicator];
        
        if (!self.twinmeContext.isConnected) {
            [self.twinmeContext connect];
        }
    }
    return self;
}

- (void)getTwincodeOutboundWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId {
    DDLogVerbose(@"%@ getTwincodeOutboundWithTwincodeOutboundId: %@", LOG_TAG, twincodeOutboundId);
    
    self.twincodeOutboundId = twincodeOutboundId;
    self.work = GET_TWINCODE;
    self.state &= ~(GET_TWINCODE | GET_TWINCODE_DONE);
    
    [self showProgressIndicator];
    [self startOperation];
}

- (void)bindAccountMigrationWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@ bindAccountMigrationWithTwincodeOutbound: %@", LOG_TAG, twincodeOutbound);
    
    self.twincodeOutbound = twincodeOutbound;
    self.work = BIND_ACCOUNT_MIGRATION;
    self.state &= ~(BIND_ACCOUNT_MIGRATION | BIND_ACCOUNT_MIGRATION_DONE);
    
    [self showProgressIndicator];
    [self startOperation];
}

- (void)createAccountMigration {
    DDLogVerbose(@"%@ createAccountMigration", LOG_TAG);
    
    self.work = CREATE_ACCOUNT_MIGRATION;
    self.state &= ~(CREATE_ACCOUNT_MIGRATION | CREATE_ACCOUNT_MIGRATION_DONE | BIND_ACCOUNT_MIGRATION | BIND_ACCOUNT_MIGRATION_DONE);
    
    [self showProgressIndicator];
    [self startOperation];
}

- (void)parseURIWithUri:(nonnull NSURL *)uri withBlock:(nonnull void (^)(TLBaseServiceErrorCode, TLTwincodeURI * _Nullable __strong))block {
    DDLogVerbose(@"%@ parseURIWithUri:%@", LOG_TAG, uri.absoluteString);
    
    dispatch_async(self.twinmeContext.twinlife.twinlifeQueue, ^{
        [self.twinmeContext.getTwincodeOutboundService parseUriWithUri:uri withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI * _Nullable twincodeUri) {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(errorCode, twincodeUri);
            });
        }];
    });
}


- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    if (self.isTwinlifeReady) {
        [[self.twinmeContext getAccountMigrationService] removeDelegate:self.accountMigrationServiceDelegate];
    }
    
    self.delegate = nil;
    [super dispose];
}

#pragma mark - Private methods

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getAccountMigrationService] addDelegate:self.accountMigrationServiceDelegate];
    [super onTwinlifeReady];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        self.restarted = NO;
        
        if (((self.state & GET_TWINCODE) != 0 ) && ((self.state & GET_TWINCODE_DONE) == 0)) {
            self.state &= ~GET_TWINCODE;
        }
    }
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    //
    // Step 1: get the current space.
    //
    if ((self.state & GET_CURRENT_SPACE) == 0) {
        self.state |= GET_CURRENT_SPACE;
        
        [self.twinmeContext getCurrentSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
            self.state |= GET_CURRENT_SPACE_DONE;
            
            // Look if we have some contacts, or groups, or click-to-call.
            // We don't care for Space, Profile and other objects.
            TLRepositoryService *repositoryService = [self.twinmeContext getRepositoryService];
            self.hasRelations = [repositoryService hasObjectsWithSchemaId:[TLContact SCHEMA_ID]];
            if (!self.hasRelations) {
                self.hasRelations = [repositoryService hasObjectsWithSchemaId:[TLGroup SCHEMA_ID]];
                if (!self.hasRelations) {
                    self.hasRelations = [repositoryService hasObjectsWithSchemaId:[TLCallReceiver SCHEMA_ID]];
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate) {
                    if (space && space.profile) {
                        [(id<AccountMigrationScannerServiceDelegate>)self.delegate onGetDefaultProfile:space.profile];
                    } else {
                        [(id<AccountMigrationScannerServiceDelegate>)self.delegate onGetDefaultProfileNotFound];
                    }
                    if (self.hasRelations) {
                        [(id<AccountMigrationScannerServiceDelegate>)self.delegate onHasRelations];
                    }
                }
            });
            [self onOperation];
        }];
        return;
    }
    
    if ((self.state & GET_CURRENT_SPACE_DONE) == 0) {
        return;
    }
    
    //
    // Step 1: create the account migration object and its twincode.
    //
    if ((self.work & CREATE_ACCOUNT_MIGRATION) != 0) {
        if ((self.state & CREATE_ACCOUNT_MIGRATION) == 0) {
            self.state |= CREATE_ACCOUNT_MIGRATION;
            
            [self.twinmeContext createAccountMigrationWithBlock:^(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable accountMigration) {
                self.state |= CREATE_ACCOUNT_MIGRATION_DONE;
                self.accountMigration = accountMigration;
                
                [self.twinmeContext.getTwincodeOutboundService createURIWithTwincodeKind:TLTwincodeURIKindAccountMigration twincodeOutbound:accountMigration.twincodeOutbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI * _Nullable twincodeUri) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.delegate) {
                            [(id<AccountMigrationScannerServiceDelegate>)self.delegate onCreateAccountMigration:accountMigration twincodeUri:twincodeUri];
                        }
                    });
                    [self onOperation];
                }];
            }];
            return;
        }
        
        if ((self.state & CREATE_ACCOUNT_MIGRATION_DONE) == 0) {
            return;
        }
    }
    
    // We must get the account migration twincode.
    if ((self.work & GET_TWINCODE) != 0 && self.twincodeOutboundId) {
        if ((self.state & GET_TWINCODE) ==0) {
            self.state |= GET_TWINCODE;
            
            DDLogVerbose(@"%@ twincodeOutboundService getTwincodeWithTwincodeId: %@", LOG_TAG, self.twincodeOutboundId);
            
            TLTwincodeOutboundService *twincodeOutboundService = [self.twinmeContext getTwincodeOutboundService];
            
            [twincodeOutboundService getTwincodeWithTwincodeId:self.twincodeOutboundId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound * _Nullable twincodeOutbound) {
                DDLogVerbose(@"%@ onGetTwincodeOutbound: twincodeOutbound=%@", LOG_TAG, twincodeOutbound);
                
                if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeOutbound) {
                    [self onErrorWithOperationId:GET_TWINCODE errorCode:errorCode errorParameter:nil];
                    return;
                }
                
                self.state |= GET_TWINCODE_DONE;
                
                self.twincodeOutbound = twincodeOutbound;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.delegate) {
                        [(id<AccountMigrationScannerServiceDelegate>)self.delegate onGetTwincodeWithTwincode:twincodeOutbound avatar:nil];
                    }
                });
                
                [self onOperation];
            }];
            return;
        }
        
        if ((self.state & GET_TWINCODE_DONE) == 0) {
            return;
        }
    }
    
    // We must bind the account migration with the peer twincode.
    if ((self.work & BIND_ACCOUNT_MIGRATION) != 0 && self.twincodeOutbound && self.accountMigration) {
        if ((self.state & BIND_ACCOUNT_MIGRATION) == 0) {
            self.state |= BIND_ACCOUNT_MIGRATION;
            
            DDLogVerbose(@"%@ twinmeContext bindDeviceMigration: twincodeOutboundId=%@", LOG_TAG, self.twincodeOutboundId);
            
            [self.twinmeContext bindAccountMigrationWithAccountMigration:self.accountMigration twincodeOutbound:self.twincodeOutbound withBlock:^(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable accountMigration) {
                DDLogVerbose(@"%@ onBindDeviceMigration: errorCode=%u accountMigration=%@", LOG_TAG, errorCode, accountMigration);
                if (errorCode == TLBaseServiceErrorCodeSuccess && accountMigration) {
                    self.accountMigration = accountMigration;
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.delegate) {
                            [(id<AccountMigrationScannerServiceDelegate>)self.delegate onAccountMigrationConnected:self.accountMigration.uuid];
                        }
                    });
                }
                
                self.state |= BIND_ACCOUNT_MIGRATION_DONE;
                [self onOperation];
            }];
            return;
        }
        
        if ((self.state & BIND_ACCOUNT_MIGRATION_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

- (void)onUpdateAccountMigrationWithAccountMigration:(TLAccountMigration *)accountMigration {
    DDLogVerbose(@"%@ onUpdateAccountMigrationWithAccountMigration: %@", LOG_TAG, accountMigration);
    
    if (!self.accountMigration || ![accountMigration.uuid isEqual:self.accountMigration.uuid]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<AccountMigrationScannerServiceDelegate>)self.delegate onUpdateAccountMigration:self.accountMigration];
    });
}

- (void)onDeleteAccountMigrationWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId {
    DDLogVerbose(@"%@ onDeleteAccountMigrationWithAccountMigrationId: %@", LOG_TAG, accountMigrationId);
    
    if (!self.accountMigration || ![accountMigrationId isEqual:self.accountMigration.uuid]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<AccountMigrationScannerServiceDelegate>)self.delegate onDeleteAccountMigration:accountMigrationId];
    });
}

- (void)onStatusChangeWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId status:(nonnull TLAccountMigrationStatus *)status {
    DDLogVerbose(@"%@ onStatusChangeWithAccountMigrationId: %@ status: %@", LOG_TAG, accountMigrationId, status);

    if (status.state == TLAccountMigrationStateNegociate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<AccountMigrationScannerServiceDelegate>)self.delegate onAccountMigrationConnected:accountMigrationId];
        });
        [self onOperation];
    }
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %i errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    if (operationId == GET_TWINCODE) {
        [self hideProgressIndicator];
        
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            if (self.delegate) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [(id<AccountMigrationScannerServiceDelegate>)self.delegate onGetTwincodeNotFound];
                });
            }
            
            return;
        }
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
