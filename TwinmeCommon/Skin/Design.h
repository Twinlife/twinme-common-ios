/*
 *  Copyright (c) 2016-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#define PROPERTY_CONVERSATION_BACKGROUND_COLOR @"ConversationBackgroundColor"
#define PROPERTY_CONVERSATION_BACKGROUND_IMAGE @"ConversationBackgroundImage"
#define PROPERTY_CONVERSATION_BACKGROUND_TEXT @"ConversationBackgroundText"
#define PROPERTY_MESSAGE_BACKGROUND_COLOR @"MessageBackgroundColor"
#define PROPERTY_PEER_MESSAGE_BACKGROUND_COLOR @"PeerMessageBackgroundColor"
#define PROPERTY_MESSAGE_BORDER_COLOR @"MessageBorderColor"
#define PROPERTY_PEER_MESSAGE_BORDER_COLOR @"PeerMessageBorderColor"
#define PROPERTY_MESSAGE_TEXT_COLOR @"MessageTextColor"
#define PROPERTY_PEER_MESSAGE_TEXT_COLOR @"PeerMessageTextColor"
#define PROPERTY_DARK_CONVERSATION_BACKGROUND_COLOR @"DarkConversationBackgroundColor"
#define PROPERTY_DARK_CONVERSATION_BACKGROUND_IMAGE @"DarkConversationBackgroundImage"
#define PROPERTY_DARK_CONVERSATION_BACKGROUND_TEXT @"DarkConversationBackgroundText"
#define PROPERTY_DARK_MESSAGE_BACKGROUND_COLOR @"DarkMessageBackgroundColor"
#define PROPERTY_DARK_PEER_MESSAGE_BACKGROUND_COLOR @"DarkPeerMessageBackgroundColor"
#define PROPERTY_DARK_MESSAGE_BORDER_COLOR @"DarkMessageBorderColor"
#define PROPERTY_DARK_PEER_MESSAGE_BORDER_COLOR @"DarkPeerMessageBorderColor"
#define PROPERTY_DARK_MESSAGE_TEXT_COLOR @"DarkMessageTextColor"
#define PROPERTY_DARK_PEER_MESSAGE_TEXT_COLOR @"DarkPeerMessageTextColor"

//
// Interface: Design
//

typedef enum {
    DisplayModeSystem,
    DisplayModeLight,
    DisplayModeDark
} DisplayMode;

typedef enum {
    FontSizeSystem,
    FontSizeSmall,
    FontSizeLarge,
    FontSizeExtraLarge
} FontSize;

typedef enum {
    EmojiSizeSmall,
    EmojiSizeStandard,
    EmojiSizeLarge
} EmojiSize;

@interface Design : NSObject

+ (CGFloat)REFERENCE_HEIGHT;

+ (CGFloat)REFERENCE_WIDTH;

+ (CGFloat)DISPLAY_HEIGHT;

+ (CGFloat)DISPLAY_WIDTH;

+ (CGFloat)HEIGHT_RATIO;

+ (CGFloat)WIDTH_RATIO;

+ (CGFloat)MIN_RATIO;

+ (CGFloat)MAX_RATIO;

//
// Colors
//

+ (UIColor *)BACKGROUND_COLOR_WHITE_OPACITY85;

+ (UIColor *)BACKGROUND_COLOR_WHITE_OPACITY36;

+ (UIColor *)BACKGROUND_COLOR_WHITE_OPACITY11;

+ (UIColor *)BACKGROUND_COLOR_BLUE;

+ (UIColor *)BACKGROUND_COLOR_GREY;

+ (UIColor *)FONT_COLOR_DEFAULT;

+ (UIColor *)FONT_COLOR_GREY;

+ (UIColor *)FONT_COLOR_PROFILE_GREY;

+ (UIColor *)FONT_COLOR_GREEN;

+ (UIColor *)FONT_COLOR_RED;

+ (UIColor *)FONT_COLOR_BLUE;

+ (UIColor *)SHADOW_COLOR_DEFAULT;

+ (UIColor *)DELETE_COLOR_RED;

+ (UIColor *)DELETE_BORDER_COLOR_RED;

+ (UIColor *)BORDER_COLOR_GREY;

+ (UIColor *)SEPARATOR_COLOR_GREY;

+ (UIColor *)FONT_COLOR_DESCRIPTION;

+ (UIColor *)SEGMENTED_CONTROL_TINT_COLOR;

+ (UIColor *)CHECKMARK_BORDER_COLOR;

+ (UIColor *)GREY_BACKGROUND_COLOR;

+ (UIColor *)MENU_BACKGROUND_COLOR;

+ (UIColor *)MENU_REACTION_BACKGROUND_COLOR;

+ (UIColor *)ACTION_BORDER_COLOR;

//
// To be reviewed
//

+ (float)SHADOW_OPACITY;

+ (CGSize)SHADOW_OFFSET;

+ (CGFloat)SHADOW_RADIUS;

+ (UIColor *)BLUE_NORMAL;

+ (UIColor *)GREY_ITEM;

+ (UIColor *)WHITE_COLOR;

+ (UIColor *)WHITE_COLOR_20_OPACITY;

+ (UIColor *)BLACK_COLOR;

+ (UIColor *)LIGHT_GREY_BACKGROUND_COLOR;

+ (UIColor *)NAVIGATION_BACKGROUND_COLOR;

+ (UIColor *)POPUP_BACKGROUND_COLOR;

+ (UIColor *)SPLASHSCREEN_LOGO_COLOR;

+ (UIColor *)PLACEHOLDER_COLOR;

+ (UIColor *)SWITCH_BORDER_COLOR;

+ (UIColor *)AUDIO_CALL_COLOR;

+ (UIColor *)VIDEO_CALL_COLOR;

+ (UIColor *)CHAT_COLOR;

+ (UIColor *)BUTTON_RED_COLOR;

+ (UIColor *)BUTTON_GREEN_COLOR;

+ (UIColor *)ACTION_CALL_COLOR;

+ (UIColor *)ACTION_IMAGE_CALL_COLOR;

+ (UIColor *)EDIT_AVATAR_BACKGROUND_COLOR;

+ (UIColor *)EDIT_AVATAR_IMAGE_COLOR;

+ (UIColor *)CONVERSATION_BACKGROUND_COLOR;

+ (UIColor *)TEXTFIELD_CONVERSATION_BACKGROUND_COLOR;

+ (UIColor *)TEXTFIELD_BACKGROUND_COLOR;

+ (UIColor *)TEXTFIELD_POPUP_BACKGROUND_COLOR;

+ (UIColor *)NAVIGATION_BAR_BACKGROUND_COLOR;

+ (UIColor *)ITEM_BORDER_COLOR;

+ (UIColor *)MAIN_COLOR;

+ (UIColor *)ACCESSORY_COLOR;

+ (UIColor *)TIME_COLOR;

+ (UIColor *)REPLY_FONT_COLOR;

+ (UIColor *)REPLY_BACKGROUND_COLOR;

+ (UIColor *)FORWARD_ITEM_COLOR;

+ (UIColor *)FORWARD_BORDER_COLOR;

+ (UIColor *)FORWARD_COMMENT_COLOR;

+ (UIColor *)OVERLAY_COLOR;

+ (UIColor *)AUDIO_TRACK_COLOR;

+ (UIColor *)PEER_AUDIO_TRACK_COLOR;

+ (UIColor *)UNSELECTED_TAB_COLOR;

+ (UIColor *)CUSTOM_TAB_BACKGROUND_COLOR;

+ (UIColor *)ZOOM_COLOR;

#if defined(SKRED)

+ (NSArray<UIColor *> *)colorsForDigit:(NSInteger)digit;

+ (UIColor *)ITEM_BACKGROUND_COLOR;

+ (UIColor *)ITEM_FONT_COLOR;

+ (UIColor *)SHADOW_COLOR;

#endif

#if defined(SKRED) || defined(TWINME_PLUS)

+ (UIColor *)BACKGROUND_SPACE_AVATAR_COLOR;

+ (NSMutableArray *)SPACES_COLOR;

+ (UIColor *)TEXTFIELD_POPUP_BACKGROUND_COLOR;

#else
+ (NSMutableArray *)COLORS;
#endif

+ (NSArray *)BACKGROUND_GRADIENT_COLORS_BLACK;

+ (NSString *)MAIN_STYLE;

+ (NSString *)DEFAULT_COLOR;

+ (void)setMainColor:(NSString *)mainColor;

#if defined(SKRED)

+ (BOOL)isDarkMode;

+ (NSArray *)BUTTON_GRADIENT_COLORS_GREEN;

+ (UIImage *)defaultBackgroundWithImage:(UIImage *)image;

#endif

#if defined(SKRED) || defined(TWINME_PLUS)
+ (void)setupColors:(DisplayMode)displayMode;

#else
+ (void)setupColors;
#endif

//
// Fonts
//

+ (UIFont *)FONT_REGULAR16;

+ (UIFont *)FONT_REGULAR20;

+ (UIFont *)FONT_REGULAR22;

+ (UIFont *)FONT_REGULAR24;

+ (UIFont *)FONT_REGULAR26;

+ (UIFont *)FONT_REGULAR28;

+ (UIFont *)FONT_REGULAR30;

+ (UIFont *)FONT_REGULAR32;

+ (UIFont *)FONT_REGULAR34;

+ (UIFont *)FONT_REGULAR36;

+ (UIFont *)FONT_REGULAR40;

+ (UIFont *)FONT_REGULAR44;

+ (UIFont *)FONT_REGULAR50;

+ (UIFont *)FONT_REGULAR58;

+ (UIFont *)FONT_REGULAR64;

+ (UIFont *)FONT_REGULAR68;

#if defined(SKRED)
+ (UIFont *)FONT_REGULAR88;
#endif

+ (UIFont *)FONT_MEDIUM16;

+ (UIFont *)FONT_MEDIUM20;

+ (UIFont *)FONT_MEDIUM24;

+ (UIFont *)FONT_MEDIUM26;

+ (UIFont *)FONT_MEDIUM28;

+ (UIFont *)FONT_MEDIUM30;

+ (UIFont *)FONT_MEDIUM32;

+ (UIFont *)FONT_MEDIUM34;

+ (UIFont *)FONT_MEDIUM36;

+ (UIFont *)FONT_MEDIUM38;

+ (UIFont *)FONT_MEDIUM40;

+ (UIFont *)FONT_MEDIUM42;

+ (UIFont *)FONT_MEDIUM44;

+ (UIFont *)FONT_MEDIUM54;

+ (UIFont *)FONT_MEDIUM_ITALIC28;

+ (UIFont *)FONT_MEDIUM_ITALIC36;

+ (UIFont *)FONT_MEDIUM_ITALIC40;

+ (UIFont *)FONT_BOLD20;

+ (UIFont *)FONT_BOLD26;

+ (UIFont *)FONT_BOLD28;

#if defined(SKRED)
+ (UIFont *)FONT_BOLD32;
#endif

+ (UIFont *)FONT_BOLD34;

+ (UIFont *)FONT_BOLD36;

+ (UIFont *)FONT_BOLD44;

#if defined(SKRED)
+ (UIFont *)FONT_BOLD54;
#endif

+ (UIFont *)FONT_BOLD68;

+ (UIFont *)FONT_BOLD88;

+ (void)scaleEdgeInsetVertically:(UIButton *)button;

+ (void)scaleEdgeInsetHorizontally:(UIButton *)button;

+ (void)setupFont;

+ (CGSize)switchSize;

//
// Unicode Character
//

+ (NSString *)PLUS_SIGN;

//
// Size
//

+ (CGFloat)SEPARATOR_HEIGHT;

+ (CGFloat)ITEM_BORDER_WIDTH;

+ (CGFloat)AVATAR_HEIGHT;

+ (CGFloat)AVATAR_LEADING;

+ (CGFloat)NAME_TRAILING;

+ (CGFloat)ACCESSORY_HEIGHT;

+ (CGFloat)CERTIFIED_HEIGHT;

+ (CGFloat)CELL_HEIGHT;

+ (CGFloat)DESCRIPTION_HEIGHT;

+ (CGFloat)SETTING_CELL_HEIGHT;

+ (CGFloat)SETTING_SECTION_HEIGHT;

+ (CGFloat)INVITATION_LINE_SPACING;

+ (CGFloat)STANDARD_NAVIGATION_BAR_HEIGHT;

+ (CGFloat)TEXT_WIDTH_PADDING;

+ (CGFloat)TEXT_HEIGHT_PADDING;

+ (CGFloat)MESSAGE_CELL_MAX_WIDTH;

+ (CGFloat)PEER_MESSAGE_CELL_MAX_WIDTH;

+ (CGFloat)REPLY_IMAGE_MAX_WIDTH;

+ (CGFloat)REPLY_IMAGE_MAX_HEIGHT;

+ (CGFloat)REPLY_VIEW_IMAGE_TOP;

+ (CGFloat)SWIPE_WIDTH_TO_REPLY;

+ (CGFloat)PROGRESS_VIEW_SCALE;

+ (CGFloat)CHECKMARK_BORDER_WIDTH;

+ (CGFloat)IMAGE_CELL_MAX_WIDTH;

+ (CGFloat)IMAGE_CELL_MAX_HEIGHT;

+ (CGFloat)FORWARDED_IMAGE_CELL_MAX_HEIGHT;

+ (CGFloat)FORWARDED_SMALL_IMAGE_CELL_MAX_HEIGHT;

+ (CGFloat)ANNOTATION_CELL_WIDTH_NORMAL;

+ (CGFloat)ANNOTATION_CELL_WIDTH_LARGE;

+ (CGFloat)BUTTON_PADDING;

+ (CGFloat)TEXT_PADDING;

//
// Radius
//

+ (CGFloat)CONTAINER_RADIUS;

+ (CGFloat)POPUP_RADIUS;

#if defined(SKRED) || defined(TWINME_PLUS)
+ (CGFloat)SPACE_RADIUS_RATIO;
#endif

//
// Emoji
//

+ (CFMutableCharacterSetRef)EMOJI_CHARACTER_SET;

+ (UIFont *)getEmojiFont:(int)nbEmoji;

+ (UIFont *)getSampleEmojiFont:(EmojiSize)emojiSize;

//
// Animation show / close view like AbstractConfimeView
//

+ (CGFloat)ANIMATION_VIEW_DURATION;

@end
