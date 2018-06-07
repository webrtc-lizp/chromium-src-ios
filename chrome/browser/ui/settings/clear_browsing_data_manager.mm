// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/clear_browsing_data_manager.h"

#include "base/ios/block_types.h"
#import "base/mac/bind_objc_block.h"
#include "base/mac/foundation_util.h"
#include "base/metrics/histogram_macros.h"
#include "base/strings/sys_string_conversions.h"
#include "components/browser_sync/profile_sync_service.h"
#include "components/browsing_data/core/history_notice_utils.h"
#include "components/browsing_data/core/pref_names.h"
#include "components/feature_engagement/public/event_constants.h"
#include "components/feature_engagement/public/tracker.h"
#include "components/google/core/browser/google_util.h"
#include "components/history/core/browser/web_history_service.h"
#include "components/prefs/pref_service.h"
#include "components/signin/core/browser/signin_manager.h"
#include "components/strings/grit/components_strings.h"
#include "ios/chrome/browser/application_context.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/browsing_data/browsing_data_counter_wrapper.h"
#include "ios/chrome/browser/browsing_data/browsing_data_remove_mask.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#include "ios/chrome/browser/experimental_flags.h"
#include "ios/chrome/browser/feature_engagement/tracker_factory.h"
#include "ios/chrome/browser/history/web_history_service_factory.h"
#include "ios/chrome/browser/signin/signin_manager_factory.h"
#include "ios/chrome/browser/sync/profile_sync_service_factory.h"
#import "ios/chrome/browser/ui/collection_view/cells/collection_view_detail_item.h"
#import "ios/chrome/browser/ui/collection_view/cells/collection_view_footer_item.h"
#import "ios/chrome/browser/ui/collection_view/cells/collection_view_item.h"
#import "ios/chrome/browser/ui/collection_view/collection_view_model.h"
#import "ios/chrome/browser/ui/colors/MDCPalette+CrAdditions.h"
#import "ios/chrome/browser/ui/icons/chrome_icon.h"
#import "ios/chrome/browser/ui/list_model/list_model.h"
#import "ios/chrome/browser/ui/settings/cells/clear_browsing_data_constants.h"
#import "ios/chrome/browser/ui/settings/cells/clear_browsing_data_item.h"
#import "ios/chrome/browser/ui/uikit_ui_util.h"
#include "ios/chrome/common/channel_info.h"
#include "ios/chrome/grit/ios_chromium_strings.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/public/provider/chrome/browser/chrome_browser_provider.h"
#import "ios/public/provider/chrome/browser/images/branded_image_provider.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// Maximum number of times to show a notice about other forms of browsing
// history.
const int kMaxTimesHistoryNoticeShown = 1;

}  // namespace

@interface ClearBrowsingDataManager ()

@property(nonatomic, assign) ios::ChromeBrowserState* browserState;
// Time Period to clear data.
@property(nonatomic, assign) browsing_data::TimePeriod timePeriod;
// Whether to show alert about other forms of browsing history.
@property(nonatomic, assign)
    BOOL shouldShowNoticeAboutOtherFormsOfBrowsingHistory;
// Whether to show popup other forms of browsing history.
@property(nonatomic, assign)
    BOOL shouldPopupDialogAboutOtherFormsOfBrowsingHistory;

@end

@implementation ClearBrowsingDataManager
@synthesize browserState = _browserState;
@synthesize consumer = _consumer;
@synthesize linkDelegate = _linkDelegate;
@synthesize timePeriod = _timePeriod;
@synthesize shouldShowNoticeAboutOtherFormsOfBrowsingHistory =
    _shouldShowNoticeAboutOtherFormsOfBrowsingHistory;
@synthesize shouldPopupDialogAboutOtherFormsOfBrowsingHistory =
    _shouldPopupDialogAboutOtherFormsOfBrowsingHistory;

