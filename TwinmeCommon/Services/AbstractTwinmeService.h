/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinme/TLTwinmeContext.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLAssertion.h>

@class TLTwinmeContext;
@class AbstractTwinmeService;
@class AbstractTwinmeServiceDelegate;
@class AbstractTwinmeContextDelegate;
@class TLSpace;
@class TLGroup;
@class TLGroupMember;

/**
 * Notes:
 * - `initWithTwinmeContext`, `dispose` must be called from the main UI thread.
 *   They are visible for the ViewController.  We must limit the visible operation to the ViewController to the strict minimum.
 * - several `getImageXXX` operation allow the ViewController to retrieve image possibly in asynchronous manner.
 *   If the image must be loaded, it is loaded from the twinlife executor's thread and the code block passed to `getImageXXX`
 *   is executed from the main UI thread.
 * - several service internal operations are provided by the `AbstractTwinmeService+Protected.h` header which
 *   should be used only from the service implementation file.
 * - the delegate methods must be called from the main UI thread.
 * - several protocols are defined to follow Android implementation and provide common definitions for observer methods.
 */

//
// Interface: ServicesAssertPoint
//

@interface ServicesAssertPoint : TLAssertPoint

+(nonnull TLAssertPoint *)UNKNOWN_ERROR;
+(nonnull TLAssertPoint *)PARAMETER;
+(nonnull TLAssertPoint *)INVALID_TWINCODE;
+(nonnull TLAssertPoint *)INVALID_CONVERSATION_ID;

@end

//
// Protocol: AbstractTwinmeDelegate
//

@protocol AbstractTwinmeDelegate
@optional

- (void)showProgressIndicator;

- (void)hideProgressIndicator;

- (void)signIn;

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus;

- (void)onSignIn;

@end

@protocol ContactListTwinmeDelegate

- (void)onGetContacts:(nonnull NSArray<TLContact *> *)contacts;

@end

@protocol GroupListTwinmeDelegate

- (void)onGetGroups:(nonnull NSArray<TLGroup *> *)groups;

@end

@protocol SpaceListTwinmeDelegate

- (void)onGetSpaces:(nonnull NSArray<TLSpace *> *)spaces;

@end

@protocol ContactTwinmeDelegate
@optional

- (void)onRefreshContactAvatar:(nonnull UIImage *)avatar;

- (void)onUpdateContact:(nonnull TLContact *)contact avatar:(nullable UIImage *)avatar;

- (void)onDeleteContact:(nonnull NSUUID *)contactId;

@end

@protocol GroupTwinmeDelegate
@optional

- (void)onUpdateGroup:(nonnull TLGroup *)group avatar:(nullable UIImage *)avatar;

- (void)onDeleteGroup:(nonnull NSUUID *)groupId;

@end

@protocol SpaceTwinmeDelegate

@optional

- (void)onUpdateSpace:(nonnull TLSpace *)space;

- (void)onGetSpace:(nonnull TLSpace *)space avatar:(nullable UIImage *)avatar;

- (void)onGetSpaceNotFound;

- (void)onDeleteSpace:(nonnull NSUUID *)spaceId;

@end

@protocol CurrentSpaceTwinmeDelegate

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

@end

@protocol TwincodeTwinmeDelegate

- (void)onGetTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincode avatar:(nullable UIImage *)avatar;

- (void)onGetTwincodeNotFound;

@end

//
// Interface: AbstractTwinmeService
//

@interface AbstractTwinmeService : NSObject

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext tag:(nonnull NSString *)tag delegate:(nonnull id<AbstractTwinmeDelegate>)delegate;

- (void)dispose;

- (void)getImageWithImageId:(nonnull TLImageId *)imageId withBlock:(nonnull void (^)(UIImage *_Nonnull image))block;

- (void)getImageWithContact:(nonnull id<TLOriginator>)originator withBlock:(nonnull void (^)(UIImage *_Nonnull image))block;

- (void)getIdentityImageWithContact:(nonnull id<TLOriginator>)originator withBlock:(nonnull void (^)(UIImage *_Nonnull image))block;

- (void)getImageWithProfile:(nonnull TLProfile *)profile withBlock:(nonnull void (^)(UIImage *_Nonnull image))block;

- (void)getImageWithGroup:(nonnull TLGroup *)group withBlock:(nonnull void (^)(UIImage *_Nonnull image))block;

- (void)getImageWithGroupMember:(nonnull TLGroupMember *)groupMember withBlock:(nonnull void (^)(UIImage *_Nonnull image))block;

- (void)getIdentityImageWithGroup:(nonnull TLGroup *)group withBlock:(nonnull void (^)(UIImage *_Nonnull image))block;

- (void)getImageWithSpace:(nonnull TLSpace *)space withBlock:(nonnull void (^)(UIImage *_Nonnull image))block;

- (void)getImageWithCallReceiver:(nonnull TLCallReceiver *)callReceiver withBlock:(nonnull void (^)(UIImage *_Nonnull image))block;

- (void)getIdentityImageWithCallReceiver:(nonnull TLCallReceiver *)callReceiver withBlock:(nonnull void (^)(UIImage *_Nonnull image))block;

- (void)getConversationImage:(nullable NSUUID *)imageId defaultImage:(nonnull UIImage *)defaultImage withBlock:(nonnull void (^)(UIImage *_Nonnull image))block;

- (void)getImagesWithOriginators:(nonnull NSArray<id<TLOriginator>> *)list withBlock:(nonnull void (^)(NSMutableArray<UIImage *> *_Nonnull images))block;

- (void)parseUriWithUri:(nonnull NSURL *)uri withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeURI *_Nullable twincodeUri))block;

- (void)createUriWithKind:(TLTwincodeURIKind)kind twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeURI *_Nullable twincodeUri))block;

@end
