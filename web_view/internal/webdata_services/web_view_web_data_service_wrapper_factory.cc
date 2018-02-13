// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/web_view/internal/webdata_services/web_view_web_data_service_wrapper_factory.h"

#include "base/bind.h"
#include "base/callback.h"
#include "base/files/file_path.h"
#include "base/logging.h"
#include "base/memory/singleton.h"
#include "components/autofill/core/browser/webdata/autofill_webdata_service.h"
#include "components/keyed_service/core/service_access_type.h"
#include "components/keyed_service/ios/browser_state_dependency_manager.h"
#include "components/signin/core/browser/webdata/token_web_data.h"
#include "components/sync/model/syncable_service.h"
#include "components/webdata_services/web_data_service_wrapper.h"
#include "ios/web/public/web_thread.h"
#include "ios/web_view/internal/app/application_context.h"
#include "ios/web_view/internal/web_view_browser_state.h"

namespace ios_web_view {
namespace {

void DoNothingOnErrorCallback(WebDataServiceWrapper::ErrorType error_type,
                              sql::InitStatus status,
                              const std::string& diagnostics) {}

}  // namespace

// static
WebDataServiceWrapper* WebViewWebDataServiceWrapperFactory::GetForBrowserState(
    WebViewBrowserState* browser_state,
    ServiceAccessType access_type) {
  DCHECK(access_type == ServiceAccessType::EXPLICIT_ACCESS ||
         !browser_state->IsOffTheRecord());
  return static_cast<WebDataServiceWrapper*>(
      GetInstance()->GetServiceForBrowserState(browser_state, true));
}

// static
scoped_refptr<autofill::AutofillWebDataService>
WebViewWebDataServiceWrapperFactory::GetAutofillWebDataForBrowserState(
    WebViewBrowserState* browser_state,
    ServiceAccessType access_type) {
  WebDataServiceWrapper* wrapper =
      GetForBrowserState(browser_state, access_type);
  return wrapper ? wrapper->GetAutofillWebData() : nullptr;
}

// static
scoped_refptr<TokenWebData>
WebViewWebDataServiceWrapperFactory::GetTokenWebDataForBrowserState(
    WebViewBrowserState* browser_state,
    ServiceAccessType access_type) {
  WebDataServiceWrapper* wrapper =
      GetForBrowserState(browser_state, access_type);
  return wrapper ? wrapper->GetTokenWebData() : nullptr;
}

// static
WebViewWebDataServiceWrapperFactory*
WebViewWebDataServiceWrapperFactory::GetInstance() {
  return base::Singleton<WebViewWebDataServiceWrapperFactory>::get();
}

WebViewWebDataServiceWrapperFactory::WebViewWebDataServiceWrapperFactory()
    : BrowserStateKeyedServiceFactory(
          "WebDataService",
          BrowserStateDependencyManager::GetInstance()) {}

WebViewWebDataServiceWrapperFactory::~WebViewWebDataServiceWrapperFactory() {}

std::unique_ptr<KeyedService>
WebViewWebDataServiceWrapperFactory::BuildServiceInstanceFor(
    web::BrowserState* context) const {
  const base::FilePath& browser_state_path = context->GetStatePath();
  return std::make_unique<WebDataServiceWrapper>(
      browser_state_path,
      ApplicationContext::GetInstance()->GetApplicationLocale(),
      web::WebThread::GetTaskRunnerForThread(web::WebThread::UI),
      base::Callback<void(syncer::ModelType)>(),
      base::BindRepeating(&DoNothingOnErrorCallback));
}

bool WebViewWebDataServiceWrapperFactory::ServiceIsNULLWhileTesting() const {
  return true;
}

}  // namespace ios_web_view
