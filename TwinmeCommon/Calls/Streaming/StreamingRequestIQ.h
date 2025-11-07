/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLBinaryPacketIQ.h>

//
// Interface: StreamingRequestIQSerializer
//

@interface StreamingRequestIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: StreamingRequestIQ
//

@interface StreamingRequestIQ : TLBinaryPacketIQ

@property (readonly) int64_t ident;
@property (readonly) int64_t offset;
@property (readonly) int64_t length;
@property (readonly) int64_t playerPosition;
@property (readonly) int64_t timestamp;
@property (readonly) int lastRTT;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId ident:(int64_t)ident offset:(int64_t)offset length:(int64_t)length playerPosition:(int64_t)playerPosition timestamp:(int64_t)timestamp lastRTT:(int)lastRTT;

@end
