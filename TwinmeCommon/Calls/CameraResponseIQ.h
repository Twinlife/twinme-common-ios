/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLBinaryPacketIQ.h>
#import <Twinlife/TLBaseService.h>

//
// Interface: CameraResponseIQSerializer
//

@interface CameraResponseIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: ParticipantInfoIQ
//

@interface CameraResponseIQ : TLBinaryPacketIQ

@property (readonly) TLBaseServiceErrorCode errorCode;
@property (readonly) int64_t cameraBitmap;
@property (readonly) int activeCamera;
@property (readonly) int minScale;
@property (readonly) int maxScale;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode cameraBitmap:(int64_t)cameraBitmap activeCamera:(int)activeCamera minScale:(int)minScale maxScale:(int)maxScale;

@end
