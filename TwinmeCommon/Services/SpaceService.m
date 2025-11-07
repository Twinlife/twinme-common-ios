/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinme/TLTwinmeContext.h>

#import <Twinme/TLContact.h>
#import <Twinme/TLGroup.h>
#import <Twinme/TLSpace.h>
#import <Twinlife/TLFilter.h>

#import "SpaceService.h"
#import "AbstractTwinmeService+Protected.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_CURRENT_SPACE = 1 << 2;
static const int GET_CURRENT_SPACE_DONE = 1 << 3;
static const int GET_SPACES = 1 << 0;
static const int GET_SPACES_DONE = 1 << 1;
static const int DELETE_SPACE = 1 << 8;
static const int DELETE_SPACE_DONE = 1 << 9;
static const int SET_CURRENT_SPACE = 1 << 10;
static const int SET_CURRENT_SPACE_DONE = 1 << 11;
static const int MOVE_CONTACT_SPACE = 1 << 12;
static const int MOVE_CONTACT_SPACE_DONE = 1 << 13;
static const int GET_SPACE_NOTIFICATIONS = 1 << 19;
static const int GET_SPACE_NOTIFICATIONS_DONE = 1 << 20;
static const int MOVE_GROUP_SPACE = 1 << 23;
static const int MOVE_GROUP_SPACE_DONE = 1 << 24;
static const int FIND_CONTACTS = 1 << 27;
static const int FIND_CONTACTS_DONE = 1 << 28;

//
// Interface: SpaceService ()
//

@class SpaceServiceTwinmeContextDelegate;

@interface SpaceService ()

@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) TLSpaceSettings *spaceSettings;
@property (nonatomic, nullable) NSString *findName;
@property (nonatomic) NSString *nameProfile;
@property (nonatomic) UIImage *avatar;
@property (nonatomic) NSMutableArray *moveContacts;
@property (nonatomic) TLContact *currentMoveContact;
@property (nonatomic) int work;
@property (nonatomic) int stateDisabled;
@property int64_t beforeTimestamp;

- (void)onOperation;

- (void)onCreateSpace:(nonnull TLSpace *)space;

- (void)onUpdateSpace:(nonnull TLSpace *)space;

- (void)onDeleteSpace:(nonnull NSUUID *)spaceId;

- (void)onSetCurrentSpace:(nonnull TLSpace *)space;

- (void)onGetCurrentSpace:(nonnull TLSpace *)space;

- (void)onMoveContactToSpace:(nonnull TLContact *)contact oldSpace:(nonnull TLSpace *)oldSpace;

- (void)onUpdateProfile:(nonnull TLProfile *)profile;

- (void)onMoveGroupToSpace:(nonnull TLGroup *)group oldSpace:(nonnull TLSpace *)oldSpace;

- (void)onUpdatePendingNotifications:(BOOL)hasPendingNotifications;

@end


//
// Interface: SpaceServiceTwinmeContextDelegate
//

@interface SpaceServiceTwinmeContextDelegate : AbstractTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull SpaceService *)service;

@end

//
// Implementation: SpaceServiceTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"SpaceServiceTwinmeContextDelegate"

@implementation SpaceServiceTwinmeContextDelegate

- (nonnull instancetype)initWithService:(nonnull SpaceService *)service {
    DDLogVerbose(@"%@ initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service];
    return self;
}

- (void)onCreateSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onCreateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    // We want to be notified when a space is modified even it we did not trigger the create.
    [self.service finishOperation:requestId];
    
    [(SpaceService *)self.service onCreateSpace:space];
}

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    // We want to be notified when a space is modified even it we did not trigger the update.
    [self.service finishOperation:requestId];
    
    [(SpaceService *)self.service onUpdateSpace:space];
}

- (void)onDeleteSpaceWithRequestId:(int64_t)requestId spaceId:(NSUUID *)spaceId {
    DDLogVerbose(@"%@ onDeleteSpaceWithRequestId: %lld spaceId: %@", LOG_TAG, requestId, spaceId);
    
    // We want to be notified when a space is deleted even it we did not trigger the delete.
    [self.service finishOperation:requestId];
    
    [(SpaceService *)self.service onDeleteSpace:spaceId];
}

- (void)onSetCurrentSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    [(SpaceService *)self.service onSetCurrentSpace:space];
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId contact:(TLContact *)contact oldSpace:(TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld contact: %@ oldSpace: %@", LOG_TAG, requestId, contact, oldSpace);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(SpaceService *)self.service onMoveContactToSpace:contact oldSpace:oldSpace];
}

