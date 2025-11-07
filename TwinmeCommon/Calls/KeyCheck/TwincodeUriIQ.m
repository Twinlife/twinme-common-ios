/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TwincodeUriIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * Result of a word check IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"413c9c59-2b93-4010-8f6c-bd4f64ce5d9d",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"TwincodeUriIQ",
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
// Implementation: TwincodeUriIQSerializer
//

@implementation TwincodeUriIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TwincodeUriIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TwincodeUriIQ *twincodeUriIQ = (TwincodeUriIQ *)object;
    [encoder writeString:twincodeUriIQ.uri];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSString *uri = [decoder readString];

    return [[TwincodeUriIQ alloc] initWithSerializer:self requestId:iq.requestId uri:uri];
}

@end

//
// Implementation: TwincodeUriIQ
//

@implementation TwincodeUriIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId uri:(nonnull NSString *)uri {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _uri = uri;
    }
    return self;
}

@end
