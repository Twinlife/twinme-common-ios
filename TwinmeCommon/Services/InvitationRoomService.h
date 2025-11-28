/*
 *  Copyright (c) 2021-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: InvitationRoomServiceDelegate
//

@protocol InvitationRoomServiceDelegate <AbstractTwinmeDelegate, ContactTwinmeDelegate, ContactListTwinmeDelegate>

@optional

- (void)onSendTwincodeToContacts;

- (void)onGetTwincodeURI:(nonnull TLTwincodeURI *)uri;

@end

//
// Interface: InvitationRoomService
//

@interface InvitationRoomService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <InvitationRoomServiceDelegate>)delegate;

- (void)initWithRoom:(nonnull TLContact *)room;

- (void)getContacts;

- (void)findContactsByName:(nonnull NSString *)name;

- (void)inviteContactToRoom:(nonnull NSArray *)contacts room:(nonnull TLContact *)room;

@end
