// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/autofill/cells/autofill_edit_item.h"

#import "ios/chrome/browser/ui/colors/MDCPalette+CrAdditions.h"
#import "ios/chrome/browser/ui/rtl_geometry.h"
#import "ios/third_party/material_components_ios/src/components/Palettes/src/MaterialPalettes.h"
#import "ios/third_party/material_roboto_font_loader_ios/src/src/MaterialRobotoFontLoader.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// Padding used on the leading and trailing edges of the cell.
const CGFloat kHorizontalPadding = 16;

// Padding used on the top and bottom edges of the cell.
const CGFloat kVerticalPadding = 16;

// Minimum gap between the label and the text field.
const CGFloat kLabelAndFieldGap = 5;
}  // namespace

@implementation AutofillEditItem

@synthesize textFieldName = _textFieldName;
@synthesize textFieldValue = _textFieldValue;
@synthesize cardTypeIcon = _cardTypeIcon;
@synthesize textFieldEnabled = _textFieldEnabled;
@synthesize autofillUIType = _autofillUIType;
@synthesize required = _required;

- (instancetype)initWithType:(NSInteger)type {
  self = [super initWithType:type];
  if (self) {
    self.cellClass = [AutofillEditCell class];
  }
  return self;
}

#pragma mark CollectionViewItem

- (void)configureCell:(AutofillEditCell*)cell {
  [super configureCell:cell];
  NSString* textLabelFormat = self.required ? @"%@*" : @"%@";
  cell.textLabel.text =
      [NSString stringWithFormat:textLabelFormat, self.textFieldName];
  cell.textField.text = self.textFieldValue;
  if (self.textFieldName.length) {
    cell.textField.accessibilityIdentifier =
        [NSString stringWithFormat:@"%@_textField", self.textFieldName];
  }
  cell.textField.enabled = self.textFieldEnabled;
  cell.textField.textColor = self.textFieldEnabled
                                 ? [[MDCPalette cr_bluePalette] tint500]
                                 : [[MDCPalette greyPalette] tint500];
  [cell.textField addTarget:self
                     action:@selector(textFieldChanged:)
           forControlEvents:UIControlEventEditingChanged];
  cell.cardTypeIconView.image = self.cardTypeIcon;
}

#pragma mark - Actions

- (void)textFieldChanged:(UITextField*)textField {
  self.textFieldValue = textField.text;
}

@end

@implementation AutofillEditCell {
  NSLayoutConstraint* _iconHeightConstraint;
  NSLayoutConstraint* _iconWidthConstraint;
  NSLayoutConstraint* _textFieldTrailingConstraint;
}

@synthesize textField = _textField;
@synthesize textLabel = _textLabel;
@synthesize cardTypeIconView = _cardTypeIconView;

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.isAccessibilityElement = YES;
    self.allowsCellInteractionsWhileEditing = YES;
    UIView* contentView = self.contentView;

    _textLabel = [[UILabel alloc] init];
    _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:_textLabel];

    _textField = [[UITextField alloc] init];
    _textField.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:_textField];

    _textLabel.font =
        [[MDFRobotoFontLoader sharedInstance] mediumFontOfSize:14];
    _textLabel.textColor = [[MDCPalette greyPalette] tint900];

    _textField.font = [[MDFRobotoFontLoader sharedInstance] lightFontOfSize:16];
    _textField.textColor = [[MDCPalette greyPalette] tint500];
    _textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    _textField.autocorrectionType = UITextAutocorrectionTypeNo;
    _textField.returnKeyType = UIReturnKeyDone;
    _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _textField.contentVerticalAlignment =
        UIControlContentVerticalAlignmentCenter;
    _textField.textAlignment =
        UseRTLLayout() ? NSTextAlignmentLeft : NSTextAlignmentRight;

    // Card type icon.
    _cardTypeIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _cardTypeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:_cardTypeIconView];

    // Set up the icons size constraints. They are activated here and updated in
    // layoutSubviews.
    _iconHeightConstraint =
        [_cardTypeIconView.heightAnchor constraintEqualToConstant:0];
    _iconWidthConstraint =
        [_cardTypeIconView.widthAnchor constraintEqualToConstant:0];

    _textFieldTrailingConstraint = [_textField.trailingAnchor
        constraintEqualToAnchor:_cardTypeIconView.leadingAnchor];

    // Set up the constraints.
    [NSLayoutConstraint activateConstraints:@[
      [_textLabel.leadingAnchor
          constraintEqualToAnchor:contentView.leadingAnchor
                         constant:kHorizontalPadding],
      [_textLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor
                                           constant:kVerticalPadding],
      [_textLabel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor
                                              constant:-kVerticalPadding],
      _textFieldTrailingConstraint,
      [_textField.firstBaselineAnchor
          constraintEqualToAnchor:_textLabel.firstBaselineAnchor],
      [_textField.leadingAnchor
          constraintEqualToAnchor:_textLabel.trailingAnchor
                         constant:kLabelAndFieldGap],
      [_cardTypeIconView.trailingAnchor
          constraintEqualToAnchor:contentView.trailingAnchor
                         constant:-kHorizontalPadding],
      [_cardTypeIconView.centerYAnchor
          constraintEqualToAnchor:contentView.centerYAnchor],
      _iconHeightConstraint,
      _iconWidthConstraint,
    ]];
    [_textField setContentHuggingPriority:UILayoutPriorityDefaultLow
                                  forAxis:UILayoutConstraintAxisHorizontal];
  }
  return self;
}

#pragma mark - UIView

- (void)layoutSubviews {
  if (self.cardTypeIconView.image) {
    _textFieldTrailingConstraint.constant = -kLabelAndFieldGap;

    // Set the size constraints of the icon view to the dimensions of the image.
    _iconHeightConstraint.constant = self.cardTypeIconView.image.size.height;
    _iconWidthConstraint.constant = self.cardTypeIconView.image.size.width;
  } else {
    _textFieldTrailingConstraint.constant = 0;

    _iconHeightConstraint.constant = 0;
    _iconWidthConstraint.constant = 0;
  }

  [super layoutSubviews];
}

#pragma mark - UICollectionReusableView

- (void)prepareForReuse {
  [super prepareForReuse];
  self.textLabel.text = nil;
  self.textField.text = nil;
  self.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
  self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
  self.textField.returnKeyType = UIReturnKeyDone;
  self.textField.accessibilityIdentifier = nil;
  self.textField.enabled = NO;
  self.textField.delegate = nil;
  [self.textField removeTarget:nil
                        action:nil
              forControlEvents:UIControlEventAllEvents];
  self.cardTypeIconView.image = nil;
}

#pragma mark - Accessibility

- (NSString*)accessibilityLabel {
  return [NSString
      stringWithFormat:@"%@, %@", self.textLabel.text, self.textField.text];
}

@end
