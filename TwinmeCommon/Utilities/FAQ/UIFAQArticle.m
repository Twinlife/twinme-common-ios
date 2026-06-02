/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "UIFAQArticle.h"

//
// Implementation: UIFAQArticle
//

@implementation UIFAQArticle

- (nonnull instancetype)init:(int)articleId question:(nonnull NSString *)question answer:(nonnull NSString *)answer image:(nullable NSString *)image video:(nullable NSString *)video tags:(nullable NSArray *)tags {
    
    self = [super init];
    
    if (self) {
        _articleId = articleId;
        _question = question;
        _answer = answer;
        _image = image;
        _video = video;
        _tags = tags;
    }
    return self;
}

- (BOOL)containsSearchText:(nonnull NSString *)text {
    
    NSString *searchText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([searchText isEqualToString:@""]) {
        return NO;
    }

    if ([self searchInString:self.question containsTerm:searchText]) {
        return YES;
    }
    
    if ([self searchInString:self.answer containsTerm:searchText]) {
        return YES;
    }

    for (NSString *tag in self.tags) {
        if ([self searchInString:tag containsTerm:searchText]) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)searchInString:(nullable NSString *)string containsTerm:(nonnull NSString *)text {
    
    return string && [string rangeOfString:text options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound;
}

@end
