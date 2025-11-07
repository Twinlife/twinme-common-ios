/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <CocoaLumberjack.h>
#import <CommonCrypto/CommonDigest.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinme/TLContact.h>
#import "KeyCheckSessionHandler.h"
#import "MnemonicCodeUtils.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define NUM_WORDS 5


@interface NSValue (BOOL)
+ (instancetype)valuewithValue:(BOOL)value;
@property (readonly) BOOL boolValue;
@end

@implementation NSValue (BOOL)
+ (instancetype)valuewithValue:(BOOL)value
{
    return [self valueWithBytes:&value objCType:@encode(BOOL)];
}
- (BOOL) boolValue
{
    BOOL value;
    [self getValue:&value];
    return value;
}
@end

//
// Implementation: WordCheckChallenge
//

@implementation WordCheckChallenge

- (nonnull instancetype)initWithIndex:(int)index word:(nonnull NSString *)word checker:(BOOL)checker {
    self = [super init];
    
    if (self) {
        _index = index;
        _word = word;
        _checker = checker;
    }
    
    return self;
}

- (nonnull NSString *)toString {
    return [NSString stringWithFormat:@"WordCheckChallenge[index=%d word=%@ checker=%@]", self.index, self.word, self.checker ? @"YES" : @"NO"];
}

@end

//
// Implementation: WordCheckResult
//

@implementation WordCheckResult

- (nonnull instancetype)initWithWordIndex:(int)wordIndex ok:(BOOL)ok {
    self = [super init];
    
    if (self) {
        _wordIndex = wordIndex;
        _ok = ok;
    }
    
    return self;
}

- (nonnull NSString *)toString {
    return [NSString stringWithFormat:@"WordCheckResult[wordIndex=¨%d ok=%@]", self.wordIndex, self.ok ? @"YES" : @"NO"];
}

@end

//
// Interface: KeyCheckSession
//

@interface KeyCheckSession : NSObject

@property (nonnull, readonly) NSArray<NSString *> *words;
@property (readonly) BOOL initiator;
@property (nonnull, readonly) NSMutableArray<NSValue *> *results;
@property int currentWordIndex;
@property BOOL terminateSent;
@property KeyCheckResult peerResult;

- (nonnull instancetype)initWithWords:(nonnull NSArray *)words initiator:(BOOL)initiator;

- (nonnull WordCheckChallenge *)getCurrentWord;
- (nullable WordCheckChallenge *)getPeerError;
- (void)addLocalResultWithResult:(nonnull WordCheckResult *)result;
- (void)addPeerResultWithResult:(nonnull WordCheckResult *)result;
- (BOOL)getAndSetTerminateSent;
@end

#undef LOG_TAG
#define LOG_TAG @"KeyCheckSession"

//
// Implementation: KeyCheckSession
//


@implementation KeyCheckSession

- (nonnull instancetype)initWithWords:(nonnull NSArray<NSString *> *)words initiator:(BOOL)initiator{
    DDLogVerbose(@"%@ initWithWords: words=%@", LOG_TAG, words);
    
    if (words.count != NUM_WORDS) {
        DDLogError(@"%@ words must contain %d words but contains %lu words", LOG_TAG, NUM_WORDS, (unsigned long)words.count);
    }
    
    self = [super init];
    
    if (self) {
        _words = words;
        _currentWordIndex = 0;
        _results = [[NSMutableArray alloc] initWithCapacity:NUM_WORDS];
        _terminateSent = NO;
        _peerResult = KeyCheckResultUnknown;
        _initiator = initiator;
    }
    
    return self;
}

- (nonnull WordCheckChallenge *)getCurrentWord {
    DDLogVerbose(@"%@ getCurrentWord, currentWordIndex=%d", LOG_TAG, self.currentWordIndex);
    
    @synchronized (self) {
        if (self.results.count > self.currentWordIndex && self.currentWordIndex < NUM_WORDS - 1) {
            self.currentWordIndex++;
        }
        
        BOOL checker = self.initiator  == (self.currentWordIndex % 2 == 0);
        
        return [[WordCheckChallenge alloc] initWithIndex:self.currentWordIndex word:self.words[self.currentWordIndex] checker:checker];
    }
}

