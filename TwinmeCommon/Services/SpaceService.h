/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

@class TLSpace;
@class TLProfile;
@class TLContact;
@class TLGroup;

//
// Protocol: SpaceServiceDelegate
//

@protocol SpaceServiceDelegate <AbstractTwinmeDelegate, CurrentSpaceTwinmeDelegate, ContactListTwinmeDelegate, GroupListTwinmeDelegate, SpaceListTwinmeDelegate, ContactTwinmeDelegate, GroupTwinmeDelegate>

- (void)onCreateSpace:(nonnull TLSpace *)space;

- (void)onGetCurrentSpace:(nonnull TLSpace *)space;

- (void)onUpdateProfile:(nonnull TLProfile *)profile;

@optional

- (void)onGetSpacesNotifications:(nonnull NSDictionary<NSUUID *, TLNotificationServiceNotificationStat *> *)spacesNotifications;

- (void)onEmptySpace:(nonnull TLSpace *)space empty:(BOOL)empty;

@end

//
// Interface: SpaceService
//

@interface SpaceService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <SpaceServiceDelegate>)delegate;

- (void)getSpaces;

- (void)findSpaceByName:(nonnull NSString *)name;

- (void)moveContactsInSpace:(nonnull NSMutableArray *)contacts space:(nonnull TLSpace *)space;

- (void)setCurrentSpace:(nonnull TLSpace *)space;

- (void)deleteSpace:(nonnull TLSpace *)space;

- (void)moveContactToSpace:(nonnull TLSpace *)space contact:(nonnull TLContact *)contact;

- (void)moveGroupToSpace:(nonnull TLSpace *)space group:(nonnull TLGroup *)group;

- (void)getAllContacts;

- (void)isEmptySpace:(nonnull TLSpace *)space;

- (void)findContactsByName:(nonnull NSString *)name;

@end

