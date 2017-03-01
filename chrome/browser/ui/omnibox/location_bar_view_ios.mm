// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <UIKit/UIKit.h>

#include "base/command_line.h"
#include "base/logging.h"
#include "base/macros.h"
#include "base/strings/string16.h"
#include "components/omnibox/browser/omnibox_edit_model.h"
#include "components/strings/grit/components_strings.h"
#include "components/toolbar/toolbar_model.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#include "ios/chrome/browser/experimental_flags.h"
#include "ios/chrome/browser/ui/commands/UIKit+ChromeExecuteCommand.h"
#include "ios/chrome/browser/ui/commands/ios_command_ids.h"
#include "ios/chrome/browser/ui/omnibox/location_bar_view_ios.h"
#import "ios/chrome/browser/ui/omnibox/omnibox_text_field_ios.h"
#include "ios/chrome/browser/ui/omnibox/omnibox_view_ios.h"
#include "ios/chrome/browser/ui/ui_util.h"
#import "ios/chrome/browser/ui/uikit_ui_util.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ios/chrome/grit/ios_theme_resources.h"
#import "ios/third_party/material_roboto_font_loader_ios/src/src/MaterialRobotoFontLoader.h"
#include "ios/web/public/navigation_item.h"
#include "ios/web/public/navigation_manager.h"
#include "ios/web/public/ssl_status.h"
#include "ios/web/public/web_state/web_state.h"
#include "ui/base/l10n/l10n_util.h"

namespace {
const CGFloat kClearTextButtonWidth = 28;
const CGFloat kClearTextButtonHeight = 28;

// Workaround for https://crbug.com/527084 . If there is connection
// information, always show the icon. Remove this once connection info
// is available via other UI: https://crbug.com/533581
bool DoesCurrentPageHaveCertInfo(web::WebState* webState) {
  if (!webState)
    return false;
  web::NavigationManager* navigationMangager = webState->GetNavigationManager();
  if (!navigationMangager)
    return false;
  web::NavigationItem* visibleItem = navigationMangager->GetVisibleItem();
  if (!visibleItem)
    return false;

  const web::SSLStatus& SSLStatus = visibleItem->GetSSL();
  // Evaluation of |security_style| SSLStatus field in WKWebView based app is an
  // asynchronous operation, so for a short period of time SSLStatus may have
  // non-null certificate and SECURITY_STYLE_UNKNOWN |security_style|.
  return SSLStatus.certificate &&
         SSLStatus.security_style != web::SECURITY_STYLE_UNKNOWN;
}

// Returns whether the |webState| is presenting an offline page.
bool IsCurrentPageOffline(web::WebState* webState) {
  if (!webState)
    return false;
  auto* navigationManager = webState->GetNavigationManager();
  auto* visibleItem = navigationManager->GetVisibleItem();
  if (!visibleItem)
    return false;
  const GURL& url = visibleItem->GetURL();
  return url.SchemeIs(kChromeUIScheme) && url.host() == kChromeUIOfflineHost;
}

}  // namespace

// An ObjC bridge class to allow taps on the clear button to be sent to a C++
// class.
@interface OmniboxClearButtonBridge : NSObject

- (instancetype)initWithOmniboxView:(OmniboxViewIOS*)omniboxView
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)clearText;

@end

@implementation OmniboxClearButtonBridge {
  OmniboxViewIOS* _omniboxView;
}

- (instancetype)initWithOmniboxView:(OmniboxViewIOS*)omniboxView {
  self = [super init];
  if (self) {
    _omniboxView = omniboxView;
  }
  return self;
}

- (instancetype)init {
  NOTREACHED();
  return nil;
}

- (void)clearText {
  _omniboxView->ClearText();
}

@end

LocationBarViewIOS::LocationBarViewIOS(OmniboxTextFieldIOS* field,
                                       ios::ChromeBrowserState* browser_state,
                                       id<PreloadProvider> preloader,
                                       id<OmniboxPopupPositioner> positioner,
                                       id<LocationBarDelegate> delegate)
    : edit_view_(new OmniboxViewIOS(field,
                                    this,
                                    browser_state,
                                    preloader,
                                    positioner)),
      field_(field),
      delegate_(delegate) {
  DCHECK([delegate_ toolbarModel]);
  show_hint_text_ = true;

  InstallLocationIcon();
  CreateClearTextIcon(browser_state->IsOffTheRecord());
}

