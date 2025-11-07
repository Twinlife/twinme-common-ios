/*
 *  Copyright (c) 2017-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: CreateProfileServiceDelegate
//

@class TLProfile;
@class TLSpace;
@class TLTwinmeContext;

@protocol CreateProfileServiceDelegate <AbstractTwinmeDelegate>

- (void)onCreateProfile:(nonnull TLProfile *)profile;

@end

//
// Interface: CreateProfileService
//

@interface CreateProfileService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<CreateProfileServiceDelegate>)delegate;

- (void)createProfile:(nonnull NSString *)name profileDescription:(nullable NSString *)profileDescription avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar nameSpace:(nullable NSString *)nameSpace createSpace:(BOOL)createSpace;

- (void)setCurrentSpace;

- (void)setLevel:(nonnull NSString *)name;

@end
