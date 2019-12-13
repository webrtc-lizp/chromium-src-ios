// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_CRASH_REPORT_BREADCRUMBS_BREADCRUMB_MANAGER_KEYED_SERVICE_FACTORY_H_
#define IOS_CHROME_BROWSER_CRASH_REPORT_BREADCRUMBS_BREADCRUMB_MANAGER_KEYED_SERVICE_FACTORY_H_

#include "base/no_destructor.h"
#include "components/keyed_service/ios/browser_state_keyed_service_factory.h"

class BreadcrumbManagerKeyedService;

namespace ios {
class ChromeBrowserState;
}

class BreadcrumbManagerKeyedServiceFactory
    : public BrowserStateKeyedServiceFactory {
 public:
  static BreadcrumbManagerKeyedServiceFactory* GetInstance();
  static BreadcrumbManagerKeyedService* GetForBrowserState(
      ios::ChromeBrowserState* browser_state);

 private:
  friend class base::NoDestructor<BreadcrumbManagerKeyedServiceFactory>;

  BreadcrumbManagerKeyedServiceFactory();
  ~BreadcrumbManagerKeyedServiceFactory() override;

  // BrowserStateKeyedServiceFactory implementation.
  std::unique_ptr<KeyedService> BuildServiceInstanceFor(
      web::BrowserState* browser_state) const override;
  web::BrowserState* GetBrowserStateToUse(
      web::BrowserState* browser_state) const override;

  BreadcrumbManagerKeyedServiceFactory(
      const BreadcrumbManagerKeyedServiceFactory&) = delete;
};

#endif  // IOS_CHROME_BROWSER_CRASH_REPORT_BREADCRUMBS_BREADCRUMB_MANAGER_KEYED_SERVICE_FACTORY_H_
