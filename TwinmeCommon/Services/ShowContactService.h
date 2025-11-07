/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import "AbstractTwinmeService.h"

@class TLContact;
@class TLTwinmeContext;

//
// Protocol: ShowContactServiceDelegate
//

@protocol ShowContactServiceDelegate <AbstractTwinmeDelegate, ContactTwinmeDelegate>

@end

//
// Interface: ShowContactService
//

@interface ShowContactService : AbstractTwinmeService

@property (nonatomic, nullable) TLContact *contact;
@property (nonatomic) int work;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<ShowContactServiceDelegate>)delegate;

- (void)initWithContact:(nonnull TLContact *)contact;

- (void)deleteContact:(nonnull TLContact *)contact;

- (void)createAuthenticateURIWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeURI *_Nullable twincodeUri))block;

- (void)verifyAuthenticateWithURI:(nonnull NSURL *)uri withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLContact *_Nullable contact))block;

@end
