// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/content_suggestions/content_suggestion.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation ContentSuggestion

@synthesize title = _title;
@synthesize image = _image;
@synthesize text = _text;
@synthesize url = _url;
@synthesize section = _section;
@synthesize type = _type;

@end
