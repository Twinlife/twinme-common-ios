/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLFilter.h>
#import <Twinlife/TLTwincodeURI.h>
#import <Twinlife/TLTwincodeOutboundService.h>

#import <Twinme/TLCallReceiver.h>
#import <Twinme/TLSpace.h>
#import <Twinme/TLTwinmeContext.h>

#import "CallReceiverService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int CREATE_CALL_RECEIVER = 1 << 0;
static const int CREATE_CALL_RECEIVER_DONE = 1 << 1;
static const int GET_CALL_RECEIVER = 1 << 2;
static const int GET_CALL_RECEIVER_DONE = 1 << 3;
static const int GET_CALL_RECEIVERS = 1 << 4;
static const int GET_CALL_RECEIVERS_DONE = 1 << 5;
static const int DELETE_CALL_RECEIVER = 1 << 6;
static const int DELETE_CALL_RECEIVER_DONE = 1 << 7;
static const int UPDATE_CALL_RECEIVER = 1 << 8;
static const int UPDATE_CALL_RECEIVER_DONE = 1 << 9;
static const int CHANGE_CALL_RECEIVER_TWINCODE = 1 << 10;
static const int CHANGE_CALL_RECEIVER_TWINCODE_DONE = 1 << 11;
static const int GET_CALL_RECEIVER_THUMBNAIL_IMAGE = 1 << 12;
static const int GET_CALL_RECEIVER_THUMBNAIL_IMAGE_DONE = 1 << 13;
static const int GET_CALL_RECEIVER_AVATAR = 1 << 14;
static const int GET_CALL_RECEIVER_AVATAR_DONE = 1 << 15;
static const int GET_INVITATION_LINK = 1 << 18;
static const int GET_INVITATION_LINK_DONE = 1 << 19;

//
// Interface: CallReceiverService ()
//

@class CallReceiverServiceTwinmeContextDelegate;

@interface CallReceiverService ()

@property(nonatomic) int work;

@property(nonatomic, nullable) TLCallReceiver *callReceiver;
@property(nonatomic, nonnull) NSString *name;
@property(nonatomic, nullable) NSString *callReceiverDescription;
@property(nonatomic, nullable) NSString *identityName;
@property(nonatomic, nullable) NSString *identityDescription;
@property(nonatomic, nullable) UIImage *avatar;
@property(nonatomic, nullable) UIImage *largeAvatar;
@property(nonatomic, nullable) TLImageId *avatarId;
@property(nonatomic, nullable) TLImageId *identityAvatarId;
@property(nonatomic, nullable) TLCapabilities *capabilities;
@property(nonatomic, nullable) TLSpace *space;
@property(nonatomic, nullable) TLTwincodeOutbound *twincodeOutbound;

@property(nonatomic, nullable) NSUUID *callReceiverId;
@property(nonatomic) TLTwincodeURIKind invitationKind;

- (void)onOperation;

- (void)onCreateCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onGetCallReceiver:(TLBaseServiceErrorCode)errorCode callReceiver:(nullable TLCallReceiver *)callReceiver;

- (void)onDeleteCallReceiver:(nonnull NSUUID *)callReceiverId;

- (void)onUpdateCallReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onChangeCallReceiverTwincode:(nonnull TLCallReceiver *)callReceiver;

@end

//
// Interface: CallReceiverServiceTwinmeContextDelegate
//

@interface CallReceiverServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull CallReceiverService *)service;

@end

//
// Implementation: CallReceiverServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"CallReceiverServiceTwinmeContextDelegate"

@implementation CallReceiverServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull CallReceiverService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);

    self = [super initWithService:service];
    return self;
}

- (void)onCreateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onCreateProfileWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);

    [(CallReceiverService *) self.service onCreateCallReceiver:callReceiver];
}

- (void)onDeleteCallReceiverWithRequestId:(int64_t)requestId callReceiverId:(NSUUID *)callReceiverId {
    DDLogVerbose(@"%@ onDeleteCallReceiverWithRequestId: %lld callReceiverId: %@", LOG_TAG, requestId, callReceiverId);

    [(CallReceiverService *) self.service onDeleteCallReceiver:callReceiverId];
}

