// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_OVERLAYS_PUBLIC_OVERLAY_REQUEST_H_
#define IOS_CHROME_BROWSER_OVERLAYS_PUBLIC_OVERLAY_REQUEST_H_

#include <memory>

#include "base/supports_user_data.h"
#include "ios/chrome/browser/overlays/public/overlay_request_callbacks.h"

class OverlayResponse;
class OverlayCallbackManager;

// Model object used to track overlays requested for OverlayManager.
class OverlayRequest {
 public:
  virtual ~OverlayRequest() = default;

  // Creates an OverlayRequest configured with an OverlayUserData of type
  // ConfigType.  The ConfigType is constructed using the arguments passed to
  // this function.  For example, if a configuration of type StringConfig has
  // a constructor that takes a string, a request configured with a StringConfig
  // can be created using:
  //
  // OverlayRequest::CreateWithConfig<StringConfig>("configuration string");
  template <class ConfigType, typename... Args>
  static std::unique_ptr<OverlayRequest> CreateWithConfig(Args&&... args) {
    std::unique_ptr<OverlayRequest> request = OverlayRequest::Create();
    ConfigType::CreateForUserData(request->data(), std::forward<Args>(args)...);
    return request;
  }

  // Returns the OverlayUserData of type ConfigType stored in the request's
  // user data, or nullptr if it is not found. For example, a configuration of
  // type Config can be retrieved using:
  //
  // request->GetConfig<Config>();
  template <class ConfigType>
  ConfigType* GetConfig() {
    return ConfigType::FromUserData(data());
  }

  // Returns the request's callback controller, which can be used to communicate
  // user interaction information back to the reqeuster.
  virtual OverlayCallbackManager* GetCallbackManager() = 0;

  // DEPRECATED: Responses and callbacks should be set using the callback
  // manager.
  virtual void set_response(std::unique_ptr<OverlayResponse> response) = 0;
  virtual OverlayResponse* response() const = 0;
  virtual void set_callback(OverlayCompletionCallback callback) = 0;

 protected:
  OverlayRequest() = default;

  // Creates an unconfigured OverlayRequest.
  static std::unique_ptr<OverlayRequest> Create();

  // The container used to hold the user data.
  virtual base::SupportsUserData* data() = 0;
};

#endif  // IOS_CHROME_BROWSER_OVERLAYS_PUBLIC_OVERLAY_REQUEST_H_