- (nullable WordCheckChallenge *)getPeerError {
    DDLogVerbose(@"%@ getPeerError", LOG_TAG);

    @synchronized (self) {
        int start = self.initiator ? 1 : 0;
        
        for (int i = start; i < self.results.count; i += 2 ) {
            if (self.results[i].boolValue == NO) {
                return [[WordCheckChallenge alloc] initWithIndex:i word:self.words[i] checker:NO];
            }
        }
        
        return nil;
    }
}

- (void)addLocalResultWithResult:(nonnull WordCheckResult *)result {
    DDLogVerbose(@"%@ addLocalResultWithResult: %@", LOG_TAG, result.toString);

    BOOL consistencyCheck = self.initiator == (result.wordIndex % 2 == 0);
    
    if (!consistencyCheck) {
        DDLogError(@"%@ Checker for %@ is the peer, but result was added as local, ignoring", LOG_TAG, result.toString);
        return;
    }
    
    [self addResult:result];
}

- (void)addPeerResultWithResult:(nonnull WordCheckResult *)result {
    DDLogVerbose(@"%@ addLocalResultWithResult: %@", LOG_TAG, result.toString);

    BOOL consistencyCheck = self.initiator != (result.wordIndex % 2 == 0);
    
    if (!consistencyCheck) {
        DDLogError(@"%@ Checker for %@ is local, but result was added as peer, ignoring", LOG_TAG, result.toString);
        return;
    }
    
    [self addResult:result];
}

- (BOOL)isDone {
    @synchronized (self) {
        return self.results.count == NUM_WORDS;
    }
}

- (KeyCheckResult)isOK {
    @synchronized (self) {
        if (!self.isDone) {
            return KeyCheckResultUnknown;
        }
        
        for (NSValue *result in self.results) {
            if (!result.boolValue) {
                return KeyCheckResultNo;
            }
        }
        
        return KeyCheckResultYes;
    }
}

- (BOOL)getAndSetTerminateSent {
    @synchronized (self) {
        BOOL previousValue = self.terminateSent;
        self.terminateSent = YES;
        return previousValue;
    }
}

- (void)addResult:(nonnull WordCheckResult *)result {
    DDLogVerbose(@"%@ addResult: %@", LOG_TAG, result.toString);
    
    @synchronized (self) {
        if (self.results.count > result.wordIndex) {
            DDLogVerbose(@"%@ word %d already checked: %@", LOG_TAG, result.wordIndex, self.results[result.wordIndex].boolValue ? @"YES" : @"NO");
        }
        
        self.results[result.wordIndex] = [NSValue valuewithValue:result.ok];
    }
}
@end

//
// Interface: KeyCheckSessionHandler
//

@interface KeyCheckSessionHandler ()

@property (nonnull, readonly) TLTwinmeContext *twinmeContext;
@property (nonnull, readonly) NSLocale *language;
@property (nullable) id<CallParticipantDelegate> callParticipantDelegate;
@property (nonnull, readonly) CallState *call;
@property (nullable) CallConnection *callConnection;
@property (nullable) KeyCheckSession *keyCheckSession;
@property (nullable) TLTwincodeURI *twincodeURI;

@end

//
// Implementation: KeyCheckSessionHandler
//

#undef LOG_TAG
#define LOG_TAG @"KeyCheckSessionHandler"

@implementation KeyCheckSessionHandler

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext callParticipantDelegate:(nullable id<CallParticipantDelegate>)callParticipantDelegate call:(nonnull CallState *)call language:(nonnull NSLocale *)language {
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;
        _callParticipantDelegate = callParticipantDelegate;
        _call = call;
        _language = language;
        _callConnection = nil;
        _twincodeURI = nil;
    }
    
    return self;
}

