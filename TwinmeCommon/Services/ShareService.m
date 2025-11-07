/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLFilter.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLMessage.h>
#import <Twinme/TLSpace.h>

#import "ShareService.h"
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
static const int GET_GROUPS = 1 << 4;
static const int GET_GROUPS_DONE = 1 << 5;
static const int PUSH_OBJECT = 1 << 7;
static const int PUSH_FILE = 1 << 8;
static const int FIND_CONTACTS_AND_GROUPS = 1 << 9;
static const int FIND_CONTACTS_AND_GROUPS_DONE = 1 << 10;

//
// Interface: ShareService ()
//

@class ShareServiceTwinmeContextDelegate;
@class ShareServiceConversationServiceDelegate;

@interface ShareService ()

@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic) int work;
@property (nonatomic, nullable) NSString *findName;

@property (nonatomic, nullable) ShareServiceConversationServiceDelegate *conversationServiceDelegate;

@property (nonatomic, nullable) id<TLConversation> conversation;

- (void)onOperation;

- (void)onTwinlifeReady;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

- (void)onCreateContact:(nonnull TLContact *)contact;

- (void)onUpdateContact:(nonnull TLContact *)contact;

- (void)onMoveContact:(nonnull TLContact *)contact oldSpace:(nonnull TLSpace *)oldSpace;

- (void)onDeleteContact:(nonnull NSUUID *)contactId;

- (void)onMoveGroup:(nonnull TLGroup *)group oldSpace:(nonnull TLSpace *)oldSpace;

- (void)onUpdateGroup:(nonnull TLGroup *)group;

- (void)onDeleteGroup:(nonnull NSUUID *)groupId;

- (void)onGetOrCreateConversation:(nonnull id <TLConversation>)conversation;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end


//
// Interface: ShareServiceTwinmeContextDelegate
//

@interface ShareServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ShareService *)service;

@end

//
// Implementation: ShareServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ShareServiceTwinmeContextDelegate"

@implementation ShareServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ShareService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    [(ShareService *)self.service onUpdateContact:contact];
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact oldSpace:(nonnull TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld contact: %@ oldSpace: %@", LOG_TAG, requestId, contact, oldSpace);
    
    [(ShareService *)self.service onMoveContact:contact oldSpace:oldSpace];
}

- (void)onDeleteContactWithRequestId:(int64_t)requestId contactId:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contactId);
    
    [(ShareService *)self.service onDeleteContact:contactId];
}

- (void)onDeleteGroupWithRequestId:(int64_t)requestId groupId:(NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, groupId);
    
    [(ShareService *)self.service onDeleteGroup:groupId];
}

- (void)onUpdateGroupWithRequestId:(int64_t)requestId group:(TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, group);
    
    [(ShareService *)self.service onUpdateGroup:group];
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId group:(TLGroup *)group oldSpace:(TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld group: %@ oldSpace: %@", LOG_TAG, requestId, group, oldSpace);
    
    [(ShareService *)self.service onMoveGroup:group oldSpace:oldSpace];
}

@end

//
// Interface: ShareServiceConversationServiceDelegate
//

@interface ShareServiceConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) ShareService *service;

- (nonnull instancetype)initWithService:(nonnull ShareService *)service;

@end

//
// Implementation: ShareServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ShareServiceConversationServiceDelegate"

@implementation ShareServiceConversationServiceDelegate

