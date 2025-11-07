/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Twinlife/TLBinaryPacketIQ.h>

//
// Interface: KeyCheckInitiateIQSerializer
//

@interface KeyCheckInitiateIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: KeyCheckInitiateIQ
//

@interface KeyCheckInitiateIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSLocale *locale;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId locale:(nonnull NSLocale *)locale;

@end
