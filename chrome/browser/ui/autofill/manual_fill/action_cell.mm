// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/autofill/manual_fill/action_cell.h"

#import "ios/chrome/browser/ui/autofill/manual_fill/manual_fill_cell_utils.h"
#import "ios/chrome/browser/ui/autofill/manual_fill/uicolor_manualfill.h"
#import "ios/chrome/browser/ui/list_model/list_model.h"
#import "ios/chrome/common/ui_util/constraints_ui_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// The multiplier for the base system spacing at the top margin.
static const CGFloat TopBaseSystemSpacingMultiplier = 1.1;

// The multiplier for the base system spacing at the bottom margin.
static const CGFloat BottomBaseSystemSpacingMultiplier = 1.5;

}  // namespace

@interface ManualFillActionItem ()

// The action block to be called when the user taps the title.
@property(nonatomic, copy, readonly) void (^action)(void);

// The title for the action.
@property(nonatomic, copy, readonly) NSString* title;

@end

@implementation ManualFillActionItem

- (instancetype)initWithTitle:(NSString*)title action:(void (^)(void))action {
  self = [super initWithType:kItemTypeEnumZero];
  if (self) {
    _title = [title copy];
    _action = [action copy];
    _enabled = YES;
    self.cellClass = [ManualFillActionCell class];
  }
  return self;
}

- (void)configureCell:(ManualFillActionCell*)cell
           withStyler:(ChromeTableViewStyler*)styler {
  [super configureCell:cell withStyler:styler];
  cell.accessibilityIdentifier = nil;
  [cell setUpWithTitle:self.title
       accessibilityID:self.accessibilityIdentifier
                action:self.action
               enabled:self.enabled];
}

@end

@interface ManualFillActionCell ()
// The action block to be called when the user taps the title button.
@property(nonatomic, copy) void (^action)(void);
// The title button of this cell.
@property(nonatomic, strong) UIButton* titleButton;
@end

@implementation ManualFillActionCell

#pragma mark - Public

- (void)prepareForReuse {
  [super prepareForReuse];
  self.action = nil;
  [self.titleButton setTitle:nil forState:UIControlStateNormal];
  self.titleButton.accessibilityIdentifier = nil;
  [self.titleButton setTitleColor:UIColor.cr_manualFillTintColor
                         forState:UIControlStateNormal];
  self.titleButton.enabled = YES;
}

- (void)setUpWithTitle:(NSString*)title
       accessibilityID:(NSString*)accessibilityID
                action:(void (^)(void))action
               enabled:(BOOL)enabled {
  if (self.contentView.subviews.count == 0) {
    [self createView];
  }

  [self.titleButton setTitle:title forState:UIControlStateNormal];
  self.titleButton.accessibilityIdentifier = accessibilityID;
  self.titleButton.enabled = enabled;
  if (!enabled) {
    [self.titleButton setTitleColor:UIColor.lightGrayColor
                           forState:UIControlStateNormal];
  }
  self.action = action;
}

#pragma mark - Private

- (void)createView {
  self.selectionStyle = UITableViewCellSelectionStyleNone;

  UIView* guide = self.contentView;

  self.titleButton = CreateButtonWithSelectorAndTarget(
      @selector(userDidTapTitleButton:), self);
  self.titleButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
  [self.contentView addSubview:self.titleButton];
  HorizontalConstraintsForViewsOnGuideWithShift(@[ self.titleButton ], guide,
                                                0);
  VerticalConstraintsSpacingForViewsInContainerWithMultipliers(
      @[ self.titleButton ], self.contentView, TopBaseSystemSpacingMultiplier,
      0, BottomBaseSystemSpacingMultiplier);
}

- (void)userDidTapTitleButton:(UIButton*)sender {
  if (self.action) {
    self.action();
  }
}

@end
