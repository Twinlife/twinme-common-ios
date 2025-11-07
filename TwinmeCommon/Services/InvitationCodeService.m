/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLFilter.h>

#import <Twinme/TLSpace.h>
#import <Twinme/TLInvitation.h>
#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLTwinmeAttributes.h>

#import "InvitationCodeService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define DEFAULT_VALIDITY_PERIOD 24 //hours

#define LIMIT_INVITATION_CODE 5
#define LIMIT_INVITATION_CODE_PREMIUM 10
#define PERIOD_TO_DELETE 48

static const int CREATE_INVITATION = 1 << 0;
static const int CREATE_INVITATION_DONE = 1 << 1;
static const int CREATE_INVITATION_CODE = 1 << 2;
static const int CREATE_INVITATION_CODE_DONE = 1 << 3;
static const int UPDATE_INVITATION = 1 << 4;
static const int UPDATE_INVITATION_DONE = 1 << 5;
static const int GET_INVITATION_CODE = 1 << 6;
static const int GET_INVITATION_CODE_DONE = 1 << 7;
static const int GET_INVITATIONS = 1 << 8;
static const int GET_INVITATIONS_DONE = 1 << 9;
static const int DELETE_INVITATION = 1 << 10;
static const int DELETE_INVITATION_DONE = 1 << 11;
static const int GET_CURRENT_SPACE = 1 << 12;
static const int GET_CURRENT_SPACE_DONE = 1 << 13;
static const int CREATE_CONTACT = 1 << 14;
static const int CREATE_CONTACT_DONE = 1 << 15;
static const int GET_TWINCODE_IMAGE = 1 << 16;
static const int GET_TWINCODE_IMAGE_DONE = 1 << 17;
static const int COUNT_VALID_INVITATIONS = 1 << 18;
static const int COUNT_VALID_INVITATIONS_DONE = 1 << 19;

//
// Interface: InvitationSubscriptionService ()
//

@interface InvitationCodeService ()

@property (nonatomic, nullable) TLInvitation *invitation;
@property (nonatomic) int validityPeriod;
@property (nonatomic, nullable) NSString *code;
@property (nonatomic, nullable) TLTwincodeOutbound *twincodeOutbound;
@property (nonatomic, nullable) NSString *publicKey;
@property (nonatomic, nullable) TLImageId *twincodeAvatarId;
@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) TLProfile *profile;
@property (nonatomic, nullable) NSMutableArray<TLInvitation *> *invitations;
@property (nonatomic, nullable) NSMutableArray<TLInvitation *> *invitationsToDelete;
@property (nonatomic) int invitationCodeLimit;

@property (nonatomic) int work;

- (void)onOperation;

- (void)onCreateInvitationWithCodeWithInvitation:(nonnull TLInvitation *)invitation;

- (void)onGetInvitationCodeWithTwincodeOutbound:(TLTwincodeOutbound *)twincodeOutbound publicKey:(NSString *)publicKey;

- (void)onDeleteInvitationWithInvitationId:(nonnull NSUUID *)invitationId;

- (void)onCreateContact:(nonnull TLContact *)contact;

@end

//
// Interface:InvitationCodeServiceTwinmeContextDelegate
//

@interface InvitationCodeServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (instancetype)initWithService:(InvitationCodeService *)service;

@end

//
// Implementation: InvitationCodeServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"InvitationCodeServiceTwinmeContextDelegate"

@implementation InvitationCodeServiceTwinmeContextDelegate

- (instancetype)initWithService:(InvitationCodeService *)service {
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
    
    [(InvitationCodeService *)self.service onCreateContact:contact];
}

- (void)onCreateInvitationWithCodeWithRequestId:(int64_t)requestId invitation:(TLInvitation *)invitation {
    [(InvitationCodeService *)self.service onCreateInvitationWithCodeWithInvitation:invitation];
}

