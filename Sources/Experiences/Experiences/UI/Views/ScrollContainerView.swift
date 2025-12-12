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

import Combine
import SwiftUI

struct ScrollContainerView: View {
    var scrollContainer: ScrollContainer

    var body: some View {
        SwiftUI.ScrollView(axis, showsIndicators: !scrollContainer.disableScrollBar) {
            switch scrollContainer.axis {
            case .horizontal:
                SwiftUI.HStack(spacing: 0) {
                    ForEach(orderedLayers) {
                        LayerView(layer: $0)
                    }
                }
            case .vertical:
                SwiftUI.VStack(spacing: 0) {
                    ForEach(orderedLayers) {
                        LayerView(layer: $0)
                    }
                }
            }
        }
        .modifier(RefreshModifier(scrollContainer: scrollContainer, axis: axis))
    }
    
    private var axis: SwiftUI.Axis.Set {
        switch scrollContainer.axis {
        case .horizontal:
            return .horizontal
        case .vertical:
            return .vertical
        }
    }
    
    private var orderedLayers: [Layer] {
        scrollContainer.children.compactMap { $0 as? Layer }
    }
}


private extension ScrollContainer {

    // Nested data source
    var nestedDataSources: [RoverExperiences.DataSource] {
        var dataSources: [DataSource] = []
        var queue: [Node] = [self]
        while !queue.isEmpty {
            let node = queue.removeLast()
            if let dataSource = node as? DataSource {
                dataSources.append(dataSource)
            } else {
                queue.append(contentsOf: node.children)
            }
        }
        return dataSources
    }
}


fileprivate struct RefreshModifier: ViewModifier {
    var scrollContainer: ScrollContainer
    var axis: SwiftUI.Axis.Set
    
    @ViewBuilder
    func body(content: Content) -> some View {
        // Enabling a refresh control only applies to ScrollContainers at the root of the screen
        if scrollContainer.parent is Screen,
           axis == .vertical,
           !scrollContainer.disableScrollBar,
           hasDataSources
        {
            content.refreshable {
                scrollContainer.nestedDataSources.forEach {
                    $0.objectWillChange.send()
                }
            }
        } else {
            content
        }
    }
    
    private var hasDataSources: Bool {
        !scrollContainer.nestedDataSources.isEmpty
    }
}
