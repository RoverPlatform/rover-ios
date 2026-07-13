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

private struct BubbleBottomAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
        context[.bottom]
    }
}

private extension VerticalAlignment {
    static let bubbleBottom = VerticalAlignment(BubbleBottomAlignment.self)
}

/// Renders a `MessageGroup` as a bubble cluster — WhatsApp/Telegram style.
/// Used as the content of each `UICollectionViewCell` via `UIHostingConfiguration`.
struct MessageGroupBubbleView: View {

    static let avatarSize: CGFloat = 28

    let group: MessageGroup
    let isMostRecent: Bool
    var onImageTap: ((URL, UIView) -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: avatarSpacing) {
            if isOutbound {
                Spacer(minLength: 40)
            }

            VStack(alignment: horizontalAlignment, spacing: 2) {
                ForEach(group.replies.indices, id: \.self) { index in
                    bubbleRow(at: index)
                }
            }

            if !isOutbound {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOutbound ? .trailing : .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    // MARK: - Subviews

    private var avatarView: some View {
        AvatarView(
            url: group.participantAvatarURL,
            name: group.participantName,
            size: Self.avatarSize
        )
    }

    private var timestampView: some View {
        Text(timestampText)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 2)
    }

    private var failedIndicatorView: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.circle")
            Text("Not Delivered")
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.red)
        .padding(.horizontal, 12)
        .padding(.top, 2)
    }

    private func senderNameView(_ name: String) -> some View {
        Text(name)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private func bubbleRow(at index: Int) -> some View {
        let reply = group.replies[index]
        let isFirst = index == group.replies.startIndex
        let isLast = index == group.replies.count - 1
        let isFailed = isOutbound && reply.syncState == .failed
        let content = rowBubble(
            bubble: bubble(contentBlocks: reply.contentBlocks, isFirst: isFirst, isLast: isLast),
            isFirst: isFirst
        )

        if isOutbound {
            if isLast || isFailed {
                bubbleWithTimestamp(row: content, isFailed: isFailed)
            } else {
                content
            }
        } else {
            HStack(alignment: isLast ? .bubbleBottom : .bottom, spacing: avatarSpacing) {
                if isLast {
                    avatarView
                        .alignmentGuide(.bubbleBottom) { $0[.bottom] }
                    bubbleWithTimestamp(row: content, isFailed: false)
                } else {
                    Color.clear
                        .frame(width: Self.avatarSize, height: Self.avatarSize)
                        .accessibilityHidden(true)
                    content
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(contentBlocks: [ContentBlock], isFirst: Bool, isLast: Bool) -> some View {
        VStack(alignment: horizontalAlignment, spacing: 4) {
            ForEach(contentBlocks.indices, id: \.self) { blockIndex in
                blockView(contentBlocks[blockIndex])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(bubbleColor)
        .foregroundStyle(bubbleForegroundColor)
        .clipShape(bubbleShape(isFirst: isFirst, isLast: isLast))
    }

    @ViewBuilder
    private func rowBubble(bubble: some View, isFirst: Bool) -> some View {
        if !isOutbound, isFirst, let senderName = group.participantName {
            VStack(alignment: horizontalAlignment, spacing: 2) {
                senderNameView(senderName)
                bubble
            }
        } else {
            bubble
        }
    }

    @ViewBuilder
    private func bubbleWithTimestamp(row: some View, isFailed: Bool) -> some View {
        VStack(alignment: horizontalAlignment, spacing: 0) {
            row
                .alignmentGuide(.bubbleBottom) { $0[.bottom] }
            if isFailed {
                failedIndicatorView
            } else if isMostRecent {
                timestampView
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: ContentBlock) -> some View {
        switch block {
        case .text(let text):
            Text(text.attributedForLinks(whiteLinks: isOutbound))
                .fixedSize(horizontal: false, vertical: true)
        case .image(let url):
            TappableAsyncImage(url: url, onTap: onImageTap)
        case .unknown:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private var isOutbound: Bool { group.senderType == .fan }

    private var bubbleColor: Color {
        isOutbound ? .accentColor : Color(.systemGray5)
    }

    private var bubbleForegroundColor: Color {
        isOutbound ? .white : .primary
    }

    private var avatarSpacing: CGFloat {
        isOutbound ? 0 : 8
    }

    private var horizontalAlignment: HorizontalAlignment {
        isOutbound ? .trailing : .leading
    }

    private var timestampText: String {
        group.hasQueuedReply
            ? "Sending…"
            : group.timestamp.formatted(date: .omitted, time: .shortened)
    }

    private func bubbleShape(isFirst: Bool, isLast: Bool) -> some Shape {
        let large: CGFloat = 20
        let small: CGFloat = 4

        if isOutbound {
            return UnevenRoundedRectangle(
                topLeadingRadius: large,
                bottomLeadingRadius: large,
                bottomTrailingRadius: isLast ? large : small,
                topTrailingRadius: isFirst ? large : small
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: isFirst ? large : small,
                bottomLeadingRadius: isLast ? large : small,
                bottomTrailingRadius: large,
                topTrailingRadius: large
            )
        }
    }
}