- (void)onUpdateProfileWithRequestId:(int64_t)requestId profile:(TLProfile *)profile {
    DDLogVerbose(@"%@ onUpdateProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    // We want to be notified when a space is deleted even it we did not trigger the delete.
    [self.service finishOperation:requestId];
    
    [(SpaceService *)self.service onUpdateProfile:profile];
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId group:(TLGroup *)group oldSpace:(TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld group: %@ oldSpace: %@", LOG_TAG, requestId, group, oldSpace);
    
    int operationId = [self.service getOperation:requestId];
    if (!operationId) {
        return;
    }
    
    [(SpaceService *)self.service onMoveGroupToSpace:group oldSpace:oldSpace];
}

- (void)onUpdatePendingNotificationsWithRequestId:(int64_t)requestId hasPendingNotifications:(BOOL)hasPendingNotifications {
    DDLogVerbose(@"%@ onUpdatePendingNotificationsWithRequestId: %lld hasPendingNotifications: %@", LOG_TAG, requestId, hasPendingNotifications ? @"YES" : @"NO");
    
    [(SpaceService *)self.service onUpdatePendingNotifications:hasPendingNotifications];
}

@end

//
// Implementation: SpaceService
//

#undef LOG_TAG
#define LOG_TAG @"SpaceService"

@implementation SpaceService

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id <SpaceServiceDelegate>)delegate {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ delegate: %@", LOG_TAG, twinmeContext, delegate);
    
    self = [super initWithTwinmeContext:twinmeContext tag:LOG_TAG delegate:delegate];
    
    if (self) {
        self.twinmeContextDelegate = [[SpaceServiceTwinmeContextDelegate alloc] initWithService:self];
        [self.twinmeContext addDelegate:self.twinmeContextDelegate];
        
        // Disable getting the list of spaces if the delegate does not need it.
        if (![(id)delegate respondsToSelector:@selector(onGetSpaces:)]) {
            self.stateDisabled |= GET_SPACES | GET_SPACES_DONE;
        }
        
        // Disable getting the space notifications if the delegate does not need it.
        if (![(id)delegate respondsToSelector:@selector(onGetSpacesNotifications:)]) {
            self.stateDisabled |= GET_SPACE_NOTIFICATIONS | GET_SPACE_NOTIFICATIONS_DONE;
        }
        
        self.state = self.stateDisabled;
        self.beforeTimestamp = INT64_MAX;
    }
    return self;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    [super dispose];
}

- (void)getSpaces {
    DDLogVerbose(@"%@ getSpaces", LOG_TAG);
    
    self.state &= ~(GET_SPACES | GET_SPACES_DONE);
    [self showProgressIndicator];
    [self startOperation];
}

- (void)findSpaceByName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ findSpaceByName: %@", LOG_TAG, name);
    
    [self showProgressIndicator];
    NSString *lowerCaseName = [name.lowercaseString stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
    [self.twinmeContext findSpacesWithPredicate:^BOOL(TLSpace *space) {
        NSString *spaceName = [space.settings.name stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
        
        if (([name isEqualToString:space.settings.name] && space.settings.isSecret) || ([spaceName.lowercaseString containsString:lowerCaseName] && !space.settings.isSecret)) {
            return true;
        }
        return false;
    } withBlock:^(NSMutableArray<TLSpace *> *spaces) {
        
        self.state |= GET_SPACES_DONE;
        [self runOnGetSpaces:spaces];
        [self onOperation];
    }];
}

- (void)moveContacts:(nonnull NSMutableArray *)contacts {
    DDLogVerbose(@"%@ moveContacts: %@", LOG_TAG, contacts);
    
    self.moveContacts = contacts;
    self.work |= MOVE_CONTACT_SPACE;
    self.state &= ~(MOVE_CONTACT_SPACE | MOVE_CONTACT_SPACE_DONE);
    
    [self showProgressIndicator];
    
    [self startOperation];
}

- (void)nextMoveContact {
    DDLogVerbose(@"%@ nextMoveContact", LOG_TAG);
    
    if (!self.moveContacts || self.moveContacts.count == 0) {
        self.currentMoveContact = nil;
        
        self.state |= MOVE_CONTACT_SPACE | MOVE_CONTACT_SPACE_DONE;
        [self runOnUpdateSpace:self.space];
    } else {
        if (self.currentMoveContact) {
            [self.moveContacts removeObjectAtIndex:0];
        }
        
        if (self.moveContacts.count > 0) {
            self.currentMoveContact = [self.moveContacts objectAtIndex:0];
        } else {
            self.currentMoveContact = nil;
        }
        
        self.state &= ~(MOVE_CONTACT_SPACE | MOVE_CONTACT_SPACE_DONE);
    }
}

- (void)moveContactsInSpace:(nonnull NSMutableArray *)contacts space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ moveContactsInSpace: %@ space: %@", LOG_TAG, contacts, space);
    
    self.space = space;
    self.moveContacts = contacts;
    self.work |= MOVE_CONTACT_SPACE;
    self.state &= ~(MOVE_CONTACT_SPACE | MOVE_CONTACT_SPACE_DONE);
    
    [self showProgressIndicator];
    
    [self startOperation];
}

- (void)setCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ setCuurentSpace: %@", LOG_TAG, space);
    
    [self showProgressIndicator];
    int64_t requestId = [self newOperation:SET_CURRENT_SPACE];
    [self.twinmeContext setCurrentSpaceWithRequestId:requestId space:space];
    if (!space.settings.isSecret) {
        [self.twinmeContext setDefaultSpace:space];
    }
}

