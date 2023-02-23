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



struct LayerView: View {
    var layer: Layer
    
    var body: some View {
        content
            .modifier(LayerViewModifier(layer: layer))
    }
    
    @ViewBuilder private var content: some View {
        switch layer {
        case let scrollContainer as RoverExperiences.ScrollContainer:
            ScrollContainerView(scrollContainer: scrollContainer)
        case let stack as RoverExperiences.HStack:
            HStackView(stack: stack)
        case let image as RoverExperiences.Image:
            ImageView(image: image)
        case let icon as RoverExperiences.Icon:
            IconView(icon: icon)
        case let text as RoverExperiences.Text:
            TextView(text: text)
        case let rectangle as RoverExperiences.Rectangle:
            RectangleView(rectangle: rectangle)
        case let stack as RoverExperiences.VStack:
            VStackView(stack: stack)
        case _ as RoverExperiences.Spacer:
            SwiftUI.Spacer().frame(minWidth: 0, minHeight: 0).layoutPriority(-1)
        case let divider as RoverExperiences.Divider: 
            DividerView(divider: divider)
        case let webView as RoverExperiences.WebView:
            WebViewView(webView: webView)
        case let stack as RoverExperiences.ZStack:
            ZStackView(stack: stack)
        case let carousel as RoverExperiences.Carousel:
            CarouselView(carousel: carousel)
        case let pageControl as RoverExperiences.PageControl:
            PageControlView(pageControl: pageControl)
        case let video as RoverExperiences.Video:
            VideoView(video: video)
        case let audio as RoverExperiences.Audio:
            AudioView(audio: audio)
        case let dataSource as RoverExperiences.DataSource:
            DataSourceView(dataSource: dataSource)
        case let collection as RoverExperiences.Collection:
            CollectionView(collection: collection)
        case let conditional as RoverExperiences.Conditional:
            ConditionalView(conditional: conditional)
        default:
            EmptyView()
        }
    }
}


struct LayerViewModifier: ViewModifier {
    var layer: Layer
    
    func body(content: Content) -> some View {
        content
            .modifier(
                AspectRatioModifier(node: layer)
            )
            .modifier(
                PaddingModifier(node: layer)
            )
            .modifier(
                FrameModifier(node: layer)
            )
            .modifier(
                LayoutPriorityModifier(node: layer)
            )
            .modifier(
                ShadowModifier(node: layer)
            )
            .modifier(
                OpacityModifier(node: layer)
            )
            .modifier(
                BackgroundModifier(node: layer)
            )
            .modifier(
                OverlayModifier(node: layer)
            )
            .modifier(
                MaskModifier(node: layer)
            )
            .contentShape(
                SwiftUI.Rectangle()
            )
            .modifier(
                AccessibilityModifier(node: layer)
            )
            .modifier(
                ActionModifier(layer: layer)
            )
            .modifier(
                OffsetModifier(node: layer)
            )
            .modifier(
                IgnoresSafeAreaModifier(node: layer)
            )
    }
}
