/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

@interface AudioTrack : NSObject

@property (readonly, nonnull) NSData *trackData;

/// Load the audio track or generate it if necessary.
- (nonnull instancetype)initWithURL:(nonnull NSURL *)urlAsset nbLines:(int)nbLines save:(BOOL)save;

@end
