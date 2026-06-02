/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

@class UIFAQCategory;

typedef void (^FAQCompletion)(NSArray<UIFAQCategory *>  * _Nullable faqCategories, NSError * _Nullable error);

//
// Interface: FAQManager
//

@interface FAQManager : NSObject

- (void)loadFAQWithCompletion:(nonnull FAQCompletion)completion;

@end
