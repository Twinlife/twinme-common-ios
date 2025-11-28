/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "AbstractTwinmeService.h"

//
// Protocol: ProxyServiceeDelegate
//

@class TLSNIProxyDescriptor;

@protocol ProxyServiceDelegate <AbstractTwinmeDelegate>

- (void)onAddProxy:(nonnull TLSNIProxyDescriptor *)proxyDescriptor;

- (void)onDeleteProxy:(nonnull TLSNIProxyDescriptor *)proxyDescriptor;

- (void)onErrorAddProxy;

- (void)onErrorAlreadyUsed;

- (void)onErrorLimitReached;

@optional - (void)onGetProxyUri:(nullable TLTwincodeURI *)twincodeURI proxyescriptor:(nonnull TLSNIProxyDescriptor *)proxyDescriptor;

@end

//
// Interface: ProxyService
//

@interface ProxyService : AbstractTwinmeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<ProxyServiceDelegate>)delegate;

- (void)getProxyURI:(nullable TLSNIProxyDescriptor *)proxyDescriptor;

- (void)verifyProxyURI:(nonnull NSURL *)proxyURI proxyDescriptor:(nullable TLSNIProxyDescriptor *)proxyDescriptor;

- (void)deleteProxy:(nonnull TLSNIProxyDescriptor *)proxyDescriptor;

@end
