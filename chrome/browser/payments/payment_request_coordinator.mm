// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/payments/payment_request_coordinator.h"

#include <unordered_set>
#include <vector>

#import "base/ios/weak_nsobject.h"
#include "base/mac/objc_property_releaser.h"
#include "base/mac/scoped_nsobject.h"
#include "base/strings/sys_string_conversions.h"
#include "base/strings/utf_string_conversions.h"
#include "components/autofill/core/browser/autofill_data_util.h"
#include "components/autofill/core/browser/autofill_profile.h"
#include "components/autofill/core/browser/credit_card.h"
#include "components/autofill/core/browser/field_types.h"
#include "components/autofill/core/browser/personal_data_manager.h"
#include "ios/chrome/browser/application_context.h"
#include "ios/chrome/browser/payments/payment_request.h"
#include "ios/chrome/browser/payments/payment_request_util.h"

@interface PaymentRequestCoordinator () {
  base::WeakNSProtocol<id<PaymentRequestCoordinatorDelegate>> _delegate;
  base::scoped_nsobject<UINavigationController> _navigationController;
  base::scoped_nsobject<PaymentRequestViewController> _viewController;
  base::scoped_nsobject<PaymentItemsDisplayCoordinator>
      _itemsDisplayCoordinator;
  base::scoped_nsobject<ShippingAddressSelectionCoordinator>
      _shippingAddressSelectionCoordinator;
  base::scoped_nsobject<ShippingOptionSelectionCoordinator>
      _shippingOptionSelectionCoordinator;
  base::scoped_nsobject<PaymentMethodSelectionCoordinator>
      _methodSelectionCoordinator;

  base::mac::ObjCPropertyReleaser _propertyReleaser_PaymentRequestCoordinator;
}

@end

@implementation PaymentRequestCoordinator {
  // The selected shipping address, pending approval from the page.
  autofill::AutofillProfile* _pendingShippingAddress;
}

@synthesize paymentRequest = _paymentRequest;
@synthesize pageFavicon = _pageFavicon;
@synthesize pageTitle = _pageTitle;
@synthesize pageHost = _pageHost;

- (instancetype)initWithBaseViewController:
    (UIViewController*)baseViewController {
  if ((self = [super initWithBaseViewController:baseViewController])) {
    _propertyReleaser_PaymentRequestCoordinator.Init(
        self, [PaymentRequestCoordinator class]);
  }
  return self;
}

- (id<PaymentRequestCoordinatorDelegate>)delegate {
  return _delegate.get();
}

- (void)setDelegate:(id<PaymentRequestCoordinatorDelegate>)delegate {
  _delegate.reset(delegate);
}

- (void)start {
  _viewController.reset([[PaymentRequestViewController alloc]
      initWithPaymentRequest:_paymentRequest]);
  [_viewController setPageFavicon:_pageFavicon];
  [_viewController setPageTitle:_pageTitle];
  [_viewController setPageHost:_pageHost];
  [_viewController setDelegate:self];
  [_viewController loadModel];

  _navigationController.reset([[UINavigationController alloc]
      initWithRootViewController:_viewController]);
  [_navigationController setNavigationBarHidden:YES];

  [[self baseViewController] presentViewController:_navigationController
                                          animated:YES
                                        completion:nil];
}

- (void)stop {
  [[_navigationController presentingViewController]
      dismissViewControllerAnimated:YES
                         completion:nil];
  _itemsDisplayCoordinator.reset();
  _shippingAddressSelectionCoordinator.reset();
  _shippingOptionSelectionCoordinator.reset();
  _methodSelectionCoordinator.reset();
  _navigationController.reset();
  _viewController.reset();
}