- (void)onUpdateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onUpdateCallReceiverWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);

    [(CallReceiverService *) self.service onUpdateCallReceiver:callReceiver];
}

- (void)onChangeCallReceiverTwincodeWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onChangeCallReceiverTwincodeWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);

    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }

    [(CallReceiverService *) self.service onChangeCallReceiverTwincode:callReceiver];
}

@end

//
// Implementation: CallReceiverService
//

#undef LOG_TAG
#define LOG_TAG @"CallReceiverService"

@implementation CallReceiverService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <CallReceiverServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);

    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];

    if (self) {
        self.twinmeContextDelegate = [[CallReceiverServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)initWithCallReceiver:(nonnull TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ initWithCallReceiver: %@", LOG_TAG, callReceiver);

    self.callReceiver = callReceiver;
    self.callReceiverId = callReceiver.uuid;
    self.avatarId = callReceiver.avatarId;
    self.work |=  GET_CALL_RECEIVER_THUMBNAIL_IMAGE | GET_CALL_RECEIVER_AVATAR | GET_CALL_RECEIVER;
    self.state &= ~(GET_CALL_RECEIVER_THUMBNAIL_IMAGE | GET_CALL_RECEIVER_THUMBNAIL_IMAGE_DONE
                    | GET_CALL_RECEIVER_AVATAR | GET_CALL_RECEIVER_AVATAR_DONE | GET_CALL_RECEIVER | GET_CALL_RECEIVER_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)createCallReceiver:(NSString *)name description:(NSString *)description identityName:(NSString *)identityName identityDescription:(NSString *)identityDescription avatar:(UIImage *)avatar largeAvatar:(UIImage *)largeAvatar capabilities:(TLCapabilities *)capabilities space:(TLSpace *)space {
    DDLogVerbose(@"%@ createCallReceiver: name: %@ description: %@ identityName: %@ identityDescription: %@", LOG_TAG, name, description, identityName, identityDescription);

    self.name = name;
    self.callReceiverDescription = description;
    self.identityName = identityName;
    self.identityDescription = identityDescription;
    self.avatar = avatar;
    self.largeAvatar = largeAvatar;
    self.capabilities = capabilities;
    self.space = space;

    self.work |= CREATE_CALL_RECEIVER;
    self.state &= ~(CREATE_CALL_RECEIVER | CREATE_CALL_RECEIVER_DONE);

    [self showProgressIndicator];
    [self startOperation];
}

- (void)getCallReceiverWithCallReceiverId:(NSUUID *)callReceiverId {
    DDLogVerbose(@"%@ getCallReceiverWithCallReceiverId: callReceiverId: %@", LOG_TAG, callReceiverId);

    self.callReceiverId = callReceiverId;

    self.work |= GET_CALL_RECEIVER;
    self.state &= ~(GET_CALL_RECEIVER | GET_CALL_RECEIVER_DONE);

    [self startOperation];
}

- (void)getCallReceivers {
    DDLogVerbose(@"%@ getCallReceivers", LOG_TAG);

    self.work |= GET_CALL_RECEIVERS;
    self.state &= ~(GET_CALL_RECEIVERS | GET_CALL_RECEIVERS_DONE);

    [self startOperation];
}

- (void)deleteCallReceiverWithCallReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ deleteCallReceiverWithCallReceiverId", LOG_TAG);

    self.work |= DELETE_CALL_RECEIVER;
    self.state &= ~(DELETE_CALL_RECEIVER | DELETE_CALL_RECEIVER_DONE);

    self.callReceiver = callReceiver;
    
    [self startOperation];
}

- (void)updateCallReceiverWithCallReceiver:(TLCallReceiver *)callReceiver name:(NSString *)name description:(NSString *)description identityName:(NSString *)identityName identityDescription:(NSString *)identityDescription avatar:(UIImage *)avatar largeAvatar:(UIImage *)largeAvatar capabilities:(TLCapabilities *)capabilities {
    DDLogVerbose(@"%@ updateCallReceiverWithCallReceiver: name: %@ description: %@ identityName: %@ identityDescription: %@", LOG_TAG, name, description, identityName, identityDescription);

    self.callReceiver = callReceiver;
    
    self.name = name;
    self.callReceiverDescription = description;
    self.identityName = identityName;
    self.identityDescription = identityDescription;
    self.avatar = avatar;
    self.largeAvatar = largeAvatar;
    self.capabilities = capabilities;

    self.work |= UPDATE_CALL_RECEIVER;
    self.state &= ~(UPDATE_CALL_RECEIVER | UPDATE_CALL_RECEIVER_DONE);

    [self showProgressIndicator];
    [self startOperation];
}

- (void)changeCallReceiverTwincodeWithCallReceiver:(nonnull TLCallReceiver *)callReceiver{
    DDLogVerbose(@"%@ changeCallReceiverTwincodeWithCallReceiver: callReceiver: %@", LOG_TAG, callReceiver);
    
    self.callReceiver = callReceiver;

    self.work |= CHANGE_CALL_RECEIVER_TWINCODE;
    self.state &= ~(CHANGE_CALL_RECEIVER_TWINCODE | CHANGE_CALL_RECEIVER_TWINCODE_DONE);
    
    [self showProgressIndicator];
    [self startOperation];
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);

    if (!self.isTwinlifeReady) {
        return;
    }
    
    //
    // Step 1: Get the contact thumbnail image if we can.
    //
    if (self.avatarId && !self.avatar) {
        if ((self.state & GET_CALL_RECEIVER_THUMBNAIL_IMAGE) == 0) {
            self.state |= GET_CALL_RECEIVER_THUMBNAIL_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                self.state |= GET_CALL_RECEIVER_THUMBNAIL_IMAGE_DONE;
                if (status == TLBaseServiceErrorCodeSuccess && image) {
                    self.avatar = image;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.delegate) {
                            [(id<CallReceiverServiceDelegate>)self.delegate onUpdateCallReceiverAvatar:image];
                        }
                    });
                }
                [self onOperation];
            }];
            return;
        }
        
        if ((self.state & GET_CALL_RECEIVER_THUMBNAIL_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 2: Get the contact large image if we can.
    //
    if (self.avatarId) {
        if ((self.state & GET_CALL_RECEIVER_AVATAR) == 0) {
            self.state |= GET_CALL_RECEIVER_AVATAR;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindNormal withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
                self.state |= GET_CALL_RECEIVER_AVATAR_DONE;
                if (status == TLBaseServiceErrorCodeSuccess && image) {
                    self.avatar = image;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.delegate) {
                            [(id<CallReceiverServiceDelegate>)self.delegate onUpdateCallReceiverAvatar:image];
                        }
                    });
                }
                [self onOperation];
            }];
            return;
        }
        
        if ((self.state & GET_CALL_RECEIVER_AVATAR_DONE) == 0) {
            return;
        }
    }

    //
    // Work step: create a call receiver.
    //
    if ((self.work & CREATE_CALL_RECEIVER) != 0) {
        if ((self.state & CREATE_CALL_RECEIVER) == 0) {
            self.state |= CREATE_CALL_RECEIVER;

            int64_t requestId = [self newOperation:CREATE_CALL_RECEIVER];
            DDLogVerbose(@"%@ createCallReceiverWithRequestId: %lld", LOG_TAG, requestId);
            [self.twinmeContext createCallReceiverWithRequestId:requestId name:self.name description:self.callReceiverDescription identityName:self.identityName identityDescription:self.identityDescription avatar:self.avatar largeAvatar:self.largeAvatar capabilities:self.capabilities space:self.space];
            return;
        }

        if ((self.state & CREATE_CALL_RECEIVER_DONE) == 0) {
            return;
        }
    }

    //
    // Work step: get a call receiver.
    //
    if ((self.work & GET_CALL_RECEIVER) != 0) {
        if ((self.state & GET_CALL_RECEIVER) == 0) {
            self.state |= GET_CALL_RECEIVER;

            DDLogVerbose(@"%@ getCallReceiverWithCallReceiverId: %@", LOG_TAG, self.callReceiverId);
            [self.twinmeContext getCallReceiverWithCallReceiverId:self.callReceiverId withBlock:^(TLBaseServiceErrorCode errorCode, TLCallReceiver *callReceiver) {
                [self onGetCallReceiver:errorCode callReceiver:callReceiver];
            }];
            return;
        }
        if ((self.state & GET_CALL_RECEIVER_DONE) == 0) {
            return;
        }
    }

    //
    // Get the call receiver URI.
    //
    if (self.twincodeOutbound && ((self.work & GET_INVITATION_LINK) != 0)) {
        if ((self.state & GET_INVITATION_LINK) == 0) {
            self.state |= GET_INVITATION_LINK;
            [[self.twinmeContext getTwincodeOutboundService] createURIWithTwincodeKind:self.invitationKind twincodeOutbound:self.twincodeOutbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI *uri) {
                [self onCreateURI:errorCode uri:uri];
            }];
            return;
        }

        if ((self.state & GET_INVITATION_LINK_DONE) == 0) {
            return;
        }
    }

    //
    // Work step: get all call receivers.
    //
    if ((self.work & GET_CALL_RECEIVERS) != 0) {
        if ((self.state & GET_CALL_RECEIVERS) == 0) {
            self.state |= GET_CALL_RECEIVERS;

            DDLogVerbose(@"%@ findCallReceiversWithRequestId", LOG_TAG);
            
            TLFilter *filter = [self.twinmeContext createSpaceFilter];
            filter.acceptWithObject = ^BOOL(id<TLDatabaseObject>  _Nonnull object) {
                TLCallReceiver *callReceiver = (TLCallReceiver *)object;
                return !callReceiver.isTransfer;
            };
        
            [self.twinmeContext findCallReceiversWithFilter:filter withBlock:^(NSMutableArray<TLCallReceiver *> *callReceivers) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self onGetCallReceivers:callReceivers];
                });
            }];
            return;
        }
        if ((self.state & GET_CALL_RECEIVERS_DONE) == 0) {
            return;
        }
    }

    //
    // Work step: delete a call receiver.
    //
    if ((self.work & DELETE_CALL_RECEIVER) != 0) {
        if ((self.state & DELETE_CALL_RECEIVER) == 0) {
            self.state |= DELETE_CALL_RECEIVER;
            
            int64_t requestId = [self newOperation:DELETE_CALL_RECEIVER];
            DDLogVerbose(@"%@ deleteCallReceiverWithRequestId: %lld", LOG_TAG, requestId);
            [self.twinmeContext deleteCallReceiverWithRequestId:requestId callReceiver:self.callReceiver];
            return;
        }
        if ((self.state & DELETE_CALL_RECEIVER_DONE) == 0) {
            return;
        }
    }
    
    //
    // Work step: update a call receiver.
    //
    if ((self.work & UPDATE_CALL_RECEIVER) != 0) {
        if ((self.state & UPDATE_CALL_RECEIVER) == 0) {
            self.state |= UPDATE_CALL_RECEIVER;
            
            int64_t requestId = [self newOperation:UPDATE_CALL_RECEIVER];
            DDLogVerbose(@"%@ updateCallReceiverWithRequestId: %lld", LOG_TAG, requestId);
            [self.twinmeContext updateCallReceiverWithRequestId:requestId callReceiver:self.callReceiver name:self.name description:self.callReceiverDescription identityName:self.identityName identityDescription:self.identityDescription avatar:self.avatar largeAvatar:self.largeAvatar capabilities:self.capabilities];
            return;
        }
        if ((self.state & UPDATE_CALL_RECEIVER_DONE) == 0) {
            return;
        }
    }
    
    //
    // Work step: change a call receiver twincode.
    //
    if ((self.work & CHANGE_CALL_RECEIVER_TWINCODE) != 0) {
        if ((self.state & CHANGE_CALL_RECEIVER_TWINCODE) == 0) {
            self.state |= CHANGE_CALL_RECEIVER_TWINCODE;
            
            int64_t requestId = [self newOperation:CHANGE_CALL_RECEIVER_TWINCODE];
            DDLogVerbose(@"%@ updateCallReceiverWithRequestId: %lld", LOG_TAG, requestId);
            [self.twinmeContext changeCallReceiverTwincodeWithRequestId:requestId callReceiver:self.callReceiver];
            return;
        }
        if ((self.state & CHANGE_CALL_RECEIVER_TWINCODE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step: everything done, we can hide the progress indicator.
    //

    [self hideProgressIndicator];
}

- (void)onCreateCallReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onCreateCallReceiver: %@", LOG_TAG, callReceiver);

    self.state |= CREATE_CALL_RECEIVER_DONE;
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id <CallReceiverServiceDelegate>) self.delegate onCreateCallReceiver:callReceiver];
    });
    [self onOperation];
}

