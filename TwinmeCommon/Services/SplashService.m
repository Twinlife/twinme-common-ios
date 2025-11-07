/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLAccountService.h>
#import <Twinlife/TLAccountMigrationService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLImageService.h>
#import <Twinme/TLTwinmeContext.h>
#import <Twinme/TLContact.h>

#import "SplashService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_CURRENT_SPACE = 1 << 0;
static const int GET_CURRENT_SPACE_DONE = 1 << 1;
static const int GET_CONTACTS = 1 << 2;
static const int GET_CONTACTS_DONE = 1 << 3;
static const int GET_SUBSCRIPTION_TWINCODE = 1 << 4;
static const int GET_SUBSCRIPTION_TWINCODE_DONE = 1 << 5;
static const int GET_SUBSCRIPTION_IMAGE = 1 << 6;
static const int GET_SUBSCRIPTION_IMAGE_DONE = 1 << 7;

#define PROBE_UPGRADE_DELAY 0.2    // 200ms
#define CHECK_CONNECTION_DELAY 5.0 // Check for connection in 5 seconds.
#define CHECK_CONNECTION_REPEAT_DELAY 10.0 // Periodic check each 10 seconds.

//
// Interface: SplashService ()
//

@class SplashServiceTwinmeContextDelegate;

@interface SplashService ()

@property (nullable) NSTimer *timer;
@property (readonly, nullable) NSUUID *subscriptionTwincodeId;
@property (nullable) TLImageId *subscriptionImageId;

- (void)onTwinlifeReady;

- (void)onOperation;

- (void)checkDatabaseUpgrade;

- (void)onGetTwincode:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Interface: SplashServiceTwinmeContextDelegate
//

@interface SplashServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull SplashService *)service;

@end

//
// Implementation: SplashServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"SplashServiceTwinmeContextDelegate"

@implementation SplashServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull SplashService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

@end

//
// Implementation: SplashService
//

#undef LOG_TAG
#define LOG_TAG @"SplashService"

@implementation SplashService

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext subscriptionTwincodeId:(nullable NSUUID *)subscriptionTwincodeId delegate:(id<SplashServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ subscriptionTwincodeId: %@ delegate: %@", LOG_TAG, twinmeContext, subscriptionTwincodeId, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[SplashServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
        _subscriptionTwincodeId = subscriptionTwincodeId;
        
        // When a database upgrade is made, the onTwinlifeReady() is not called immediately but after some delay
        // which depends on the migration.  The isDatabaseUpgraded() will be set sometimes in a near future but we
        // cannot have a callback to be notified.  We also want to display some "Upgrading" message to the user as
        // soon as possible.  Setup a timer to test if the database upgrade is in progress.
        // The timer is scheduled each 200ms until onTwinlifeReady() is called.
        [self checkDatabaseUpgrade];
    }
    return self;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    
    // If the account is disabled, stop immediately and report the ApplicationStateTypeDisabled.
    TLAccountServiceAuthenticationAuthority authenticationAuthority = [[self.twinmeContext getAccountService] getAuthenticationAuthority];
    if (authenticationAuthority == TLAccountServiceAuthenticationAuthorityDisabled) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate) {
                [(id<SplashServiceDelegate>)self.delegate onState:ApplicationStateTypeDisabled];
            }
        });
        return;
    }
    
    self.isTwinlifeReady = YES;
    
    if ([[self.twinmeContext getAccountMigrationService] getActiveDeviceMigrationId]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<SplashServiceDelegate>)self.delegate onState:ApplicationStateTypeMigration];
        });
    } else if ([self.twinmeContext isDatabaseUpgraded]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<SplashServiceDelegate>)self.delegate onState:ApplicationStateTypeUpgrading];
        });
        
        // When doing an upgrade, we may need the connection to Twinme server and we may block
        // on the SplashScreen until this is finished.  Check in 5s if we are connected to report a message.
        // self.timer = [NSTimer scheduledTimerWithTimeInterval:CHECK_CONNECTION_DELAY target:self selector:@selector(checkConnection) userInfo:nil repeats:NO];
    }
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    // Only activated for the subscription twincodes if we don't know the twincode and the image.
    if (self.restarted) {
        self.restarted = NO;
        
        if (((self.state & GET_SUBSCRIPTION_TWINCODE) != 0 ) && ((self.state & GET_SUBSCRIPTION_TWINCODE_DONE) == 0)) {
            self.state &= ~GET_SUBSCRIPTION_TWINCODE;
        }
        if (((self.state & GET_SUBSCRIPTION_IMAGE) != 0 ) && ((self.state & GET_SUBSCRIPTION_IMAGE_DONE) == 0)) {
            self.state &= ~GET_SUBSCRIPTION_IMAGE;
        }
    }
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    
    self.delegate = nil;
    [super dispose];
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
        
        [self.twinmeContext getCurrentSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
            self.state |= GET_CURRENT_SPACE_DONE;
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_CURRENT_SPACE_DONE) == 0) {
        return;
    }
    
    //
    // Step 2: We must get the list of contacts for the space.
    //
    if ((self.state & GET_CONTACTS) == 0) {
        self.state |= GET_CONTACTS;
        
        [self.twinmeContext findContactsWithFilter:[self.twinmeContext createSpaceFilter] withBlock:^(NSMutableArray<TLContact *> *list) {
            self.state |= GET_CONTACTS_DONE;
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_CONTACTS_DONE) == 0) {
        return;
    }

    // If there is a subscription twincode get that twincode to get the thumbnail and use it if we have it.
    if (self.subscriptionTwincodeId && (self.state & GET_SUBSCRIPTION_TWINCODE) == 0) {
        self.state |= GET_SUBSCRIPTION_TWINCODE;
        
        [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.subscriptionTwincodeId refreshPeriod:0 withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
            [self onGetTwincode:twincodeOutbound errorCode:errorCode];
        }];
        // Continue even if we don't have the subscription twincode.
    }
    
    //
    // Step 23: Optional step to get the subscription image from the server.
    //
    if (self.subscriptionImageId) {
        if ((self.state & GET_SUBSCRIPTION_IMAGE) == 0) {
            self.state |= GET_SUBSCRIPTION_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.subscriptionImageId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                [self onGetImage:image errorCode:errorCode];
            }];
        }
    }
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
    
    if(![[self.twinmeContext getAccountMigrationService] getActiveDeviceMigrationId]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate) {
                [(id<SplashServiceDelegate>)self.delegate onState:ApplicationStateTypeReady];
            }
        });
    }
}

