// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/overlays/public/overlay_request_callback_installer.h"

#include "ios/chrome/browser/overlays/public/overlay_callback_manager.h"
#include "ios/chrome/browser/overlays/public/overlay_request.h"
#include "ios/chrome/browser/overlays/public/overlay_response.h"
#include "ios/chrome/browser/overlays/test/fake_overlay_request_callback_installer.h"
#include "ios/chrome/browser/overlays/test/overlay_test_macros.h"
#include "testing/gmock/include/gmock/gmock.h"
#include "testing/platform_test.h"

namespace {
// Request configs used in tests.
DEFINE_TEST_OVERLAY_REQUEST_CONFIG(SupportedConfig);
DEFINE_TEST_OVERLAY_REQUEST_CONFIG(UnsupportedConfig);
DEFINE_TEST_OVERLAY_RESPONSE_INFO(DispatchInfo);
DEFINE_TEST_OVERLAY_RESPONSE_INFO(CompletionInfo);

// Mock callback receiver.
class MockCallbackReceiver : public FakeOverlayRequestCallbackReceiver {
 public:
  MockCallbackReceiver() = default;
  ~MockCallbackReceiver() = default;

  MOCK_METHOD2(CompletionCallback,
               void(OverlayRequest* request, OverlayResponse* response));
  MOCK_METHOD3(DispatchCallback,
               void(OverlayRequest* request,
                    const OverlayResponseSupport* response_support,
                    OverlayResponse* response));
};
}  // namespace

// Test fixture for OverlayRequestCallbackInstaller.
class OverlayRequestCallbackInstallerTest : public PlatformTest {
 public:
  OverlayRequestCallbackInstallerTest() : installer_(&mock_receiver_) {
    installer_.SetRequestSupport(SupportedConfig::RequestSupport());
    installer_.StartInstallingDispatchCallbacksWithSupport(
        DispatchInfo::ResponseSupport());
  }
  ~OverlayRequestCallbackInstallerTest() override = default;

  // Dispatches an OverlayResponse created with DispatchInfo through |request|'s
  // callback manager.  The mock callback receiver will be notified to expect
  // callback execution if |expect_callback_execution| is true.
  void DispatchResponse(OverlayRequest* request,
                        bool expect_callback_execution) {
    std::unique_ptr<OverlayResponse> response =
        OverlayResponse::CreateWithInfo<DispatchInfo>();
    if (expect_callback_execution) {
      EXPECT_CALL(mock_receiver_,
                  DispatchCallback(request, DispatchInfo::ResponseSupport(),
                                   response.get()));
    }
    request->GetCallbackManager()->DispatchResponse(std::move(response));
  }

 protected:
  testing::StrictMock<MockCallbackReceiver> mock_receiver_;
  FakeOverlayRequestCallbackInstaller installer_;
};

// Tests that callbacks are successfully installed for supported requests.
TEST_F(OverlayRequestCallbackInstallerTest, InstallCallbacks) {
  std::unique_ptr<OverlayRequest> request =
      OverlayRequest::CreateWithConfig<SupportedConfig>();
  installer_.InstallCallbacks(request.get());

  // Dispatch responses with DispatchInfo, verifying that the mock dispatch
  // callback was executed for each.
  DispatchResponse(request.get(), /*expect_callback_execution=*/true);
  DispatchResponse(request.get(), /*expect_callback_execution=*/true);

  // Destroy the request and verify that the completion callback was executed.
  std::unique_ptr<OverlayResponse> completion_response =
      OverlayResponse::CreateWithInfo<CompletionInfo>();
  EXPECT_CALL(mock_receiver_,
              CompletionCallback(request.get(), completion_response.get()));
  request->GetCallbackManager()->SetCompletionResponse(
      std::move(completion_response));
  request = nullptr;
}

// Tests that callbacks are not installed for unsupported requests.
TEST_F(OverlayRequestCallbackInstallerTest, UnsupportedRequest) {
  std::unique_ptr<OverlayRequest> request =
      OverlayRequest::CreateWithConfig<UnsupportedConfig>();
  installer_.InstallCallbacks(request.get());

  // Dispatch a response with DispatchInfo, verifying that the mock dispatch
  // callback was not executed.
  DispatchResponse(request.get(), /*expect_callback_execution=*/false);

  // Destroy the request, verifying that the mock completion was not executed.
  request = nullptr;
}

// Tests that InstallCallbacks() only installs the installer's callbacks once,
// even if called multiple times.
TEST_F(OverlayRequestCallbackInstallerTest, Idempotency) {
  std::unique_ptr<OverlayRequest> request =
      OverlayRequest::CreateWithConfig<SupportedConfig>();

  // Attempt to install callbacks twice on the same request.
  installer_.InstallCallbacks(request.get());
  installer_.InstallCallbacks(request.get());

  // Dispatch a single response with DispatchInfo verifying that the callback
  // was only executed once.
  DispatchResponse(request.get(), /*expect_callback_execution=*/true);

  // Expect the completion callback to be executed upon destruction of
  // |request|.
  EXPECT_CALL(mock_receiver_, CompletionCallback(request.get(), nullptr));
}
