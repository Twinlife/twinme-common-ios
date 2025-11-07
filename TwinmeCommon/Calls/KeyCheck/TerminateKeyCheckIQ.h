/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Twinlife/TLBinaryPacketIQ.h>

//
// Interface: ParticipantInfoIQSerializer
//

@interface TerminateKeyCheckIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TerminateKeyCheckIQ
//

@interface TerminateKeyCheckIQ : TLBinaryPacketIQ

@property (readonly) BOOL result;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId result:(BOOL)result;

@end
