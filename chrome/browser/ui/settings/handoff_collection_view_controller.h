// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SETTINGS_HANDOFF_COLLECTION_VIEW_CONTROLLER_H_
#define IOS_CHROME_BROWSER_UI_SETTINGS_HANDOFF_COLLECTION_VIEW_CONTROLLER_H_

#import "ios/chrome/browser/ui/settings/settings_root_collection_view_controller.h"

namespace ios {
class ChromeBrowserState;
}  // namespace ios

// This View Controller is responsible for managing the settings related to
// Handoff.
@interface HandoffCollectionViewController
    : SettingsRootCollectionViewController

// The designated initializer. |browserState| must not be nil.
- (instancetype)initWithBrowserState:(ios::ChromeBrowserState*)browserState
    NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithStyle:(CollectionViewControllerStyle)style
    NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

#endif  // IOS_CHROME_BROWSER_UI_SETTINGS_HANDOFF_COLLECTION_VIEW_CONTROLLER_H_
