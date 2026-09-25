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

import CoreGraphics
import CoreText
import Foundation

/// Downloads and registers the custom fonts declared by an experience document.
///
/// Shared by the SwiftUI (`RenderExperienceView`) and UIKit
/// (`RenderExperienceViewController`) rendering paths. Registration of downloaded
/// fonts runs on the `AssetsDownloader`'s serial completion queue, which keeps the
/// check-then-register sequence in `registerFontIfNeeded(data:)` free of races.
enum ExperienceFontLoader {
    /// A failed download (or corrupt cached font data) is retried once after this
    /// delay, so a transient network failure does not cost the font for the whole
    /// session. Live text re-resolves via
    /// `ExperienceManager.didRegisterCustomFontNotification` when the retry lands,
    /// so the recovered font swaps in on screen.
    static let retryDelay: TimeInterval = 2.0

    enum FontRegistrationError: Error, LocalizedError {
        /// The bytes are not a decodable font. When they came through the asset
        /// cache, the cached response should be evicted so a later attempt
        /// refetches instead of replaying the same bad bytes.
        case invalidFontData

        /// The data was a valid font but Core Text refused to register it. The
        /// cached copy is fine and must not be evicted.
        case registrationFailed(fontName: String, message: String)

        var errorDescription: String? {
            switch self {
            case .invalidFontData:
                return "Unable to decode font from provided data."
            case .registrationFailed(let fontName, let message):
                return "Unable to register font \(fontName): \(message)"
            }
        }
    }

    /// Registers every font the experience declares. File URLs (bundled `.rover`
    /// documents) register synchronously so their fonts are available before the
    /// first render; network URLs download asynchronously and recover via the
    /// font-registration notification.
    static func loadFonts(for experience: ExperienceModel, experienceManager: ExperienceManager) {
        experience.fontURLs.forEach { url in
            if url.isFileURL {
                do {
                    try registerFontIfNeeded(data: try Data(contentsOf: url))
                } catch {
                    rover_log(
                        .error,
                        "Unable to load font at %@. Error: %@",
                        url.absoluteString,
                        error.debugDescription
                    )
                }
            } else {
                downloadAndRegister(url: url, experienceManager: experienceManager, retriesRemaining: 1)
            }
        }
    }

    private static func downloadAndRegister(url: URL, experienceManager: ExperienceManager, retriesRemaining: Int) {
        experienceManager.downloader.download(url: url) { result in
            switch result {
            case .success(let data):
                do {
                    try registerFontIfNeeded(data: data)
                } catch FontRegistrationError.invalidFontData {
                    // The response body is not a font. Evict it so a retry (or the
                    // next open) refetches rather than replaying the same bytes out
                    // of the cache under `.returnCacheDataElseLoad`.
                    experienceManager.assetsURLCache.removeCachedResponse(for: URLRequest(url: url))
                    retry(
                        url: url,
                        experienceManager: experienceManager,
                        retriesRemaining: retriesRemaining,
                        reason: "response did not contain a decodable font"
                    )
                } catch {
                    rover_log(
                        .error,
                        "Unable to register font at %@. Error: %@",
                        url.absoluteString,
                        error.debugDescription
                    )
                }
            case .failure(let error):
                retry(
                    url: url,
                    experienceManager: experienceManager,
                    retriesRemaining: retriesRemaining,
                    reason: error.debugDescription
                )
            }
        }
    }

    private static func retry(url: URL, experienceManager: ExperienceManager, retriesRemaining: Int, reason: String) {
        guard retriesRemaining > 0 else {
            rover_log(
                .error,
                "Unable to load font at %@, giving up for this session. Reason: %@",
                url.absoluteString,
                reason
            )
            return
        }
        rover_log(
            .error,
            "Unable to load font at %@, retrying once. Reason: %@",
            url.absoluteString,
            reason
        )
        DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) {
            downloadAndRegister(
                url: url,
                experienceManager: experienceManager,
                retriesRemaining: retriesRemaining - 1
            )
        }
    }

    /// Registers the given font data with Core Text, unless a font with the same
    /// PostScript name is already available (in which case this is a no-op
    /// success, including when another experience or the host app registered it).
    static func registerFontIfNeeded(data: Data) throws {
        guard let fontProvider = CGDataProvider(data: data as CFData),
            let cgFont = CGFont(fontProvider),
            let fontName = cgFont.postScriptName as String?
        else {
            throw FontRegistrationError.invalidFontData
        }

        let queryCollection = CTFontCollectionCreateWithFontDescriptors(
            [
                CTFontDescriptorCreateWithAttributes(
                    [kCTFontNameAttribute: fontName] as CFDictionary
                )
            ] as CFArray,
            nil
        )

        let fontExists =
            (CTFontCollectionCreateMatchingFontDescriptors(queryCollection) as? [CTFontDescriptor])?.isEmpty == false
        guard !fontExists else {
            return
        }

        var registrationError: Unmanaged<CFError>?
        guard CTFontManagerRegisterGraphicsFont(cgFont, &registrationError) else {
            let underlying = registrationError?.takeRetainedValue()
            if let underlying = underlying, isAlreadyRegistered(underlying) {
                // Another screen, experience, or the host app got there first; the
                // font resolves either way, so this is a success.
                return
            }
            let message = underlying.map { CFErrorCopyDescription($0) as String } ?? "unknown error"
            throw FontRegistrationError.registrationFailed(fontName: fontName, message: message)
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: ExperienceManager.didRegisterCustomFontNotification,
                object: fontName
            )
        }
    }

    private static func isAlreadyRegistered(_ error: CFError) -> Bool {
        CFErrorGetDomain(error) as String == kCTFontManagerErrorDomain as String
            && CFErrorGetCode(error) == CTFontManagerError.alreadyRegistered.rawValue
    }
}
