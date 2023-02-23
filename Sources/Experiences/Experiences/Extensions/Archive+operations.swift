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

import Foundation
import ZIPFoundation


extension Archive {
    /// Extract the entire ZIP Entry (assuming it is a File entry) into a single buffer.
    func extractEntire(entry: Entry) throws -> Data {
        var buffer = Data(count: Int(entry.uncompressedSize))
        
        // the CRC32 check is extremely slow in debug builds, so skip it.
#if DEBUG
        let skipCRC32 = true
#else
        let skipCRC32 = false
#endif
        
        var position = 0
        // despite the closure, this is not asynchronous.
        let _ = try self.extract(entry, skipCRC32: skipCRC32) { chunk in
            let endPos = Swift.min(position + chunk.count, Int(entry.uncompressedSize))
            let targetRange: Range<Data.Index> = position..<endPos
            if targetRange.count > 0 {
                buffer[targetRange] = chunk
            }
            position = endPos
        }
        return buffer
    }
    
    func extractImages() throws -> [String: ImageValue] {
        let entriesByPath: [String: Entry] = reduce(into: [:]) { result, entry in
            result[entry.path] = entry
        }
        
        let imageEntries = entriesByPath.filter { (path, entry) in
            (path.starts(with: "images/") || path.starts(with: "/images/")) && entry.type == .file
        }
        
        return try imageEntries.reduce(into: [String: ImageValue]()) { result, element in
            guard element.value.type == .file else {
                throw CocoaError(.fileReadUnknown)
            }
            
            let imageData = try extractEntire(entry: element.value)
            
            guard let imageValue = ImageValue(data: imageData) else {
                throw CocoaError(.fileReadUnknown)
            }
            
            let fileurl = URL(fileURLWithPath: element.value.path, isDirectory: false)
            result[fileurl.lastPathComponent] = imageValue
        }
    }
    
    func extractMediaURLs() throws -> Set<URL> {
        Set(
            try filter {
                $0.type == .file && $0.path.hasPrefix("media/")
            }
                .map { entry in
                    let fm = FileManager()
                    let fileName = (entry.path as NSString).lastPathComponent
                    
                    let downloadURL = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(fileName, isDirectory: false)
                    try? fm.removeItem(at: downloadURL)
                    
                    try _ = self.extract(entry, to: downloadURL)
                    return downloadURL
                }
        )
    }
    
    func extractStringsTables() throws -> StringTable {
        let jsonDecoder = JSONDecoder()
        return try reduce(into: [:]) { result, entry in
            let segments = entry.path.split(separator: "/")
            guard segments.count == 2, segments.first == "localization", let fileNameComponents = segments.last?.split(separator: ".", maxSplits: 1), fileNameComponents.count == 2, fileNameComponents[1] == "json" else {
                // this ZIP entry is not a strings table. next.
                return
            }
            
            let table = try jsonDecoder.decode([StringKey: String].self, from: try extractEntire(entry: entry))
            result[LocaleIdentifier(fileNameComponents[0])] = table
        }
    }
    
    func extractFontURLs() throws -> Set<URL> {
        Set(
            try filter {
                $0.type == .file && $0.path.hasPrefix("fonts/")
            }
                .map { entry in
                    let fm = FileManager()
                    let fileName = (entry.path as NSString).lastPathComponent
                    
                    let downloadURL = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(fileName, isDirectory: false)
                    try? fm.removeItem(at: downloadURL)
                    
                    try _ = self.extract(entry, to: downloadURL)
                    return downloadURL
                }
        )
    }
}
