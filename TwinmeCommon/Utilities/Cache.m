/*
 *  Copyright (c) 2017-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Thibaud David (contact@thibauddavid.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLConversationService.h>

#import "Cache.h"

#import "Design.h"

@interface Cache()

@property (nonatomic) NSCache *cache;

@end

//
// Implementation: Cache
//

@implementation Cache

+ (id)getInstance {
    
    static Cache *INSTANCE = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        INSTANCE = [[self alloc] init];
    });
    return INSTANCE;
}

- (instancetype)init {
    
    if (self = [super init]) {
        self.cache = [[NSCache alloc] init];
        self.cache.evictsObjectsWithDiscardedContent = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)applicationDidReceiveMemoryWarning {
    
    NSLog(@"[Cache] applicationDidReceiveMemoryWarning, clearing cache");
    [self.cache removeAllObjects];
}

- (void)setObject:(id)object forKey:(NSString *)key {
    
    [self.cache setObject:object forKey:key];
}

- (id)objectForKey:(NSString *)key {
    
    return [self.cache objectForKey:key];
}

- (UIImage *)imageFromImageDescriptor:(TLImageDescriptor *)imageDescriptor size:(CGSize)size {

    NSString *cacheKey = [NSString stringWithFormat:@"%@_%fx%f", [imageDescriptor getDescriptorKey], size.width, size.height];
    return [self.cache objectForKey:cacheKey];
}

- (void)setImageWithImageDescriptor:(nonnull TLImageDescriptor *)imageDescriptor size:(CGSize)size image:(nonnull UIImage*)image {

    NSString *cacheKey = [NSString stringWithFormat:@"%@_%fx%f", [imageDescriptor getDescriptorKey], size.width, size.height];
    [self.cache setObject:image forKey:cacheKey];
}

- (UIImage *)imageFromVideoDescriptor:(TLVideoDescriptor *)videoDescriptor size:(CGSize)size {
    
    NSString *cacheKey = [videoDescriptor getDescriptorKey];
    return [self objectForKey:cacheKey];
}

- (void)setImageWithVideoDescriptor:(nonnull TLVideoDescriptor *)videoDescriptor size:(CGSize)size image:(nonnull UIImage*)image {
    
    NSString *cacheKey = [videoDescriptor getDescriptorKey];
    [self.cache setObject:image forKey:cacheKey];
}

- (nullable NSString *)titleFromObjectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor {
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@_title", [objectDescriptor getDescriptorKey]];
    return [self.cache objectForKey:cacheKey];
}

- (nullable UIImage *)imageFromObjectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor {
 
    NSString *cacheKey = [NSString stringWithFormat:@"%@_image", [objectDescriptor getDescriptorKey]];
    return [self.cache objectForKey:cacheKey];
}

- (void)setTitleWithObjectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor title:(nonnull NSString *)title {
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@_title", [objectDescriptor getDescriptorKey]];
    [self.cache setObject:title forKey:cacheKey];
}

- (void)setImageWithObjectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor image:(nonnull UIImage*)image {
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@_image", [objectDescriptor getDescriptorKey]];
    [self.cache setObject:image forKey:cacheKey];
}

@end
