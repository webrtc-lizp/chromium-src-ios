// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/clean/chrome/browser/ui/dialogs/test_helpers/test_dialog_mediator.h"

#import "ios/clean/chrome/browser/ui/dialogs/dialog_mediator+subclassing.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation TestDialogMediator
@synthesize title = _title;
@synthesize message = _message;
@synthesize buttonConfigs = _buttonConfigs;
@synthesize textFieldConfigs = _textFieldConfigs;
@end

@implementation TestDialogMediator (DialogMediatorSubclassing)

- (NSString*)dialogTitle {
  return _title;
}

- (NSString*)dialogMessage {
  return _message;
}

- (NSArray<DialogButtonConfiguration*>*)buttonConfigs {
  return _buttonConfigs;
}

- (NSArray<DialogTextFieldConfiguration*>*)textFieldConfigs {
  return _textFieldConfigs;
}

@end
