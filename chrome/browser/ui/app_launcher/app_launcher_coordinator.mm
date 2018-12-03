// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/app_launcher/app_launcher_coordinator.h"

#import <UIKit/UIKit.h>

#include "base/logging.h"
#include "base/metrics/histogram_macros.h"
#include "components/strings/grit/components_strings.h"
#include "ios/chrome/browser/app_launcher/app_launcher_flags.h"
#include "ios/chrome/browser/procedural_block_types.h"
#import "ios/chrome/browser/ui/app_launcher/app_launcher_util.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ios/public/provider/chrome/browser/chrome_browser_provider.h"
#include "ios/public/provider/chrome/browser/mailto/mailto_handler_provider.h"
#import "net/base/mac/url_conversions.h"
#include "ui/base/l10n/l10n_util.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// Records histogram metric on the user's response when prompted to open another
// application. |user_accepted| should be YES if the user accepted the prompt to
// launch another application. This call is extracted to a separate function to
// reduce macro code expansion.
void RecordUserAcceptedAppLaunchMetric(BOOL user_accepted) {
  UMA_HISTOGRAM_BOOLEAN("Tab.ExternalApplicationOpened", user_accepted);
}

}  // namespace

@interface AppLauncherCoordinator ()
// The base view controller from which to present UI.
@property(nonatomic, weak) UIViewController* baseViewController;
@end

@implementation AppLauncherCoordinator
@synthesize baseViewController = _baseViewController;

- (instancetype)initWithBaseViewController:
    (UIViewController*)baseViewController {
  if (self = [super init]) {
    _baseViewController = baseViewController;
  }
  return self;
}

#pragma mark - Private methods

// Alerts the user with |message| and buttons with titles
// |acceptActionTitle| and |rejectActionTitle|. |completionHandler| is called
// with a BOOL indicating whether the user has tapped the accept button.
- (void)showAlertWithMessage:(NSString*)message
           acceptActionTitle:(NSString*)acceptActionTitle
           rejectActionTitle:(NSString*)rejectActionTitle
           completionHandler:(ProceduralBlockWithBool)completionHandler {
  UIAlertController* alertController =
      [UIAlertController alertControllerWithTitle:nil
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction* acceptAction =
      [UIAlertAction actionWithTitle:acceptActionTitle
                               style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction* action) {
                               completionHandler(YES);
                             }];
  UIAlertAction* rejectAction =
      [UIAlertAction actionWithTitle:rejectActionTitle
                               style:UIAlertActionStyleCancel
                             handler:^(UIAlertAction* action) {
                               completionHandler(NO);
                             }];
  [alertController addAction:rejectAction];
  [alertController addAction:acceptAction];

  [self.baseViewController presentViewController:alertController
                                        animated:YES
                                      completion:nil];
}

// Shows an alert that the app will open in another application. If the user
// accepts, the |URL| is launched.
- (void)showAlertAndLaunchAppURL:(const GURL&)URL {
  NSString* prompt = l10n_util::GetNSString(IDS_IOS_OPEN_IN_ANOTHER_APP);
  NSString* openLabel =
      l10n_util::GetNSString(IDS_IOS_APP_LAUNCHER_OPEN_APP_BUTTON_LABEL);
  NSString* cancelLabel = l10n_util::GetNSString(IDS_CANCEL);
  NSURL* copiedURL = net::NSURLWithGURL(URL);
  [self showAlertWithMessage:prompt
           acceptActionTitle:openLabel
           rejectActionTitle:cancelLabel
           completionHandler:^(BOOL userAccepted) {
             RecordUserAcceptedAppLaunchMetric(userAccepted);
             if (userAccepted) {
               [[UIApplication sharedApplication] openURL:copiedURL
                                                  options:@{}
                                        completionHandler:nil];
             }
           }];
}

#pragma mark - AppLauncherTabHelperDelegate

- (BOOL)appLauncherTabHelper:(AppLauncherTabHelper*)tabHelper
            launchAppWithURL:(const GURL&)URL
              linkTransition:(BOOL)linkTransition {
  // Don't open application if chrome is not active.
  if ([[UIApplication sharedApplication] applicationState] !=
      UIApplicationStateActive) {
    return NO;
  }
  if (UrlHasAppStoreScheme(URL)) {
    [self showAlertAndLaunchAppURL:URL];
    return YES;
  }

  // Uses a Mailto Handler to open the appropriate app, if available.
  if (URL.SchemeIs(url::kMailToScheme)) {
    MailtoHandlerProvider* provider =
        ios::GetChromeBrowserProvider()->GetMailtoHandlerProvider();
    provider->HandleMailtoURL(net::NSURLWithGURL(URL));
    return YES;
  }

  if (base::FeatureList::IsEnabled(kAppLauncherRefresh)) {
    // For all other apps other than AppStore, show a prompt if there was no
    // link transition.
    if (linkTransition) {
      [[UIApplication sharedApplication] openURL:net::NSURLWithGURL(URL)
                                         options:@{}
                               completionHandler:nil];
    } else {
      [self showAlertAndLaunchAppURL:URL];
    }
    return YES;
  }

// If the following call returns YES, an application is about to be
// launched and Chrome will go into the background now.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  // TODO(crbug.com/774736): This method needs to be converted to an
  // asynchronous call so that the call below can be replaced with
  // |openURL:options:completionHandler:|.
  return [[UIApplication sharedApplication] openURL:net::NSURLWithGURL(URL)];
#pragma clang diagnostic pop
}

- (void)appLauncherTabHelper:(AppLauncherTabHelper*)tabHelper
    showAlertOfRepeatedLaunchesWithCompletionHandler:
        (ProceduralBlockWithBool)completionHandler {
  NSString* message =
      l10n_util::GetNSString(IDS_IOS_OPEN_REPEATEDLY_ANOTHER_APP);
  NSString* allowLaunchTitle =
      l10n_util::GetNSString(IDS_IOS_OPEN_REPEATEDLY_ANOTHER_APP_ALLOW);
  NSString* blockLaunchTitle =
      l10n_util::GetNSString(IDS_IOS_OPEN_REPEATEDLY_ANOTHER_APP_BLOCK);
  [self showAlertWithMessage:message
           acceptActionTitle:allowLaunchTitle
           rejectActionTitle:blockLaunchTitle
           completionHandler:^(BOOL userAllowed) {
             UMA_HISTOGRAM_BOOLEAN("IOS.RepeatedExternalAppPromptResponse",
                                   userAllowed);
             completionHandler(userAllowed);
           }];
}

@end
