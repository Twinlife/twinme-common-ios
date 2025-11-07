/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>

#import "DeleteAccountService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int DELETE_ACCOUNT = 1 << 0;
static const int DELETE_ACCOUNT_DONE = 1 << 1;

//
// Interface: DeleteAccountService ()
//

@class DeleteAccountServiceTwinmeContextDelegate;

@interface DeleteAccountService ()

@property (nonatomic) int work;

- (void)onOperation;

- (void)onDeleteAccount;

@end

//
// Interface: DeleteAccountServiceTwinmeContextDelegate
//

@interface DeleteAccountServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (instancetype)initWithService:(DeleteAccountService *)service;

@end

//
// Implementation: DeleteAccountServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"DeleteAccountServiceTwinmeContextDelegate"

@implementation DeleteAccountServiceTwinmeContextDelegate

- (instancetype)initWithService:(DeleteAccountService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onDeleteAccountWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ onDeleteAccountWithRequestId: %lld", LOG_TAG, requestId);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(DeleteAccountService *)self.service onDeleteAccount];
}

@end

//
// Implementation: DeleteAccountService
//

#undef LOG_TAG
#define LOG_TAG @"DeleteAccountService"

@implementation DeleteAccountService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <DeleteAccountServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[DeleteAccountServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

/**
 * The destructive and dangerous delete account operation.
 *
 * - delete the contacts,
 * - delete the groups,
 * - delete the profiles,
 * - delete the system account.
 */
- (void)deleteAccount {
    DDLogVerbose(@"%@ deleteAccount", LOG_TAG);
    
    self.work |= DELETE_ACCOUNT;
    self.state &= ~(DELETE_ACCOUNT | DELETE_ACCOUNT_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

#pragma mark - Private methods

- (void)onDeleteAccount {
    DDLogVerbose(@"%@ onDeleteAccount", LOG_TAG);
    
    self.state |= DELETE_ACCOUNT_DONE;
    
    if ([(id)self.delegate respondsToSelector:@selector(onDeleteAccount)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<DeleteAccountServiceDelegate>)self.delegate onDeleteAccount];
        });
    }
    [self onOperation];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    // We must delete the account.
    if ((self.work & DELETE_ACCOUNT) != 0) {
        if ((self.state & DELETE_ACCOUNT) == 0) {
            self.state |= DELETE_ACCOUNT;
            
            int64_t requestId = [self newOperation:DELETE_ACCOUNT];
            [self.twinmeContext deleteAccountWithRequestId:requestId];
            return;
        }
        if ((self.state & DELETE_ACCOUNT_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

@end
