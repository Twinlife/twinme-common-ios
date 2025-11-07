/*
 *  Copyright (c) 2017-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Thibaud David (contact@thibauddavid.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: Cache
//

@class TLImageDescriptor;
@class TLVideoDescriptor;

@interface Cache : NSObject

+ (nonnull id)getInstance;

- (nullable UIImage *)imageFromImageDescriptor:(nonnull TLImageDescriptor *)imageDescriptor size:(CGSize)size;

- (nullable UIImage *)imageFromVideoDescriptor:(nonnull TLVideoDescriptor *)videoDescriptor size:(CGSize)size;

- (void)setImageWithImageDescriptor:(nonnull TLImageDescriptor *)imageDescriptor size:(CGSize)size image:(nonnull UIImage*)image;

- (void)setImageWithVideoDescriptor:(nonnull TLVideoDescriptor *)videoDescriptor size:(CGSize)size image:(nonnull UIImage*)image;

- (nullable NSString *)titleFromObjectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor;

- (nullable UIImage *)imageFromObjectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor;

- (void)setTitleWithObjectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor title:(nonnull NSString *)title;

- (void)setImageWithObjectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor image:(nonnull UIImage*)image;

@end
