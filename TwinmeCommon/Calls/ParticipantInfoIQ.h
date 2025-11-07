/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLBinaryPacketIQ.h>

//
// Interface: ParticipantInfoIQSerializer
//

@interface ParticipantInfoIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: ParticipantInfoIQ
//

@interface ParticipantInfoIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *memberId;
@property (readonly, nonnull) NSString *name;
@property (readonly, nullable) NSString *memberDescription;
@property (readonly, nullable) NSData *thumbnail;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId memberId:(nonnull NSString *)memberId name:(nonnull NSString *)name memberDescription:(nullable NSString *)memberDescription thumbnail:(nullable NSData *)thumbnail;

@end