- (void)onGetInvitationCodeWithRequestId:(int64_t)requestId twincodeOutbound:(TLTwincodeOutbound *)twincodeOutbound publicKey:(NSString *)publicKey {
    [(InvitationCodeService *)self.service onGetInvitationCodeWithTwincodeOutbound:twincodeOutbound publicKey:publicKey];
}

- (void)onDeleteInvitationWithRequestId:(int64_t)requestId invitationId:(NSUUID *)invitationId {
    [(InvitationCodeService *)self.service onDeleteInvitationWithInvitationId:invitationId];
}

@end

//
// Implementation: InvitationCodeService
//

#undef LOG_TAG
#define LOG_TAG @"InvitationCodeService"

@implementation InvitationCodeService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <InvitationCodeServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[InvitationCodeServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
    }
    return self;
}


- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [super onTwinlifeReady];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        self.restarted = NO;
        
        if (((self.state & CREATE_INVITATION_CODE) != 0 ) && ((self.state & CREATE_INVITATION_CODE_DONE) == 0)) {
            self.state &= ~CREATE_INVITATION_CODE;
        }
        if (((self.state & GET_INVITATION_CODE) != 0 ) && ((self.state & GET_INVITATION_CODE_DONE) == 0)) {
            self.state &= ~GET_INVITATION_CODE;
        }
        
        if (((self.state & GET_INVITATIONS) != 0 ) && ((self.state & GET_INVITATIONS_DONE) == 0)) {
            self.state &= ~GET_INVITATIONS;
        }
    }
}

- (void)createInvitationWithCode:(BOOL)isPremiumVersion {
    DDLogVerbose(@"%@ createInvitationWithCode", LOG_TAG);

    self.invitationCodeLimit = isPremiumVersion ? LIMIT_INVITATION_CODE_PREMIUM : LIMIT_INVITATION_CODE;
    
    self.work |= COUNT_VALID_INVITATIONS;
    self.state &= ~(COUNT_VALID_INVITATIONS | COUNT_VALID_INVITATIONS_DONE);
    
    [self startOperation];
}

- (void)getInvitationCodeWithCode:(nonnull NSString *)code {
    DDLogVerbose(@"%@ createInvitationCodeWithCode: %@", LOG_TAG, code);
    
    if (self.invitations) {
        for (TLInvitation *invitation in self.invitations) {
            if ([code isEqual:invitation.invitationCode.code]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([(id)self.delegate respondsToSelector:@selector(onGetLocalInvitationCode)]) {
                        [(id<InvitationCodeServiceDelegate>)self.delegate onGetLocalInvitationCode];
                    }
                });
                return;
            }
        }
    }
    
    self.code = code;
    
    self.work |= GET_INVITATION_CODE;
    self.state &= ~(GET_INVITATION_CODE | GET_INVITATION_CODE_DONE);
    
    [self startOperation];
}

- (void)getInvitations {
    DDLogVerbose(@"%@ getInvitations", LOG_TAG);
    
    self.work |= GET_INVITATIONS;
    self.state &= ~(GET_INVITATIONS | GET_INVITATIONS_DONE);
    
    [self startOperation];
}

- (void)deleteInvitationWithInvitation:(nonnull TLInvitation *)invitation {
    DDLogVerbose(@"%@ deleteInvitationWithInvitation: %@", LOG_TAG, invitation);
    
    self.invitation = invitation;
    
    self.work |= DELETE_INVITATION;
    self.state &= ~(DELETE_INVITATION | DELETE_INVITATION_DONE);
    
    [self startOperation];
}

- (void)createContact:(nonnull TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@ createContact: %@", LOG_TAG, twincodeOutbound);
    
    self.twincodeOutbound = twincodeOutbound;
    
    self.work |= CREATE_CONTACT;
    self.state &= ~(CREATE_CONTACT | CREATE_CONTACT_DONE);
    
    [self startOperation];
}

