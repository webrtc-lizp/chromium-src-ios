// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web_view/internal/translate/criwv_translate_client.h"

#include <vector>

#include "base/logging.h"
#import "base/mac/scoped_nsobject.h"
#include "base/memory/ptr_util.h"
#include "components/infobars/core/infobar.h"
#include "components/prefs/pref_service.h"
#include "components/translate/core/browser/page_translated_details.h"
#include "components/translate/core/browser/translate_accept_languages.h"
#include "components/translate/core/browser/translate_infobar_delegate.h"
#include "components/translate/core/browser/translate_manager.h"
#include "components/translate/core/browser/translate_prefs.h"
#include "components/translate/core/browser/translate_step.h"
#include "ios/web/public/browser_state.h"
#import "ios/web/public/web_state/web_state.h"
#include "ios/web_view/internal/criwv_browser_state.h"
#include "ios/web_view/internal/pref_names.h"
#include "ios/web_view/internal/translate/criwv_translate_accept_languages_factory.h"
#import "ios/web_view/internal/translate/criwv_translate_manager_impl.h"
#import "ios/web_view/public/cwv_translate_delegate.h"
#include "url/gurl.h"

DEFINE_WEB_STATE_USER_DATA_KEY(ios_web_view::CRIWVTranslateClient);

namespace ios_web_view {

CRIWVTranslateClient::CRIWVTranslateClient(web::WebState* web_state)
    : web::WebStateObserver(web_state),
      translate_manager_(base::MakeUnique<translate::TranslateManager>(
          this,
          prefs::kAcceptLanguages)),
      translate_driver_(web_state,
                        web_state->GetNavigationManager(),
                        translate_manager_.get()) {}

CRIWVTranslateClient::~CRIWVTranslateClient() {}

// TranslateClient implementation:

std::unique_ptr<infobars::InfoBar> CRIWVTranslateClient::CreateInfoBar(
    std::unique_ptr<translate::TranslateInfoBarDelegate> delegate) const {
  NOTREACHED();
  return nullptr;
}

void CRIWVTranslateClient::ShowTranslateUI(
    translate::TranslateStep step,
    const std::string& source_language,
    const std::string& target_language,
    translate::TranslateErrors::Type error_type,
    bool triggered_from_menu) {
  if (!delegate_)
    return;

  if (error_type != translate::TranslateErrors::NONE)
    step = translate::TRANSLATE_STEP_TRANSLATE_ERROR;

  translate_manager_->GetLanguageState().SetTranslateEnabled(true);

  if (step == translate::TRANSLATE_STEP_BEFORE_TRANSLATE &&
      !translate_manager_->GetLanguageState().HasLanguageChanged()) {
    return;
  }

  base::scoped_nsobject<CRIWVTranslateManagerImpl> criwv_manager(
      [[CRIWVTranslateManagerImpl alloc]
          initWithTranslateManager:translate_manager_.get()
                    sourceLanguage:source_language
                    targetLanguage:target_language]);

  CRIWVTransateStep criwv_step;
  switch (step) {
    case translate::TRANSLATE_STEP_BEFORE_TRANSLATE:
      criwv_step = CRIWVTransateStepBeforeTranslate;
      break;
    case translate::TRANSLATE_STEP_TRANSLATING:
      criwv_step = CRIWVTransateStepTranslating;
      break;
    case translate::TRANSLATE_STEP_AFTER_TRANSLATE:
      criwv_step = CRIWVTransateStepAfterTranslate;
      break;
    case translate::TRANSLATE_STEP_TRANSLATE_ERROR:
      criwv_step = CRIWVTransateStepError;
      break;
    case translate::TRANSLATE_STEP_NEVER_TRANSLATE:
      NOTREACHED() << "Never translate is not supported yet in web_view.";
      criwv_step = CRIWVTransateStepError;
      break;
  }
  [delegate_ translateStepChanged:criwv_step manager:criwv_manager.get()];
}

translate::TranslateDriver* CRIWVTranslateClient::GetTranslateDriver() {
  return &translate_driver_;
}

PrefService* CRIWVTranslateClient::GetPrefs() {
  DCHECK(web_state());
  return CRIWVBrowserState::FromBrowserState(web_state()->GetBrowserState())
      ->GetPrefs();
}

std::unique_ptr<translate::TranslatePrefs>
CRIWVTranslateClient::GetTranslatePrefs() {
  DCHECK(web_state());
  return base::MakeUnique<translate::TranslatePrefs>(
      GetPrefs(), prefs::kAcceptLanguages, nullptr);
}

translate::TranslateAcceptLanguages*
CRIWVTranslateClient::GetTranslateAcceptLanguages() {
  translate::TranslateAcceptLanguages* accept_languages =
      CRIWVTranslateAcceptLanguagesFactory::GetForBrowserState(
          CRIWVBrowserState::FromBrowserState(web_state()->GetBrowserState()));
  DCHECK(accept_languages);
  return accept_languages;
}

int CRIWVTranslateClient::GetInfobarIconID() const {
  NOTREACHED();
  return 0;
}

bool CRIWVTranslateClient::IsTranslatableURL(const GURL& url) {
  return !url.is_empty() && !url.SchemeIs(url::kFtpScheme);
}

void CRIWVTranslateClient::ShowReportLanguageDetectionErrorUI(
    const GURL& report_url) {
  NOTREACHED();
}

void CRIWVTranslateClient::WebStateDestroyed() {
  // Translation process can be interrupted.
  // Destroying the TranslateManager now guarantees that it never has to deal
  // with nullptr WebState.
  translate_manager_.reset();
}

}  // namespace ios_web_view
