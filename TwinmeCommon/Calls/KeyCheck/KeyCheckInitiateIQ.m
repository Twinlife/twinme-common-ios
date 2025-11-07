/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "KeyCheckInitiateIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * Start key check session request IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"9c1a7c29-3402-4941-9480-0fd9258f5e5b",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"KeyCheckInitiateIQ",
 *  "namespace":"org.twinlife.schemas.calls.keycheck",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"locale", "type":"string"}
 *  ]
 * }
 *
 * </pre>
 */


//
// Implementation:KeyCheckInitiateIQerializer
//

@implementation KeyCheckInitiateIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[KeyCheckInitiateIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    KeyCheckInitiateIQ *keyCheckInitiateIQ = (KeyCheckInitiateIQ *)object;
    [encoder writeString:keyCheckInitiateIQ.locale.languageCode];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSString *language = [decoder readString];
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:language];
    
    return [[KeyCheckInitiateIQ alloc] initWithSerializer:self requestId:iq.requestId locale:locale];
}

@end

//
// Implementation: KeyCheckInitiateIQ
//

@implementation KeyCheckInitiateIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId locale:(nonnull NSLocale *)locale {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _locale = locale;
    }
    return self;
}

@end
