/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

//
// Protocol: BottomSheetViewDelegate
//

@class AbstractBottomSheetView;

@protocol BottomSheetViewDelegate <NSObject>

- (void)didTapConfirm:(nonnull AbstractBottomSheetView *)abstractBottomSheetView;

- (void)didTapCancel:(nonnull AbstractBottomSheetView *)abstractBottomSheetView;

- (void)didClose:(nonnull AbstractBottomSheetView *)abstractBottomSheetView;

- (void)didFinishCloseAnimation:(nonnull AbstractBottomSheetView *)abstractBottomSheetView;

@end

@interface AbstractBottomSheetView : UIView

@property (weak, nonatomic) id<BottomSheetViewDelegate> bottomSheetViewDelegate;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *actionViewBottomConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *avatarContainerViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *avatarContainerViewTopConstraint;
@property (weak, nonatomic) IBOutlet UIView *avatarContainerView;
@property (weak, nonatomic) IBOutlet UIImageView *avatarView;
@property (weak, nonatomic) IBOutlet UIView *iconView;
@property (weak, nonatomic) IBOutlet UIImageView *iconImageView;
@property (weak, nonatomic) IBOutlet UIView *bulletView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *titleLabelTopConstraint;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *confirmViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UIView *confirmView;
@property (weak, nonatomic) IBOutlet UILabel *confirmLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cancelViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cancelViewBottomConstraint;
@property (weak, nonatomic) IBOutlet UIView *cancelView;
@property (weak, nonatomic) IBOutlet UILabel *cancelLabel;
@property (nonatomic) BOOL forceDarkMode;

- (void)initWithTitle:(nonnull NSString *)title message:(nonnull NSString *)message avatar:(nullable UIImage *)avatar icon:(nullable UIImage *)icon;

- (void)setConfirmTitle:(nonnull NSString *)title;

- (void)updateTitle:(nonnull NSMutableAttributedString *)title;

- (void)initViews;

- (void)showConfirmView;

- (void)closeConfirmView;

- (void)handleConfirmTapGesture:(nonnull UITapGestureRecognizer *)sender;

- (void)finish;

- (void)updateColor;

- (void)updateFont;

@end
