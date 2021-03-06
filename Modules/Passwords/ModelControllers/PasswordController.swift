//
//  PasswordController.swift
//  MyMonero
//
//  Created by Paul Shapiro on 5/22/17.
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
import RNCryptor
import LocalAuthentication
//
//
protocol PasswordControllerEventParticipant: class
{
	func identifier() -> String // To support isEqual
}
func isEqual(_ l: PasswordControllerEventParticipant, _ r: PasswordControllerEventParticipant) -> Bool
{
	return l.identifier() == r.identifier()
}
//
// TODO: namespace within Passwords
protocol DeleteEverythingRegistrant: PasswordControllerEventParticipant
{
	func passwordController_DeleteEverything() -> String? // return err_str:String if error. at time of writing, this was able to be kept synchronous.
}
struct WeakRefTo_DeleteEverythingRegistrant
{
	weak var value: DeleteEverythingRegistrant?
}
func isEqual(
	_ l: WeakRefTo_DeleteEverythingRegistrant,
	_ r: WeakRefTo_DeleteEverythingRegistrant
) -> Bool {
	if l.value == nil && r.value == nil {
		return true
	}
	return l.value?.identifier() == r.value?.identifier()
}
//
protocol ChangePasswordRegistrant: PasswordControllerEventParticipant
{
	// Implement this function to support change-password events as well as revert-from-failed-change-password
	func passwordController_ChangePassword() -> String? // return err_str:String if error - it will abort and try to revert the changepassword process. at time of writing, this was able to be kept synchronous.
}
struct WeakRefTo_ChangePasswordRegistrant
{
	weak var value: ChangePasswordRegistrant?
}
func isEqual(
	_ l: WeakRefTo_ChangePasswordRegistrant,
	_ r: WeakRefTo_ChangePasswordRegistrant
) -> Bool {
	if l.value == nil && r.value == nil {
		return true
	}
	return l.value?.identifier() == r.value?.identifier()
}
//
//
protocol PasswordEntryDelegate
{
	func getUserToEnterExistingPassword(
		isForChangePassword: Bool,
		isForAuthorizingAppActionOnly: Bool, // normally no - this is for things like SendFunds
		customNavigationBarTitle: String?,
		_ enterExistingPassword_cb: @escaping (
			_ didCancel_orNil: Bool?,
			_ obtainedPasswordString: PasswordController.Password?
		) -> Void
	)
	func getUserToEnterNewPasswordAndType(
		isForChangePassword: Bool,
		_ enterNewPasswordAndType_cb: @escaping (
			_ didCancel_orNil: Bool?,
			_ obtainedPasswordString: PasswordController.Password?,
			_ passwordType: PasswordController.PasswordType?
		) -> Void
	)
	//
	// To support isEqual
	func identifier() -> String
}
func isEqual(_ l: PasswordEntryDelegate, _ r: PasswordEntryDelegate) -> Bool
{
	return l.identifier() == r.identifier()
}
//
final class PasswordController
{
	// Types/Constants
	typealias Password = String
	enum PasswordType: String
	{
		case PIN = "PIN" // 6-digit numerical PIN/code
		case password = "password" // free-form, string password
		var humanReadableString: String { // TODO: return localized
			return self.rawValue
		}
		var incorrectEntry_humanReadableString: String {
			switch self {
				case .PIN:
					return NSLocalizedString("Incorrect PIN", comment: "")
				case .password:
					return NSLocalizedString("Incorrect password", comment: "")
			}
		}
		var capitalized_humanReadableString: String
		{ // this is done instead of calling .capitalize as that will convert the remainder to lowercase characters
			let string = self.humanReadableString
			let capitalizingFirstLetter = string.prefix(1).capitalized
			let remainder = string.dropFirst()
			return capitalizingFirstLetter + remainder
		}
		static func new(detectedFromPassword password: Password) -> PasswordType
		{
			let numbers = CharacterSet(charactersIn: "0123456789")
			if password.trimmingCharacters(in: numbers) == "" { // and contains only numbers
				return .PIN
			}
			return .password
		}
	}
	let collectionName = "PasswordMeta"
	let plaintextMessageToSaveForUnlockChallenges = "this is just a string that we'll use for checking whether a given password can unlock an encrypted version of this very message"
	enum DictKey: String
	{
		case _id = "_id"
		case passwordType = "passwordType"
		case messageAsEncryptedDataForUnlockChallenge_base64String = "messageAsEncryptedDataForUnlockChallenge_base64String"
	}
	enum NotificationNames: String
	{
		case setFirstPasswordDuringThisRuntime = "PasswordController_NotificationNames_SetFirstPasswordDuringThisRuntime"
		case registrantsAllChangedPassword = "PasswordController_NotificationNames_registrantsAllChangedPassword" // not really used anymore - never use for critical things
		//
		case obtainedNewPassword = "PasswordController_Runtime_NotificationNames_ObtainedNewPassword"
		case obtainedCorrectExistingPassword = "PasswordController_Runtime_NotificationNames_ObtainedCorrectExistingPassword"
		//
		case erroredWhileSettingNewPassword = "PasswordController_Runtime_NotificationNames_ErroredWhileSettingNewPassword"
		case erroredWhileGettingExistingPassword = "PasswordController_Runtime_NotificationNames_ErroredWhileGettingExistingPassword"
		case canceledWhileEnteringExistingPassword = "PasswordController_Runtime_NotificationNames_canceledWhileEnteringExistingPassword"
		case canceledWhileEnteringNewPassword = "PasswordController_Runtime_NotificationNames_canceledWhileEnteringNewPassword"
		//
		case canceledWhileChangingPassword = "PasswordController_Runtime_NotificationNames_canceledWhileChangingPassword"
		case errorWhileChangingPassword = "PasswordController_Runtime_NotificationNames_errorWhileChangingPassword"
		//
		case errorWhileAuthorizingForAppAction = "PasswordController_Runtime_NotificationNames_errorWhileAuthorizingForAppAction"
		case successfullyAuthenticatedForAppAction = "PasswordController_Runtime_NotificationNames_successfullyAuthenticatedForAppAction"
		//
		case willDeconstructBootedStateAndClearPassword = "PasswordController_Runtime_NotificationNames_willDeconstructBootedStateAndClearPassword"
		case didDeconstructBootedStateAndClearPassword = "PasswordController_Runtime_NotificationNames_didDeconstructBootedStateAndClearPassword"
		case havingDeletedEverything_didDeconstructBootedStateAndClearPassword = "PasswordController_Runtime_NotificationNames_havingDeletedEverything_didDeconstructBootedStateAndClearPassword"
		//
		var notificationName: NSNotification.Name { return NSNotification.Name(self.rawValue) }
	}
	enum Notification_UserInfo_Keys: String
	{
		case err_str = "err_str"
		case isForADeleteEverything = "isForADeleteEverything"
	}
	//
	// Properties
	var hasBooted = false
	var _id: DocumentPersister.DocumentId?
	var password: Password?
	var passwordType: PasswordType! // it will default to .password per init
	var hasUserSavedAPassword: Bool { // this obviously has a file I/O hit, which is not optimal; alternatives are use sparingly or cache at appropriate locations
		let (err_str, ids) = DocumentPersister.shared.IdsOfAllDocuments(inCollectionNamed: self.collectionName)
		if err_str != nil {
			DDLog.Error("Passwords", ".hasUserSavedAPassword: \(err_str!)")
			assert(false)
			return false
		}
		let numberOfIds = ids!.count
		if numberOfIds > 1 {
			assert(false, "Illegal: Should be only one document")
			return false
		} else if numberOfIds == 0 {
			return false
		}
		return true
	}
	var messageAsEncryptedDataForUnlockChallenge_base64String: String?
	var isAlreadyGettingExistingOrNewPWFromUser: Bool?
	private var passwordEntryDelegate: PasswordEntryDelegate? // someone in the app must set this by calling setPasswordEntryDelegate(to:); TODO: would we like this to be weak?
	func setPasswordEntryDelegate(to delegate: PasswordEntryDelegate)
	{
		if self.passwordEntryDelegate != nil {
			assert(false, "\(#function) called but self.passwordEntryDelegate already exists")
		}
		self.passwordEntryDelegate = delegate
	}
	func clearPasswordEntryDelegate(from existing_delegate: PasswordEntryDelegate)
	{
		if self.passwordEntryDelegate == nil {
			assert(false, "\(#function) called but no passwordEntryDelegate exists")
		}
		if isEqual(self.passwordEntryDelegate!, existing_delegate) == false {
			assert(false, "\(#function) called but passwordEntryDelegate does not match")
		}
		self.passwordEntryDelegate = nil
	}
	//
	// Lifecycle - Singleton Init
	static let shared = PasswordController()
	private init()
	{
		self.setup()
	}
	func setup()
	{
		self.startObserving_userIdle()
		self.initializeRuntimeAndBoot()
	}
	func startObserving_userIdle()
	{
		NotificationCenter.default.addObserver(self, selector: #selector(UserIdle_userDidBecomeIdle), name: UserIdle.NotificationNames.userDidBecomeIdle.notificationName, object: nil)
	}
	func initializeRuntimeAndBoot()
	{
		assert(self.hasBooted == false, "\(#function) called while already booted")
		let (err_str, documentJSONs) = DocumentPersister.shared.AllDocuments(
			inCollectionNamed: self.collectionName
		)
		if err_str != nil {
			DDLog.Error("Passwords", "Fatal error while loading \(self.collectionName): \(err_str!)")
			assert(false)
			return
		}
		let documentJSONs_count = documentJSONs!.count
		if documentJSONs_count > 1 {
			DDLog.Error("Passwords", "Unexpected state while loading \(self.collectionName): more than one saved doc.")
			assert(false)
			return
		}
		func _proceedTo_load(documentJSON: DocumentPersister.DocumentJSON)
		{
			self._id = documentJSON[DictKey._id.rawValue] as? DocumentPersister.DocumentId
			let passwordType_rawValue = documentJSON[DictKey.passwordType.rawValue] as? String ?? PasswordType.password.rawValue
			self.passwordType = PasswordType(rawValue: passwordType_rawValue)
			self.messageAsEncryptedDataForUnlockChallenge_base64String = documentJSON[DictKey.messageAsEncryptedDataForUnlockChallenge_base64String.rawValue] as? String
			if self._id != nil { // existing doc
				if self.messageAsEncryptedDataForUnlockChallenge_base64String == nil || self.messageAsEncryptedDataForUnlockChallenge_base64String == "" {
					// ^-- but it was saved w/o an encrypted challenge str
					// TODO: not sure how to handle this case. delete all local info? would suck but otoh when would this happen if not for a cracking attempt, some odd/fatal code fault, or a known migration?
					let err_str = "Found undefined encrypted msg for unlock challenge in saved password model document"
					DDLog.Error("Passwords", "\(err_str)")
					return
				}
			}
			//
			self.hasBooted = true
			self._callAndFlushAllBlocksWaitingForBootToExecute()
//			DDLog.Done("Passwords", "Booted \(self) and called all waiting blocks. Waiting for unlock.")
		}
		if documentJSONs_count == 0 {
			let fabricated_documentJSON =
			[
				DictKey.passwordType.rawValue: PasswordType.password // default (at least for now)
			]
			_proceedTo_load(documentJSON: fabricated_documentJSON)
			return
		}
		let documentJSON = documentJSONs![0]
		_proceedTo_load(documentJSON: documentJSON)
	}
	//
	// Accessors - Runtime - Derived properties
	var hasUserEnteredValidPasswordYet: Bool {
		return self.password != nil
	}
	var isUserChangingPassword: Bool {
		return self.hasUserEnteredValidPasswordYet == true && self.isAlreadyGettingExistingOrNewPWFromUser == true
	}
	var new_incorrectPasswordValidationErrorMessageString: String {
		return self.passwordType!.incorrectEntry_humanReadableString
	}
	//
	// Accessors - Common
	fileprivate func withExistingPassword_isCorrect(enteredPassword: String) -> Bool
	{ // NOTE: This function should most likely remain fileprivate so that it is not cheap to check PW and must be done through the PW entry UI (by way of methods on PasswordController)
		//
		// FIXME/TODO: is this check too weak? is it better to try decrypt and check hmac mismatch?
		//
		return self.password! == enteredPassword // force unwrap self.password so it cannot be equal to a nil passed as arg despite present method sig decl
	}
	//
	// Accessors - Deferring execution convenience methods
	func OnceBootedAndPasswordObtained(
		_ fn: @escaping (_ password: Password, _ passwordType: PasswordType) -> Void,
		_ userCanceled_fn: (() -> Void)? = {}
	) {
		func callBackHavingObtainedPassword()
		{
			fn(self.password!, self.passwordType)
		}
		func callBackHavingCanceled()
		{
			userCanceled_fn!()
		}
		if self.hasUserEnteredValidPasswordYet == true {
			callBackHavingObtainedPassword()
			return
		}
		// then we have to wait for it
		var hasCalledBack = false
		var token__obtainedNewPassword: Any?
		var token__obtainedCorrectExistingPassword: Any?
		var token__canceledWhileEnteringExistingPassword: Any?
		var token__canceledWhileEnteringNewPassword: Any?
		func ___guardAllCallBacks() -> Bool
		{
			if hasCalledBack == true {
				DDLog.Error("Passwords", "PasswordController/OnceBootedAndPasswordObtained hasCalledBack already true")
				assert(false)
				return false // ^- shouldn't happen but just in case???
			}
			hasCalledBack = true
			return true
		}
		func __stopListening()
		{
			NotificationCenter.default.removeObserver(token__obtainedNewPassword!)
			NotificationCenter.default.removeObserver(token__obtainedCorrectExistingPassword!)
			NotificationCenter.default.removeObserver(token__canceledWhileEnteringExistingPassword!)
			NotificationCenter.default.removeObserver(token__canceledWhileEnteringNewPassword!)
			token__obtainedNewPassword = nil
			token__obtainedCorrectExistingPassword = nil
			token__canceledWhileEnteringExistingPassword = nil
			token__canceledWhileEnteringNewPassword = nil
		}
		func _aPasswordWasObtained()
		{
			if (___guardAllCallBacks() != false) {
				__stopListening() // immediately unsubscribe
				callBackHavingObtainedPassword()
			}
		}
		func _obtainingPasswordWasCanceled()
		{
			if (___guardAllCallBacks() != false) {
				__stopListening() // immediately unsubscribe
				callBackHavingCanceled()
			}
		}
		self.onceBooted({ [unowned self] in
			// hang onto tokens so we can unsub
			token__obtainedNewPassword = NotificationCenter.default.addObserver(
				forName: NotificationNames.obtainedNewPassword.notificationName,
				object: self,
				queue: OperationQueue.main,
				using:
				{ (notification) in
					_aPasswordWasObtained()
				}
			)
			token__obtainedCorrectExistingPassword = NotificationCenter.default.addObserver(
				forName: NotificationNames.obtainedCorrectExistingPassword.notificationName,
				object: self,
				queue: OperationQueue.main,
				using:
				{ (notification) in
					_aPasswordWasObtained()
				}
			)
			token__canceledWhileEnteringExistingPassword = NotificationCenter.default.addObserver(
				forName: NotificationNames.canceledWhileEnteringExistingPassword.notificationName,
				object: self,
				queue: OperationQueue.main,
				using:
				{ (notification) in
					_obtainingPasswordWasCanceled()
				}
			)
			token__canceledWhileEnteringNewPassword = NotificationCenter.default.addObserver(
				forName: NotificationNames.canceledWhileEnteringNewPassword.notificationName,
				object: self,
				queue: OperationQueue.main,
				using:
				{ (notification) in
					_obtainingPasswordWasCanceled()
				}
			)
			// now that we're subscribed, initiate the pw request
			self.givenBooted_initiateGetNewOrExistingPasswordFromUserAndEmitIt()
		})
	}
	func givenBooted_initiateGetNewOrExistingPasswordFromUserAndEmitIt()
	{
		if self.hasUserEnteredValidPasswordYet == true {
			DDLog.Warn("Passwords", "\(#function) asked to givenBooted_initiateGetNewOrExistingPasswordFromUserAndEmitIt but already has password.")
			return // already got it
		}
		do { // guard
			if self.isAlreadyGettingExistingOrNewPWFromUser == true {
				return // only need to wait for it to be obtained
			}
			self.isAlreadyGettingExistingOrNewPWFromUser = true
		}
		// we'll use this in a couple places
		let isForChangePassword = false // this is simply for requesting to have the existing or a new password from the user
		let isForAuthorizingAppActionOnly = false // "
		//
		if self._id == nil { // if the user is not unlocking an already pw-protected app
			// then we need to get a new PW from the user
			self.obtainNewPasswordFromUser( // this will also call self.unguard_getNewOrExistingPassword()
				isForChangePassword: isForChangePassword
			)
			return
		} else { // then we need to get the existing PW and check it against the encrypted message
			//
			if self.messageAsEncryptedDataForUnlockChallenge_base64String == nil {
				let err_str = "Code fault: Existing document but no messageAsEncryptedDataForUnlockChallenge_base64String"
				DDLog.Error("Passwords", "\(err_str)")
				self.unguard_getNewOrExistingPassword()
				assert(false, err_str)
				return
			}
			self._getUserToEnterTheirExistingPassword(
				isForChangePassword: isForChangePassword,
				isForAuthorizingAppActionOnly: isForAuthorizingAppActionOnly // false
			) { [unowned self] (didCancel_orNil, validationErr_orNil, obtainedPasswordString) in
				if validationErr_orNil != nil { // takes precedence over cancel
					self.unguard_getNewOrExistingPassword()
					NotificationCenter.default.post(
						name: NotificationNames.erroredWhileGettingExistingPassword.notificationName,
						object: self,
						userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: validationErr_orNil! ]
					)
					return
				}
				if didCancel_orNil == true {
					NotificationCenter.default.post(
						name: NotificationNames.canceledWhileEnteringExistingPassword.notificationName,
						object: self
					)
					self.unguard_getNewOrExistingPassword()
					return // just silently exit after unguarding
				}
				let encrypted_data = Data(base64Encoded: self.messageAsEncryptedDataForUnlockChallenge_base64String!)!
				var plaintext_data: Data?
				do {
					plaintext_data = try RNCryptor.decrypt(
						data: encrypted_data,
						withPassword: obtainedPasswordString!
					)
				} catch let e {
					self.unguard_getNewOrExistingPassword()
					DDLog.Error("Passwords", "Error while decrypting message for unlock challenge: \(e) \(e.localizedDescription)")
					let err_str = self.new_incorrectPasswordValidationErrorMessageString
					NotificationCenter.default.post(
						name: NotificationNames.erroredWhileGettingExistingPassword.notificationName,
						object: self,
						userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: err_str ]
					)
					return
				}
				let decryptedMessageForUnlockChallenge = String(data: plaintext_data!, encoding: .utf8)
				if decryptedMessageForUnlockChallenge != self.plaintextMessageToSaveForUnlockChallenges {
					self.unguard_getNewOrExistingPassword()
					let err_str = self.new_incorrectPasswordValidationErrorMessageString
					NotificationCenter.default.post(
						name: NotificationNames.erroredWhileGettingExistingPassword.notificationName,
						object: self,
						userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: err_str ]
					)
					return
				}
				// then it's correct
				// hang onto pw and set state
				self._didObtainPassword(password: obtainedPasswordString!)
				// all done
				self.unguard_getNewOrExistingPassword()
				NotificationCenter.default.post(
					name: NotificationNames.obtainedCorrectExistingPassword.notificationName,
					object: self
				)
			}
		}
	}
	//
	// Runtime - Imperatives - Password change
	var weakRefsTo_changePasswordRegistrants: [WeakRefTo_ChangePasswordRegistrant] = []
	func addRegistrantForChangePassword(
		_ registrant: ChangePasswordRegistrant
	) -> Void {
		//		DDLog.Info("Passwords", "Adding registrant for 'ChangePassword': \(registrant)")
		self.weakRefsTo_changePasswordRegistrants.append(
			WeakRefTo_ChangePasswordRegistrant(value: registrant)
		)
	}
	func removeRegistrantForChangePassword(
		_ registrant: ChangePasswordRegistrant
	) -> Void {
		var index: Int?
		for (this_index, this_weakRefTo_registrant) in self.weakRefsTo_changePasswordRegistrants.enumerated() {
			if this_weakRefTo_registrant.value == nil {
				continue // skip - has dealloced somewhere
			}
			if isEqual(registrant, this_weakRefTo_registrant.value!) {
				index = this_index
				break
			}
		}
		if index == nil {
			assert(false, "registrant is not registered")
			return
		}
		DDLog.Info("Passwords", "Removing registrant for 'ChangePassword': \(registrant)")
		self.weakRefsTo_changePasswordRegistrants.remove(at: index!)
	}
	func initiate_changePassword()
	{
		self.onceBooted
		{ [unowned self] in
			if self.hasUserEnteredValidPasswordYet == false {
				let err_etr = "initiate_changePassword called but hasUserEnteredValidPasswordYet == false. This should be disallowed in the UI"
				assert(false, err_etr)
				return
			}
			do { // guard
				if self.isAlreadyGettingExistingOrNewPWFromUser == true {
					let err_str = "initiate_changePassword called but isAlreadyGettingExistingOrNewPWFromUser == true. This should be precluded in the UI"
					assert(false, err_str)
					// only need to wait for it to be obtained
					return
				}
				self.isAlreadyGettingExistingOrNewPWFromUser = true
			}
			// ^-- we're relying on having checked above that user has entered a valid pw already
			let isForChangePassword = true // we'll use this in a couple places
			self._getUserToEnterTheirExistingPassword(
				isForChangePassword: isForChangePassword,
				isForAuthorizingAppActionOnly: false,
				{ [unowned self] (didCancel_orNil, validationErr_orNil, entered_existingPassword) in
					if validationErr_orNil != nil { // takes precedence over cancel
						self.unguard_getNewOrExistingPassword()
						NotificationCenter.default.post(
							name: NotificationNames.errorWhileChangingPassword.notificationName,
							object: self,
							userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: validationErr_orNil! ]
						)
						return
					}
					if didCancel_orNil == true {
						self.unguard_getNewOrExistingPassword()
						NotificationCenter.default.post(
							name: NotificationNames.canceledWhileChangingPassword.notificationName,
							object: self
						)
						return // just silently exit after unguarding
					}
					let isGoodEnteredPassword = self.withExistingPassword_isCorrect(
						enteredPassword: entered_existingPassword!
					)
					if isGoodEnteredPassword == false {
						self.unguard_getNewOrExistingPassword()
						let err_str = self.new_incorrectPasswordValidationErrorMessageString
						NotificationCenter.default.post(
							name: NotificationNames.errorWhileChangingPassword.notificationName,
							object: self,
							userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: err_str ]
						)
						return
					}
					// passwords match checked as necessary, we can proceed
					self.obtainNewPasswordFromUser(
						isForChangePassword: isForChangePassword
					)
				}
			)
		}
	}
	//
	// Runtime - Imperatives - Password verification
	func initiate_verifyUserAuthenticationForAction(
		customNavigationBarTitle: String? = nil,
		canceled_fn: (() -> Void)?, // NOTE: this compiles b/c optional closures are treated as @escaping
		entryAttempt_succeeded_fn: @escaping (() -> Void) // required
	) {
		self.onceBooted
		{ [unowned self] in
			if self.hasUserEnteredValidPasswordYet == false {
				let err_etr = "initiate_verifyUserAuthenticationForAction called but hasUserEnteredValidPasswordYet == false. This should be disallowed in the UI"
				assert(false, err_etr)
				return
			}
			do { // guard
				if self.isAlreadyGettingExistingOrNewPWFromUser == true {
					let err_str = "initiate_changePassword called but isAlreadyGettingExistingOrNewPWFromUser == true. This should be precluded in the UI"
					assert(false, err_str)
					// only need to wait for it to be obtained
					return
				}
				self.isAlreadyGettingExistingOrNewPWFromUser = true
			}
			// ^-- we're relying on having checked above that user has entered a valid pw already
			func _proceedTo_verifyVia_passphrase()
			{
				self._getUserToEnterTheirExistingPassword(
					isForChangePassword: false,
					isForAuthorizingAppActionOnly: true,
					customNavigationBarTitle: customNavigationBarTitle,
					{ [unowned self] (didCancel_orNil, validationErr_orNil, entered_existingPassword) in
						if validationErr_orNil != nil { // takes precedence over cancel
							self.unguard_getNewOrExistingPassword()
							NotificationCenter.default.post(
								name: NotificationNames.errorWhileAuthorizingForAppAction.notificationName,
								object: self,
								userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: validationErr_orNil! ]
							)
							return
						}
						if didCancel_orNil == true {
							self.unguard_getNewOrExistingPassword()
							//
							// currently there's no need of a .canceledWhileAuthorizingForAppAction note post here
							canceled_fn?() // but must call cb
							//
							return // just silently exit after unguarding
						}
						let isGoodEnteredPassword = self.withExistingPassword_isCorrect(
							enteredPassword: entered_existingPassword!
						)
						if isGoodEnteredPassword == false {
							self.unguard_getNewOrExistingPassword()
							let err_str = self.new_incorrectPasswordValidationErrorMessageString
							NotificationCenter.default.post(
								name: NotificationNames.errorWhileAuthorizingForAppAction.notificationName,
								object: self,
								userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: err_str ]
							)
							return
						}
						//
						self.unguard_getNewOrExistingPassword() // must be called
						NotificationCenter.default.post( // this must be posted so the PresentationController can dismiss the entry modal
							name: NotificationNames.successfullyAuthenticatedForAppAction.notificationName,
							object: self
						)
						entryAttempt_succeeded_fn()
					}
				)
			}
			let tryBiometrics = SettingsController.shared.authentication__tryBiometric
			// now see if we can use biometrics
			if tryBiometrics == false {
				_proceedTo_verifyVia_passphrase()
				return // so we don't have to wrap the whole following branch in an if
			}
			if #available(iOS 8.0, macOS 10.12.1, *) {
				func _handle(receivedLAError error: NSError)
				{
					let code = LAError.Code(rawValue: error.code)!
					switch code {
						case .biometryNotEnrolled, // this case, go straight to pw
							 .biometryNotAvailable, // straight to pw
							 .biometryLockout, // this case, because we want to present a fallback method plus the cancel button
							 .authenticationFailed, // is including this correct?
							 .passcodeNotSet, // go straight to pw?
							 .notInteractive,
							 .userFallback
							:
							_proceedTo_verifyVia_passphrase()
							break
						// compiler says these will never be executed, that a default won't either, /and/ that switch must be exhaustive. so, opted to just enumerate the cases here to retain compiler check for exhaustiveness
						case .touchIDNotEnrolled,
							 .touchIDNotAvailable,
							 .touchIDLockout: // this case, because we want to present a fallback method plus the cancel button
							_proceedTo_verifyVia_passphrase()
							break
						case .systemCancel,
							 .appCancel,
							 .userCancel:
							self.unguard_getNewOrExistingPassword() // must be called at function terminus
							canceled_fn?()
							break
						case .invalidContext: // error.. fatal?
							fatalError("LAContext passed to this call has been previously invalidated.")
							break
					}
				}
				let laContext = LAContext()
				let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics
				var authError: NSError?
				if laContext.canEvaluatePolicy(policy, error: &authError) {
					let reason_localizedString = NSLocalizedString(customNavigationBarTitle ?? "Authenticate to allow MyMonero to perform this action.", comment: "")
					laContext.evaluatePolicy(policy, localizedReason: reason_localizedString)
					{ [weak self] (success, evaluateError) in
						guard let thisSelf = self else {
							return
						}
						func ___proceed()
						{
							if success {
								thisSelf.unguard_getNewOrExistingPassword() // must be called at function terminus
								entryAttempt_succeeded_fn() // consider this an authentication
							} else { // User did not authenticate successfully
								_handle(receivedLAError: evaluateError! as NSError)
							}
						}
						if Thread.isMainThread == false { // has a tendency to call back on a bg thread
							DispatchQueue.main.async {
								___proceed()
							}
						} else {
							___proceed()
						}
					}
				} else { // Could not evaluate policy
					_handle(receivedLAError: authError!)
					return
				}
			} else {
				_proceedTo_verifyVia_passphrase()
			}
		}
	}
	//
	// Runtime - Imperatives - Private - Requesting password from user
	func unguard_getNewOrExistingPassword()
	{
		self.isAlreadyGettingExistingOrNewPWFromUser = false
	}
	func _getUserToEnterTheirExistingPassword(
		isForChangePassword: Bool,
		isForAuthorizingAppActionOnly: Bool,
		customNavigationBarTitle: String? = nil,
		_ fn: @escaping (
			_ didCancel_orNil: Bool?,
			_ validationErr_orNil: String?,
			_ obtainedPasswordString: Password?
		) -> Void
	) {
		var _isCurrentlyLockedOut: Bool = false
		var _unlockTimer: Timer?
		var _numberOfTriesDuringThisTimePeriod: Int = 0
		var _dateOf_firstPWTryDuringThisTimePeriod: Date? = Date() // initialized to current time
		func __cancelAnyAndRebuildUnlockTimer()
		{
			let wasAlreadyLockedOut = _unlockTimer != nil
			if _unlockTimer != nil {
				// DDLog.Info("Passwords", "clearing existing unlock timer")
				_unlockTimer!.invalidate()
				_unlockTimer = nil // not strictly necessary
			}
			let unlockInT_s: TimeInterval = 10.0 // allows them to try again every T sec, but resets timer if they submit w/o waiting
			DDLog.Info("Passwords", "???? Too many password entry attempts within \(unlockInT_s)s. \(!wasAlreadyLockedOut ? "Locking out" : "Extending lockout.").")
			_unlockTimer = Timer.scheduledTimer(
				withTimeInterval: unlockInT_s,
				repeats: false,
				block:
				{ timer in
					DDLog.Info("Passwords", "??????  Unlocking password entry.")
					_isCurrentlyLockedOut = false
					fn(nil, "", nil) // this is _sort_ of a hack and should be made more explicit in API but I'm sending an empty string, and not even an err_str, to clear the validation error so the user knows to try again
				}
			)
		}
		assert(isForChangePassword == false || isForAuthorizingAppActionOnly == false) // both shouldn't be true
		// Now put request out
		self.passwordEntryDelegate!.getUserToEnterExistingPassword(
			isForChangePassword: isForChangePassword,
			isForAuthorizingAppActionOnly: isForAuthorizingAppActionOnly,
			customNavigationBarTitle: customNavigationBarTitle
		) { (didCancel_orNil, obtainedPasswordString) in
			var validationErr_orNil: String? = nil // so far???
			if didCancel_orNil != true { // so user did NOT cancel
				// user did not cancel??? let's check if we need to send back a pre-emptive validation err (such as because they're trying too much)
				if _isCurrentlyLockedOut == false {
					if _numberOfTriesDuringThisTimePeriod == 0 {
						_dateOf_firstPWTryDuringThisTimePeriod = Date()
					}
					_numberOfTriesDuringThisTimePeriod += 1
					let maxLegal_numberOfTriesDuringThisTimePeriod = 5
					if (_numberOfTriesDuringThisTimePeriod > maxLegal_numberOfTriesDuringThisTimePeriod) { // rhs must be > 0
						_numberOfTriesDuringThisTimePeriod = 0
						// ^- no matter what, we're going to need to reset the above state for the next 'time period'
						//
						let s_since_firstPWTryDuringThisTimePeriod = Date().timeIntervalSince(_dateOf_firstPWTryDuringThisTimePeriod!)
						let noMoreThanNTriesWithin_s = TimeInterval(30)
						if (s_since_firstPWTryDuringThisTimePeriod > noMoreThanNTriesWithin_s) { // enough time has passed since this group began - only reset the "time period" with tries->0 and let this pass through as valid check
							_dateOf_firstPWTryDuringThisTimePeriod = nil // not strictly necessary to do here as we reset the number of tries during this time period to zero just above
							DDLog.Info("Passwords", "There were more than \(maxLegal_numberOfTriesDuringThisTimePeriod) password entry attempts during this time period but the last attempt was more than \(noMoreThanNTriesWithin_s)s ago, so letting this go.")
						} else { // simply too many tries!???
							// lock it out for the next time (supposing this try does not pass)
							_isCurrentlyLockedOut = true
						}
					}
				}
				if _isCurrentlyLockedOut == true { // do not try to check pw - return as validation err
					DDLog.Info("Passwords", "????  Received password entry attempt but currently locked out.")
					validationErr_orNil = NSLocalizedString("As a security precaution, please wait a few moments before trying again.", comment: "")
					// setup or extend unlock timer - NOTE: this is pretty strict - we don't strictly need to extend the timer each time to prevent spam unlocks
					__cancelAnyAndRebuildUnlockTimer()
				}
			}
			// then regardless of whether user canceled???
			fn(
				didCancel_orNil,
				validationErr_orNil,
				obtainedPasswordString
			)
		}
	}
	//
	//
	// Runtime - Imperatives - Private - Setting/changing Password
	//
	func obtainNewPasswordFromUser(isForChangePassword: Bool)
	{
		let wasFirstSetOfPasswordAtRuntime = self.hasUserEnteredValidPasswordYet == false // it's ok if we derive this here instead of in obtainNewPasswordFromUser because this fn will only be called, if setting the pw for the first time, if we have not yet accepted a valid PW yet
		// for possible revert:
		let old_password = self.password // this may be undefined
		let old_passwordType = self.passwordType
		//
		self.passwordEntryDelegate!.getUserToEnterNewPasswordAndType(isForChangePassword: isForChangePassword)
		{ [unowned self] (didCancel_orNil, obtainedPasswordString, userSelectedTypeOfPassword) in
			if didCancel_orNil == true {
				NotificationCenter.default.post(
					name: NotificationNames.canceledWhileEnteringNewPassword.notificationName,
					object: self
				)
				self.unguard_getNewOrExistingPassword()
				return // just silently exit after unguarding
			}
			//
			// I. Validate features of pw before trying and accepting
			if userSelectedTypeOfPassword == .PIN {
				if obtainedPasswordString!.count < 6 { // this is too short. get back to them with a validation err by re-entering obtainPasswordFromUser_cb
					self.unguard_getNewOrExistingPassword()
					let err_str = "Please enter a longer PIN."
					NotificationCenter.default.post(
						name: NotificationNames.erroredWhileSettingNewPassword.notificationName,
						object: self,
						userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: err_str ]
					)
					return // bail
				}
				// TODO: check if all numbers
				// TODO: check that numbers are not all just one number
			} else if userSelectedTypeOfPassword == .password {
				if obtainedPasswordString!.count < 6 { // this is too short. get back to them with a validation err by re-entering obtainPasswordFromUser_cb
					self.unguard_getNewOrExistingPassword()
					let err_str = "Please enter a longer password."
					NotificationCenter.default.post(
						name: NotificationNames.erroredWhileSettingNewPassword.notificationName,
						object: self,
						userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: err_str ]
					)
					return // bail
				}
				// TODO: check if password content too weak?
			} else { // this is weird - code fault or cracking attempt?
				self.unguard_getNewOrExistingPassword()
				let err_str = "Unrecognized password type"
				NotificationCenter.default.post(
					name: NotificationNames.erroredWhileSettingNewPassword.notificationName,
					object: self,
					userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: err_str ]
				)
				assert(false)
			}
			if isForChangePassword == true {
				if self.password == obtainedPasswordString { // they are disallowed from using change pw to enter the same pw??? despite that being convenient for dev ;)
					self.unguard_getNewOrExistingPassword()
					//
					var err_str: String!
					if userSelectedTypeOfPassword == .password {
						err_str = "Please enter a fresh password."
					} else if userSelectedTypeOfPassword == .PIN {
						err_str = "Please enter a fresh PIN."
					} else {
						err_str = "Unrecognized password type"
						assert(false)
					}
					NotificationCenter.default.post(
						name: NotificationNames.erroredWhileSettingNewPassword.notificationName,
						object: self,
						userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: err_str ]
					)
					return // bail
				}
			}
			//
			// II. hang onto new pw, pw type, and state(s)
			DDLog.Info("Passwords", "Obtained \(userSelectedTypeOfPassword!) \(obtainedPasswordString!.count) chars long")
			self._didObtainPassword(password: obtainedPasswordString!)
			self.passwordType = userSelectedTypeOfPassword!
			//
			// III. finally, save doc (and unlock on success) so we know a pw has been entered once before
			let err_str = self.saveToDisk()
			if err_str != nil {
				self.unguard_getNewOrExistingPassword()
				assert(wasFirstSetOfPasswordAtRuntime == false || self.password == nil)
				self.password = old_password // they'll have to try again - and revert to old pw rather than nil for changePassword (should be nil for first pw set)
				self.passwordType = old_passwordType
				NotificationCenter.default.post(
					name: NotificationNames.erroredWhileSettingNewPassword.notificationName,
					object: self,
					userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: err_str! ]
				)
				return
			}
			// detecting & emiting first set or handling result of change saves
			if wasFirstSetOfPasswordAtRuntime == true {
				self.unguard_getNewOrExistingPassword()
				// specific emit
				NotificationCenter.default.post(
					name: NotificationNames.setFirstPasswordDuringThisRuntime.notificationName,
					object: self
				)
				// general purpose emit
				NotificationCenter.default.post(
					name: NotificationNames.obtainedNewPassword.notificationName,
					object: self
				)
				//
				return // prevent fallthrough
			}
			// then, it's a change password
			let changePassword_err_orNil = self._changePassword_tellRegistrants_doChangePassword() // returns error
			if changePassword_err_orNil == nil { // actual success - we can return early
				self.unguard_getNewOrExistingPassword()
				//
				NotificationCenter.default.post(
					name: NotificationNames.registrantsAllChangedPassword.notificationName,
					object: self
				)
				// general purpose emit
				NotificationCenter.default.post(
					name: NotificationNames.obtainedNewPassword.notificationName,
					object: self
				)
				//
				return
			}
			// try to revert save files to old password...
			self.password = old_password // first revert, so consumers can read reverted value
			self.passwordType = old_passwordType
			//
			let revert_save_errStr_orNil = self.saveToDisk()
			if revert_save_errStr_orNil != nil {
				assert(false, "Couldn't saveToDisk to revert failed changePassword") // in debug mode, treat this as fatal
			} else { // continue trying to revert
				let revert_registrantsChangePw_err_orNil = self._changePassword_tellRegistrants_doChangePassword() // this may well fail
				if revert_registrantsChangePw_err_orNil != nil {
					assert(false, "Some registrants couldn't revert failed changePassword") // in debug mode, treat this as fatal
				} else {
					// revert successful
				}
			}
			// finally, notify of error while changing password
			self.unguard_getNewOrExistingPassword() // important
			NotificationCenter.default.post(
				name: NotificationNames.erroredWhileSettingNewPassword.notificationName,
				object: self,
				userInfo: [ Notification_UserInfo_Keys.err_str.rawValue: changePassword_err_orNil! ] // the original changePassword_err_orNil
			)
		}
	}
	func _changePassword_tellRegistrants_doChangePassword() -> String? // err_str
	{
		for (_, weakRefTo_registrant) in self.weakRefsTo_changePasswordRegistrants.enumerated() {
			guard let registrant = weakRefTo_registrant.value else {
				continue // skip ; has dealloced somehow
			}
			let err_str = registrant.passwordController_ChangePassword()
			if err_str != nil {
				return err_str
			}
		}
		return nil
	}
	//
	//
	// Imperatives - Execution deferment
	//
	var __blocksWaitingForBootToExecute: [() -> Void]?
	// NOTE: onceBooted() exists because even though init()->setup() is synchronous, we need to be able to tear down and reconstruct the passwordController booted state, e.g. on user idle and delete everything
	func onceBooted(
		_ fn: @escaping (() -> Void)
	) {
		if self.hasBooted == true {
			fn()
			return
		}
		if self.__blocksWaitingForBootToExecute == nil {
			self.__blocksWaitingForBootToExecute = []
		}
		self.__blocksWaitingForBootToExecute!.append(fn)
	}
	func _callAndFlushAllBlocksWaitingForBootToExecute()
	{
		if self.__blocksWaitingForBootToExecute == nil {
			return
		}
		let blocks = self.__blocksWaitingForBootToExecute!
		self.__blocksWaitingForBootToExecute = nil
		for (_, block) in blocks.enumerated() {
			block()
		}
	}
	//
	// Imperatives - Persistence
	func saveToDisk() -> String? // err_str?
	{
		if self.password == nil {
			let err_str = "Code fault: saveToDisk musn't be called until a password has been set"
			return err_str
		}
		let plaintextData = self.plaintextMessageToSaveForUnlockChallenges.data(using: .utf8, allowLossyConversion: false)!
		let encryptedData = RNCryptor.encrypt(data: plaintextData, withPassword: self.password!)
		let encryptedData_base64String = encryptedData.base64EncodedString()
		self.messageAsEncryptedDataForUnlockChallenge_base64String = encryptedData_base64String // it's important that we hang onto this in memory so we can access it if we need to change the password later
		if self._id == nil {
			self._id = DocumentPersister.new_DocumentId()
		}
		let persistableDocument: [String: Any] =
		[
			DictKey._id.rawValue: self._id!,
			DictKey.passwordType.rawValue: self.passwordType.rawValue,
			DictKey.messageAsEncryptedDataForUnlockChallenge_base64String.rawValue: self.messageAsEncryptedDataForUnlockChallenge_base64String!
		]
		let (err_str, _) = DocumentPersister.shared.Upsert(
			documentWithId: self._id!,
			inCollectionNamed: self.collectionName,
			withUpdate: persistableDocument
		)
		if err_str != nil {
			DDLog.Error("Passwords", "Error while persisting \(self): \(err_str!)")
		}
		//
		return err_str
	}
	//
	// Runtime - Imperatives - Delete everything
	var weakRefsTo_deleteEverythingRegistrants: [WeakRefTo_DeleteEverythingRegistrant] = []
	func addRegistrantForDeleteEverything(
		_ registrant: DeleteEverythingRegistrant
	) -> Void {
//		DDLog.Info("Passwords", "Adding registrant for 'DeleteEverything': \(registrant)")
		self.weakRefsTo_deleteEverythingRegistrants.append(
			WeakRefTo_DeleteEverythingRegistrant(value: registrant)
		)
	}
	func removeRegistrantForDeleteEverything(
		_ registrant: DeleteEverythingRegistrant
	) -> Void {
		var index: Int?
		for (this_index, this_weakRefTo_registrant) in self.weakRefsTo_deleteEverythingRegistrants.enumerated() {
			if this_weakRefTo_registrant.value == nil {
				continue // skip - has dealloced somewhere
			}
			if isEqual(registrant, this_weakRefTo_registrant.value!) {
				index = this_index
				break
			}
		}
		if index == nil {
			assert(false, "registrant is not registered")
			return
		}
		DDLog.Info("Passwords", "Removing registrant for 'DeleteEverything': \(registrant)")
		self.weakRefsTo_deleteEverythingRegistrants.remove(at: index!)
	}
	func initiateDeleteEverything()
	{ // this is used as a central initiation/sync point for delete everything like user idle
		// maybe it should be moved, maybe not.
		// And note we're assuming here the PW has been entered already.
		if self.hasUserSavedAPassword != true {
			let err_str = "initiateDeleteEverything() called but hasUserSavedAPassword != true. This should be disallowed in the UI."
			assert(false, err_str)
			return
		}
		self._deconstructBootedStateAndClearPassword(
			isForADeleteEverything: true,
			optl__hasFiredWill_fn:
			{ [unowned self] (cb) in
				// reset state cause we're going all the way back to pre-boot
				self.hasBooted = false // require this pw controller to boot
				self.password = nil // this is redundant but is here for clarity
				self._id = nil
				self.messageAsEncryptedDataForUnlockChallenge_base64String = nil
				//
				// first have registrants delete everything
				for (_, weakRefTo_registrant) in self.weakRefsTo_deleteEverythingRegistrants.enumerated() {
					guard let registrant = weakRefTo_registrant.value else {
						continue // skip ; has dealloced somehow
					}
					let registrant__err_str = registrant.passwordController_DeleteEverything()
					if registrant__err_str != nil {
						cb(registrant__err_str)
						return
					}
				}
				//
				// then delete pw record
				let (err_str, _) = DocumentPersister.shared.RemoveAllDocuments(inCollectionNamed: self.collectionName)
				if err_str != nil {
					cb(err_str)
					return
				}
				DDLog.Deleting("Passwords", "Deleted password record.")
				//
				self.initializeRuntimeAndBoot() // now trigger a boot before we call cb (tho we could do it after - consumers will wait for boot)
				cb(nil)
			},
			optl__fn:
			{ [unowned self] (err_str) in
				if err_str != nil {
					DDLog.Error("Passwords", "Error while deleting everything: \(err_str!)")
					assert(false, "Error while deleting everything")
					// we probably want to just fatalError here since password etc has been un-set - user can always relaunch
					fatalError("Error while deleting everything")
//					return
				}
				NotificationCenter.default.post(
					name: NotificationNames.havingDeletedEverything_didDeconstructBootedStateAndClearPassword.notificationName,
					object: self
				)
			}
		)
	}
	//
	// Runtime - Imperatives - App lock down interface (special case usage only)
	func lockDownAppAndRequirePassword()
	{ // just a public interface for this - special-case-usage only!
		if self.hasUserEnteredValidPasswordYet == false { // this is fine, but should be used to bail
			DDLog.Warn("Passwords", "Asked to lockDownAppAndRequirePassword but no password entered yet.")
			return
		}
		DDLog.Info("Passwords", "Will lockDownAppAndRequirePassword")
		self._deconstructBootedStateAndClearPassword(
			isForADeleteEverything: false,
			optl__hasFiredWill_fn: nil,
			optl__fn: nil
		)
	}
	//
	// Runtime - Imperatives - Boot-state deconstruction/teardown
	func _deconstructBootedStateAndClearPassword(
		isForADeleteEverything: Bool,
		optl__hasFiredWill_fn: ((
			_ cb: (_ err_str: String?) -> Void
		) -> Void)?,
		optl__fn: ((
			_ err_str: String?
		) -> Void)?
	) {
		let hasFiredWill_fn = optl__hasFiredWill_fn ?? { (cb) in cb(nil) }
		let fn = optl__fn ?? { (err_str) in }
		//
		// TODO:? do we need to cancel any waiting functions here? not sure it would be possible to have any (unless code fault)?????? we'd only deconstruct the booted state and pop the enter pw screen here if we had already booted before - which means there shouldn't be such waiting functions - so maybe assert that here - which requires hanging onto those functions somehow
		do { // indicate to consumers they should tear down and await the "did" event to re-request
			NotificationCenter.default.post(
				name: NotificationNames.willDeconstructBootedStateAndClearPassword.notificationName,
				object: self,
				userInfo: [ Notification_UserInfo_Keys.isForADeleteEverything.rawValue: isForADeleteEverything ]
			)
		}
		hasFiredWill_fn(
			{ err_str in
				if err_str != nil {
					fn(err_str)
					return
				}
				do { // trigger deconstruction of booted state and require password
					self.password = nil // clear pw in memory
					self.hasBooted = false // require this pw controller to boot
					self._id = nil
					self.messageAsEncryptedDataForUnlockChallenge_base64String = nil
				}
				do { // we're not going to call WhenBootedAndPasswordObtained_PasswordAndType because consumers will call it for us after they tear down their booted state with the "will" event and try to boot/decrypt again when they get this "did" event
					NotificationCenter.default.post(
						name: NotificationNames.didDeconstructBootedStateAndClearPassword.notificationName,
						object: self
					)
				}
				//
				self.initializeRuntimeAndBoot() // now trigger a boot before we call cb (tho we could do it after - consumers will wait for boot)
				//
				fn(nil)
			}
		)
	}
	//
	// Delegation - Password
	func _didObtainPassword(password: Password)
	{
		self.password = password
	}
	//
	// Delegation - Notifications
	@objc func UserIdle_userDidBecomeIdle()
	{
		if self.hasUserSavedAPassword == false {
			// nothing to do here because the app is not unlocked and/or has no data which would be locked
			DDLog.Info("Passwords", "User became idle but no password has ever been entered/no saved data should exist.")
			return
		} else if self.hasUserEnteredValidPasswordYet == false {
			// user has saved data but hasn't unlocked the app yet
			DDLog.Info("Passwords", "User became idle and saved data/pw exists, but user hasn't unlocked app yet.")
			return
		}
		self._didBecomeIdleAfterHavingPreviouslyEnteredPassword()
	}
	//
	// Delegation - User having become idle -> teardown booted state and require pw
	func _didBecomeIdleAfterHavingPreviouslyEnteredPassword()
	{
		self._deconstructBootedStateAndClearPassword(
			isForADeleteEverything: false,
			optl__hasFiredWill_fn: nil,
			optl__fn: nil
		)
	}
}
