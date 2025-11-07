/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinlife/TLConversationService.h>

#import "AudioTrack.h"
#import "AsyncAudioTrackLoader.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: AsyncAudioTrackLoader ()
//

@interface AsyncAudioTrackLoader ()

@property (readonly, nonnull) id<NSObject> item;
@property (readonly) int nbLines;
@property (nullable) TLAudioDescriptor *audioDescriptor;
@property BOOL loaderIsFinished;

@end

//
// Implementation: AsyncAudioTrackLoader
//

#undef LOG_TAG
#define LOG_TAG @"AsyncAudioTrackLoader"

@implementation AsyncAudioTrackLoader

- (nonnull instancetype)initWithItem:(nonnull id<NSObject>)item audioDescriptor:(nonnull TLAudioDescriptor *)audioDescriptor nbLines:(int)nbLines {
    DDLogVerbose(@"%@ initWithItem: %@ audioDescriptor: %@ nbLines: %d", LOG_TAG, item, audioDescriptor, nbLines);
    
    self = [super init];
    
    if (self) {
        _item = item;
        _audioDescriptor = audioDescriptor;
        _nbLines = nbLines;
        _loaderIsFinished = NO;
    }
    return self;
}

- (void)cancel {
    DDLogVerbose(@"%@ cancel", LOG_TAG);

    self.audioDescriptor = nil;
}

- (BOOL)isFinished {
    DDLogVerbose(@"%@ isFinished", LOG_TAG);

    return self.loaderIsFinished;
}

#pragma mark - Private methods

- (void)loadObjectWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext fetchCompletionHandler:(void (^)(id<NSObject> item))completionHandler {
    DDLogVerbose(@"%@ loadObjectWithTwinmeContext", LOG_TAG);

    TLAudioDescriptor *audioDescriptor = self.audioDescriptor;
    if (!audioDescriptor) {
        self.loaderIsFinished = YES;

        completionHandler(nil);
        return;
    }

    NSURL *url = [audioDescriptor getURL];
    AudioTrack *audioTrack = [[AudioTrack alloc] initWithURL:url nbLines:self.nbLines save:[audioDescriptor isAvailable]];
    if (audioTrack.trackData) {
        self.audioTrack = audioTrack;
        self.loaderIsFinished = YES;
        completionHandler(self.item);
    }

    self.loaderIsFinished = YES;
    completionHandler(nil);
}

@end
