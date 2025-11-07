/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLBinaryPacketIQ.h>

//
// Interface: StreamingDataIQSerializer
//

@interface StreamingDataIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: StreamingDataIQ
//

@interface StreamingDataIQ : TLBinaryPacketIQ

@property (readonly) int64_t ident;
@property (readonly) int64_t offset;
@property (readonly) int64_t streamerPosition;
@property (readonly) int streamerLatency;
@property (readonly) int64_t timestamp;
@property (readonly, nullable) NSData* data;
@property (readonly) int32_t start;
@property (readonly) int32_t length;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId ident:(int64_t)ident offset:(int64_t)offset streamerPosition:(int64_t)streamerPosition timestamp:(int64_t)timestamp streamerLatency:(int)streamerLatency data:(nullable NSData*)data start:(int32_t)start length:(int32_t)length;

@end
