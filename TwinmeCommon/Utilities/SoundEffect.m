/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "SoundEffect.h"

#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>
#import <CocoaLumberjack.h>

#import "ApplicationDelegate.h"
#import "TwinmeApplication.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"SoundEffect"

@implementation SoundEffect

static NSMutableDictionary<NSString *, NSNumber *> *soundIds = nil;

+ (void)playSoundWithType:(SoundEffectType)type {
    DDLogVerbose(@"%@ playSoundWithType: %ld", LOG_TAG, (long)type);
    
    ApplicationDelegate *delegate = (ApplicationDelegate *)[[UIApplication sharedApplication] delegate];
    TwinmeApplication *twinmeApplication = [delegate twinmeApplication];
    
    if (![twinmeApplication allowSoundEffects]) {
        return;
    }

    SystemSoundID soundID = [self soundIDForType:type];
    if (soundID == 0) {
        return;
    }

    AudioServicesPlaySystemSound(soundID);
}

+ (void)disposeSounds {
    DDLogVerbose(@"%@ disposeSounds", LOG_TAG);
    
    @synchronized (self) {
        for (NSNumber *soundIDNumber in soundIds.allValues) {
            AudioServicesDisposeSystemSoundID((SystemSoundID) soundIDNumber.unsignedIntValue);
        }

        [soundIds removeAllObjects];
    }
}

+ (SystemSoundID)soundIDForType:(SoundEffectType)type {
    DDLogVerbose(@"%@ soundIDForType: %ld", LOG_TAG, (long)type);
    
    NSString *resourceName = [self resourceNameForType:type];

    @synchronized (self) {
        NSNumber *soundIDNumber = soundIds[resourceName];
        if (soundIDNumber != nil) {
            return (SystemSoundID)soundIDNumber.unsignedIntValue;
        }

        NSURL *url = [[NSBundle mainBundle] URLForResource:resourceName withExtension:@"caf"];
        if (!url) {
            return 0;
        }

        SystemSoundID soundID = 0;
        OSStatus status = AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &soundID);
        if (status != kAudioServicesNoError) {
            return 0;
        }

        if (soundIds == nil) {
            soundIds = [NSMutableDictionary dictionary];
        }

        soundIDNumber = @(soundID);
        [soundIds setValue:soundIDNumber forKey:resourceName];
        
        return soundID;
    }
}

+ (NSString *)resourceNameForType:(SoundEffectType)type {
    DDLogVerbose(@"%@ resourceNameForType: %ld", LOG_TAG, (long)type);
    
    switch (type) {
        case SoundEffectTypeSendMessage:
            return @"send_message";
            
        case SoundEffectTypeNewMessage:
            return @"new_message";
            
        case SoundEffectTypeDeleteMessage:
            return @"delete_message";
            
        case SoundEffectTypeEmoji:
            return @"emoji";
            
        case SoundEffectTypeJoinCall:
            return @"join_call";
    }
}

@end
