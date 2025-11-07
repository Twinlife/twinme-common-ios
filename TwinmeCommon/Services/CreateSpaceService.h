/*
 *  Copyright (c) 2019-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: CreateSpaceServiceDelegate
//

@protocol CreateSpaceServiceDelegate <AbstractTwinmeDelegate>

- (void)onCreateSpace:(nonnull TLSpace *)space;

@end

//
// Interface: CreateSpaceService
//

@interface CreateSpaceService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <CreateSpaceServiceDelegate>)delegate;

- (void)createSpace:(nonnull TLSpaceSettings *)spaceSettings spaceAvatar:(nonnull UIImage *)spaceAvatar spaceLargeAvatar:(nonnull UIImage *)spaceLargeAvatar nameProfile:(nonnull NSString *)nameProfile descriptionProfile:(nullable NSString *)descriptionProfile avatar:(nonnull UIImage *)avatar largeAvatar:(nonnull UIImage *)largeAvatar contacts:(nonnull NSMutableArray<id<TLOriginator>> *)contacts conversationBackgroundLightImage:(nullable UIImage *)conversationBackgroundLightImage conversationBackgroundLightLargeImage:(nullable UIImage *)conversationBackgroundLightLargeImage conversationBackgroundDarkImage:(nullable UIImage *)conversationBackgroundDarkImage conversationBackgroundDarkLargeImage:(nullable UIImage *)conversationBackgroundDarkLargeImage;

@end
