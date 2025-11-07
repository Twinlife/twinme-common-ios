/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Twinlife/TLBinaryPacketIQ.h>
#import <Twinlife/TLBaseService.h>

//
// Interface: OnKeyCheckInitiateIQSerializer
//

@interface OnKeyCheckInitiateIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: OnKeyCheckInitiateIQ
//

@interface OnKeyCheckInitiateIQ : TLBinaryPacketIQ

@property (readonly) TLBaseServiceErrorCode errorCode;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode;

@end
