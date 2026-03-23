/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <CocoaLumberjack.h>

#import "MnemonicCodeUtils.h"

#import <CommonCrypto/CommonDigest.h>
#import <Utils/NSString+Utils.h>


#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif


@interface MnemonicCodeUtils ()

@property (nonatomic, nonnull, readonly) NSMutableDictionary<NSString *, NSArray<NSString *> *> *wordLists;

@end


#undef LOG_TAG
#define LOG_TAG @"MnemonicCodeUtils"

@implementation MnemonicCodeUtils

- (nonnull instancetype) init {
    self = [super init];
    
    if (self) {
        _wordLists = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (nonnull NSArray<NSString *> *)xorAndMnemonicWithData:(nonnull NSData *)data locale:(nullable NSLocale *)locale {
    DDLogVerbose(@"%@ xorAndMnemonicWithData: %@ locale:%@", LOG_TAG, data, locale.languageCode);

    if (data.length != 32) {
        DDLogError(@"%@ data must contain exactly 32 bytes, got %lu bytes", LOG_TAG, (unsigned long)data.length);
        return [[NSArray alloc] init];
    }
    
    NSArray<NSString *> *wordList = [self getWordListWithLocale:locale];
    
    if (wordList.count == 0) {
        DDLogError(@"%@ couldn't get words for locale: %@", LOG_TAG, locale.languageCode);
        return [[NSArray alloc] init];
    }
    
    NSData *xoredData = [self xorBytesWithData:data];
    
    return [self getWordsWithData:xoredData wordList:wordList];
}

- (nonnull NSArray<NSString *> *) getSuggestionsWithPrefix:(nonnull NSString *)prefix locale:(nullable NSLocale *)locale {
    DDLogVerbose(@"%@ getSuggestionsWithPrefix: %@ locale:%@", LOG_TAG, prefix, locale.languageCode);

    NSArray<NSString *> *wordList = [self getWordListWithLocale:locale];
    NSMutableArray<NSString *> *suggestions = [NSMutableArray array];
        
    prefix = [[prefix stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
    
    if (prefix.length == 0) {
        return suggestions;
    }
    
    for (NSString *word in wordList) {
        if ([word hasPrefix:prefix]) {
            [suggestions addObject:word];
        } else if ([word compare:prefix] == NSOrderedDescending) {
            break;
        }
    }
    
    return suggestions;
}

/// Convert mnemonic word list to original entropy value.
- (nonnull NSData *) toEntropyWithWords:(nonnull NSArray<NSString *> *)words {
    DDLogVerbose(@"%@ toEntropyWithWords: %@", LOG_TAG, [words componentsJoinedByString:@" "]);
    
    if (words.count % 3 > 0 || words.count == 0) {
        DDLogError(@"%@ Word list size must be a multiple of three words, got %lu words", LOG_TAG, words.count);
        return [NSData data];
    }
    
    NSArray<NSString *> *wordList = [self getWordListWithLocale:nil];
    
    // Look up all the words in the list and construct the
    // concatenation of the original entropy and the checksum.
    
    int concatLenBits = (int)(words.count) * 11;
    bool *concatBits = malloc(concatLenBits * sizeof(bool));
    if (!concatBits) {
        DDLogError(@"%@ couldn't allocate memory for concatBits", LOG_TAG);
        return [NSData data];
    }
    
    int wordIndex = 0;
    
    for (NSString *word in words) {
        // Find the words index in the wordlist.
        NSUInteger ndx = [wordList indexOfObject:word.lowercaseString];
        if (ndx == NSNotFound) {
            DDLogError(@"%@ \"%@\" not found in wordlist", LOG_TAG, word);
            free(concatBits);
            return [NSData data];
        }
        
        for (int i = 0; i < 11; ++i) {
            concatBits[(wordIndex * 11) + i] = (ndx & (1 << (10 - i))) != 0;
        }
        ++wordIndex;
    }
    
    int checksumLengthBits = concatLenBits / 33;
    int entropyLengthBits = concatLenBits - checksumLengthBits;
    
    uint8_t *entropy = calloc(entropyLengthBits / 8, sizeof(uint8_t));
    if (!entropy) {
        DDLogError(@"%@ could not allocate memory for entropy", LOG_TAG);
        free(concatBits);
        return [NSData data];
    }
    
    for (int i = 0; i < entropyLengthBits / 8; ++i) {
        for (int j = 0; j < 8; ++j) {
            if (concatBits[(i * 8) + j]) {
                entropy[i] |= (uint8_t) (1 << (7 - j));
            }
        }
    }
    
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(entropy, (CC_LONG) (entropyLengthBits / 8),  hash.mutableBytes);
    
    bool *hashBits = [self bytesToBitsWithData:hash];
    
    for (int i = 0; i < checksumLengthBits; ++i) {
        if (concatBits[entropyLengthBits + i] != hashBits[i]) {
            DDLogError(@"%@ invalid checksum", LOG_TAG);
            free(concatBits);
            free(entropy);
            free(hashBits);
            return [NSData data];
        }
    }
    
    NSData *result = [NSData dataWithBytes:entropy length:(entropyLengthBits / 8)];
    
    free(concatBits);
    free(entropy);
    free(hashBits);
    
    return result;
}

/// Convert entropy data to mnemonic word list.
- (nonnull NSArray<NSString *> *)toMnemonicWithEntropy:(nonnull NSData *)entropy {
    DDLogVerbose(@"%@ toMnemonicWithEntropy: %@", LOG_TAG, entropy);

    if (entropy.length % 4 != 0 || entropy.length == 0) {
        DDLogError(@"%@ Entropy size must be a multiple of 32 bits, got %lu", LOG_TAG, entropy.length);
        return [NSArray array];
    }
    
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(entropy.bytes, (CC_LONG) entropy.length,  hash.mutableBytes);

    bool *hashBits = [self bytesToBitsWithData:hash];
    if (!hashBits) {
        DDLogError(@"%@ couldn't allocate memory for hashBits", LOG_TAG);
        return [NSArray array];
    }
    
    bool *entropyBits = [self bytesToBitsWithData:entropy];
    if (!entropyBits) {
        DDLogError(@"%@ couldn't allocate memory for entropyBits", LOG_TAG);
        free(hashBits);
        return [NSArray array];
    }
    
    int entropyLengthBits = (int)entropy.length * 8;
    int checksumLengthBits = entropyLengthBits / 32;
    int totalLengthBits = entropyLengthBits + checksumLengthBits;
    
    bool *concatBits = malloc(totalLengthBits * sizeof(bool));
    if (!concatBits) {
        DDLogError(@"%@ couldn't allocate memory for concatBits", LOG_TAG);
        free(concatBits);
        return [NSArray array];
    }
    
    memcpy(concatBits, entropyBits, entropyLengthBits * sizeof(bool));
    memcpy(concatBits + entropyLengthBits, hashBits, checksumLengthBits * sizeof(bool));
    
    NSArray<NSString *> *wordList = [self getWordListWithLocale:nil];
    NSMutableArray<NSString *> *words = [NSMutableArray array];
    
    int nWords = ((int)entropy.length * 8 + checksumLengthBits) / 11;
    for (int i = 0; i < nWords; ++i) {
        int index = 0;
        for (int j = 0; j < 11; ++j) {
            index <<=1;
            if (concatBits[(i * 11) + j]) {
                index |= 0x1;
            }
        }
        [words addObject:[wordList objectAtIndex:index]];
    }
    
    free(hashBits);
    free(entropyBits);
    free(concatBits);
    
    return words;
}


- (nonnull NSData *) xorBytesWithData:(nonnull NSData *)data {
    char *dataBytes = (char *)data.bytes;
    
    char *result = malloc(8);
    
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 8; j++) {
            result[j] = result[j] ^ dataBytes[i * 8 + j];
        }
    }
    
    NSData* res = [[NSData alloc] initWithBytes:result length:8];
    free(result);
    return res;
}

- (nonnull NSArray<NSString *> *) getWordsWithData:(nonnull NSData *)data wordList:(nonnull NSArray<NSString *> *)wordList {
    DDLogVerbose(@"%@ getWordsWithData: %@", LOG_TAG, data);

    bool *dataBits = [self bytesToBitsWithData:data];
    
    if (!dataBits) {
        DDLogError(@"%@ couldn't allocate memory for dataBits", LOG_TAG);
        return [NSArray array];
    }
    
    // We take these bits and split them into
    // groups of 11 bits. Each group encodes number from 0-2047
    // which is a position in a wordlist.  We convert numbers into
    // words and use joined words as mnemonic sentence.
    
    NSMutableArray<NSString *> *words = [[NSMutableArray alloc] init];
    int nWords = sizeof(dataBits) * 8 / 11;
    for (int i = 0; i < nWords; i++) {
        int index = 0;
        for (int j = 0; j < 11; ++j) {
            index <<= 1;
            if (dataBits[(i * 11) + j]) index |= 0x1;
        }
        [words addObject:wordList[index]];
    }
    
    free(dataBits);
    
    return words;
}

- (nullable bool *) bytesToBitsWithData:(nonnull NSData *)data {
    DDLogVerbose(@"%@ bytesToBitsWithData: %@", LOG_TAG, data);

    char *dataBytes = (char *)data.bytes;
    bool *bits = malloc(data.length * 8 * sizeof(bool));
    
    if (!bits) {
        DDLogError(@"%@ couldn't allocate memory for bits", LOG_TAG);
        return nil;
    }
    
    for (int i = 0; i < data.length; i++) {
        for (int j = 0; j < 8; j++) {
            bits[(i * 8) + j] = (dataBytes[i] & 0xff & (1 << (7 - j))) != 0;
        }
    }
    
    return bits;
}


- (nonnull NSArray<NSString *> *)getWordListWithLocale:(nullable NSLocale *)locale {
    DDLogVerbose(@"%@ getWordListWithLocale: %@", LOG_TAG, locale.languageCode);

    if (!locale) {
        locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en"];
    }
    
    NSArray<NSString *> *wordList;
    @synchronized (self.wordLists) {
        wordList = self.wordLists[locale.languageCode];
        
        if (!wordList) {
            wordList = [self loadWordListWithLocale:locale];
            self.wordLists[locale.languageCode] = wordList;
        }
    }
    
    return wordList;
}

- (nonnull NSArray<NSString *> *)loadWordListWithLocale:(nonnull NSLocale *)locale {
    
    NSString *fileName = TwinmeLocalizedString(@"wordlist", nil);
    NSString* path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"txt"];
    
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    
    if (!content || error) {
        DDLogError(@"%@ could not read content of file %@: %@", LOG_TAG, path, error.localizedDescription);
        return [[NSArray alloc] init];
    }
    
    return [content componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
}

@end
