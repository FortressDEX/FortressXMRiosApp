//
//  Wallet_HostPollingController.swift
//  MyMonero
//
//  Created by Paul Shapiro on 5/26/17.
//  Copyright (c) 2014-2019, MyMonero.com
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are
//  permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice, this list of
//	conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice, this list
//	of conditions and the following disclaimer in the documentation and/or other
//	materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors may be
//	used to endorse or promote products derived from this software without specific
//	prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
//  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
//  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
//  THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//
import Foundation
//
class Wallet_HostPollingController
{
	//
	// Properties - Internal
	weak var wallet: Wallet? // prevent retain cycle since wallet owns self
	var didUpdate_factorOf_isFetchingAnyUpdates_fn: (() -> Void)!
	//
	var timer: Timer!
	//
	var requestHandleFor_addressInfo: HostedMonero.APIClient.RequestHandle?
	var requestHandleFor_addressTransactions: HostedMonero.APIClient.RequestHandle?
	//
	// Lifecycle - Init
	init(
		wallet: Wallet,
		didUpdate_factorOf_isFetchingAnyUpdates_fn: (() -> Void)?
	) {
		self.wallet = wallet
		self.didUpdate_factorOf_isFetchingAnyUpdates_fn = didUpdate_factorOf_isFetchingAnyUpdates_fn
		self.setup()
	}
	func setup()
	{
		self.startPollingTimer()
		// ^ just immediately going to jump into the runtime - so only instantiate self when you're ready to do this
		//
		self.performRequests()
	}
	//
	// Lifecycle - Teardown
	deinit
	{
		self.tearDown()
	}
	func tearDown()
	{
		self.invalidateTimer()
		do {
			if let requestHandle = self.requestHandleFor_addressInfo {
				requestHandle.cancel()
				self.requestHandleFor_addressInfo = nil
			}
			if let requestHandle = self.requestHandleFor_addressTransactions {
				requestHandle.cancel()
				self.requestHandleFor_addressTransactions = nil
			}
		}
		self._didUpdate_factorOf_isFetchingAnyUpdates() // unsure if emitting is desired here but it probably isn't harmful
		self.didUpdate_factorOf_isFetchingAnyUpdates_fn = nil
		//
		self.wallet = nil
	}
	//
	// Accessors
	var isFetchingAnyUpdates: Bool {
		return self.requestHandleFor_addressInfo != nil || self.requestHandleFor_addressTransactions != nil
	}
	static let manualRefreshCoolDownMinimumTimeInterval: TimeInterval = 10
	static let pollingTimerPeriod: TimeInterval = 30
	//
	// Imperatives - Timer
	func startPollingTimer()
	{
		self.timer = Timer.scheduledTimer(withTimeInterval: Wallet_HostPollingController.pollingTimerPeriod, repeats: true, block: { [weak self] (timer) in
			guard let thisSelf = self else {
				return
			}
			thisSelf.__timerFired()
		})
	}
	func invalidateTimer()
	{
		self.timer.invalidate()
		self.timer = nil
	}
	//
	// Imperatives - Requests
	func performRequests()
	{
		self._fetch_addressInfo()
		self._fetch_addressTransactions()
	}
	var _dateOfLast_fetch_addressInfo: Date?
	func _fetch_addressInfo()
	{
		if self.requestHandleFor_addressInfo != nil {
			DDLog.Warn("Wallets", "_fetch_addressInfo called but request already exists")
			return
		}
		guard let wallet = self.wallet else {
			return
		}
		if wallet.isLoggedIn != true {
			DDLog.Error("Wallets", "Unable to do request while not isLoggedIn")
			return
		}
		if wallet.public_address == nil || wallet.public_address == "" {
			DDLog.Error("Wallets", "Unable to do request for wallet w/o public_address")
			return
		}
		if wallet.private_keys == nil {
			DDLog.Error("Wallets", "Unable to do request for wallet w/o private_keys")
			return
		}
		self.requestHandleFor_addressInfo = HostedMonero.APIClient.shared.AddressInfo(
			wallet_keyImageCache: wallet.keyImageCache,
			address: wallet.public_address,
			view_key__private: wallet.private_keys.view,
			spend_key__public: wallet.public_keys.spend,
			spend_key__private: wallet.private_keys.spend,
			{ [weak self] (err_str, parsedResult) in
				guard let thisSelf = self else {
					DDLog.Warn("Wallets.Wallet_HostPollingController", "self already nil")
					return
				}
				if thisSelf.requestHandleFor_addressInfo == nil {
					assert(false, "Already canceled")
					return
				}
				thisSelf._dateOfLast_fetch_addressInfo = Date()
				thisSelf.requestHandleFor_addressInfo = nil // first/immediately unlock this request fetch
				thisSelf._didUpdate_factorOf_isFetchingAnyUpdates()
				//
				if err_str != nil {
					return // already logged err
				}
				guard let wallet = thisSelf.wallet else {
					DDLog.Warn("Wallets", "Wallet host polling request response returned but wallet already freed.")
					return
				}
				wallet._HostPollingController_didFetch_addressInfo(parsedResult!)
			}
		)
		self._didUpdate_factorOf_isFetchingAnyUpdates()
	}
	var _dateOfLast_fetch_addressTransactions: Date?
	func _fetch_addressTransactions()
	{
		if self.requestHandleFor_addressTransactions != nil {
			DDLog.Warn("Wallets", "_fetch_addressInfo called but request already exists")
			return
		}
		guard let wallet = self.wallet else {
			return
		}
		if wallet.isLoggedIn != true {
			DDLog.Error("Wallets", "Unable to do request while not isLoggedIn")
			return
		}
		if wallet.public_address == nil || wallet.public_address == "" {
			DDLog.Error("Wallets", "Unable to do request for wallet w/o public_address")
			return
		}
		if wallet.private_keys == nil {
			DDLog.Error("Wallets", "Unable to do request for wallet w/o private_keys")
			return
		}
		self.requestHandleFor_addressTransactions = HostedMonero.APIClient.shared.AddressTransactions(
			wallet_keyImageCache: wallet.keyImageCache,
			address: wallet.public_address,
			view_key__private: wallet.private_keys.view,
			spend_key__public: wallet.public_keys.spend,
			spend_key__private: wallet.private_keys.spend,
			{ [weak self] (err_str, parsedResult) in
				guard let thisSelf = self else {
					DDLog.Warn("Wallets.Wallet_HostPollingController", "self already nil")
					return
				}
				if thisSelf.requestHandleFor_addressTransactions == nil {
					assert(false, "Already canceled")
					return
				}
				thisSelf._dateOfLast_fetch_addressTransactions = Date()
				thisSelf.requestHandleFor_addressTransactions = nil // first/immediately unlock this request fetch
				thisSelf._didUpdate_factorOf_isFetchingAnyUpdates()
				//
				if err_str != nil {
					return // already logged err
				}
				guard let wallet = thisSelf.wallet else {
					DDLog.Warn("Wallets", "Wallet host polling request response returned but wallet already freed.")
					return
				}
				wallet._HostPollingController_didFetch_addressTransactions(parsedResult!)
			}
		)
		self._didUpdate_factorOf_isFetchingAnyUpdates()
	}
	//
	// Imperatives - Manual refresh
	func requestFromUI_manualRefresh()
	{
		if self.requestHandleFor_addressInfo != nil || self.requestHandleFor_addressTransactions != nil {
			return // still refreshing.. no need
		}
		// now since addressInfo and addressTransactions are nearly happening at the same time (with failures and delays unlikely), I'm just going to use time since addressTransactions to approximate length since last collective refresh
		let hasBeenLongEnoughSinceLastRefreshToRefresh: Bool = self._dateOfLast_fetch_addressTransactions == nil /* we know a request is not _currently_ happening, so nil date means one has never happened */
			|| abs(self._dateOfLast_fetch_addressTransactions!.timeIntervalSinceNow/*negative*/) >= Wallet_HostPollingController.manualRefreshCoolDownMinimumTimeInterval
		if hasBeenLongEnoughSinceLastRefreshToRefresh {
			// and here we again know we don't have any requests to cancel
			self.performRequests() // approved manual refresh
			//
			self.invalidateTimer() // clear and reset timer to push next fresh out by timer period
			self.startPollingTimer()
		}
	}
	//
	// Delegation - isFetchingAnyUpdates
	var lastRecorded_isFetchingAnyUpdates: Bool?
	func _didUpdate_factorOf_isFetchingAnyUpdates() // must be called manually
	{
		let previous_lastRecorded_isFetchingAnyUpdates: Bool? = self.lastRecorded_isFetchingAnyUpdates
		let current_isFetchingAnyUpdates = self.isFetchingAnyUpdates
		self.lastRecorded_isFetchingAnyUpdates = current_isFetchingAnyUpdates
		if previous_lastRecorded_isFetchingAnyUpdates == nil
			|| previous_lastRecorded_isFetchingAnyUpdates != current_isFetchingAnyUpdates
		{ // Emit
			self.didUpdate_factorOf_isFetchingAnyUpdates_fn()
		}
	}
	//
	// Delegation - Polling
	@objc func __timerFired()
	{
		self.performRequests()
	}
}