- (instancetype)initWithBrowserState:(ios::ChromeBrowserState*)browserState {
  self = [super init];
  if (self) {
    _browserState = browserState;

    _timePeriod = browsing_data::TimePeriod::ALL_TIME;
    if (experimental_flags::IsNewClearBrowsingDataUIEnabled()) {
      constexpr int maxValue =
          static_cast<int>(browsing_data::TimePeriod::TIME_PERIOD_LAST);
      const int prefValue = browserState->GetPrefs()->GetInteger(
          browsing_data::prefs::kDeleteTimePeriod);

      if (0 <= prefValue && prefValue <= maxValue) {
        _timePeriod = static_cast<browsing_data::TimePeriod>(prefValue);
      }
    }
  }
  return self;
}

#pragma mark - Public Methods

- (void)loadModel:(ListModel*)model {
  // Time range section.
  if (experimental_flags::IsNewClearBrowsingDataUIEnabled()) {
    [model addSectionWithIdentifier:SectionTimeRange];
    [model addItem:[self timeRangeItem]
        toSectionWithIdentifier:SectionTimeRange];
  }

  [self addClearBrowsingDataItemsToModel:model];

  [self addSyncProfileItemsToModel:model];
}

// Add items for types of browsing data to clear.
- (void)addClearBrowsingDataItemsToModel:(ListModel*)model {
  // Data types section.
  [model addSectionWithIdentifier:SectionDataTypes];
  CollectionViewItem* browsingHistoryItem =
      [self clearDataItemWithType:DataTypeBrowsingHistory
                          titleID:IDS_IOS_CLEAR_BROWSING_HISTORY
                             mask:BrowsingDataRemoveMask::REMOVE_HISTORY
                         prefName:browsing_data::prefs::kDeleteBrowsingHistory];
  [model addItem:browsingHistoryItem toSectionWithIdentifier:SectionDataTypes];

  // This data type doesn't currently have an associated counter, but displays
  // an explanatory text instead, when the new UI is enabled.
  ClearBrowsingDataItem* cookiesSiteDataItem =
      [self clearDataItemWithType:DataTypeCookiesSiteData
                          titleID:IDS_IOS_CLEAR_COOKIES
                             mask:BrowsingDataRemoveMask::REMOVE_SITE_DATA
                         prefName:browsing_data::prefs::kDeleteCookies];
  [model addItem:cookiesSiteDataItem toSectionWithIdentifier:SectionDataTypes];

  ClearBrowsingDataItem* cacheItem =
      [self clearDataItemWithType:DataTypeCache
                          titleID:IDS_IOS_CLEAR_CACHE
                             mask:BrowsingDataRemoveMask::REMOVE_CACHE
                         prefName:browsing_data::prefs::kDeleteCache];
  [model addItem:cacheItem toSectionWithIdentifier:SectionDataTypes];

  ClearBrowsingDataItem* savedPasswordsItem =
      [self clearDataItemWithType:DataTypeSavedPasswords
                          titleID:IDS_IOS_CLEAR_SAVED_PASSWORDS
                             mask:BrowsingDataRemoveMask::REMOVE_PASSWORDS
                         prefName:browsing_data::prefs::kDeletePasswords];
  [model addItem:savedPasswordsItem toSectionWithIdentifier:SectionDataTypes];

  ClearBrowsingDataItem* autofillItem =
      [self clearDataItemWithType:DataTypeAutofill
                          titleID:IDS_IOS_CLEAR_AUTOFILL
                             mask:BrowsingDataRemoveMask::REMOVE_FORM_DATA
                         prefName:browsing_data::prefs::kDeleteFormData];
  [model addItem:autofillItem toSectionWithIdentifier:SectionDataTypes];

  // Clear Browsing Data button.
  [model addSectionWithIdentifier:SectionClearBrowsingDataButton];
  CollectionViewTextItem* clearButtonItem =
      [[CollectionViewTextItem alloc] initWithType:ClearBrowsingDataButton];
  clearButtonItem.text = l10n_util::GetNSString(IDS_IOS_CLEAR_BUTTON);
  clearButtonItem.accessibilityTraits |= UIAccessibilityTraitButton;
  clearButtonItem.textColor = [[MDCPalette cr_redPalette] tint500];
  [model addItem:clearButtonItem
      toSectionWithIdentifier:SectionClearBrowsingDataButton];
}

