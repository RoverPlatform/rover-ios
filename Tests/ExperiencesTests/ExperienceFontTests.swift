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

import CoreText
import UIKit
import XCTest

@testable import RoverExperiences

/// `AssetsDownloader.result(data:response:error:)` decides what a font (or any
/// asset) download callback means. A non-2xx body must never be handed to the
/// caller as asset data: handing a CDN error page to `CGFont` was the root cause
/// of SDK-386's intermittently missing fonts.
final class AssetsDownloaderResultTests: XCTestCase {
    private let url = URL(string: "https://content.example.com/fonts/abc.ttf")!

    private func httpResponse(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    func testSuccessfulResponsePassesDataThrough() throws {
        let data = Data([0x00, 0x01, 0x00, 0x00])
        let result = AssetsDownloader.result(data: data, response: httpResponse(status: 200), error: nil)
        XCTAssertEqual(try result.get(), data)
    }

    func testTransportErrorIsFailure() {
        let result = AssetsDownloader.result(data: nil, response: nil, error: URLError(.timedOut))
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
    }

    func testNonSuccessStatusCodeIsFailureEvenWithBody() {
        let body = Data("{\"code\":\"NOT_FOUND_ERROR\"}".utf8)
        let result = AssetsDownloader.result(data: body, response: httpResponse(status: 404), error: nil)
        XCTAssertThrowsError(try result.get()) { error in
            guard case AssetDownloadError.invalidStatusCode(let statusCode) = error else {
                XCTFail("Expected invalidStatusCode, got \(error)")
                return
            }
            XCTAssertEqual(statusCode, 404)
        }
    }

    func testEmptyBodyIsFailure() {
        // A zero-byte 200 is not an asset; it must map to emptyResponse rather
        // than handing empty data to CGFont or UIImage.
        let result = AssetsDownloader.result(data: Data(), response: httpResponse(status: 200), error: nil)
        XCTAssertThrowsError(try result.get()) { error in
            guard case AssetDownloadError.emptyResponse = error else {
                XCTFail("Expected emptyResponse, got \(error)")
                return
            }
        }
    }

    func testMissingDataWithoutErrorIsFailure() {
        // The old implementation never called the completion in this case, so the
        // font was silently lost. Now it must surface as a failure.
        let result = AssetsDownloader.result(data: nil, response: httpResponse(status: 200), error: nil)
        XCTAssertThrowsError(try result.get()) { error in
            guard case AssetDownloadError.emptyResponse = error else {
                XCTFail("Expected emptyResponse, got \(error)")
                return
            }
        }
    }
}

final class ExperienceFontRegistrationTests: XCTestCase {
    func testGarbageDataThrowsInvalidFontData() {
        // Only this error is allowed to evict the cached response; a registration
        // failure must not, so the distinction matters.
        XCTAssertThrowsError(try ExperienceFontLoader.registerFontIfNeeded(data: Data("not a font".utf8))) { error in
            guard case ExperienceFontLoader.FontRegistrationError.invalidFontData = error else {
                XCTFail("Expected invalidFontData, got \(error)")
                return
            }
        }
    }

    func testRegisteringTheSameFontTwiceSucceeds() throws {
        // Fixture: Roboto-Regular, licensed under the Apache License 2.0.
        let fontUrl = try XCTUnwrap(Bundle.module.url(forResource: "Roboto-Regular", withExtension: "ttf"))
        let data = try Data(contentsOf: fontUrl)

        // Registration is process-global; leave the process as found so later
        // suites never see a Roboto that this test installed. Only unregister
        // when the font was absent going in: registerFontIfNeeded skips an
        // already-available font, and unregistering one this test did not
        // install would strip it from whoever did.
        let wasAlreadyAvailable = UIFont(name: "Roboto-Regular", size: 17) != nil
        addTeardownBlock {
            guard !wasAlreadyAvailable,
                let provider = CGDataProvider(data: data as CFData),
                let cgFont = CGFont(provider)
            else {
                return
            }
            CTFontManagerUnregisterGraphicsFont(cgFont, nil)
        }

        try ExperienceFontLoader.registerFontIfNeeded(data: data)
        // A font that is already available (registered by an earlier experience or
        // by the host app) is a success, never an error.
        XCTAssertNoThrow(try ExperienceFontLoader.registerFontIfNeeded(data: data))
        XCTAssertNotNil(UIFont(name: "Roboto-Regular", size: 17))
    }
}

final class FontEmphasesTests: XCTestCase {
    func testBoldAndItalicEmphasesBothApply() throws {
        let font = RoverExperiences.Font.dynamic(textStyle: .body, emphases: [.bold, .italic])
        let uiFont = try XCTUnwrap(font.uikitFont(with: nil))

        let traits = uiFont.fontDescriptor.symbolicTraits
        XCTAssertTrue(traits.contains(.traitBold), "Bold emphasis was dropped")
        XCTAssertTrue(traits.contains(.traitItalic), "Italic emphasis was dropped")
    }
}

final class ExperienceModelFontURLsTests: XCTestCase {
    /// A `DocumentFont` family entry as the Mac app writes it. Real customer
    /// documents (SDK-386's included) can carry the same family entry several
    /// times over, so `fontURLs` must deduplicate.
    private func familyJSON(assetName: String) -> String {
        let style = "{\"fontName\":\"Example-Regular\",\"size\":17}"
        return """
            {"fontFamily":"Example","largeTitle":\(style),"title":\(style),"title2":\(style),\
            "title3":\(style),"headline":\(style),"body":\(style),"callout":\(style),\
            "subheadline":\(style),"footnote":\(style),"caption":\(style),"caption2":\(style),\
            "sources":[{"fontNames":["Example-Regular"],"assetName":"\(assetName)"}]}
            """
    }

    private func decodeExperience(fontsJSON: String) throws -> ExperienceModel {
        let json = String(data: ExperienceFixtures.simpleScreenJSON, encoding: .utf8)!
            .replacingOccurrences(of: "\"fonts\":[]", with: "\"fonts\":[\(fontsJSON)]")
        let assetContext = RemoteAssetContext(
            baseUrl: URL(string: "https://content.example.com/experience")!,
            configuration: nil
        )
        return try ExperienceModel.decode(from: Data(json.utf8), assetContext: assetContext)
    }

    func testDuplicateFamilyEntriesProduceEachFontURLOnce() throws {
        let duplicated = [familyJSON(assetName: "a.ttf"), familyJSON(assetName: "a.ttf")].joined(separator: ",")
        let experience = try decodeExperience(fontsJSON: duplicated)

        XCTAssertEqual(
            experience.fontURLs,
            [URL(string: "https://content.example.com/experience/fonts/a.ttf")!]
        )
    }

    func testDistinctFontURLsArePreservedInOrder() throws {
        let fonts = [familyJSON(assetName: "a.ttf"), familyJSON(assetName: "b.ttf")].joined(separator: ",")
        let experience = try decodeExperience(fontsJSON: fonts)

        XCTAssertEqual(
            experience.fontURLs,
            [
                URL(string: "https://content.example.com/experience/fonts/a.ttf")!,
                URL(string: "https://content.example.com/experience/fonts/b.ttf")!
            ]
        )
    }
}
