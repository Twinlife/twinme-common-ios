/*
 *  Copyright (c) 2021-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLAccountService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLFilter.h>

#import <Twinme/TLContact.h>
#import <Twinme/TLInvitation.h>
#import <Twinme/TLTwinmeContext.h>

#import "InvitationRoomService.h"
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
static const int PUSH_TWINCODE = 1 << 5;

//
// Interface: InvitationRoomService ()
//

@class InvitationRoomServiceTwinmeContextDelegate;
@class InvitationRoomServiceConversationServiceDelegate;

@interface InvitationRoomService ()

@property (nonatomic, nullable) TLContact *room;
@property (nonatomic, nullable) NSString *findName;
@property (nonatomic, nullable) NSMutableArray *contactsToInvite;
@property (nonatomic, nullable) TLContact *currentContact;
@property (nonatomic) int work;
@property (nonatomic, nullable) id<TLConversation> conversation;

@property (nonatomic, nullable) InvitationRoomServiceConversationServiceDelegate *conversationServiceDelegate;

- (void)onOperation;

- (void)onTwinlifeReady;

- (void)onGetOrCreateConversation:(nonnull id <TLConversation>)conversation;

- (void)onPushTwincode:(nonnull id <TLConversation>)conversation;

@end

//
// Interface: InvitationRoomServiceTwinmeContextDelegate
//

@interface InvitationRoomServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (instancetype)initWithService:(InvitationRoomService *)service;

@end

//
// Implementation: InvitationRoomServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"InvitationRoomServiceTwinmeContextDelegate"

@implementation InvitationRoomServiceTwinmeContextDelegate

- (instancetype)initWithService:(InvitationRoomService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorcode errorParameter:(NSString *)errorParameter {
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(InvitationRoomService *)self.service onErrorWithOperationId:operationId errorCode:errorcode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Interface: InvitationRoomServiceConversationServiceDelegate
//

@interface InvitationRoomServiceConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) InvitationRoomService *service;

- (nonnull instancetype)initWithService:(nonnull InvitationRoomService *)service;

@end

//
// Implementation: InvitationRoomServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"InvitationRoomServiceConversationServiceDelegate"

@implementation InvitationRoomServiceConversationServiceDelegate

- (nonnull instancetype)initWithService:(nonnull InvitationRoomService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onGetOrCreateConversationWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onGetOrCreateConversationWithRequestId: %lld conversation: %@", LOG_TAG, requestId, conversation);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [self.service onGetOrCreateConversation:conversation];
}

- (void)onPushDescriptorRequestId:(int64_t)requestId conversation:(id<TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [self.service onPushTwincode:conversation];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [self.service onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
    [self.service onOperation];
}

@end


//
// Implementation: InvitationRoomService
//

#undef LOG_TAG
#define LOG_TAG @"InvitationRoomService"

@implementation InvitationRoomService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <InvitationRoomServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _conversationServiceDelegate = [[InvitationRoomServiceConversationServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[InvitationRoomServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];
    
    [super dispose];
}

- (void)getContacts {
    DDLogVerbose(@"%@ getContacts", LOG_TAG);
    
    self.work |= GET_CONTACTS;
    self.state &= ~(GET_CONTACTS | GET_CONTACTS_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)findContactsByName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ findContactsByName: %@", LOG_TAG, name);
    
    self.findName = [name.lowercaseString stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
    self.work = FIND_CONTACTS;
    self.state &= ~(FIND_CONTACTS | FIND_CONTACTS_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)inviteContactToRoom:(nonnull NSArray *)contacts room:(nonnull TLContact *)room  {
    DDLogVerbose(@"%@ inviteContactToRoom: %@", LOG_TAG, contacts);
    
    self.room = room;
    self.contactsToInvite = [NSMutableArray arrayWithArray:contacts];
    self.currentContact = [self.contactsToInvite firstObject];
    
    [self getConversationWithCurrentContact];
}

- (void)getConversationWithCurrentContact {
    DDLogVerbose(@"%@ getConversationWithCurrentContact", LOG_TAG);
    
    id<TLConversation> conversation = [[self.twinmeContext getConversationService] getOrCreateConversationWithSubject:self.currentContact create:true];
    [self onGetOrCreateConversation:conversation];
}

- (void)pushTwincode {
    DDLogVerbose(@"%@ pushTwincode", LOG_TAG);
    
    int64_t requestId = [self newOperation:PUSH_TWINCODE];
    [[self.twinmeContext getConversationService] pushTwincodeWithRequestId:requestId conversation:self.conversation sendTo:nil replyTo:nil twincodeId:self.room.publicPeerTwincodeOutboundId schemaId:[TLInvitation SCHEMA_ID] publicKey:nil copyAllowed:NO expireTimeout:0];
}

#pragma mark - Private methods

- (void)onGetOrCreateConversation:(nonnull id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onGetOrCreateConversation: %@", LOG_TAG, conversation);
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, conversation.contactId, [ServicesAssertPoint PARAMETER], nil);

    if (!conversation.contactId) {
        return;
    }
    
    self.conversation = conversation;
    
    [self pushTwincode];
}

- (void)onPushTwincode:(id<TLConversation>)conversation {
    DDLogVerbose(@"%@ onPushTwincode: %@", LOG_TAG, conversation);
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, conversation.contactId, [ServicesAssertPoint PARAMETER], nil);

    if (!conversation.contactId) {
        return;
    }
    
    [self.contactsToInvite removeObjectAtIndex:0];
    
    if (self.contactsToInvite.count > 0) {
        self.currentContact = [self.contactsToInvite firstObject];
        [self getConversationWithCurrentContact];
    } else if ([(id)self.delegate respondsToSelector:@selector(onSendTwincodeToContacts)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<InvitationRoomServiceDelegate>)self.delegate onSendTwincodeToContacts];
        });
    }
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    // We must get the list of contacts.
    if ((self.work & GET_CONTACTS) != 0) {
        if ((self.state & GET_CONTACTS) == 0) {
            self.state |= GET_CONTACTS;
            
            TLFilter *filter = [self.twinmeContext createSpaceFilter];
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
            
            TLFilter *filter = [self.twinmeContext createSpaceFilter];
            filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLContact *contact = (TLContact *)object;
                NSString *contactName = [contact.name stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
                return [contactName.lowercaseString containsString:self.findName] && !contact.isTwinroom && contact.hasPeer;
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

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [super onTwinlifeReady];
    
    [[self.twinmeContext getConversationService] addDelegate:self.conversationServiceDelegate];
}

@end
