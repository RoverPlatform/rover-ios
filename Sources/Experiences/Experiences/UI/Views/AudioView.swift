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
    @State var didPlayToEndTimeObserver: NSObjectProtocol? = nil
    @State var willEnterForegroundObserver: NSObjectProtocol? = nil
    @State var playerCurrentTimeObserver: Any? = nil
    @State var playerDuration: TimeInterval = 0.0
    
    @Environment(\.mediaDidFinishPlaying) var mediaDidFinishPlaying
    @Environment(\.mediaCurrentTime) var mediaCurrentTime
    @Environment(\.mediaDuration) var mediaDuration
    
    // For coordinating with carousel/stories.
    @EnvironmentObject var carouselState: CarouselState
    @Environment(\.carouselViewID) var carouselViewID
    @Environment(\.carouselPageNumber) var carouselPageNumber
    @Environment(\.carouselCurrentPage) var carouselCurrentPage
    
    var body: some View {
        if let player = self.player {
            AudioPlayerView(player: player, autoPlay: autoPlay)
                .preference(key: IsMediaPresentKey.self, value: true)
                .onAppear {
                    addObservers()
                    
                    if autoPlay && (carouselPageNumber == carouselCurrentPage) {
                        player.play()
                    }
                }
                .onValueChanged(of: carouselCurrentPage) { carouselCurrentPage in
                    if autoPlay && (carouselCurrentPage == carouselPageNumber) {
                        // when being revealed in a carousel, we should seek to the beginning and resume if autoplay
                        player.seek(to: CMTime.zero)
                        player.play()
                    } else {
                        player.pause()
                    }
                }
                .onDisappear {
                    removeObservers()
                    player.pause()
                }
            
        } else {
            SwiftUI.Rectangle()
                .frame(width: 0, height: 0)
                .hidden()
                .onAppear {
                    if (player == nil) {
                        setupPlayer()
                    }
                }
        }
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
        
        if #available(iOS 15.0, *) {
            player?.audiovisualBackgroundPlaybackPolicy = .pauses
        }
    }
    
    private func addObservers() {
        guard let player = player else {
            return
        }
        
        if self.playerCurrentTimeObserver == nil {
            let interval = CMTime(value: 1, timescale: 60)
            self.playerCurrentTimeObserver = player.addPeriodicTimeObserver(
                forInterval: interval,
                queue: .main
            ) { time in
                mediaCurrentTime.send(time.seconds)
                mediaDuration.send(player.currentItem?.duration.seconds ?? 0.0)
            }
        }
        
        if self.didPlayToEndTimeObserver == nil {
            self.didPlayToEndTimeObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                mediaDidFinishPlaying.send()
            }
        }
        
        if self.willEnterForegroundObserver == nil {
            self.willEnterForegroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { _ in
                // resume playback of autoplay videos when returning from background.
                // however, when present in a carousel, we want to be sure we are the current page before autoplaying.
                // also, with carousels, we cannot use the \.carouselCurrentPage environment value in this context since it is a changing value that will be stale in this context where this callback closure has an old captured view struct without an up-to-date environment variable. To work around this, we will retrieve the carousel's current page directly from CarouselState.
                if let carouselViewID = self.carouselViewID, let carouselCurrentPage = self.carouselState.currentPageForCarousel[carouselViewID] {
                    // we are in a carousel and have a current page:
                    if autoPlay && (carouselPageNumber == carouselCurrentPage) {
                        player.play()
                    }
                } else {
                    // not in a carousel, do standard behaviour
                    if autoPlay {
                        player.play()
                    }
                }
            }
        }
    }
    
    private func removeObservers() {
        if let didPlayToEndTimeObserver = self.didPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(didPlayToEndTimeObserver)
            self.didPlayToEndTimeObserver = nil
        }
        
        if let willEnterForegroundObserver = self.willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(willEnterForegroundObserver)
            self.willEnterForegroundObserver = nil
        }
        
        if let player = player,
           let playerCurrentTimeObserver = playerCurrentTimeObserver {
            player.removeTimeObserver(playerCurrentTimeObserver)
            self.playerCurrentTimeObserver = nil
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
        self.updatesNowPlayingInfoCenter = false
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
