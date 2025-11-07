/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLImageService.h>
#import <Twinlife/TLTwinlife.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLGroupMember.h>
#import <Twinme/TLTwinmeAttributes.h>

#import "InfoItemService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int UPDATE_DESCRIPTOR = 1 << 0;

//
// Interface: InfoItemService ()
//

@class InfoItemServiceTwinmeContextDelegate;
@class InfoItemServiceConversationServiceDelegate;

@interface InfoItemService ()

@property NSUUID *conversationId;
@property (nonatomic) id<TLOriginator> contact;
@property (nonatomic) NSUUID *twincodeOutboundId;
@property (nonatomic) NSUUID *peerTwincodeOutboundId;
@property (nonatomic) NSUUID *twincodeInboundId;
@property (nonatomic) BOOL isGroup;
@property (nonatomic) TLGroup *group;

@property (nonatomic) InfoItemServiceConversationServiceDelegate *infoItemServiceDelegate;

- (void)onOperation;

- (void)onUpdateContact:(TLContact *)contact;

- (void)onUpdateDescriptor:(TLDescriptor *)descriptor;

- (void)onErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

@end

//
// Interface: InfoItemServiceTwinmeContextDelegate
//

@interface InfoItemServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull InfoItemService *)service;

@end

//
// Implementation:InfoItemServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"InfoItemServiceTwinmeContextDelegate"

@implementation InfoItemServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull InfoItemService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    [(InfoItemService *)self.service onUpdateContact:contact];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);

    // If a storage error is raised, report it.
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
// Interface: InfoItemServiceConversationServiceDelegate
//

@interface InfoItemServiceConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) InfoItemService *service;

- (instancetype)initWithService:(InfoItemService *)service;

@end

//
// Implementation: InfoItemServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"InfoItemServiceConversationServiceDelegate"

@implementation InfoItemServiceConversationServiceDelegate

- (instancetype)initWithService:(InfoItemService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onUpdateDescriptorWithRequestId:(int64_t)requestId conversation:(id<TLConversation>)conversation descriptor:(TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType {
    DDLogVerbose(@"%@ onUpdateDescriptorWithRequestId: %lld conversation: %@ descriptor: %@ updateType: %u", LOG_TAG, requestId, conversation, descriptor, updateType);
    
    if (updateType == TLConversationServiceUpdateTypeContent) {
        return;
    }
    
    [self.service onUpdateDescriptor:descriptor];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    if (requestId == [TLBaseService DEFAULT_REQUEST_ID]) {
        if (errorCode == TLBaseServiceErrorCodeFeatureNotSupportedByPeer) {
            NSUUID *conversationId = [[NSUUID alloc] initWithUUIDString:errorParameter];
            if (conversationId && [conversationId isEqual:self.service.conversationId]) {
                [self.service onErrorWithErrorCode:errorCode errorParameter:errorParameter];
            }
        } else if (errorCode == TLBaseServiceErrorCodeNoStorageSpace) {
            [self.service onErrorWithErrorCode:errorCode errorParameter:errorParameter];
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
// Implementation: InfoItemService
//

#undef LOG_TAG
#define LOG_TAG @"InfoItemService"

@implementation InfoItemService

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext delegate:(id<InfoItemServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _infoItemServiceDelegate = [[InfoItemServiceConversationServiceDelegate alloc] initWithService:self];
        self.twinmeContextDelegate = [[InfoItemServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

#pragma mark - Public methods

- (void)initWithContact:(id<TLOriginator>)contact {
    DDLogVerbose(@"%@ initWithContact: %@", LOG_TAG, contact);
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, contact, [ServicesAssertPoint PARAMETER], nil);

    self.state = 0;
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

- (void)listAnnotationsWithDescriptorId:(nonnull TLDescriptorId *)descriptorId withBlock:(nonnull void (^)(NSMutableDictionary<NSUUID *, TLDescriptorAnnotationPair*> * _Nonnull list))block {
    DDLogVerbose(@"%@ listAnnotationsWithDescriptorId: %@", LOG_TAG, descriptorId);

    [self.twinmeContext listAnnotationsWithDescriptorId:descriptorId withBlock:block];
}

- (void)updateDescriptor:(nonnull TLDescriptorId *)descriptorId allowCopy:(BOOL)allowCopy {
    DDLogVerbose(@"%@ updateDescriptor: %@", LOG_TAG, descriptorId);
    
    int64_t requestId = [self newOperation:UPDATE_DESCRIPTOR];
    [[self.twinmeContext getConversationService] updateDescriptorWithRequestId:requestId descriptorId:descriptorId message:nil copyAllowed:[NSNumber numberWithBool:allowCopy] expireTimeout:nil];
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getConversationService] removeDelegate:self.infoItemServiceDelegate];
    [self.twinmeContext removeDelegate:self.twinmeContextDelegate];
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getConversationService] addDelegate:self.infoItemServiceDelegate];
    [super onTwinlifeReady];
}

- (void)onUpdateContact:(TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContact: %@", LOG_TAG, contact);
    
    if (![self.contact.uuid isEqual:contact.uuid] || ![contact hasPrivatePeer]) {
        return;
    }
    
    self.contact = contact;
    self.peerTwincodeOutboundId = contact.peerTwincodeOutboundId;
}

- (void)onUpdateDescriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onUpdateDescriptor: %@", LOG_TAG, descriptor);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<InfoItemServiceDelegate>)self.delegate onUpdateDescriptor:descriptor];
    });
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
