/*
 *  Copyright (c) 2016-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

@import AVFoundation;

#import <CocoaLumberjack.h>

#import <WebRTC/RTCAudioSession.h>
#import <WebRTC/RTCDispatcher.h>
#import <UserNotifications/UserNotifications.h>

#import "NotificationSound.h"

//
// Interface: NotificationSound ()
//

@interface NotificationSound () <AVAudioPlayerDelegate>

@property NSString *category;
@property AVAudioSessionCategoryOptions options;
@property AVAudioPlayer *player;
@property BOOL playing;
@property BOOL loop;
@property BOOL isActive;
@property BOOL usingAudioSession;

@end

//
// Implementation: NotificationSound
//

@implementation NotificationSound

#pragma mark - Public methods

- (BOOL)isAvailable {
    
    if (self.soundPath) {
        return [[NSBundle mainBundle] pathForResource:self.soundPath ofType:nil] != nil;
    }
    
    return YES;
}

- (UNNotificationSound *)getSoundForLocalNotification {
    
    if (self.soundPath) {
        return [UNNotificationSound soundNamed:self.soundPath];
    }
    
    return [UNNotificationSound defaultSound];
}

- (void)playWithLoop:(BOOL)loop {
    
    [self playWithLoop:loop audioSessionCategory:AVAudioSessionCategoryPlayback];
}

- (void)playWithLoop:(BOOL)loop audioSessionCategory:(NSString *)category {
    self.loop = loop;
    
    RTC_OBJC_TYPE(RTCAudioSession) *audioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
    
    BOOL speaker = NO;
    self.isActive = audioSession.isActive;
    if (self.isActive) {
        category = AVAudioSessionCategoryPlayAndRecord;
        for (AVAudioSessionPortDescription *portDescription in audioSession.currentRoute.outputs) {
            if ([portDescription.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]) {
                speaker = YES;
                break;
            }
        }
    }
    
    if (self.soundPath) {
        [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
            [audioSession lockForConfiguration];
            self.category = audioSession.category;
            self.options = audioSession.categoryOptions;
            self.usingAudioSession = YES;

            // We must activate the session if it is not active and release it once we are done.
            if (!self.isActive) {
                [audioSession setActive:YES error:nil];
            }

            // Play the sound on the headset and mix with existing audio streams.
            [audioSession setCategory:category withOptions:AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionAllowBluetoothA2DP | AVAudioSessionCategoryOptionMixWithOthers error:nil];
            NSError *error = nil;
            if (speaker) {
                if (![audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error]) {
                }
            }
            [audioSession unlockForConfiguration];
            
            NSString *path = [[NSBundle mainBundle] pathForResource:self.soundPath ofType:nil];
            if (path) {
                NSURL *url = [[NSURL alloc] initFileURLWithPath:path];
                if (url) {
                    NSError* err;
                    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
                    
                    self.player.delegate = self;
                    self.playing = YES;
                    [self.player play];
                }
            }
        }];
    } else {
        self.playing = YES;
        AudioServicesPlaySystemSound(self.soundId);
    }
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    
    if (self.loop) {
        NSTimeInterval shortStartDelay = 1.0;
        NSTimeInterval now = player.deviceCurrentTime;
        [self.player playAtTime:now + shortStartDelay];
    } else {
        [self releaseAudioSession];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"audioPlayerDidFinishPlaying" object:nil];
}

- (void)releaseAudioSession {
    
    if (self.usingAudioSession) {
        self.usingAudioSession = NO;
        
        [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
            RTC_OBJC_TYPE(RTCAudioSession) *audioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
            if (self.player) {
                [self.player stop];
                self.player.delegate = nil;
            }

            [audioSession lockForConfiguration];
            [audioSession setCategory:self.category withOptions:self.options error:nil];

            // Release the audio session so that we restore other players.
            if (!self.isActive) {
                [audioSession setActive:NO error:nil];
            }
            [audioSession unlockForConfiguration];
        }];
    }
}

- (void)dispose {
    
    [self releaseAudioSession];
    if (!self.playing) {
        return;
    }
    self.playing = NO;
    if (!self.soundPath) {
        // TBD is it required?
        AudioServicesDisposeSystemSoundID(self.soundId);
    }
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    
    self = [super init];
    if (self) {
        self.soundName = [coder decodeObjectForKey:@"soundName"];
        self.soundPath = [coder decodeObjectForKey:@"soundPath"];
        self.soundId = [coder decodeInt32ForKey:@"soundId"];
        
        _playing = NO;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    
    [coder encodeObject:self.soundName forKey:@"soundName"];
    [coder encodeObject:self.soundPath forKey:@"soundPath"];
    [coder encodeInt32:self.soundId forKey:@"soundId"];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    
    if (self == object) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[NotificationSound class]]) {
        return NO;
    }
    NotificationSound *notificationSound = (NotificationSound *)object;
    if (self.soundPath) {
        return [self.soundPath isEqualToString:notificationSound.soundPath];
    } else {
        return self.soundId == notificationSound.soundId;
    }
}

- (NSUInteger)hash {
    
    NSUInteger result = 17;
    if (self.soundPath) {
        result = 31 * result + self.soundPath.hash;
    } else {
        result = 31 * result + self.soundId;
    }
    return result;
}

#pragma mark - Private methods

- (nonnull instancetype)initWithSettings:(nonnull NotificationSoundSetting *)settings {
    
    self = [super initWithType:settings.soundType name:settings.soundName soundId:settings.soundId soundPath:settings.soundPath];
    if (self) {
        _playing = NO;
        _isActive = NO;
        _usingAudioSession = NO;
    }
    return self;
}

- (instancetype)initWithType:(NotificationSoundType)soundType name:(NSString *)name soundId:(SystemSoundID)soundId soundPath:(NSString *)soundPath {
    
    self = [super initWithType:soundType name:name soundId:soundId soundPath:soundPath];
    if (self) {
        _playing = NO;
        _isActive = NO;
        _usingAudioSession = NO;
    }
    return self;
}

@end
