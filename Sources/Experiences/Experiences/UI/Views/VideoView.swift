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

import AVKit
import Combine
import SwiftUI
import RoverFoundation

struct VideoView: View {
    @Environment(\.data) private var data
    @Environment(\.urlParameters) private var urlParameters
    @Environment(\.userInfo) private var userInfo

    let video: RoverExperiences.Video
    @State private var isVisible = true

    var body: some View {
        if let urlString = video.sourceURL.evaluatingExpressions(data: data, urlParameters: urlParameters, userInfo: userInfo), let sourceURL = URL(string: urlString) {
            VideoPlayerView(
                sourceURL: sourceURL,
                posterImageURL: posterURL,
                resizingMode: video.resizingMode,
                showControls: video.showControls,
                autoPlay: video.autoPlay,
                removeAudio: video.removeAudio,
                looping: video.looping,
                isVisible: isVisible
            )
            .onDisappear { isVisible = false }
            .onAppear { isVisible = true }
        }
    }
    
    var posterURL: URL? {
        if let url = video.posterImageURL {
            return URL(string: url)
        } else {
            return nil
        }
    }
}

private struct VideoPlayerView: UIViewControllerRepresentable {
    var sourceURL: URL
    var posterImageURL: URL?
    var resizingMode: RoverExperiences.Video.ResizingMode
    var showControls: Bool
    var autoPlay: Bool
    var removeAudio: Bool
    var looping: Bool
    var isVisible: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let viewController = VideoPlayerViewController(
            sourceURL: sourceURL,
            looping: looping,
            removeAudio: removeAudio
        )
        
        viewController.allowsPictureInPicturePlayback = false
        viewController.showsPlaybackControls = showControls
        
        switch resizingMode {
        case .scaleToFill:
            viewController.videoGravity = .resizeAspectFill
        case .scaleToFit:
            viewController.videoGravity = .resizeAspect
        }
        
        if let url = posterImageURL {
            viewController.setPosterImage(url: url)
        }
        
        return viewController
    }
    
    func updateUIViewController(_ viewController: AVPlayerViewController, context: Context) {
        if !isVisible {
            viewController.player?.pause()
        } else if autoPlay {
            viewController.player?.play()
        }
    }
}

private class VideoPlayerViewController: AVPlayerViewController {
    private var looper: AVPlayerLooper?
    private var timeControlStatusOberver: AnyCancellable?
    
    init(sourceURL: URL, looping: Bool, removeAudio: Bool) {
        super.init(nibName: nil, bundle: nil)
        
        let playerItem = AVPlayerItem(url: sourceURL)
        
        if removeAudio {
            let zeroMix = AVMutableAudioMix()
            zeroMix.inputParameters = playerItem.asset.tracks(withMediaType: .audio).map { track in
                let audioInputParams = AVMutableAudioMixInputParameters()
                audioInputParams.setVolume(0, at: .zero)
                audioInputParams.trackID = track.trackID
                return audioInputParams
            }

            playerItem.audioMix = zeroMix
        }
        
        if looping {
            let player = AVQueuePlayer()
            self.player = player
            self.looper = AVPlayerLooper(player: player, templateItem: playerItem)
        } else {
            player = AVPlayer(playerItem: playerItem)
        }
        
        setupBackgroundAudioSupport()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Poster
    
    func setPosterImage(url: URL) {
        let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
        
        experienceManager.downloader.download(url: url) { [weak self] result in
            guard let data = try? result.get(), let image = UIImage(data: data) else {
                return
            }

            DispatchQueue.main.async {
                self?.setPosterImage(image)
            }
        }
    }
    
    private func setPosterImage(_ image: UIImage) {
        let imageView = UIImageView(image: image)
        imageView.frame = contentOverlayView?.frame ?? .zero
        imageView.contentMode = videoGravity == .resizeAspectFill ? .scaleAspectFill : .scaleAspectFit
        imageView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        contentOverlayView?.addSubview(imageView)
        
        timeControlStatusOberver = player?.publisher(for: \.timeControlStatus)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .playing {
                    self?.removePoster()
                }
            }
    }
    
    private func removePoster() {
        contentOverlayView?.subviews.forEach {
            $0.removeFromSuperview()
        }
    }
    
    // MARK: - Background Audio Support
    // https://developer.apple.com/documentation/avfoundation/media_playback_and_selection/creating_a_basic_video_player_ios_and_tvos/playing_audio_from_a_video_asset_in_the_background
    
    private func setupBackgroundAudioSupport() {
        NotificationCenter.default.addObserver(
          self,
          selector: #selector(didEnterBackground(_:)),
          name: UIApplication.didEnterBackgroundNotification,
          object: nil
        )
        
        NotificationCenter.default.addObserver(
          self,
          selector: #selector(willEnterForeground(_:)),
          name: UIApplication.willEnterForegroundNotification,
          object: nil
        )
    }
    
    private var backgroundPlayer: AVPlayer?
    
    @objc
    private func didEnterBackground(_ notification: Notification) {
        backgroundPlayer = player
        player = nil
    }
    
    @objc
    private func willEnterForeground(_ notification: Notification) {
        player = backgroundPlayer
        backgroundPlayer = nil
    }
}