- (void)deleteSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ deleteSpace: %@", LOG_TAG, space);
    
    [self showProgressIndicator];
    int64_t requestId = [self newOperation:DELETE_SPACE];
    [self.twinmeContext deleteSpaceWithRequestId:requestId space:space];
}

- (void)moveContactToSpace:(nonnull TLSpace *)space contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ moveContactToSpace: %@ contact: %@", LOG_TAG, space, contact);
    
    [self showProgressIndicator];
    int64_t requestId = [self newOperation:MOVE_CONTACT_SPACE];
    [self.twinmeContext moveToSpaceWithRequestId:requestId contact:contact space:space];
}

- (void)moveGroupToSpace:(nonnull TLSpace *)space group:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ moveGroupToSpace: %@ group: %@", LOG_TAG, space, group);
    
    [self showProgressIndicator];
    int64_t requestId = [self newOperation:MOVE_GROUP_SPACE];
    [self.twinmeContext moveToSpaceWithRequestId:requestId group:group space:space];
}

- (void)getAllContacts {
    DDLogVerbose(@"%@ getAllContacts", LOG_TAG);
        
    TLFilter *filter = [[TLFilter alloc] init];
    filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
        TLContact *contact = (TLContact *)object;
        
        return !contact.space.settings.isSecret;
    };
    [self showProgressIndicator];

    [self.twinmeContext findContactsWithFilter:filter withBlock:^(NSMutableArray<TLContact *> *contacts) {
        [self runOnGetContacts:contacts];
        [self onOperation];
    }];
}

- (void)isEmptySpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ isEmptySpace: %@", LOG_TAG, space);
    
    [self.twinmeContext findContactsWithFilter:[self.twinmeContext createSpaceFilter] withBlock:^(NSMutableArray<TLContact *> *contacts) {
        if(contacts.count > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<SpaceServiceDelegate>)self.delegate onEmptySpace:space empty:NO];
            });
            [self onOperation];
        } else {
            [self.twinmeContext findGroupsWithFilter:[self.twinmeContext createSpaceFilter] withBlock:^(NSMutableArray<TLGroup *> *groups) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (groups.count > 0) {
                        [(id<SpaceServiceDelegate>)self.delegate onEmptySpace:space empty:NO];
                    } else {
                        [(id<SpaceServiceDelegate>)self.delegate onEmptySpace:space empty:YES];
                    }
                });
                [self onOperation];
            }];
        }
    }];
    
}

- (void)findContactsByName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ findSpaceByName: %@", LOG_TAG, name);
    
    self.findName = [name.lowercaseString stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
    self.work = FIND_CONTACTS;
    self.state &= ~(FIND_CONTACTS | FIND_CONTACTS_DONE);
    [self startOperation];
}

- (void)onCreateSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onCreateSpace: %@", LOG_TAG, space);

    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<SpaceServiceDelegate>)self.delegate onCreateSpace:space];
    });
    [self onOperation];
}

- (void)onUpdateSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpace: %@", LOG_TAG, space);
    
    [self runOnUpdateSpace:space];
    [self onOperation];
}

- (void)onDeleteSpace:(nonnull NSUUID *)spaceId {
    DDLogVerbose(@"%@ onDeleteSpace: %@", LOG_TAG, spaceId);
    
    self.state |= DELETE_SPACE_DONE;
    [self runOnDeleteSpace:spaceId];
    [self onOperation];
}

- (void)onSetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onSetCurrentSpace: %@", LOG_TAG, space);
    
    self.state |= SET_CURRENT_SPACE_DONE;
    
    if (space) {
        [self runOnSetCurrentSpace:space];
    }
    
    [self onOperation];
}

- (void)onGetCurrentSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onGetCurrentSpace: %@", LOG_TAG, space);

    self.state |= GET_CURRENT_SPACE_DONE;
    self.space = space;
    if (space) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(id<SpaceServiceDelegate>)self.delegate onGetCurrentSpace:space];
        });
    }
    [self onOperation];
}