#pragma mark - Private methods

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
        
        [self.twinmeContext getCurrentSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace * _Nullable space) {
            DDLogVerbose(@"%@ onGetCurrentSpace: %@", LOG_TAG, space);
            
            self.state |= GET_CURRENT_SPACE_DONE;
            self.space = space;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (errorCode != TLBaseServiceErrorCodeSuccess || !space || !space.profile) {
                    if ([(id)self.delegate respondsToSelector:@selector(onGetDefaultProfileNotFound)]) {
                        [(id<InvitationCodeServiceDelegate>)self.delegate onGetDefaultProfileNotFound];
                    }
                } else if ([(id)self.delegate respondsToSelector:@selector(onGetDefaultProfileWithProfile:)]) {
                    self.profile = space.profile;
                    [(id<InvitationCodeServiceDelegate>)self.delegate onGetDefaultProfileWithProfile:space.profile];
                }
            });
            
            [self onOperation];
        }];
        return;
    }
    
    if ((self.state & GET_CURRENT_SPACE_DONE) == 0) {
        return;
    }
    
    //
    // Step 4: get the twincode avatar image.
    //
    if (self.twincodeAvatarId) {
        if ((self.state & GET_TWINCODE_IMAGE) == 0) {
            self.state |= GET_TWINCODE_IMAGE;
            
            DDLogVerbose(@"%@ getImageWithImageId: %@", LOG_TAG, self.twincodeAvatarId);
            [[self.twinmeContext getImageService] getImageWithImageId:self.twincodeAvatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                [self onGetTwincodeImage:image];
            }];
            return;
        }
        if ((self.state & GET_TWINCODE_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & GET_INVITATIONS) != 0) {
        if ((self.state & GET_INVITATIONS) == 0) {
            self.state |= GET_INVITATIONS;
            
            TLFilter *filter = [self.twinmeContext createSpaceFilter];
            filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLInvitation *invitation = (TLInvitation *)object;
                
                return invitation.invitationCode != nil;
            };
            
            [self.twinmeContext findInvitationsWithFilter:filter withBlock:^(NSArray<TLInvitation *> * _Nonnull list) {
                [self onGetInvitations:list];
            }];
        }
        
        if ((self.state & GET_INVITATIONS_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & COUNT_VALID_INVITATIONS) != 0) {
        if ((self.state & COUNT_VALID_INVITATIONS) == 0) {
            self.state |= COUNT_VALID_INVITATIONS;
            
            TLFilter *filter = [TLFilter alloc];
            filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLInvitation *invitation = (TLInvitation *)object;
                return invitation.invitationCode != nil && [[NSDate dateWithTimeIntervalSince1970:(invitation.invitationCode.creationDate / 1000) + (60L * 60 * invitation.invitationCode.validityPeriod)] compare:[NSDate date]] == NSOrderedDescending;
            };
            
            [self.twinmeContext findInvitationsWithFilter:filter withBlock:^(NSArray<TLInvitation *> * _Nonnull list) {
                [self onCountValidInvitation:list.count];
                [self onOperation];
            }];
        }
        
        if ((self.state & COUNT_VALID_INVITATIONS_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & CREATE_INVITATION_CODE) != 0) {
        if ((self.state & CREATE_INVITATION_CODE) == 0) {
            self.state |= CREATE_INVITATION_CODE;
            
            int64_t requestId = [self newOperation:CREATE_INVITATION_CODE];
            [self.twinmeContext createInvitationWithCodeWithRequestId:requestId validityPeriod:self.validityPeriod];
            
            return;
        }
        
        if ((self.state & CREATE_INVITATION_CODE_DONE) == 0) {
            return;
        }
        

    }
    
    if ((self.work & GET_INVITATION_CODE) != 0) {
        if ((self.state & GET_INVITATION_CODE) == 0) {
            self.state |= GET_INVITATION_CODE;
            
            if (!self.code) {
                TL_ASSERT_NOT_NULL(self.twinmeContext, self.code, [ServicesAssertPoint PARAMETER], nil);
                return;
            }
            
            int64_t requestId = [self newOperation:GET_INVITATION_CODE];
            
            [self.twinmeContext getInvitationCodeWithRequestId:requestId code:self.code];
            return;
        }
        
        if ((self.state & GET_INVITATION_CODE_DONE) == 0) {
            return;
        }
    }
    
    if ((self.work & DELETE_INVITATION) != 0) {
        if ((self.state & DELETE_INVITATION) == 0) {
            self.state |= DELETE_INVITATION;
            
            if (!self.invitation) {
                TL_ASSERT_NOT_NULL(self.twinmeContext, self.invitation, [ServicesAssertPoint PARAMETER], nil);
                return;
            }
            
            int64_t requestId = [self newOperation:GET_INVITATION_CODE];
            [self.twinmeContext deleteInvitationWithRequestId:requestId invitation:self.invitation];
            return;
        }
        
        if ((self.state & DELETE_INVITATION_DONE) == 0) {
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
    // Last Step
    //
    
    [self hideProgressIndicator];
}

- (void)onCreateInvitationWithCodeWithInvitation:(nonnull TLInvitation *)invitation {
    DDLogVerbose(@"%@ onCreateInvitationWithCodeWithInvitation: %@", LOG_TAG, invitation);
    
    self.state |= CREATE_INVITATION_CODE_DONE;
    
    self.invitation = invitation;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([(id)self.delegate respondsToSelector:@selector(onCreateInvitationWithCodeWithInvitation:)]) {
            [(id<InvitationCodeServiceDelegate>)self.delegate onCreateInvitationWithCodeWithInvitation:self.invitation];
        }
    });
        
    [self onOperation];
}