- (void)sendPaymentResponse {
  DCHECK(_paymentRequest->selected_credit_card());
  autofill::CreditCard* selectedCreditCard =
      _paymentRequest->selected_credit_card();

  // TODO(crbug.com/602666): Unmask if this is a server card and/or ask the user
  //   for CVC here.
  // TODO(crbug.com/602666): Record the use of this card with the
  //   PersonalDataManager.
  web::PaymentResponse paymentResponse;
  paymentResponse.details.cardholder_name =
      selectedCreditCard->GetRawInfo(autofill::CREDIT_CARD_NAME_FULL);
  paymentResponse.details.card_number =
      selectedCreditCard->GetRawInfo(autofill::CREDIT_CARD_NUMBER);
  paymentResponse.details.expiry_month =
      selectedCreditCard->GetRawInfo(autofill::CREDIT_CARD_EXP_MONTH);
  paymentResponse.details.expiry_year =
      selectedCreditCard->GetRawInfo(autofill::CREDIT_CARD_EXP_4_DIGIT_YEAR);
  paymentResponse.details.card_security_code =
      selectedCreditCard->GetRawInfo(autofill::CREDIT_CARD_VERIFICATION_CODE);
  if (!selectedCreditCard->billing_address_id().empty()) {
    autofill::AutofillProfile* address =
        autofill::PersonalDataManager::GetProfileFromProfilesByGUID(
            selectedCreditCard->billing_address_id(),
            _paymentRequest->billing_profiles());
    if (address) {
      paymentResponse.details.billing_address =
          payment_request_util::PaymentAddressFromAutofillProfile(address);
    }
  }

  [_delegate paymentRequestCoordinator:self
         didConfirmWithPaymentResponse:paymentResponse];
}

- (void)updatePaymentDetails:(web::PaymentDetails)paymentDetails {
  BOOL totalValueChanged =
      (_paymentRequest->payment_details().total != paymentDetails.total);
  _paymentRequest->set_payment_details(paymentDetails);

  if (!paymentDetails.error.empty()) {
    // Display error in the shipping address/option selection view.
    if (_shippingAddressSelectionCoordinator) {
      _paymentRequest->set_selected_shipping_profile(nil);
      [_shippingAddressSelectionCoordinator stopSpinnerAndDisplayError];
    } else if (_shippingOptionSelectionCoordinator) {
      [_shippingOptionSelectionCoordinator stopSpinnerAndDisplayError];
    }
    // Update the payment request summary view.
    [_viewController loadModel];
    [[_viewController collectionView] reloadData];
  } else {
    // Update the payment summary section.
    [_viewController
        updatePaymentSummaryWithTotalValueChanged:totalValueChanged];

    if (_shippingAddressSelectionCoordinator) {
      // Set the selected shipping address and update the selected shipping
      // address in the payment request summary view.
      _paymentRequest->set_selected_shipping_profile(_pendingShippingAddress);
      _pendingShippingAddress = nil;
      [_viewController updateSelectedShippingAddressUI];

      // Dismiss the shipping address selection view.
      [_shippingAddressSelectionCoordinator stop];
      _shippingAddressSelectionCoordinator.reset();
    } else if (_shippingOptionSelectionCoordinator) {
      // Update the selected shipping option in the payment request summary
      // view. The updated selection is already reflected in |_paymentRequest|.
      [_viewController updateSelectedShippingOptionUI];

      // Dismiss the shipping option selection view.
      [_shippingOptionSelectionCoordinator stop];
      _shippingOptionSelectionCoordinator.reset();
    }
  }
}

#pragma mark - PaymentRequestViewControllerDelegate

- (void)paymentRequestViewControllerDidCancel:
    (PaymentRequestViewController*)controller {
  [_delegate paymentRequestCoordinatorDidCancel:self];
}

- (void)paymentRequestViewControllerDidConfirm:
    (PaymentRequestViewController*)controller {
  [self sendPaymentResponse];
}

- (void)paymentRequestViewControllerDidSelectPaymentSummaryItem:
    (PaymentRequestViewController*)controller {
  _itemsDisplayCoordinator.reset([[PaymentItemsDisplayCoordinator alloc]
      initWithBaseViewController:_viewController]);
  [_itemsDisplayCoordinator setPaymentRequest:_paymentRequest];
  [_itemsDisplayCoordinator setDelegate:self];

  [_itemsDisplayCoordinator start];
}

- (void)paymentRequestViewControllerDidSelectShippingAddressItem:
    (PaymentRequestViewController*)controller {
  _shippingAddressSelectionCoordinator.reset(
      [[ShippingAddressSelectionCoordinator alloc]
          initWithBaseViewController:_viewController]);
  [_shippingAddressSelectionCoordinator setPaymentRequest:_paymentRequest];
  [_shippingAddressSelectionCoordinator setDelegate:self];

  [_shippingAddressSelectionCoordinator start];
}

