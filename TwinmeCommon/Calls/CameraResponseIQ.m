/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "CameraResponseIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * Camera response IQ sent as a response of a CameraControlIQ request.
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"c9ba7001-c32d-4545-bdfb-e80ff0db21aa",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"CameraResponseIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"errorCode", "type":"enum"},
 *     {"name":"cameraBitmap", "type":"long"},
 *     {"name":"activeCamera", "type":"int"},
 *     {"name":"minScale", "type":"long"],
 *     {"name":"maxScale", "type":"long"}
 *  ]
 * }
s * </pre>
 */

//
// Implementation: CameraResponseIQSerializer
//

@implementation CameraResponseIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[CameraResponseIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    CameraResponseIQ *cameraResponseIQ = (CameraResponseIQ *)object;
    [encoder writeEnum:[TLBaseService fromErrorCode:cameraResponseIQ.errorCode]];
    [encoder writeLong:cameraResponseIQ.cameraBitmap];
    [encoder writeInt:cameraResponseIQ.activeCamera];
    [encoder writeInt:cameraResponseIQ.minScale];
    [encoder writeInt:cameraResponseIQ.maxScale];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    TLBaseServiceErrorCode errorCode = [decoder readEnum];
    int64_t cameraBitmap = [decoder readLong];
    int activeCamera = [decoder readInt];
    int minScale = [decoder readInt];
    int maxScale = [decoder readInt];

    return [[CameraResponseIQ alloc] initWithSerializer:self requestId:iq.requestId errorCode:errorCode cameraBitmap:cameraBitmap activeCamera:activeCamera minScale:minScale maxScale:maxScale];
}

@end

//
// Implementation: CameraResponseIQ
//

@implementation CameraResponseIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode cameraBitmap:(int64_t)cameraBitmap activeCamera:(int)activeCamera minScale:(int)minScale maxScale:(int)maxScale {

    self = [super initWithSerializer:serializer requestId:requestId];
    if (self) {
        _errorCode = errorCode;
        _cameraBitmap = cameraBitmap;
        _activeCamera = activeCamera;
        _minScale = minScale;
        _maxScale = maxScale;
    }
    return self;
}

@end
