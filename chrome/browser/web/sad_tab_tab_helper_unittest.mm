// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/web/sad_tab_tab_helper.h"

#import "ios/chrome/browser/ui/sad_tab/sad_tab_view.h"
#import "ios/web/public/test/fakes/test_web_state.h"
#import "ios/web/public/web_state/ui/crw_generic_content_view.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// Verifies that provided |content_view| exists, contains the expected
// view and matches the desired |mode|.
void VerifyContentViewMatchesMode(CRWContentView* content_view,
                                  SadTabViewMode mode) {
  ASSERT_TRUE([content_view isKindOfClass:[CRWGenericContentView class]]);
  UIView* content_view_view = [(CRWGenericContentView*)content_view view];
  ASSERT_TRUE([content_view_view isKindOfClass:[SadTabView class]]);
  EXPECT_EQ([(SadTabView*)content_view_view mode], mode);
}

class SadTabTabHelperTest : public PlatformTest {
 protected:
  SadTabTabHelperTest() : application_(OCMClassMock([UIApplication class])) {
    SadTabTabHelper::CreateForWebState(&web_state_);
    OCMStub([application_ sharedApplication]).andReturn(application_);
  }
  ~SadTabTabHelperTest() override { [application_ stopMocking]; }
  web::TestWebState web_state_;
  id application_;
};

// Tests that SadTab is not presented for not shown web states.
TEST_F(SadTabTabHelperTest, NotPresented) {
  OCMStub([application_ applicationState]).andReturn(UIApplicationStateActive);

  // WebState should not have presented a transient content view.
  EXPECT_FALSE(web_state_.GetTransientContentView());

  // Helper should get notified of render process failure,
  // but Sad Tab should not be presented, because web state was not shown.
  web_state_.OnRenderProcessGone();
  EXPECT_FALSE(web_state_.GetTransientContentView());
}

// Tests that SadTab is not presented if app is in background.
TEST_F(SadTabTabHelperTest, AppInBackground) {
  OCMStub([application_ applicationState])
      .andReturn(UIApplicationStateBackground);
  web_state_.WasShown();

  // WebState should not have presented a transient content view.
  EXPECT_FALSE(web_state_.GetTransientContentView());

  // Helper should get notified of render process failure,
  // but Sad Tab should not be presented, because application is backgrounded.
  web_state_.OnRenderProcessGone();
  EXPECT_FALSE(web_state_.GetTransientContentView());
}

// Tests that SadTab is not presented if app is in inactive.
TEST_F(SadTabTabHelperTest, AppIsInactive) {
  OCMStub([application_ applicationState])
      .andReturn(UIApplicationStateInactive);
  web_state_.WasShown();

  // WebState should not have presented a transient content view.
  EXPECT_FALSE(web_state_.GetTransientContentView());

  // Helper should get notified of render process failure,
  // but Sad Tab should not be presented, because application is inactive.
  web_state_.OnRenderProcessGone();
  EXPECT_FALSE(web_state_.GetTransientContentView());
}

// Tests that SadTab is presented for shown web states.
TEST_F(SadTabTabHelperTest, Presented) {
  OCMStub([application_ applicationState]).andReturn(UIApplicationStateActive);

  web_state_.WasShown();

  // WebState should not have presented a transient content view.
  EXPECT_FALSE(web_state_.GetTransientContentView());

  // Helper should get notified of render process failure.
  web_state_.OnRenderProcessGone();
  EXPECT_TRUE(web_state_.GetTransientContentView());
}

// Tests that repeated failures generate the correct UI.
TEST_F(SadTabTabHelperTest, RepeatedFailuresShowCorrectUI) {
  OCMStub([application_ applicationState]).andReturn(UIApplicationStateActive);
  web_state_.WasShown();

  // Helper should get notified of render process failure.
  web_state_.OnRenderProcessGone();

  // The content view should initially be of the RELOAD type.
  VerifyContentViewMatchesMode(web_state_.GetTransientContentView(),
                               SadTabViewMode::RELOAD);

  // On a second render process crash, the content view should be of a
  // FEEDBACK type.
  web_state_.OnRenderProcessGone();
  VerifyContentViewMatchesMode(web_state_.GetTransientContentView(),
                               SadTabViewMode::FEEDBACK);

  // All subsequent crashes should be of a FEEDBACK type.
  web_state_.OnRenderProcessGone();
  VerifyContentViewMatchesMode(web_state_.GetTransientContentView(),
                               SadTabViewMode::FEEDBACK);
}

// Tests that repeated failures can time out, and return to the RELOAD UI.
TEST_F(SadTabTabHelperTest, FailureInterval) {
  OCMStub([application_ applicationState]).andReturn(UIApplicationStateActive);

  // N.B. The test fixture web_state_ is not used for this test as a custom
  // |repeat_failure_interval| is required.
  web::TestWebState web_state;
  SadTabTabHelper::CreateForWebState(&web_state, 0.0f);
  web_state.WasShown();

  // Helper should get notified of render process failure.
  // SadTab should be shown.
  web_state.OnRenderProcessGone();

  // The content view should initially be of the RELOAD type.
  VerifyContentViewMatchesMode(web_state.GetTransientContentView(),
                               SadTabViewMode::RELOAD);

  // On a second render process crash, the content view should still be of a
  // RELOAD type due to the 0.0f interval timeout.
  web_state.OnRenderProcessGone();
  VerifyContentViewMatchesMode(web_state.GetTransientContentView(),
                               SadTabViewMode::RELOAD);
}
