/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */


@interface MnemonicCodeUtils : NSObject

- (nonnull NSArray<NSString *> *) xorAndMnemonicWithData:(nonnull NSData *)data locale:(nullable NSLocale *)locale;

@end
