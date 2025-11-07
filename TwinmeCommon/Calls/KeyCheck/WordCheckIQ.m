/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "WordCheckIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * Result of a word check IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"949a64db-deb4-4266-9a2a-b680c80ecc07",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"WordCheckIQ",
 *  "namespace":"org.twinlife.schemas.calls.keycheck",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"wordIndex", "type":"int"},
 *     {"name":"errorCode", "type":"enum"}
 *  ]
 * }
 *
 * </pre>
 */


//
// Implementation: WordCheckIQSerializer
//

@implementation WordCheckIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[WordCheckIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    WordCheckIQ *wordCheckIQ = (WordCheckIQ *)object;
    [encoder writeInt:wordCheckIQ.result.wordIndex];
    [encoder writeBoolean:wordCheckIQ.result.ok];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int wordIndex = [decoder readInt];
    BOOL ok = [decoder readBoolean];
    
    return [[WordCheckIQ alloc] initWithSerializer:self requestId:iq.requestId wordCheckResult:[[WordCheckResult alloc] initWithWordIndex:wordIndex ok:ok]];
}

@end

//
// Implementation: WordCheckIQ
//

@implementation WordCheckIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId wordCheckResult:(nonnull WordCheckResult *)wordCheckResult {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _result = wordCheckResult;
    }
    return self;
}

@end
