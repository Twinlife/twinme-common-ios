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

@interface UIFAQArticle : NSObject

@property (nonatomic) int articleId;
@property (nonatomic, nonnull) NSString *question;
@property (nonatomic, nonnull) NSString *answer;
@property (nonatomic, nullable) NSString *image;
@property (nonatomic, nullable) NSString *video;
@property (nonatomic, nullable) NSArray *tags;

- (nonnull instancetype)init:(int)articleId question:(nonnull NSString *)question answer:(nonnull NSString *)answer image:(nullable NSString *)image video:(nullable NSString *)video tags:(nullable NSArray *)tags;

- (BOOL)containsSearchText:(nonnull NSString *)text;

@end
