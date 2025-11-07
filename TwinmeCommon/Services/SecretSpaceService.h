/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"

@class TLSpace;

//
// Protocol: SecretSpaceServiceDelegate
//

@protocol SecretSpaceServiceDelegate <AbstractTwinmeDelegate>

- (void)onGetSpaces:(nonnull NSArray *)spaces;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

@end

//
// Interface: SecretSpaceService
//

@interface SecretSpaceService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <SecretSpaceServiceDelegate>)delegate;

- (void)findSecretSpaceByName:(nonnull NSString *)name;

- (void)setCurrentSpace:(nonnull TLSpace *)space;

@end
