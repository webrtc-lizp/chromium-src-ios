// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/tab_grid/transitions/grid_transition_layout.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

#include "base/logging.h"

@interface GridTransitionLayout ()
@property(nonatomic, readwrite) NSArray<GridTransitionItem*>* inactiveItems;
@property(nonatomic, readwrite) GridTransitionActiveItem* activeItem;
@property(nonatomic, readwrite) GridTransitionItem* selectionItem;
@end

@implementation GridTransitionLayout
@synthesize activeItem = _activeItem;
@synthesize selectionItem = _selectionItem;
@synthesize inactiveItems = _inactiveItems;
@synthesize expandedRect = _expandedRect;

+ (instancetype)layoutWithInactiveItems:(NSArray<GridTransitionItem*>*)items
                             activeItem:(GridTransitionActiveItem*)activeItem
                          selectionItem:(GridTransitionItem*)selectionItem {
  DCHECK(items);
  GridTransitionLayout* layout = [[GridTransitionLayout alloc] init];
  layout.inactiveItems = items;
  layout.activeItem = activeItem;
  layout.selectionItem = selectionItem;
  return layout;
}

@end

@interface GridTransitionItem ()
@property(nonatomic, readwrite) UIView* cell;
@property(nonatomic, readwrite) CGPoint center;
@end

@implementation GridTransitionItem
@synthesize cell = _cell;
@synthesize center = _center;

+ (instancetype)itemWithCell:(UIView*)cell center:(CGPoint)center {
  DCHECK(cell);
  DCHECK(!cell.superview);
  GridTransitionItem* item = [[self alloc] init];
  item.cell = cell;
  item.center = center;
  return item;
}
@end

@interface GridTransitionActiveItem ()
@property(nonatomic, readwrite) UIView<GridToTabTransitionView>* cell;
@property(nonatomic, readwrite) CGSize size;
@end

@implementation GridTransitionActiveItem
@dynamic cell;
@synthesize size = _size;

+ (instancetype)itemWithCell:(UIView<GridToTabTransitionView>*)cell
                      center:(CGPoint)center
                        size:(CGSize)size {
  GridTransitionActiveItem* item = [self itemWithCell:cell center:center];
  item.size = size;
  return item;
}

@end
