// Copyright (c) 2020 KineApps. All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.

import Foundation
import MobileCoreServices
import UIKit

enum OpenFileDialogType: String {
    case document
    case image
}

class OpenFileDialog: NSObject, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private var flutterResult: FlutterResult?
    private var params: OpenFileDialogParams?

    deinit {
        writeLog("OpenFileDialog.deinit")
    }

    func pickFile(_ params: OpenFileDialogParams, result: @escaping FlutterResult) {
        flutterResult = result
        self.params = params

        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            result(FlutterError(code: "fatal",
                                message: "Getting rootViewController failed",
                                details: nil)
            )
            return
        }

        if params.dialogType == OpenFileDialogType.image {
            let imagePicker = UIImagePickerController()
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                imagePicker.delegate = self
                imagePicker.sourceType = params.sourceType
                imagePicker.allowsEditing = params.allowEditing

                viewController.present(imagePicker, animated: true, completion: nil)
            }

        } else {
            let documentTypes = params.allowedUtiTypes ?? [String(kUTTypeText), String(kUTTypeContent), String(kUTTypeItem), String(kUTTypeData)]

            let documentPickerViewController = UIDocumentPickerViewController(documentTypes: documentTypes, in: .import)

            documentPickerViewController.delegate = self

            viewController.present(documentPickerViewController, animated: true, completion: nil)
        }
    }

    // MARK: - UIImagePickerController

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)
        // if !params!.allowEditing, let pickedFileUrl: URL = info[UIImagePickerController.InfoKey.imageURL] as? URL {
        //     writeLog("picked file: " + pickedFileUrl.absoluteString)
        //     handlePickedFile(pickedFileUrl)
        // } else {
        //     if let pickedImage: UIImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage ??
        //         info[UIImagePickerController.InfoKey.originalImage] as? UIImage
        //     {
        //         // save picked image to temp dir
        //         DispatchQueue.global(qos: .userInitiated).async {
        //             do {
        //                 let directory = NSTemporaryDirectory()

        //                 let dateFormatter = DateFormatter()
        //                 dateFormatter.dateFormat = "yyyyMMddHHmmss"

        //                 let fileName = dateFormatter.string(from: Date()) + ".jpg"

        //                 let destinationFileUrl = NSURL.fileURL(withPathComponents: [directory, fileName])!

        //                 let jpeg = pickedImage.jpegData(compressionQuality: CGFloat(1.0))!
        //                 try jpeg.write(to: destinationFileUrl)

        //                 // return picked file path
        //                 DispatchQueue.main.async {
        //                     writeLog("Saved picked image to: " + destinationFileUrl.path)
        //                     self.flutterResult?(destinationFileUrl.path)
        //                 }
        //             } catch {
        //                 DispatchQueue.main.async {
        //                     writeLog(error.localizedDescription)
        //                     self.flutterResult?(FlutterError(code: "file_copy_error",
        //                                                      message: error.localizedDescription,
        //                                                      details: nil))
        //                 }
        //             }
        //         }
        //     } else {
        //         flutterResult?(nil)
        //     }
        // }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        writeLog("imagePickerController cancelled")
        picker.dismiss(animated: true, completion: nil)
        flutterResult?(nil)
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        // this callback is depracated
        writeLog("didPickDocumentAt")
        handlePickedFile(url)
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        writeLog("didPickDocumentsAt")
        let url = urls[0]
        handlePickedFile(url)
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        writeLog("documentPickerWasCancelled")
        flutterResult?(nil)
    }

    private func handlePickedFile(_ url: URL) {
        writeLog("handlePickedFile: \(url.path)")

        let fileExtension = url.pathExtension

        if let fileExtensionsFilter = params?.fileExtensionsFilter {
            if !fileExtensionsFilter.contains(where: { $0.caseInsensitiveCompare(fileExtension) == .orderedSame }) {
                flutterResult?(FlutterError(code: "invalid_file_extension",
                                            message: "Invalid file type was picked",
                                            details: fileExtension))
                return
            }
        }

        // get destination file path
        let fileName = cleanupFileName(url.lastPathComponent)
        var destinationFileUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        destinationFileUrl.appendPathComponent(fileName)

        // move file to destination
        // file is already saved to destination path if picked from photos
        if destinationFileUrl.absoluteString != url.absoluteString {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // overwrite existing file
                    if FileManager.default.fileExists(atPath: destinationFileUrl.path) {
                        try FileManager.default.removeItem(atPath: destinationFileUrl.path)
                    }

                    // move file from app_id-Inbox to destination
                    writeLog("Moving '\(url.path)' to '\(destinationFileUrl.path)'")
                    try FileManager.default.moveItem(atPath: url.path, toPath: destinationFileUrl.path)

                    DispatchQueue.main.async {
                        // return picked file path
                        self.flutterResult?(destinationFileUrl.path)
                    }
                } catch {
                    DispatchQueue.main.async {
                        writeLog(error.localizedDescription)
                        self.flutterResult?(FlutterError(code: "file_copy_error",
                                                         message: error.localizedDescription,
                                                         details: nil))
                    }
                    return
                }
            }
        } else {
            // return picked file path
            flutterResult?(destinationFileUrl.path)
        }
    }

    private func cleanupFileName(_ fileName: String) -> String {
        let invalidCharacters: Set<Character> =
            Set("\\/:*?\"<>|[]")
        return String(fileName.filter { !invalidCharacters.contains($0) })
    }
}
