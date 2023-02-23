// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import os.log
import SwiftUI

import ZIPFoundation

extension ExperienceStoreService {
    func read(contentsOf fileUrl: URL) throws -> ExperienceModel? {
        let fileData = try Data(contentsOf: fileUrl)
        
        return try? read(contentsOfFile: fileData)
    }

    func read(contentsOfFile data: Data) throws -> ExperienceModel? {
        guard let archive = ZIPFoundation.Archive(data: data, accessMode: .read) else {
            os_log("Unable to open ZIP container", type: .error)
            throw CocoaError(.fileReadCorruptFile)
        }

        guard let documentFile = archive["document.json"], documentFile.type == .file else {
            throw CocoaError(.fileReadUnknown)
        }
        var documentData: Data?
        
        do {
            documentData = try archive.extractEntire(entry: documentFile)
        } catch {
            os_log(
                "Unable to read document due to ZIP decoding issue: %s",
                log: OSLog.default,
                type: .error,
                error.debugDescription
            )
            throw CocoaError(.fileReadUnknown)
        }
        
        guard let documentData = documentData else {
            return nil
        }

        do {
            return try ExperienceModel.decode(
                from: documentData,
                images: try archive.extractImages(),
                assetContext: LocalAssetContext(mediaURLs: try archive.extractMediaURLs(),
                                                fontURLs: try archive.extractFontURLs()))
        } catch {
            os_log(
                "Unable to read document due to JSON decoding issue: %s",
                log: OSLog.default,
                type: .error,
                error.debugDescription
            )
            throw CocoaError(.fileReadUnknown)
        }
    }
}
