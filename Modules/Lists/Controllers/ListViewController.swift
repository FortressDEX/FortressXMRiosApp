//
//  ListViewController.swift
//  MyMonero
//
//  Created by Paul Shapiro on 5/19/17.
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
//
class ListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
	//
	// Properties
	var tableView: UITableView!
	var listController: PersistedObjectListController!
	//
	// Lifecycle - Init
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
	{
		fatalError("\(#function) has not been implemented")
	}
	required init?(coder aDecoder: NSCoder)
	{
		fatalError("\(#function) has not been implemented")
	}
	init(withListController listController: PersistedObjectListController)
	{
		super.init(nibName: nil, bundle: nil)
		self.listController = listController
		self.setup()
	}
	func setup()
	{
		self.setup_views()
		do {
			self.configure_navigation_title()
			self.configure_navigation_barButtonItems()
		}
		self.startObserving()
	}
	func setup_views()
	{
		self.view.backgroundColor = .contentBackgroundColor
		//
		self.setup_tableView()
		//
		self.configure_emptyStateView()
	}
	func setup_tableView()
	{
		let view = UITableView()
		view.delegate = self
		view.dataSource = self
		view.backgroundColor = .contentBackgroundColor
		view.indicatorStyle = .white // TODO: configure via theme controller
		self.tableView = view
		self.view.addSubview(tableView)
		do { // to fix apparent visual bug of vertical transit on nav push/pop
			self.automaticallyAdjustsScrollViewInsets = false
			if #available(iOS 11.0, *) {
				view.contentInsetAdjustmentBehavior = .never
			}
		}
	}
	func startObserving()
	{
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(PersistedObjectListController_Notifications_List_updated),
			name: PersistedObjectListController.Notifications_List.updated.notificationName,
			object: self.listController
		)
	}
	//
	// Lifecycle - Deinit
	deinit
	{
		self.stopObserving()
	}
	func stopObserving()
	{
		NotificationCenter.default.removeObserver(
			self,
			name: PersistedObjectListController.Notifications_List.updated.notificationName,
			object: self.listController
		)
	}
	//
	// Accessors - Required
	func new_navigationTitle() -> String
	{
		assert(false, "required")
		return ""
	}
	//
	// Accessors - Overridable - Optional
	func new_emptyStateView() -> UIView?
	{
		return nil
	}
	//
	// Imperatives
	func configure_navigation_title()
	{
		self.navigationItem.title = self.new_navigationTitle() // mustn't set self.title or it will also set tabBarItem title
	}
	func configure_navigation_barButtonItems()
	{
	}
	var _emptyStateView: UIView?
	func configure_emptyStateView()
	{
		let shouldShow = self.listController.records.count == 0 // TODO: fix this so it refreshes after app is unlocked: PasswordController.shared.hasUserSavedAPassword == false || (PasswordController.shared.hasUserEnteredValidPasswordYet && self.listController.records.count == 0)
		if shouldShow {
			if self._emptyStateView == nil {
				self._emptyStateView = self.new_emptyStateView()
				if self._emptyStateView != nil {
					self.view.addSubview(self._emptyStateView!)
				}
			}
		} else {
			if self._emptyStateView != nil {
				self._emptyStateView!.removeFromSuperview()
				self._emptyStateView = nil
			}
		}

	}
	//
	// Protocol - Table View - Accessors & Delegation
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
	{
		assert(false, "required")
		return UITableViewCell()
	}
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
	{
		assert(false, "required")
		return 0
	}
	func numberOfSections(in tableView: UITableView) -> Int
	{
		return 1
	}
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
	{
		return self.listController.records.count
	}
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
	{
		tableView.deselectRow(at: indexPath, animated: true)
	}
	//
	// Delegation - Layout
	override func viewDidLayoutSubviews()
	{
		super.viewDidLayoutSubviews()
		//
		let safeAreaInsets = self.view.polyfilled_safeAreaInsets
		let contentViewFrame = self.view.bounds.inset(by: safeAreaInsets)
		self.tableView.frame = contentViewFrame
		if let view = self._emptyStateView {
			view.frame = contentViewFrame
		}
	}
	//
	// Delegation - Notifications
	@objc func PersistedObjectListController_Notifications_List_updated()
	{
		self.configure_navigation_title()
		self.configure_navigation_barButtonItems()
		//
		self.configure_emptyStateView()
		self.tableView.reloadData()
	}
	//
	// Delegation - View lifecycle
	override func viewWillAppear(_ animated: Bool)
	{
		super.viewWillAppear(animated)
		ThemeController.shared.styleViewController_navigationBarTitleTextAttributes(
			viewController: self,
			titleTextColor: nil // default
		) // to support clearing potential red clr transactions details on popping to self
	}
}
