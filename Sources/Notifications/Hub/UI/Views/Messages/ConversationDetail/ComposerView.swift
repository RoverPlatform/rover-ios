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
import UIKit

/// Multiline reply composer: growing text view + send button.
/// Hosted in a UIHostingController inside ConversationCollectionViewController,
/// pinned to view.keyboardLayoutGuide so UIKit drives keyboard animation.
///
/// Text state is self-contained — no external binding needed.
/// Focus is managed by the UIKit responder chain; no FocusState parameter.
struct ComposerView: View {
    let placeholderText: String

    /// Called with the trimmed, non-empty text when the user taps Send.
    /// Receives the text **before** the internal state is cleared.
    let onSend: (String) -> Void

    @State private var text: String = ""

    private var lineHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight
    }

    private let verticalPadding: CGFloat = 9

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                placeholder
            }

            HStack(alignment: .bottom, spacing: 8) {
                ComposerTextEditor(
                    text: $text
                )
                .accessibilityLabel("Reply")

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .frame(height: lineHeight)
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 3)
        .padding(.vertical, verticalPadding)
        .modifier(ComposerFieldBackground(defaultHeight: lineHeight + verticalPadding * 2))
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private var placeholder: some View {
        Text(placeholderText)
            .font(.body)
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend(trimmed)
        text = ""
    }
}

private struct ComposerTextEditor: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        if uiView.font != bodyFont {
            uiView.font = bodyFont
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let proposalWidth = proposal.width else { return nil }
        let fitting = uiView.sizeThatFits(
            CGSize(width: proposalWidth, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: proposalWidth, height: ceil(fitting.height))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }
    }
}

private struct ComposerFieldBackground: ViewModifier {
    var defaultHeight: CGFloat

    private var cornerRadius: CGFloat {
        defaultHeight / 2
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color(.separator).opacity(0.12), lineWidth: 0.5)
                )
        }
    }
}

#if DEBUG
    #Preview {
        VStack {
            Spacer()
            ComposerView(placeholderText: "App Message", onSend: { _ in })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
#endif
