/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

//
// Interface: MainViewController
//

@class TLProfile;
@class TLSpace;
@class CallState;
@class TwinmeNavigationController;
@class CallState;

@protocol MainSpaceDelegate <NSObject>

- (void)editSpace:(nonnull TLSpace *)space;

@end

@interface MainViewController : UIViewController

@property (nonatomic, nullable) TLProfile *profile;
@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) NSURL *shareContentURL;

- (BOOL)isInitialized;

- (BOOL)hasCurrentSpaceNotification;

- (nonnull TwinmeNavigationController *)selectedViewController;

- (void)openSideMenu:(BOOL)animated;

- (void)closeSideMenu:(BOOL)animated;

- (void)updateColor;

- (void)initCallFloatingViewWithCall:(nonnull CallState *)call;

- (void)removeCallFloatingView;

- (void)selectTab:(int)index;

- (NSUInteger)getSelectedTab;

- (void)refreshTab;

#if defined(TWINME)
- (void)activeProfile:(nonnull TLProfile *)profile;
#endif

- (void)onOpenURL:(nonnull NSURL *)url;

#if defined(SKRED) || defined(TWINME_PLUS)
- (void)setCurrentSpace:(nonnull TLSpace *)space;

- (void)searchSecretSpace;

- (NSUInteger)numberSpaces:(BOOL)countSecretSpace;

- (nullable TLSpace *)getNextDefaultSpace:(nonnull TLSpace *)oldDefaultSpace;
#endif

@end
