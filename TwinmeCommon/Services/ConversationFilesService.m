/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>

#import "ConversationFilesService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int MAX_OBJECTS = 30;

static const int GET_OR_CREATE_CONVERSATION = 1 << 0;
static const int GET_OR_CREATE_CONVERSATION_DONE = 1 << 1;
static const int GET_DESCRIPTORS = 1 << 2;
static const int GET_DESCRIPTORS_DONE = 1 << 3;
static const int DELETE_DESCRIPTOR = 1 << 4;
static const int MARK_DESCRIPTOR_DELETED = 1 << 7;

//
// Interface: ConversationFilesService ()
//

@class ConversationFilesServiceTwinmeContextDelegate;
@class ConversationFilesServiceConversationServiceDelegate;

@interface ConversationFilesService ()

@property NSUUID *conversationId;
@property (nonatomic) id<TLOriginator> contact;
@property (nonatomic) NSUUID *twincodeOutboundId;
@property (nonatomic) NSUUID *peerTwincodeOutboundId;
@property (nonatomic) NSUUID *twincodeInboundId;
@property (nonatomic) id <TLConversation> conversation;
@property (nonatomic) id<TLGroupConversation> groupConversation;
@property (nonatomic) int64_t beforeTimestamp;
@property (nonatomic) BOOL getDescriptorsDone;
@property (nonatomic) NSArray<TLDescriptor *> *descriptors;
@property (nonatomic) BOOL isGroup;
@property (nonatomic) TLGroup *group;

@property (nonatomic) ConversationFilesServiceConversationServiceDelegate *conversationFilesConversationServiceDelegate;

- (void)onOperation;

- (void)onGetOrCreateConversation:(id<TLConversation>)conversation;

- (void)onMarkDescriptorDeleted:(TLDescriptor *)descriptor;

- (void)onDeleteDescriptors:(NSSet<TLDescriptorId *> *)descriptors;

- (void)onErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

@end

//
// Interface: ConversationFilesServiceTwinmeContextDelegate
//

@interface ConversationFilesServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ConversationFilesService *)service;

@end

//
// Implementation: ConversationFilesServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ConversationFilesServiceTwinmeContextDelegate"

@implementation ConversationFilesServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ConversationFilesService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);

    // If a storage error is raised, report it.
    if (requestId == [TLBaseService DEFAULT_REQUEST_ID]) {
        if (errorCode == TLBaseServiceErrorCodeNoStorageSpace) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.service onErrorWithOperationId:0 errorCode:errorCode errorParameter:errorParameter];
            });
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
// Interface: ConversationFilesServiceConversationServiceDelegate
//

@interface ConversationFilesServiceConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) ConversationFilesService *service;

- (instancetype)initWithService:(ConversationFilesService *)service;

@end

//
// Implementation: ConversationFilesServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ConversationFilesServiceConversationServiceDelegate"

@implementation ConversationFilesServiceConversationServiceDelegate

- (instancetype)initWithService:(ConversationFilesService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onGetOrCreateConversationWithRequestId:(int64_t)requestId conversation:(id<TLConversation>)conversation {
    DDLogVerbose(@"%@ onGetOrCreateConversationWithRequestId: %lld conversation: %@", LOG_TAG, requestId, conversation);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }

    [self.service onGetOrCreateConversation:conversation];
}

- (void)onMarkDescriptorDeletedWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onMarkDescriptorDeletedWithRequestId: %lld conversation: %@ descriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    if (![conversation.uuid isEqual:self.service.conversationId]) {
        return;
    }
    
    [self.service onMarkDescriptorDeleted:descriptor];
}

- (void)onDeleteDescriptorsWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation descriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors {
    DDLogVerbose(@"%@ onDeleteDescriptorsWithRequestId: %lld conversation: %@ descriptors: %@", LOG_TAG, requestId, conversation, descriptors);
    
    if (![conversation isConversationWithUUID:self.service.conversationId]) {
        return;
    }
    
    [self.service onDeleteDescriptors:descriptors];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    if (requestId == [TLBaseService DEFAULT_REQUEST_ID]) {
        if (errorCode == TLBaseServiceErrorCodeFeatureNotSupportedByPeer) {
            NSUUID *conversationId = [[NSUUID alloc] initWithUUIDString:errorParameter];
            if (conversationId && [conversationId isEqual:self.service.conversationId]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.service onErrorWithErrorCode:errorCode errorParameter:errorParameter];
                });
            }
        } else if (errorCode == TLBaseServiceErrorCodeNoStorageSpace) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.service onErrorWithErrorCode:errorCode errorParameter:errorParameter];
            });
        } else {
            [self.service.twinmeContext assertionWithAssertPoint:[ServicesAssertPoint UNKNOWN_ERROR], [TLAssertValue initWithLine:__LINE__], [TLAssertValue initWithErrorCode:errorCode], nil];
        }
    } else {
        int operationId = [self.service getOperation:requestId];
        if (!operationId) {
            return;
        }

        [self.service onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
        [self.service onOperation];
    }
}

