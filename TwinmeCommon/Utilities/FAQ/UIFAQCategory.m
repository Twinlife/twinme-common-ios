/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "UIFAQCategory.h"

//
// Implementation: UIFAQCategory
//

@implementation UIFAQCategory

- (nonnull instancetype)initWithTitle:(nonnull NSString *)title articles:(nonnull NSMutableArray<UIFAQArticle *>*)articles {
    
    self = [super init];
    
    if (self) {
        _title = title;
        _articles = articles;
    }
    return self;
}

- (void)addArticle:(nonnull UIFAQArticle *)article {
    
    [self.articles addObject:article];
}

@end
