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

import RoverFoundation
import SafariServices
import SwiftUI
import os.log

struct ScreenDestination: Hashable, Identifiable {
    let id = UUID()
    let screen: Screen
    let data: Any?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScreenDestination, rhs: ScreenDestination) -> Bool {
        lhs.id == rhs.id
    }
}

struct ScreenView: View {
    let experience: ExperienceModel
    let screen: Screen
    let data: Any?
    let urlParameters: [String: String]
    let userInfo: [String: Any]
    let deviceContext: [String: Any] = Rover.shared.deviceContext
    let authorizers: Authorizers
    let carouselState: CarouselState
    let experienceManager: ExperienceManager

    // Modal state for this screen
    @State private var fullScreenModal: ScreenDestination?
    @State private var screenModal: ScreenDestination?
    @State private var safariURL: SafariURL?

    // Navigation path for when this is a modal (manages own navigation)
    @State private var modalNavigationPath = NavigationPath()
    // Navigation path for the ScreenView
    @Binding var path: NavigationPath

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(
        experience: ExperienceModel,
        screen: Screen,
        data: Any?,
        urlParameters: [String: String],
        userInfo: [String: Any],
        authorizers: Authorizers,
        carouselState: CarouselState,
        experienceManager: ExperienceManager,
        path: Binding<NavigationPath>
    ) {
        self.experience = experience
        self.screen = screen
        self.data = data
        self.urlParameters = urlParameters
        self.userInfo = userInfo
        self.authorizers = authorizers
        self.carouselState = carouselState
        self.experienceManager = experienceManager
        self._path = path
    }

    var body: some View {
        screenContent
            .environment(\.navigationPath, $path)
            .environment(\.presentWebsiteAction) { url in
                safariURL = url
            }
            .environment(\.dismissAction) {
                dismiss()
            }
            .environment(\.fullScreenModal) { destination in
                fullScreenModal = destination
            }
            .environment(\.screenModal) { destination in
                screenModal = destination
            }
            .fullScreenCover(item: $safariURL) { safariURL in
                SafariView(url: safariURL.url)
                    .ignoresSafeArea()
            }
            .sheet(item: $screenModal) { destination in
                modalScreenView(destination: destination)
            }
            .fullScreenCover(item: $fullScreenModal) { destination in
                modalScreenView(destination: destination)
            }
            // Reset the modal navigation path whenever a modal is presented,
            // dismissed, or switched. This is the single source of truth for
            // path resets — callers only need to set the destination and the
            // reactive handler ensures a fresh NavigationPath.
            .onChange(of: screenModal) { _, _ in
                modalNavigationPath = NavigationPath()
            }
            .onChange(of: fullScreenModal) { _, _ in
                modalNavigationPath = NavigationPath()
            }
            // When the navigation path changes externally (e.g., HubCoordinator
            // resetting the path during push notification navigation), dismiss any
            // modals this screen is presenting. This ensures nested modal stacks
            // are torn down when navigating to a new destination.
            .onChange(of: path) { _, _ in
                screenModal = nil
                fullScreenModal = nil
                safariURL = nil
            }
    }

