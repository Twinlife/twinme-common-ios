/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

//
// Interface: WordCheckResult
//

@interface WordCheckResult : NSObject

@property (readonly) int wordIndex;
@property (readonly) BOOL ok;

- (nonnull instancetype)initWithWordIndex:(int)wordIndex ok:(BOOL)ok;

- (nonnull NSString *)toString;

@end
