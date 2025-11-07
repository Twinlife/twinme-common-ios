/*
 *  Copyright (c) 2016-2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life) */

#import <AudioToolbox/AudioToolbox.h>

#import <Notification/NotificationSettings.h>

//
// Interface: NotificationSound
//

@interface NotificationSound : NotificationSoundSetting

- (nonnull instancetype)initWithSettings:(nonnull NotificationSoundSetting *)settings;

- (BOOL)isAvailable;

- (void)playWithLoop:(BOOL)loop;

- (void)playWithLoop:(BOOL)loop audioSessionCategory:(nonnull NSString *)category;

- (void)dispose;

@end
