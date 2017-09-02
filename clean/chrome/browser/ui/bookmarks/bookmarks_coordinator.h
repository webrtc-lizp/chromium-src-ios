// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CLEAN_CHROME_BROWSER_UI_BOOKMARKS_BOOKMARKS_COORDINATOR_H_
#define IOS_CLEAN_CHROME_BROWSER_UI_BOOKMARKS_BOOKMARKS_COORDINATOR_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/coordinators/browser_coordinator.h"

// A coordinator for the bookmarks UI, which can be presented modally on its
// own or inside the NTP.
@interface BookmarksCoordinator : BrowserCoordinator

// Whether the ViewController created by this coordinator will be contained.
@property(nonatomic, assign) BOOL contained;

@end

#endif  // IOS_CLEAN_CHROME_BROWSER_UI_BOOKMARKS_BOOKMARKS_COORDINATOR_H_
