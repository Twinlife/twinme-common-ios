/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Twinlife/TLBinaryPacketIQ.h>

//
// Interface: TwincodeUriIQSerializer
//

@interface TwincodeUriIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TwincodeUriIQ
//

@interface TwincodeUriIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *uri;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId uri:(nonnull NSString *)uri;

@end
