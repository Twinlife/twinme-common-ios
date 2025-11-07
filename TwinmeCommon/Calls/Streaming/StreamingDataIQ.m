/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "StreamingDataIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * A data block for the streaming flow in response to a streaming request.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"5a5d0994-2ca3-4a62-9da3-9b7d5c4abdd4",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"StreamingDataIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"ident", "type":"long"},
 *     {"name":"offset", "type":"long"},
 *     {"name":"timestamp", "type":"long"},
 *     {"name":"streamerPosition", "type":"long"},
 *     {"name":"streamerLatency", "type":"int"},
 *     {"name":"data", "type": [null, "bytes"]}
 *  ]
 * }
 *
 * </pre>
 *
 * @see StreamingRequestIQ
 */

//
// Implementation: StreamingDataIQSerializer
//

@implementation StreamingDataIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[StreamingDataIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    StreamingDataIQ *streamingDataIQ = (StreamingDataIQ *)object;
    [encoder writeLong:streamingDataIQ.ident];
    [encoder writeLong:streamingDataIQ.offset];
    [encoder writeLong:streamingDataIQ.timestamp];
    [encoder writeLong:streamingDataIQ.streamerPosition];
    [encoder writeInt:streamingDataIQ.streamerLatency];
    if (!streamingDataIQ.data || streamingDataIQ.length <= 0) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeDataWithData:streamingDataIQ.data start:streamingDataIQ.start length:streamingDataIQ.length];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t ident = [decoder readLong];
    int64_t offset = [decoder readLong];
    int64_t timestamp = [decoder readLong];
    int64_t streamerPosition = [decoder readLong];
    int streamerLatency = [decoder readInt];
    int32_t length;
    NSData *data;
    if ([decoder readEnum] == 0) {
        data = nil;
        length = 0;
    } else {
        data = [decoder readData];
        length = (int32_t) data.length;
    }

    return [[StreamingDataIQ alloc] initWithSerializer:self requestId:iq.requestId ident:ident offset:offset streamerPosition:streamerPosition timestamp:timestamp streamerLatency:streamerLatency data:data start:0 length:length];
}

@end

//
// Implementation: StreamingDataIQ
//

@implementation StreamingDataIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId ident:(int64_t)ident offset:(int64_t)offset streamerPosition:(int64_t)streamerPosition timestamp:(int64_t)timestamp streamerLatency:(int)streamerLatency data:(nullable NSData*)data start:(int32_t)start length:(int32_t)length {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _ident = ident;
        _offset = offset;
        _streamerPosition = streamerPosition;
        _timestamp = timestamp;
        _streamerLatency = streamerLatency;
        _data = data;
        _start = start;
        _length = length;
    }
    return self;
}

@end