- (void)checkDatabaseUpgrade {
    DDLogVerbose(@"%@ checkDatabaseUpgrade", LOG_TAG);
    
    self.timer = nil;
    if ([self.twinmeContext isDatabaseUpgraded]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate) {
                [(id<SplashServiceDelegate>)self.delegate onState:ApplicationStateTypeUpgrading];
            }
        });
    } else {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:PROBE_UPGRADE_DELAY target:self selector:@selector(checkDatabaseUpgrade) userInfo:nil repeats:NO];
    }
}

- (void)checkConnection {
    DDLogVerbose(@"%@ checkConnection", LOG_TAG);
    
    self.timer = nil;
    if (![self.twinmeContext isConnected]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate) {
                [self.delegate onConnectionStatusChange:[self.twinmeContext connectionStatus]];
            }
        });
        
        self.timer = [NSTimer scheduledTimerWithTimeInterval:CHECK_CONNECTION_REPEAT_DELAY target:self selector:@selector(checkConnection) userInfo:nil repeats:NO];
    }
}

- (void)onGetTwincode:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetTwincode: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);
    
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    // Look in the image cache and load from database: we are running from twinlife executor and could
    // block while reading the database.
    self.state |= GET_SUBSCRIPTION_TWINCODE_DONE;
    if (twincodeOutbound && errorCode == TLBaseServiceErrorCodeSuccess && self.delegate) {
        TLImageId *imageId = twincodeOutbound.avatarId;
        if (imageId) {
            TLImageService *imageService = [self.twinmeContext getImageService];
            UIImage *image = [imageService getCachedImageWithImageId:imageId kind:TLImageServiceKindThumbnail];
            if (image) {
                self.state |= GET_SUBSCRIPTION_IMAGE | GET_SUBSCRIPTION_IMAGE_DONE;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.delegate && [(id)self.delegate respondsToSelector:@selector(onPremiumImage:)]) {
                        [(id<SplashServiceDelegate>)self.delegate onPremiumImage:image];
                    }
                });
            } else {
                self.subscriptionImageId = imageId;
            }
        }
    }
    [self onOperation];
}

- (void)onGetImage:(nullable UIImage *)image errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetImage: %@ errorCode: %d", LOG_TAG, image, errorCode);
    
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    self.state |= GET_SUBSCRIPTION_IMAGE_DONE;
    if (image) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [(id)self.delegate respondsToSelector:@selector(onPremiumImage:)]) {
                [(id<SplashServiceDelegate>)self.delegate onPremiumImage:image];
            }
        });
    }
}

@end
