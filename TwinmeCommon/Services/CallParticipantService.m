/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLContact.h>
#import <Twinme/TLSpace.h>
#import <Twinme/TLTwinmeContext.h>
#import <Twinlife/TLFilter.h>

#import "CallParticipantService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_CONTACTS = 1 << 0;
static const int GET_CONTACTS_DONE = 1 << 1;
static const int FIND_CONTACTS = 1 << 2;
static const int FIND_CONTACTS_DONE = 1 << 3;

//
// Interface: CallParticipantService ()
//

@class CallParticipantServiceTwinmeContextDelegate;

@interface CallParticipantService ()

@property (nonatomic, nullable) NSString *findName;
@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic) int work;

- (void)onOperation;

@end

//
// Interface: CallParticipantServiceTwinmeContextDelegate
//

@interface CallParticipantServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (instancetype)initWithService:(CallParticipantService *)service;

@end

//
// Implementation: CallParticipantServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"CallParticipantServiceTwinmeContextDelegate"

@implementation CallParticipantServiceTwinmeContextDelegate

- (instancetype)initWithService:(CallParticipantService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorcode errorParameter:(NSString *)errorParameter {
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(CallParticipantService *)self.service onErrorWithOperationId:operationId errorCode:errorcode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Implementation: CallParticipantService
//

#undef LOG_TAG
#define LOG_TAG @"CallParticipantService"

@implementation CallParticipantService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <CallParticipantServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[CallParticipantServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [super dispose];
}

- (void)getContacts:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ getContacts", LOG_TAG);
    
    self.space = space;
    self.work |= GET_CONTACTS;
    self.state &= ~(GET_CONTACTS | GET_CONTACTS_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)findContactsByName:(nonnull NSString *)name space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ findContactsByName: %@", LOG_TAG, name);
    
    self.findName = [name.lowercaseString stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
    self.work = FIND_CONTACTS;
    self.state &= ~(FIND_CONTACTS | FIND_CONTACTS_DONE);
    [self startOperation];
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    // We must get the list of contacts.
    if ((self.work & GET_CONTACTS) != 0) {
        if ((self.state & GET_CONTACTS) == 0) {
            self.state |= GET_CONTACTS;
            
            TLFilter *filter = [TLFilter alloc];
            filter.owner = self.space;
            filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLContact *contact = (TLContact *)object;
                
                return !contact.isTwinroom && contact.hasPeer;
            };

            [self.twinmeContext findContactsWithFilter:filter withBlock:^(NSMutableArray<TLContact *> *contacts) {
                self.state |= GET_CONTACTS_DONE;
                [self runOnGetContacts:contacts];
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_CONTACTS_DONE) == 0) {
            return;
        }
    }
    
    // We must search for a contact with some name.
    if ((self.work & FIND_CONTACTS) != 0) {
        if ((self.state & FIND_CONTACTS) == 0) {
            self.state |= FIND_CONTACTS;
            
            TLFilter *filter = [TLFilter alloc];
            filter.owner = self.space;
            filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLContact *contact = (TLContact *)object;
                NSString *contactName = [contact.name stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
                return [self.twinmeContext isCurrentSpace:contact] && [contactName.lowercaseString containsString:self.findName] && !contact.isTwinroom && contact.hasPeer;
            };
            
            [self.twinmeContext findContactsWithFilter:filter withBlock:^(NSMutableArray<TLContact *> *contacts) {
                self.state |= FIND_CONTACTS_DONE;
                [self runOnGetContacts:contacts];
                [self onOperation];
            }];
            return;
        }
        if ((self.state & FIND_CONTACTS_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

@end
