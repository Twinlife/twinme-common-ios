/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

//
// Interface: WordCheckChallenge
//

@interface WordCheckChallenge : NSObject

@property (readonly) int index;
@property (readonly, nonnull) NSString *word;
@property (readonly) BOOL checker;


- (nonnull instancetype)initWithIndex:(int)index word:(nonnull NSString *)word checker:(BOOL)checker;

- (nonnull NSString *)toString;

@end