- (void)onMoveContactToSpace:(nonnull TLContact *)contact oldSpace:(nonnull TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveContactToSpace: %@ oldSpace: %@", LOG_TAG, contact, oldSpace);
    
    self.state |= MOVE_CONTACT_SPACE_DONE;
    
    [self runOnUpdateContact:contact avatar:nil];
    [self nextMoveContact];
    [self onOperation];
}

- (void)onMoveGroupToSpace:(nonnull TLGroup *)group oldSpace:(nonnull TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveGroupToSpace: %@", LOG_TAG, group);
    
    self.state |= MOVE_GROUP_SPACE_DONE;
    [self runOnUpdateGroup:group avatar:nil];
    [self onOperation];
}

- (void)onUpdateProfile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ onUpdateProfile: %@", LOG_TAG, profile);

    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<SpaceServiceDelegate>)self.delegate onUpdateProfile:profile];
    });
    [self onOperation];
}

- (void)onUpdatePendingNotifications:(BOOL)hasPendingNotifications {
    DDLogVerbose(@"%@ onUpdatePendingNotifications: %@", LOG_TAG, hasPendingNotifications ? @"YES" : @"NO");
    
    self.state &= ~(GET_SPACE_NOTIFICATIONS | GET_SPACE_NOTIFICATIONS_DONE);
    self.state |= self.stateDisabled;
    [self onOperation];
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
            [self onGetCurrentSpace:space];
        }];
        return;
    }
    if ((self.state & GET_CURRENT_SPACE_DONE) == 0) {
        return;
    }
    
    //
    // Step 2: get the list of spaces.
    //
    if ((self.state & GET_SPACES) == 0) {
        self.state |= GET_SPACES;
        [self.twinmeContext findSpacesWithPredicate:^BOOL(TLSpace *space) {
            return !space.settings.isSecret || (space.settings.isSecret && [[self.twinmeContext getCurrentSpace] isEqual:space]);
        } withBlock:^(NSMutableArray<TLSpace *> *spaces) {
            self.state |= GET_SPACES_DONE;
            [self runOnGetSpaces:spaces];
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_SPACES_DONE) == 0) {
        return;
    }
    
    //
    // Step 3: get the pending space notifications.
    //
    if ((self.state & GET_SPACE_NOTIFICATIONS) == 0) {
        self.state |= GET_SPACE_NOTIFICATIONS;
        
        [self.twinmeContext getNotificationStatsWithBlock:^(TLBaseServiceErrorCode errorCode, NSDictionary<NSUUID *, TLNotificationServiceNotificationStat *> *spacesWithNotifications) {
            self.state |= GET_SPACE_NOTIFICATIONS_DONE;
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id<SpaceServiceDelegate>)self.delegate onGetSpacesNotifications:spacesWithNotifications];
            });
            [self onOperation];
        }];
        return;
    }
    if ((self.state & GET_SPACE_NOTIFICATIONS_DONE) == 0) {
        return;
    }
    
    if ((self.work & MOVE_CONTACT_SPACE) != 0 && self.space) {
        if ((self.state & MOVE_CONTACT_SPACE) == 0) {
            
            if (!self.currentMoveContact) {
                [self nextMoveContact];
            }
            
            self.state |= MOVE_CONTACT_SPACE;
            
            if (self.currentMoveContact) {
                int64_t requestId = [self newOperation:MOVE_CONTACT_SPACE];
                DDLogVerbose(@"%@ moveToSpaceWithRequestId: %lld contact:%@ space:%@", LOG_TAG, requestId, self.currentMoveContact, self.space);
                [self.twinmeContext moveToSpaceWithRequestId:requestId contact:self.currentMoveContact space:self.space];
                return;
            }
        }
        
        if ((self.state & MOVE_CONTACT_SPACE_DONE) == 0) {
            return;
        }
    }
    
    //
    // We must search for a contact with some name.
    //
    if ((self.work & FIND_CONTACTS) != 0) {
        if ((self.state & FIND_CONTACTS) == 0) {
            self.state |= FIND_CONTACTS;
                        
            TLFilter *filter = [[TLFilter alloc] init];
            filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLContact *contact = (TLContact *)object;
                
                NSString *contactName = [contact.name stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
                return [contactName.lowercaseString containsString:self.findName] && !contact.space.settings.isSecret;
            };
            
            [self.twinmeContext findContactsWithFilter:filter withBlock:^(NSMutableArray<TLContact *> *contacts) {
                self.state |= FIND_CONTACTS_DONE;
                [self runOnGetContacts:contacts];
                [self onOperation];
            }];
            return;
        }
        if ((self.state & FIND_CONTACTS_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    [self hideProgressIndicator];
}

@end
