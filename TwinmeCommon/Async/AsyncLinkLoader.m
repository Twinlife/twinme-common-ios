/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (fabrice.trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <LinkPresentation/LinkPresentation.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/UTType.h>

#import <Twinme/TLMessage.h>
#import <Twinme/TLTwinmeContext.h>
#import <Twinlife/TLConversationService.h>

#import "AsyncLinkLoader.h"

#import "Cache.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: AsyncLinkLoader ()
//

@interface AsyncLinkLoader ()

@property (readonly, nonnull) id<NSObject> item;
@property (readonly, nonnull) Cache *cache;
@property (nullable) TLObjectDescriptor *objectDescriptor;
@property (nullable) NSString *content;
@property BOOL loaderIsFinished;

@end

//
// Implementation: AsyncLinkLoader
//

#undef LOG_TAG
#define LOG_TAG @"AsyncLinkLoader"

@implementation AsyncLinkLoader

- (nonnull instancetype)initWithItem:(nonnull id<NSObject>)item objectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor  {
    DDLogVerbose(@"%@ initWithItem: %@", LOG_TAG, item);
    
    self = [super init];
    
    if (self) {
        _item = item;
        _objectDescriptor = objectDescriptor;
        _content = objectDescriptor.message;
        _cache = [Cache getInstance];
        _title = [_cache titleFromObjectDescriptor:objectDescriptor];
        _image = [_cache imageFromObjectDescriptor:objectDescriptor];
        _loaderIsFinished = NO;
    }
    return self;
}

- (void)cancel {
    DDLogVerbose(@"%@ cancel", LOG_TAG);

    self.content = nil;
}

- (BOOL)isFinished {
    DDLogVerbose(@"%@ isFinished", LOG_TAG);

    return self.loaderIsFinished;
}

#pragma mark - Private methods

- (void)loadObjectWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext fetchCompletionHandler:(void (^)(id<NSObject> item))completionHandler {
    DDLogVerbose(@"%@ loadObjectWithTwinmeContext", LOG_TAG);

    TLObjectDescriptor *objectDescriptor = self.objectDescriptor;
    if (!objectDescriptor) {
        self.loaderIsFinished = YES;
        completionHandler(nil);
        return;
    }
    
    NSString *content = self.content;
    if (!content) {
        self.loaderIsFinished = YES;
        completionHandler(nil);
        return;
    } else if (self.title || self.image) {
        self.loaderIsFinished = YES;
        completionHandler(self.item);
        return;
    }
    
    NSError *error = nil;
    NSDataDetector *dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
    
    NSTextCheckingResult *firstMatch = [dataDetector firstMatchInString:content options:0 range:NSMakeRange(0, [content length])];
    if (firstMatch) {
        if (@available(iOS 13.0, *)) {
            LPMetadataProvider *metaDataProvider = [[LPMetadataProvider alloc]init];
            NSURL *url = firstMatch.URL;
            self.url = url;
            // Fetch the metadata from the main UI thread to avoid a crash.
            dispatch_async(dispatch_get_main_queue(), ^{
                [metaDataProvider startFetchingMetadataForURL:url completionHandler:^(LPLinkMetadata *fetchedLinkMetadata, NSError * error) {
                
                    self.title = fetchedLinkMetadata.title;
                
                    if (self.title) {
                        [self.cache setTitleWithObjectDescriptor:self.objectDescriptor title:self.title];
                    }
                
                    if (fetchedLinkMetadata.imageProvider) {
                        [fetchedLinkMetadata.imageProvider loadItemForTypeIdentifier:(NSString *)kUTTypeImage
                                                                             options:nil
                                                                   completionHandler:^(UIImage *image, NSError *error) {
                        
                            self.image = image;
                            if (self.image) {
                                [self.cache setImageWithObjectDescriptor:self.objectDescriptor image:self.image];
                            }
                            self.loaderIsFinished = YES;
                            completionHandler(self.item);
                            return;
                        }];
                    } else {
                        self.image = nil;
                        self.loaderIsFinished = YES;
                        completionHandler(self.item);
                        return;
                    }
                
                }];
            });
        }
    } else {
        self.loaderIsFinished = YES;
        completionHandler(self.item);
    }
}

@end