- (void)paymentRequestViewControllerDidSelectShippingOptionItem:
    (PaymentRequestViewController*)controller {
  _shippingOptionSelectionCoordinator.reset(
      [[ShippingOptionSelectionCoordinator alloc]
          initWithBaseViewController:_viewController]);
  [_shippingOptionSelectionCoordinator setPaymentRequest:_paymentRequest];
  [_shippingOptionSelectionCoordinator setDelegate:self];

  [_shippingOptionSelectionCoordinator start];
}

- (void)paymentRequestViewControllerDidSelectPaymentMethodItem:
    (PaymentRequestViewController*)controller {
  _methodSelectionCoordinator.reset([[PaymentMethodSelectionCoordinator alloc]
      initWithBaseViewController:_viewController]);
  [_methodSelectionCoordinator setPaymentRequest:_paymentRequest];
  [_methodSelectionCoordinator setDelegate:self];

  [_methodSelectionCoordinator start];
}

#pragma mark - PaymentItemsDisplayCoordinatorDelegate

- (void)paymentItemsDisplayCoordinatorDidReturn:
    (PaymentItemsDisplayCoordinator*)coordinator {
  // Clear the 'Updated' label on the payment summary item, if there is one.
  [_viewController updatePaymentSummaryWithTotalValueChanged:NO];

  [_itemsDisplayCoordinator stop];
  _itemsDisplayCoordinator.reset();
}

- (void)paymentItemsDisplayCoordinatorDidConfirm:
    (PaymentItemsDisplayCoordinator*)coordinator {
  [self sendPaymentResponse];
}

#pragma mark - ShippingAddressSelectionCoordinatorDelegate

- (void)shippingAddressSelectionCoordinator:
            (ShippingAddressSelectionCoordinator*)coordinator
                   didSelectShippingAddress:
                       (autofill::AutofillProfile*)shippingAddress {
  _pendingShippingAddress = shippingAddress;

  web::PaymentAddress address =
      payment_request_util::PaymentAddressFromAutofillProfile(shippingAddress);
  [_delegate paymentRequestCoordinator:self didSelectShippingAddress:address];
}

- (void)shippingAddressSelectionCoordinatorDidReturn:
    (ShippingAddressSelectionCoordinator*)coordinator {
  // Clear the 'Updated' label on the payment summary item, if there is one.
  [_viewController updatePaymentSummaryWithTotalValueChanged:NO];

  [_shippingAddressSelectionCoordinator stop];
  _shippingAddressSelectionCoordinator.reset();
}

#pragma mark - ShippingOptionSelectionCoordinatorDelegate

- (void)shippingOptionSelectionCoordinator:
            (ShippingOptionSelectionCoordinator*)coordinator
                   didSelectShippingOption:
                       (web::PaymentShippingOption*)shippingOption {
  [_delegate paymentRequestCoordinator:self
               didSelectShippingOption:*shippingOption];
}

- (void)shippingOptionSelectionCoordinatorDidReturn:
    (ShippingAddressSelectionCoordinator*)coordinator {
  // Clear the 'Updated' label on the payment summary item, if there is one.
  [_viewController updatePaymentSummaryWithTotalValueChanged:NO];

  [_shippingOptionSelectionCoordinator stop];
  _shippingOptionSelectionCoordinator.reset();
}

#pragma mark - PaymentMethodSelectionCoordinatorDelegate

- (void)paymentMethodSelectionCoordinator:
            (PaymentMethodSelectionCoordinator*)coordinator
                   didSelectPaymentMethod:(autofill::CreditCard*)creditCard {
  _paymentRequest->set_selected_credit_card(creditCard);

  [_viewController updateSelectedPaymentMethodUI];

  // Clear the 'Updated' label on the payment summary item, if there is one.
  [_viewController updatePaymentSummaryWithTotalValueChanged:NO];

  [_methodSelectionCoordinator stop];
  _methodSelectionCoordinator.reset();
}

- (void)paymentMethodSelectionCoordinatorDidReturn:
    (PaymentMethodSelectionCoordinator*)coordinator {
  // Clear the 'Updated' label on the payment summary item, if there is one.
  [_viewController updatePaymentSummaryWithTotalValueChanged:NO];

  [_methodSelectionCoordinator stop];
  _methodSelectionCoordinator.reset();
}

@end
