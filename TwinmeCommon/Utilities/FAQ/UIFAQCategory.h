/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

//
// Interface: UIFAQArticle
//

@class UIFAQArticle;

@interface UIFAQCategory : NSObject

@property (nonatomic, nonnull) NSString *title;
@property (nonatomic, nonnull) NSMutableArray<UIFAQArticle *> *articles;

- (nonnull instancetype)initWithTitle:(nonnull NSString *)title articles:(nonnull NSMutableArray<UIFAQArticle *>*)articles;

- (void)addArticle:(nonnull UIFAQArticle *)article;

@end
