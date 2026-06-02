/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "FAQManager.h"

#import "UIFAQArticle.h"
#import "UIFAQCategory.h"

#if defined(SKRED)
# define URL_FAQ @"https://skred.mobi/download/faq-skred-ios.json"
#elif defined(TWINME_PLUS)
# define URL_FAQ @"https://twin.me/download/faq-twinme-plus-ios.json"
#elif defined(TWINME)
# define URL_FAQ @"https://twin.me/download/faq-twinme-ios.json"
#elif defined(MYTWINLIFE) || defined(MYTWINLIFE_PLUS)
# define URL_FAQ @"https://invite.mytwinlife.net/download/faq-twinme-ios.json"
#else
 // DO NOT DEFINE URL_FAQ, compilation must fail if this is not handled by above checks.
#endif
#define FILE_FAQ @"faq.json"
#define ID_KEY @"id"
#define TITLE_KEY @"title"
#define ARTICLES_KEY @"articles"
#define DESCRIPTION_KEY @"description"
#define TAGS_KEY @"tags"
#define IMAGE_KEY @"images_dark"
#define VIDEO_KEY @"changes"
#define MIN_VERSION_KEY @"min_version"
#define MAX_VERSION_KEY @"max_version"

//
// Interface: FAQManager ()
//

@interface FAQManager ()

@end

//
// Implementation: FAQManager ()
//

@implementation FAQManager

- (void)loadFAQWithCompletion:(nonnull FAQCompletion)completion {
    
    NSURL *url = [NSURL URLWithString:URL_FAQ];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    
    NSURLSessionConfiguration *urlSessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    urlSessionConfiguration.requestCachePolicy = NSURLRequestReloadRevalidatingCacheData;
    NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:urlSessionConfiguration delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
    
    NSURLSessionDataTask *urlSessionDataTask = [urlSession dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        BOOL saveInCache = YES;
        if (!data) {
            data = [self loadFromCache];
            
            if (!data) {
                data = [self loadFromResources];
            }
            saveInCache = NO;
        }
                
        if (data) {
            NSError *jsonError = nil;
            id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

            if (jsonError || !jsonObject) {
                completion(nil, jsonError);
            } else {
                if (saveInCache) {
                    [self saveJSONFile:data];
                }
                NSMutableArray *faqCategories = [self parseJSON:jsonObject];
                completion(faqCategories, nil);
            }
        } else {
            completion(nil, error);
        }
    }];
    [urlSessionDataTask resume];
}

