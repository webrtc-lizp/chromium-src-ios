// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_OVERLAYS_WEB_CONTENT_AREA_JAVA_SCRIPT_DIALOGS_JAVA_SCRIPT_ALERT_OVERLAY_MEDIATOR_H_
#define IOS_CHROME_BROWSER_UI_OVERLAYS_WEB_CONTENT_AREA_JAVA_SCRIPT_DIALOGS_JAVA_SCRIPT_ALERT_OVERLAY_MEDIATOR_H_

#import "ios/chrome/browser/ui/overlays/common/alerts/alert_overlay_mediator.h"

class OverlayRequest;

// Mediator object that uses a JavaScriptAlertOverlayRequestConfig to set up the
// UI for a JavaScript alert overlay.
@interface JavaScriptAlertOverlayMediator : AlertOverlayMediator
@end

#endif  // IOS_CHROME_BROWSER_UI_OVERLAYS_WEB_CONTENT_AREA_JAVA_SCRIPT_DIALOGS_JAVA_SCRIPT_ALERT_OVERLAY_MEDIATOR_H_
