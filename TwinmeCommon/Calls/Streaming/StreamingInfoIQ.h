/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLBinaryPacketIQ.h>

//
// Interface: StreamingInfoIQSerializer
//

@interface StreamingInfoIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: StreamingInfoIQ
//

@interface StreamingInfoIQ : TLBinaryPacketIQ

@property (readonly) int64_t ident;
@property (readonly, nonnull) NSString* title;
@property (readonly, nullable) NSString* album;
@property (readonly, nullable) NSString* artist;
@property (readonly, nullable) NSData* artwork;
@property (readonly) int64_t duration;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId ident:(int64_t)ident title:(nonnull NSString *)title album:(nullable NSString *)album artist:(nullable NSString *)artist artwork:(nullable NSData *)artwork duration:(int64_t)duration;

@end
