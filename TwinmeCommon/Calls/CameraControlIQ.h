/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLBinaryPacketIQ.h>
#import "CallConnection.h"

//
// Interface: CameraControlIQSerializer
//

@interface CameraControlIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: CameraControlIQ
//

@interface CameraControlIQ : TLBinaryPacketIQ

@property (readonly) CameraControlMode mode;
@property (readonly) int camera;
@property (readonly) int scale;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId mode:(CameraControlMode)mode camera:(int)camera scale:(int)scale;

@end