- (nonnull instancetype)initWithService:(nonnull ShareService *)service {
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

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    if (requestId == [TLBaseService DEFAULT_REQUEST_ID]) {
        if (errorCode == TLBaseServiceErrorCodeNoStorageSpace) {
            [self.service onErrorWithOperationId:0 errorCode:errorCode errorParameter:errorParameter];
        }
        return;
    }

    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [self.service onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Implementation: ShareService
//

#undef LOG_TAG
#define LOG_TAG @"ShareService"

@implementation ShareService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <ShareServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _conversationServiceDelegate = [[ShareServiceConversationServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[ShareServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)getConversationWithContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ getConversationWithContact: %@", LOG_TAG, contact);
    
    id<TLConversation> conversation = [[self.twinmeContext getConversationService] getOrCreateConversationWithSubject:contact create:true];
    [self onGetOrCreateConversation:conversation];
}

- (void)getConversationWithGroup:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ getConversationWithGroup: %@", LOG_TAG, group);
    
    id<TLConversation> conversation = [[self.twinmeContext getConversationService] getConversationWithSubject:group];
    if (conversation) {
        self.conversation = conversation;
        [(id<ShareServiceDelegate>)self.delegate onGetConversation:conversation];
    }
}

- (void)forwardDescriptor:(nonnull TLDescriptorId *)descriptorId copyAllowed:(BOOL)copyAllowed {
    DDLogVerbose(@"%@ forwardDescriptor: %@ copyAllowed: %d", LOG_TAG, descriptorId, copyAllowed);
    
    int64_t requestId = [self newOperation:PUSH_OBJECT];
    [self.twinmeContext forwardDescriptorWithRequestId:requestId conversation:self.conversation sendTo:nil descriptorId:descriptorId copyAllowed:copyAllowed expireTimeout:0];
}

- (void)pushMessage:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed {
    DDLogVerbose(@"%@ pushMessage: %@ copyAllowed: %d", LOG_TAG, message, copyAllowed);
    
    int64_t requestId = [self newOperation:PUSH_OBJECT];
    [self.twinmeContext pushObjectWithRequestId:requestId conversation:self.conversation sendTo:nil replyTo:nil message:message copyAllowed:copyAllowed expireTimeout:0];
}

- (void)pushFileWithPath:(nonnull NSString *)path type:(TLDescriptorType)type toBeDeleted:(BOOL)toBeDeleted copyAllowed:(BOOL)copyAllowed {
    DDLogVerbose(@"%@ pushFileWithPath: %@ type: %d toBeDeleted: %d copyAllowed: %d", LOG_TAG, path, type, toBeDeleted, copyAllowed);
    
    int64_t requestId = [self newOperation:PUSH_FILE];
    [self.twinmeContext pushFileWithRequestId:requestId conversation:self.conversation sendTo:nil replyTo:nil path:path type:type toBeDeleted:toBeDeleted copyAllowed:copyAllowed expireTimeout:0];
}

- (void)findContactsAndGroupsByName:(nonnull NSString *)name space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ findContactsAndGroupsByName: %@", LOG_TAG, name);
    
    self.findName = [name.lowercaseString stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
    self.space = space;
    self.work = FIND_CONTACTS_AND_GROUPS;
    self.state &= ~(FIND_CONTACTS_AND_GROUPS | FIND_CONTACTS_AND_GROUPS_DONE);
    [self startOperation];
}

- (void)getContactsAndGroups:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ getContactsAndGroups", LOG_TAG);
    
    self.space = space;
    self.state &= ~(GET_CONTACTS | GET_CONTACTS_DONE);
    self.state &= ~(GET_GROUPS | GET_GROUPS_DONE);
    [self startOperation];
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];
    
    [super dispose];
}

#pragma mark - Private methods

- (void)onSetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    // Switching to a new space, fetch again the contacts, groups, conversations.
    if (self.space != space) {
        self.space = space;
        self.state &= ~(GET_CONTACTS | GET_CONTACTS_DONE);
        self.state &= ~(GET_GROUPS | GET_GROUPS_DONE);
    }
    [self runOnSetCurrentSpace:space];
    [self onOperation];
}

- (void)onCreateContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onCreateContact: %@", LOG_TAG, contact);
    
    if (self.space == contact.space) {
        UIImage *avatar = [self getImageWithContact:contact];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ShareServiceDelegate>)self.delegate onCreateContact:contact avatar:avatar];
        });
    }
}

- (void)onUpdateContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContact: %@", LOG_TAG, contact);
    
    if (self.space == contact.space) {
        UIImage *avatar = [self getImageWithContact:contact];
        [self runOnUpdateContact:contact avatar:avatar];
    }
}

- (void)onMoveContact:(nonnull TLContact *)contact oldSpace:(nonnull TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveContact: %@ oldSpace: %@", LOG_TAG, contact, oldSpace);
    
    if (self.space != contact.space) {
        [self runOnDeleteContact:contact.uuid];
    }
}

- (void)onDeleteContact:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContact: %@", LOG_TAG, contactId);
    
    [self runOnDeleteContact:contactId];
}

