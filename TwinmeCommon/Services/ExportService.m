/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "ExportService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int PREPARE_EXPORT = 1 << 1;

//
// Interface: ExportService ()
//

@interface ExportService () <TLExportDelegate>

@property (nonatomic, nullable) TLExportExecutor *export;
@property (nonatomic, nullable) NSString *path;
@property (nonatomic, readonly, nullable) TLContact *contact;
@property (nonatomic, readonly, nullable) TLGroup *group;
@property (nonatomic, readonly, nullable) TLSpace *space;

- (void)onTwinlifeReady;

- (void)onOperation;

@end

//
// Interface: ExportServiceTwinmeContextDelegate
//

@interface ExportServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ExportService *)service;

@end

//
// Implementation: ExportServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ExportServiceTwinmeContextDelegate"

@implementation ExportServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull ExportService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

@end

//
// Implementation: ExportService
//

#undef LOG_TAG
#define LOG_TAG @"ExportService"

@implementation ExportService

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext delegate:(id<ExportServiceDelegate>)delegate space:(nullable TLSpace *)space contact:(nullable TLContact *)contact group:(nullable TLGroup *)group {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@ space: %@ contact: %@ group: %@", LOG_TAG, twinmeContext, delegate, space, contact, group);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        if (space) {
            _space = space;
        } else if (contact) {
            _contact = contact;
        } else if (group) {
            _group = group;
        }
        self.twinmeContextDelegate = [[ExportServiceTwinmeContextDelegate alloc] initWithService:self];
        self.export = [[TLExportExecutor alloc] initWithTwinmeContext:twinmeContext delegate:self statAllDescriptors:NO needConversations:NO];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)runExport:(nonnull NSArray<NSNumber *> *)typeFilter fileName:(NSString *)fileName {
    DDLogVerbose(@"%@ runExport", LOG_TAG);
    
    self.path = [NSString stringWithFormat:@"%@/%@",
                        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0], fileName];
    self.export.typeFilter = typeFilter;
    [self.export runExportWithPath:self.path password:nil];
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);

    self.isTwinlifeReady = YES;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);

    [super dispose];
    
    if (self.path) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager removeItemAtPath:self.path error:nil];
        self.path = nil;
    }
}

#pragma mark - ExportDelegate methods

- (void)onProgressWithState:(TLExportState)state stats:(nonnull TLExportStats *)stats {
    DDLogVerbose(@"%@ onProgressWithState: %d stats: %@", LOG_TAG, state, stats);

    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (state == TLExportStateDone) {
                [(id<ExportServiceDelegate>)self.delegate onReadyToExport:self.path];
            } else {
                [(id<ExportServiceDelegate>)self.delegate onProgressWithState:state stats:stats];
            }
        });
    }
}

- (void)onErrorWithMessage:(nonnull NSString *)message {
    DDLogVerbose(@"%@ onErrorWithMessage: %@", LOG_TAG, message);

    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<ExportServiceDelegate>)self.delegate onErrorWithMessage:message];
        });
    }
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isTwinlifeReady) {
        return;
    }
    
    if ((self.state & PREPARE_EXPORT) == 0) {
        self.state |= PREPARE_EXPORT;
            
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
}

@end
