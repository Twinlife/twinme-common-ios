/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import "OnboardingConfirmView.h"

#import <Utils/NSString+Utils.h>

#import "Design.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const CGFloat CONTENT_MIN_HEIGHT = 634;

//
// Interface: OnboardingConfirmView ()
//

@interface OnboardingConfirmView ()

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *actionImageViewTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *actionImageViewWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *actionImageViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UIImageView *actionImageView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageTextViewTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageTextViewLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageTextViewTrailingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageTextViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UITextView *messageTextView;

@end

//
// Implementation: OnboardingConfirmView
//

#undef LOG_TAG
#define LOG_TAG @"OnboardingConfirmView"

@implementation OnboardingConfirmView

#pragma mark - UIView

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    NSArray *objects = [[NSBundle mainBundle] loadNibNamed:@"OnboardingConfirmView" owner:self options:nil];
    self = [objects objectAtIndex:0];
    self.translatesAutoresizingMaskIntoConstraints = NO;
    if (self) {
        [self initViews];
    }
    return self;
}

- (void)layoutSubviews {
    DDLogVerbose(@"%@ layoutSubviews", LOG_TAG);
    
    [self updateTextViewHeight];
}

- (void)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image action:(NSString *)action actionColor:(UIColor *)actionColor cancel:(NSString *)cancel {
    DDLogVerbose(@"%@ initWithTitle: %@ message: %@ image: %@ action: %@ actionColor: %@", LOG_TAG, title, message, image, action, actionColor);
    
    self.actionImageView.image = image;
    self.titleLabel.text = title;
    self.messageTextView.text = message;
    self.confirmLabel.text = action;
    
    if (cancel) {
        self.cancelLabel.text = cancel;
    }
    
    if (!title) {
        self.titleLabel.hidden = YES;
        self.titleLabelTopConstraint.constant = 0;
    } else {
        self.titleLabel.text = title;
    }
    
    if (actionColor) {
        self.confirmView.backgroundColor = actionColor;
    }
    
    if (!image) {
        self.actionImageView.hidden = YES;
        self.actionImageViewHeightConstraint.constant = 0;
        self.actionImageViewTopConstraint.constant = 0;
    }
    
    [self updateTextViewHeight];
}

- (void)hideCancelAction {
    DDLogVerbose(@"%@ hideCancelAction", LOG_TAG);
    
    self.cancelView.hidden = YES;
    self.cancelViewHeightConstraint.constant = 0;
    
    if (self.cancelViewBottomConstraint.constant == 0) {
        self.cancelViewBottomConstraint.constant = self.confirmViewHeightConstraint.constant;
    }
}

- (void)initViews {
    DDLogVerbose(@"%@ initViews", LOG_TAG);
    
    [super initViews];
        
    self.bulletView.hidden = YES;
    self.iconView.hidden = YES;
    self.avatarContainerView.hidden = YES;
    self.messageLabel.hidden = YES;
    self.messageLabel.hidden = YES;
    
    self.actionImageViewTopConstraint.constant *= Design.HEIGHT_RATIO;
    self.actionImageViewWidthConstraint.constant *= Design.WIDTH_RATIO;
    self.actionImageViewHeightConstraint.constant *= Design.HEIGHT_RATIO;
        
    self.messageTextViewTopConstraint.constant *= Design.HEIGHT_RATIO;
    self.messageTextViewLeadingConstraint.constant *= Design.WIDTH_RATIO;
    self.messageTextViewTrailingConstraint.constant *= Design.WIDTH_RATIO;
    
    self.messageTextView.font = Design.FONT_MEDIUM32;
    self.messageTextView.textColor = Design.FONT_COLOR_DEFAULT;
    self.messageTextView.editable = NO;
    self.messageTextView.selectable = NO;
    self.messageTextView.textContainerInset = UIEdgeInsetsZero;
    self.messageTextView.textContainer.lineFragmentPadding = 0;
    
    self.confirmView.backgroundColor = Design.MAIN_COLOR;
    
    self.confirmLabel.text = TwinmeLocalizedString(@"application_ok", nil);
    
    self.cancelLabel.textColor = Design.FONT_COLOR_DEFAULT;
    
    [self updateTextViewHeight];
}

- (void)updateTextViewHeight {
    DDLogVerbose(@"%@ updateTextViewHeight", LOG_TAG);
    
    CGRect titleRect;
    CGFloat textWidth = self.frame.size.width - self.messageTextViewLeadingConstraint.constant - self.messageTextViewTrailingConstraint.constant;
    
    if (self.titleLabel.attributedText) {
        titleRect =
          [self.titleLabel.attributedText boundingRectWithSize:CGSizeMake(textWidth, CGFLOAT_MAX)
          options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
          context:nil];
    } else {
        titleRect = [self.titleLabel.text boundingRectWithSize:CGSizeMake(textWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{
            NSFontAttributeName : Design.FONT_BOLD36
        } context:nil];
    }

    CGFloat maxHeight = self.frame.size.height - (CONTENT_MIN_HEIGHT * Design.HEIGHT_RATIO) - titleRect.size.height;

    CGRect messageRect = [self.messageTextView.text boundingRectWithSize:CGSizeMake(textWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{
        NSFontAttributeName : Design.FONT_MEDIUM32
    } context:nil];
    
    if (messageRect.size.height > maxHeight) {
        self.messageTextViewHeightConstraint.constant = maxHeight;
    } else {
        self.messageTextViewHeightConstraint.constant = messageRect.size.height;
    }
}

- (void)updateColor {
    DDLogVerbose(@"%@ updateColor", LOG_TAG);
    
    [super updateColor];
    
    if (!self.forceDarkMode) {
        self.messageTextView.textColor = Design.FONT_COLOR_DEFAULT;
        self.cancelLabel.textColor = Design.FONT_COLOR_DEFAULT;
    } else {
        self.messageTextView.textColor = [UIColor whiteColor];
    }
}

- (void)updateFont {
    DDLogVerbose(@"%@ updateFont", LOG_TAG);
    
    [super updateFont];
    
    if (!self.titleLabel.attributedText) {
        self.titleLabel.font = Design.FONT_BOLD36;
    }
    
    self.messageTextView.font = Design.FONT_MEDIUM32;
}

@end