- (void)onUpdateGroup:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroup: %@", LOG_TAG, group);
    
    if (self.space == group.space) {
        UIImage *avatar = [self getImageWithGroup:group];
        [self runOnUpdateGroup:group avatar:avatar];
    }
}

- (void)onMoveGroup:(nonnull TLGroup *)group oldSpace:(nonnull TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveGroup: %@ oldSpace: %@", LOG_TAG, group, oldSpace);
    
    if (self.space != group.space) {
        [self runOnDeleteGroup:group.uuid];
    }
}

- (void)onDeleteGroup:(nonnull NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroup: %@", LOG_TAG, groupId);
    
    [self runOnDeleteGroup:groupId];
}

- (void)onGetOrCreateConversation:(nonnull id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onGetOrCreateConversation: %@", LOG_TAG, conversation);

    if (!conversation.contactId) {
        return;
    }
    
    self.conversation = conversation;
    [(id<ShareServiceDelegate>)self.delegate onGetConversation:conversation];
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
            [self runOnSetCurrentSpace:space];
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_CURRENT_SPACE_DONE) == 0) {
        return;
    }
    
    //
    // Step 2: Get the list of contacts.
    //
    if ((self.state & GET_CONTACTS) == 0) {
        self.state |= GET_CONTACTS;

        TLFilter *filter = [TLFilter alloc];
        filter.owner = self.space;
        filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
            TLContact *contact = (TLContact *)object;
            
            return [contact hasPeer];
        };
        [self.twinmeContext findContactsWithFilter:filter withBlock:^(NSMutableArray<TLContact *> *list) {
            self.state |= GET_CONTACTS_DONE;
            [self runOnGetContacts:list];
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_CONTACTS_DONE) == 0) {
        return;
    }
    
    //
    // Step 3: get the list of groups before the conversations.
    //
    if ((self.state & GET_GROUPS) == 0) {
        self.state |= GET_GROUPS;
        
        TLFilter *filter = [TLFilter alloc];
        filter.owner = self.space;
        filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
            TLGroup *group = (TLGroup *)object;
            return !group.isLeaving;
        };
        
        [self.twinmeContext findGroupsWithFilter:filter withBlock:^(NSMutableArray<TLGroup *> *groups) {
            self.state |= GET_GROUPS_DONE;
            [self runOnGetGroups:groups];
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_GROUPS_DONE) == 0) {
        return;
    }
    
    //
    // We must search for a contact and group with some name.
    //
    if ((self.work & FIND_CONTACTS_AND_GROUPS) != 0) {
        if ((self.state & FIND_CONTACTS_AND_GROUPS) == 0) {
            self.state |= FIND_CONTACTS_AND_GROUPS;

            TLFilter *contactFilter = [TLFilter alloc];
            NSString *findName = self.findName;
            contactFilter.owner = self.space;
            if (findName) {
                contactFilter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                    TLContact *contact = (TLContact *)object;
                    NSString *contactName = [contact.name stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
                    
                    return [contactName.lowercaseString containsString:findName];
                };
            }
            [self.twinmeContext findContactsWithFilter:contactFilter withBlock:^(NSMutableArray<TLContact *> *contacts) {
                self.state |= FIND_CONTACTS_AND_GROUPS_DONE;
                [self runOnGetContacts:contacts];
                [self onOperation];
            }];

            TLFilter *groupFilter = [TLFilter alloc];
            groupFilter.owner = self.space;
            groupFilter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLGroup *group = (TLGroup *)object;
                NSString *groupName = [group.name stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
                return [groupName.lowercaseString containsString:findName] && !group.isLeaving;
            };
            [self.twinmeContext findGroupsWithFilter:groupFilter withBlock:^(NSMutableArray<TLGroup *> *groups) {
                self.state |= FIND_CONTACTS_AND_GROUPS_DONE;
                [self runOnGetGroups:groups];
                [self onOperation];
            }];
            return;
        }
        if ((self.state & FIND_CONTACTS_AND_GROUPS_DONE) == 0) {
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

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // We can ignore the error if the conversation id was not found.
    if (errorCode == TLBaseServiceErrorCodeItemNotFound && (operationId == PUSH_FILE || operationId == PUSH_OBJECT)) {

        return;
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