- (BOOL)initSession {
    DDLogVerbose(@"%@ initSession", LOG_TAG);
    
    if (self.call.isGroupCall) {
        DDLogError(@"%@ Key checking on group calls is not supported", LOG_TAG);
        return NO;
    }
    
    if (!self.call.originator || ![self.call.originator isKindOfClass:[TLContact class]]) {
        DDLogError(@"%@ Key checking only supported for contacts but originator is %@", LOG_TAG, [self.call.originator class]);
        return NO;
    }
    
    self.callConnection = self.call.initialConnection;
    
    if (!self.callConnection) {
        DDLogError(@"%@ call %@ has no CallConnection", LOG_TAG, self.call);
        return NO;
    }
    
    TLTwincodeOutbound *twincodeOutbound = self.call.originator.twincodeOutbound;
    
    if (!twincodeOutbound) {
        DDLogError(@"%@ Call originator %@ has no twincodeOutbound", LOG_TAG, self.call.originator);
        return NO;
    }
    
    if (!twincodeOutbound.isSigned) {
        DDLogError(@"%@ twincodeOutbound %@ is not signed", LOG_TAG, twincodeOutbound);
        return NO;
    }
    
    [self.twinmeContext.getTwincodeOutboundService createURIWithTwincodeKind:TLTwincodeURIKindAuthenticate twincodeOutbound:twincodeOutbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI * _Nullable twincodeUri) {
        if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeUri) {
            DDLogError(@"%@ Could not create twincode URI: %d", LOG_TAG, errorCode);
            return;
        }
        
        self.twincodeURI = twincodeUri;
        
        MnemonicCodeUtils *mNemonicCodeUtils = [[MnemonicCodeUtils alloc]init];
        
        NSMutableData *outData = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
        NSData *data = [self.twincodeURI.label dataUsingEncoding:NSUTF8StringEncoding];
        CC_SHA256(data.bytes, (CC_LONG) data.length,  outData.mutableBytes);
        
        NSArray<NSString *> *words = [mNemonicCodeUtils xorAndMnemonicWithData:outData locale:self.language];
        
        self.keyCheckSession = [[KeyCheckSession alloc] initWithWords:words initiator:YES];
        
        [self.callConnection sendKeyCheckInitiateIQWithLanguage:self.language];
    }];
    
    return YES;
}

- (BOOL)initSessionWithCallConnection:(nonnull CallConnection *)callConnection {
    DDLogVerbose(@"%@ initSessionWithCallConnection: %@", LOG_TAG, callConnection);
    
    self.callConnection = callConnection;
    
    if (self.call != callConnection.call || self.call.isGroupCall) {
        DDLogError(@"%@ Key checking on group calls is not supported", LOG_TAG);
        [self.callConnection sendOnKeyCheckInitiateIQWithErrorCode:TLBaseServiceErrorCodeBadRequest];
        return NO;
    }
    
    if (!self.call.originator || ![self.call.originator isKindOfClass:[TLContact class]]) {
        DDLogError(@"%@ Key checking only supported for contacts but originator is %@", LOG_TAG, [self.call.originator class]);
        return NO;
    }
    
    TLTwincodeOutbound *twincodeOutbound = callConnection.originator != nil ? callConnection.originator.twincodeOutbound : nil;
    
    if (!twincodeOutbound) {
        DDLogError(@"%@ Call originator %@ has no twincodeOutbound", LOG_TAG, self.call.originator);
        [self.callConnection sendOnKeyCheckInitiateIQWithErrorCode:TLBaseServiceErrorCodeLibraryError];
        return NO;
    }
    
    if (!twincodeOutbound.isSigned) {
        DDLogError(@"%@ twincodeOutbound %@ is not signed", LOG_TAG, twincodeOutbound);
        [self.callConnection sendOnKeyCheckInitiateIQWithErrorCode:TLBaseServiceErrorCodeNoPublicKey];
        return NO;
    }
    
    [self.twinmeContext.getTwincodeOutboundService createURIWithTwincodeKind:TLTwincodeURIKindAuthenticate twincodeOutbound:twincodeOutbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI * _Nullable twincodeUri) {
        if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeUri) {
            DDLogError(@"%@ Could not create twincode URI: %d", LOG_TAG, errorCode);
            [self.callConnection sendOnKeyCheckInitiateIQWithErrorCode:errorCode];
            return;
        }
        
        self.twincodeURI = twincodeUri;
        
        MnemonicCodeUtils *mNemonicCodeUtils = [[MnemonicCodeUtils alloc]init];
        
        NSMutableData *outData = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
        NSData *data = [self.twincodeURI.label dataUsingEncoding:NSUTF8StringEncoding];
        CC_SHA256(data.bytes, (CC_LONG) data.length,  outData.mutableBytes);
        
        NSArray<NSString *> *words = [mNemonicCodeUtils xorAndMnemonicWithData:outData locale:self.language];
        
        self.keyCheckSession = [[KeyCheckSession alloc] initWithWords:words initiator:NO];
        
        [self.callConnection sendOnKeyCheckInitiateIQWithErrorCode:TLBaseServiceErrorCodeSuccess];
        [self sendParticipantEventWithEvent:CallParticipantEventKeyCheckInitiate];
    }];
    
    return YES;
}

