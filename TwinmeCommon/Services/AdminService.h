/*
 *  Copyright (c) 2018-2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

@class TLTwinmeContext;

//
// Interface: AdminService
//

@interface AdminService : NSObject

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext;

@end