- (NSMutableArray *)parseJSON:(id)jsonObject {
    
    NSMutableArray *faqCategories = [[NSMutableArray alloc]init];
    
    if ([jsonObject isKindOfClass:[NSArray class]]) {
        
        NSArray *jsonArray = (NSArray *)jsonObject;
        
        for (id json in jsonArray) {
            if ([json isKindOfClass:[NSDictionary class]]) {
                NSDictionary *jsonDictionary = (NSDictionary *)json;
                
                NSString *title;
                NSMutableArray *articles = [[NSMutableArray alloc]init];
                
                if ([jsonDictionary objectForKey:TITLE_KEY] && [[jsonDictionary objectForKey:TITLE_KEY] isKindOfClass:[NSString class]]) {
                    title = [jsonDictionary objectForKey:TITLE_KEY];
                }
                
                if ([jsonDictionary objectForKey:ARTICLES_KEY] && [[jsonDictionary objectForKey:ARTICLES_KEY] isKindOfClass:[NSArray class]]) {
                    NSArray *jsonArray = [jsonDictionary objectForKey:ARTICLES_KEY];
                    
                    for (id article in jsonArray) {
                        NSDictionary *articleDictionary = (NSDictionary *)article;
                        
                        int articleId = -1;
                        NSString *question;
                        NSString *answer;
                        NSString *image;
                        NSString *video;
                        NSString *minVersion;
                        NSString *maxVersion;
                        NSArray *tags;
                        
                        if ([articleDictionary objectForKey:MIN_VERSION_KEY] && [[articleDictionary objectForKey:MIN_VERSION_KEY] isKindOfClass:[NSString class]]) {
                            minVersion = [articleDictionary objectForKey:MIN_VERSION_KEY];
                        }
                        
                        if ([articleDictionary objectForKey:MAX_VERSION_KEY] && [[articleDictionary objectForKey:MAX_VERSION_KEY] isKindOfClass:[NSString class]]) {
                            maxVersion = [articleDictionary objectForKey:MAX_VERSION_KEY];
                        }
                        
                        NSString *currentVersion  = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
                        if (minVersion && ![minVersion isEqualToString:@""] && [currentVersion compare:minVersion options:NSNumericSearch] == NSOrderedAscending) {
                            continue;
                        }
                        
                        if (maxVersion && ![maxVersion isEqualToString:@""] && [currentVersion compare:maxVersion options:NSNumericSearch] == NSOrderedDescending) {
                            continue;
                        }
                        
                        if ([articleDictionary objectForKey:ID_KEY] && [[articleDictionary objectForKey:ID_KEY] isKindOfClass:[NSNumber class]]) {
                            articleId = [[articleDictionary objectForKey:ID_KEY] intValue];
                        }
                        
                        if ([articleDictionary objectForKey:TITLE_KEY] && [[articleDictionary objectForKey:TITLE_KEY] isKindOfClass:[NSString class]]) {
                            question = [articleDictionary objectForKey:TITLE_KEY];
                        }
            
                        if ([articleDictionary objectForKey:DESCRIPTION_KEY] && [[articleDictionary objectForKey:DESCRIPTION_KEY] isKindOfClass:[NSString class]]) {
                            answer = [articleDictionary objectForKey:DESCRIPTION_KEY];
                        }
                        
                        if ([articleDictionary objectForKey:IMAGE_KEY] && [[articleDictionary objectForKey:IMAGE_KEY] isKindOfClass:[NSString class]]) {
                            image = [articleDictionary objectForKey:IMAGE_KEY];
                        }
                        
                        if ([articleDictionary objectForKey:VIDEO_KEY] && [[articleDictionary objectForKey:VIDEO_KEY] isKindOfClass:[NSString class]]) {
                            video = [articleDictionary objectForKey:VIDEO_KEY];
                        }
                        
                        if ([articleDictionary objectForKey:TAGS_KEY] && [[articleDictionary objectForKey:TAGS_KEY] isKindOfClass:[NSArray class]]) {
                            tags = [articleDictionary objectForKey:TAGS_KEY];
                        }
                        
                        if (question && answer) {
                            UIFAQArticle *faqArticle = [[UIFAQArticle alloc]init:articleId question:question answer:answer image:image video:video tags:tags];
                            [articles addObject:faqArticle];
                        }
                    }
                }
                
                UIFAQCategory *faqCategory = [[UIFAQCategory alloc]initWithTitle:title articles:articles];
                [faqCategories addObject:faqCategory];
            }
        }
    }
    
    return faqCategories;
}

- (nullable UIFAQCategory *)findFAQCategoryWithTag:(NSString *)tag categories:(NSMutableArray<UIFAQCategory *> *)categories {
    
    for (UIFAQCategory *faqCategory in categories) {
        if ([faqCategory.title isEqualToString:tag]) {
            return faqCategory;
        }
    }
    
    return nil;
}

- (void)saveJSONFile:(NSData *)data {
    
    NSString *cacheDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSString *filePath = [cacheDirectory stringByAppendingPathComponent:FILE_FAQ];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        
        if (error) {
            return;
        }
    }
    
    [data writeToURL:[NSURL fileURLWithPath:filePath] options:NSDataWritingAtomic error:nil];
}
    
- (nullable NSData *)loadFromCache {
    
    NSString *cacheDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSString *filePath = [cacheDirectory stringByAppendingPathComponent:FILE_FAQ];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        return [NSData dataWithContentsOfFile:filePath];
    }
    
    return nil;
}

- (nullable NSData *)loadFromResources {
    
    NSData *data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"faq" ofType:@"json"]];
    return data;
}

@end
