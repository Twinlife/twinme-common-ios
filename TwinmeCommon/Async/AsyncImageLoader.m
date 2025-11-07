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

#import "AsyncImageLoader.h"
#import "Cache.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: AsyncImageLoader ()
//

@interface AsyncImageLoader ()

@property (readonly, nonnull) id<NSObject> item;
@property (readonly) CGSize size;
@property (readonly, nonnull) Cache *cache;
@property (nullable) TLImageDescriptor *imageDescriptor;
@property BOOL loaderIsFinished;

@end

//
// Implementation: AsyncImageLoader
//

#undef LOG_TAG
#define LOG_TAG @"AsyncImageLoader"

@implementation AsyncImageLoader

- (nonnull instancetype)initWithItem:(nonnull id<NSObject>)item imageDescriptor:(nonnull TLImageDescriptor *)imageDescriptor size:(CGSize)size {
    DDLogVerbose(@"%@ initWithItem: %@ imageDescriptor: %@", LOG_TAG, item, imageDescriptor);
    
    self = [super init];
    
    if (self) {
        _item = item;
        _imageDescriptor = imageDescriptor;
        _size = size;
        _loaderIsFinished = NO;
        _cache = [Cache getInstance];
        _image = [_cache imageFromImageDescriptor:imageDescriptor size:size];
    }
    return self;
}

- (void)cancel {
    DDLogVerbose(@"%@ cancel", LOG_TAG);

    self.imageDescriptor = nil;
}

- (BOOL)isFinished {
    DDLogVerbose(@"%@ isFinished", LOG_TAG);

    return self.loaderIsFinished;
}

#pragma mark - Private methods

- (void)loadObjectWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext fetchCompletionHandler:(void (^)(id<NSObject> item))completionHandler {
    DDLogVerbose(@"%@ loadObjectWithTwinmeContext", LOG_TAG);

    TLImageDescriptor *imageDescriptor = self.imageDescriptor;
    if (!imageDescriptor) {
        self.loaderIsFinished = YES;

        completionHandler(nil);
        return;
    }

    self.image = [imageDescriptor getThumbnailWithMaxSize:MAX(self.size.width, self.size.height)];
    self.loaderIsFinished = YES;
    if (self.image) {
        [self.cache setImageWithImageDescriptor:imageDescriptor size:self.size image:self.image];
    }

    completionHandler(self.image ? self.item : nil);
}

@end
