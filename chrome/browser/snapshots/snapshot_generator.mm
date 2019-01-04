// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/snapshots/snapshot_generator.h"

// TODO(crbug.com/636188): required to implement ViewHierarchyContainsWKWebView
// for -drawViewHierarchyInRect:afterScreenUpdates:, remove once the workaround
// is no longer needed.
#import <WebKit/WebKit.h>

#include <algorithm>

#include "base/bind.h"
#include "base/logging.h"
#include "base/task/post_task.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/snapshots/snapshot_cache.h"
#import "ios/chrome/browser/snapshots/snapshot_cache_factory.h"
#import "ios/chrome/browser/snapshots/snapshot_generator_delegate.h"
#import "ios/chrome/browser/snapshots/snapshot_overlay.h"
#import "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/web/public/web_state/web_state.h"
#import "ios/web/public/web_state/web_state_observer_bridge.h"
#include "ios/web/public/web_task_traits.h"
#include "ios/web/public/web_thread.h"
#include "ui/gfx/image/image.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// Returns YES if |view| or any view it contains is a WKWebView.
BOOL ViewHierarchyContainsWKWebView(UIView* view) {
  if ([view isKindOfClass:[WKWebView class]])
    return YES;
  for (UIView* subview in view.subviews) {
    if (ViewHierarchyContainsWKWebView(subview))
      return YES;
  }
  return NO;
}
}  // namespace

@interface SnapshotGenerator ()<CRWWebStateObserver>

// Property providing access to the snapshot's cache. May be nil.
@property(nonatomic, readonly) SnapshotCache* snapshotCache;

// The unique ID for the web state.
@property(nonatomic, copy) NSString* sessionID;

// The associated web state.
@property(nonatomic, assign) web::WebState* webState;

@end

@implementation SnapshotGenerator {
  std::unique_ptr<web::WebStateObserver> _webStateObserver;
}

- (instancetype)initWithWebState:(web::WebState*)webState
               snapshotSessionId:(NSString*)snapshotSessionId {
  if ((self = [super init])) {
    DCHECK(webState);
    DCHECK(snapshotSessionId);
    _webState = webState;
    _sessionID = snapshotSessionId;

    _webStateObserver = std::make_unique<web::WebStateObserverBridge>(self);
    _webState->AddObserver(_webStateObserver.get());
  }
  return self;
}

- (void)dealloc {
  if (_webState) {
    _webState->RemoveObserver(_webStateObserver.get());
    _webStateObserver.reset();
    _webState = nullptr;
  }
}

- (void)retrieveSnapshot:(void (^)(UIImage*))callback {
  DCHECK(callback);
  if (self.snapshotCache) {
    [self.snapshotCache retrieveImageForSessionID:self.sessionID
                                         callback:callback];
  } else {
    callback(nil);
  }
}

- (void)retrieveGreySnapshot:(void (^)(UIImage*))callback {
  DCHECK(callback);

  __weak SnapshotGenerator* weakSelf = self;
  void (^wrappedCallback)(UIImage*) = ^(UIImage* image) {
    if (!image) {
      image = [weakSelf updateSnapshot];
      if (image)
        image = GreyImage(image);
    }
    callback(image);
  };

  SnapshotCache* snapshotCache = self.snapshotCache;
  if (snapshotCache) {
    [snapshotCache retrieveGreyImageForSessionID:self.sessionID
                                        callback:wrappedCallback];
  } else {
    wrappedCallback(nil);
  }
}

- (UIImage*)updateSnapshot {
  UIImage* snapshot = [self generateSnapshotWithOverlays:YES];
  if (snapshot) {
    [self.snapshotCache setImage:snapshot withSessionID:self.sessionID];
  }
  return snapshot;
}

