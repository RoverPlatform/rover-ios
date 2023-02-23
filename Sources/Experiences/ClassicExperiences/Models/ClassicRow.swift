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

public struct ClassicRow {
    public var background: ClassicBackground
    public var blocks: [ClassicBlock]
    public var height: ClassicHeight
    public var id: String
    public var name: String
    public var keys: [String: String]
    public var tags: [String]
    
    public init(background: ClassicBackground, blocks: [ClassicBlock], height: ClassicHeight, id: String, name: String, keys: [String: String], tags: [String]) {
        self.background = background
        self.blocks = blocks
        self.height = height
        self.id = id
        self.name = name
        self.keys = keys
        self.tags = tags
    }
}

// MARK: Decodable

extension ClassicRow: Decodable {
    enum CodingKeys: String, CodingKey {
        case background
        case blocks
        case height
        case id
        case name
        case keys
        case tags
    }
    
    enum BlockType: Decodable {
        case barcodeBlock
        case buttonBlock
        case imageBlock
        case rectangleBlock
        case textBlock
        case webViewBlock
        case textPollBlock
        case imagePollBlock
        
        enum CodingKeys: String, CodingKey {
            case typeName = "__typename"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeName = try container.decode(String.self, forKey: .typeName)
            switch typeName {
            case "BarcodeBlock":
                self = .barcodeBlock
            case "ButtonBlock":
                self = .buttonBlock
            case "ImageBlock":
                self = .imageBlock
            case "RectangleBlock":
                self = .rectangleBlock
            case "TextBlock":
                self = .textBlock
            case "WebViewBlock":
                self = .webViewBlock
            case "TextPollBlock":
                self = .textPollBlock
            case "ImagePollBlock":
                self = .imagePollBlock
            default:
                throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected one of BarcodeBlock, ButtonBlock, ImageBlock, RectangleBlock, TextBlock, WebViewBlock, TextPollBlock, ImagePollBlock – found \(typeName)")
            }
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        background = try container.decode(ClassicBackground.self, forKey: .background)
        height = try container.decode(ClassicHeight.self, forKey: .height)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        keys = try container.decode([String: String].self, forKey: .keys)
        tags = try container.decode([String].self, forKey: .tags)
        
        blocks = [ClassicBlock]()
        
        let blockTypes = try container.decode([BlockType].self, forKey: .blocks)
        var blocksContainer = try container.nestedUnkeyedContainer(forKey: .blocks)
        while !blocksContainer.isAtEnd {
            let block: ClassicBlock
            switch blockTypes[blocksContainer.currentIndex] {
            case .barcodeBlock:
                block = try blocksContainer.decode(ClassicBarcodeBlock.self)
            case .buttonBlock:
                block = try blocksContainer.decode(ClassicButtonBlock.self)
            case .imageBlock:
                block = try blocksContainer.decode(ClassicImageBlock.self)
            case .rectangleBlock:
                block = try blocksContainer.decode(ClassicRectangleBlock.self)
            case .textBlock:
                block = try blocksContainer.decode(ClassicTextBlock.self)
            case .webViewBlock:
                block = try blocksContainer.decode(ClassicWebViewBlock.self)
            case .textPollBlock:
                block = try blocksContainer.decode(ClassicTextPollBlock.self)
            case .imagePollBlock:
                block = try blocksContainer.decode(ClassicImagePollBlock.self)
            }
            blocks.append(block)
        }
    }
}