- (NSString*)counterTextFromResult:
    (const browsing_data::BrowsingDataCounter::Result&)result {
  if (!result.Finished()) {
    // The counter is still counting.
    return l10n_util::GetNSString(IDS_CLEAR_BROWSING_DATA_CALCULATING);
  }

  base::StringPiece prefName = result.source()->GetPrefName();
  if (prefName != browsing_data::prefs::kDeleteCache) {
    return base::SysUTF16ToNSString(
        browsing_data::GetCounterTextFromResult(&result));
  }

  browsing_data::BrowsingDataCounter::ResultInt cacheSizeBytes =
      static_cast<const browsing_data::BrowsingDataCounter::FinishedResult*>(
          &result)
          ->Value();

  // Three cases: Nonzero result for the entire cache, nonzero result for
  // a subset of cache (i.e. a finite time interval), and almost zero (less
  // than 1 MB). There is no exact information that the cache is empty so that
  // falls into the almost zero case, which is displayed as less than 1 MB.
  // Because of this, the lowest unit that can be used is MB.
  static const int kBytesInAMegabyte = 1 << 20;
  if (cacheSizeBytes >= kBytesInAMegabyte) {
    NSByteCountFormatter* formatter = [[NSByteCountFormatter alloc] init];
    formatter.allowedUnits = NSByteCountFormatterUseAll &
                             (~NSByteCountFormatterUseBytes) &
                             (~NSByteCountFormatterUseKB);
    formatter.countStyle = NSByteCountFormatterCountStyleMemory;
    NSString* formattedSize = [formatter stringFromByteCount:cacheSizeBytes];
    return (self.timePeriod == browsing_data::TimePeriod::ALL_TIME)
               ? formattedSize
               : l10n_util::GetNSStringF(
                     IDS_DEL_CACHE_COUNTER_UPPER_ESTIMATE,
                     base::SysNSStringToUTF16(formattedSize));
  }

  return l10n_util::GetNSString(IDS_DEL_CACHE_COUNTER_ALMOST_EMPTY);
}

- (UIAlertController*)alertControllerWithDataTypesToRemove:
    (BrowsingDataRemoveMask)dataTypeMaskToRemove {
  if (dataTypeMaskToRemove == BrowsingDataRemoveMask::REMOVE_NOTHING) {
    // Nothing to clear (no data types selected).
    return nil;
  }
  __weak ClearBrowsingDataManager* weakSelf = self;
  UIAlertController* alertController = [UIAlertController
      alertControllerWithTitle:nil
                       message:nil
                preferredStyle:UIAlertControllerStyleActionSheet];

  UIAlertAction* clearDataAction = [UIAlertAction
      actionWithTitle:l10n_util::GetNSString(IDS_IOS_CLEAR_BUTTON)
                style:UIAlertActionStyleDestructive
              handler:^(UIAlertAction* action) {
                [weakSelf clearDataForDataTypes:dataTypeMaskToRemove];
              }];
  clearDataAction.accessibilityLabel =
      l10n_util::GetNSString(IDS_IOS_CONFIRM_CLEAR_BUTTON);
  UIAlertAction* cancelAction =
      [UIAlertAction actionWithTitle:l10n_util::GetNSString(IDS_CANCEL)
                               style:UIAlertActionStyleCancel
                             handler:nil];
  [alertController addAction:clearDataAction];
  [alertController addAction:cancelAction];
  return alertController;
}

