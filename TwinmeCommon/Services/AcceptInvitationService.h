/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"
#import <Twinlife/TLTwincode.h>

@class TLContact;
@class TLTwinmeContext;
@class TLDescriptorId;
@class TLGroup;
@class TLSpace;

//
// Protocol: AcceptInvitationServiceDelegate
//

@protocol AcceptInvitationServiceDelegate <AbstractTwinmeDelegate>

- (void)onLocalTwincode;

- (void)onExistingContacts:(nonnull NSArray<TLContact *> *)contacts;

- (void)onCreateContact:(nonnull TLContact *)contact;

- (void)onParseTwincodeURI:(TLBaseServiceErrorCode)errorCode uri:(nullable TLTwincodeURI *)uri;

- (void)onGetDefaultProfile:(nonnull TLProfile *)profile;

- (void)onMoveContact:(nonnull TLContact *)contact;

- (void)onGetDefaultSpace:(nonnull TLSpace *)space;

- (void)onGetDefaultProfileNotFound;

- (void)onDeleteDescriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors;

- (void)onDeleteNotification:(nonnull NSUUID *)notificationId;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;
@end

//
// Interface: AcceptInvitationService
//

@interface AcceptInvitationService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<AcceptInvitationServiceDelegate>)delegate uri:(nonnull NSURL *)uri contactId:(nullable NSUUID *)contactId groupId:(nullable NSUUID *)groupId descriptorId:(nullable TLDescriptorId *)descriptorId trustMethod:(TLTrustMethod)trustMethod;

- (void)createContactWithProfile:(nonnull TLProfile *)profile space:(nonnull TLSpace *)space;

- (void)deleteDescriptor:(nonnull TLDescriptorId *)descriptorId;

- (void)deleteNotification:(nonnull TLNotification *)notification;

- (void)getDefaultProfile;

- (void)setCurrentSpace:(nonnull TLSpace *)space;

@end
