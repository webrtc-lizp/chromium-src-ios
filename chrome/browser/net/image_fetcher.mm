// Copyright 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/net/image_fetcher.h"

#import <Foundation/Foundation.h>

#include "base/bind.h"
#include "base/compiler_specific.h"
#include "base/location.h"
#include "base/logging.h"
#include "base/mac/scoped_block.h"
#include "base/memory/scoped_ptr.h"
#include "base/task_runner_util.h"
#include "base/threading/sequenced_worker_pool.h"
#include "ios/web/public/webp_decoder.h"
#include "net/base/load_flags.h"
#include "net/http/http_response_headers.h"
#include "net/url_request/url_fetcher.h"
#include "url/gurl.h"

namespace {

class WebpDecoderDelegate : public web::WebpDecoder::Delegate {
 public:
  NSData* data() const { return decoded_image_; }

  // WebpDecoder::Delegate methods
  void OnFinishedDecoding(bool success) override {
    if (!success)
      decoded_image_.reset();
  }
  void SetImageFeatures(
      size_t total_size,
      web::WebpDecoder::DecodedImageFormat format) override {
    decoded_image_.reset([[NSMutableData alloc] initWithCapacity:total_size]);
  }
  void OnDataDecoded(NSData* data) override {
    DCHECK(decoded_image_);
    [decoded_image_ appendData:data];
  }
 private:
  ~WebpDecoderDelegate() override {}
  base::scoped_nsobject<NSMutableData> decoded_image_;
};

// Returns a NSData object containing the decoded image.
// Returns nil in case of failure.
base::scoped_nsobject<NSData> DecodeWebpImage(
    const base::scoped_nsobject<NSData>& webp_image) {
  scoped_refptr<WebpDecoderDelegate> delegate(new WebpDecoderDelegate);
  scoped_refptr<web::WebpDecoder> decoder(new web::WebpDecoder(delegate.get()));
  decoder->OnDataReceived(webp_image);
  DLOG_IF(ERROR, !delegate->data()) << "WebP image decoding failed.";
  return base::scoped_nsobject<NSData>([delegate->data() retain]);
}

}  // namespace

namespace image_fetcher {

ImageFetcher::ImageFetcher(
    const scoped_refptr<base::SequencedWorkerPool> decoding_pool)
    : request_context_getter_(nullptr),
      weak_factory_(this),
      decoding_pool_(decoding_pool) {
  DCHECK(decoding_pool_.get());
}

ImageFetcher::~ImageFetcher() {
  // Delete all the entries in the |downloads_in_progress_| map.  This will in
  // turn cancel all of the requests.
  for (std::map<const net::URLFetcher*, Callback>::iterator it =
           downloads_in_progress_.begin();
       it != downloads_in_progress_.end(); ++it) {
    [it->second release];
    delete it->first;
  }
}

void ImageFetcher::StartDownload(
    const GURL& url,
    Callback callback,
    const std::string& referrer,
    net::URLRequest::ReferrerPolicy referrer_policy) {
  DCHECK(request_context_getter_.get());
  net::URLFetcher* fetcher = net::URLFetcher::Create(url,
                                                     net::URLFetcher::GET,
                                                     this);
  downloads_in_progress_[fetcher] = [callback copy];
  fetcher->SetLoadFlags(
      net::LOAD_DO_NOT_SEND_COOKIES | net::LOAD_DO_NOT_SAVE_COOKIES);
  fetcher->SetRequestContext(request_context_getter_.get());
  fetcher->SetReferrer(referrer);
  fetcher->SetReferrerPolicy(referrer_policy);
  fetcher->Start();
}

void ImageFetcher::StartDownload(const GURL& url, Callback callback) {
  ImageFetcher::StartDownload(
      url, callback, "", net::URLRequest::NEVER_CLEAR_REFERRER);
}

// Delegate callback that is called when URLFetcher completes.  If the image
// was fetched successfully, creates a new NSData and returns it to the
// callback, otherwise returns nil to the callback.
void ImageFetcher::OnURLFetchComplete(const net::URLFetcher* fetcher) {
  if (downloads_in_progress_.find(fetcher) == downloads_in_progress_.end()) {
    LOG(ERROR) << "Received callback for unknown URLFetcher " << fetcher;
    return;
  }

  // Ensures that |fetcher| will be deleted even if we return early.
  scoped_ptr<const net::URLFetcher> fetcher_deleter(fetcher);

  // Retrieves the callback and ensures that it will be deleted even if we
  // return early.
  base::mac::ScopedBlock<Callback> callback(downloads_in_progress_[fetcher]);

  // Remove |fetcher| from the map.
  downloads_in_progress_.erase(fetcher);

  // Make sure the request was successful. For "data" requests, the response
  // code has no meaning, because there is no actual server (data is encoded
  // directly in the URL). In that case, we set the response code to 200.
  const GURL& original_url = fetcher->GetOriginalURL();
  const int http_response_code = original_url.SchemeIs("data") ?
      200 : fetcher->GetResponseCode();
  if (http_response_code != 200) {
    (callback.get())(original_url, http_response_code, nil);
    return;
  }

  std::string response;
  if (!fetcher->GetResponseAsString(&response)) {
    (callback.get())(original_url, http_response_code, nil);
    return;
  }

  // Create a NSData from the returned data and notify the callback.
  base::scoped_nsobject<NSData> data([[NSData alloc]
      initWithBytes:reinterpret_cast<const unsigned char*>(response.data())
             length:response.size()]);

  if (fetcher->GetResponseHeaders()) {
    std::string mime_type;
    fetcher->GetResponseHeaders()->GetMimeType(&mime_type);
    if (mime_type == "image/webp") {
      base::PostTaskAndReplyWithResult(decoding_pool_.get(),
                                       FROM_HERE,
                                       base::Bind(&DecodeWebpImage, data),
                                       base::Bind(&ImageFetcher::RunCallback,
                                                  weak_factory_.GetWeakPtr(),
                                                  callback,
                                                  original_url,
                                                  http_response_code));
      return;
    }
  }
  (callback.get())(original_url, http_response_code, data);
}

void ImageFetcher::RunCallback(const base::mac::ScopedBlock<Callback>& callback,
                               const GURL& url,
                               int http_response_code,
                               NSData* data) {
  (callback.get())(url, http_response_code, data);
}

void ImageFetcher::SetRequestContextGetter(
    net::URLRequestContextGetter* request_context_getter) {
  request_context_getter_ = request_context_getter;
}

}  // namespace image_fetcher