- (void)setCallParticipantDelegateWithDelegate:(nullable id<CallParticipantDelegate>)callParticipantDelegate {
    DDLogVerbose(@"%@ setCallParticipantDelegateWithDelegate: %@", LOG_TAG, self.callParticipantDelegate);
    
    if (!self.callParticipantDelegate) {
        self.callParticipantDelegate = callParticipantDelegate;
    }
}

- (nullable WordCheckChallenge *)getCurrentWord {
    DDLogVerbose(@"%@ getCurrentWord", LOG_TAG);
    
    if (!self.keyCheckSession) {
        DDLogVerbose(@"%@ Key check session not started", LOG_TAG);
        return nil;
    }
    
    return [self.keyCheckSession getCurrentWord];
}

- (nullable WordCheckChallenge *)getPeerError {
    DDLogVerbose(@"%@ getPeerError", LOG_TAG);
    
    if (!self.keyCheckSession) {
        DDLogVerbose(@"%@ Key check session not started", LOG_TAG);
        return nil;
    }
    
    return [self.keyCheckSession getPeerError];
}

- (BOOL)isDone {
    DDLogVerbose(@"%@ isDone", LOG_TAG);
    
    if (!self.keyCheckSession) {
        DDLogVerbose(@"%@ Key check session not started", LOG_TAG);
        return NO;
    }
    
    return [self.keyCheckSession isDone];
}

- (KeyCheckResult) isOK {
    DDLogVerbose(@"%@ isDone", LOG_TAG);
    
    if (!self.keyCheckSession) {
        DDLogVerbose(@"%@ Key check session not started", LOG_TAG);
        return KeyCheckResultUnknown;
    }
    
    return [self.keyCheckSession isOK];
}

- (void)processLocalWordCheckResultWithResult:(nonnull WordCheckResult *)result {
    DDLogVerbose(@"%@ processLocalWordCheckResultWithResult: %@", LOG_TAG, result.toString);
    
    if (!self.keyCheckSession || !self.callConnection) {
        DDLogVerbose(@"%@ Key check session not started", LOG_TAG);
        return;
    }

    WordCheckChallenge *currentWord = self.getCurrentWord;
    
    if (!currentWord || currentWord.index != result.wordIndex || !currentWord.checker) {
        DDLogError(@"%@ Got local result %@ but we're not the checker for the current word: %@", LOG_TAG, result.toString, currentWord.toString);
        return;
    }
    
    [self.keyCheckSession addLocalResultWithResult:result];
    [self.callConnection sendWordCheckResultIQWithResult:result];
    
    [self sendParticipantEventWithEvent:CallParticipantEventCurrentWordChanged];
    
    [self maybeSendTerminateKeyCheck];
}

