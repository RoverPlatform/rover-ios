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

public final class DocumentColor: Decodable {
    init(id: DocumentColor.ID = UUID(), name: String = "", color: ColorValue, variants: [Set<DocumentColor.Selector> : ColorValue] = [:]) {
        self.id = id
        self.name = name
        self.color = color
        self.variants = variants
    }
    
  
    public typealias ID = UUID
    
    public var id: ID = UUID()
    public var name: String = ""
    
    /// The base color, equivalent to Light Mode, in Normal Contrast mode.  If none of the variant selectors match, this one is selected.
    public var color: ColorValue
    public var variants: [Set<Selector>: ColorValue]
    
    public enum Selector: String, Hashable {
        case darkMode = "darkMode"
        case highContrast = "highContrast"
    }
    
    // MARK: Decodable
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case `default`
        case darkMode
        case highContrast
        case darkModeHighContrast
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(ColorValue.self, forKey: .default)
        variants = [Set<Selector>: ColorValue]()
        
        if container.contains(.darkMode) {
            variants[[.darkMode]] = try container.decode(ColorValue.self, forKey: .darkMode)
        }
        
        if container.contains(.highContrast) {
            variants[[.highContrast]] = try container.decode(ColorValue.self, forKey: .highContrast)
        }
        
        if container.contains(.darkModeHighContrast) {
            variants[[.darkMode, .highContrast]] = try container.decode(ColorValue.self, forKey: .darkModeHighContrast)
        }
    }
    
    // MARK: Resolution
    
    public func resolveColor(darkMode: Bool = false, highContrast: Bool = false) -> ColorValue {
        // prefer tightest match of selectors.  Fault backwards through tightest matches of selectors until getting to the base color.
        let variant: ColorValue?
        if darkMode, highContrast {
            variant = variants[[.darkMode, .highContrast]] ?? variants[[.darkMode]] ?? variants[[.highContrast]]
        } else if darkMode {
            variant = variants[[.darkMode]]
        } else if highContrast {
            variant = variants[[.highContrast]]
        } else {
            variant = nil
        }
        return variant ?? color
    }
}
