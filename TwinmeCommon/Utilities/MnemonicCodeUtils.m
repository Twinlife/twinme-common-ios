/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <CocoaLumberjack.h>

#import "MnemonicCodeUtils.h"

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
    bool *dataBits = [self bytesToBitsWithData:data];
    
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

- (bool *) bytesToBitsWithData:(nonnull NSData *)data {
    char *dataBytes = (char *)data.bytes;
    bool *bits = malloc(data.length * 8);
    
    for (int i = 0; i < strlen(dataBytes); i++) {
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
    NSString *resourcePath = [NSBundle.mainBundle pathForResource:locale.languageCode ofType:@"lproj"];
    NSBundle *bundle = [[NSBundle alloc] initWithPath:resourcePath];
    
    NSString *fileName = NSLocalizedStringWithDefaultValue(@"wordlist", nil, bundle, @"bip39_wordlist_en", @"");
    
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
