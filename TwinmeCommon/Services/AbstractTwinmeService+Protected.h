/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "AbstractTwinmeService.h"

#ifdef DEBUG
#define TWINLIFE_CHECK_THREAD(MSG)      NSAssert(!NSThread.isMainThread, @MSG);
#define TWINLIFE_CHECK_MAIN_THREAD(MSG) NSAssert(NSThread.isMainThread, @MSG);
#else
#define TWINLIFE_CHECK_THREAD(MSG)
#define TWINLIFE_CHECK_MAIN_THREAD(MSG)
#endif

/**
 * Interfaces and declarations defined in this file are internal to the services and should not be used by a ViewController directly.
 * - `onOperation`, `finishOperation`, `getOperation` must be called from the twinlife executor's thread.
 * - `onXXX` observers are called from the twinlife executor thread, either by TwinlifeContext or from a Twinlife service.
 * - several `runOnXXX` methods are defined to trigger the execution of the UI observer from the main UI thread.
 *   They check whether the view delegate supports the method and call it from the main UI thread.
 * - several `getImageWithXXX` operation that return the UIImage must be called only from the twinlife executor's thread.
 *   They are not visible to the ViewController which must use the asynchronous form with the code block.
 */

//
// Interface: AbstractTwinmeServiceDelegate
//

@interface AbstractTwinmeServiceDelegate:NSObject <AbstractTwinmeDelegate>

@property (nullable, weak) AbstractTwinmeService *service;
- (nonnull instancetype)initWithService:(nonnull AbstractTwinmeService *)service;

- (void)onTwinlifeReady;

- (void)onTwinlifeOnline;

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus;

- (void)showProgressIndicator;

- (void)hideProgressIndicator;

- (void)signIn;

- (void)onSignIn;

@end

//
// Interface: AbstractTwinmeContextDelegate
//

@interface AbstractTwinmeContextDelegate:NSObject <TLTwinmeContextDelegate>

@property (nullable, weak) AbstractTwinmeService *service;

- (nonnull instancetype)initWithService:(nonnull AbstractTwinmeService *)service;

- (void)onTwinlifeReady;

- (void)onTwinlifeOnline;

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus;

@end

//
// Interface: AbstractTwinmeService
//

@interface AbstractTwinmeService ()

@property (nonatomic, nullable) id<AbstractTwinmeDelegate> delegate;
@property (nonatomic, readonly, nonnull) TLTwinmeContext *twinmeContext;
@property (nonatomic, readonly, nonnull) NSString *tag;

@property (nonatomic) BOOL connected;

@property (nonatomic) BOOL isTwinlifeReady;
@property (nonatomic) int state;
@property (nonatomic, readonly, nonnull) NSMutableDictionary *requestIds;
@property (nonatomic) BOOL restarted;
@property (nonatomic, nullable) AbstractTwinmeContextDelegate *twinmeContextDelegate;

- (int64_t)newOperation:(int)operationId;

/// Finish and get the operation associated with the given requestId or returns nil if the request was not made by the service.
- (int)getOperation:(int64_t)requestId;

/// Start the pending operation from the twinlife executor thread.
- (void)startOperation;

/// Finish the operation associated with the given requestId.
- (void)finishOperation:(int64_t)requestId;

- (void)onOperation;

- (void)onTwinlifeReady;

- (void)onTwinlifeOnline;

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

- (void)showProgressIndicator;

- (void)hideProgressIndicator;

//
// CurrentSpaceTwinmeDelegate runner
//
- (void)runOnSetCurrentSpace:(nonnull TLSpace *)space;

//
// {Contact|Group|Space}TwinmeDelegate runners
//
- (void)runOnRefreshContactAvatar:(nullable UIImage *)avatar;

- (void)runOnUpdateContact:(nonnull TLContact *)contact avatar:(nullable UIImage *)avatar;

- (void)runOnDeleteContact:(nonnull NSUUID *)contactId;

- (void)runOnUpdateGroup:(nonnull TLGroup *)group avatar:(nullable UIImage *)avatar;

- (void)runOnDeleteGroup:(nonnull NSUUID *)groupId;

- (void)runOnUpdateSpace:(nonnull TLSpace *)space;

- (void)runOnDeleteSpace:(nonnull NSUUID *)spaceId;

- (void)runOnGetSpace:(nonnull TLSpace *)space avatar:(nullable UIImage *)avatar;

- (void)runOnGetSpaceNotFound;

//
// {Contact|Groups|Spaces}ListTwinmeDelegate runners
//
- (void)runOnGetContacts:(nonnull NSArray<TLContact *> *)contacts;

- (void)runOnGetGroups:(nonnull NSArray<TLGroup *> *)groups;

- (void)runOnGetSpaces:(nonnull NSArray<TLSpace *> *)spaces;

//
// TwincodeTwinmeDelegate runner
//
- (void)runOnGetTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincode avatar:(nullable UIImage *)avatar;

- (void)runOnGetTwincodeNotFound;

- (nonnull UIImage *)getImageWithContact:(nonnull id<TLOriginator>)originator;

- (nonnull UIImage *)getImageWithGroup:(nonnull TLGroup *)group;

- (nonnull UIImage *)getImageWithGroupMember:(nonnull TLGroupMember *)groupMember;

- (nonnull UIImage *)getImageWithTwincode:(nonnull TLTwincodeOutbound *)twincode;

#if 0
- (nonnull UIImage *)getIdentityImageWithContact:(nonnull id<TLOriginator>)originator kind:(TLImageServiceKind)kind;

- (nonnull UIImage *)getImageWithProfile:(nonnull TLProfile *)profile;


- (nonnull UIImage *)getIdentityImageWithGroup:(nonnull TLGroup *)group;

- (nonnull UIImage *)getImageWithSpace:(nonnull TLSpace *)space;

- (nonnull UIImage *)getImageWithSpaceCard:(nonnull TLSpaceCard *)spaceCard;

- (nonnull UIImage *)getImageWithCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (nonnull UIImage *)getIdentityImageWithCallReceiver:(nonnull TLCallReceiver *)callReceiver;
#endif

@end
