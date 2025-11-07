/*
 *  Copyright (c) 2023-2025twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"
#import <Twinme/TLExportExecutor.h>

//
// Protocol: ExportServiceDelegate
//

@protocol ExportServiceDelegate <AbstractTwinmeDelegate, TLExportDelegate>

- (void)onReadyToExport:(nonnull NSString *)path;

@end

//
// Interface: ExportService
//

@interface ExportService : AbstractTwinmeService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<ExportServiceDelegate>)delegate space:(nullable TLSpace *)space contact:(nullable TLContact *)contact group:(nullable TLGroup *)group;

/**
  * Create zip file
 */

- (void)runExport:(nonnull NSArray<NSNumber *> *)typeFilter fileName:(nonnull NSString *)fileName;

@end
