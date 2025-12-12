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
import RoverFoundation

struct StoryControlView: View {
    @Environment(\.collectionIndex) private var collectionIndex
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.data) private var data
    @Environment(\.urlParameters) private var urlParameters
    @Environment(\.userInfo) private var userInfo
    
    @EnvironmentObject private var carouselState: CarouselState
    let pageControl: PageControl
    let viewID: ViewID
    
    var body: some View {
        switch pageControl.style {
        case .`default`:
            switch colorScheme {
            case .dark:
                StoryControlViewBody(
                    numberOfPages: numberOfPages,
                    currentPage: currentPage,
                    viewID: viewID,
                    hidesForSinglePage: pageControl.hidesForSinglePage,
                    normalColor: Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.3),
                    currentColor: Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)
                )
            default: // case .light:
                StoryControlViewBody(
                    numberOfPages: numberOfPages,
                    currentPage: currentPage,
                    viewID: viewID,
                    hidesForSinglePage: pageControl.hidesForSinglePage,
                    normalColor: Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.3),
                    currentColor: Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0)
                )
            }
        case .light:
            StoryControlViewBody(
                numberOfPages: numberOfPages,
                currentPage: currentPage,
                viewID: viewID,
                hidesForSinglePage: pageControl.hidesForSinglePage,
                normalColor: Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.3),
                currentColor: Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)
            )
        case .dark:
            StoryControlViewBody(
                numberOfPages: numberOfPages,
                currentPage: currentPage,
                viewID: viewID,
                hidesForSinglePage: pageControl.hidesForSinglePage,
                normalColor: Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.3),
                currentColor: Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0)
            )
        case .inverted:
            switch colorScheme {
            
            case .dark:
                StoryControlViewBody(
                    numberOfPages: numberOfPages,
                    currentPage: currentPage,
                    viewID: viewID,
                    hidesForSinglePage: pageControl.hidesForSinglePage,
                    normalColor: Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.3),
                    currentColor: Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0)
                )
            default: // .light:
                StoryControlViewBody(
                    numberOfPages: numberOfPages,
                    currentPage: currentPage,
                    viewID: viewID,
                    hidesForSinglePage: pageControl.hidesForSinglePage,
                    normalColor: Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.3),
                    currentColor: Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)
                )
            }
        case let .custom(normalColor, currentColor):
            RealizeColor(normalColor) { normalColor in
                RealizeColor(currentColor) { currentColor in
                    StoryControlViewBody(
                        numberOfPages: numberOfPages,
                        currentPage: currentPage,
                        viewID: viewID,
                        hidesForSinglePage: pageControl.hidesForSinglePage,
                        normalColor: normalColor,
                        currentColor: currentColor
                    )
                }
            }
        case .image(_, _, _, _):
            EmptyView()
        }
    }
    
    private var currentPage: Binding<Int> {
        return Binding {
            carouselState.currentPageForCarousel[viewID] ?? 0
        } set: { newValue in
            carouselState.currentPageForCarousel[viewID] = newValue
        }
    }
    
    private var numberOfPages: Binding<Int> {
        return Binding {
            carouselState.currentNumberOfPagesForCarousel[viewID] ?? 0
        } set: { newValue in
            carouselState.currentNumberOfPagesForCarousel[viewID] = newValue
        }
    }
}

fileprivate struct StoryControlViewBody: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding private var numberOfPages: Int
    @Binding private var currentPage: Int
    private var hidesForSinglePage: Bool
    private var viewID: ViewID

    private let normalColor: Color
    private let currentColor: Color
    
    @EnvironmentObject private var carouselState: CarouselState
    
    init(
        numberOfPages: Binding<Int>,
        currentPage: Binding<Int>,
        viewID: ViewID,
        hidesForSinglePage: Bool,
        normalColor: Color,
        currentColor: Color
    ) {
        self._numberOfPages = numberOfPages
        self._currentPage = currentPage
        self.viewID = viewID
        self.hidesForSinglePage = hidesForSinglePage
        self.normalColor = normalColor
        self.currentColor = currentColor
    }

    var body: some View {
        SwiftUI.HStack(spacing: 3) {
            ForEach(0..<numberOfPages, id:\.self) { pageNumber in
                let barProgress = barProgress(for: pageNumber)
                GeometryReader { proxy in
                    SwiftUI.ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(normalColor)

                        // progress bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(currentColor)
                            .frame(width: proxy.size.width * barProgress)
                            .modifier(
                                StoryControlAnimationModifier(barProgress: barProgress)
                            )
                    }
                    .onChange(of: currentPage) { _, _ in
                        carouselState.resetBarProgress(for: viewID)
                    }
                }
                    .frame(height: 3)
            }
        }
        .padding(14)
    }
    
    private func barProgress(for pageNumber: Int) -> Double {
        return pageNumber == currentPage ? carouselState.getBarProgress(for: viewID, index: currentPage) : (pageNumber < currentPage ? 1.0 : 0.0)
    }
}

fileprivate struct StoryControlAnimationModifier: ViewModifier {
    var barProgress: Double
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if barProgress > 0.0 {
            content
                .animation(.linear(duration: 0.167), value: barProgress)
        } else {
            content
        }
    }
}
