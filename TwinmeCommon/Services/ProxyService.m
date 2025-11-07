/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>

#import <Twinlife/TLConnectivityService.h>
#import <Twinlife/TLProxyDescriptor.h>

#import "ProxyService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: ProxyService ()
//

@interface ProxyService ()

@property (nonatomic) TLSNIProxyDescriptor *proxyDescriptor;

@end

//
// Implementation: ProxyService
//

#undef LOG_TAG
#define LOG_TAG @"ProxyService"

@implementation ProxyService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <ProxyServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    return self;
}

- (void)verifyProxyURI:(nonnull NSURL *)proxyURI proxyDescriptor:(nullable TLSNIProxyDescriptor *)proxyDescriptor {
    DDLogVerbose(@"%@ verifyProxyURI: %@ proxyDescriptor: %@", LOG_TAG, proxyURI, proxyDescriptor);
    
    self.proxyDescriptor = proxyDescriptor;
    
    [self parseUriWithUri:proxyURI withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI *twincodeURI) {
        [self onParseURI:errorCode uri:twincodeURI];
    }];
}

- (void)deleteProxy:(nonnull TLSNIProxyDescriptor *)proxyDescriptor {
    DDLogVerbose(@"%@ deleteProxy: %@", LOG_TAG, proxyDescriptor);
    
    dispatch_async(self.twinmeContext.twinlife.twinlifeQueue, ^{
        NSMutableArray *proxies = [[self.twinmeContext getConnectivityService] getUserProxies];
        [proxies removeObject:proxyDescriptor];
        [[self.twinmeContext getConnectivityService] saveWithUserProxies:proxies];
        
        if ([(id)self.delegate respondsToSelector:@selector(onDeleteProxy:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<ProxyServiceDelegate>)self.delegate onDeleteProxy:proxyDescriptor];
            });
        }
    });
}

#pragma mark - Private methods

- (void)onParseURI:(TLBaseServiceErrorCode)errorCode uri:(nullable TLTwincodeURI *)twincodeUri {
    DDLogVerbose(@"%@ onParseURI: %d twincodeUri: %@", LOG_TAG, errorCode, twincodeUri);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeUri) {
        if ([(id)self.delegate respondsToSelector:@selector(onErrorAddProxy)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<ProxyServiceDelegate>)self.delegate onErrorAddProxy];
            });
        }
    } else {
        NSMutableArray *proxies = [[self.twinmeContext getConnectivityService] getUserProxies];

        int proxyPosition = -1;
        for (int index = 0; index < [proxies count]; index++) {
            TLProxyDescriptor *proxy = [proxies objectAtIndex:index];
            if ([proxy isEqual:self.proxyDescriptor]) {
                proxyPosition = index;
                break;
            }
        }
        
        TLSNIProxyDescriptor *proxy = [TLSNIProxyDescriptor createWithProxyDescription:twincodeUri.uri];
        if (self.proxyDescriptor) {
            [proxies replaceObjectAtIndex:proxyPosition withObject:proxy];
        } else {
            [proxies addObject:proxy];
        }
        
        [[self.twinmeContext getConnectivityService] saveWithUserProxies:proxies];
        
        if ([(id)self.delegate respondsToSelector:@selector(onAddProxy:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<ProxyServiceDelegate>)self.delegate onAddProxy:proxy];
            });
        }
    }
}

@end
