/*
 *  Copyright (c) 2016-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <Twinlife/TLBaseService.h>

#import <Twinme/TLTwinmeApplication.h>
#import <Twinme/TLProfile.h>

#import <Notification/NotificationSettings.h>

#import "NotificationSound.h"
#import "Design.h"
#import "CoachMark.h"

///enum order has an impact to save and retrieve settings in NSUserDefault
#ifdef TWINME
typedef enum {
    DefaultTabProfiles,
    DefaultTabCalls,
    DefaultTabContacts,
    DefaultTabConversations,
    DefaultTabNotifications
} DefaultTab;
#else
typedef enum {
    DefaultTabSpaces,
    DefaultTabCalls,
    DefaultTabContacts,
    DefaultTabConversations,
    DefaultTabNotifications
} DefaultTab;
#endif

typedef enum {
    HapticFeedbackModeSystem,
    HapticFeedbackModeOn,
    HapticFeedbackModeOff
} HapticFeedbackMode;

typedef enum {
    QualityMediaStandard,
    QualityMediaOrginal
} QualityMedia;

typedef enum {
    OnboardingTypeCertifiedRelation,
    OnboardingTypeExternalCall,
    OnboardingTypeProfile,
    OnboardingTypeSpace,
    OnboardingTypeTransfer,
    OnboardingTypeEnterMiniCode,
    OnboardingTypeMiniCode,
    OnboardingTypeRemoteCamera,
    OnboardingTypeRemoteCameraSettings,
    OnboardingTypeTransferCall,
    OnboardingTypeProxy,
    OnboardingTypeCount
} OnboardingType;

@class TLSpaceSettings;
@class NotificationCenter;
@class LastVersionManager;
@class CoachMarkManager;

#define APP_ALBUM_NAME @"Skred"  // Name of the photo album to save or access photos.

#define DEFAULT_TIMEOUT_MESSAGE 30
#define MAX_CALL_GROUP_PARTICIPANTS 8

//
// Interface: TwinmeApplication
//

@interface TwinmeApplication : TLTwinmeApplication

@property NotificationCenter *notificationCenter;
@property NotificationSettings *settings;
@property LastVersionManager *lastVersionManager;
@property CoachMarkManager *coachMarkManager;

#ifdef TWINME_PLUS
//
//  First installation
//

- (BOOL)isFirstInstallation;
//TODO: there's already setFirstInstallation from Skred (with no getter?), keep only one?
- (void)setIsFirstInstallation:(BOOL)first;
#endif

//
// Welcome screen management
//

- (BOOL)showWelcomeScreen;

- (void)hideWelcomeScreen;

- (void)restoreWelcomeScreen;

//
// Settings preferences management
//

- (BOOL)settingWelcomeScreen;

- (void)setEnableWelcomeScreen:(BOOL)enable;

- (BOOL)hasNotificationSoundWithType:(NotificationSoundType)type;

- (void)setNotificationSoundWithType:(NotificationSoundType)type state:(BOOL)state;

- (BOOL)hasVibrationWithType:(NotificationSoundType)type;

- (void)setVibrationWithType:(NotificationSoundType)type state:(BOOL)state;

- (NotificationSound *)getNotificationSoundWithType:(NotificationSoundType)type;

- (void)setNotificationSoundWithType:(NotificationSoundType)type notificationSound:(NotificationSound *)notificationSound;

- (BOOL)hasSoundEnable;

- (void)setSoundEnableWithState:(BOOL)state;

- (BOOL)hasDisplayNotificationSender;

- (void)setDisplayNotificationSenderWithState:(BOOL)state;

- (BOOL)hasDisplayNotificationContent;

- (void)setDisplayNotificationContentWithState:(BOOL)state;

- (void)setDisplayNotificationLikeWithState:(BOOL)state;

- (BOOL)hasDisplayNotificationLike;

- (BOOL)allowCopyText;

- (void)setAllowCopyTextWithState:(BOOL)state;

- (BOOL)allowCopyFile;

- (void)setAllowCopyFileWithState:(BOOL)state;

- (TLSpaceSettings *)defaultSpaceSettings;

- (DefaultTab)defaultTab;

- (void)setDefaultTabWithTab:(DefaultTab)defaultTab;

- (QualityMedia)qualityMedia;

- (void)setQualityMediaWithQuality:(QualityMedia)qualityMedia;

- (TLDisplayCallsMode)displayCallsMode;

- (void)setDisplayCallsModeWithMode:(TLDisplayCallsMode)displayCallsMode;

- (TLProfileUpdateMode)profileUpdateMode;

- (void)setProfileUpdateModeWithMode:(TLProfileUpdateMode)profileUpdateMode;

//
// Utilities
//

- (CGFloat)getDefaultKeyboardHeight;

- (void)setDefaultKeyboardHeight:(CGFloat)keyboardHeight;

//
// Audio Player
//

- (CGFloat)getAudioPlayerRate;

- (void)updateAudioPlayerRate;

//
// Appearance
//

- (DisplayMode)displayMode;

- (void)setDisplayModeWithMode:(DisplayMode)displayMode;

#ifdef TWINME
- (BOOL)darkModeEnable;
#endif

#if defined(SKRED) || defined(TWINME_PLUS)
- (BOOL)darkModeEnable:(TLSpaceSettings *)spaceSettings;
#endif

- (FontSize)fontSize;

- (void)setFontSizeWithSize:(FontSize)fontSize;

- (EmojiSize)emojiSize;

- (void)setEmojiSizeWithSize:(EmojiSize)emojiSize;

- (BOOL)visualizationLink;

- (void)setVisualizationLinkWithState:(BOOL)state;

//
// Haptic Feedback
//

- (HapticFeedbackMode)hapticFeedbackMode;

- (void)setHapticFeedbackModeWithMode:(HapticFeedbackMode)hapticFeedbackMode;

//
// Call
//

/// Returns true if we have an active audio/video call.
- (BOOL)inCall;

- (BOOL)isVideoInFitMode;

- (void)setIsVideoInFitMode:(BOOL)state;

- (BOOL)askCallQualityWithCallDuration:(int)duration;

#if defined(SKRED) || defined(TWINME_PLUS)
//
// Privacy
//

- (BOOL)isScreenLock;

- (void)setScreenLockWithState:(BOOL)state;

- (int)getTimeoutScreenLock;

- (void)setTimeoutScreenLockWithTime:(int)time;

- (BOOL)isLastScreenHidden;

- (void)setHideLastScreenWithState:(BOOL)state;

- (void)setResignActiveDateWithDate:(NSDate *)date;

- (BOOL)showLockScreen;

- (BOOL)isRecentCallsHidden;

- (void)setHideRecentCallsWithState:(BOOL)state;

#endif

#if defined(SKRED)

//
// Ephemeral message
//

- (BOOL)allowEphemeralMessage;

- (void)setAllowEphemeralMessageWithState:(BOOL)state;

- (int)getTimeoutEphemeralMessage;

- (void)setTimeoutEphemeralMessageWithTime:(int)time;

//
// Invitation subscription
//

- (NSString *)getInvitationSubscriptionImage;

- (void)setInvitationSubscriptionImageWithImage:(NSString *)image;

- (NSUUID *)getInvitationSubscriptionTwincode;

- (void)setInvitationSubscriptionTwincodeWithTwincode:(NSUUID *)twincode;

//
// Space onboarding
//

- (BOOL)showSpaceOnboarding;

- (void)hideSpaceOnboarding;
#endif

#if defined(SKRED) || defined(TWINME_PLUS)
//
// Click to call description
//

- (BOOL)showClickToCallDescription;
#endif

//
// Access twinme management
//

- (BOOL)showConnectedMessage;

- (void)setShowConnectedMessage:(BOOL)enable;

#if defined(SKRED) || defined(TWINME)
//
// Skred plus and twinme upgrade
//

- (BOOL)canShowUpgradeScreenAtStart;

- (void)setCanShowUpgradeScreenWithState:(BOOL)state;

- (BOOL)showUpgradeScreen;
#endif

- (void)setFirstInstallation;

//
// Enable Notification
//

- (BOOL)showEnableNotificationScreen;

//
//  Update
//

- (BOOL)showWhatsNew;

//
//  CoachMark
//

- (BOOL)showCoachMark;

- (void)setShowCoachMark:(BOOL)showCoachMark;

- (BOOL)showCoachMark:(CoachMarkTag)coachMarkTag;

- (void)hideCoachMark:(CoachMarkTag)coachMarkTag;

- (void)hideAllCoachMark;

//
// Onboarding
//

- (BOOL)startOnboarding:(OnboardingType)onboardingType;

- (void)setShowOnboardingType:(OnboardingType)onboardingType state:(BOOL)state;

- (void)resetOnboarding;

- (BOOL)startWarningEditMessage;

- (void)setShowWarningEditMessageWithState:(BOOL)state;

//
// Group call animation
//

- (BOOL)showGroupCallAnimation;

- (void)hideGroupCallAnimation;


//
// Twinlife error management
//

- (void)onErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode message:(NSString *)message;

@end
