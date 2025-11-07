/*
 *  Copyright (c) 2021-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

@class TLTwinmeContext;
@class TwinmeApplication;

@protocol AsyncLoader

/// Load the object or perform some long computation from the Manager thread.
- (void)loadObjectWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext fetchCompletionHandler:(nonnull void (^)(_Nullable id<NSObject>item))completionHandler;

@end

@protocol AsyncLoaderDelegate

/// The async loader manager has successfully loaded some items.
/// This method is called from the main UI thread: the list of items are ready to be refreshed on the UI.
- (void)onLoadedWithItems:(nonnull NSMutableArray<id<NSObject>> *)items;

@end

//
// Interface: AsyncManager
//

/**
 * Asynchronous object loader, to use this:
 * <p>
 * 1. Implement the AsyncLoaderListener protocol on the ViewController,
 * <p>
 * 2. Allocate an instance of AsyncManager in the viewWillAppear(),
 * <p>
 * 3. For async loading, allocate a AsyncImageLoader, AsyncVideoLoader, or AsyncXXXLoader,
 * <p>
 * 4. Add the XXXLoader instance to the manager through the addItemWithAsyncLoader(Loader) instance,
 * <p>
 * 5. In finish(), stop the manager by calling the stop() method.
 */
@interface AsyncManager : NSObject

/// Create the async manager with the twinme context and application.
- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<AsyncLoaderDelegate>)delegate;

/// Stop the async loader (should be called from finish).
- (void)stop;

/// Clear the list of items to be loaded (should be called from viewWillDisappear).
- (void)clear;

/// Add an item to be loaded by the background executor.
- (void)addItemWithAsyncLoader:(nonnull id<AsyncLoader>)loader;

/// Run the block from the background executor's thread.
- (void)asyncLoader:(nonnull dispatch_block_t)block;

@end
