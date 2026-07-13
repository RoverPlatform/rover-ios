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

enum SenderKind {
    case participant
    case subscription
}

/// Shared mail-app-style row layout used by both PostRowView and ConversationRowView.
struct MessageRowView: View {
    let isRead: Bool
    let avatarURL: URL?
    let senderKind: SenderKind

    /// Pass nil to hide the sender-name label.
    let senderName: String?
    let date: Date?
    let subject: String?
    let previewText: String?
    let action: () -> Void

    private var formattedDate: String? {
        date?.formattedTimestamp()
    }

    private let unknownLabel = "Unknown"
    private let missingSubjectLabel = "No subject"

    private var rowAccessibilityLabel: String {
        [senderName ?? unknownLabel, subject, previewText, formattedDate]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top) {
                HStack(alignment: .center) {
                    unreadIndicator

                    switch senderKind {
                    case .participant:
                        AvatarView(
                            url: avatarURL,
                            name: senderName
                        )
                        .accessibilityHidden(true)
                    case .subscription:
                        LogoView(url: avatarURL)
                            .accessibilityHidden(true)
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    headerLine
                    subjectLine
                    previewLine
                }
                .alignmentGuide(.listRowSeparatorLeading) { dimensions in
                    dimensions[.leading]
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityValue(isRead ? "Read" : "Unread")
        .buttonStyle(.plain)
    }

    private var unreadIndicator: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 10, height: 10)
            .opacity(isRead ? 0 : 1)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var headerLine: some View {
        HStack(spacing: 0) {
            senderLine
            Spacer(minLength: 6)
            formattedDateLine
        }
    }

    private var senderLine: some View {
        Text(senderName ?? unknownLabel)
            .fontWeight(.bold)
            .lineLimit(1)
            .font(.callout)
    }

    @ViewBuilder
    private var formattedDateLine: some View {
        HStack(spacing: 4) {
            if let formattedDate {
                Text(formattedDate)
                    .lineLimit(1)
            } else {
                Text(unknownLabel)
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var subjectLine: some View {
        Group {
            if let subject {
                Text(subject)
                    .lineLimit(1)
            } else {
                Text(missingSubjectLabel)
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var previewLine: some View {
        if let previewText {
            Text(previewText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        } else {
            Text(unknownLabel)
                .foregroundStyle(.tertiary)
        }
    }
}
