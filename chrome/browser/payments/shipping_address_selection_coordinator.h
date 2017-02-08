// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_PAYMENTS_SHIPPING_ADDRESS_SELECTION_COORDINATOR_H_
#define IOS_CHROME_BROWSER_PAYMENTS_SHIPPING_ADDRESS_SELECTION_COORDINATOR_H_

#import <UIKit/UIKit.h>
#include <vector>

#import "ios/chrome/browser/chrome_coordinator.h"
#include "ios/chrome/browser/payments/payment_request.h"

namespace autofill {
class AutofillProfile;
}  // namespace autofill

@class ShippingAddressSelectionCoordinator;

// Delegate protocol for ShippingAddressSelectionCoordinator.
@protocol ShippingAddressSelectionCoordinatorDelegate<NSObject>

// Notifies the delegate that the user has selected a shipping address.
- (void)shippingAddressSelectionCoordinator:
            (ShippingAddressSelectionCoordinator*)coordinator
                   didSelectShippingAddress:
                       (autofill::AutofillProfile*)shippingAddress;

// Notifies the delegate that the user has chosen to return to the previous
// screen without making a selection.
- (void)shippingAddressSelectionCoordinatorDidReturn:
    (ShippingAddressSelectionCoordinator*)coordinator;

@end

// Coordinator responsible for creating and presenting the shipping address
// selection view controller. This view controller will be presented by the view
// controller provided in the initializer.
@interface ShippingAddressSelectionCoordinator : ChromeCoordinator

// The PaymentRequest object owning an instance of web::PaymentRequest as
// provided by the page invoking the Payment Request API. This pointer is not
// owned by this class and should outlive it.
@property(nonatomic, assign) PaymentRequest* paymentRequest;

// The delegate to be notified when the user selects a shipping address or
// returns without selecting one.
@property(nonatomic, weak) id<ShippingAddressSelectionCoordinatorDelegate>
    delegate;

@end

#endif  // IOS_CHROME_BROWSER_PAYMENTS_SHIPPING_ADDRESS_SELECTION_COORDINATOR_H_
