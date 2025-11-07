/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <Twinme/TLTwinmeContext.h>

#import "CallParticipant.h"
#import "CallState.h"
#import "CallConnection.h"
#import "WordCheckChallenge.h"
#import "WordCheckResult.h"

typedef enum {
    KeyCheckResultUnknown,
    KeyCheckResultNo,
    KeyCheckResultYes
} KeyCheckResult;

//
// Interface: KeyCheckSessionHandler
//

@interface KeyCheckSessionHandler : NSObject

@property KeyCheckResult peerResult;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext callParticipantDelegate:(nullable id<CallParticipantDelegate>)callParticipantDelegate call:(nonnull CallState *)call language:(nonnull NSLocale *)language;

- (BOOL)initSession;

- (BOOL)initSessionWithCallConnection:(nonnull CallConnection *)callConnection;

- (void)setCallParticipantDelegateWithDelegate:(nullable id<CallParticipantDelegate>)callParticipantDelegate;

- (nullable WordCheckChallenge *)getCurrentWord;

- (nullable WordCheckChallenge *)getPeerError;

- (BOOL)isDone;

- (KeyCheckResult)isOK;

- (void)processLocalWordCheckResultWithResult:(nonnull WordCheckResult *)result;

- (void)onPeerWordCheckResultWithResult:(nonnull WordCheckResult *)result;

- (void)onOnKeyCheckInitiate;

- (void)onTerminateKeyCheckWithResult:(BOOL)result;

- (void)onTwincodeUriIQWithUri:(nonnull NSString *)uri;

@end
