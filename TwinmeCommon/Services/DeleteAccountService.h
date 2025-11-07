/*
 *  Copyright (c) 2018 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: DeleteAccountServiceDelegate
//

@protocol DeleteAccountServiceDelegate <AbstractTwinmeDelegate>
@optional

- (void)onDeleteAccount;

@end

//
// Interface: DeleteAccountService
//

@interface DeleteAccountService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <DeleteAccountServiceDelegate>)delegate;

- (void)deleteAccount;

@end
