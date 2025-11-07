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

#import "AsyncVideoLoader.h"
#import "Cache.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: AsyncVideoLoader ()
//

@interface AsyncVideoLoader ()

@property (readonly, nonnull) id<NSObject> item;
@property (readonly, nonnull) Cache *cache;
@property (readonly) CGSize size;
@property (nullable) TLVideoDescriptor *videoDescriptor;
@property BOOL loaderIsFinished;

@end

//
// Implementation: AsyncVideoLoader
//

#undef LOG_TAG
#define LOG_TAG @"AsyncVideoLoader"

@implementation AsyncVideoLoader

- (nonnull instancetype)initWithItem:(nonnull id<NSObject>)item videoDescriptor:(nonnull TLVideoDescriptor *)videoDescriptor size:(CGSize)size {
    DDLogVerbose(@"%@ initWithItem: %@ videoDescriptor: %@", LOG_TAG, item, videoDescriptor);
    
    self = [super init];
    
    if (self) {
        _item = item;
        _videoDescriptor = videoDescriptor;
        _size = size;
        _loaderIsFinished = NO;
        _cache = [Cache getInstance];
        _image = [_cache imageFromVideoDescriptor:videoDescriptor size:size];
    }
    return self;
}

- (void)cancel {
    DDLogVerbose(@"%@ cancel", LOG_TAG);

    self.videoDescriptor = nil;
}

- (BOOL)isFinished {
    DDLogVerbose(@"%@ isFinished", LOG_TAG);

    return self.loaderIsFinished;
}

#pragma mark - Private methods

- (void)loadObjectWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext fetchCompletionHandler:(void (^)(id<NSObject> item))completionHandler {
    DDLogVerbose(@"%@ loadObjectWithTwinmeContext", LOG_TAG);

    TLVideoDescriptor *videoDescriptor = self.videoDescriptor;
    if (!videoDescriptor) {
        self.loaderIsFinished = YES;

        completionHandler(nil);
        return;
    }

    self.image = [videoDescriptor getThumbnailWithMaxSize:CGSizeMake(self.size.width, self.size.height)];
    self.loaderIsFinished = YES;
    if (self.image) {
        [self.cache setImageWithVideoDescriptor:videoDescriptor size:self.size image:self.image];
    }

    completionHandler(self.image ? self.item : nil);
}

@end
