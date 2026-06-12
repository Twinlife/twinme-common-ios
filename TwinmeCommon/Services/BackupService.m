/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "BackupService.h"
#import <Twinlife/TLBackupService.h>
#import <Twinlife/NSData+Extensions.h>
#import <Twinlife/TLRestoreContent.h>
#import <Twinlife/TLVerifyReport.h>
#import <Twinme/TLTwinmeContext.h>
#import "MnemonicCodeUtils.h"
#import <Twinme/TLSpaceSettings.h>
#import <Twinme/TLSpace.h>
#import <Twinme/TLProfile.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLCallReceiver.h>

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

@class BackupServiceDelegate;

//
// Interface: BackupService
//

@interface BackupService ()

@property (nonatomic, nullable) TLBackupService *backupService;
@property (nonatomic, nonnull, readonly) MnemonicCodeUtils *mnemonicCodeUtils;

@property (nonatomic, nonnull, readonly) BackupServiceDelegate *backupServiceDelegate;

@property (nonatomic, nonnull) NSArray<NSUUID *> *supportedSchemaIds;

@property (nonatomic) TLBackupState backupState;
@property (nonatomic) TLRestoreState restoreState;
@property (nonatomic) TLBackupServiceTerminateReason terminateReason;
@property (nonatomic, nullable) NSUUID *backupId;
@property (nonatomic, nullable) NSString *backupFilePath;
@property (nonatomic) TLBackupServiceErrorCode errorCode;
@property (nonatomic, nullable) TLBackupHeaderInfo *backupHeaderInfo;
@property (nonatomic, nullable) NSArray<NSString *> *passwordWords;

- (void)onBackupHeaderInfoWithHeaderInfo:(nonnull TLBackupHeaderInfo *)headerInfo lastBackupId:(nullable NSUUID *)lastBackupId lastBackupTimestamp:(int64_t)lastBackupTimestamp;

- (void)onBackupStateChangeWithBackupId:(nonnull NSUUID *)backupId state:(TLBackupState)state;

- (void)onRestoreStateChangeWithState:(TLRestoreState)state restoreContent:(nullable TLRestoreContent *)restoreContent;

- (void)onTerminateBackupWithBackupId:(nonnull NSUUID *)backupId backupFilePath:(nullable NSString *)backupFilePath stats:(nonnull NSDictionary<NSUUID *, NSNumber *> *)stats done:(BOOL)done;

- (void)onTerminateRestoreWithTerminateReason:(TLBackupServiceTerminateReason)terminateReason;

- (void)onBackupErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode;

- (void)onRestoreErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode;

- (void)onGetAllBackupsWithErrorCode:(TLBaseServiceErrorCode)errorCode backups:(NSArray<TLBackupInfo *> *)backups;

- (void)onDeleteBackupsWithErrorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onTerminateVerifyWithReport:(nonnull TLVerifyReport *)report;

@end

//
// Interface: RestoreReport
//
@interface RestoreReport ()

- (nonnull instancetype)initWithRestoreContent:(nonnull TLRestoreContent *)restoreContent;

- (nonnull instancetype)initWithVerifyReport:(nonnull TLVerifyReport *)verifyReport;

@end

//
// Implementation: RestoreReport
//
@implementation RestoreReport

- (nonnull instancetype)initWithRestoreContent:(nonnull TLRestoreContent *)restoreContent {
    self = [super init];
    
    if (self) {
        _contacts = [restoreContent getStatsWithSchemaId:TLContact.SCHEMA_ID];
        _groups = [restoreContent getStatsWithSchemaId:TLGroup.SCHEMA_ID];
        _profiles = [restoreContent getStatsWithSchemaId:TLProfile.SCHEMA_ID];
        _clickToCall = [restoreContent getStatsWithSchemaId:TLCallReceiver.SCHEMA_ID];
    }
    
    return self;
}

- (nonnull instancetype)initWithVerifyReport:(TLVerifyReport *)verifyReport {
    self = [super init];
    
    if (self) {
        _contacts = [verifyReport getStatsWithSchemaId:TLContact.SCHEMA_ID];
        _groups = [verifyReport getStatsWithSchemaId:TLGroup.SCHEMA_ID];
        _profiles = [verifyReport getStatsWithSchemaId:TLProfile.SCHEMA_ID];
        _clickToCall = [verifyReport getStatsWithSchemaId:TLCallReceiver.SCHEMA_ID];
    }
    
    return self;
}


- (BOOL)isRestoreUpToDate {
    return self.contacts.isStatsUpToDate && self.profiles.isStatsUpToDate && self.clickToCall.isStatsUpToDate && self.groups.isStatsUpToDate;
}

@end

