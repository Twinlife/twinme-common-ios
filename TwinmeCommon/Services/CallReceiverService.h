/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: CallReceiverServiceDelegate
//

@class TLProfile;
@class TLSpace;
@class TLTwinmeContext;
@class TLTwincodeURI;

@protocol CallReceiverServiceDelegate <AbstractTwinmeDelegate>

- (void)onCreateCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onGetCallReceiver:(nullable TLCallReceiver *)callReceiver;

- (void)onGetTwincodeURI:(nonnull TLTwincodeURI *)uri;

- (void)onGetCallReceivers:(nonnull NSArray<TLCallReceiver *> *)callReceivers;

- (void)onDeleteCallReceiver:(nonnull NSUUID *)callReceiverId;

- (void)onUpdateCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onUpdateCallReceiverAvatar:(nonnull UIImage *)avatar;

- (void)onChangeCallReceiverTwincode:(nonnull TLCallReceiver *)callReceiver;

@end

//
// Interface: CallReceiverService
//

@interface CallReceiverService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<CallReceiverServiceDelegate>)delegate;

- (void)initWithCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)createCallReceiver:(nonnull NSString *)name description:(nullable NSString *)description identityName:(nullable NSString *)identityName identityDescription:(nullable NSString *)identityDescription avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar capabilities:(nullable TLCapabilities *)capabilities  space:(nonnull TLSpace *)space;

- (void)getCallReceiverWithCallReceiverId:(nonnull NSUUID *)callReceiverId;

- (void)getCallReceivers;

- (void)deleteCallReceiverWithCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)updateCallReceiverWithCallReceiver:(nonnull TLCallReceiver *)callReceiver name:(nonnull NSString *)name description:(nullable NSString *)description identityName:(nullable NSString *)identityName identityDescription:(nullable NSString *)identityDescription avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar capabilities:(nullable TLCapabilities *)capabilities;

- (void)changeCallReceiverTwincodeWithCallReceiver:(nonnull TLCallReceiver *)callReceiver;

@end
