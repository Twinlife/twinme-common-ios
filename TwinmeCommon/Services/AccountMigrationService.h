/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "AbstractTwinmeService.h"
#import <Twinlife/TLAccountMigrationService.h>

@class TLQueryInfo;
@class TLAccountMigrationVersion;

@protocol AccountMigrationServiceDelegate <AbstractTwinmeDelegate>

- (void)onUpdateMigrationStateWithMigrationId:(nullable NSUUID *)migrationId startTime:(int64_t)startTime state:(TLAccountMigrationState)state status:(nullable TLAccountMigrationStatus *)status peerInfo:(nullable TLQueryInfo *)peerInfo localInfo:(nullable TLQueryInfo *)localInfo peerVersion:(nullable TLAccountMigrationVersion *)peerVersion;

- (void)onErrorWithErrorCode:(TLAccountMigrationErrorCode)errorCode;

@end

@interface AccountMigrationService : AbstractTwinmeService

@property (atomic, nullable, weak) id<AccountMigrationServiceDelegate> migrationObserver;

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext;

- (void)incomingMigrationWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId accountMigration:(nonnull TLAccountMigration *)accountMigration;

- (void)outgoingMigrationWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId;

- (void)startMigration;

- (void)cancelMigration;

- (void)getMigrationState;
@end
