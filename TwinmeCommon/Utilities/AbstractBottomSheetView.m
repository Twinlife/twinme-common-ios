/*
 *  Copyright (c) 2024-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeAttributes.h>

#import "AbstractBottomSheetView.h"

#import "Design.h"
#import "UIViewController+Utils.h"

#import <Utils/NSString+Utils.h>

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: AbstractBottomSheetView ()
//

@interface AbstractBottomSheetView ()<CAAnimationDelegate>

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *actionViewTopConstraint;
@property (weak, nonatomic) IBOutlet UIView *actionView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *slideMarkViewTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *slideMarkViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *slideMarkViewWidthConstraint;
@property (weak, nonatomic) IBOutlet UIView *slideMarkView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *iconViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *iconImageViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bulletViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bulletViewTrailingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *titleLabelLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *titleLabelTrailingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageLabelTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageLabelLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageLabelTrailingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *confirmViewTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *confirmViewWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *confirmLabelWidthConstraint;

@property (nonatomic) UIView *overlayView;

@end

//
// Implementation: AbstractBottomSheetView
//

#undef LOG_TAG
#define LOG_TAG @"AbstractBottomSheetView"

@implementation AbstractBottomSheetView

#pragma mark - Public methods

- (void)initWithTitle:(nonnull NSString *)title message:(nonnull NSString *)message avatar:(nullable UIImage *)avatar icon:(nullable UIImage *)icon {
    DDLogVerbose(@"%@ initWithTitle: %@ message: %@ avatar: %@ icon: %@", LOG_TAG, title, message, avatar, icon);
 
    self.titleLabel.text = title;
    self.messageLabel.text = message;
    
    if (avatar) {
        self.avatarView.image = avatar;
        self.avatarView.hidden = NO;
        
        if ([avatar isEqual:[TLTwinmeAttributes DEFAULT_GROUP_AVATAR]]) {
            self.avatarView.backgroundColor = Design.GREY_ITEM;
        } else {
            self.avatarView.backgroundColor = [UIColor clearColor];
        }
    } else {
        self.avatarView.hidden = YES;
    }
    
    if (icon) {
        self.iconImageView.image = icon;
        self.iconView.hidden = NO;
        self.bulletView.hidden = NO;
    } else {
        self.iconView.hidden = YES;
        self.bulletView.hidden = YES;
    }
}

- (void)setConfirmTitle:(nonnull NSString *)title {
    DDLogVerbose(@"%@ setConfirmTitle: %@", LOG_TAG, title);
    
    self.confirmLabel.text = title;
}

- (void)updateTitle:(nonnull NSMutableAttributedString *)title {
    DDLogVerbose(@"%@ updateTitle", LOG_TAG);
    
    self.titleLabel.text = nil;
    self.titleLabel.attributedText = title;
}

- (void)showConfirmView {
    DDLogVerbose(@"%@ showConfirmView", LOG_TAG);
    
    UIView *containerView = self.superview;
    if (!containerView) {
        return;
    }
    
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [self.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
        [self.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [self.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
    ]];
    
    [self updateFont];
    [self updateColor];
    
    [UIView animateWithDuration:Design.ANIMATION_VIEW_DURATION
                          delay:0
                        options:0
                     animations:^{
        self.overlayView.alpha = 0.3f;
        self.actionView.frame = CGRectMake(0, containerView.frame.size.height - self.actionView.frame.size.height, containerView.frame.size.width, self.actionView.frame.size.height);
    }
                     completion:nil];
}

- (void)closeConfirmView {
    DDLogVerbose(@"%@ closeConfirmView", LOG_TAG);
    
    [UIView animateWithDuration:Design.ANIMATION_VIEW_DURATION
                          delay:0
                        options:0
                     animations:^{
        self.overlayView.alpha = 0.f;
        self.actionView.frame = CGRectMake(0, self.superview.frame.size.height, self.superview.frame.size.width, self.actionView.frame.size.height);
    }
                     completion:^(BOOL finished) {
        [self finish];
        
        if ([self.bottomSheetViewDelegate respondsToSelector:@selector(didFinishCloseAnimation:)]) {
            [self.bottomSheetViewDelegate didFinishCloseAnimation:self];
        }
    }];
}

- (void)handleConfirmTapGesture:(UITapGestureRecognizer *)sender {
    DDLogVerbose(@"%@ handleConfirmTapGesture: %@", LOG_TAG, sender);
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        if ([self.bottomSheetViewDelegate respondsToSelector:@selector(didTapConfirm:)]) {
            [self.bottomSheetViewDelegate didTapConfirm:self];
        }
    }
}

- (void) initViews {
    DDLogVerbose(@"%@ initViews", LOG_TAG);
    
    self.userInteractionEnabled = YES;
    
    self.overlayView = [[UIView alloc]init];
    self.overlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.overlayView.alpha = .0f;
    self.overlayView.backgroundColor = [UIColor blackColor];
    
    [self insertSubview:self.overlayView atIndex:0];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.overlayView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.overlayView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.overlayView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.overlayView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];
    
    UITapGestureRecognizer *tapOverlayGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleCloseConfirmView:)];
    [self.overlayView addGestureRecognizer:tapOverlayGestureRecognizer];
    
    self.actionViewTopConstraint.constant *= Design.HEIGHT_RATIO;
    self.actionViewBottomConstraint.constant *= Design.WIDTH_RATIO;
    
    self.actionView.userInteractionEnabled = YES;
    self.actionView.backgroundColor = Design.POPUP_BACKGROUND_COLOR;
    self.actionView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.actionView.layer.cornerRadius = 40 * Design.HEIGHT_RATIO;
    self.actionView.clipsToBounds = YES;
        
    UISwipeGestureRecognizer *swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleCloseConfirmView:)];
    [swipeGestureRecognizer setDirection:(UISwipeGestureRecognizerDirectionDown)];
    [self.actionView addGestureRecognizer:swipeGestureRecognizer];
    
    self.slideMarkViewTopConstraint.constant *= Design.HEIGHT_RATIO;
    self.slideMarkViewHeightConstraint.constant *= Design.HEIGHT_RATIO;
    self.slideMarkViewWidthConstraint.constant *= Design.WIDTH_RATIO;
    self.slideMarkView.backgroundColor = [UIColor colorWithRed:244./255. green:244./255. blue:244./255. alpha:1.0];
    self.slideMarkView.layer.cornerRadius = self.slideMarkViewHeightConstraint.constant * 0.5;
    self.slideMarkView.clipsToBounds = YES;
    
    self.avatarContainerViewTopConstraint.constant *= Design.HEIGHT_RATIO;
    self.avatarContainerViewHeightConstraint.constant *= Design.HEIGHT_RATIO;
    
    self.avatarContainerView.clipsToBounds = YES;
    self.avatarContainerView.layer.cornerRadius = self.avatarContainerViewHeightConstraint.constant * 0.5f;
    self.avatarContainerView.layer.borderWidth = 3.f;
    self.avatarContainerView.layer.borderColor = [UIColor whiteColor].CGColor;

    self.avatarContainerView.layer.shadowOpacity = Design.SHADOW_OPACITY;
    self.avatarContainerView.layer.shadowOffset = Design.SHADOW_OFFSET;
    self.avatarContainerView.layer.shadowRadius = Design.SHADOW_RADIUS;
    self.avatarContainerView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.avatarContainerView.layer.masksToBounds = NO;
    
    self.avatarView.clipsToBounds = YES;
    self.avatarView.layer.cornerRadius = self.avatarContainerViewHeightConstraint.constant * 0.5f;

    self.iconViewHeightConstraint.constant *= Design.HEIGHT_RATIO;
   
    self.iconView.layer.cornerRadius = self.iconViewHeightConstraint.constant * 0.5f;
    self.iconView.layer.borderWidth = 3.f;
    self.iconView.layer.borderColor = [UIColor whiteColor].CGColor;
    
    self.iconView.layer.shadowOpacity = Design.SHADOW_OPACITY;
    self.iconView.layer.shadowOffset = Design.SHADOW_OFFSET;
    self.iconView.layer.shadowRadius = Design.SHADOW_RADIUS;
    self.iconView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.iconView.layer.masksToBounds = NO;
    
    self.iconImageViewHeightConstraint.constant *= Design.HEIGHT_RATIO;
    
    self.bulletViewHeightConstraint.constant *= Design.HEIGHT_RATIO;
    self.bulletViewTrailingConstraint.constant *= Design.WIDTH_RATIO;
    
    self.bulletView.clipsToBounds = YES;
    self.bulletView.layer.cornerRadius = self.bulletViewHeightConstraint.constant * 0.5f;
    self.bulletView.layer.borderWidth = 3.f;
    self.bulletView.layer.borderColor = [UIColor whiteColor].CGColor;
    
    self.titleLabelTopConstraint.constant *= Design.HEIGHT_RATIO;
    self.titleLabelLeadingConstraint.constant *= Design.WIDTH_RATIO;
    self.titleLabelTrailingConstraint.constant *= Design.WIDTH_RATIO;
    
    self.titleLabel.font = Design.FONT_MEDIUM40;
    self.titleLabel.textColor = Design.FONT_COLOR_DEFAULT;
    
    self.messageLabelLeadingConstraint.constant *= Design.WIDTH_RATIO;
    self.messageLabelTrailingConstraint.constant *= Design.WIDTH_RATIO;
    
    self.messageLabel.font = Design.FONT_MEDIUM38;
    self.messageLabel.textColor = Design.FONT_COLOR_GREY;
    
    self.confirmViewTopConstraint.constant *= Design.HEIGHT_RATIO;
    self.confirmViewHeightConstraint.constant *= Design.HEIGHT_RATIO;
    self.confirmViewWidthConstraint.constant *= Design.WIDTH_RATIO;
        
    self.confirmView.backgroundColor = Design.MAIN_COLOR;
    self.confirmView.userInteractionEnabled = YES;
    self.confirmView.layer.cornerRadius = Design.CONTAINER_RADIUS;
    self.confirmView.clipsToBounds = YES;
    self.confirmView.isAccessibilityElement = YES;
    [self.confirmView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleConfirmTapGesture:)]];
    
    self.confirmLabelWidthConstraint.constant *= Design.WIDTH_RATIO;
        
    self.confirmLabel.font = Design.FONT_BOLD36;
    self.confirmLabel.textColor = [UIColor whiteColor];
    self.confirmLabel.text = TwinmeLocalizedString(@"application_confirm", nil);
    
    self.cancelViewHeightConstraint.constant *= Design.HEIGHT_RATIO;
    
    UITapGestureRecognizer *cancelViewGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleCancelTapGesture:)];
    [self.cancelView addGestureRecognizer:cancelViewGestureRecognizer];
    
    UIWindow *window = [UIViewController currentWindow];
    if (window) {
        self.cancelViewBottomConstraint.constant = window.safeAreaInsets.bottom;
    } else {
        self.cancelViewBottomConstraint.constant = window.safeAreaInsets.bottom;
    }
    
    self.cancelLabel.font = Design.FONT_MEDIUM38;
    self.cancelLabel.textColor = Design.DELETE_COLOR_RED;
    self.cancelLabel.text = TwinmeLocalizedString(@"application_cancel", nil);
}

#pragma mark - Private methods

- (void)handleCancelTapGesture:(UITapGestureRecognizer *)sender {
    DDLogVerbose(@"%@ handleCancelTapGesture: %@", LOG_TAG, sender);
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        if ([self.bottomSheetViewDelegate respondsToSelector:@selector(didTapCancel:)]) {
            [self.bottomSheetViewDelegate didTapCancel:self];
        }
    }
}

- (void)handleCloseConfirmView:(UISwipeGestureRecognizer *)sender {
    DDLogVerbose(@"%@ handleCloseConfirmView: %@", LOG_TAG, sender);
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        if ([self.bottomSheetViewDelegate respondsToSelector:@selector(didClose:)]) {
            [self.bottomSheetViewDelegate didClose:self];
        }
    }
}

- (void)finish {
    DDLogVerbose(@"%@ finish", LOG_TAG);
    
}

- (void)updateFont {
    DDLogVerbose(@"%@ updateFont", LOG_TAG);
        
    if (!self.titleLabel.attributedText) {
        self.titleLabel.font = Design.FONT_BOLD44;
    }
    
    self.messageLabel.font = Design.FONT_MEDIUM40;
    self.confirmLabel.font = Design.FONT_BOLD36;
    self.cancelLabel.font = Design.FONT_BOLD36;
}

- (void)updateColor {
    DDLogVerbose(@"%@ updateColor", LOG_TAG);
    
    if (self.forceDarkMode) {
        self.actionView.backgroundColor = [UIColor colorWithRed:72./255. green:72./255. blue:72./255. alpha:1];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.cancelLabel.textColor = [UIColor whiteColor];
    } else {
        self.actionView.backgroundColor = Design.POPUP_BACKGROUND_COLOR;
        if (!self.titleLabel.attributedText) {
            self.titleLabel.textColor = Design.FONT_COLOR_DEFAULT;
        }
    }
    
    self.messageLabel.textColor = Design.FONT_COLOR_GREY;
}

@end
