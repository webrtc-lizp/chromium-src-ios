// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SETTINGS_LANGUAGE_SETTINGS_DATA_SOURCE_H_
#define IOS_CHROME_BROWSER_UI_SETTINGS_LANGUAGE_SETTINGS_DATA_SOURCE_H_

#include <Foundation/Foundation.h>

#include <string>

@class LanguageItem;
@protocol LanguageSettingsConsumer;

// The data source protocol for the Language Settings page.
@protocol LanguageSettingsDataSource

// Returns the accept languages list ordered according to the user prefs.
- (NSArray<LanguageItem*>*)acceptLanguagesItems;

// Returns whether or not Translate is enabled.
- (BOOL)translateEnabled;

// Returns the target language code with the Translate server format
- (std::string)targetLanguageCode;

// The consumer for this protocol.
@property(nonatomic, weak) id<LanguageSettingsConsumer> consumer;

@end

#endif  // IOS_CHROME_BROWSER_UI_SETTINGS_LANGUAGE_SETTINGS_DATA_SOURCE_H_
