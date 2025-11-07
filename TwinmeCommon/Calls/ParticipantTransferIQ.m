/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "ParticipantTransferIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * Participant transfer IQ sent to a call group member to indicate that a transfer is taking place.
 * Upon reception, the member which sent this IQ will be replaced by the member whose ID is found in the payload.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"800fd629-83c4-4d42-8910-1b4256d19eb8",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"ParticipantInfoIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"memberId", "type":"String"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: ParticipantTransferIQSerializer
//

@implementation ParticipantTransferIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[ParticipantTransferIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    ParticipantTransferIQ *participantTransferIQ = (ParticipantTransferIQ *)object;
    [encoder writeString:participantTransferIQ.memberId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSString *memberId = [decoder readString];

    return [[ParticipantTransferIQ alloc] initWithSerializer:self requestId:iq.requestId memberId:memberId];
}

@end

//
// Implementation: ParticipantTransferIQ
//

@implementation ParticipantTransferIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId memberId:(nonnull NSString *)memberId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _memberId = memberId;
    }
    return self;
}

@end
