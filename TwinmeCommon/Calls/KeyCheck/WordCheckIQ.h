/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Twinlife/TLBinaryPacketIQ.h>
#import "WordCheckResult.h"

//
// Interface: WordCheckIQSerializer
//

@interface WordCheckIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: WordCheckIQ
//

@interface WordCheckIQ : TLBinaryPacketIQ

@property (readonly, nonnull) WordCheckResult *result;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId wordCheckResult:(nonnull WordCheckResult *)wordCheckResult;

@end