// Add footers about user's account data.
- (void)addSyncProfileItemsToModel:(ListModel*)model {
  // Google Account footer.
  SigninManager* signinManager =
      ios::SigninManagerFactory::GetForBrowserState(self.browserState);
  if (signinManager->IsAuthenticated()) {
    // TODO(crbug.com/650424): Footer items must currently go into a separate
    // section, to work around a drawing bug in MDC.
    [model addSectionWithIdentifier:SectionGoogleAccount];
    [model addItem:[self footerForGoogleAccountSectionItem]
        toSectionWithIdentifier:SectionGoogleAccount];
  }

  browser_sync::ProfileSyncService* syncService =
      ProfileSyncServiceFactory::GetForBrowserState(self.browserState);
  if (syncService && syncService->IsSyncActive()) {
    // TODO(crbug.com/650424): Footer items must currently go into a separate
    // section, to work around a drawing bug in MDC.
    [model addSectionWithIdentifier:SectionClearSyncAndSavedSiteData];
    [model addItem:[self footerClearSyncAndSavedSiteDataItem]
        toSectionWithIdentifier:SectionClearSyncAndSavedSiteData];
  } else {
    // TODO(crbug.com/650424): Footer items must currently go into a separate
    // section, to work around a drawing bug in MDC.
    [model addSectionWithIdentifier:SectionSavedSiteData];
    [model addItem:[self footerSavedSiteDataItem]
        toSectionWithIdentifier:SectionSavedSiteData];
  }

  // If not signed in, no need to continue with profile syncing.
  if (!signinManager->IsAuthenticated()) {
    return;
  }

  history::WebHistoryService* historyService =
      ios::WebHistoryServiceFactory::GetForBrowserState(_browserState);

  __weak ClearBrowsingDataManager* weakSelf = self;
  browsing_data::ShouldShowNoticeAboutOtherFormsOfBrowsingHistory(
      syncService, historyService, base::BindBlockArc(^(bool shouldShowNotice) {
        ClearBrowsingDataManager* strongSelf = weakSelf;
        [strongSelf
            setShouldShowNoticeAboutOtherFormsOfBrowsingHistory:shouldShowNotice
                                                       forModel:model];
      }));

  browsing_data::ShouldPopupDialogAboutOtherFormsOfBrowsingHistory(
      syncService, historyService, GetChannel(),
      base::BindBlockArc(^(bool shouldShowPopup) {
        ClearBrowsingDataManager* strongSelf = weakSelf;
        [strongSelf setShouldPopupDialogAboutOtherFormsOfBrowsingHistory:
                        shouldShowPopup];
      }));
}

#pragma mark Items

// Creates item of type |itemType| with |mask| of data to be cleared if
// selected, |prefName|, and |titleId| of item.
- (ClearBrowsingDataItem*)clearDataItemWithType:
                              (ClearBrowsingDataItemType)itemType
                                        titleID:(int)titleMessageID
                                           mask:(BrowsingDataRemoveMask)mask
                                       prefName:(const char*)prefName {
  PrefService* prefs = self.browserState->GetPrefs();
  std::unique_ptr<BrowsingDataCounterWrapper> counter;
  if (experimental_flags::IsNewClearBrowsingDataUIEnabled()) {
    __weak ClearBrowsingDataManager* weakSelf = self;
    counter = BrowsingDataCounterWrapper::CreateCounterWrapper(
        prefName, self.browserState, prefs,
        base::BindBlockArc(
            ^(const browsing_data::BrowsingDataCounter::Result& result) {
              [weakSelf.consumer
                  updateCounter:itemType
                     detailText:[weakSelf counterTextFromResult:result]];
            }));
  }

  ClearBrowsingDataItem* clearDataItem =
      [[ClearBrowsingDataItem alloc] initWithType:itemType
                                          counter:std::move(counter)];
  clearDataItem.text = l10n_util::GetNSString(titleMessageID);
  if (prefs->GetBoolean(prefName)) {
    clearDataItem.accessoryType = MDCCollectionViewCellAccessoryCheckmark;
  }
  clearDataItem.dataTypeMask = mask;
  clearDataItem.prefName = prefName;
  clearDataItem.accessibilityIdentifier =
      [self accessibilityIdentifierFromItemType:itemType];

  // Because there is no counter for cookies, an explanatory text is displayed.
  if (itemType == DataTypeCookiesSiteData &&
      experimental_flags::IsNewClearBrowsingDataUIEnabled() &&
      prefs->GetBoolean(browsing_data::prefs::kDeleteCookies)) {
    clearDataItem.detailText = l10n_util::GetNSString(IDS_DEL_COOKIES_COUNTER);
  }

  return clearDataItem;
}

- (CollectionViewItem*)footerForGoogleAccountSectionItem {
  return _shouldShowNoticeAboutOtherFormsOfBrowsingHistory
             ? [self footerGoogleAccountAndMyActivityItem]
             : [self footerGoogleAccountItem];
}

