/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: ShareProfileServiceDelegate
//

@class TLProfile;
@class TLTwinmeContext;
@class TLTwincodeURI;

@protocol ShareProfileServiceDelegate <AbstractTwinmeDelegate>

- (void)onGetDefaultProfile:(nonnull TLProfile *)profile;

- (void)onGetDefaultProfileNotFound;

- (void)onGetTwincodeURI:(nonnull TLTwincodeURI *)uri;

- (void)onCreateContact:(nonnull TLContact *)contact;

@end

//
// Interface: ShareProfileService
//

@interface ShareProfileService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<ShareProfileServiceDelegate>)delegate;

- (void)changeProfileTwincode:(nonnull TLProfile *)profile;

- (void)verifyAuthenticateWithURI:(nonnull NSURL *)uri withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLContact *_Nullable contact))block;

@end