@end

//
// Implementation: ConversationFilesService
//

#undef LOG_TAG
#define LOG_TAG @"ConversationFilesService"

@implementation ConversationFilesService

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext delegate:(id<ConversationFilesServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _beforeTimestamp = INT64_MAX;
        _getDescriptorsDone = NO;
        
        _conversationFilesConversationServiceDelegate = [[ConversationFilesServiceConversationServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[ConversationFilesServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

#pragma mark - Public methods

- (void)initWithOriginator:(id<TLOriginator>)contact {
    DDLogVerbose(@"%@ initWithOriginator: %@", LOG_TAG, contact);
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, contact, [ServicesAssertPoint PARAMETER], nil);

    self.state = 0;
    self.beforeTimestamp = INT64_MAX;
    self.getDescriptorsDone = NO;
    self.contact = contact;
    self.twincodeOutboundId = contact.twincodeOutboundId;
    self.twincodeInboundId = contact.twincodeInboundId;
    if (![contact isGroup]) {
        TLContact *c = (TLContact *)contact;
        if ([c hasPrivatePeer]) {
            self.peerTwincodeOutboundId = c.peerTwincodeOutboundId;
        } else {
            self.peerTwincodeOutboundId = nil;
        }
        self.isGroup = [c isTwinroom];
    } else {
        self.group = (TLGroup *)contact;
        self.peerTwincodeOutboundId = self.group.groupTwincodeOutboundId;
        self.isGroup = YES;
    }
    
    [self startOperation];
}

- (void)initWithConversationId:(NSUUID *)conversationId {
    DDLogVerbose(@"%@ initWithConversationId: %@", LOG_TAG, conversationId);
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, conversationId, [ServicesAssertPoint PARAMETER], nil);

    self.conversationId = conversationId;
}

- (void)getPreviousDescriptors {
    DDLogVerbose(@"%@ getPreviousDescriptors", LOG_TAG);
    
    if (self.getDescriptorsDone) {
        return;
    }
    
    if ((self.state & GET_DESCRIPTORS) != 0 && (self.state & GET_DESCRIPTORS_DONE) != 0) {
        self.state &= ~GET_DESCRIPTORS;
        self.state &= ~GET_DESCRIPTORS_DONE;
        
        [self startOperation];
    }
}

- (BOOL)isGetDescriptorDone {
    DDLogVerbose(@"%@ isGetDescriptorDone", LOG_TAG);
    
    return self.getDescriptorsDone;
}

- (BOOL)isLocalDescriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ isLocalDescriptor: %@", LOG_TAG, descriptor);
    
    return [descriptor isTwincodeOutbound:self.twincodeOutboundId];
}

- (BOOL)isPeerDescriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ isPeerDescriptor: %@", LOG_TAG, descriptor);
    
    return [descriptor isTwincodeOutbound:self.peerTwincodeOutboundId] || self.isGroup;
}

- (void)markDescriptorDeletedWithDescriptorId:(TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ markDescriptorDeletedWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    int64_t requestId = [self newOperation:MARK_DESCRIPTOR_DELETED];
    DDLogVerbose(@"%@ markDescriptorDeletedWithRequestId: %lld descriptorId: %@", LOG_TAG, requestId, descriptorId);
    [self.twinmeContext markDescriptorDeletedWithRequestId:requestId descriptorId:descriptorId];
}

