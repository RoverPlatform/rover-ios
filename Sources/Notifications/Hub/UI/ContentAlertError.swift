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

import SwiftUI

/// Generic alert error type for content loading failures in Hub
enum ContentAlertError: Identifiable {
    case notFound(_ contentType: ContentType)
    case error(String)

    var id: String {
        switch self {
        case .notFound(let type): return "notFound_\(type)"
        case .error(let msg): return "error_\(msg)"
        }
    }

    var title: String {
        switch self {
        case .notFound(let type): return "\(type.title) Not Found"
        case .error: return "Error"
        }
    }

    var message: String {
        switch self {
        case .notFound(let type): return "The requested \(type.title.lowercased()) could not be found."
        case .error(let msg): return msg
        }
    }
}

enum ContentType: String {
    case post

    var title: String {
        switch self {
        case .post: return "Post"
        }
    }
}