- (CollectionViewItem*)footerGoogleAccountItem {
  CollectionViewFooterItem* footerItem =
      [[CollectionViewFooterItem alloc] initWithType:FooterGoogleAccount];
  footerItem.text =
      l10n_util::GetNSString(IDS_IOS_CLEAR_BROWSING_DATA_FOOTER_ACCOUNT);
  UIImage* image = ios::GetChromeBrowserProvider()
                       ->GetBrandedImageProvider()
                       ->GetClearBrowsingDataAccountActivityImage();
  footerItem.image = image;
  return footerItem;
}

- (CollectionViewItem*)footerGoogleAccountAndMyActivityItem {
  UIImage* image = ios::GetChromeBrowserProvider()
                       ->GetBrandedImageProvider()
                       ->GetClearBrowsingDataAccountActivityImage();
  return [self
      footerItemWithType:FooterGoogleAccountAndMyActivity
                 titleID:IDS_IOS_CLEAR_BROWSING_DATA_FOOTER_ACCOUNT_AND_HISTORY
                     URL:kClearBrowsingDataMyActivityUrlInFooterURL
                   image:image];
}

- (CollectionViewItem*)footerSavedSiteDataItem {
  UIImage* image = ios::GetChromeBrowserProvider()
                       ->GetBrandedImageProvider()
                       ->GetClearBrowsingDataSiteDataImage();
  return [self
      footerItemWithType:FooterSavedSiteData
                 titleID:IDS_IOS_CLEAR_BROWSING_DATA_FOOTER_SAVED_SITE_DATA
                     URL:kClearBrowsingDataLearnMoreURL
                   image:image];
}

- (CollectionViewItem*)footerClearSyncAndSavedSiteDataItem {
  UIImage* infoIcon = [ChromeIcon infoIcon];
  UIImage* image = TintImage(infoIcon, [[MDCPalette greyPalette] tint500]);
  return [self
      footerItemWithType:FooterClearSyncAndSavedSiteData
                 titleID:
                     IDS_IOS_CLEAR_BROWSING_DATA_FOOTER_CLEAR_SYNC_AND_SAVED_SITE_DATA
                     URL:kClearBrowsingDataLearnMoreURL
                   image:image];
}

- (CollectionViewItem*)footerItemWithType:(ClearBrowsingDataItemType)itemType
                                  titleID:(int)titleMessageID
                                      URL:(const char[])URL
                                    image:(UIImage*)image {
  CollectionViewFooterItem* footerItem =
      [[CollectionViewFooterItem alloc] initWithType:itemType];
  footerItem.text = l10n_util::GetNSString(titleMessageID);
  footerItem.linkURL = google_util::AppendGoogleLocaleParam(
      GURL(URL), GetApplicationContext()->GetApplicationLocale());
  footerItem.linkDelegate = self.linkDelegate;
  footerItem.image = image;
  return footerItem;
}

- (CollectionViewItem*)timeRangeItem {
  CollectionViewDetailItem* timeRangeItem =
      [[CollectionViewDetailItem alloc] initWithType:TimeRange];
  timeRangeItem.text = l10n_util::GetNSString(
      IDS_IOS_CLEAR_BROWSING_DATA_TIME_RANGE_SELECTOR_TITLE);
  NSString* detailText = [TimeRangeSelectorCollectionViewController
      timePeriodLabelForPrefs:self.browserState->GetPrefs()];
  DCHECK(detailText);
  timeRangeItem.detailText = detailText;
  timeRangeItem.accessoryType =
      MDCCollectionViewCellAccessoryDisclosureIndicator;
  timeRangeItem.accessibilityTraits |= UIAccessibilityTraitButton;
  return timeRangeItem;
}

- (NSString*)accessibilityIdentifierFromItemType:(NSInteger)itemType {
  switch (itemType) {
    case DataTypeBrowsingHistory:
      return kClearBrowsingHistoryCellAccessibilityIdentifier;
    case DataTypeCookiesSiteData:
      return kClearCookiesCellAccessibilityIdentifier;
    case DataTypeCache:
      return kClearCacheCellAccessibilityIdentifier;
    case DataTypeSavedPasswords:
      return kClearSavedPasswordsCellAccessibilityIdentifier;
    case DataTypeAutofill:
      return kClearAutofillCellAccessibilityIdentifier;
    default: {
      NOTREACHED();
      return nil;
    }
  }
}