//
// Interface: BackupServiceTwinmeContextDelegate
//

@interface BackupServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull BackupService *)service;

@end

//
// Implementation: BackupServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"BackupServiceTwinmeContextDelegate"

@implementation BackupServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull BackupService *)service {
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

@end

//
// Interface: BackupServiceDelegate
//

@interface  BackupServiceDelegate : NSObject<TLBackupServiceDelegate>

@property (nonatomic, nonnull, readonly) BackupService *service;

- (nonnull instancetype)initWithService:(nonnull BackupService *)service;

@end


//
// Implementation: BackupServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"BackupServiceDelegate"

@implementation BackupServiceDelegate

- (nonnull instancetype)initWithService:(nonnull BackupService *)service {
    self = [super init];
    
    if (self) {
        _service = service;
    }
    
    return self;
}

- (void)onBackupHeaderInfoWithHeaderInfo:(nonnull TLBackupHeaderInfo *)headerInfo lastBackupId:(nullable NSUUID *)lastBackupId lastBackupTimestamp:(int64_t)lastBackupTimestamp {
    DDLogVerbose(@"%@ onBackupHeaderInfoWithHeaderInfo: %@", LOG_TAG, headerInfo);
    
    [self.service onBackupHeaderInfoWithHeaderInfo:headerInfo lastBackupId:lastBackupId lastBackupTimestamp:lastBackupTimestamp];
}

- (void)onBackupStateChangeWithBackupId:(nonnull NSUUID *)backupId state:(TLBackupState)state {
    DDLogVerbose(@"%@ onBackupStateChangeWithBackupId: %@ state:%u", LOG_TAG, backupId, state);

    [self.service onBackupStateChangeWithBackupId:backupId state:state];
}

- (void)onRestoreStateChangeWithState:(TLRestoreState)state restoreContent:(nullable TLRestoreContent *)restoreContent {
    DDLogVerbose(@"%@ onRestoreStateChangeWithState: %u restoreContent:%@", LOG_TAG, state, restoreContent);

    [self.service onRestoreStateChangeWithState:state restoreContent:restoreContent];
}

- (void)onTerminateBackupWithBackupId:(nonnull NSUUID *)backupId backupFilePath:(nullable NSString *)backupFilePath stats:(nonnull NSDictionary<NSUUID *, NSNumber *> *)stats done:(BOOL)done {
    DDLogVerbose(@"%@ onTerminateBackupWithBackupId: %@ backupFilePath:%@ done:%@", LOG_TAG, backupId, backupFilePath, done ? @"YES" : @"NO");

    [self.service onTerminateBackupWithBackupId:backupId backupFilePath:backupFilePath stats:stats done:done];
}

- (void)onTerminateRestoreWithTerminateReason:(TLBackupServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ onTerminateRestoreWithTerminateReason: %d", LOG_TAG, terminateReason);

    [self.service onTerminateRestoreWithTerminateReason:terminateReason];
}

- (void)onBackupErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode {
    DDLogVerbose(@"%@ onBackupErrorWithBackupErrorCode: %d baseErrorCpde: %d", LOG_TAG, backupErrorCode, baseErrorCode);

    [self.service onBackupErrorWithBackupErrorCode:backupErrorCode baseErrorCode:baseErrorCode];
}

- (void)onRestoreErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode {
    DDLogVerbose(@"%@ onRestoreErrorWithBackupErrorCode: %d baseErrorCode: %d", LOG_TAG, backupErrorCode, baseErrorCode);

    [self.service onRestoreErrorWithBackupErrorCode:backupErrorCode baseErrorCode:baseErrorCode];
}

- (void)onGetAllBackupsWithErrorCode:(TLBaseServiceErrorCode)errorCode backups:(NSArray<TLBackupInfo *> *)backups {
    DDLogVerbose(@"%@ onGetAllBackupsWithErrorCode: %d backups: %lu", LOG_TAG, errorCode, backups.count);

    [self.service onGetAllBackupsWithErrorCode:errorCode backups:backups];
}

- (void)onDeleteBackupsWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteBackupsWithErrorCode: %d", LOG_TAG, errorCode);

    [self.service onDeleteBackupsWithErrorCode:errorCode];
}

- (void)onTerminateVerifyWithReport:(nonnull TLVerifyReport *)report {
    DDLogVerbose(@"%@ onTerminateVerifyWithReport: %@", LOG_TAG, report);

    [self.service onTerminateVerifyWithReport:report];
}

@end


//
// Implementation: BackupService
//

#undef LOG_TAG
#define LOG_TAG @"BackupService"

