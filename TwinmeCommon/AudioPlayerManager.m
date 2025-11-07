/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <AVFoundation/AVFoundation.h>
#import <CocoaLumberjack.h>

#import <WebRTC/RTCDispatcher.h>
#import <WebRTC/RTCAudioSession.h>

#import "AudioPlayerManager.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static AudioPlayerManager *sharedInstance = nil;

//
// Interface: AudioSessionManager ()
//

@interface AudioSessionManager ()

@property (nonatomic, nullable) NSString *category;
@property (nonatomic) AVAudioSessionCategoryOptions options;
@property (nonatomic) BOOL usingAudioSession;
@property (nonatomic) BOOL isActive;

@end

//
// Interface: AudioPlayerManager ()
//

@interface AudioPlayerManager () <AVAudioPlayerDelegate>

@property (nonatomic, nullable) AVAudioPlayer *audioPlayer;

@end

#undef LOG_TAG
#define LOG_TAG @"AudioSessionManager"

@implementation AudioSessionManager

- (nonnull instancetype) init {
    
    self = [super init];
    if (self) {
        _usingAudioSession = NO;
    }
    return self;
}

- (void)startAudioSessionWithCompletion:(nullable dispatch_block_t)completion {
    DDLogVerbose(@"%@ startWithCompletion: %@", LOG_TAG, completion);

    [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
        RTC_OBJC_TYPE(RTCAudioSession) *audioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
        [audioSession lockForConfiguration];
        NSError *error = nil;

        // Record previous audio session settings and setActive first.
        // RTCAudioSession keeps an internal counter incremented at each setActive:YES and
        // decremented at each setActive:NO and it will use the CoreAudio when the counter is > 0.
        if (!self.usingAudioSession) {
            self.usingAudioSession = YES;
            self.category = audioSession.category;
            self.options = audioSession.categoryOptions;
            self.isActive = [audioSession isActive];
            [audioSession setActive:YES error:&error];
        }
        [audioSession setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionAllowBluetoothA2DP | AVAudioSessionCategoryOptionDuckOthers error:&error];
        if (![audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error]) {
            DDLogError(@"Error overriding output port: %@", error.localizedDescription);
        }
        [audioSession unlockForConfiguration];

        if (completion) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }
    }];
}

- (void)releaseAudioSession {
    DDLogVerbose(@"%@ releaseAudioSession", LOG_TAG);

    if (self.usingAudioSession) {
        [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
            RTC_OBJC_TYPE(RTCAudioSession) *audioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];

            [audioSession lockForConfiguration];
            if (self.usingAudioSession) {
                // [audioSession setCategory:self.category withOptions:self.options error:nil];
                
                // Release the audio session so that we restore other players.
                [audioSession setActive:NO error:nil];
            } else {
                DDLogError(@"%@ releaseAudioSession do nothing", LOG_TAG);
            }
            self.usingAudioSession = NO;
            [audioSession unlockForConfiguration];
        }];
    }
}

- (void)proximityChanged {
    DDLogVerbose(@"%@ proximityChanged", LOG_TAG);
    
    if ([[UIDevice currentDevice] proximityState]) {
        [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
            RTC_OBJC_TYPE(RTCAudioSession) *audioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
            [audioSession lockForConfiguration];
            if (self.usingAudioSession) {
                NSError *error = nil;
                [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
                if (![audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error]) {
                    DDLogError(@"Error overriding output port: %@", error.localizedDescription);
                }
            }
            [audioSession unlockForConfiguration];
        }];
    } else {
        [RTC_OBJC_TYPE(RTCDispatcher) dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
            RTC_OBJC_TYPE(RTCAudioSession) *audioSession = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
            [audioSession lockForConfiguration];
            if (self.usingAudioSession) {
                NSError *error = nil;
                [audioSession setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
                if (![audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error]) {
                    DDLogError(@"Error overriding output port: %@", error.localizedDescription);
                }
            }
            [audioSession unlockForConfiguration];
        }];
    }
}

@end

#undef LOG_TAG
#define LOG_TAG @"AudioPlayerManager"

@implementation AudioPlayerManager

+ (AudioPlayerManager *)sharedInstance {
    
    if (sharedInstance == nil) {
        
        sharedInstance = [[AudioPlayerManager alloc] init];
    }
    
    return sharedInstance;
}

+ (void)stopPlaying {
    
    AudioPlayerManager *player = sharedInstance;
    if (player && [player isPlaying]) {
        [player stop];
    }
}

- (void)playWithURL:(NSURL *)url currentTime:(float)currentTime  startPlayingBlock:(nullable dispatch_block_t)startPlayingBlock {
    DDLogVerbose(@"%@ playWithURL: %@", LOG_TAG, url);

    [self startAudioSessionWithCompletion:^{
        NSError *error = nil;
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
        if (error == nil){
            self.audioPlayer.delegate = self;
            [self.audioPlayer play];
            if (currentTime > 0.0) {
                [self.audioPlayer setCurrentTime:currentTime];
            }
            if (startPlayingBlock) {
                dispatch_async(dispatch_get_main_queue(), startPlayingBlock);
            }
        }
    }];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    DDLogVerbose(@"%@ audioPlayerDidFinishPlaying: %@ flag: %d", LOG_TAG, player, flag);

    [self releaseAudioSession];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"audioPlayerDidFinishPlaying" object:nil];
}

- (void)releaseAudioSession {
    DDLogVerbose(@"%@ releaseAudioSession", LOG_TAG);

    if (self.audioPlayer) {
        [self.audioPlayer stop];
        self.audioPlayer.delegate = nil;
    }

    [super releaseAudioSession];
}

- (BOOL)isPlaying {
    return [self.audioPlayer isPlaying];
}

- (void)pause {
    DDLogVerbose(@"%@ pause", LOG_TAG);

    if ([self.audioPlayer isPlaying]) {
        [self.audioPlayer pause];
    }
    [self releaseAudioSession];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);

    if ([self.audioPlayer isPlaying]) {
        [self.audioPlayer stop];
    }
    [self releaseAudioSession];
}

- (float)currentPlaybackTime {
    return self.audioPlayer.currentTime;
}

- (float)duration {
    return self.audioPlayer.duration;
}

- (void)setCurrentTime:(float)currentTime {
    [self.audioPlayer setCurrentTime:currentTime];
}

@end
