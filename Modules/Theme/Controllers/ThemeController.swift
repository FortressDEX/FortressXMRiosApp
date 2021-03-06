//
//  ThemeController.swift
//  MyMonero
//
//  Created by Paul Shapiro on 6/3/17.
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
import PKHUD
import AMPopTip
//
class ThemeController
{
	enum ThemeMode
	{
		case dark
	}
	var mode: ThemeMode = .dark
	//
	static let shared = ThemeController()
	private init() // private due to singleton init
	{
		self.setup()
	}
	func setup()
	{
		self.configureWithMode()
	}
	//
	func configureWithMode()
	{
		self.configureAppearance()
	}
	func configureAppearance()
	{
		UINavigationBar.appearance().tintColor = UIColor.utilityOrConstructiveLinkColor
		//
		self.configureAppearance_navigationBar()
		self.configureAppearance_PKHUD()
		self.configureAppearance_keyboard()
	}
	func configureAppearance_navigationBar()
	{
		let appearance = UINavigationBar.appearance()
		appearance.barTintColor = UIColor.contentBackgroundColor
		appearance.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
		appearance.isTranslucent = false // when this is set to false, if a view wants its extended layout to include .top, it must say its extendedLayoutIncludesOpaqueBars - TODO: possible to deprecate this for future proofing w/o too-significant UI overhaul?
		appearance.titleTextAttributes =
		[
			NSAttributedString.Key.font: UIFont.navigationBarBoldSansSerif,
			NSAttributedString.Key.foregroundColor: UIColor.normalNavigationBarTitleColor
		]
		if UIFont.shouldStepDownLargerFontSizes {
			UINavigationBar.appearance().setTitleVerticalPositionAdjustment(-2, for: .default) // b/c font is smaller, need to align w/nav buttons
		}
		appearance.shadowImage = UIImage() // remove shadow - would be good to place shadow back on view's scroll (may do manually)
	}
	func configureAppearance_PKHUD()
	{
		PKHUD.sharedHUD.dimsBackground = false // debatable
		PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false // ofc
	}
	func configureAppearance_keyboard()
	{
		// this is configured on a per-component basis to avoid stepping on the background color theming of the picker presented as the .inputView of the WalletPicker inputField   
	}
	//
	// Imperatives - Convenience
	func styleViewController_navigationBarTitleTextAttributes(
		viewController: UIViewController,
		titleTextColor: UIColor? // nil to reset
	) {
		if viewController.navigationController == nil {
			DDLog.Warn("Theme", "Asked to \(#function) for viewController \(viewController.debugDescription) but viewController.navigationController=nil.")
			return
		}
		let navigationBar = viewController.navigationController!.navigationBar
		navigationBar.titleTextAttributes =
		[
			NSAttributedString.Key.font: UIFont.navigationBarBoldSansSerif,
			NSAttributedString.Key.foregroundColor: titleTextColor ?? UIColor.normalNavigationBarTitleColor
		]

	}
}
//
extension CGFloat
{
	static let visual__form_input_margin_x: CGFloat = 24
	static let form_input_margin_x: CGFloat = visual__form_input_margin_x - UICommonComponents.FormInputCells.imagePadding_x
	//
	static let form_label_margin_x: CGFloat = 33
	static let form_labelAccessoryLabel_margin_x = visual__form_input_margin_x
}
//
extension UIColor
{ // This is a place to use app-wide, oft-repeated colors - rather than colors which can be encapsulated within e.g. singular components (for their specific semantic or use-cases).
	// Once we add multiple themes, switch by ThemeController.shared.mode
	static var contentBackgroundColor: UIColor
	{
		return UIColor(rgb: 0x272527)
	}
	static var customKeyboardBackgroundColor: UIColor
	{
		return UIColor(rgb: 0x212021)
	}
	static var contentTextColor: UIColor
	{
		return UIColor(rgb: 0x9E9C9E)
	}
	//
	static var standaloneValidationTextOrDestructiveLinkContentColor: UIColor
	{
		return UIColor(red: 249.0/255.0, green: 119.0/255.0, blue: 119.0/255.0, alpha: 1)
//		return UIColor(rgb: 0xF97777)
	}
	static var utilityOrConstructiveLinkColor: UIColor
	{
		return UIColor(rgb: 0x00C6FF)
	}
	static var disabledLinkColor: UIColor
	{
		return UIColor(rgb: 0xD4D4D4)
	}
	static var disabledAndSemiVisibleLinkColor: UIColor
	{
		return UIColor(red: 73/255, green: 71/255, blue: 73/255, alpha: 40)
	}
	//
	static var normalNavigationBarTitleColor: UIColor
	{
		return UIColor.white
	}
	//
	//
	static var systemStandard_navigationBar_tintColor: UIColor {
		return UIColor.normalNavigationBarTitleColor
	}
}
//
extension UIFont
{
	//
	// Monospace - "Native"
	static var lightMonospaceFontName: String {
		return "Native-Light"
	}
	static var regularMonospaceFontName: String {
		return "Native-Regular"
	}
	static var boldMonospaceFontName: String {
		return "Native-Bold"
	}
	//
	static var smallLightMonospace: UIFont
	{
		return UIFont(name: self.lightMonospaceFontName, size: 13)!
	}
	static var smallRegularMonospace: UIFont
	{
		return UIFont(name: self.regularMonospaceFontName, size: 13)!
	}
	static var smallBoldMonospace: UIFont
	{
		return UIFont(name: self.boldMonospaceFontName, size: 13)!
	}
	static var middlingLightMonospace: UIFont
	{
		return UIFont(name: self.lightMonospaceFontName, size: 15)!
	}
	static var middlingRegularMonospace: UIFont
	{
		return UIFont(name: self.regularMonospaceFontName, size: 15)!
	}
	static var subMiddlingRegularMonospace: UIFont
	{ // still not 100% sold on this??? it's not in the mds MVP design
		return UIFont(name: self.regularMonospaceFontName, size: 14)!
	}
	static var subMiddlingBoldMonospace: UIFont
	{ // still not 100% sold on this??? it's not in the mds MVP design
		return UIFont(name: self.boldMonospaceFontName, size: 14)!
	}
	static var middlingBoldMonospace: UIFont
	{
		return UIFont(name: self.boldMonospaceFontName, size: 15)!
	}
	//
	// Sans Serif - (systemFont should be "San Francisco")
	static var smallRegularSansSerif: UIFont
	{
		return UIFont.systemFont(ofSize: 13, weight: UIFont.Weight.regular)
	}
	static var smallSemiboldSansSerif: UIFont
	{
		return UIFont.systemFont(ofSize: 13, weight: UIFont.Weight.semibold)
	}
	static var smallMediumSansSerif: UIFont
	{
		return UIFont.systemFont(ofSize: 13, weight: UIFont.Weight.medium)
	}
	static var smallBoldSansSerif: UIFont
	{
		return UIFont.systemFont(ofSize: 13, weight: UIFont.Weight.bold)
	}
	static var middlingBoldSansSerif: UIFont
	{
		return UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.bold)
	}
	static var middlingMediumSansSerif: UIFont
	{
		return UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.medium)
	}
	static var middlingSemiboldSansSerif: UIFont
	{
		return UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.semibold)
	}
	static var middlingRegularSansSerif: UIFont
	{
		return UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.regular)
	}
	static var middlingButtonContentSemiboldSansSerif: UIFont
	{
		return UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.semibold)
	}
	static var navigationBarBoldSansSerif: UIFont
	{
		let size: CGFloat = UIFont.shouldStepDownLargerFontSizes ? 15 : 17 
		return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.bold)
	}
	static var largeSemiboldSansSerif: UIFont
	{
		return UIFont.systemFont(ofSize: 17, weight: UIFont.Weight.semibold)
	}
	static var largeMediumSansSerif: UIFont
	{
		return UIFont.systemFont(ofSize: 17, weight: UIFont.Weight.medium)
	}
	static var largeRegularSansSerif: UIFont
	{
		return UIFont.systemFont(ofSize: 17, weight: UIFont.Weight.regular)
	}
	static var keyboardContentSemiboldSansSerif: UIFont
	{
		return UIFont.largeSemiboldSansSerif
	}
	//
	static var shouldStepDownLargerFontSizes: Bool {
		return UIScreen.main.bounds.size.width <= 320
	}
}
