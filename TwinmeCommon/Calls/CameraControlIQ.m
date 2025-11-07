/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "CameraControlIQ.h"

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

/**
 * Camera control IQ sent to change the configuration of the camera on the peer device.
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"6512ff06-7c18-4de4-8760-61b87b9169a5",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"CameraControlIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"control": "type":"int"},
 *     {"name":"camera", "type":"int"},
 *     {"name":"scale", "type":"int"},
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: CameraControlIQSerializer
//

@implementation CameraControlIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[CameraControlIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    CameraControlIQ *cameraControlIQ = (CameraControlIQ *)object;
    switch (cameraControlIQ.mode) {
        case CameraControlModeCheck:
            [encoder writeEnum:0];
            break;
        case CameraControlModeON:
            [encoder writeEnum:1];
            break;
        case CameraControlModeOFF:
            [encoder writeEnum:2];
            break;
        case CameraControlModeSelect:
            [encoder writeEnum:3];
            break;
        case CameraControlModeZoom:
            [encoder writeEnum:4];
            break;
        case CameraControlModeStop:
            [encoder writeEnum:5];
            break;
        default:
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
    }
    [encoder writeInt:cameraControlIQ.camera];
    [encoder writeInt:cameraControlIQ.scale];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    CameraControlMode mode;
    switch ([decoder readEnum]) {
        case 0:
            mode = CameraControlModeCheck;
            break;
        case 1:
            mode = CameraControlModeON;
            break;
        case 2:
            mode = CameraControlModeOFF;
            break;
        case 3:
            mode = CameraControlModeSelect;
            break;
        case 4:
            mode = CameraControlModeZoom;
            break;
        case 5:
            mode = CameraControlModeStop;
            break;
        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    int camera = [decoder readInt];
    int scale = [decoder readInt];


    return [[CameraControlIQ alloc] initWithSerializer:self requestId:iq.requestId mode:mode camera:camera scale:scale];
}

@end

//
// Implementation: CameraControlIQ
//

@implementation CameraControlIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId mode:(CameraControlMode)mode camera:(int)camera scale:(int)scale {

    self = [super initWithSerializer:serializer requestId:requestId];
    if (self) {
        _mode = mode;
        _camera = camera;
        _scale = scale;
    }
    return self;
}

@end
