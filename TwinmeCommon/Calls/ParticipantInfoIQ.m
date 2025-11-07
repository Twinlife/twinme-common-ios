/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "ParticipantInfoIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * Participant info IQ sent to a call group member to share the participant name and picture.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"a8aa7e0d-c495-4565-89bb-0c5462b54dd0",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"ParticipantInfoIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"memberId", "type":"String"},
 *     {"name":"name", "type":"String"},
 *     {"name":"description", [null, "type":"String"}],
 *     {"name":"avatar", [null, "type":"bytes"]}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: ParticipantInfoIQSerializer
//

@implementation ParticipantInfoIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[ParticipantInfoIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    ParticipantInfoIQ *participantInfoIQ = (ParticipantInfoIQ *)object;
    [encoder writeString:participantInfoIQ.memberId];
    [encoder writeString:participantInfoIQ.name];
    [encoder writeOptionalString:participantInfoIQ.memberDescription];
    [encoder writeOptionalData:participantInfoIQ.thumbnail];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSString *memberId = [decoder readString];
    NSString *name = [decoder readString];
    NSString *memberDescription = [decoder readOptionalString];
    NSData *imageData = [decoder readOptionalData];

    return [[ParticipantInfoIQ alloc] initWithSerializer:self requestId:iq.requestId memberId:memberId name:name memberDescription:memberDescription thumbnail:imageData];
}

@end

//
// Implementation: ParticipantInfoIQ
//

@implementation ParticipantInfoIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId memberId:(nonnull NSString *)memberId name:(nonnull NSString *)name memberDescription:(nullable NSString *)memberDescription thumbnail:(nullable NSData *)thumbnail {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _memberId = memberId;
        _name = name;
        _memberDescription = memberDescription;
        _thumbnail = thumbnail;
    }
    return self;
}

@end
