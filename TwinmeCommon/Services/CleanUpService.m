/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLConversationService.h>

#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLSpace.h>

#import "CleanUpService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_CONVERSATIONS = 1 << 1;
static const int GET_CONVERSATIONS_DONE = 1 << 2;

//
// Interface: CleanUpService ()
//

@interface CleanUpService () <TLExportDelegate>

@property (nonatomic, nullable) TLExportExecutor *export;
@property (nonatomic, readonly, nullable) TLContact *contact;
@property (nonatomic, readonly, nullable) TLGroup *group;
@property (nonatomic, readonly, nullable) TLSpace *space;
@property (nonatomic, nonnull, readonly) NSMutableArray<id<TLConversation>> *conversations;
@property (nonatomic) int work;

- (void)onOperation;

@end

//
// Interface: CleanUpServiceTwinmeContextDelegate
//

@interface CleanUpServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull CleanUpService *)service;

@end

//
// Implementation: CleanUpServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"CleanUpServiceTwinmeContextDelegate"

@implementation CleanUpServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull CleanUpService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

@end

//
// Implementation: CleanUpService
//

#undef LOG_TAG
#define LOG_TAG @"CleanUpService"

@implementation CleanUpService

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext delegate:(id<CleanUpServiceDelegate>)delegate space:(nullable TLSpace *)space contact:(nullable TLContact *)contact group:(nullable TLGroup *)group {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[CleanUpServiceTwinmeContextDelegate alloc] initWithService:self];
        BOOL needConversations = NO;
        if (space) {
            _space = space;
            needConversations = YES;
        } else if (contact) {
            _contact = contact;
        } else if (group) {
            _group = group;
        } else {
            needConversations = YES;
        }
        _export = [[TLExportExecutor alloc] initWithTwinmeContext:twinmeContext delegate:self statAllDescriptors:YES needConversations:needConversations];
        _conversations = [[NSMutableArray alloc]init];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)setDateFilter:(int64_t)dateFilter {
    DDLogVerbose(@"%@ setDateFilter: %lld", LOG_TAG, dateFilter);
    
    self.export.dateFilter = dateFilter;
    
    if (self.contact) {
        [self.export prepareWithContacts:@[self.contact]];
    } else if (self.group) {
        [self.export prepareWithGroups:@[self.group]];
    } else if (self.space) {
        [self.export prepareWithSpace:self.space reset:YES];
    } else {
        [self.export prepareAll];
    }
}

- (void)startCleanUpFrom:(int64_t)clearDate clearMode:(TLConversationServiceClearMode)clearMode {
    DDLogVerbose(@"%@ startCleanUp", LOG_TAG);
    
    dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
        if (self.export.conversations) {
            [self.conversations addObjectsFromArray:self.export.conversations];
        }
        for (id<TLConversation> conversation in self.conversations) {
            [[self.twinmeContext getConversationService] clearConversationWithConversation:conversation clearDate:clearDate clearMode:clearMode];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CleanUpServiceDelegate>)self.delegate onClearConversation];
        });
    });
}

#pragma mark - ExportDelegate methods

- (void)onProgressWithState:(TLExportState)state stats:(nonnull TLExportStats *)stats {
    DDLogVerbose(@"%@ onProgressWithState: %d stats: %@", LOG_TAG, state, stats);

    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CleanUpServiceDelegate>)self.delegate onProgressWithState:state stats:stats];
        });
    }
}

- (void)onErrorWithMessage:(nonnull NSString *)message {
    DDLogVerbose(@"%@ onErrorWithMessage: %@", LOG_TAG, message);

    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CleanUpServiceDelegate>)self.delegate onErrorWithMessage:message];
        });
    }
}

#pragma mark - Private methods

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    TWINLIFE_CHECK_MAIN_THREAD("Service must be called from main UI thread!");

    [self.export dispose];
    [super dispose];
    self.export = nil;
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    if ((self.state & GET_CONVERSATIONS) == 0) {
        self.state |= GET_CONVERSATIONS;
            
        if (self.contact) {
            id<TLConversation> conversation = [[self.twinmeContext getConversationService] getConversationWithSubject:self.contact];
            if (conversation) {
                [self.conversations addObject:conversation];
            }
            [self.export prepareWithContacts:@[self.contact]];
        } else if (self.group) {
            id<TLConversation> conversation = [[self.twinmeContext getConversationService] getConversationWithSubject:self.group];
            if (conversation) {
                [self.conversations addObject:conversation];
            }
            [self.export prepareWithGroups:@[self.group]];
        } else if (self.space) {
            [self.export prepareWithSpace:self.space reset:YES];
        } else {
            [self.export prepareAll];
        }
    }
    if ((self.state & GET_CONVERSATIONS_DONE) == 0) {
        return;
    }

    [self hideProgressIndicator];
}

@end