- (void)onGetCallReceiver:(TLBaseServiceErrorCode)errorCode callReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onGetCallReceiver: %d callReceiver: %@", LOG_TAG, errorCode, callReceiver);

    self.state |= GET_CALL_RECEIVER_DONE;
    if (callReceiver) {
        self.twincodeOutbound = callReceiver.twincodeOutbound;
        self.invitationKind = callReceiver.isTransfer ? TLTwincodeURIKindTransfer : TLTwincodeURIKindCall;
        self.work |= GET_INVITATION_LINK;
        self.state &= ~(GET_INVITATION_LINK | GET_INVITATION_LINK_DONE);
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id <CallReceiverServiceDelegate>) self.delegate onGetCallReceiver:callReceiver];
        });
    }
    [self onOperation];
}

- (void)onCreateURI:(TLBaseServiceErrorCode)errorCode uri:(nullable TLTwincodeURI *)uri {
    DDLogVerbose(@"%@ onCreateURI: %d uri: %@", LOG_TAG, errorCode, uri);

    self.state |= GET_INVITATION_LINK_DONE;
    if (uri) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<CallReceiverServiceDelegate>)self.delegate onGetTwincodeURI:uri];
        });
    }
    [self onOperation];
}

- (void)onGetCallReceivers:(NSArray<TLCallReceiver *> *)callReceivers {
    DDLogVerbose(@"%@ onGetCallReceivers: %@", LOG_TAG, callReceivers);

    self.state |= GET_CALL_RECEIVERS_DONE;

    NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"modificationDate" ascending:NO];
    callReceivers = [callReceivers sortedArrayUsingDescriptors:@[sd]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id <CallReceiverServiceDelegate>) self.delegate onGetCallReceivers:callReceivers];
    });
    [self onOperation];
}

