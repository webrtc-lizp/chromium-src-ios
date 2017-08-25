// Copyright 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_METRICS_TAB_USAGE_RECORDER_H_
#define IOS_CHROME_BROWSER_METRICS_TAB_USAGE_RECORDER_H_

#include <deque>
#include <map>
#include <vector>

#include "base/ios/weak_nsobject.h"
#include "base/macros.h"
#include "base/time/time.h"
#import "ios/chrome/browser/web_state_list/web_state_list_observer.h"

class PrerenderService;
class WebStateList;

namespace web {
class WebState;
}

// Histogram names (visible for testing only).

// The name of the histogram that records the state of the selected tab
// (i.e. the tab being switched to).
extern const char kSelectedTabHistogramName[];

// The name of the histogram that records the number of page loads before an
// evicted tab is selected.
extern const char kPageLoadsBeforeEvictedTabSelected[];

// The name of the histogram tracking the reload time for a previously-evicted
// tab.
extern const char kEvictedTabReloadTime[];

// The name of the histogram for whether or not the reload of a
// previously-evicted tab completed successfully.
extern const char kEvictedTabReloadSuccessRate[];

// The name of the histogram for whether or not the user switched tabs before an
// evicted tab completed reloading.
extern const char kDidUserWaitForEvictedTabReload[];

// The name of the histogram that records time intervals between restores of
// previously-evicted tabs.  The first restore seen in a session will record the
// time since the session started.
extern const char kTimeBetweenRestores[];

// The name of the histogram that records time intervals between the last
// restore of a previously-evicted tab and the end of the session.
extern const char kTimeAfterLastRestore[];

// Name of histogram to record whether a memory warning had been recently
// received when a renderer termination occurred.
extern const char kRendererTerminationSawMemoryWarning[];

// Name of histogram to record the number of alive renderers when a renderer
// termination is received.
extern const char kRendererTerminationAliveRenderers[];

// Name of histogram to record the number of renderers that were alive shortly
// before a renderer termination. This metric is being recorded in case the OS
// kills renderers in batches.
extern const char kRendererTerminationRecentlyAliveRenderers[];

// The recently alive renderer count metric counts all renderers that were alive
// x seconds before a renderer termination. |kSecondsBeforeRendererTermination|
// specifies x.
extern const int kSecondsBeforeRendererTermination;

// Reports usage about the lifecycle of a single TabModel's tabs.
class TabUsageRecorder : public WebStateListObserver {
 public:
  enum TabStateWhenSelected {
    IN_MEMORY = 0,
    EVICTED,
    EVICTED_DUE_TO_COLD_START,
    PARTIALLY_EVICTED,             // Currently, used only by Android.
    EVICTED_DUE_TO_BACKGROUNDING,  // Deprecated
    EVICTED_DUE_TO_INCOGNITO,
    RELOADED_DUE_TO_COLD_START_FG_TAB_ON_START,   // Android.
    RELOADED_DUE_TO_COLD_START_BG_TAB_ON_SWITCH,  // Android.
    LAZY_LOAD_FOR_OPEN_IN_NEW_TAB,                // Android
    STOPPED_DUE_TO_LOADING_WHEN_BACKGROUNDING,    // Deprecated.
    EVICTED_DUE_TO_LOADING_WHEN_BACKGROUNDING,    // Deprecated.
    EVICTED_DUE_TO_RENDERER_TERMINATION,
    TAB_STATE_COUNT,
  };

  enum LoadDoneState {
    LOAD_FAILURE,
    LOAD_SUCCESS,
    LOAD_DONE_STATE_COUNT,
  };

  enum EvictedTabUserBehavior {
    USER_WAITED,
    USER_DID_NOT_WAIT,
    USER_LEFT_CHROME,
    USER_BEHAVIOR_COUNT,
  };

  // Initializes the TabUsageRecorder to watch |web_state_list|.
  TabUsageRecorder(WebStateList* web_state_list,
                   PrerenderService* prerender_service);
  ~TabUsageRecorder() override;

  // Called during startup when the tab model is created, or shortly after a
  // post-crash launch if the tabs are restored.  |tabs| is an array containing
  // the tabs being restored in the current tab model. |active_tab| is the tab
  // currently in the foreground.
  void InitialRestoredTabs(web::WebState* active_tab,
                           const std::vector<web::WebState*>& tabs);

  // Called when a tab switch is made.  Determines what value to record, and
  // when to reset the page load counter.
  void RecordTabSwitched(web::WebState* old_tab, web::WebState* new_tab);

  // Called when the tab model which the user is primarily interacting with has
  // changed. The |active_tab| is the current tab of the tab model. If the user
  // began interacting with |active_tab|, |primary| should be true. If the user
  // stopped interacting with |active_tab|, |primary| should be false.
  void RecordPrimaryTabModelChange(bool primary, web::WebState* active_tab);

