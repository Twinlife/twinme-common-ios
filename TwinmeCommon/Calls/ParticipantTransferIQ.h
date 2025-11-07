/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Twinlife/TLBinaryPacketIQ.h>

//
// Interface: ParticipantTransferIQSerializer
//

@interface ParticipantTransferIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: ParticipantTransferIQ
//

@interface ParticipantTransferIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *memberId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId memberId:(nonnull NSString *)memberId;

@end