    private var screenContent: some View {
        RealizeColor(screen.backgroundColor) { backgroundColor in
            SwiftUI.ZStack {
                backgroundColor.ignoresSafeArea()
                ForEach(children, id: \.id) { layer in
                    viewForLayer(layer)
                }
            }
        }
        .optionalNavigationTitle(resolvedTitle)
        // When the navigationBar is nil (i.e. the experience author
        // has not added a navigation bar to the screen), we must not set a
        // toolbarTitleDisplayMode at all. Previously we defaulted to
        // `.automatic`, which lets SwiftUI decide how the title display mode
        // should be rendered. When an ancestor view (e.g. HubContentView) forces the
        // navigation bar visible to show toolbar items like the inbox button,
        // `.automatic` could cause SwiftUI to render the navigation bar
        // in an unexpected way.
        //
        // By making the modifier conditional (only applying it when a
        // navigationBar exists), we avoid interfering with how ancestor
        // views display the navigation bar.
        .optionalTitleDisplayMode(navigationBar?.titleDisplayMode)
        .navigationBarVisibility(navigationBar == nil ? .hidden : .visible)
        .navigationBarBackButtonHidden(navigationBar?.hidesBackButton ?? false)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                ForEach(leadingButtons, id: \.id) { button in
                    navBarButton(button)
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ForEach(trailingButtons, id: \.id) { button in
                    navBarButton(button)
                }
            }
        }
        .toolbarColorScheme(statusBarStyle: screen.statusBarStyle, colorScheme: colorScheme)
        .environment(\.data, data)
        .onAppear {
            NotificationCenter.default.post(
                name: ExperienceManager.screenViewedNotification,
                object: nil,
                userInfo: [
                    "experience": experience,
                    "screen": screen,
                    "campaignID": urlParameters["campaignID"] as Any,
                    "data": data as Any,
                ]
            )
        }
    }

    @ViewBuilder
    private func modalScreenView(destination: ScreenDestination) -> some View {
        NavigationStack(path: $modalNavigationPath) {
            ScreenView(
                experience: experience,
                screen: destination.screen,
                data: destination.data,
                urlParameters: urlParameters,
                userInfo: userInfo,
                authorizers: authorizers,
                carouselState: carouselState,
                experienceManager: experienceManager,
                path: $modalNavigationPath
            )
            .navigationDestination(for: ScreenDestination.self) { navDestination in
                ScreenView(
                    experience: experience,
                    screen: navDestination.screen,
                    data: navDestination.data,
                    urlParameters: urlParameters,
                    userInfo: userInfo,
                    authorizers: authorizers,
                    carouselState: carouselState,
                    experienceManager: experienceManager,
                    path: $modalNavigationPath
                )
            }
        }
    }

    private var children: [Layer] {
        screen.children.compactMap { $0 as? Layer }.reversed()
    }

    var navigationBar: NavBar? {
        screen.children.first(where: { $0 is NavBar }) as? NavBar
    }

    private var resolvedTitle: String? {
        guard let navBar = navigationBar else { return nil }
        let title = navBar.title
        guard !title.isEmpty else { return nil }
        return experience.localization.resolve(key: title)
            .evaluatingExpressions(
                data: data,
                urlParameters: urlParameters,
                userInfo: userInfo,
                deviceContext: deviceContext
            )
    }

    private func edgeSetFromLayer(_ layer: Layer) -> Edge.Set {
        layer.ignoresSafeArea?.reduce(into: Edge.Set()) { result, edge in
            result.insert(Edge.Set(edge))
        } ?? []
    }

    private var leadingButtons: [NavBarButton] {
        navigationBar?.children
            .compactMap { $0 as? NavBarButton }
            .filter { $0.placement == .leading } ?? []
    }

    private var trailingButtons: [NavBarButton] {
        navigationBar?.children
            .compactMap { $0 as? NavBarButton }
            .filter { $0.placement == .trailing } ?? []
    }

    @ViewBuilder
    private func navBarButton(_ button: NavBarButton) -> some View {
        Button {
            handleNavBarButtonTap(button)
        } label: {
            navBarButtonLabel(button)
        }
    }

    @ViewBuilder
    private func navBarButtonLabel(_ button: NavBarButton) -> some View {
        switch button.style {
        case .close:
            SwiftUI.Image(systemName: "xmark")
        case .done:
            SwiftUI.Text("Done")
        case .custom:
            if let icon = button.icon {
                SwiftUI.Image(systemName: icon.symbolName)
            } else if let title = button.title {
                SwiftUI.Text(
                    experience.localization.resolve(key: title)
                        .evaluatingExpressions(
                            data: data,
                            urlParameters: urlParameters,
                            userInfo: userInfo,
                            deviceContext: deviceContext
                        ) ?? ""
                )
            }
        }
    }

    private func handleNavBarButtonTap(_ button: NavBarButton) {
        switch button.style {
        case .close, .done:
            dismiss()
        case .custom:
            button.action?.handle(
                experience: experience,
                node: button,
                screen: screen,
                data: data,
                urlParameters: urlParameters,
                userInfo: userInfo,
                deviceContext: deviceContext,
                authorizers: authorizers,
                path: $path,
                presentWebsiteAction: { url in safariURL = url },
                dismissAction: { dismiss() },
                fullScreenModal: { destination in
                    fullScreenModal = destination
                },
                screenModal: { destination in
                    screenModal = destination
                }
            )
        }
    }

    private func viewForLayer(_ layer: Layer) -> some View {
        LayerView(layer: layer)
            .environmentObject(carouselState)
            .environment(\.experienceManager, experienceManager)
            .environment(\.experience, experience)
            .environment(\.screen, screen)
            .environment(\.stringTable, experience.localization)
            .environment(\.urlParameters, urlParameters)
            .environment(\.userInfo, userInfo)
            .environment(\.deviceContext, deviceContext)
            .environment(\.authorizers, authorizers)
            .ignoresSafeArea(edges: edgeSetFromLayer(layer))
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // no-op
    }
}

struct SafariURL: Identifiable {
    let url: URL

    var id: String {
        url.absoluteString
    }
}

extension View {
    /// Conditionally applies a `toolbarTitleDisplayMode` only when a display
    /// mode is provided. When `nil`, no modifier is applied at all, which
    /// avoids letting SwiftUI decide the title display mode via `.automatic`
    /// — a decision that isn't always correct and can cause the navigation
    /// bar to render unexpectedly.
    @ViewBuilder
    func optionalTitleDisplayMode(_ titleDisplayMode: NavBar.TitleDisplayMode?) -> some View {
        if let titleDisplayMode {
            switch titleDisplayMode {
            case .inline:
                self.toolbarTitleDisplayMode(.inline)
            case .large:
                self.toolbarTitleDisplayMode(.large)
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func optionalNavigationTitle(_ title: String?) -> some View {
        if let title {
            self.navigationTitle(title)
        } else {
            self
        }
    }

    @ViewBuilder
    func navigationBarVisibility(_ visibility: Visibility) -> some View {
        if #available(iOS 18.0, *) {
            self.toolbarVisibility(visibility, for: .navigationBar)
        } else {
            self.toolbar(visibility, for: .navigationBar)
        }
    }

    @ViewBuilder
    func toolbarColorScheme(statusBarStyle: StatusBarStyle, colorScheme: ColorScheme) -> some View {
        switch statusBarStyle {
        case .default:
            self
        case .light:
            self.toolbarColorScheme(.dark, for: .navigationBar)
        case .dark:
            self.toolbarColorScheme(.light, for: .navigationBar)
        case .inverted:
            self.toolbarColorScheme(colorScheme == .dark ? .light : .dark, for: .navigationBar)
        }
    }
}