@implementation BackupService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<BackupServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);

    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _backupServiceDelegate = [[BackupServiceDelegate alloc] initWithService:self];
        _mnemonicCodeUtils = [[MnemonicCodeUtils alloc] init];
        _supportedSchemaIds = @[
            TLSpaceSettings.SCHEMA_ID,
            TLSpace.SCHEMA_ID,
            TLProfile.SCHEMA_ID,
            TLContact.SCHEMA_ID,
            TLCallReceiver.SCHEMA_ID,
            TLGroup.SCHEMA_ID,
        ];
        
        self.twinmeContextDelegate = [[BackupServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    
    return self;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);

    self.isTwinlifeReady = YES;
    self.backupService = self.twinmeContext.getBackupService;
    
    [self.backupService addDelegate:self.backupServiceDelegate];
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);

    [self.backupService removeDelegate:self.backupServiceDelegate];
    [super dispose];
}

- (void)generateWords {
    DDLogVerbose(@"%@ generateWords", LOG_TAG);
    
    NSData *password = [NSData secureRandomWithLength:16];
    
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        self.passwordWords = [self.mnemonicCodeUtils toMnemonicWithEntropy:password];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<BackupServiceDelegate>)self.delegate onWordsGeneratedWithWords:self.passwordWords];
        });
    });
}

- (void)startBackupWithPassword:(nullable NSData *)password {
    DDLogVerbose(@"%@ startBackupWithPassword: %@", LOG_TAG, password);
    
    if (!password && !self.passwordWords) {
        //TODO BPK handle error
        DDLogError(@"%@ password is nil and generateWords wasn't call before startBackupWithPassword, aborting", LOG_TAG);
        return;
    }
    
    if (password) {
        self.passwordWords = [self.mnemonicCodeUtils toMnemonicWithEntropy:password];
    }
    
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        [self.backupService backupWithPassword:[self.mnemonicCodeUtils toEntropyWithWords:self.passwordWords] supportedSchemaIds:self.supportedSchemaIds];
    });
}

- (void)startRestoreWithPassword:(nonnull NSData *)password backupPath:(nonnull NSString *)backupPath inPlace:(BOOL)inPlace {
    DDLogVerbose(@"%@ startRestoreWithPassword: %@ backupPath: %@ inPlace: %@", LOG_TAG, password, backupPath, inPlace ? @"YES":@"NO");
   
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        [self.backupService restoreWithPassword:password backupPath:backupPath supportedSchemaIds:self.supportedSchemaIds inPlace:[NSNumber numberWithBool:inPlace] twinlifeContext:self.twinmeContext];
    });
}

- (void)startRestoreWithPassword:(nonnull NSData *)password backupPath:(nonnull NSString *)backupPath {
    DDLogVerbose(@"%@ startRestoreWithPassword: %@ backupPath: %@", LOG_TAG, password, backupPath);
   
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        [self.backupService restoreWithPassword:password backupPath:backupPath supportedSchemaIds:self.supportedSchemaIds inPlace:nil twinlifeContext:self.twinmeContext];
    });
}

- (void)startVerifyWithPassword:(nonnull NSData *)password backupPath:(nonnull NSString *)backupPath {
    DDLogVerbose(@"%@ startVerifyWithPassword: %@ backupPath: %@", LOG_TAG, password, backupPath);
   
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        [self.backupService verifyWithPassword:password backupPath:backupPath supportedSchemaIds:self.supportedSchemaIds];
    });
}

- (void)commitRestore {
    DDLogVerbose(@"%@ commitRestore", LOG_TAG);
    
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        [self.backupService commitRestore];
    });
}

- (void)cancelRestore {
    DDLogVerbose(@"%@ cancelRestore", LOG_TAG);
    
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
            [self.backupService cancelRestore];
    });
}

- (void)getAllBackups {
    DDLogVerbose(@"%@ getAllBackups", LOG_TAG);
    
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
            [self.backupService getAllBackups];
    });
}

- (void)deleteBackups {
    DDLogVerbose(@"%@ deleteBackups", LOG_TAG);
    
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
            [self.backupService deleteBackups];
    });
}

- (void)checkFileCompatibilityWithBackupPath:(nonnull NSString *)backupPath {
    DDLogVerbose(@"%@ checkFileCompatibilityWithBackupPath:%@", LOG_TAG, backupPath);
    
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        TLBackupServiceErrorCode result = [self.backupService checkFileCompatibilityWithBackupPath:backupPath];
        
        if ([(id)self.delegate respondsToSelector:@selector(onCheckFileCompatibilityWithResult:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<BackupServiceDelegate>)self.delegate onCheckFileCompatibilityWithResult:result];
            });
        }
    });
}

// TLBackupService delegate callbacks

