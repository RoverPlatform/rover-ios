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
import Combine

struct CarouselView: View {
    @Environment(\.collectionIndex) private var collectionIndex
    @Environment(\.data) private var data
    @Environment(\.urlParameters) private var urlParameters
    @Environment(\.userInfo) private var userInfo
    
    let carousel: Carousel

    @EnvironmentObject private var carouselState: CarouselState

    var body: some View {
        PageViewController(
            pages: pages,
            loop: carousel.isLoopEnabled,
            currentPage: currentPage,
            numberOfPages: numberOfPages
        )
        .id(pages)
    }
    
    private var currentPage: Binding<Int> {
        let viewID = ViewID(nodeID: carousel.id, collectionIndex: collectionIndex)
        
        return Binding {
            carouselState.currentPageForCarousel[viewID] ?? 0
        } set: { newValue in
            carouselState.currentPageForCarousel[viewID] = newValue
        }
    }
    
    private var numberOfPages: Binding<Int> {
        let viewID = ViewID(nodeID: carousel.id, collectionIndex: collectionIndex)
        
        return Binding {
            carouselState.currentNumberOfPagesForCarousel[viewID] ?? 0
        } set: { newValue in
            carouselState.currentNumberOfPagesForCarousel[viewID] = newValue
        }
    }
    
    private var pages: [Page] {
        func generatePages(node: Node, item: Any? = nil) -> [Page] {
            switch node {
            case let collection as Collection:
                let collectionItems = collection.items(
                    data: item,
                    urlParameters: urlParameters,
                    userInfo: userInfo
                )
                
                return collectionItems.flatMap { collectionItem in
                    collection.children.flatMap { child -> [Page] in
                        generatePages(node: child, item: collectionItem)
                    }
                }
                
            case let conditional as Conditional:
                if !conditional.allConditionsSatisfied(
                    data: item,
                    urlParameters: urlParameters,
                    userInfo: userInfo
                ) {
                    return []
                }
                
                return conditional.children.flatMap { child -> [Page] in
                    generatePages(node: child, item: item)
                }
                
            case let carousel as Carousel:
                return carousel.children.flatMap { child -> [Page] in
                    generatePages(node: child, item: item)
                }
                
            case let layer as Layer:
                return [Page(layer: layer, carouselState: carouselState, item: item)]
                
            default:
                return []
            }
        }

        return generatePages(node: carousel, item: data)
    }
}

private struct Page: View, Hashable, Identifiable {
    var id: String

    /// Injecting CarouselState through here in order to re-add it to Environment. This is to work around an apparent
    /// bug in SwiftUI where, at certain lifecycle points, view body evaluations of the page's contents may occur without
    /// the environment fully hooked up.
    ///
    /// That bug was causing a downstream crash in the page control.
    var carouselState: CarouselState

    var layer: Layer
    var item: Any?
    
    static func == (lhs: Page, rhs: Page) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    init(layer: Layer, carouselState: CarouselState, item: Any? = nil) {
        self.layer = layer
        self.carouselState = carouselState
        self.item = item
        
        if let item = item,
           let idString = try? JSONSerialization.data(withJSONObject: item).toString() {
            self.id = idString
        } else {
            self.id = layer.id
        }
    }
    
    var body: some View {
        if let item = item {
            LayerView(layer: layer).environment(\.data, item).environmentObject(carouselState)
        } else {
            LayerView(layer: layer)
                .environmentObject(carouselState)
                // safe areas are enforced at the screen children level only.
                .edgesIgnoringSafeArea(.all)
        }
    }
}

private struct PageViewController: UIViewControllerRepresentable {
    private let pages: [Page]
    private let loop: Bool
    @Binding private var currentPage: Int
    @Binding private var numberOfPages: Int

    init(pages: [Page], loop: Bool, currentPage: Binding<Int>, numberOfPages: Binding<Int>) {
        self.pages = pages
        self.loop = loop
        self._currentPage = currentPage
        self._numberOfPages = numberOfPages
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, loop: loop)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal)
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        
        self.numberOfPages = self.pages.count

        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.loop = self.loop
        
        if !context.coordinator.controllers.isEmpty {
            guard context.coordinator.controllers.indices.contains(currentPage) else {
                // Carousel contents are now smaller while viewing a larger index
                
                // Reset current page
                currentPage = 0
                
                // Make the first view controller of the current set visible
                pageViewController.setViewControllers(
                    [context.coordinator.controllers[0]],
                    direction: .forward,
                    animated: true
                )
                return
            }

            pageViewController.setViewControllers(
                [context.coordinator.controllers[currentPage]],
                direction: .forward,
                animated: true
            )
        }
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageViewController
        var controllers: [UIViewController]
        var loop: Bool

        init(_ pageViewController: PageViewController, loop: Bool) {
            parent = pageViewController
            self.loop = loop
            controllers = parent.pages.map {
                let controller = CarouselPageHostController(pageContent: $0)
                controller.view.backgroundColor = .clear
                return controller
            }
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController) else {
                return nil
            }

            if index > 0 {
                return controllers[index - 1]
            } else if loop {
                return controllers.last
            } else {
                return nil
            }
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController) else {
                return nil
            }

            if index + 1 < controllers.count {
                return controllers[index + 1]
            } else if loop {
                return controllers.first
            } else {
                return nil
            }
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed,
               let visibleViewController = pageViewController.viewControllers?.first,
               let index = controllers.firstIndex(of: visibleViewController)
            {
                parent.currentPage = index
            }
        }
    }
}

/// This overload of UIHostingController exposes publishers in the SwiftUI environment to the page content to inform it when the carousel/uipageviewcontroller page is about to appear or disappear.
///
/// This is a workaround for the standard SwiftUI onAppear/onDisappear modifiers not working as expected within UIPageViewController.
internal class CarouselPageHostController<V>: UIHostingController<CarouselPageHostWrapperView<V>> where V: View {
    private var pageDidDisappear = PassthroughSubject<Void, Never>()
    private var pageDidAppear = PassthroughSubject<Void, Never>()
    
    override init(rootView: CarouselPageHostWrapperView<V>) {
        super.init(
            rootView: rootView
        )
    }
    
    convenience init(pageContent: V) {
        self.init(rootView: CarouselPageHostWrapperView(content: pageContent, pageDidDisappear: PassthroughSubject<Void, Never>(), pageDidAppear: PassthroughSubject<Void, Never>()))
        self.rootView = CarouselPageHostWrapperView(content: pageContent, pageDidDisappear: pageDidDisappear, pageDidAppear: pageDidAppear)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        pageDidAppear.send()
        super.viewDidAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        pageDidDisappear.send()
        super.viewDidDisappear(animated)
    }
}

internal struct CarouselPageHostWrapperView<Content>: View where Content: View {
    var content: Content
    
    var pageDidDisappear: PassthroughSubject<Void, Never>
    var pageDidAppear: PassthroughSubject<Void, Never>
    
    var body: some View {
        content
            .environment(\.pageDidDisappear, pageDidDisappear.eraseToAnyPublisher())
            .environment(\.pageDidAppear, pageDidAppear.eraseToAnyPublisher())
    }
}
