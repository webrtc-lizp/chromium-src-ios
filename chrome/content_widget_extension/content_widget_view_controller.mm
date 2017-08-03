// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/content_widget_extension/content_widget_view_controller.h"

#import <NotificationCenter/NotificationCenter.h>

#include "base/ios/ios_util.h"
#include "base/mac/foundation_util.h"
#include "base/strings/sys_string_conversions.h"
#import "ios/chrome/browser/ui/ntp/ntp_tile.h"
#import "ios/chrome/browser/ui/util/constraints_ui_util.h"
#include "ios/chrome/common/app_group/app_group_constants.h"
#include "ios/chrome/content_widget_extension/content_widget_view.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// Using GURL in the extension is not wanted as it includes ICU which makes the
// extension binary much larger; therefore, ios/chrome/common/x_callback_url.h
// cannot be used. This class makes a very basic use of x-callback-url, so no
// full implementation is required.
NSString* const kXCallbackURLHost = @"x-callback-url";
const CGFloat widgetCompactHeightIOS9 = 110;
}  // namespace

@interface ContentWidgetViewController ()
@property(nonatomic, strong) NSDictionary<NSURL*, NTPTile*>* sites;
@property(nonatomic, weak) ContentWidgetView* widgetView;
@property(nonatomic, readonly) BOOL isCompact;

// Updates the widget with latest data. Returns whether any visual updates
// occurred.
- (BOOL)updateWidget;
// Opens the main application with the given |URL|.
- (void)openAppWithURL:(NSString*)URL;
@end

@implementation ContentWidgetViewController

@synthesize sites = _sites;
@synthesize widgetView = _widgetView;

#pragma mark - properties

- (BOOL)isCompact {
  return [self.extensionContext widgetActiveDisplayMode] ==
         NCWidgetDisplayModeCompact;
}

#pragma mark - UIViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  CGFloat height =
      self.extensionContext
          ? [self.extensionContext
                widgetMaximumSizeForDisplayMode:NCWidgetDisplayModeCompact]
                .height
          : widgetCompactHeightIOS9;

  // A local variable is necessary here as the property is declared weak and the
  // object would be deallocated before being retained by the addSubview call.
  ContentWidgetView* widgetView =
      [[ContentWidgetView alloc] initWithCompactHeight:height
                                      initiallyCompact:self.isCompact];
  self.widgetView = widgetView;
  [self.view addSubview:self.widgetView];

  if (base::ios::IsRunningOnIOS10OrLater()) {
    self.extensionContext.widgetLargestAvailableDisplayMode =
        NCWidgetDisplayModeExpanded;
  }

  self.widgetView.translatesAutoresizingMaskIntoConstraints = NO;
  AddSameConstraints(self.widgetView, self.view);
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self updateWidget];
}

- (void)widgetPerformUpdateWithCompletionHandler:
    (void (^)(NCUpdateResult))completionHandler {
  completionHandler([self updateWidget] ? NCUpdateResultNewData
                                        : NCUpdateResultNoData);
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:
           (id<UIViewControllerTransitionCoordinator>)coordinator {
  [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

  [coordinator
      animateAlongsideTransition:^(
          id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
        [self.widgetView showMode:self.isCompact];
      }
                      completion:nil];
}

#pragma mark - NCWidgetProviding

- (void)widgetActiveDisplayModeDidChange:(NCWidgetDisplayMode)activeDisplayMode
                         withMaximumSize:(CGSize)maxSize {
  switch (activeDisplayMode) {
    case NCWidgetDisplayModeCompact:
      self.preferredContentSize = maxSize;
      break;
    case NCWidgetDisplayModeExpanded:
      self.preferredContentSize =
          CGSizeMake(maxSize.width, [self.widgetView widgetExpandedHeight]);
      break;
  }
}

// Implementing this method removes the leading edge inset for iOS version < 10.
// TODO(crbug.com/720490): Remove implementation when dropping ios9 support.
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_10_0
- (UIEdgeInsets)widgetMarginInsetsForProposedMarginInsets:
    (UIEdgeInsets)defaultMa‌​rginInsets {
  return UIEdgeInsetsZero;
}
#endif

#pragma mark - internal

- (BOOL)updateWidget {
  NSUserDefaults* sharedDefaults =
      [[NSUserDefaults alloc] initWithSuiteName:app_group::ApplicationGroup()];
  NSDictionary<NSURL*, NTPTile*>* newSites = [NSKeyedUnarchiver
      unarchiveObjectWithData:[sharedDefaults
                                  objectForKey:app_group::kSuggestedItems]];
  if (newSites == self.sites) {
    return NO;
  }
  self.sites = newSites;
  return YES;
}

- (void)openAppWithURL:(NSString*)URL {
  NSUserDefaults* sharedDefaults =
      [[NSUserDefaults alloc] initWithSuiteName:app_group::ApplicationGroup()];
  NSString* defaultsKey =
      base::SysUTF8ToNSString(app_group::kChromeAppGroupCommandPreference);

  NSString* timePrefKey =
      base::SysUTF8ToNSString(app_group::kChromeAppGroupCommandTimePreference);
  NSString* appPrefKey =
      base::SysUTF8ToNSString(app_group::kChromeAppGroupCommandAppPreference);
  NSString* commandPrefKey = base::SysUTF8ToNSString(
      app_group::kChromeAppGroupCommandCommandPreference);
  NSString* paramPrefKey = base::SysUTF8ToNSString(
      app_group::kChromeAppGroupCommandParameterPreference);

  NSDictionary* commandDict = @{
    timePrefKey : [NSDate date],
    appPrefKey : @"TodayExtension",
    commandPrefKey :
        base::SysUTF8ToNSString(app_group::kChromeAppGroupOpenURLCommand),
    paramPrefKey : URL,
  };

  [sharedDefaults setObject:commandDict forKey:defaultsKey];
  [sharedDefaults synchronize];

  NSString* scheme = base::mac::ObjCCast<NSString>([[NSBundle mainBundle]
      objectForInfoDictionaryKey:@"KSChannelChromeScheme"]);
  if (!scheme)
    return;

  NSURLComponents* urlComponents = [NSURLComponents new];
  urlComponents.scheme = scheme;
  urlComponents.host = kXCallbackURLHost;
  urlComponents.path = [@"/"
      stringByAppendingString:base::SysUTF8ToNSString(
                                  app_group::kChromeAppGroupXCallbackCommand)];

  NSURL* openURL = [urlComponents URL];
  [self.extensionContext openURL:openURL completionHandler:nil];
}

@end