LocationBarViewIOS::~LocationBarViewIOS() {}

void LocationBarViewIOS::HideKeyboardAndEndEditing() {
  edit_view_->HideKeyboardAndEndEditing();
}

void LocationBarViewIOS::SetShouldShowHintText(bool show_hint_text) {
  show_hint_text_ = show_hint_text;
}

const OmniboxView* LocationBarViewIOS::GetLocationEntry() const {
  return edit_view_.get();
}

OmniboxView* LocationBarViewIOS::GetLocationEntry() {
  return edit_view_.get();
}

void LocationBarViewIOS::OnToolbarUpdated() {
  edit_view_->UpdateAppearance();
  OnChanged();
}

void LocationBarViewIOS::OnAutocompleteAccept(
    const GURL& gurl,
    WindowOpenDisposition disposition,
    ui::PageTransition transition,
    AutocompleteMatchType::Type type) {
  if (gurl.is_valid()) {
    transition = ui::PageTransitionFromInt(
        transition | ui::PAGE_TRANSITION_FROM_ADDRESS_BAR);
    [delegate_ loadGURLFromLocationBar:gurl transition:transition];
  }
}

void LocationBarViewIOS::OnChanged() {
  const bool page_is_offline = IsCurrentPageOffline(GetWebState());
  const int resource_id = edit_view_->GetIcon(page_is_offline);
  [field_ setPlaceholderImage:resource_id];

  // TODO(rohitrao): Can we get focus information from somewhere other than the
  // model?
  if (!IsIPadIdiom() && !edit_view_->model()->has_focus()) {
    ToolbarModel* toolbarModel = [delegate_ toolbarModel];
    if (toolbarModel) {
      bool page_is_secure =
          toolbarModel->GetSecurityLevel(false) != security_state::NONE;
      bool page_has_downgraded_HTTPS =
          experimental_flags::IsPageIconForDowngradedHTTPSEnabled() &&
          DoesCurrentPageHaveCertInfo(GetWebState());
      if (page_is_secure || page_has_downgraded_HTTPS || page_is_offline) {
        [field_ showPlaceholderImage];
        is_showing_placeholder_while_collapsed_ = true;
      } else {
        [field_ hidePlaceholderImage];
        is_showing_placeholder_while_collapsed_ = false;
      }
    }
  }
  UpdateRightDecorations();
  [delegate_ locationBarChanged];

  NSString* placeholderText =
      show_hint_text_ ? l10n_util::GetNSString(IDS_OMNIBOX_EMPTY_HINT) : nil;
  [field_ setPlaceholder:placeholderText];
}

bool LocationBarViewIOS::IsShowingPlaceholderWhileCollapsed() {
  return is_showing_placeholder_while_collapsed_;
}

void LocationBarViewIOS::OnInputInProgress(bool in_progress) {
  if ([delegate_ toolbarModel])
    [delegate_ toolbarModel]->set_input_in_progress(in_progress);
  if (in_progress)
    [delegate_ locationBarBeganEdit];
}

void LocationBarViewIOS::OnKillFocus() {
  // Hide the location icon on phone.  A subsequent call to OnChanged() will
  // bring the icon back if needed.
  if (!IsIPadIdiom()) {
    [field_ hidePlaceholderImage];
    is_showing_placeholder_while_collapsed_ = false;
  }

  // Update the placeholder icon.
  const int resource_id =
      edit_view_->GetIcon(IsCurrentPageOffline(GetWebState()));
  [field_ setPlaceholderImage:resource_id];

  // Show the placeholder text on iPad.
  if (IsIPadIdiom()) {
    NSString* placeholderText = l10n_util::GetNSString(IDS_OMNIBOX_EMPTY_HINT);
    [field_ setPlaceholder:placeholderText];
  }

  UpdateRightDecorations();
  [delegate_ locationBarHasResignedFirstResponder];
}