- (void)onGetInvitationCodeWithTwincodeOutbound:(TLTwincodeOutbound *)twincodeOutbound publicKey:(NSString *)publicKey {
    DDLogVerbose(@"%@ onGetInvitationCodeWithTwincodeOutbound: %@ publicKey: %@", LOG_TAG, twincodeOutbound, publicKey);

    self.state |= GET_INVITATION_CODE_DONE;
    
    self.twincodeOutbound = twincodeOutbound;
    self.publicKey = publicKey;
    
    if (!self.twincodeOutbound.avatarId) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([(id)self.delegate respondsToSelector:@selector(onGetInvitationCodeWithTwincodeOutbound:avatar:publicKey:)]) {
                [(id<InvitationCodeServiceDelegate>)self.delegate onGetInvitationCodeWithTwincodeOutbound:twincodeOutbound avatar:nil publicKey:publicKey];
            }
        });
    } else {
        self.twincodeAvatarId = twincodeOutbound.avatarId;
        self.state &= ~(GET_TWINCODE_IMAGE | GET_TWINCODE_IMAGE_DONE);
    }

    [self onOperation];
}

- (void)onGetTwincodeImage:(UIImage *)avatar {
    DDLogVerbose(@"%@ onGetTwincodeImage: %@", LOG_TAG, avatar);

    self.state |= GET_TWINCODE_IMAGE_DONE;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([(id)self.delegate respondsToSelector:@selector(onGetInvitationCodeWithTwincodeOutbound:avatar:publicKey:)]) {
            [(id<InvitationCodeServiceDelegate>)self.delegate onGetInvitationCodeWithTwincodeOutbound:self.twincodeOutbound avatar:avatar publicKey:self.publicKey];
        }
    });
    
    [self onOperation];
}

