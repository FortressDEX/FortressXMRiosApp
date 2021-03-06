//
//  WalletPicker.swift
//  MyMonero
//
//  Created by Paul Shapiro on 7/5/17.
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
import UIKit

extension UICommonComponents
{
	class WalletPickerButtonFieldView: UIView, UIGestureRecognizerDelegate
	{
		//
		static var fixedHeight: CGFloat = 66
		//
		static let visual__arrowRightPadding: CGFloat = 16
		//
		// Properties
		var tapped_fn: (() -> Void)?
		var picker_inputField_didBeginEditing: ((_ textField: UITextField) -> Void)?
		var selectionUpdated_fn: (() -> Void)?
		var selectedWallet: Wallet? // weak might be a good idea but strong should be ok here b/c we unpick the selectedWallet when wallets reloads on logged-in runtime teardown
		var pickerView: WalletPickerView!
		var picker_inputField: UITextField!

		var touchInterceptingFieldBackgroundView: UIView!
		var contentView = WalletCellContentView(
			sizeClass: .medium32,
			wantsNoSecondaryBalances: true,
			wantsOnlySpendableBalance: true // this could be changed to false for e.g. the createfundsrequestform
		)
		let accessoryChevronView = UIImageView(image: UIImage(named: "list_rightside_chevron")!)
		var separatorView: UICommonComponents.Details.FieldSeparatorView!		
		//
		// Lifecycle - Init
		init(selectedWallet: Wallet?)
		{
			super.init(frame: .zero)
//			assert(WalletsListController.shared.records.count > 0) // not actually going to assert this, b/c the Send view will need to be able to have this set up w/o any wallets being available yet
			if selectedWallet != nil {
				self.selectedWallet = selectedWallet!
			} else {
				self.selectedWallet = WalletsListController.shared.records.first as? Wallet
			}
			self.setup()
		}
		required init?(coder aDecoder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}
		func setup()
		{
			do {
				let view = UIView(frame: .zero)
				self.touchInterceptingFieldBackgroundView = view
				self.addSubview(view)
				//
				let recognizer = UITapGestureRecognizer(target: self, action: #selector(backgroundView_tapped))
				recognizer.delegate = self
				view.addGestureRecognizer(recognizer)
			}
			do {
				let view = WalletPickerView()
				view.didSelect_fn =
				{ [unowned self] (wallet) in
					self.set(
						selectedWallet: wallet,
						skipSettingOnPickerView: true // because we got this from the picker view
					)
				}
				view.reloaded_fn =
				{ [unowned self] in
					do { // reconfigure /self/ with selected wallet, not picker
						if let _ = self.selectedWallet {
							let records = WalletsListController.shared.records
							if records.count == 0 { // e.g. booted state deconstructed
								self.selectedWallet = nil
								if self.picker_inputField.isFirstResponder {
									self.picker_inputField.resignFirstResponder()
								}
								self.contentView.prepareForReuse()
								self.contentView.clearFields()
								self.selectionUpdated_fn?()
								return
							}
						} else {
//							DDLog.Info("UICommonComponents.WalletPicker", "Going to check selectedWallet no currently selected wallet")
						}
						let picker_selectedWallet = self.pickerView.selectedWallet
						if picker_selectedWallet == nil {
							self.contentView.prepareForReuse() // might as well call it even though it will have handled
							return
						}
						let selectedWallet = picker_selectedWallet!
						if self.selectedWallet == nil || self.selectedWallet! != selectedWallet {
							self.selectedWallet = selectedWallet
							self.contentView.configure(withObject: selectedWallet)
							self.selectionUpdated_fn?()
						} else {
							DDLog.Warn("UICommonComponents.WalletPicker", "reloaded but was same")
						}
					}
				}
				self.pickerView = view
			}
			self.addSubview(self.accessoryChevronView)
			do {
				let view = UICommonComponents.Details.FieldSeparatorView(
					mode: .contentBackgroundAccent_subtle
				)
				view.isUserInteractionEnabled = false // so as not to intercept touches
				self.separatorView = view
				self.addSubview(view)
			}
			do {
				let view = UITextField(frame: .zero) // invisible - and possibly wouldn't work if hidden
				view.inputView = pickerView
				self.picker_inputField = view
				self.addSubview(view)
			}
			do {
				let view = self.contentView
				view.isUserInteractionEnabled = false // pass touches through to self
				self.addSubview(view)
			}
			if self.selectedWallet != nil {
				self.configure(withRecord: self.selectedWallet!)
			}
		}
		//
		// Accessors
		//
		// Imperatives - Interactivity
		var isEnabled: Bool = true
		func set(isEnabled: Bool)
		{
			self.isEnabled = isEnabled
		}
		//
		// Imperatives - Overrides
		override func layoutSubviews()
		{
			super.layoutSubviews()
			//
			let arrow_w = self.accessoryChevronView.frame.size.width
//			let arrow_margin_left: CGFloat = 17
			let arrow_margin_right: CGFloat = 11
			let arrow_x = self.bounds.size.width - arrow_w - arrow_margin_right

			self.touchInterceptingFieldBackgroundView.frame = self.bounds
			self.contentView.frame = CGRect(
				x: 0,
				y: 0,
				width: self.bounds.size.width,
				height: self.bounds.size.height
			)
			self.accessoryChevronView.frame = CGRect(
				x: arrow_x,
				y: (self.frame.size.height - self.accessoryChevronView.frame.size.height)/2 - 2,
				width: self.accessoryChevronView.frame.size.width,
				height: self.accessoryChevronView.frame.size.height
				).integral
			//
			self.separatorView.frame = CGRect(x: 0, y: self.bounds.size.height - self.separatorView.frame.size.height, width: self.bounds.size.width, height: self.separatorView.frame.size.height)
		}
		//
		// Imperatives - Config
		func set(
			selectedWallet wallet: Wallet,
			skipSettingOnPickerView: Bool = false // leave as false if you're setting from anywhere but the PickerView
		) {
			self.selectedWallet = wallet
			self.configure(withRecord: wallet)
			if skipSettingOnPickerView == false {
				self.pickerView.selectWithoutYielding(wallet: wallet)
			}
			//
			self.selectionUpdated_fn?()
		}
		//
		func configure(withRecord record: Wallet)
		{
			self.contentView.configure(withObject: record)
		}
		//
		// Delegation - Interactions
		@objc func backgroundView_tapped()
		{
			if self.isEnabled == false {
				return
			}
			// the popover should be guaranteed not to be showing here???
			if let tapped_fn = self.tapped_fn {
				tapped_fn()
			}
			if self.picker_inputField.isFirstResponder {
				self.picker_inputField.resignFirstResponder()
			} else {
				self.picker_inputField.becomeFirstResponder()
			}
		}
		//
		// Delegation - UITextField
		func textFieldDidBeginEditing(_ textField: UITextField)
		{
			if textField == self.picker_inputField {
				self.picker_inputField_didBeginEditing?(textField)
			}
		}
	}
	//
	class WalletPickerView: UIPickerView, UIPickerViewDelegate, UIPickerViewDataSource
	{
		//
		// Constants
		static let listController = WalletsListController.shared
		static let records = listController.records // array instance never changes, but is mutated
		//
		// Properties
		var didSelect_fn: ((_ record: Wallet) -> Void)?
		var reloaded_fn: (() -> Void)?
		//
		// Lifecycle
		init()
		{
			super.init(frame: .zero)
			self.setup()
		}
		required init?(coder aDecoder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}
		func setup()
		{
			self.backgroundColor = .customKeyboardBackgroundColor
			self.delegate = self
			self.dataSource = self
			//
			self.startObserving()
		}
		func startObserving()
		{
			NotificationCenter.default.addObserver(
				self,
				selector: #selector(PersistedObjectListController_Notifications_List_updated),
				name: PersistedObjectListController.Notifications_List.updated.notificationName,
				object: WalletPickerView.listController
			)
		}
		//
		deinit
		{
			self.teardown()
		}
		func teardown()
		{
			self.stopObserving()
		}
		func stopObserving()
		{
			NotificationCenter.default.removeObserver(
				self,
				name: PersistedObjectListController.Notifications_List.updated.notificationName,
				object: WalletPickerView.listController
			)
		}
		//
		// Accessors
		var selectedWallet: Wallet? {
			let selectedIndex = self.selectedRow(inComponent: 0)
			if selectedIndex == -1 {
				return nil
			}
			let records = WalletsListController.shared.records
			if records.count <= selectedIndex {
				DDLog.Warn("UICommonComponents", "WalletPicker has non -1 selectedIndex but too few records for the selectedIndex to be correct. Returning nil.")
				return nil
			}
			return records[selectedIndex] as? Wallet
		}
		//
		// Imperatives - Interface - Setting wallet externally
		func selectWithoutYielding(wallet: Wallet)
		{
			let row = WalletsListController.shared.records.index(of: wallet)!
			self.selectRow(row, inComponent: 0, animated: false) // not pickWallet(atRow:) b/c that will merely notify
		}
		//
		// Delegation - Yielding
		func didPickWallet(atRow row: Int)
		{
			let record = WalletsListController.shared.records[row] as! Wallet
			if let fn = self.didSelect_fn {
				fn(record)
			}
		}
		//
		// Delegation - UIPickerView
		func numberOfComponents(in pickerView: UIPickerView) -> Int
		{
			return 1
		}
		func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int
		{
			return WalletsListController.shared.records.count
		}
		func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat
		{
			return WalletPickerButtonFieldView.fixedHeight - 6 // i dunno where the 6 is coming from
		}
		func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int)
		{
			self.didPickWallet(atRow: row)
		}
		func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat
		{
			let safeAreaInsets = pickerView.polyfilled_safeAreaInsets
			let w = pickerView.frame.size.width - safeAreaInsets.left - safeAreaInsets.right - 2*CGFloat.form_input_margin_x
			//
			return w
		}
		func pickerView(
			_ pickerView: UIPickerView,
			viewForRow row: Int,
			forComponent component: Int,
			reusing view: UIView?
		) -> UIView {
			var mutable_view: UIView? = view
			if mutable_view == nil {
				mutable_view = WalletCellContentView(
					sizeClass: .medium32,
					wantsNoSecondaryBalances: true,
					wantsOnlySpendableBalance: true // this could be changed to false for e.g. the createfundsrequestform
				)
			}
			let cellView = mutable_view as! WalletCellContentView
			let record = WalletsListController.shared.records[row] as! Wallet
			cellView.configure(withObject: record)
			//
			return cellView
		}
		//
		// Delegation - Notifications
		@objc func PersistedObjectListController_Notifications_List_updated()
		{
			self.reloadAllComponents()
			//
			DispatchQueue.main.async
			{ [weak self] in // give components time to reload - reloaded_fn might trigger access to them
				guard let thisSelf = self else {
					return
				}
				if let fn = thisSelf.reloaded_fn {
					fn()
				}
			}
		}
	}
}
