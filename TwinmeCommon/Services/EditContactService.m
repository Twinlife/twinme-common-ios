/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinlife/TLImageService.h>
#import <Twinme/TLContact.h>

#import "EditContactService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

// Last operation of ShowContactService is 1 << 5.
static const int UPDATE_CONTACT = 1 << 10;
static const int UPDATE_CONTACT_DONE = 1 << 11;

//
// Interface: EditContactService ()
//

@interface EditContactService ()

@property (nonatomic, nullable) NSString *contactName;
@property (nonatomic, nullable) NSString *contactDescription;

- (void)onOperation;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Interface: EditContactServiceTwinmeContextDelegate
//

@interface EditContactServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull EditContactService *)service;

@end

//
// Implementation: EditContactService
//

#undef LOG_TAG
#define LOG_TAG @"EditContactService"

@implementation EditContactService

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext delegate:(id<EditContactServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext delegate:delegate];
    return self;
}

- (void)updateContactWithContact:(TLContact *)contact contactName:(NSString *)contactName contactDescription:(NSString *)contactDescription {
    DDLogVerbose(@"%@ updateContactWithContact: %@ contactName: %@ contactDescription: %@", LOG_TAG, contact, contactName, contactDescription);
    
    self.contact = contact;
    self.contactName = contactName;
    self.contactDescription = contactDescription;
    
    self.work |= UPDATE_CONTACT;
    self.state &= ~(UPDATE_CONTACT | UPDATE_CONTACT_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);

    // Work action: we must update the contact name.
    if (self.contact && self.contactName && (self.work & UPDATE_CONTACT) != 0) {
        if ((self.state & UPDATE_CONTACT) == 0) {
            self.state |= UPDATE_CONTACT;
            
            int64_t requestId = [self newOperation:UPDATE_CONTACT];
            DDLogVerbose(@"%@ updateContactWithRequestId: %lld contact: %@ contactName: %@", LOG_TAG, requestId, self.contact, self.contactName);
            [self.twinmeContext updateContactWithRequestId:requestId contact:self.contact contactName:self.contactName description:self.contactDescription];
            return;
        }
        
        if ((self.state & UPDATE_CONTACT_DONE) == 0) {
            return;
        }
    }
    
    [super onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %i errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    if (errorCode == TLBaseServiceErrorCodeItemNotFound && operationId == UPDATE_CONTACT) {
        self.state |= UPDATE_CONTACT_DONE;
        [self runOnDeleteContact:self.contact.uuid];
        return;
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
