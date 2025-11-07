/*
 *  Copyright (c) 2022, 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: CallParticipantServiceDelegate
//

@protocol CallParticipantServiceDelegate <AbstractTwinmeDelegate, ContactListTwinmeDelegate>

@end

//
// Interface: CallParticipantService
//

@interface CallParticipantService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <CallParticipantServiceDelegate>)delegate;

- (void)getContacts:(nonnull TLSpace *)space;

- (void)findContactsByName:(nonnull NSString *)name space:(nonnull TLSpace *)space;

@end
