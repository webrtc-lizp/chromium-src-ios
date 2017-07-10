// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_TEST_EARL_GREY_CHROME_MATCHERS_H_
#define IOS_CHROME_TEST_EARL_GREY_CHROME_MATCHERS_H_

#include <string>

#import <EarlGrey/EarlGrey.h>

namespace chrome_test_util {

// Matcher for element with accessibility label corresponding to |message_id|
// and accessibility trait UIAccessibilityTraitButton.
id<GREYMatcher> ButtonWithAccessibilityLabelId(int message_id);

// Matcher for element with accessibility label corresponding to |label| and
// accessibility trait UIAccessibilityTraitButton.
id<GREYMatcher> ButtonWithAccessibilityLabel(NSString* label);

// Matcher for element with an image corresponding to |image_id| and
// accessibility trait UIAccessibilityTraitButton.
id<GREYMatcher> ButtonWithImage(int image_id);

// Matcher for element with accessibility label corresponding to |message_id|
// and accessibility trait UIAccessibilityTraitStaticText.
id<GREYMatcher> StaticTextWithAccessibilityLabelId(int message_id);

// Matcher for element with accessibility label corresponding to |label| and
// accessibility trait UIAccessibilityTraitStaticText.
id<GREYMatcher> StaticTextWithAccessibilityLabel(NSString* label);

// Returns matcher for WKWebView containing a blocked |image_id|.  When blocked,
// the image element will be smaller than actual image.
id<GREYMatcher> WebViewContainingBlockedImage(std::string image_id);

// Returns matcher for WKWebView containing loaded image with |image_id|.  When
// loaded, the image element will have the same size as actual image.
id<GREYMatcher> WebViewContainingLoadedImage(std::string image_id);

// Returns matcher for a cancel button.
id<GREYMatcher> CancelButton();

// Matcher for the navigate forward button.
id<GREYMatcher> ForwardButton();

// Matcher for the navigate backward button.
id<GREYMatcher> BackButton();

// Matcher for the reload button.
id<GREYMatcher> ReloadButton();

// Matcher for the stop loading button.
id<GREYMatcher> StopButton();

// Returns a matcher for the omnibox.
id<GREYMatcher> Omnibox();

// Returns a matcher for the page security info button.
id<GREYMatcher> PageSecurityInfoButton();

// Returns matcher for omnibox containing |text|. Performs an exact match of the
// omnibox contents.
id<GREYMatcher> OmniboxText(std::string text);

// Matcher for Tools menu button.
id<GREYMatcher> ToolsMenuButton();

// Matcher for the Share menu button.
id<GREYMatcher> ShareButton();

// Matcher for show tabs button.
id<GREYMatcher> ShowTabsButton();

// Matcher for CollectionViewSwitchCell.
// TODO(crbug.com/684139): Update |isOn| to something more obvious from
// callsites.
id<GREYMatcher> CollectionViewSwitchCell(NSString* accessibilityIdentifier,
                                         BOOL isOn);

// Matcher for the Open in New Tab option in the context menu when long pressing
// a link.
id<GREYMatcher> OpenLinkInNewTabButton();

// Matcher for the done button on the navigation bar.
id<GREYMatcher> NavigationBarDoneButton();

// Returns matcher for the account consistency setup signin button.
id<GREYMatcher> AccountConsistencySetupSigninButton();

// Returns matcher for the account consistency confirmation button.
id<GREYMatcher> AccountConsistencyConfirmationOkButton();

// Returns matcher for the sign out accounts button.
id<GREYMatcher> SignOutAccountsButton();

// Returns matcher for the clear browsing data collection view.
id<GREYMatcher> ClearBrowsingDataCollectionView();

// Returns matcher for the settings button in the tools menu.
id<GREYMatcher> SettingsMenuButton();

// Returns matcher for the OK button.
id<GREYMatcher> OKButton();

// Returns matcher for the signin button in the settings menu.
id<GREYMatcher> SignInMenuButton();

// Returns matcher for the button for the currently signed in account in the
// settings menu.
id<GREYMatcher> SettingsAccountButton();

// Returns matcher for the menu button to sync accounts.
id<GREYMatcher> AccountsSyncButton();

// Returns matcher for the Content Settings button on the main Settings screen.
id<GREYMatcher> ContentSettingsButton();

// Returns matcher for the back button on a settings menu.
id<GREYMatcher> SettingsMenuBackButton();

}  // namespace chrome_test_util

#endif  // IOS_CHROME_TEST_EARL_GREY_CHROME_MATCHERS_H_