- (void)deleteDescriptorWithDescriptorId:(TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ deleteDescriptorWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    int64_t requestId = [self newOperation:DELETE_DESCRIPTOR];
    DDLogVerbose(@"%@ deleteDescriptorWithDescriptorId: %lld descriptorId: %@", LOG_TAG, requestId, descriptorId);
    [self.twinmeContext deleteDescriptorWithRequestId:requestId descriptorId:descriptorId];
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getConversationService] removeDelegate:self.conversationFilesConversationServiceDelegate];
    [self.twinmeContext removeDelegate:self.twinmeContextDelegate];
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    //
    // Step 1
    //

    
    if (self.group && self.twincodeOutboundId) {
        if ((self.state & GET_OR_CREATE_CONVERSATION) == 0) {
            self.state |= GET_OR_CREATE_CONVERSATION;
            
            // For a group, we must not create the conversation and the get can fail.
            id<TLConversation> conversation = [[self.twinmeContext getConversationService] getConversationWithSubject:self.group];
            if (conversation) {
                [self onGetOrCreateConversation:conversation];
            } else {
                DDLogError(@"%@ group conversation for twincode %@ does not exist", LOG_TAG, self.twincodeOutboundId);
            }
        }
        
    } else if (self.contact) {
        if ((self.state & GET_OR_CREATE_CONVERSATION) == 0) {
            self.state |= GET_OR_CREATE_CONVERSATION;
            
            DDLogVerbose(@"%@ getConversationWithSubject: %@", LOG_TAG, self.contact);
            id<TLConversation> conversation = [[self.twinmeContext getConversationService] getConversationWithSubject:self.contact];
            if (conversation) {
                [self onGetOrCreateConversation:conversation];
            } else {
                DDLogError(@"%@ conversation for contact %@ does not exist", LOG_TAG, self.contact);
            }
        }
    }

    //
    // Step 2
    //
    if (self.conversation) {
        if ((self.state & GET_DESCRIPTORS) == 0) {
            self.state |= GET_DESCRIPTORS;
            
            DDLogVerbose(@"%@ getDescriptorsWithConversation: %@ beforeSequence: %lld maxObjects: %d", LOG_TAG, self.conversationId, self.beforeTimestamp, MAX_OBJECTS);
            NSArray<TLDescriptor *> *descriptors = [[self.twinmeContext getConversationService] getDescriptorsWithConversation:self.conversation types:@[@(TLDescriptorTypeImageDescriptor), @(TLDescriptorTypeVideoDescriptor), @(TLDescriptorTypeNamedFileDescriptor), @(TLDescriptorTypeObjectDescriptor)] callsMode:TLDisplayCallsModeAll beforeTimestamp:self.beforeTimestamp maxDescriptors:MAX_OBJECTS];
            
            [self onGetDescriptors:descriptors];
            return;
        }
        if ((self.state & GET_DESCRIPTORS_DONE) == 0) {
            return;
        }
    }
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getConversationService] addDelegate:self.conversationFilesConversationServiceDelegate];
    [super onTwinlifeReady];
}

- (void)onGetOrCreateConversation:(id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onGetOrCreateConversation: %@", LOG_TAG, conversation);

    self.state |= GET_OR_CREATE_CONVERSATION_DONE;
    
    self.conversation = conversation;
    self.conversationId = [self.conversation uuid];
    if ([conversation isGroup]) {
        self.groupConversation = (id<TLGroupConversation>)conversation;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ConversationFilesServiceDelegate>)self.delegate onGetConversation:conversation];
    });
    [self onOperation];
}

- (void)onGetDescriptors:(NSArray *)descriptors {
    DDLogVerbose(@"%@ onGetDescriptors: %@", LOG_TAG, descriptors);

    for (TLDescriptor *descriptor in descriptors) {
        if (descriptor.createdTimestamp < self.beforeTimestamp) {
            self.beforeTimestamp = descriptor.createdTimestamp;
        }
        
        if (!self.isGroup) {
            continue;
        }
        if ([descriptor isTwincodeOutbound:self.contact.twincodeOutboundId]) {
            continue;
        }
    }
    
    if (descriptors.count < MAX_OBJECTS) {
        self.getDescriptorsDone = YES;
    }
    
    self.state |= GET_DESCRIPTORS_DONE;
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ConversationFilesServiceDelegate>)self.delegate onGetDescriptors:descriptors];
    });
    [self onOperation];
}

- (void)onMarkDescriptorDeleted:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onMarkDescriptorDeleted: %@", LOG_TAG, descriptor);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ConversationFilesServiceDelegate>)self.delegate onMarkDescriptorDeleted:descriptor];
    });
    [self onOperation];
}

- (void)onDeleteDescriptors:(NSSet<TLDescriptorId *> *)descriptors {
    DDLogVerbose(@"%@ onDeleteDescriptors: %@", LOG_TAG, descriptors);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ConversationFilesServiceDelegate>)self.delegate onDeleteDescriptors:descriptors];
    });
    [self onOperation];
}

- (void)onErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithErrorCode: %u errorParameter: %@", LOG_TAG, errorCode, errorParameter);
    
    if (errorCode == TLBaseServiceErrorCodeNoStorageSpace) {
        [super onErrorWithOperationId:0 errorCode:errorCode errorParameter:errorParameter];
        return;
    }
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %u errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    
    if (errorCode == TLBaseServiceErrorCodeNoStorageSpace) {
        [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
        return;
    }
}

@end
