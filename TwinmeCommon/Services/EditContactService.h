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
#import "ShowContactService.h"

//
// Protocol: EditContactServiceDelegate
//

@class TLContact;
@class TLTwinmeContext;

@protocol EditContactServiceDelegate <ShowContactServiceDelegate>

@end

//
// Interface: EditContactService
//

@interface EditContactService : ShowContactService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<EditContactServiceDelegate>)delegate;

- (void)updateContactWithContact:(nonnull TLContact *)contact contactName:(nonnull NSString *)contactName contactDescription:(nullable NSString *)contactDescription;

@end