- (void)onDeleteCallReceiver:(nonnull NSUUID *)callReceiverId {
    DDLogVerbose(@"%@ onDeleteCallReceiver: %@", LOG_TAG, callReceiverId);

    self.state |= DELETE_CALL_RECEIVER_DONE;
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id <CallReceiverServiceDelegate>) self.delegate onDeleteCallReceiver:callReceiverId];
    });
    [self onOperation];
}

- (void)onUpdateCallReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onUpdateCallReceiver: %@", LOG_TAG, callReceiver);

    self.state |= UPDATE_CALL_RECEIVER_DONE;
    // Trigger getting the avatar again if it was changed.
    if (!self.avatarId || ![self.avatarId isEqual:callReceiver.avatarId]) {
        self.state &= ~(GET_CALL_RECEIVER_THUMBNAIL_IMAGE | GET_CALL_RECEIVER_THUMBNAIL_IMAGE_DONE | GET_CALL_RECEIVER_AVATAR | GET_CALL_RECEIVER_AVATAR_DONE);
        self.avatarId = callReceiver.avatarId;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id <CallReceiverServiceDelegate>) self.delegate onUpdateCallReceiver:callReceiver];
    });
    [self onOperation];
}

-(void)onChangeCallReceiverTwincode:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onUpdateCallReceiver: %@", LOG_TAG, callReceiver);

    self.state |= CHANGE_CALL_RECEIVER_TWINCODE_DONE;
    self.callReceiver = callReceiver;
    self.twincodeOutbound = callReceiver.twincodeOutbound;
    
    self.work |= GET_INVITATION_LINK;
    self.state &= ~(GET_INVITATION_LINK | GET_INVITATION_LINK_DONE);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id <CallReceiverServiceDelegate>) self.delegate onChangeCallReceiverTwincode:callReceiver];
    });
    [self onOperation];
}

@end
