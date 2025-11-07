/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TerminateKeyCheckIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * Terminate Key check IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"f57606a3-9455-4efe-b375-38e1a142465f",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"TerminateKeyCheckIQ",
 *  "namespace":"org.twinlife.schemas.calls.keycheck",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"result", "type":"boolean"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TerminateKeyCheckIQSerializer
//

@implementation TerminateKeyCheckIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TerminateKeyCheckIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TerminateKeyCheckIQ *terminateKeyCheckIQ = (TerminateKeyCheckIQ *)object;
    [encoder writeBoolean:terminateKeyCheckIQ.result];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    BOOL result = [decoder readBoolean];
    
    return [[TerminateKeyCheckIQ alloc] initWithSerializer:self requestId:iq.requestId result:result];
}

@end

//
// Implementation: TerminateKeyCheckIQ
//

@implementation TerminateKeyCheckIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId result:(BOOL)result {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _result = result;
    }
    return self;
}

@end
