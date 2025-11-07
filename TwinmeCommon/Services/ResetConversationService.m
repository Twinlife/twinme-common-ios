/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLTwinmeAttributes.h>

#import "ResetConversationService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_OR_CREATE_CONVERSATION = 1 << 0;
static const int GET_OR_CREATE_CONVERSATION_DONE = 1 << 1;

//
// Interface: ResetConversationService ()
//

@class ResetConversationFilesTwinmeContextDelegate;
@class ResetConversationServiceConversationServiceDelegate;

@interface ResetConversationService ()

@property NSUUID *conversationId;
@property (nonatomic) id<TLOriginator> contact;
@property (nonatomic) NSUUID *twincodeOutboundId;
@property (nonatomic) NSUUID *peerTwincodeOutboundId;
@property (nonatomic) id <TLConversation> conversation;
@property (nonatomic) TLGroup *group;

@property (nonatomic) ResetConversationServiceConversationServiceDelegate *resetConversationServiceDelegate;

- (void)onOperation;

- (void)onGetOrCreateConversation:(id<TLConversation>)conversation;

- (void)onResetConversation:(id<TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode;

@end

//
// Interface: ResetConversationServiceTwinmeContextDelegate
//

@interface ResetConversationServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ResetConversationService *)service;

@end

//
// Implementation: ResetConversationServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ResetConversationServiceTwinmeContextDelegate"

@implementation ResetConversationServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ResetConversationService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

@end


//
// Interface: ResetConversationServiceConversationServiceDelegate
//

@interface ResetConversationServiceConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) ResetConversationService *service;

- (instancetype)initWithService:(ResetConversationService *)service;

@end

//
// Implementation: ResetConversationServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ResetConversationServiceConversationServiceDelegate"

@implementation ResetConversationServiceConversationServiceDelegate

- (instancetype)initWithService:(ResetConversationService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onResetConversationWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode {
    DDLogVerbose(@"%@ onResetConversationWithRequestId: %lld conversation: %@ clearMode: %d", LOG_TAG, requestId, conversation, clearMode);
    
    if (![conversation isConversationWithUUID:self.service.conversationId]) {
        return;
    }
    
    [self.service onResetConversation:conversation clearMode:clearMode];
}

@end

//
// Implementation: ResetConversationService
//

#undef LOG_TAG
#define LOG_TAG @"ResetConversationService"

@implementation ResetConversationService

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext delegate:(id<ResetConversationServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        _resetConversationServiceDelegate = [[ResetConversationServiceConversationServiceDelegate alloc] initWithService:self];
        
        self.twinmeContextDelegate = [[ResetConversationServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];        
    }
    return self;
}

#pragma mark - Public methods

- (void)initWithContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ initWithContact: %@", LOG_TAG, contact);
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, contact, [ServicesAssertPoint PARAMETER], nil);

    self.state = 0;
    self.contact = contact;
    self.twincodeOutboundId = contact.twincodeOutboundId;
    
    [self startOperation];
}

- (void)initWithGroup:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ initWithGroup: %@", LOG_TAG, group);
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, group, [ServicesAssertPoint PARAMETER], nil);

    self.state = 0;
    self.group = group;
    self.twincodeOutboundId = group.twincodeOutboundId;
    
    [self startOperation];
}

- (void)resetConversation {
    DDLogVerbose(@"%@ resetConversation", LOG_TAG);
    
    if (self.conversation) {
        dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
            [[self.twinmeContext getConversationService] clearConversationWithConversation:self.conversation clearDate:0 clearMode:TLConversationServiceClearBoth];
        });
    }
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [[self.twinmeContext getConversationService] removeDelegate:self.resetConversationServiceDelegate];
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
            }
        }
        
    } else if (self.contact) {
        if ((self.state & GET_OR_CREATE_CONVERSATION) == 0) {
            self.state |= GET_OR_CREATE_CONVERSATION;
            
            id<TLConversation> conversation = [[self.twinmeContext getConversationService] getOrCreateConversationWithSubject:self.contact create:true];
            [self onGetOrCreateConversation:conversation];
        }
        if ((self.state & GET_OR_CREATE_CONVERSATION_DONE) == 0) {
            return;
        }
    }
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getConversationService] addDelegate:self.resetConversationServiceDelegate];
    [super onTwinlifeReady];
}

- (void)onGetOrCreateConversation:(id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onGetOrCreateConversation: %@", LOG_TAG, conversation);

    self.state |= GET_OR_CREATE_CONVERSATION_DONE;
    
    self.conversation = conversation;
    self.conversationId = [self.conversation uuid];
    [self onOperation];
}

- (void)onResetConversation:(id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode {
    DDLogVerbose(@"%@ onResetConversation: %@ clearMode: %d", LOG_TAG, conversation, clearMode);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<ResetConversationServiceDelegate>)self.delegate onResetConversation:conversation clearMode:clearMode];
    });
}

@end