void LocationBarViewIOS::OnSetFocus() {
  // Show the location icon on phone.
  if (!IsIPadIdiom())
    [field_ showPlaceholderImage];

  // Update the placeholder icon.
  const int resource_id =
      edit_view_->GetIcon(IsCurrentPageOffline(GetWebState()));
  [field_ setPlaceholderImage:resource_id];

  // Hide the placeholder text on iPad.
  if (IsIPadIdiom()) {
    [field_ setPlaceholder:nil];
  }
  UpdateRightDecorations();
  [delegate_ locationBarHasBecomeFirstResponder];
}

const ToolbarModel* LocationBarViewIOS::GetToolbarModel() const {
  return [delegate_ toolbarModel];
}

ToolbarModel* LocationBarViewIOS::GetToolbarModel() {
  return [delegate_ toolbarModel];
}

web::WebState* LocationBarViewIOS::GetWebState() {
  return [delegate_ getWebState];
}

void LocationBarViewIOS::InstallLocationIcon() {
  // Set the placeholder for empty omnibox.
  UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
  UIImage* image = NativeImage(IDR_IOS_OMNIBOX_SEARCH);
  [button setImage:image forState:UIControlStateNormal];
  [button setFrame:CGRectMake(0, 0, image.size.width, image.size.height)];
  [button addTarget:nil
                action:@selector(chromeExecuteCommand:)
      forControlEvents:UIControlEventTouchUpInside];
  [button setTag:IDC_SHOW_PAGE_INFO];
  SetA11yLabelAndUiAutomationName(
      button, IDS_IOS_PAGE_INFO_SECURITY_BUTTON_ACCESSIBILITY_LABEL,
      @"Page Security Info");
  [button setIsAccessibilityElement:YES];

  // Set chip text options.
  [button setTitleColor:[UIColor colorWithWhite:0.631 alpha:1]
               forState:UIControlStateNormal];
  [button titleLabel].font =
      [[MDFRobotoFontLoader sharedInstance] regularFontOfSize:12];
  [field_ setLeftView:button];

  // The placeholder image is only shown when in edit mode on iPhone, and always
  // shown on iPad.
  if (IsIPadIdiom())
    [field_ setLeftViewMode:UITextFieldViewModeAlways];
  else
    [field_ setLeftViewMode:UITextFieldViewModeNever];
}

void LocationBarViewIOS::CreateClearTextIcon(bool is_incognito) {
  UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
  UIImage* omniBoxClearImage = is_incognito
                                   ? NativeImage(IDR_IOS_OMNIBOX_CLEAR_OTR)
                                   : NativeImage(IDR_IOS_OMNIBOX_CLEAR);
  UIImage* omniBoxClearPressedImage =
      is_incognito ? NativeImage(IDR_IOS_OMNIBOX_CLEAR_OTR_PRESSED)
                   : NativeImage(IDR_IOS_OMNIBOX_CLEAR_PRESSED);
  [button setImage:omniBoxClearImage forState:UIControlStateNormal];
  [button setImage:omniBoxClearPressedImage forState:UIControlStateHighlighted];

  CGRect frame = CGRectZero;
  frame.size = CGSizeMake(kClearTextButtonWidth, kClearTextButtonHeight);
  [button setFrame:frame];

  clear_button_bridge_.reset(
      [[OmniboxClearButtonBridge alloc] initWithOmniboxView:edit_view_.get()]);
  [button addTarget:clear_button_bridge_
                action:@selector(clearText)
      forControlEvents:UIControlEventTouchUpInside];
  clear_text_button_.reset([button retain]);

  SetA11yLabelAndUiAutomationName(clear_text_button_,
                                  IDS_IOS_ACCNAME_CLEAR_TEXT, @"Clear Text");
}

void LocationBarViewIOS::UpdateRightDecorations() {
  DCHECK(clear_text_button_);
  if (!edit_view_->model()->has_focus()) {
    // Do nothing for iPhone. The right view will be set to nil after the
    // omnibox animation is completed.
    if (IsIPadIdiom())
      [field_ setRightView:nil];
  } else if ([field_ displayedText].empty() &&
             ![field_ isShowingQueryRefinementChip]) {
    [field_ setRightView:nil];
  } else {
    [field_ setRightView:clear_text_button_];
    [clear_text_button_ setAlpha:1];
  }
}
