/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "AbstractTwinmeService.h"
#import "AbstractTwinmeService+Protected.h"
#import <Twinlife/TLBackupService.h>

@class TLRestoreContent;
@class TLRestoreContentStats;

//
// Interface: RestoreReport
//

@interface RestoreReport : NSObject

@property (nonnull, readonly) TLRestoreContentStats *contacts;
@property (nonnull, readonly) TLRestoreContentStats *groups;
@property (nonnull, readonly) TLRestoreContentStats *profiles;
@property (nonnull, readonly) TLRestoreContentStats *clickToCall;

- (BOOL)isRestoreUpToDate;

@end

//
// Protocol: BackupServiceDelegate
//

@protocol BackupServiceDelegate <AbstractTwinmeDelegate>

- (void)onBackupHeaderInfoWithHeaderInfo:(nonnull TLBackupHeaderInfo *)headerInfo lastBackupId:(nullable NSUUID *)lastBackupId lastBackupTimestamp:(int64_t)lastBackupTimestamp;

- (void)onBackupStateChangeWithBackupId:(nonnull NSUUID *)backupId state:(TLBackupState)state;

- (void)onTerminateBackupWithBackupId:(nonnull NSUUID *)backupId backupFilePath:(nullable NSString *)backupFilePath stats:(nonnull NSDictionary<NSUUID *, NSNumber *> *)stats done:(BOOL)done;

- (void)onRestoreStateChangeWithState:(TLRestoreState)state restoreReport:(nullable RestoreReport *)restoreReport;

- (void)onTerminateRestoreWithTerminateReason:(TLBackupServiceTerminateReason)terminateReason;

- (void)onBackupErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode;

- (void)onRestoreErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode;

- (void)onWordsGeneratedWithWords:(nonnull NSArray<NSString *> *)words;

- (void)onGetAllBackupsWithErrorCode:(TLBaseServiceErrorCode)errorCode backups:(nonnull NSArray<TLBackupInfo *> *)backups;

- (void)onDeleteBackupsWithErrorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onTerminateVerifyWithReport:(nonnull RestoreReport *)report;

- (void)onCheckFileSignatureWithResult:(BOOL)result;
@end

//
// Interface BackupService
//

@interface BackupService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<BackupServiceDelegate>)delegate;

- (void)generateWords;

/// Starts the backup process. password can be nil if generateWords was called first
- (void)startBackupWithPassword:(nullable NSData *)password;

/// Starts the restore process. Restore will be in-place if the current account is the same as the one in the backup.
- (void)startRestoreWithPassword:(nonnull NSData *)password backupPath:(nonnull NSString *)backupPath;

- (void)startRestoreWithPassword:(nonnull NSData *)password backupPath:(nonnull NSString *)backupPath inPlace:(BOOL)inPlace;

- (void)startVerifyWithPassword:(nonnull NSData *)password backupPath:(nonnull NSString *)backupPath;

- (void)commitRestore;

- (void)cancelRestore;

- (void)getAllBackups;

- (void)deleteBackups;

- (void)checkFileSignatureWithBackupPath:(nonnull NSString *)backupPath;
@end