- (void)updateWebViewSnapshotWithCompletion:(void (^)(UIImage*))completion {
  DCHECK(self.webState);
  UIView* snapshotView = [self.delegate snapshotGenerator:self
                                      baseViewForWebState:self.webState];
  CGRect snapshotFrame =
      [self.webState->GetView() convertRect:[self snapshotFrame]
                                   fromView:snapshotView];
  if (CGRectIsEmpty(snapshotFrame)) {
    if (completion) {
      base::PostTaskWithTraits(FROM_HERE, {web::WebThread::UI},
                               base::BindOnce(^{
                                 completion(nil);
                               }));
    }
    return;
  }
  CGSize size = snapshotFrame.size;
  DCHECK(std::isnormal(size.width) && (size.width > 0))
      << ": snapshotFrame.size.width=" << size.width;
  DCHECK(std::isnormal(size.height) && (size.height > 0))
      << ": snapshotFrame.size.height=" << size.height;
  NSArray<SnapshotOverlay*>* overlays =
      [self.delegate snapshotGenerator:self
           snapshotOverlaysForWebState:self.webState];

  [self.delegate snapshotGenerator:self
      willUpdateSnapshotForWebState:self.webState];
  __weak SnapshotGenerator* weakSelf = self;
  self.webState->TakeSnapshot(
      snapshotFrame, base::BindOnce(^(const gfx::Image& image) {
        UIImage* snapshot = [weakSelf snapshotWithOverlays:overlays
                                                     image:image
                                                     frame:snapshotFrame];
        [weakSelf updateSnapshotCacheWithImage:snapshot];
        if (completion)
          completion(snapshot);
      }));
}

- (UIImage*)generateSnapshotWithOverlays:(BOOL)shouldAddOverlay {
  CGRect frame = [self snapshotFrame];
  if (CGRectIsEmpty(frame))
    return nil;

  NSArray<SnapshotOverlay*>* overlays =
      shouldAddOverlay ? [self.delegate snapshotGenerator:self
                              snapshotOverlaysForWebState:self.webState]
                       : nil;

  [self.delegate snapshotGenerator:self
      willUpdateSnapshotForWebState:self.webState];
  UIView* view = [self.delegate snapshotGenerator:self
                              baseViewForWebState:self.webState];
  UIImage* snapshot = [self generateSnapshotForView:view
                                           withRect:frame
                                           overlays:overlays];
  [self.delegate snapshotGenerator:self
      didUpdateSnapshotForWebState:self.webState
                         withImage:snapshot];
  return snapshot;
}

- (void)removeSnapshot {
  [self.snapshotCache removeImageWithSessionID:self.sessionID];
}

#pragma mark - Private methods

// Returns the frame of the snapshot. Will return an empty rectangle if the
// WebState is not ready to capture a snapshot.
- (CGRect)snapshotFrame {
  // Do not generate a snapshot if web usage is disabled (as the WebState's
  // view is blank in that case).
  if (!self.webState->IsWebUsageEnabled())
    return CGRectZero;

  // Do not generate a snapshot if the delegate says the WebState view is
  // not ready (this generally mean a placeholder is displayed).
  if (self.delegate && ![self.delegate snapshotGenerator:self
                              canTakeSnapshotForWebState:self.webState])
    return CGRectZero;

  UIView* view = [self.delegate snapshotGenerator:self
                              baseViewForWebState:self.webState];
  UIEdgeInsets headerInsets = [self.delegate snapshotGenerator:self
                                 snapshotEdgeInsetsForWebState:self.webState];
  return UIEdgeInsetsInsetRect(view.bounds, headerInsets);
}

// Takes a snapshot for the supplied view (which should correspond to the given
// type of web view). Returns an autoreleased image cropped and scaled
// appropriately. The image can also contain overlays (if |overlays| is not
// nil and not empty).
- (UIImage*)generateSnapshotForView:(UIView*)view
                           withRect:(CGRect)rect
                           overlays:(NSArray<SnapshotOverlay*>*)overlays {
  DCHECK(view);
  CGSize size = rect.size;
  DCHECK(std::isnormal(size.width) && (size.width > 0))
      << ": size.width=" << size.width;
  DCHECK(std::isnormal(size.height) && (size.height > 0))
      << ": size.height=" << size.height;
  const CGFloat kScale =
      std::max<CGFloat>(1.0, [self.snapshotCache snapshotScaleForDevice]);
  UIGraphicsBeginImageContextWithOptions(size, YES, kScale);
  CGContext* context = UIGraphicsGetCurrentContext();
  DCHECK(context);

  // TODO(crbug.com/636188): -drawViewHierarchyInRect:afterScreenUpdates: is
  // buggy on iOS 8/9/10 (and state is unknown for iOS 11) causing GPU glitches,
  // screen redraws during animations, broken pinch to dismiss on tablet, etc.
  // For the moment, only use it for WKWebView with depends on it. Remove this
  // check and always use -drawViewHierarchyInRect:afterScreenUpdates: once it
  // is working correctly in all version of iOS supported.
  BOOL useDrawViewHierarchy = ViewHierarchyContainsWKWebView(view);

  BOOL snapshotSuccess = YES;
  CGContextSaveGState(context);
  CGContextTranslateCTM(context, -rect.origin.x, -rect.origin.y);
  if (useDrawViewHierarchy) {
    snapshotSuccess =
        [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:NO];
  } else {
    [[view layer] renderInContext:context];
  }
  if ([overlays count]) {
    for (SnapshotOverlay* overlay in overlays) {
      // Render the overlay view at the desired offset. It is achieved
      // by shifting origin of context because view frame is ignored when
      // drawing to context.
      CGContextSaveGState(context);
      CGContextTranslateCTM(context, 0, overlay.yOffset);
      // |drawViewHierarchyInRect:| has undefined behavior when the view is not
      // in the visible view hierarchy. In practice, when this method is called
      // on a view that is part of view controller containment, an
      // UIViewControllerHierarchyInconsistency exception will be thrown.
      if (useDrawViewHierarchy && overlay.view.window) {
        [overlay.view drawViewHierarchyInRect:overlay.view.bounds
                           afterScreenUpdates:YES];
      } else {
        [[overlay.view layer] renderInContext:context];
      }
      CGContextRestoreGState(context);
    }
  }
  UIImage* image = nil;
  if (snapshotSuccess)
    image = UIGraphicsGetImageFromCurrentImageContext();
  CGContextRestoreGState(context);
  UIGraphicsEndImageContext();
  return image;
}

