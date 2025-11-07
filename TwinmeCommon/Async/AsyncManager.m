/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>

#import "AsyncManager.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: AsyncManager ()
//

@interface AsyncManager ()

@property (readonly, nonnull) TLTwinmeContext *twinmeContext;
@property (readonly, weak) id<AsyncLoaderDelegate> delegate;
@property (readonly, nonnull) NSMutableArray<id<AsyncLoader>> *items;
@property (readonly, nonnull) dispatch_queue_t loaderQueue;
@property (nullable) NSMutableArray<id<NSObject>> *loaded;
@property BOOL scheduled;
@property BOOL notified;

///Notify the UI that some loadable items have been refreshed (executed from the main UI thread).
- (void)refreshItems;

/// Load the item data (image, audio track, ...) from the background executor thread.
- (void)loadItems;

@end

//
// Implementation: AsyncManager
//

#undef LOG_TAG
#define LOG_TAG @"AsyncManager"

@implementation AsyncManager

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<AsyncLoaderDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@", LOG_TAG, twinmeContext);
    
    self = [super init];
    if (self) {
        _twinmeContext = twinmeContext;
        _delegate = delegate;
        _items = [[NSMutableArray alloc] init];
        _loaded = nil;
        _loaderQueue = dispatch_queue_create("loaderQueue", DISPATCH_QUEUE_SERIAL);
        _scheduled = NO;
    }

    return self;
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);

    @synchronized (self) {
        [self.items removeAllObjects];
        self.loaded = nil;
    }
}

- (void)clear {
    DDLogVerbose(@"%@ clear", LOG_TAG);

    @synchronized (self) {
        [self.items removeAllObjects];
    }
}

- (void)addItemWithAsyncLoader:(nonnull id<AsyncLoader>)loader {
    DDLogVerbose(@"%@ addItemWithAsyncLoader", LOG_TAG);

    @synchronized (self) {
        [self.items addObject:loader];
        if (!self.scheduled) {
            self.scheduled = YES;
            dispatch_async(self.loaderQueue, ^{
                [self loadItems];
            });
        }
    }
}

- (void)asyncLoader:(nonnull dispatch_block_t)block {
    DDLogVerbose(@"%@ asyncLoader", LOG_TAG);

    dispatch_async(self.loaderQueue, block);
}

#pragma mark - Private methods

- (void)refreshItems {
    DDLogVerbose(@"%@ refreshItems", LOG_TAG);

    NSMutableArray<id<NSObject>> *list;
    @synchronized (self) {
        list = self.loaded;
        self.loaded = nil;
        self.notified = NO;
    }

    if (list) {
        [self.delegate onLoadedWithItems:list];
    }
}

- (void)loadItems {
    DDLogVerbose(@"%@ loadItems", LOG_TAG);

    while (true) {
        // Pick a loader to load or terminate.
        id<AsyncLoader> loader;
        @synchronized (self) {
            if (self.items.count == 0) {
                self.scheduled = NO;
                return;
            }
            loader = self.items[0];
            [self.items removeObjectAtIndex:0];
        }
        
        [loader loadObjectWithTwinmeContext:self.twinmeContext fetchCompletionHandler:^(id<NSObject> item){
            if (item) {
                // The loader has loaded an object, schedule a UI refresh.
                @synchronized (self) {
                    if (!self.loaded) {
                        self.loaded = [[NSMutableArray alloc] init];
                    }
                    [self.loaded addObject:item];
                    if (!self.notified) {
                        self.notified = YES;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self refreshItems];
                        });
                    }
                }
            }
        }];
        
    }
}

@end
