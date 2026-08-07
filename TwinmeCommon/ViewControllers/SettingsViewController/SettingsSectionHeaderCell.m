/*
 *  Copyright (c) 2019-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import "SettingsSectionHeaderCell.h"

#import <Utils/NSString+Utils.h>

#import "Design.h"
#import "PaddingLabel.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: SettingsSectionHeaderCell
//

@interface SettingsSectionHeaderCell()

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *titleLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *titleTrailingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *titleBottomConstraint;
@property (weak, nonatomic) IBOutlet UILabel *title;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *badgeLabelLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *badgeLabelHeightConstraint;
@property (weak, nonatomic) IBOutlet PaddingLabel *badgeLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *separatorViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UIView *separatorView;

@end

//
// Implementation: SettingsSectionHeaderCell
//

#undef LOG_TAG
#define LOG_TAG @"SettingsSectionHeaderCell"

@implementation SettingsSectionHeaderCell

- (void)awakeFromNib {
    DDLogVerbose(@"%@ awakeFromNib", LOG_TAG);
    
    [super awakeFromNib];
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    self.contentView.backgroundColor = Design.WHITE_COLOR;
    
    self.titleLeadingConstraint.constant *= Design.WIDTH_RATIO;
    self.titleTrailingConstraint.constant *= Design.WIDTH_RATIO;
    self.titleBottomConstraint.constant *= Design.HEIGHT_RATIO;
    self.title.font = Design.FONT_BOLD26;
    self.title.textColor = Design.FONT_COLOR_DEFAULT;
    
    self.badgeLabelLeadingConstraint.constant *= Design.WIDTH_RATIO;
    self.badgeLabelHeightConstraint.constant *= Design.HEIGHT_RATIO;
    
    self.badgeLabel.font = Design.FONT_MEDIUM32;
    self.badgeLabel.textColor = [UIColor whiteColor];
    
    self.badgeLabel.textAlignment = NSTextAlignmentCenter;
    self.badgeLabel.insets = UIEdgeInsetsMake(0, Design.TEXT_PADDING, 0, Design.TEXT_PADDING);
    
    self.badgeLabel.clipsToBounds = YES;
    self.badgeLabel.userInteractionEnabled = YES;
    self.badgeLabel.backgroundColor = Design.MAIN_COLOR;
    self.badgeLabel.layer.cornerRadius = self.badgeLabelHeightConstraint.constant * 0.5;
    
    UITapGestureRecognizer *badgeViewGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBadgeTapGesture:)];
    [self.badgeLabel addGestureRecognizer:badgeViewGestureRecognizer];
    
    self.separatorViewHeightConstraint.constant = Design.SEPARATOR_HEIGHT;
    self.separatorView.backgroundColor = Design.SEPARATOR_COLOR_GREY;
}

- (void)resetMargins {
    
    self.titleLeadingConstraint.constant = 0;
}

- (void)bindWithTitle:(NSString *)title backgroundColor:(UIColor *)backgroundColor hideSeparator:(BOOL)hideSeparator uppercaseString:(BOOL)uppercaseString {
    DDLogVerbose(@"%@ bindWithTitle: %@ backgroundColor: %@", LOG_TAG, title, backgroundColor);
    
    [self updateViews:title backgroundColor:backgroundColor hideSeparator:hideSeparator uppercaseString:uppercaseString badgeTitle:nil];
}

- (void)bindWithTitle:(nonnull NSString *)title backgroundColor:(nonnull UIColor *)backgroundColor hideSeparator:(BOOL)hideSeparator uppercaseString:(BOOL)uppercaseString badgeTitle:(nullable NSString *)badgeTitle {
    DDLogVerbose(@"%@ bindWithTitle: %@ backgroundColor: %@", LOG_TAG, title, backgroundColor);
 
    [self updateViews:title backgroundColor:backgroundColor hideSeparator:hideSeparator uppercaseString:uppercaseString badgeTitle:badgeTitle];
}

- (void)updateViews:(nonnull NSString *)title backgroundColor:(nonnull UIColor *)backgroundColor hideSeparator:(BOOL)hideSeparator uppercaseString:(BOOL)uppercaseString badgeTitle:(nullable NSString *)badgeTitle {
    
    if (uppercaseString) {
        self.title.text = title.uppercaseString;
    } else {
        self.title.text = title;
    }
    
    if (badgeTitle) {
        self.badgeLabel.hidden = NO;
        self.badgeLabel.text = badgeTitle;
    } else {
        self.badgeLabel.hidden = YES;
    }
    
    self.contentView.backgroundColor = backgroundColor;
    self.separatorView.hidden = hideSeparator;
    
    [self updateFont];
    [self updateColor];
}

- (void)handleBadgeTapGesture:(UITapGestureRecognizer *)sender {
    DDLogVerbose(@"%@ handleSettingsTapGesture: %@", LOG_TAG, sender);
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        if ([self.delegate respondsToSelector:@selector(didTapSectionBadge)]) {
            [self.delegate didTapSectionBadge];
        }
    }
}

- (void)updateFont {
    DDLogVerbose(@"%@ updateFont", LOG_TAG);
    
    self.title.font = Design.FONT_BOLD26;
    self.badgeLabel.font = Design.FONT_MEDIUM32;
}

- (void)updateColor {
    DDLogVerbose(@"%@ updateColor", LOG_TAG);
    
    self.title.textColor = Design.FONT_COLOR_DEFAULT;
    self.separatorView.backgroundColor = Design.SEPARATOR_COLOR_GREY;
    self.badgeLabel.backgroundColor = Design.MAIN_COLOR;
}

@end
