/*
 *  Copyright (c) 2021-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLProfile.h>
#import <Twinme/TLContact.h>

#import "EditContactCapabilitiesService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int UPDATE_CONTACT = 1 << 0;
static const int UPDATE_CONTACT_DONE = 1 << 1;

//
// Interface: EditContactCapabilitiesService ()
//

@class EditContactCapabilitiesServiceTwinmeContextDelegate;

@interface EditContactCapabilitiesService ()

@property (nonatomic, nullable) TLContact *contact;
@property (nonatomic, nullable) TLCapabilities *identityCapabilities;
@property (nonatomic, nullable) UIImage *avatar;
@property (nonatomic, nullable) UIImage *largeAvatar;

@property (nonatomic) int work;

- (void)onOperation;

- (void)onUpdateContact:(nonnull TLContact *)contact;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Interface: EditContactCapabilitiesServiceTwinmeContextDelegate
//

@interface EditContactCapabilitiesServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull EditContactCapabilitiesService *)service;

@end

//
// Implementation: EditContactCapabilitiesServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"EditContactCapabilitiesServiceTwinmeContextDelegate"

@implementation EditContactCapabilitiesServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull EditContactCapabilitiesService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(EditContactCapabilitiesService *)self.service onUpdateContact:contact];
}

@end

//
// Implementation: EditContactCapabilitiesService
//

#undef LOG_TAG
#define LOG_TAG @"EditContactCapabilitiesService"

@implementation EditContactCapabilitiesService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<EditContactCapabilitiesServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[EditContactCapabilitiesServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)updateIdentityWithContact:(nonnull TLContact *)contact identityCapabilities:(nullable TLCapabilities *)identityCapabilities {
    DDLogVerbose(@"%@ updateIdentityWithContact: %@ identityCapabilities: %@", LOG_TAG, contact, identityCapabilities);
    
    self.contact = contact;
    self.identityCapabilities = identityCapabilities;
    
    self.work |= UPDATE_CONTACT;
    self.state &= ~(UPDATE_CONTACT | UPDATE_CONTACT_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    // We must update identity for contact.
    if ((self.work & UPDATE_CONTACT) != 0) {
        if ((self.state & UPDATE_CONTACT) == 0) {
            self.state |= UPDATE_CONTACT;
            
            int64_t requestId = [self newOperation:UPDATE_CONTACT];
            [self.twinmeContext updateContactIdentityWithRequestId:requestId contact:self.contact identityName:self.contact.identityName identityAvatar:[self getImageWithContact:self.contact] identityLargeAvatar:self.largeAvatar description:self.contact.identityDescription capabilities:self.identityCapabilities];
            return;
        }
        
        if ((self.state & UPDATE_CONTACT_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step: everything done, we can hide the progress indicator.
    //
    
    [self hideProgressIndicator];
}

- (void)onUpdateContact:(TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContact: %@", LOG_TAG, contact);
    
    self.state |= UPDATE_CONTACT_DONE;
    
    [self runOnUpdateContact:contact avatar:nil];
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %i errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    if (errorCode == TLBaseServiceErrorCodeItemNotFound && operationId == UPDATE_CONTACT) {
        self.state |= UPDATE_CONTACT_DONE;
        [self runOnDeleteContact:self.contact.uuid];
        return;
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
