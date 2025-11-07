/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "OnKeyCheckInitiateIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * Start key check session response IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"773743ea-2d2b-4b64-9ab5-e072571456d8",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnKeyCheckInitiateIQ",
 *  "namespace":"org.twinlife.schemas.calls.keycheck",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"errorCode", "type":"enum"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: OnKeyCheckInitiateIQSerializer
//

@implementation OnKeyCheckInitiateIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[OnKeyCheckInitiateIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    OnKeyCheckInitiateIQ *onKeyCheckInitiateIQ = (OnKeyCheckInitiateIQ *)object;
    [encoder writeEnum:[TLBaseService fromErrorCode:onKeyCheckInitiateIQ.errorCode]];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    TLBaseServiceErrorCode errorCode = [TLBaseService toErrorCode:[decoder readEnum]];
    
    return [[OnKeyCheckInitiateIQ alloc] initWithSerializer:self requestId:iq.requestId errorCode:errorCode];
}

@end

//
// Implementation: OnKeyCheckInitiateIQ
//

@implementation OnKeyCheckInitiateIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _errorCode = errorCode;
    }
    return self;
}

@end
