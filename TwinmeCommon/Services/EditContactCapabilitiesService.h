/*
 *  Copyright (c) 2021-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: EditContactCapabilitiesService
//

@class TLContact;
@class TLTwinmeContext;

@protocol EditContactCapabilitiesServiceDelegate <AbstractTwinmeDelegate, ContactTwinmeDelegate>

@end

//
// Interface: EditContactCapabilitiesService
//

@interface EditContactCapabilitiesService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<EditContactCapabilitiesServiceDelegate>)delegate;

- (void)updateIdentityWithContact:(nonnull TLContact *)contact identityCapabilities:(nullable TLCapabilities *)identityCapabilities;

@end
