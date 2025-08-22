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

import RoverData
import RoverFoundation
import SwiftUI

/// Embed this view within a tab to integrate the Rover Communication Hub.
public struct CommunicationHubView: View {
  var title: String?
  var accentColor: Color
  var navigationBarBackgroundColor: Color? = nil
  var navigationBarColorScheme: ColorScheme? = nil

  @StateObject var navigator: CommunicationHubNavigator = CommunicationHubNavigator()

  public init(title: String? = nil, accentColor: Color = .accentColor, navigationBarBackgroundColor: Color? = nil, navigationBarColorScheme: ColorScheme? = nil) {
    self.title = title
    self.accentColor = accentColor
    self.navigationBarBackgroundColor = navigationBarBackgroundColor
    self.navigationBarColorScheme = navigationBarColorScheme
  }

  public init(
    navigator: CommunicationHubNavigator, title: String? = nil, accentColor: Color = .accentColor, navigationBarBackgroundColor: Color? = nil, navigationBarColorScheme: ColorScheme? = nil
  ) {
    self._navigator = StateObject(wrappedValue: navigator)
    self.title = title
    self.accentColor = accentColor
    self.navigationBarBackgroundColor = navigationBarBackgroundColor
    self.navigationBarColorScheme = navigationBarColorScheme
  }

  public var body: some View {
    ContentView(
      navigator: navigator,
      navigationBarBackgroundColor: navigationBarBackgroundColor,
      navigationBarColorScheme: navigationBarColorScheme
    )
      .environment(\.communicationHubContainer, persistentContainer)
      .environment(\.managedObjectContext, persistentContainer.viewContext)
      .environment(\.refreshCommunicationHub, { await refreshPosts() })
      .environment(\.rchSync, rchSync)
      .environment(\.eventQueue, Rover.shared.eventQueue)
      .environment(\.roverCommunicationHubAccentColor, accentColor)
      .tint(accentColor)
  }

  var persistentContainer: RCHPersistentContainer {
    Rover.shared.resolve(RCHPersistentContainer.self)!
  }

  var rchSync: RCHSync {
    Rover.shared.resolve(RCHSync.self)!
  }

  func refreshPosts() async {
    await Rover.shared.resolve(SyncCoordinator.self)!.syncAsync()
  }
}

private struct ContentView: View {
  @ObservedObject var navigator: CommunicationHubNavigator

  var navigationBarBackgroundColor: Color?
  var navigationBarColorScheme: ColorScheme?

  @Environment(\.isPresented) private var isPresented
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack(path: $navigator.navigationPath) {
      contentWithNavBackground
        .toolbar {
          if isPresented {
            ToolbarItem(placement: .navigationBarTrailing) {
              Button("Done") {
                dismiss()
              }
            }
          }
        }
    }
  }

  var listContent: some View {
    PostsListView(navigationPath: $navigator.navigationPath, navigator: navigator, navigationBarBackgroundColor: navigationBarBackgroundColor, navigationBarColorScheme: navigationBarColorScheme)
      .navigationTitle("Inbox")
      .toolbarColorScheme(navigationBarColorScheme, for: .navigationBar)
  }

  @ViewBuilder
  var contentWithNavBackground: some View {
    if let navigationBarBackgroundColor {
      listContent
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(navigationBarBackgroundColor, for: .navigationBar)
    } else {
      listContent
    }
  }
}

private struct PreviewContent: View {
  var title: String?

  var body: some View {
    let container = RCHPersistentContainer(storage: .inMemory)
    container.loadSampleData()

    return ContentView(navigator: CommunicationHubNavigator())
      .environment(\.communicationHubContainer, container)
      .environment(\.managedObjectContext, container.viewContext)
      .environment(\.refreshCommunicationHub) {
        // simulate a delay from user refreshing.
        do {
          try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
          // Ignore errors in preview
        }
      }
  }
}

#Preview("Dark Mode") {
  PreviewContent()
    .preferredColorScheme(.dark)
    .tint(Color(red: 0.067, green: 0.341, blue: 0.251))  // #115740
}

#Preview("Light Mode") {
  PreviewContent()
    .preferredColorScheme(.light)
    .tint(Color(red: 0.067, green: 0.341, blue: 0.251))  // #115740
}
