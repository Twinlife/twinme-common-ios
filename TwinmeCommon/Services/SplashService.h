/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

typedef enum {
    ApplicationStateTypeStarting,
    ApplicationStateTypeUpgrading,
    ApplicationStateTypeReady,
    ApplicationStateTypeDisabled,
    ApplicationStateTypeMigration
} ApplicationStateType;

//
// Protocol: SplashServiceDelegate
//

@protocol SplashServiceDelegate <AbstractTwinmeDelegate>

- (void)onState:(ApplicationStateType)state;

@optional

- (void)onPremiumImage:(nonnull UIImage *)image;

@end

//
// Interface: SplashService
//

@interface SplashService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext subscriptionTwincodeId:(nullable NSUUID *)subscriptionTwincodeId delegate:(nonnull id<SplashServiceDelegate>)delegate;

@end