// Returns an image of the |image| overlaid with |overlays| with the given
// |frame|.
- (UIImage*)snapshotWithOverlays:(NSArray<SnapshotOverlay*>*)overlays
                           image:(const gfx::Image&)image
                           frame:(CGRect)frame {
  if (image.IsEmpty())
    return nil;
  if (overlays.count == 0)
    return image.ToUIImage();
  CGSize size = frame.size;
  DCHECK(std::isnormal(size.width) && (size.width > 0))
      << ": size.width=" << size.width;
  DCHECK(std::isnormal(size.height) && (size.height > 0))
      << ": size.height=" << size.height;
  const CGFloat kScale =
      std::max<CGFloat>(1.0, [self.snapshotCache snapshotScaleForDevice]);
  UIGraphicsBeginImageContextWithOptions(size, YES, kScale);
  CGContext* context = UIGraphicsGetCurrentContext();
  DCHECK(context);
  CGContextSaveGState(context);
  [image.ToUIImage() drawAtPoint:CGPointZero];
  for (SnapshotOverlay* overlay in overlays) {
    // Render the overlay view at the desired offset. It is achieved
    // by shifting origin of context because view frame is ignored when
    // drawing to context.
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0, overlay.yOffset - frame.origin.y);
    // |drawViewHierarchyInRect:| has undefined behavior when the view is not in
    // the visible view hierarchy. In practice, when this method is called on a
    // view that is part of view controller containment, an
    // UIViewControllerHierarchyInconsistency exception will be thrown.
    if (overlay.view.window) {
      [overlay.view drawViewHierarchyInRect:overlay.view.bounds
                         afterScreenUpdates:YES];
    } else {
      [[overlay.view layer] renderInContext:context];
    }
    CGContextRestoreGState(context);
  }
  UIImage* snapshotWithOverlays = UIGraphicsGetImageFromCurrentImageContext();
  CGContextRestoreGState(context);
  UIGraphicsEndImageContext();
  return snapshotWithOverlays;
}

// Updates the snapshot cache with |snapshot|.
- (void)updateSnapshotCacheWithImage:(UIImage*)snapshot {
  if (snapshot) {
    [self.snapshotCache setImage:snapshot withSessionID:self.sessionID];
  } else {
    // Remove any stale snapshot since the snapshot failed.
    [self.snapshotCache removeImageWithSessionID:self.sessionID];
  }
  [self.delegate snapshotGenerator:self
      didUpdateSnapshotForWebState:self.webState
                         withImage:snapshot];
}

#pragma mark - Properties

- (SnapshotCache*)snapshotCache {
  return SnapshotCacheFactory::GetForBrowserState(
      ios::ChromeBrowserState::FromBrowserState(
          self.webState->GetBrowserState()));
}

#pragma mark - CRWWebStateObserver

- (void)webStateDestroyed:(web::WebState*)webState {
  DCHECK_EQ(_webState, webState);
  _webState->RemoveObserver(_webStateObserver.get());
  _webStateObserver.reset();
  _webState = nullptr;
}

@end
