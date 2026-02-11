/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinme/TLTwinmeContext.h>

#import "ApplicationDelegate.h"
#import "TwinmeApplication.h"

//
// Interface: AbstractTwinmeViewController
//

@class TLSpace;
@class UISpace;
@class TLProfile;
@class AbstractTwinmeService;

@interface AbstractTwinmeViewController : UIViewController

@property (nonatomic, weak, nullable) TwinmeApplication *twinmeApplication;
@property (nonatomic, weak, nullable) TLTwinmeContext *twinmeContext;

- (nullable TLSpace *)currentSpace;

#if defined(SKRED) || defined(TWINME)
- (nullable TLProfile *)defaultProfile;
#endif

- (BOOL)adjustStatusBarAppearance;

- (BOOL)darkStatusBar;

- (void)setNavigationTitle:(nonnull NSString *)title;

- (BOOL)hasCurrentSpaceNotification;

- (void)hapticFeedBack:(UIImpactFeedbackStyle)style;

- (void)updateFont;

- (void)updateColor;

#if defined(SKRED) || defined(TWINME_PLUS)
- (void)updateCurrentSpace;

- (void)getImageWithService:(nonnull AbstractTwinmeService *)service space:(nonnull TLSpace *)space withBlock:(nonnull void (^)(UIImage *_Nonnull image))block;

- (nonnull UISpace *)createUISpaceWithSpace:(nonnull TLSpace *)space service:(nonnull AbstractTwinmeService *)service withRefresh:(nonnull void (^)(void))block;

#endif

- (nonnull TLSpaceSettings *)currentSpaceSettings;

- (void)finish;

- (void)openSideMenu:(BOOL)animated;

- (void)setLeftBarButtonItem:(nonnull UIImage *)avatar;

- (void)setLeftBarButtonItem:(nonnull AbstractTwinmeService *)service profile:(nonnull TLProfile *)profile;

- (void)updateInCall;

- (void)showContactWithContact:(nonnull TLContact *)contact popToRoot:(BOOL)popToRoot;

- (void)showGroupWithGroup:(nonnull TLGroup *)group;

@end
