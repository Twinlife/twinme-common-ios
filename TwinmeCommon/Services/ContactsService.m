/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>

#import <Twinme/TLContact.h>
#import <Twinlife/TLFilter.h>

#import "ContactsService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_CURRENT_SPACE = 1 << 0;
static const int GET_CURRENT_SPACE_DONE = 1 << 1;
static const int GET_CONTACTS = 1 << 2;
static const int GET_CONTACTS_DONE = 1 << 3;
static const int FIND_CONTACTS = 1 << 4;
static const int FIND_CONTACTS_DONE = 1 << 5;

//
// Interface: ContactsService ()
//

@class ContactsServiceTwinmeContextDelegate;

@interface ContactsService ()

@property (nonatomic) int work;
@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) NSString *findName;

- (void)onOperation;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

- (void)onUpdateSpace:(nonnull TLSpace *)space;

- (void)onCreateContact:(nonnull TLContact *)contact;

- (void)onUpdateContact:(nonnull TLContact *)contact;

- (void)onMoveContact:(nonnull TLContact *)contact;

- (void)onDeleteContact:(nonnull NSUUID *)contactId;

@end


//
// Interface: ContactsServiceTwinmeContextDelegate
//

@interface ContactsServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ContactsService *)service;

@end

//
// Implementation: ContactsServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ContactsServiceTwinmeContextDelegate"

@implementation ContactsServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ContactsService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onSetCurrentSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(ContactsService *)self.service onSetCurrentSpace:space];
}

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(ContactsService *)self.service onUpdateSpace:space];
}

- (void)onCreateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onCreateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    [(ContactsService *)self.service onCreateContact:contact];
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    [(ContactsService *)self.service onUpdateContact:contact];
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId contact:(TLContact *)contact oldSpace:(TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld contact: %@ oldSpace: %@", LOG_TAG, requestId, contact, oldSpace);
    
    [(ContactsService *)self.service onMoveContact:contact];
}

- (void)onDeleteContactWithRequestId:(int64_t)requestId contactId:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contactId);
    
    [(ContactsService *)self.service onDeleteContact:contactId];
}

@end

//
// Implementation: ContactsService
//

#undef LOG_TAG
#define LOG_TAG @"ContactsService"

@implementation ContactsService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <ContactsServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[ContactsServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [super dispose];
}

- (void)getContacts {
    DDLogVerbose(@"%@ getContacts", LOG_TAG);
    
    [self showProgressIndicator];
    self.state &= ~(GET_CONTACTS | GET_CONTACTS_DONE | GET_CURRENT_SPACE | GET_CURRENT_SPACE_DONE);
    [self startOperation];
}

- (void)findContactsByName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ findContactsByName: %@", LOG_TAG, name);
    
    self.findName = [name.lowercaseString stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
    self.work = FIND_CONTACTS;
    self.state &= ~(FIND_CONTACTS | FIND_CONTACTS_DONE);
    [self startOperation];
}

- (BOOL)isGetContactsDone {
    DDLogVerbose(@"%@ isGetContactsDone", LOG_TAG);
    
    return (self.state & GET_CONTACTS_DONE) != 0;
}

#pragma mark - Private methods

- (void)onSetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    if (self.space != space) {
        self.space = space;
        self.state &= ~(GET_CONTACTS | GET_CONTACTS_DONE);
    }
    [self runOnSetCurrentSpace:space];
    [self onOperation];
}

- (void)onUpdateSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpace: %@", LOG_TAG, space);

    [self runOnUpdateSpace:space];
    [self onOperation];
}

- (void)onCreateContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onCreateContact: %@", LOG_TAG, contact);
    
    if (self.space == contact.space) {
        UIImage *avatar = [self getImageWithContact:contact];

        id delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(onCreateContact:avatar:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<ContactsServiceDelegate>)delegate onCreateContact:contact avatar:avatar];
            });
        }
    }
}

- (void)onUpdateContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContact: %@", LOG_TAG, contact);
    
    if (self.space == contact.space) {
        UIImage *avatar = [self getImageWithContact:contact];
        [self runOnUpdateContact:contact avatar:avatar];
    }
}

- (void)onMoveContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onMoveContact: %@", LOG_TAG, contact);
    
    if (self.space != contact.space) {
        [self runOnDeleteContact:contact.uuid];
    }
}

- (void)onDeleteContact:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContact: %@", LOG_TAG, contactId);
    
    [self runOnDeleteContact:contactId];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    //
    // Step 1: get the current space.
    //
    if ((self.state & GET_CURRENT_SPACE) == 0) {
        self.state |= GET_CURRENT_SPACE;

        [self.twinmeContext getCurrentSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
            self.state |= GET_CURRENT_SPACE_DONE;
            self.space = space;
            [self runOnGetSpace:space avatar:nil];
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_CURRENT_SPACE_DONE) == 0) {
        return;
    }
    
    //
    // Step 2: We must get the list of contacts for the space.
    //
    if ((self.state & GET_CONTACTS) == 0) {
        self.state |= GET_CONTACTS;
        
        [self.twinmeContext findContactsWithFilter:[self.twinmeContext createSpaceFilter] withBlock:^(NSMutableArray<TLContact *> *contacts) {
            self.state |= GET_CONTACTS_DONE;
            [self runOnGetContacts:contacts];
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_CONTACTS_DONE) == 0) {
        return;
    }
    
    //
    // Step 3: We must search for a contact with some name.
    //
    if ((self.work & FIND_CONTACTS) != 0) {
        if ((self.state & FIND_CONTACTS) == 0) {
            self.state |= FIND_CONTACTS;
                       
            TLFilter *filter = [self.twinmeContext createSpaceFilter];
            NSString *findName = self.findName;
            if (findName) {
                filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                    TLContact *contact = (TLContact *)object;
                    NSString *contactName = [contact.name stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
                    return [contactName.lowercaseString containsString:findName];
                };
            }
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