- (void)onBackupStateChangeWithBackupId:(nonnull NSUUID *)backupId state:(TLBackupState)state {
    self.backupState = state;
    
    if ([(id)self.delegate respondsToSelector:@selector(onBackupStateChangeWithBackupId:state:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<BackupServiceDelegate>)self.delegate onBackupStateChangeWithBackupId:backupId state:state];
        });
    }
}


- (void)onBackupErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode {
    self.errorCode = backupErrorCode;
    
    if ([(id)self.delegate respondsToSelector:@selector(onBackupErrorWithBackupErrorCode:baseErrorCode:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<BackupServiceDelegate>)self.delegate onBackupErrorWithBackupErrorCode:backupErrorCode baseErrorCode:baseErrorCode];
        });
    }}

- (void)onRestoreStateChangeWithState:(TLRestoreState)state restoreContent:(nullable TLRestoreContent *)restoreContent {
    self.restoreState = state;
    
    RestoreReport *restoreReport;
    
    if (restoreContent) {
        restoreReport = [[RestoreReport alloc] initWithRestoreContent:restoreContent];
    }
    
    if ([(id)self.delegate respondsToSelector:@selector(onRestoreStateChangeWithState:restoreReport:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<BackupServiceDelegate>)self.delegate onRestoreStateChangeWithState:state restoreReport:restoreReport];
        });
    }
}

- (void)onTerminateBackupWithBackupId:(nonnull NSUUID *)backupId backupFilePath:(nullable NSString *)backupFilePath stats:(nonnull NSDictionary<NSUUID *, NSNumber *> *)stats done:(BOOL)done {
    self.backupId = backupId;
    self.backupFilePath = backupFilePath;
    self.backupState = TLBackupStateTerminated;
    
    if ([(id)self.delegate respondsToSelector:@selector(onTerminateBackupWithBackupId:backupFilePath:stats:done:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<BackupServiceDelegate>)self.delegate onTerminateBackupWithBackupId:self.backupId backupFilePath:self.backupFilePath stats:stats done:done];
        });
    }
    
    //TODO BKP: stop service?
}

- (void)onTerminateRestoreWithTerminateReason:(TLBackupServiceTerminateReason)terminateReason {
    self.restoreState = TLRestoreStateTerminated;
    self.terminateReason = terminateReason;
    
    if ([(id)self.delegate respondsToSelector:@selector(onTerminateRestoreWithTerminateReason:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<BackupServiceDelegate>)self.delegate onTerminateRestoreWithTerminateReason:terminateReason];
        });
    }
    //TODO BKP: stop service?
}

- (void)onRestoreErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode {
    self.errorCode = backupErrorCode;
    
    if ([(id)self.delegate respondsToSelector:@selector(onRestoreErrorWithBackupErrorCode:baseErrorCode:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<BackupServiceDelegate>)self.delegate onRestoreErrorWithBackupErrorCode:backupErrorCode baseErrorCode:baseErrorCode];
        });
    }
}

- (void)onBackupHeaderInfoWithHeaderInfo:(nonnull TLBackupHeaderInfo *)headerInfo lastBackupId:(nullable NSUUID *)lastBackupId lastBackupTimestamp:(int64_t)lastBackupTimestamp {
    self.backupHeaderInfo = headerInfo;
    
    if ([(id)self.delegate respondsToSelector:@selector(onBackupHeaderInfoWithHeaderInfo:lastBackupId:lastBackupTimestamp:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<BackupServiceDelegate>)self.delegate onBackupHeaderInfoWithHeaderInfo:self.backupHeaderInfo lastBackupId:lastBackupId lastBackupTimestamp:lastBackupTimestamp];
        });
    }
}

- (void)onGetAllBackupsWithErrorCode:(TLBaseServiceErrorCode)errorCode backups:(NSArray<TLBackupInfo *> *)backups {
    if ([(id)self.delegate respondsToSelector:@selector(onGetAllBackupsWithErrorCode:backups:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<BackupServiceDelegate>)self.delegate onGetAllBackupsWithErrorCode:errorCode backups:backups];
        });
    }
}

- (void)onDeleteBackupsWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    if ([(id)self.delegate respondsToSelector:@selector(onDeleteBackupsWithErrorCode:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<BackupServiceDelegate>)self.delegate onDeleteBackupsWithErrorCode:errorCode];
        });
    }
}

- (void)onTerminateVerifyWithReport:(nonnull TLVerifyReport *)report {
    
    RestoreReport *restoreReport = [[RestoreReport alloc] initWithVerifyReport:report];
    
    if ([(id)self.delegate respondsToSelector:@selector(onTerminateVerifyWithReport:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<BackupServiceDelegate>)self.delegate onTerminateVerifyWithReport:restoreReport];
        });
    }
}

@end
