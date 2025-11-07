/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "StreamingInfoIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * Streaming information.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"30991309-e91f-4295-8a9c-995fcfaf042e",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"StreamingInfoIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"ident", "type":"long"},
 *     {"name":"title", "type":"string"},
 *     {"name":"album", [null, "type":"string"]},
 *     {"name":"artist", [null, "type":"string"]},
 *     {"name":"artwork", [null, "type":"bytes"]}
 *     {"name":"duration", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: StreamingInfoIQSerializer
//

@implementation StreamingInfoIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[StreamingInfoIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    StreamingInfoIQ *streamingInfoIQ = (StreamingInfoIQ *)object;
    [encoder writeLong:streamingInfoIQ.ident];
    [encoder writeString:streamingInfoIQ.title];
    [encoder writeOptionalString:streamingInfoIQ.album];
    [encoder writeOptionalString:streamingInfoIQ.artist];
    [encoder writeOptionalData:streamingInfoIQ.artwork];
    [encoder writeLong:streamingInfoIQ.duration];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t ident = [decoder readLong];
    NSString *title = [decoder readString];
    NSString *album = [decoder readOptionalString];
    NSString *artist = [decoder readOptionalString];
    NSData *artwork = [decoder readOptionalData];
    int64_t duration = [decoder readLong];

    return [[StreamingInfoIQ alloc] initWithSerializer:self requestId:iq.requestId ident:ident title:title album:album artist:artist artwork:artwork duration:duration];
}

@end

//
// Implementation: StreamingInfoIQ
//

@implementation StreamingInfoIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId ident:(int64_t)ident title:(nonnull NSString *)title album:(nullable NSString *)album artist:(nullable NSString *)artist artwork:(nullable NSData *)artwork  duration:(int64_t)duration {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _ident = ident;
        _title = title;
        _album = album;
        _artist = artist;
        _artwork = artwork;
        _duration = duration;
    }
    return self;
}

@end
