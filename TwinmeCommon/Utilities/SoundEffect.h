/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

typedef NS_ENUM(NSInteger, SoundEffectType) {
    SoundEffectTypeSendMessage,
    SoundEffectTypeNewMessage,
    SoundEffectTypeDeleteMessage,
    SoundEffectTypeEmoji,
    SoundEffectTypeJoinCall
};

//
// Interface: SoundEffect
//

@interface SoundEffect : NSObject

+ (void)playSoundWithType:(SoundEffectType)type;

+ (void)disposeSounds;

@end