- (void)onPeerWordCheckResultWithResult:(nonnull WordCheckResult *)result {
    DDLogVerbose(@"%@ onPeerWordCheckResultWithResult: %@", LOG_TAG, result.toString);
    
    if (!self.keyCheckSession || !self.callConnection) {
        DDLogVerbose(@"%@ Key check session not started", LOG_TAG);
        return;
    }

    WordCheckChallenge *currentWord = self.getCurrentWord;
    
    if (!currentWord || currentWord.index != result.wordIndex || currentWord.checker) {
        DDLogError(@"%@ Got peer result %@ but we're the checker for the current word: %@", LOG_TAG, result.toString, currentWord.toString);
        return;
    }
    
    [self.keyCheckSession addPeerResultWithResult:result];
    
    if (result.ok) {
        [self sendParticipantEventWithEvent:CallParticipantEventCurrentWordChanged];
    } else {
        [self sendParticipantEventWithEvent:CallParticipantEventWordCheckResultKO];
    }
    
    [self maybeSendTerminateKeyCheck];
}

- (void)onOnKeyCheckInitiate {
    DDLogVerbose(@"%@ onOnKeyCheckInitiate", LOG_TAG);
    
    if (!self.keyCheckSession || !self.callConnection) {
        DDLogVerbose(@"%@ Key check session not started", LOG_TAG);
        return;
    }
    
    [self sendParticipantEventWithEvent:CallParticipantEventOnKeyCheckInitiate];
}

- (void)onTerminateKeyCheckWithResult:(BOOL)result {
    DDLogVerbose(@"%@ onTerminateKeyCheckWithResult", LOG_TAG);
    
    if (!self.keyCheckSession || !self.callConnection) {
        DDLogVerbose(@"%@ Key check session not started", LOG_TAG);
        return;
    }
    
    // TODO: abort check session? send error to ViewController?
    if (![self isDone]) {
        DDLogError(@"%@ Got result %@ but we're not done yet", LOG_TAG, result ? @"YES":@"NO");
    }
    
    self.keyCheckSession.peerResult = result;
    
    if (self.keyCheckSession.terminateSent) {
        [self finishSession];
    }
}

- (void)onTwincodeUriIQWithUri:(nonnull NSString *)uri {
    DDLogVerbose(@"%@ onTwincodeUriIQWithUri: %@", LOG_TAG, uri);
   
    if (!self.keyCheckSession || !self.callConnection) {
        DDLogVerbose(@"%@ Key check session not started", LOG_TAG);
        return;
    }
    
    if ([self isOK] != KeyCheckResultYes) {
        DDLogError(@"%@ Peer sent a twincodeURI but the check is not OK! Ignoring", LOG_TAG);
        return;
    }

    [self.twinmeContext.getTwincodeOutboundService parseUriWithUri:[[NSURL alloc] initWithString:uri] withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI * _Nullable twincodeUri) {
        if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeUri) {
            DDLogError(@"%@ Could not parse URI: %@ errorCode: %d", LOG_TAG, uri, errorCode);
            return;
        }
        
        [self.twinmeContext verifyContactWithUri:twincodeUri trustMethod:TLTrustMethodVideo withBlock:^(TLBaseServiceErrorCode errorCode, TLContact * _Nullable contact) {
            if (errorCode != TLBaseServiceErrorCodeSuccess || !contact) {
                DDLogError(@"%@ Couldn't verify contact with twincodeUri: %@ errorCode: %d", LOG_TAG, uri, errorCode);
                return;
            }
            
            DDLogVerbose(@"%@ Contact is now verified !", LOG_TAG);
        }];
    }];
}

