// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/metrics/tab_usage_recorder_test_util.h"
#import "ios/chrome/test/earl_grey/chrome_error_util.h"

#import <EarlGrey/EarlGrey.h>
#import <Foundation/Foundation.h>

#import "base/ios/block_types.h"
#import "base/test/ios/wait_util.h"
#import "ios/chrome/app/main_controller.h"
#import "ios/chrome/browser/tabs/tab_model.h"
#import "ios/chrome/browser/ui/main/browser_interface_provider.h"
#import "ios/chrome/browser/ui/popup_menu/popup_menu_constants.h"
#include "ios/chrome/browser/ui/tab_grid/tab_grid_egtest_util.h"
#include "ios/chrome/browser/ui/util/ui_util.h"
#include "ios/chrome/browser/web_state_list/web_state_list.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/app/chrome_test_util.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/testing/nserror_util.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// The delay to wait for an element to appear before tapping on it.
const NSTimeInterval kWaitElementTimeout = 3;

// Shows the tab switcher by tapping the switcher button.  Works on both phone
// and tablet.
bool ShowTabSwitcher() {
  id<GREYMatcher> matcher = chrome_test_util::TabGridOpenButton();
  // Perform a tap with a timeout. Occasionally EG doesn't sync up properly to
  // the animations of tab switcher, so it is necessary to poll here.
  GREYCondition* tapTabSwitcher =
      [GREYCondition conditionWithName:@"Tap tab switcher button"
                                 block:^BOOL {
                                   NSError* error;
                                   [[EarlGrey selectElementWithMatcher:matcher]
                                       performAction:grey_tap()
                                               error:&error];
                                   return error == nil;
                                 }];

  // Wait until 2 seconds for the tap.
  return [tapTabSwitcher waitWithTimeout:2];
}

}  // namespace

namespace tab_usage_recorder_test_util {

NSError* OpenNewIncognitoTabUsingUIAndEvictMainTabs() {
  int nb_incognito_tab = [ChromeEarlGrey incognitoTabCount];
  [ChromeEarlGreyUI openToolsMenu];
  id<GREYMatcher> new_incognito_tab_button_matcher =
      grey_accessibilityID(kToolsMenuNewIncognitoTabId);
  [[EarlGrey selectElementWithMatcher:new_incognito_tab_button_matcher]
      performAction:grey_tap()];
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey waitForIncognitoTabCount:(nb_incognito_tab + 1)]);
  ConditionBlock condition = ^bool {
    return [ChromeEarlGrey isIncognitoMode];
  };

  bool success = base::test::ios::WaitUntilConditionOrTimeout(
      kWaitElementTimeout, condition);
  if (!success) {
    return testing::NSErrorWithLocalizedDescription(
        @"Waiting switch to incognito mode.");
  }

  [ChromeEarlGrey evictOtherTabModelTabs];
  return nil;
}

NSError* SwitchToNormalMode() {
  if (![ChromeEarlGrey isIncognitoMode]) {
    return testing::NSErrorWithLocalizedDescription(
        @"Switching to normal mode is only allowed from Incognito.");
  }

  // Enter the tab grid to switch modes.
  if (!ShowTabSwitcher()) {
    return testing::NSErrorWithLocalizedDescription(
        @"Tab switcher could not be tapped.");
  }

  // Switch modes and exit the tab grid.
  TabModel* model = chrome_test_util::GetMainController()
                        .interfaceProvider.mainInterface.tabModel;
  const int tab_index = model.webStateList->active_index();
  [[EarlGrey
      selectElementWithMatcher:chrome_test_util::TabGridOpenTabsPanelButton()]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:chrome_test_util::TabGridCellAtIndex(
                                          tab_index)] performAction:grey_tap()];

  // Turn off synchronization of GREYAssert to test the pending states.
  [[GREYConfiguration sharedInstance]
          setValue:@(NO)
      forConfigKey:kGREYConfigKeySynchronizationEnabled];
  ConditionBlock condition = ^bool {
    return ![ChromeEarlGrey isIncognitoMode];
  };

  if (!base::test::ios::WaitUntilConditionOrTimeout(kWaitElementTimeout,
                                                    condition)) {
    return testing::NSErrorWithLocalizedDescription(
        @"Waiting switch to normal mode.");
  }

  [[GREYConfiguration sharedInstance]
          setValue:@(YES)
      forConfigKey:kGREYConfigKeySynchronizationEnabled];
  return nil;
}

}  // namespace tab_usage_recorder_test_util
