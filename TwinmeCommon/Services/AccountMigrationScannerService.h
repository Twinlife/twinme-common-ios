/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "AbstractTwinmeService.h"

@class TLAccountMigration;
@class TLProfile;
@class TLTwinmeContext;
@class TLTwincodeOutbound;
@class TLTwincodeURI;

//
// Protocol: AccountMigrationScannerServiceDelegate
//

@protocol AccountMigrationScannerServiceDelegate <AbstractTwinmeDelegate, TwincodeTwinmeDelegate>

- (void)onGetDefaultProfile:(nonnull TLProfile *)profile;

- (void)onGetDefaultProfileNotFound;

- (void)onCreateAccountMigration:(nullable TLAccountMigration *)accountMigration twincodeUri:(nonnull TLTwincodeURI *)twincodeUri;

- (void)onUpdateAccountMigration:(nonnull TLAccountMigration *)accountMigration;

- (void)onDeleteAccountMigration:(nonnull NSUUID *)accountMigrationId;

- (void)onAccountMigrationConnected:(nonnull NSUUID *)accountMigrationId;

- (void)onHasRelations;
@end

//
// Interface: AccountMigrationScannerService
//

@interface AccountMigrationScannerService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<AccountMigrationScannerServiceDelegate>)delegate;

- (void)getTwincodeOutboundWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId;

- (void)bindAccountMigrationWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound;

- (void)createAccountMigration;

- (void)parseURIWithUri:(nonnull NSURL *)uri withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeURI *_Nullable twincodeUri))block;

- (void)dispose;

@end