#pragma mark - Private Methods

- (void)clearDataForDataTypes:(BrowsingDataRemoveMask)mask {
  DCHECK(mask != BrowsingDataRemoveMask::REMOVE_NOTHING);

  [self.consumer removeBrowsingDataForBrowserState:_browserState
                                        timePeriod:self.timePeriod
                                        removeMask:mask
                                   completionBlock:nil];

  // Send the "Cleared Browsing Data" event to the feature_engagement::Tracker
  // when the user initiates a clear browsing data action. No event is sent if
  // the browsing data is cleared without the user's input.
  feature_engagement::TrackerFactory::GetForBrowserState(_browserState)
      ->NotifyEvent(feature_engagement::events::kClearedBrowsingData);

  if (IsRemoveDataMaskSet(mask, BrowsingDataRemoveMask::REMOVE_HISTORY)) {
    PrefService* prefs = _browserState->GetPrefs();
    int noticeShownTimes = prefs->GetInteger(
        browsing_data::prefs::kClearBrowsingDataHistoryNoticeShownTimes);

    // When the deletion is complete, we might show an additional dialog with
    // a notice about other forms of browsing history. This is the case if
    const bool showDialog =
        // 1. The dialog is relevant for the user.
        _shouldPopupDialogAboutOtherFormsOfBrowsingHistory &&
        // 2. The notice has been shown less than |kMaxTimesHistoryNoticeShown|.
        noticeShownTimes < kMaxTimesHistoryNoticeShown;
    if (!showDialog) {
      return;
    }
    UMA_HISTOGRAM_BOOLEAN(
        "History.ClearBrowsingData.ShownHistoryNoticeAfterClearing",
        showDialog);

    // Increment the preference.
    prefs->SetInteger(
        browsing_data::prefs::kClearBrowsingDataHistoryNoticeShownTimes,
        noticeShownTimes + 1);
    [self.consumer showBrowsingHistoryRemovedDialog];
  }
}

#pragma mark Properties

- (void)setShouldShowNoticeAboutOtherFormsOfBrowsingHistory:(BOOL)showNotice
                                                   forModel:(ListModel*)model {
  _shouldShowNoticeAboutOtherFormsOfBrowsingHistory = showNotice;
  // Update the account footer if the model was already loaded.
  if (!model) {
    return;
  }
  UMA_HISTOGRAM_BOOLEAN(
      "History.ClearBrowsingData.HistoryNoticeShownInFooterWhenUpdated",
      _shouldShowNoticeAboutOtherFormsOfBrowsingHistory);

  SigninManager* signinManager =
      ios::SigninManagerFactory::GetForBrowserState(_browserState);
  if (!signinManager->IsAuthenticated()) {
    return;
  }

  CollectionViewItem* footerItem = [self footerForGoogleAccountSectionItem];
  // TODO(crbug.com/650424): Simplify with setFooter:inSection: when the bug in
  // MDC is fixed.
  // Remove the footer if there is one in that section.
  if ([model hasSectionForSectionIdentifier:SectionGoogleAccount]) {
    if ([model hasItemForItemType:FooterGoogleAccount
                sectionIdentifier:SectionGoogleAccount]) {
      [model removeItemWithType:FooterGoogleAccount
          fromSectionWithIdentifier:SectionGoogleAccount];
    } else {
      [model removeItemWithType:FooterGoogleAccountAndMyActivity
          fromSectionWithIdentifier:SectionGoogleAccount];
    }
  }
  // Add the new footer.
  [model addItem:footerItem toSectionWithIdentifier:SectionGoogleAccount];
  [self.consumer updateCellsForItem:footerItem];
}

#pragma mark TimeRangeSelectorCollectionViewControllerDelegate

- (void)timeRangeSelectorViewController:
            (TimeRangeSelectorCollectionViewController*)collectionViewController
                    didSelectTimePeriod:(browsing_data::TimePeriod)timePeriod {
  self.timePeriod = timePeriod;
}

@end
