// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/signin/browser_state_data_remover.h"

#include <memory>

#include "base/logging.h"
#include "base/threading/thread_task_runner_handle.h"
#include "components/prefs/pref_service.h"
#include "components/signin/core/browser/signin_pref_names.h"
#include "ios/chrome/browser/bookmarks/bookmarks_utils.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/reading_list/reading_list_remover_helper.h"
#import "ios/chrome/browser/ui/commands/UIKit+ChromeExecuteCommand.h"
#import "ios/chrome/browser/ui/commands/clear_browsing_data_command.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

BrowserStateDataRemover::BrowserStateDataRemover(
    ios::ChromeBrowserState* browser_state)
    : browser_state_(browser_state) {}

BrowserStateDataRemover::~BrowserStateDataRemover() {}

// static
void BrowserStateDataRemover::ClearData(ios::ChromeBrowserState* browser_state,
                                        ProceduralBlock completion) {
  BrowserStateDataRemover* remover = new BrowserStateDataRemover(browser_state);
  remover->RemoveBrowserStateData(completion);
}

void BrowserStateDataRemover::RemoveBrowserStateData(ProceduralBlock callback) {
  DCHECK(!callback_);
  callback_ = [callback copy];

  // It is safe to use |this| in the block as the object manage its own lifetime
  // and only call delete once the callback has been invoked.
  ClearBrowsingDataCommand* command = [[ClearBrowsingDataCommand alloc]
      initWithBrowserState:browser_state_
                      mask:BrowsingDataRemoveMask::REMOVE_ALL
                timePeriod:browsing_data::TimePeriod::ALL_TIME
           completionBlock:^{
             this->BrowsingDataCleared();
           }];

  UIWindow* mainWindow = [[UIApplication sharedApplication] keyWindow];
  DCHECK(mainWindow);
  [mainWindow chromeExecuteCommand:command];
}

void BrowserStateDataRemover::BrowsingDataCleared() {
  // Remove bookmarks and Reading List entriesonce all browsing data was
  // removed.
  // Removal of browsing data waits for the bookmark model to be loaded, so
  // there should be no issue calling the function here.
  CHECK(RemoveAllUserBookmarksIOS(browser_state_))
      << "Failed to remove all user bookmarks.";
  reading_list_remover_helper_ =
      std::make_unique<reading_list::ReadingListRemoverHelper>(browser_state_);
  reading_list_remover_helper_->RemoveAllUserReadingListItemsIOS(base::BindOnce(
      &BrowserStateDataRemover::ReadingListCleaned, base::Unretained(this)));
}

void BrowserStateDataRemover::ReadingListCleaned(bool reading_list_cleaned) {
  CHECK(reading_list_cleaned)
      << "Failed to remove all user reading list items.";

  // The user just changed the account and chose to clear the previously
  // existing data. As browsing data is being cleared, it is fine to clear the
  // last username, as there will be no data to be merged.
  browser_state_->GetPrefs()->ClearPref(prefs::kGoogleServicesLastAccountId);
  browser_state_->GetPrefs()->ClearPref(prefs::kGoogleServicesLastUsername);

  if (callback_)
    callback_();

  base::ThreadTaskRunnerHandle::Get()->DeleteSoon(FROM_HERE, this);
}
