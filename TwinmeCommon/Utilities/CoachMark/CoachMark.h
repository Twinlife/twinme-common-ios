/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

typedef enum {
    TAG_COACH_MARK_CONVERSATION_EPHEMERAL,
    TAG_COACH_MARK_ADD_PARTICIPANT_TO_CALL,
    TAG_COACH_MARK_PRIVACY,
    TAG_COACH_MARK_CONTACT_CAPABILITIES,
    TAG_COACH_MARK_CREATE_SPACE
} CoachMarkTag;

@interface CoachMark : NSObject

- (nonnull instancetype)initWithMessage:(nonnull NSString *)message tag:(CoachMarkTag)tag alignLeft:(BOOL)alignLeft onTop:(BOOL)onTop featureRect:(CGRect)featureRect featureRadius:(CGFloat)featureRadius;

@property (nullable) NSString *message;
@property (nonatomic) BOOL alignLeft;
@property (nonatomic) BOOL onTop;
@property (nonatomic) CoachMarkTag coachMarkTag;
@property (nonatomic) CGRect featureRect;
@property (nonatomic) CGFloat featureRadius;

@end
