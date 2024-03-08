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
            storyStyle: carousel.isStoryStyleEnabled,
            autoAdvanceDuration: carousel.storyAutoAdvanceDuration,
            currentPage: currentPage,
            numberOfPages: numberOfPages,
            viewID: viewID
        )
        .environment(\.carouselCurrentPage, currentPage.wrappedValue)
        .environment(\.carouselViewID, viewID)
        .onAppear {
            carouselState.storyStyleStatusForCarousel[viewID] = carousel.isStoryStyleEnabled
        }
        .id(pages)
    }
    
    private var viewID: ViewID {
        return ViewID(nodeID: carousel.id, collectionIndex: collectionIndex)
    }
    
    private var currentPage: Binding<Int> {
        return Binding {
            guard let currentPage = carouselState.currentPageForCarousel[viewID] else {
                if carousel.isStoryStyleEnabled {
                    carouselState.currentPageForCarousel[viewID] = carouselState.getPersistedPosition(for: viewID)
                }
                
                return carouselState.currentPageForCarousel[viewID] ?? 0
            }
            
            return currentPage
        } set: { newValue in
            carouselState.currentPageForCarousel[viewID] = newValue
            
            if carousel.isStoryStyleEnabled {
                carouselState.setPersistedPosition(for: viewID, newValue: newValue)
            }
        }
    }
    
    private var numberOfPages: Binding<Int> {
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
    private let storyStyle: Bool
    private let autoAdvanceDuration: Int
    private let viewID: ViewID
    @Binding private var currentPage: Int
    @Binding private var numberOfPages: Int
    
    @EnvironmentObject private var carouselState: CarouselState

    init(
        pages: [Page],
        loop: Bool,
        storyStyle: Bool,
        autoAdvanceDuration: Int,
        currentPage: Binding<Int>,
        numberOfPages: Binding<Int>,
        viewID: ViewID
    ) {
        self.pages = pages
        self.loop = loop
        self.storyStyle = storyStyle
        self.autoAdvanceDuration = autoAdvanceDuration
        self._currentPage = currentPage
        self._numberOfPages = numberOfPages
        self.viewID = viewID
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(
            self,
            carouselState: carouselState,
            viewID: viewID,
            loop: loop,
            autoAdvanceDuration: autoAdvanceDuration
        )
        
        if storyStyle {
            coordinator.controllers.forEach { controller in
                if let controller = controller as? CarouselPageHostController<Page> {
                    controller.autoAdvanceDelegate = coordinator
                }
            }
        }
        
        return coordinator
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
            
            // filter out unnecessary updates, which can have undesirable side effects.
            guard context.coordinator.lastUpdatedForPage != currentPage else {
                return
            }
            context.coordinator.lastUpdatedForPage = currentPage

            pageViewController.setViewControllers(
                [context.coordinator.controllers[currentPage]],
                direction: context.coordinator.direction,
                animated: true
            )
        }
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate, AutoAdvanceDelegate {
        var parent: PageViewController
        var controllers: [UIViewController]
        var loop: Bool
        var direction: UIPageViewController.NavigationDirection = .forward
        var carouselState: CarouselState
        var viewID: ViewID
        
        /// This tracks the value of `currentPage`, used for filtering out unnecessary updates being made to the page view controller's child view controller list, which is a side-effect of other data on CarouselState being updated.
        var lastUpdatedForPage: Int? = nil

        init(_ 
             pageViewController: PageViewController,
             carouselState: CarouselState,
             viewID: ViewID,
             loop: Bool,
             autoAdvanceDuration: Int
        ) {
            parent = pageViewController
            self.carouselState = carouselState
            self.loop = loop
            self.viewID = viewID
            controllers = parent.pages.enumerated().map { (index, page) in
                let controller = CarouselPageHostController(
                    pageContent: page,
                    autoAdvanceDuration: autoAdvanceDuration,
                    carouselState: carouselState,
                    index: index,
                    viewID: viewID
                )
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
        
        func advancePage() {
            if self.parent.currentPage + 1 < self.parent.numberOfPages {
                self.parent.currentPage += 1
                self.direction = .forward
            } else if loop {
                self.parent.currentPage = 0
                self.direction = .forward
            }
        }
        
        func previousPage() {
            if self.parent.currentPage > 0 {
                self.parent.currentPage -= 1
                self.direction = .reverse
            } else if loop {
                self.parent.currentPage = self.parent.numberOfPages - 1
                self.direction = .reverse
            }
        }
    }
}

/// This overload of UIHostingController exposes publishers in the SwiftUI environment to the page content to inform it when the carousel/uipageviewcontroller page is about to appear or disappear.
///
/// This is a workaround for the standard SwiftUI onAppear/onDisappear modifiers not working as expected within UIPageViewController.
internal class CarouselPageHostController<V>: UIHostingController<CarouselPageHostWrapperView<V>> where V: View {
    private var viewModel: ViewModel
    private var carouselState: CarouselState
    var autoAdvanceDuration: Int
    var index: Int
    var viewID: ViewID
    
    weak var autoAdvanceDelegate: AutoAdvanceDelegate? {
        didSet {
            self.rootView.autoAdvanceDelegate = autoAdvanceDelegate
        }
    }

    var mediaProgressObserver: AnyCancellable?
    var timer: Timer?
    
    private init(
        rootView: CarouselPageHostWrapperView<V>,
        viewModel: ViewModel,
        carouselState: CarouselState,
        autoAdvanceDuration: Int,
        index: Int,
        viewID: ViewID
    ) {
        self.viewModel = viewModel
        self.carouselState = carouselState
        self.autoAdvanceDuration = autoAdvanceDuration
        self.index = index
        self.viewID = viewID
        super.init(rootView: rootView)
    }
    
    convenience init(
        pageContent: V,
        autoAdvanceDuration: Int,
        carouselState: CarouselState,
        index: Int,
        viewID: ViewID
    ) {
        let viewModel: ViewModel = ViewModel()
        
        let rootView = CarouselPageHostWrapperView(
            content: pageContent,
            index: index,
            viewModel: viewModel
        )

        self.init(
            rootView: rootView,
            viewModel: viewModel,
            carouselState: carouselState,
            autoAdvanceDuration: autoAdvanceDuration,
            index: index,
            viewID: viewID
        )
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.stopTimer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        carouselState.setBarProgress(for: viewID, index: index, value: 0.0)
        
        mediaProgressObserver = viewModel.$mediaCurrentTime.sink { [weak self] currentTime in
            guard let host = self else {
                return
            }
            let mediaDuration = host.viewModel.mediaDuration
            
            guard mediaDuration > 0.0 else {
                return
            }
            
            host.carouselState.setBarProgress(for: host.viewID, index: host.index, value: currentTime / mediaDuration)
        }
        
        self.startTimer()
        
        super.viewDidAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.stopTimer()

        super.viewDidDisappear(animated)
    }
}

// MARK: Timer

extension CarouselPageHostController {
    func startTimer() {
        self.stopTimer()
        
        self.timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(0.167),
            repeats: true
        ) { [weak self] _ in
            guard let host = self else {
                return
            }
            
            if !(host.viewModel.isMediaPresent) {
                host.carouselState.addBarProgress(for: host.viewID, index: host.index, value: 0.167 / Double(host.autoAdvanceDuration))
                
                if host.carouselState.getBarProgress(for: host.viewID, index: host.index) >= 1.0 {
                    host.autoAdvanceDelegate?.advancePage()
                    host.stopTimer()
                }
            }
        }
    }
    
    func stopTimer() {
        guard let timer = self.timer else {
            return
        }
        
        timer.invalidate()
        self.timer = nil
    }
}

internal struct CarouselPageHostWrapperView<Content>: View where Content: View {
    var content: Content
    var index: Int
    
    var mediaDidFinishPlaying: PassthroughSubject<Void, Never>  = PassthroughSubject<Void, Never>()
    var mediaCurrentTimePlaying: CurrentValueSubject<TimeInterval, Never> = CurrentValueSubject<TimeInterval, Never>(0.0)
    var mediaDuration: CurrentValueSubject<TimeInterval, Never> = CurrentValueSubject<TimeInterval, Never>(0.0)
    weak var autoAdvanceDelegate: AutoAdvanceDelegate?
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        content
            .environment(\.carouselPageNumber, index)
            .environment(\.mediaDidFinishPlaying, mediaDidFinishPlaying)
            .environment(\.mediaCurrentTime, mediaCurrentTimePlaying)
            .environment(\.mediaDuration, mediaDuration)
            .onPreferenceChange(IsMediaPresentKey.self) { value in
                viewModel.isMediaPresent = value
            }
            .onReceive(mediaDidFinishPlaying) {
                if viewModel.isMediaPresent {
                    autoAdvanceDelegate?.advancePage()
                }
            }
            .onReceive(mediaCurrentTimePlaying) { time in
                viewModel.mediaCurrentTime = time
            }
            .onReceive(mediaDuration) { duration in
                viewModel.mediaDuration = duration
            }
            .modifier(AutoAdvanceModifier(autoAdvanceDelegate: autoAdvanceDelegate))
    }
}

internal protocol AutoAdvanceDelegate: AnyObject {
    func advancePage()
    func previousPage()
}

class ViewModel: ObservableObject {
    @Published var isMediaPresent = false
    @Published var mediaDuration: TimeInterval = 0.0
    @Published var mediaCurrentTime: TimeInterval = 0.0
}

fileprivate struct AutoAdvanceModifier: ViewModifier {
    weak var autoAdvanceDelegate: AutoAdvanceDelegate?
    
    func body(content: Content) -> some View {
        if let autoAdvanceDelegate = self.autoAdvanceDelegate,
            #available(iOS 17, *) {
            GeometryReader { geometry in
                content
                    .onTapGesture { location in
                        if location.x > (geometry.frame(in: .local).width * 0.15) {
                            autoAdvanceDelegate.advancePage()
                        } else {
                            autoAdvanceDelegate.previousPage()
                        }
                    }
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
            }
        } else {
            content
        }
    }
}
