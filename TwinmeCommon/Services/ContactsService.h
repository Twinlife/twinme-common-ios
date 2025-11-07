/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: ContactsServiceDelegate
//

@protocol ContactsServiceDelegate <AbstractTwinmeDelegate, ContactTwinmeDelegate, ContactListTwinmeDelegate, CurrentSpaceTwinmeDelegate, SpaceTwinmeDelegate>
@optional

- (void)onCreateContact:(nonnull TLContact *)contact avatar:(nonnull UIImage *)avatar;

- (void)onDeleteContact:(nonnull NSUUID *)contactId;

@end

//
// Interface: ContactsService
//

@interface ContactsService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <ContactsServiceDelegate>)delegate;

- (void)getContacts;

- (void)findContactsByName:(nonnull NSString *)name;

- (BOOL)isGetContactsDone;

@end