- (void)maybeSendTerminateKeyCheck {
    DDLogVerbose(@"%@ maybeSendTerminateKeyCheck", LOG_TAG);

    if (!self.keyCheckSession || !self.callConnection) {
        DDLogVerbose(@"%@ Key check session not started", LOG_TAG);
        return;
    }
    
    KeyCheckResult finalResult = [self isOK];
    
    if (finalResult != KeyCheckResultUnknown) {
        BOOL terminateSent = self.keyCheckSession.getAndSetTerminateSent;
        
        if (!terminateSent) {
            [self.callConnection sendTerminateKeyCheckIQWithResult:finalResult];
        }
        
        if (self.keyCheckSession.peerResult != KeyCheckResultUnknown) {
            [self finishSession];
        }
    }
    
}

- (void)finishSession {
    DDLogVerbose(@"%@ finishSession", LOG_TAG);

    // We have sent our Terminate and got the peer's Terminate => notify UI that we're done
    [self sendParticipantEventWithEvent:CallParticipantEventTerminateKeyCheck];
    
    if ([self isOK] == KeyCheckResultYes && self.twincodeURI) {
        NSArray *factories = [NSArray arrayWithObjects: [TLContact FACTORY], nil];
        TLFindResult *result = [self.twinmeContext.getRepositoryService findObjectWithSignature:self.twincodeURI.publicKey factories:factories];
        
        if (result.errorCode != TLBaseServiceErrorCodeSuccess || ![result.object isKindOfClass:TLContact.class]) {
            DDLogError(@"%@ Contact not found: errorCode=%d object=%@", LOG_TAG, result.errorCode, result.object);
            return;
        }
        
        TLContact *contact = (TLContact *)result.object;
        
        TLTwincodeOutbound *twincodeOutbound = contact.twincodeOutbound;
        TLTwincodeOutbound *peerTwincodeOutbound = contact.peerTwincodeOutbound;
        
        if (!twincodeOutbound) {
            DDLogError(@"%@ Contact %@ has no twincodeOutbound", LOG_TAG, contact);
            return;
        }
        
        if (!peerTwincodeOutbound) {
            DDLogError(@"%@ Contact %@ has no peerTwincodeOutbound", LOG_TAG, contact);
            return;
        }
        
        if ([self peerTrustsUs:contact]) {
            DDLogVerbose(@"%@ Peer already trusts us, nothing to do", LOG_TAG);
            return;
        }
        
        [self.twinmeContext.getTwincodeOutboundService createURIWithTwincodeKind:TLTwincodeURIKindAuthenticate twincodeOutbound:twincodeOutbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI * _Nullable twincodeUri) {
            if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeUri) {
                DDLogError(@"%@ Couldn't create twincodeURI for twincodeOutbound: %@, errorCode=%d", LOG_TAG, twincodeOutbound, errorCode);
                return;
            }
            
            if (self.callConnection) {
                [self.callConnection sendTwincodeUriIQWithUri:twincodeUri.uri];
            }
        }];
    }
}

- (BOOL) peerTrustsUs:(nonnull TLContact *)contact {
    TLTwincodeOutbound *twincodeOutbound = contact.twincodeOutbound;
    TLTwincodeOutbound *peerTwincodeOutbound = contact.peerTwincodeOutbound;
    
    if (!twincodeOutbound || !peerTwincodeOutbound) {
        return NO;
    }
        
    TLCapabilities *peerCaps = peerTwincodeOutbound.capabilities != nil ? [[TLCapabilities alloc] initWithCapabilities:peerTwincodeOutbound.capabilities] : [[TLCapabilities alloc] init];
    
    return [peerCaps isTrustedWithTwincodeId:twincodeOutbound.uuid];
}

- (void) sendParticipantEventWithEvent:(CallParticipantEvent)event {
    if (self.callConnection && self.callParticipantDelegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.callParticipantDelegate onEventWithParticipant:self.callConnection.mainParticipant event:event];
        });
    }
}

@end
