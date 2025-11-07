/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "StreamingRequestIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * A request to ask a data block for a streaming content.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"4fab57a3-6c24-4318-b71d-22b60807cbc5",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"StreamingRequestIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"ident", "type":"long"},
 *     {"name":"offset", "type":"long"},
 *     {"name":"length", "type":"long"},
 *     {"name":"timestamp", "type":"long"},
 *     {"name":"playerPosition", "type":"long"},
 *     {"name":"lastRTT", "type":"int"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: StreamingRequestIQSerializer
//

@implementation StreamingRequestIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[StreamingRequestIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    StreamingRequestIQ *streamingRequestIQ = (StreamingRequestIQ *)object;
    [encoder writeLong:streamingRequestIQ.ident];
    [encoder writeLong:streamingRequestIQ.offset];
    [encoder writeLong:streamingRequestIQ.length];
    [encoder writeLong:streamingRequestIQ.timestamp];
    [encoder writeLong:streamingRequestIQ.playerPosition];
    [encoder writeInt:streamingRequestIQ.lastRTT];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t ident = [decoder readLong];
    int64_t offset = [decoder readLong];
    int64_t length = [decoder readLong];
    int64_t timestamp = [decoder readLong];
    int64_t playerPosition = [decoder readLong];
    int lastRTT = [decoder readInt];

    return [[StreamingRequestIQ alloc] initWithSerializer:self requestId:iq.requestId ident:ident offset:offset length:length playerPosition:playerPosition timestamp:timestamp lastRTT:lastRTT];
}

@end

//
// Implementation: StreamingRequestIQ
//
static TLBinaryPacketIQSerializer *IQ_STREAMING_REQUEST_SERIALIZER = nil;

@implementation StreamingRequestIQ

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_STREAMING_REQUEST_SERIALIZER;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId ident:(int64_t)ident offset:(int64_t)offset length:(int64_t)length playerPosition:(int64_t)playerPosition timestamp:(int64_t)timestamp lastRTT:(int)lastRTT {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _ident = ident;
        _offset = offset;
        _length = length;
        _playerPosition = playerPosition;
        _timestamp = timestamp;
        _lastRTT = lastRTT;
    }
    return self;
}

@end
