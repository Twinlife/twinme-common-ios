/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"

#import <Twinlife/TLConversationService.h>

//
// Protocol: ShareServiceDelegate
//

@class TLProfile;
@class TLContact;
@class TLGroup;
@protocol TLConversation;
@protocol TLGroupConversation;
@class TLTwinmeContext;

//
// Interface: ShareServiceDelegate
//

@protocol ShareServiceDelegate <AbstractTwinmeDelegate, ContactTwinmeDelegate, ContactListTwinmeDelegate, GroupListTwinmeDelegate, GroupTwinmeDelegate, CurrentSpaceTwinmeDelegate>

- (void)onCreateContact:(nonnull TLContact *)contact avatar:(nonnull UIImage *)avatar;

- (void)onGetConversation:(nonnull id<TLConversation>)conversation;

@end

//
// Interface: ShareService
//

@interface ShareService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<ShareServiceDelegate>)delegate;

- (void)getConversationWithContact:(nonnull TLContact *)contact;

- (void)getConversationWithGroup:(nonnull TLGroup *)group;

- (void)forwardDescriptor:(nonnull TLDescriptorId *)descriptorId copyAllowed:(BOOL)copyAllowed;

- (void)pushMessage:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed;

- (void)pushFileWithPath:(nonnull NSString *)path type:(TLDescriptorType)type toBeDeleted:(BOOL)toBeDeleted copyAllowed:(BOOL)copyAllowed;

- (void)findContactsAndGroupsByName:(nonnull NSString *)name space:(nonnull TLSpace *)space;

- (void)getContactsAndGroups:(nonnull TLSpace *)space;

- (void)dispose;

@end
