//
//  DocumentPersister.swift
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
import Foundation
//
class DocumentPersister
{
	typealias DocumentId = String
	static func new_DocumentId() -> DocumentId { return UUID().uuidString }
	typealias CollectionName = String
	typealias DocumentJSON = [String: Any]
	static let documentFiles_parentDirectory_URL = try! FileManager().url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
	struct DocumentFileDescription
	{
		var inCollectionName: CollectionName
		var documentId: DocumentId
		static let fileKeyComponentDelimiterString = "__" // not -, because those exist in uuids
		var new_fileKey: String {
			return "\(self.inCollectionName)\(DocumentFileDescription.fileKeyComponentDelimiterString)\(self.documentId)"
		}
		static let filenameExt = v1_filenameExt
		static let v1_filenameExt = "mmdbdoc_v1"
		static let preV0_filenameExt = "MMDBDoc.json" // still around so it can be used for migration
		var new_filename: String {
			return "\(self.new_fileKey).\(DocumentFileDescription.filenameExt)"
		}
		var new_fileURL: URL {
			let fileURL = DocumentPersister.documentFiles_parentDirectory_URL.appendingPathComponent(self.new_filename)
			
			return fileURL
		}
	}
	//
	// Interface - Static - Instance access
	static let shared = DocumentPersister()
	//
	//
	// Lifecycle - Init
	//
	private init()
	{
		self.setup()
	}
	func setup()
	{
	}
	//
	//
	// Interface - Runtime - Accessors
	//
	func Documents(
		withIds ids: [DocumentId],
		inCollectionNamed collectionName: CollectionName
	) -> (
		err_str: String?,
		documentJSONs: [DocumentJSON]?
	) {
		let fileDescriptions = ids.map{
			DocumentFileDescription(
				inCollectionName: collectionName,
				documentId: $0
			)
		}
		let documentJSONs = self._read_existentDocumentJSONs(
			withDocumentFileDescriptions: fileDescriptions
		)
		return documentJSONs
	}
	// Or if you are writing the file data directly, read with:
	func DocumentsData(
		withIds ids: [DocumentId],
		inCollectionNamed collectionName: CollectionName
	) -> (
		err_str: String?,
		documentsData: [Data]?
	) {
		let fileDescriptions = ids.map{
			DocumentFileDescription(
				inCollectionName: collectionName,
				documentId: $0
			)
		}
		let documentsData = self._read_existentDocumentsData(
			withDocumentFileDescriptions: fileDescriptions
		)
		return documentsData
	}
	func IdsOfAllDocuments(
		inCollectionNamed collectionName: CollectionName
	) -> (
		err_str: String?,
		ids: [DocumentId]?
	) {
		let (err_str, fileDescriptions) = self._read_documentFileDescriptions(inCollectionNamed: collectionName)
		if err_str != nil {
			return (err_str, nil)
		}
		assert(fileDescriptions != nil, "nil fileDescriptions")
		var ids = [DocumentId]()
		for (_, fileDescription) in fileDescriptions!.enumerated() {
			ids.append(fileDescription.documentId)
		}
		//
		return (nil, ids)
	}
	func AllDocuments(
		inCollectionNamed collectionName: CollectionName
	) -> (
		err_str: String?,
		documentJSONs: [DocumentJSON]?
	) {
		let (err_str, fileDescriptions) = self._read_documentFileDescriptions(inCollectionNamed: collectionName)
		if err_str != nil {
			return (err_str, nil)
		}
		assert(fileDescriptions != nil, "nil fileDescriptions")
		//
		return self._read_existentDocumentJSONs(withDocumentFileDescriptions: fileDescriptions)
	}
	//
	// Interface - Runtime - Imperatives
	func UpdateDocument(
		withId id: DocumentId,
		inCollectionNamed collectionName: CollectionName,
		withDocument updatedDocument: DocumentJSON
	) -> (
		err_str: String?,
		insertedDocument: DocumentJSON? // returned because it may now contain a _id field
	) {
		let fileDescription = DocumentFileDescription(
			inCollectionName: collectionName,
			documentId: id
		)
		var final_document = updatedDocument // mutable copy
		let document_id = updatedDocument["_id"] as? DocumentId
		if document_id == nil {
			final_document["_id"] = document_id // just as a safeguard against consumers submitting a different document
		}
		do {
			try self._write_fileDescriptionDocumentData(
				fileDescription: fileDescription,
				jsonToWrite: final_document
			)
		} catch let e {
			return (e.localizedDescription, nil)
		}
		return (nil, final_document)
	}
	func Upsert(
		documentWithId id: DocumentId,
		inCollectionNamed collectionName: CollectionName,
		withUpdate updatedDocument: DocumentJSON
	) -> (
		err_str: String?,
		upsertedDocument: DocumentJSON? // returned because it may now contain a _id field
	) {
		let fileDescription = DocumentFileDescription(
			inCollectionName: collectionName,
			documentId: id
		)
		var final_document = updatedDocument // mutable copy
		let document_id = updatedDocument["_id"] as? DocumentId
		if document_id == nil {
			final_document["_id"] = document_id // just as a safeguard against consumers submitting a different document
		}
		do {
			try self._write_fileDescriptionDocumentData(
				fileDescription: fileDescription,
				jsonToWrite: final_document
			)
		} catch let e {
			return (e.localizedDescription, nil)
		}
		return (nil, final_document)
	}
	// Or, instead of using insert/update/upsert, if you want to control the format of the fileData, say, to encrypt it, you can use:
	func Write(
		documentFileWithData fileData: Data, // if you're using this for Documents, be sure to set field _id to id within your fileData
		withId id: DocumentId, // consumer must supply the document ID since we can't make assumptions about fileData
		toCollectionNamed collectionName: CollectionName
	) -> String? { // err_str
		let fileDescription = DocumentFileDescription(
			inCollectionName: collectionName,
			documentId: id
		)
		do {
			try self._write_fileDescriptionDocumentData(
				fileDescription: fileDescription,
				fileData: fileData
			)
		} catch let e {
			return e.localizedDescription
		}
		return nil
	}
	//
	func RemoveDocuments(
		inCollectionNamed collectionName: CollectionName,
		withIds ids: [DocumentId]
	) -> (err_str: String?, numRemoved: Int?) {
		var numRemoved = 0
		for (_, id) in ids.enumerated() {
			let fileDescription = DocumentFileDescription(
				inCollectionName: collectionName,
				documentId: id
			)
			let fileURL = fileDescription.new_fileURL
			do {
				try FileManager.default.removeItem(at: fileURL)
			} catch let e {
				return (e.localizedDescription, numRemoved)
			}
			numRemoved += 1
		}
		return (nil, numRemoved)
	}
	func RemoveAllDocuments(
		inCollectionNamed collectionName: CollectionName
	) -> (err_str: String?, numRemoved: Int?) {
		let (err_str, ids) = self.IdsOfAllDocuments(inCollectionNamed: collectionName)
		if err_str != nil {
			return (err_str, nil)
		}
		//
		return self.RemoveDocuments(inCollectionNamed: collectionName, withIds: ids!)
	}
	//
	//
	// Internal - Accessors - Files
	//
	func _read_existentDocumentJSONs(
		withDocumentFileDescriptions documentFileDescriptions: [DocumentFileDescription]?
	) -> (
		err_str: String?,
		documentJSONs: [DocumentJSON]?
	) {
		var documentJSONs = [DocumentJSON]()
		guard let documentFileDescriptions = documentFileDescriptions, documentFileDescriptions.count > 0 else {
			return (nil, documentJSONs)
		}
		for (_, documentFileDescription) in documentFileDescriptions.enumerated() {
			let (err_str, documentJSON) = self.__read_existentDocumentJSON(withDocumentFileDescription: documentFileDescription)
			if err_str != nil {
				return (err_str, nil) // immediately
			}
			assert(documentJSON != nil, "nil documentJSON")
			documentJSONs.append(documentJSON!)
		}
		return (nil, documentJSONs)
	}
	func _read_existentDocumentsData(
		withDocumentFileDescriptions documentFileDescriptions: [DocumentFileDescription]?
	) -> (
		err_str: String?,
		documentsData: [Data]?
	) {
		var documentsData = [Data]()
		guard let documentFileDescriptions = documentFileDescriptions, documentFileDescriptions.count > 0 else {
			return (nil, documentsData)
		}
		for (_, documentFileDescription) in documentFileDescriptions.enumerated() {
			let (err_str, data) = self.__read_existentDocumentData(withDocumentFileDescription: documentFileDescription)
			if err_str != nil {
				return (err_str, nil) // immediately
			}
			assert(data != nil, "nil data")
			documentsData.append(data!)
		}
		return (nil, documentsData)
	}
	func __read_existentDocumentJSON(
		withDocumentFileDescription documentFileDescription: DocumentFileDescription
	) -> (
		err_str: String?,
		documentJSON: DocumentJSON?
	) {
		let (err_str, fileData) = self.__read_existentDocumentData(withDocumentFileDescription: documentFileDescription)
		if err_str != nil {
			return (err_str, nil)
		}
		var json: [String: Any]
		do {
			json = try JSONSerialization.jsonObject(with: fileData!) as! [String: Any]
		} catch let e {
			return (e.localizedDescription, nil)
		}
		return (nil, json)
	}
	func __read_existentDocumentData(
		withDocumentFileDescription documentFileDescription: DocumentFileDescription
	) -> (
		err_str: String?,
		data: Data?
	) {
		let expected_fileURL = documentFileDescription.new_fileURL
		var fileData: Data
		do {
			fileData = try Data(contentsOf: expected_fileURL, options: [])
		} catch let e {
			return (e.localizedDescription, nil)
		}
		return (nil, fileData)
	}
	func _read_documentFileDescriptions(
		inCollectionNamed collectionName: CollectionName
	) -> (
		err_str: String?,
		fileDescriptions: [DocumentFileDescription]?
	) {
		var fileDescriptions = [DocumentFileDescription]()
		let parentDirectory_URL = DocumentPersister.documentFiles_parentDirectory_URL
		do {
			let directoryContents = try FileManager.default.contentsOfDirectory(
				at: parentDirectory_URL,
				includingPropertiesForKeys: nil,
				options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants]
			)
			// filtering to what should be JSON doc files
			let filenameSuffix = ("."+DocumentFileDescription.filenameExt)
			let filenameSuffix_length = filenameSuffix.count
			let dbDocumentFileURLs = directoryContents.filter{
				return $0.lastPathComponent.hasSuffix(filenameSuffix)
			}
			// going to assume they're not directories - probably is better way to check or pre-filter
			for (_, fileURL) in dbDocumentFileURLs.enumerated() {
				let filename_withExt = fileURL.lastPathComponent
				let endIndex = filename_withExt.index(
					filename_withExt.endIndex,
					offsetBy: -1 * filenameSuffix_length
				)
				let filename_sansExt = String(filename_withExt[..<endIndex])
				//
				let fileKey = filename_sansExt // assumption
				let fileKey_components = fileKey.components(separatedBy: DocumentFileDescription.fileKeyComponentDelimiterString)
				if fileKey_components.count != 2 {
					return ("Unrecognized filename format in db data directory.", nil)
				}
				let fileKey_collectionName = fileKey_components[0] as CollectionName
				if fileKey_collectionName != collectionName {
//					DDLog.Info("Persistence", "Skipping file named \(fileKey) as it's not in \(collectionName)")
					continue
				}
				let fileKey_id  = fileKey_components[1] as DocumentId
				let fileDescription = DocumentFileDescription(
					inCollectionName: fileKey_collectionName,
					documentId: fileKey_id
				)
				fileDescriptions.append(fileDescription) // ought to be a JSON doc file
			}
		} catch let error as NSError {
			return (error.localizedDescription, nil)
		}
		return (nil, fileDescriptions)
	}
	//
	//
	// Internal - Imperatives - File writing
	//
	func _write_fileDescriptionDocumentData(
		fileDescription: DocumentFileDescription,
		jsonToWrite: DocumentJSON
	) throws {
		let json_Data =  try JSONSerialization.data(
			withJSONObject: jsonToWrite,
			options: []
		)
		let fileURL = fileDescription.new_fileURL
		try __write_dataToFileURL(fileURL, json_Data)
	}
	func _write_fileDescriptionDocumentData(
		fileDescription: DocumentFileDescription,
		fileData: Data
	) throws {
		let fileURL = fileDescription.new_fileURL
		try __write_dataToFileURL(fileURL, fileData)
	}
	func __write_dataToFileURL(
		_ fileURL: URL,
		_ fileData: Data
	) throws {
		try fileData.write(to: fileURL, options: .atomic)
	}
}