  // Called when a page load begins, to keep track of how many page loads
  // happen before an evicted tab is seen.
  void RecordPageLoadStart(web::WebState* tab);

  // Called when a page load finishes, to track the load time for evicted tabs.
  void RecordPageLoadDone(web::WebState* tab, bool success);

  // Called when there is a user-initiated reload.
  void RecordReload(web::WebState* tab);

  // Called when WKWebView's renderer is terminated. |web_state| contains the
  // tab whose renderer was terminated, and |visible| indicates whether or not
  // the tab was visible when the renderer terminated.
  void RendererTerminated(web::WebState* tab, bool visible);

  // Called when the app has been backgrounded.
  void AppDidEnterBackground();

  // Called when the app has been foregrounded.
  void AppWillEnterForeground();

  // Resets the page load count.
  void ResetPageLoads();

  // Size of |evicted_tabs_|.  Used for testing.
  int EvictedTabsMapSize();

  // Resets all tracked data.  Used for testing.
  void ResetAll();

 private:
  // TODO(crbug.com/731724): remove this once the code has been refactored not
  // to depends on injecting values in |termination_timestamps_|.
  friend class TabUsageRecorderTest;

  // Clear out all state regarding a current evicted tab.
  void ResetEvictedTab();

  // Whether or not a tab can be disregarded by the metrics.
  bool ShouldIgnoreTab(web::WebState* tab);

  // Whether or not the tab has already been evicted.
  bool TabAlreadyEvicted(web::WebState* tab);

  // Returns the state of the given tab.  Call only once per tab, as it removes
  // the tab from |evicted_tabs_|.
  TabStateWhenSelected ExtractTabState(web::WebState* tab);

  // Records various time metrics when a restore of an evicted tab begins.
  void RecordRestoreStartTime();

  // Returns the number of WebState that are still alive (in-memory).
  int GetLiveTabsCount() const;

  // Called before one of the tracked WebState is destroyed. The WebState is
  // still valid but will become invalid afterwards, so any reference to it
  // should be removed.
  void OnWebStateDestroyed(web::WebState* web_state);

  // WebStateListObserver implementation.
  void WebStateInsertedAt(WebStateList* web_state_list,
                          web::WebState* web_state,
                          int index,
                          bool activating) override;
  void WebStateReplacedAt(WebStateList* web_state_list,
                          web::WebState* old_web_state,
                          web::WebState* new_web_state,
                          int index) override;
  void WebStateDetachedAt(WebStateList* web_state_list,
                          web::WebState* web_state,
                          int index) override;
  void WebStateActivatedAt(WebStateList* web_state_list,
                           web::WebState* old_web_state,
                           web::WebState* new_web_state,
                           int active_index,
                           bool user_action) override;

  // Keep track of when the most recent tab restore begins, to record the time
  // between evicted-tab-reloads.
  base::TimeTicks restore_start_time_;

  // Keep track of the timestamps of renderer terminations in order to find the
  // number of recently alive tabs when a renderer termination occurs.
  std::deque<base::TimeTicks> termination_timestamps_;

  // Number of page loads since the last evicted tab was seen.
  unsigned int page_loads_ = 0;

  // Keep track of the current tab, but only if it has been evicted.
  // This is kept as a pointer value only - it should never be dereferenced.
  web::WebState* evicted_tab_ = nullptr;

  // State of |evicted_tab_| at the time it became the current tab.
  TabStateWhenSelected evicted_tab_state_ = IN_MEMORY;

  // Keep track of the tab last selected when this tab model was switched
  // away from to another mode (e.g. to incognito).
  // Kept as a pointer value only - it should never be dereferenced.
  web::WebState* mode_switch_tab_ = nullptr;

  // Keep track of a tab that was created to be immediately selected.  It should
  // not contribute to the "StatusWhenSwitchedBackToForeground" metric.
  web::WebState* tab_created_selected_ = nullptr;

  // Keep track of when the evicted tab starts to reload, so that the total
  // time it takes to reload can be recorded.
  base::TimeTicks evicted_tab_reload_start_time_;

  // Keep track of the tabs that have a known eviction cause.
  std::map<web::WebState*, TabStateWhenSelected> evicted_tabs_;

  // The WebStateList containing all the monitored tabs.
  WebStateList* web_state_list_;  // weak

  // The PrerenderService used to check whether a tab is pre-rendering. May
  // be null during unit testing.
  PrerenderService* prerender_service_;

  // Observers for NSNotificationCenter notifications.
  __strong id<NSObject> application_backgrounding_observer_;
  __strong id<NSObject> application_foregrounding_observer_;

  DISALLOW_COPY_AND_ASSIGN(TabUsageRecorder);
};

#endif  // IOS_CHROME_BROWSER_METRICS_TAB_USAGE_RECORDER_H_
