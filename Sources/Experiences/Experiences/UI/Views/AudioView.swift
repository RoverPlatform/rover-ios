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
import SwiftUI
import AVKit
import Combine

struct AudioView: View {
    @Environment(\.data) private var data
    @Environment(\.urlParameters) private var urlParameters
    @Environment(\.userInfo) private var userInfo
    
    let audio: RoverExperiences.Audio

    var body: some View {
        if let urlString = audio.sourceURL.evaluatingExpressions(data: data, urlParameters: urlParameters, userInfo: userInfo), let sourceURL = URL(string: urlString) {
            Player(
                sourceURL: sourceURL,
                looping: audio.looping,
                autoPlay: audio.autoPlay
            )
            .modifier(AudioPlayerFrameModifier())
            // just in case URL changes.
            .id(urlString)
        }
    }
}

private struct Player: View {
    var sourceURL: URL
    var looping: Bool
    var autoPlay: Bool
    
    @State var player: AVPlayer? = nil
    @State var looper: AVPlayerLooper? = nil
    
    @Environment(\.pageDidDisappear) var pageDidDisappear
    @Environment(\.pageDidAppear) var pageDidAppear
    
    var body: some View {
        Group {
            if let player = self.player {
                AudioPlayerView(player: player, autoPlay: autoPlay)
            } else {
                // dummy view so onAppear below works.
                SwiftUI.Rectangle().frame(width: 0, height: 0).hidden()
            }
        }.onAppear {
            if (player == nil) {
                setupPlayer()
            } else {
                // resume playback if it was set to autoplay
                if autoPlay {
                    player?.play()
                }
            }
        }
        .onDisappear {
            player?.pause()
        }
        // the following two publisher listeners listen for messages sent down by CarouselView, to ensure that playback is paused/resumed correctly when paging between media in a carousel.
        .onReceive(pageDidDisappear, perform: { _ in
            player?.pause()
        })
        .onReceive(pageDidAppear, perform: { _ in
            // carousel page is (re-) appearing, (re)start playback.
            if autoPlay {
                player?.play()
            }
        })
    }
    
    func setupPlayer() {
        if (looping) {
            player = AVQueuePlayer()
        } else {
            player = AVPlayer()
        }
        
        let playerItem = AVPlayerItem(url: sourceURL)
        
        if looping, let queuePlayer = player as? AVQueuePlayer {
            self.looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        } else {
            self.player?.replaceCurrentItem(with: playerItem)
        }
    }
    
}

private struct AudioPlayerView: UIViewControllerRepresentable {
    var player: AVPlayer
    var autoPlay: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let viewController = AudioPlayerViewController(player: player)
        
        if autoPlay {
            player.play()
        }
        
        return viewController
    }
    
    func updateUIViewController(_ viewController: AVPlayerViewController, context: Context) {
       
    }
}

private class AudioPlayerViewController: AVPlayerViewController {
    init(player: AVPlayer) {
        super.init(nibName: nil, bundle: nil)
        
        self.player = player
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate struct AudioPlayerFrameModifier: ViewModifier {
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.frame(height: 110)
        } else {
            content.frame(height: 44)
        }
    }
}
