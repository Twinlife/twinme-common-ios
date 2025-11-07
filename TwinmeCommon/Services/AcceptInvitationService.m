/*
 *  Copyright (c) 2017-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLFilter.h>

#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLTwinmeAttributes.h>
#import <Twinme/TLSpace.h>
#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>

#import "AcceptInvitationService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_CURRENT_SPACE = 1 << 0;
static const int GET_CURRENT_SPACE_DONE = 1 << 1;
static const int PARSE_URI = 1 << 24;
static const int PARSE_URI_DONE = 1 << 25;
static const int GET_DESCRIPTOR = 1 << 26;
static const int GET_EXISTING_CONTACTS = 1 << 2;
static const int GET_EXISTING_CONTACTS_DONE = 1 << 3;
static const int GET_TWINCODE = 1 << 4;
static const int GET_TWINCODE_DONE = 1 << 5;
static const int GET_TWINCODE_IMAGE = 1 << 6;
static const int GET_TWINCODE_IMAGE_DONE = 1 << 7;
static const int GET_GROUP = 1 << 8;
static const int GET_GROUP_DONE = 1 << 9;
static const int GET_CONTACT = 1 << 10;
static const int GET_CONTACT_DONE = 1 << 11;
static const int CREATE_CONTACT = 1 << 12;
static const int CREATE_CONTACT_DONE = 1 << 13;
static const int DELETE_DESCRIPTOR = 1 << 14;
static const int DELETE_DESCRIPTOR_DONE = 1 << 15;
static const int DELETE_NOTIFICATION = 1 << 16;
static const int DELETE_NOTIFICATION_DONE = 1 << 17;
static const int SET_CURRENT_SPACE = 1 << 18;
static const int SET_CURRENT_SPACE_DONE = 1 << 19;

//
// Interface: AcceptInvitationService ()
//

@class AcceptInvitationServiceTwinmeContextDelegate;
@class AcceptInvitationServiceConversationServiceDelegate;

@interface AcceptInvitationService ()
@property (nonatomic, nullable) NSUUID *twincodeOutboundId;
@property (nonatomic, nullable) TLTwincodeOutbound *twincodeOutbound;

@property (nonatomic, nonnull, readonly) AcceptInvitationServiceConversationServiceDelegate *conversationServiceDelegate;
@property (nonatomic, nonnull, readonly) NSURL *uri;
@property (nonatomic, readonly, nullable) NSUUID *groupId;
@property (nonatomic, readonly, nullable) NSUUID *contactId;

@property (nonatomic) int work;

@property (nonatomic, nullable) TLImageId *twincodeAvatarId;
@property (nonatomic, nullable) TLDescriptorId *descriptorId;
@property (nonatomic, nullable) TLNotification *notification;
@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) TLProfile *profile;
@property (nonatomic, nullable) NSString *publicKey;
@property (nonatomic) TLTrustMethod trustMethod;

- (void)onOperation;

- (void)onCreateContact:(nonnull TLContact *)contact;

- (void)onGetTwincode:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

- (void)onDeleteDescriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors;

- (void)onGetGroup:(nonnull TLGroup *)group errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

- (void)onGetContact:(nonnull TLContact *)contact errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onDeleteNotification:(nonnull NSUUID *)notificationId;

@end

//
// Interface: AcceptInvitationServiceTwinmeContextDelegate
//

@interface AcceptInvitationServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull AcceptInvitationService *)service;

@end

//
// Implementation: AcceptInvitationServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"AcceptInvitationServiceTwinmeContextDelegate"

@implementation AcceptInvitationServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull AcceptInvitationService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onCreateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onCreateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(AcceptInvitationService *)self.service onCreateContact:contact];
}

- (void)onDeleteNotificationsWithList:(nonnull NSArray<NSUUID *> *)list {
    DDLogVerbose(@"%@ onDeleteNotificationsWithList: %@", LOG_TAG, list);
    
    TLNotification *notification = [(AcceptInvitationService *)self.service notification];
    if (notification) {
        for (NSUUID *notificationId in list) {
            if ([notificationId isEqual:notification.uuid]) {
                [(AcceptInvitationService *)self.service onDeleteNotification:notificationId];
                return;
            }
        }
    }
}

- (void)onSetCurrentSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(AcceptInvitationService *)self.service onSetCurrentSpace:space];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(AcceptInvitationService *)self.service onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Interface: AcceptInvitationServiceConversationServiceDelegate
//

@interface AcceptInvitationServiceConversationServiceDelegate: NSObject <TLConversationServiceDelegate>

@property (weak) AcceptInvitationService *service;

- (nonnull instancetype)initWithService:(nonnull AcceptInvitationService *)service;

@end

//
// Implementation: AcceptInvitationServiceConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"AcceptInvitationServiceConversationServiceDelegate"

@implementation AcceptInvitationServiceConversationServiceDelegate

- (nonnull instancetype)initWithService:(nonnull AcceptInvitationService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super init];
    
    if (self) {
        _service = service;
    }
    return self;
}

- (void)onDeleteDescriptorsWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors {
    DDLogVerbose(@"%@ onDeleteDescriptorsWithRequestId: %lld conversation: %@ descriptor: %@", LOG_TAG, requestId, conversation, descriptors);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [self.service onDeleteDescriptors:descriptors];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [self.service onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
    [self.service onOperation];
}

@end

//
// Implementation: AcceptInvitationService
//

#undef LOG_TAG
#define LOG_TAG @"AcceptInvitationService"

@implementation AcceptInvitationService

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<AcceptInvitationServiceDelegate>)delegate uri:(nonnull NSURL *)uri contactId:(nullable NSUUID *)contactId groupId:(nullable NSUUID *)groupId descriptorId:(nullable TLDescriptorId *)descriptorId trustMethod:(TLTrustMethod)trustMethod {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@ uri: %@ contactId: %@ groupId: %@ descriptorId: %@", LOG_TAG, twinmeContext, delegate, uri, contactId, groupId, descriptorId);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[AcceptInvitationServiceTwinmeContextDelegate alloc] initWithService:self];
        _conversationServiceDelegate = [[AcceptInvitationServiceConversationServiceDelegate alloc] initWithService:self];
        _work = 0;
        _uri = uri;
        _groupId = groupId;
        _contactId = contactId;
        _descriptorId = descriptorId;
        _trustMethod = trustMethod;
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}

- (void)getDefaultProfile {
    DDLogVerbose(@"%@ getDefaultProfile", LOG_TAG);

    self.state &= ~(GET_CURRENT_SPACE | GET_CURRENT_SPACE_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)createContactWithProfile:(nonnull TLProfile *)profile space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ createContactWithProfile: %@ space: %@", LOG_TAG, profile, space);
    
    self.work |= CREATE_CONTACT;
    self.profile = profile;
    self.space = space;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)deleteDescriptor:(nonnull TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ deleteDescriptor: %@", LOG_TAG, descriptorId);
    
    self.work |= DELETE_DESCRIPTOR;
    self.descriptorId = descriptorId;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)deleteNotification:(nonnull TLNotification *)notification {
    DDLogVerbose(@"%@ deleteNotification: %@", LOG_TAG, notification);
    
    self.work |= DELETE_NOTIFICATION;
    self.notification = notification;
    [self showProgressIndicator];
    [self startOperation];
}

- (void)setCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ setCurrentSpace: %@", LOG_TAG, space);
    
    int64_t requestId = [self newOperation:SET_CURRENT_SPACE];
    [self showProgressIndicator];
    [self.twinmeContext setCurrentSpaceWithRequestId:requestId space:space];
    if (!space.settings.isSecret) {
        [self.twinmeContext setDefaultSpace:space];
    }
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    // Remove the peer twincode from our local cache:
    // - we want to force a fetch to the server the next time it is required,
    //   (so that we take into account a profile refresh by the peer)
    // - we don't need it in our database.
    // - when we evict the twincode, the associated avatar is also evicted.
    // - IFF the twincode is referenced, it is not and must not be evicted!
    if (self.twincodeOutbound) {
        [[self.twinmeContext getTwincodeOutboundService] evictWithTwincode:self.twincodeOutbound];
    }

    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];
    
    self.delegate = nil;
    [super dispose];
}

#pragma mark - Private methods

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getConversationService] addDelegate:self.conversationServiceDelegate];
    [super onTwinlifeReady];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        self.restarted = NO;
        
        if (((self.state & GET_TWINCODE) != 0 ) && ((self.state & GET_TWINCODE_DONE) == 0)) {
            self.state &= ~GET_TWINCODE;
        }
        if (((self.state & GET_TWINCODE_IMAGE) != 0 ) && ((self.state & GET_TWINCODE_IMAGE_DONE) == 0)) {
            self.state &= ~GET_TWINCODE_IMAGE;
        }
    }
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
            if (space && space.profile) {
                self.profile = space.profile;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [(id<AcceptInvitationServiceDelegate>)self.delegate onGetDefaultProfile:self.profile];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [(id<AcceptInvitationServiceDelegate>)self.delegate onGetDefaultProfileNotFound];
                });
            }
        }];
        
        if ((self.state & GET_CURRENT_SPACE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 2: parse the URI to build the TwincodeURI instance.
    //
    if (self.uri) {
        if ((self.state & PARSE_URI) == 0) {
            self.state |= PARSE_URI;
            [[self.twinmeContext getTwincodeOutboundService] parseUriWithUri:self.uri withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI *uri) {
                [self onParseTwincodeURI:errorCode uri:uri];
            }];
            return;
        }
        if ((self.state & PARSE_URI_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 2b: get the twincode from the twincode descriptor.
    //
    if (self.descriptorId) {
        if ((self.state & GET_DESCRIPTOR) == 0) {
            self.state |= GET_DESCRIPTOR;

            TLTwincodeDescriptor *twincodeDescriptor = [[self.twinmeContext getConversationService] getTwincodeWithDescriptorId:self.descriptorId];
            if (twincodeDescriptor) {
                self.twincodeOutboundId = twincodeDescriptor.twincodeId;
                self.publicKey = twincodeDescriptor.publicKey;
            } else {
                [self onParseTwincodeURI:TLBaseServiceErrorCodeItemNotFound uri:nil];
            }
        }
    }

    if (self.twincodeOutboundId) {
        //
        // Step 2: find whether we have some contacts that were created by this same invitation.
        //
        if ((self.state & GET_EXISTING_CONTACTS) == 0) {
            self.state |= GET_EXISTING_CONTACTS;

            TLFilter *filter = [TLFilter alloc];
            filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLContact *contact = (TLContact *)object;

                return [self.twincodeOutboundId isEqual:contact.publicPeerTwincodeOutboundId];
            };

            // Look for contacts matching the public peer twincode outbound in every space.
            [self.twinmeContext findContactsWithFilter:filter withBlock:^(NSMutableArray *contacts) {
                [self onExistingContacts:contacts];
            }];
            return;
        }
        
        if ((self.state & GET_EXISTING_CONTACTS_DONE) == 0) {
            return;
        }
        
        //
        // Step 3: get the twincode outbound.
        //
        if ((self.state & GET_TWINCODE) == 0) {
            self.state |= GET_TWINCODE;
                        
            if (self.publicKey) {
                [[self.twinmeContext getTwincodeOutboundService] getSignedTwincodeWithTwincodeId:self.twincodeOutboundId publicKey:self.publicKey trustMethod:self.trustMethod withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                    [self onGetTwincode:twincodeOutbound errorCode:errorCode];
                }];
            } else {
                [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.twincodeOutboundId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                    [self onGetTwincode:twincodeOutbound errorCode:errorCode];
                }];
            }
            return;
        }
        
        if ((self.state & GET_TWINCODE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 4: get the twincode avatar image.
    //
    if (self.twincodeAvatarId) {
        if ((self.state & GET_TWINCODE_IMAGE) == 0) {
            self.state |= GET_TWINCODE_IMAGE;
            
            DDLogVerbose(@"%@ getImageWithImageId: %@", LOG_TAG, self.twincodeAvatarId);
            [[self.twinmeContext getImageService] getImageWithImageId:self.twincodeAvatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                self.state |= GET_TWINCODE_IMAGE_DONE;
                if (image) {
                    [self runOnGetTwincodeWithTwincode:self.twincodeOutbound avatar:image];
                }
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_TWINCODE_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 5a: get the optional group.
    //
    if (self.groupId) {
        if ((self.state & GET_GROUP) == 0) {
            self.state |= GET_GROUP;
            
            [self.twinmeContext getGroupWithGroupId:self.groupId withBlock:^(TLBaseServiceErrorCode errorCode, TLGroup *group) {
                [self onGetGroup:group errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & GET_GROUP_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 5b: get the optional contact.
    //
    if (self.contactId) {
        if ((self.state & GET_CONTACT) == 0) {
            self.state |= GET_CONTACT;
            
            [self.twinmeContext getContactWithContactId:self.contactId withBlock:^(TLBaseServiceErrorCode errorCode, TLContact *contact) {
                [self onGetContact:contact errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & GET_CONTACT_DONE) == 0) {
            return;
        }
    }
    
    //
    // Work step: create the contact.
    //
    if (self.profile && self.twincodeOutbound && (self.work & CREATE_CONTACT) != 0) {
        if ((self.state & CREATE_CONTACT) == 0) {
            self.state |= CREATE_CONTACT;
            
            int64_t requestId = [self newOperation:CREATE_CONTACT];
            DDLogVerbose(@"%@ createContactPhase1WithRequestId %lld peerTwincodeOutbound: %@ profile: %@", LOG_TAG, requestId, self.twincodeOutbound, self.profile);
            [self.twinmeContext createContactPhase1WithRequestId:requestId peerTwincodeOutbound:self.twincodeOutbound space:self.space profile:self.profile];
            return;
        }
        
        if ((self.state & CREATE_CONTACT_DONE) == 0) {
            return;
        }
    }
    
    //
    // Work step: delete the descriptor.
    //
    if (self.descriptorId && (self.work & DELETE_DESCRIPTOR) != 0) {
        if ((self.state & DELETE_DESCRIPTOR) == 0) {
            self.state |= DELETE_DESCRIPTOR;
            
            int64_t requestId = [self newOperation:DELETE_DESCRIPTOR];
            DDLogVerbose(@"%@ deleteDescriptor: %lld", LOG_TAG, requestId);
            [[self.twinmeContext getConversationService] deleteDescriptorWithRequestId:requestId descriptorId:self.descriptorId];
            return;
        }
        
        if ((self.state & DELETE_DESCRIPTOR_DONE) == 0) {
            return;
        }
    }
    
    //
    // Work step: delete the notification.
    //
    if (self.notification && (self.work & DELETE_NOTIFICATION) != 0) {
        if ((self.state & DELETE_NOTIFICATION) == 0) {
            self.state |= DELETE_NOTIFICATION;
            
            DDLogVerbose(@"%@ deleteNotificationWithNotification: %@", LOG_TAG, self.notification);
            [self.twinmeContext deleteWithNotification:self.notification];
            return;
        }
        
        if ((self.state & DELETE_NOTIFICATION_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

- (void)onCreateContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onCreateContact: %@", LOG_TAG, contact);
    
    self.state |= CREATE_CONTACT_DONE;
    
    // Keep the image because we are going to use it when the contact is created
    // (until the CreateContactPhase2 is called).
    self.twincodeAvatarId = nil;
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<AcceptInvitationServiceDelegate>)self.delegate onCreateContact:contact];
        });
    }
    [self onOperation];
}

- (void)onExistingContacts:(nonnull NSArray<TLContact *> *)contacts {
    DDLogVerbose(@"%@ onExistingContacts: %@", LOG_TAG, contacts);

    self.state |= GET_EXISTING_CONTACTS_DONE;
    if (self.delegate && contacts.count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<AcceptInvitationServiceDelegate>)self.delegate onExistingContacts:contacts];
        });
    }
    [self onOperation];
}

- (void)onParseTwincodeURI:(TLBaseServiceErrorCode)errorCode uri:(nullable TLTwincodeURI *)uri {
    DDLogVerbose(@"%@ onParseTwincodeURI: %d uri: %@", LOG_TAG, errorCode, uri);

    self.state |= PARSE_URI_DONE;
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<AcceptInvitationServiceDelegate>)self.delegate onParseTwincodeURI:errorCode uri:uri];
    });

    if (errorCode == TLBaseServiceErrorCodeSuccess && uri) {
        self.twincodeOutboundId = uri.twincodeId;
        self.publicKey = uri.publicKey;
    }
    [self onOperation];
}

- (void)onGetTwincode:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetTwincode: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeOutbound) {
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self runOnGetTwincodeNotFound];
        } else {
            [self onErrorWithOperationId:GET_TWINCODE errorCode:errorCode errorParameter:self.twincodeOutboundId.UUIDString];
        }
        return;
    }
    
    if (twincodeOutbound) {
        self.state |= GET_TWINCODE_DONE;

        TL_ASSERT_EQUAL(self.twinmeContext, twincodeOutbound.uuid, self.twincodeOutboundId, [ServicesAssertPoint INVALID_TWINCODE], TLAssertionParameterTwincodeId, [TLAssertValue initWithTwincodeOutbound:twincodeOutbound], nil);
        
        // If the twincode is one of our twincode, report the error to avoid creating the contact.
        if ([self.twinmeContext isProfileTwincode:twincodeOutbound.uuid]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<AcceptInvitationServiceDelegate>)self.delegate onLocalTwincode];
            });
            return;
        }
        
        self.twincodeOutbound = twincodeOutbound;
        self.twincodeAvatarId = [twincodeOutbound avatarId];
        [self runOnGetTwincodeWithTwincode:twincodeOutbound avatar:nil];
        
        [self onOperation];
    }
}

- (void)onGetGroup:(nonnull TLGroup *)group errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetGroup: %@", LOG_TAG, group);
    
    self.state |= GET_GROUP_DONE;
    if (group) {
        id <TLConversation> conversation = [[self.twinmeContext getConversationService] getConversationWithSubject:group];
        if (!conversation) {
            // This group has been deleted.
            [self runOnGetTwincodeNotFound];
        }
    } else if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        // Group not found means the invitation is invalid.
        [self runOnGetTwincodeNotFound];
    } else {
        [self onErrorWithOperationId:GET_GROUP errorCode:errorCode errorParameter:nil];
    }
    [self onOperation];
}

- (void)onGetContact:(nonnull TLContact *)contact errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetContact: %@", LOG_TAG, contact);
    
    self.state |= GET_CONTACT_DONE;
    if (contact) {
        
    } else if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        // Contact not found means the invitation is invalid.
        [self runOnGetTwincodeNotFound];
    } else {
        [self onErrorWithOperationId:GET_CONTACT errorCode:errorCode errorParameter:nil];
    }
    [self onOperation];
}

- (void)onDeleteDescriptors:(NSSet<TLDescriptorId *> *)descriptors {
    DDLogVerbose(@"%@ onDeleteDescriptors: %@", LOG_TAG, descriptors);
    
    self.state |= DELETE_DESCRIPTOR_DONE;
    
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<AcceptInvitationServiceDelegate>)self.delegate onDeleteDescriptors:descriptors];
        });
    }
    [self onOperation];
}

- (void)onDeleteNotification:(NSUUID *)notificationId {
    DDLogVerbose(@"%@ onDeleteNotification: %@", LOG_TAG, notificationId);
    
    self.state |= DELETE_NOTIFICATION_DONE;
    
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<AcceptInvitationServiceDelegate>)self.delegate onDeleteNotification:notificationId];
        });
    }
    [self onOperation];
}

- (void)onSetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    self.state |= SET_CURRENT_SPACE_DONE;
    [self runOnSetCurrentSpace:space];
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %i errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch (operationId) {
            case GET_TWINCODE:
                self.state |= GET_TWINCODE_DONE;
                [self runOnGetTwincodeNotFound];
                break;
                
            case GET_CONTACT:
                self.state |= GET_CONTACT_DONE;
                [self runOnGetTwincodeNotFound];
                break;
                
            case GET_GROUP:
                self.state |= GET_GROUP_DONE;
                [self runOnGetTwincodeNotFound];
                break;
                
            case CREATE_CONTACT:
                self.state |= CREATE_CONTACT_DONE;
                [self runOnGetTwincodeNotFound];
                break;
                
            case DELETE_DESCRIPTOR:
                self.state |= DELETE_DESCRIPTOR_DONE;
                
                // We can ignore deletion if the descriptor was not found.
                if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
                    if (self.delegate) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [(id<AcceptInvitationServiceDelegate>)self.delegate onDeleteDescriptors:[[NSSet alloc] initWithObjects:self.descriptorId, nil]];
                        });
                    }
                    return;
                }
                break;
                
            case DELETE_NOTIFICATION:
                self.state |= DELETE_NOTIFICATION_DONE;
                
                // We can ignore deletion if the notification was not found.
                if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
                    if (self.delegate && self.notification) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [(id<AcceptInvitationServiceDelegate>)self.delegate onDeleteNotification:self.notification.uuid];
                        });
                    }
                    return;
                }
                break;

            case GET_EXISTING_CONTACTS:
                self.state |= GET_EXISTING_CONTACTS_DONE;
                return;

            default:
                break;
        }
    } else if (errorCode == TLBaseServiceErrorCodeBadRequest && operationId == CREATE_CONTACT) {
        self.state |= CREATE_CONTACT_DONE;
        
        if (self.delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<AcceptInvitationServiceDelegate>)self.delegate onLocalTwincode];
            });
        }
        return;
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
