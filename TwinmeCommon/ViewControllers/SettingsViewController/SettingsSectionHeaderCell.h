/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

//
// Protocol: SettingsSectionHeaderDelegate
//

@protocol SettingsSectionHeaderDelegate <NSObject>

- (void)didTapSectionBadge;

@end

//
// Interface: SettingsSectionHeaderCell
//

@interface SettingsSectionHeaderCell : UITableViewCell

@property (nonatomic, weak) id<SettingsSectionHeaderDelegate>delegate;

- (void)bindWithTitle:(nonnull NSString *)title backgroundColor:(nonnull UIColor *)backgroundColor hideSeparator:(BOOL)hideSeparator uppercaseString:(BOOL)uppercaseString;

- (void)bindWithTitle:(nonnull NSString *)title backgroundColor:(nonnull UIColor *)backgroundColor hideSeparator:(BOOL)hideSeparator uppercaseString:(BOOL)uppercaseString badgeTitle:(nullable NSString *)badgeTitle;

- (void)resetMargins;

@end