- (void)onDeleteInvitationWithInvitationId:(nonnull NSUUID *)invitationId {
    DDLogVerbose(@"%@ onDeleteInvitationWithInvitationId: %@", LOG_TAG, invitationId);

    self.state |= DELETE_INVITATION_DONE;
    
    if (self.invitationsToDelete && self.invitationsToDelete.count > 0) {
        [self nextInvitationToDelete];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([(id)self.delegate respondsToSelector:@selector(onDeleteInvitationWithInvitationId:)]) {
                [(id<InvitationCodeServiceDelegate>)self.delegate onDeleteInvitationWithInvitationId:invitationId];
            }
        });
    }
    
    [self onOperation];
}

- (void)nextInvitationToDelete {
    DDLogVerbose(@"%@ nextInvitationToDelete", LOG_TAG);
    
    while (self.invitationsToDelete.count > 0) {
        self.invitation = [self.invitationsToDelete objectAtIndex:0];
        [self.invitationsToDelete removeObjectAtIndex:0];
        if (self.invitation) {
            self.work |= DELETE_INVITATION;
            self.state &= ~(DELETE_INVITATION | DELETE_INVITATION_DONE);
            [self onOperation];
            return;
        }
    }
}

- (void)onCreateContact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onCreateContact: %@", LOG_TAG, contact);
    
    self.state |= CREATE_CONTACT_DONE;
    
    self.twincodeAvatarId = nil;
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<InvitationCodeServiceDelegate>)self.delegate onCreateContact:contact];
        });
    }
    [self onOperation];
}

- (void)onGetInvitations:(NSArray<TLInvitation *> *)invitations {
    DDLogVerbose(@"%@ onGetInvitations: %@", LOG_TAG, invitations);
    
    self.state |= GET_INVITATIONS_DONE;
    
    if (!self.invitations) {
        self.invitations = [[NSMutableArray alloc]init];
        self.invitationsToDelete = [[NSMutableArray alloc]init];
    }
    
    [self.invitations removeAllObjects];
    [self.invitationsToDelete removeAllObjects];
    
    for (TLInvitation *invitation in invitations) {
        
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSince1970:(invitation.invitationCode.creationDate / 1000) + (60L * 60 * invitation.invitationCode.validityPeriod)];
        NSDate *deleteDate = [expirationDate dateByAddingTimeInterval:PERIOD_TO_DELETE * 60 * 60];
        
        if ([deleteDate compare:[NSDate date]] == NSOrderedDescending) {
            [self.invitations addObject:invitation];
        } else {
            [self.invitationsToDelete addObject:invitation];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([(id)self.delegate respondsToSelector:@selector(onGetInvitationsWithInvitations:)]) {
            [(id<InvitationCodeServiceDelegate>)self.delegate onGetInvitationsWithInvitations:self.invitations];
        }
    });
    
    if (self.invitationsToDelete.count > 0) {
        [self nextInvitationToDelete];
    }
    
    [self onOperation];
}

- (void)onCountValidInvitation:(NSUInteger)count {
    DDLogVerbose(@"%@ onCountValidInvitation: %lu", LOG_TAG, (unsigned long)count);
    
    self.state |= COUNT_VALID_INVITATIONS_DONE;
    
    if (count >= self.invitationCodeLimit) {
        if (self.delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<InvitationCodeServiceDelegate>)self.delegate onLimitInvitationCodeReach];
            });
        }
    } else {
        self.validityPeriod = DEFAULT_VALIDITY_PERIOD;
        
        self.work |= CREATE_INVITATION_CODE;
        self.state &= ~(CREATE_INVITATION | CREATE_INVITATION_DONE | CREATE_INVITATION_CODE | CREATE_INVITATION_CODE_DONE | UPDATE_INVITATION | UPDATE_INVITATION_DONE);
    }
    
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %i errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
        
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    if (errorCode == TLBaseServiceErrorCodeItemNotFound && operationId == GET_INVITATION_CODE) {
        if (self.delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<InvitationCodeServiceDelegate>)self.delegate onGetInvitationCodeNotFound];
            });
        }
        return;
    }
    
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<InvitationCodeServiceDelegate>)self.delegate onInvitationCodeError:errorCode];
        });
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
