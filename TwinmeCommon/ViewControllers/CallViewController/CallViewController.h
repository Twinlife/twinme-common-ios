/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeViewController.h"

@class AbstractCallParticipantView;

//
// Protocol: CallParticipantViewDelegate
//

@protocol CallParticipantViewDelegate <NSObject>

- (void)didTapInfoCallParticipantView:(nonnull AbstractCallParticipantView *)callParticipantView;

- (void)didTapLocationCallParticipantView:(nonnull AbstractCallParticipantView *)callParticipantView;

- (void)didTapCallParticipantView:(nonnull AbstractCallParticipantView *)callParticipantView;

- (void)didDoubleTapCallParticipantView:(nonnull AbstractCallParticipantView *)callParticipantView;

- (void)didTapCancelCallParticipantView:(nonnull AbstractCallParticipantView *)callParticipantView;

- (void)didTapMinimizeSharingScreenCallParticipantView:(nonnull AbstractCallParticipantView *)callParticipantView;

- (void)didTapFullScreenSharingScreenCallParticipantView:(nonnull AbstractCallParticipantView *)callParticipantView;

- (void)didTapSwitchCameraCallParticipantView:(nonnull AbstractCallParticipantView *)callParticipantView;

- (void)didPinchLocaleVideo:(CGFloat)value gestureState:(UIGestureRecognizerState)state;

- (void)didPinchRemoteVideo:(CGFloat)value gestureState:(UIGestureRecognizerState)state;

@end

//
// Interface: CallViewController
//

@protocol TLOriginator;

@interface CallViewController : AbstractTwinmeViewController

- (void)initCallWithOriginator:(nonnull id<TLOriginator>)originator isVideoCall:(BOOL)isVideoCall;

- (void)startCallWithOriginator:(nonnull id<TLOriginator>)originator videoBell:(BOOL)videoBell isVideoCall:(BOOL)isVideoCall isCertifyCall:(BOOL)isCertifyCall;

- (void)back;

@end
