//
//  RawEditorView.swift
//  MarkLens
//
//  Created by Philipp on 16.01.2026.
//
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct RawEditorView: View {
    @Binding var text: String
    @Binding var showFind: Bool
    @Binding var scrollPosition: DocumentScrollPosition
    var scrollTarget: DocumentScrollPosition
    var scrollRequest: Int

    @ViewBuilder
    var textEditor: some View {
        if #available(macOS 26.0, iOS 16.0, *) {
            TextEditor(text: $text)
                .findNavigator(isPresented: $showFind)
        } else {
            TextEditor(text: $text)
        }
    }

    var body: some View {
        textEditor
            .background(
                RawEditorScrollBridge(
                    scrollPosition: $scrollPosition,
                    scrollTarget: scrollTarget,
                    scrollRequest: scrollRequest
                )
            )
            .font(.system(.body, design: .monospaced))
#if os(iOS)
            .textInputAutocapitalization(.never)
#endif
            .disableAutocorrection(true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Markdown source editor")
            .accessibilityTextContentType(.plain)
    }
}

#if os(macOS)
private struct RawEditorScrollBridge: NSViewRepresentable {
    @Binding var scrollPosition: DocumentScrollPosition
    var scrollTarget: DocumentScrollPosition
    var scrollRequest: Int

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.parent = self
        DispatchQueue.main.async { context.coordinator.connect(from: view) }
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.disconnect()
    }

    final class Coordinator {
        var parent: RawEditorScrollBridge
        weak var textView: NSTextView?
        private var boundsObserver: NSObjectProtocol?
        private var textObserver: NSObjectProtocol?
        private var appliedRequest = -1
        private var connectionAttempts = 0

        init(parent: RawEditorScrollBridge) { self.parent = parent }

        func connect(from marker: NSView) {
            if textView == nil {
                textView = enclosingTextView(from: marker)
                observeScrolling()
                observeTextChanges()
                if textView == nil, connectionAttempts < 5 {
                    connectionAttempts += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak marker] in
                        guard let self, let marker else { return }
                        self.connect(from: marker)
                    }
                    return
                }
            }
            applyTargetIfNeeded()
            reportPosition()
        }

        func disconnect() {
            if let boundsObserver { NotificationCenter.default.removeObserver(boundsObserver) }
            if let textObserver { NotificationCenter.default.removeObserver(textObserver) }
            boundsObserver = nil
            textObserver = nil
            textView = nil
        }

        private func enclosingTextView(from marker: NSView) -> NSTextView? {
            var ancestor = marker.superview
            while let view = ancestor {
                if let textView = firstTextView(in: view) { return textView }
                ancestor = view.superview
            }
            return nil
        }

        private func firstTextView(in view: NSView) -> NSTextView? {
            if let textView = view as? NSTextView { return textView }
            for child in view.subviews {
                if let result = firstTextView(in: child) { return result }
            }
            return nil
        }

        private func observeScrolling() {
            guard let clipView = textView?.enclosingScrollView?.contentView else { return }
            clipView.postsBoundsChangedNotifications = true
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                self?.reportPosition()
            }
        }

        private func observeTextChanges() {
            guard let textView else { return }
            textObserver = NotificationCenter.default.addObserver(
                forName: NSText.didChangeNotification,
                object: textView,
                queue: .main
            ) { [weak self] _ in
                self?.reportPosition()
            }
        }

        private func applyTargetIfNeeded() {
            guard appliedRequest != parent.scrollRequest, let textView else { return }
            appliedRequest = parent.scrollRequest
            if let line = parent.scrollTarget.sourceLine,
               let layoutManager = textView.layoutManager,
               let textContainer = textView.textContainer,
               layoutManager.numberOfGlyphs > 0 {
                let character = SourceLineMapper.characterOffset(forLine: line, in: textView.string)
                let glyph = layoutManager.glyphIndexForCharacter(
                    at: min(character, max(0, textView.string.utf16.count - 1))
                )
                let rect = layoutManager.boundingRect(
                    forGlyphRange: NSRange(location: glyph, length: 1),
                    in: textContainer
                )
                if let scrollView = textView.enclosingScrollView {
                    let clipView = scrollView.contentView
                    let targetY = rect.minY + textView.textContainerOrigin.y
                        - unobscuredTopInset(in: textView)
                    clipView.scroll(to: NSPoint(x: clipView.bounds.minX, y: targetY))
                    scrollView.reflectScrolledClipView(clipView)
                }
            } else if let scrollView = textView.enclosingScrollView {
                let clipView = scrollView.contentView
                let maximum = max(0, textView.bounds.height - scrollView.documentVisibleRect.height)
                clipView.scroll(to: NSPoint(x: clipView.bounds.minX, y: maximum * parent.scrollTarget.progress))
                scrollView.reflectScrolledClipView(clipView)
            }
        }

        private func reportPosition() {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            var unobscuredRect = textView.visibleRect
            let topInset = unobscuredTopInset(in: textView)
            unobscuredRect.origin.y += topInset
            unobscuredRect.size.height = max(0, unobscuredRect.height - topInset)
            unobscuredRect.origin.x -= textView.textContainerOrigin.x
            unobscuredRect.origin.y -= textView.textContainerOrigin.y
            let glyphRange = layoutManager.glyphRange(
                forBoundingRect: unobscuredRect,
                in: textContainer
            )
            let character = glyphRange.location < layoutManager.numberOfGlyphs
                ? layoutManager.characterIndexForGlyph(at: glyphRange.location)
                : textView.string.utf16.count
            let maximum = max(0, textView.bounds.height - textView.visibleRect.height)
            let progress = maximum == 0 ? 0 : textView.visibleRect.minY / maximum
            let position = DocumentScrollPosition(
                sourceLine: SourceLineMapper.lineNumber(at: character, in: textView.string),
                progress: min(max(progress, 0), 1)
            )
            parent.scrollPosition = position
        }

        private func unobscuredTopInset(in textView: NSTextView) -> CGFloat {
            let safeAreaInset = max(0, textView.safeAreaRect.minY - textView.visibleRect.minY)
            let scrollInset = textView.enclosingScrollView?.contentInsets.top ?? 0
            return max(safeAreaInset, scrollInset)
        }
    }
}
#else
private struct RawEditorScrollBridge: UIViewRepresentable {
    @Binding var scrollPosition: DocumentScrollPosition
    var scrollTarget: DocumentScrollPosition
    var scrollRequest: Int

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> UIView { UIView(frame: .zero) }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.parent = self
        DispatchQueue.main.async { context.coordinator.connect(from: view) }
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.disconnect()
    }

    final class Coordinator {
        var parent: RawEditorScrollBridge
        weak var textView: UITextView?
        private var offsetObservation: NSKeyValueObservation?
        private var textObserver: NSObjectProtocol?
        private var appliedRequest = -1
        private var connectionAttempts = 0

        init(parent: RawEditorScrollBridge) { self.parent = parent }

        func connect(from marker: UIView) {
            if textView == nil {
                textView = enclosingTextView(from: marker)
                offsetObservation = textView?.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                    self?.reportPosition()
                }
                observeTextChanges()
                if textView == nil, connectionAttempts < 5 {
                    connectionAttempts += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak marker] in
                        guard let self, let marker else { return }
                        self.connect(from: marker)
                    }
                    return
                }
            }
            applyTargetIfNeeded()
            reportPosition()
        }

        func disconnect() {
            offsetObservation?.invalidate()
            if let textObserver { NotificationCenter.default.removeObserver(textObserver) }
            offsetObservation = nil
            textObserver = nil
            textView = nil
        }

        private func enclosingTextView(from marker: UIView) -> UITextView? {
            var ancestor = marker.superview
            while let view = ancestor {
                if let textView = firstTextView(in: view) { return textView }
                ancestor = view.superview
            }
            return nil
        }

        private func firstTextView(in view: UIView) -> UITextView? {
            if let textView = view as? UITextView { return textView }
            for child in view.subviews {
                if let result = firstTextView(in: child) { return result }
            }
            return nil
        }

        private func observeTextChanges() {
            guard let textView else { return }
            textObserver = NotificationCenter.default.addObserver(
                forName: UITextView.textDidChangeNotification,
                object: textView,
                queue: .main
            ) { [weak self] _ in
                self?.reportPosition()
            }
        }

        private func applyTargetIfNeeded() {
            guard appliedRequest != parent.scrollRequest, let textView else { return }
            appliedRequest = parent.scrollRequest
            if let line = parent.scrollTarget.sourceLine,
               textView.layoutManager.numberOfGlyphs > 0 {
                let character = SourceLineMapper.characterOffset(forLine: line, in: textView.text)
                let glyph = textView.layoutManager.glyphIndexForCharacter(
                    at: min(character, max(0, (textView.text as NSString).length - 1))
                )
                let rect = textView.layoutManager.boundingRect(
                    forGlyphRange: NSRange(location: glyph, length: 1),
                    in: textView.textContainer
                )
                let maximum = max(
                    -textView.adjustedContentInset.top,
                    textView.contentSize.height - textView.bounds.height
                        + textView.adjustedContentInset.bottom
                )
                let y = min(
                    max(
                        rect.minY + textView.textContainerInset.top
                            - textView.adjustedContentInset.top,
                        -textView.adjustedContentInset.top
                    ),
                    maximum
                )
                textView.setContentOffset(
                    CGPoint(x: textView.contentOffset.x, y: y),
                    animated: false
                )
            } else {
                let maximum = max(0, textView.contentSize.height - textView.bounds.height)
                textView.setContentOffset(
                    CGPoint(x: textView.contentOffset.x, y: maximum * parent.scrollTarget.progress),
                    animated: false
                )
            }
        }

        private func reportPosition() {
            guard let textView else { return }
            var visibleRect = CGRect(origin: textView.contentOffset, size: textView.bounds.size)
            visibleRect.origin.y += textView.adjustedContentInset.top
            visibleRect.size.height = max(
                0,
                visibleRect.height - textView.adjustedContentInset.top
                    - textView.adjustedContentInset.bottom
            )
            visibleRect.origin.x -= textView.textContainerInset.left
            visibleRect.origin.y -= textView.textContainerInset.top
            let glyphRange = textView.layoutManager.glyphRange(
                forBoundingRect: visibleRect,
                in: textView.textContainer
            )
            let character = glyphRange.location < textView.layoutManager.numberOfGlyphs
                ? textView.layoutManager.characterIndexForGlyph(at: glyphRange.location)
                : (textView.text as NSString).length
            let maximum = max(0, textView.contentSize.height - textView.bounds.height)
            let progress = maximum == 0 ? 0 : max(0, textView.contentOffset.y) / maximum
            let position = DocumentScrollPosition(
                sourceLine: SourceLineMapper.lineNumber(at: character, in: textView.text),
                progress: min(max(progress, 0), 1)
            )
            parent.scrollPosition = position
        }
    }
}
#endif

private enum SourceLineMapper {
    static func characterOffset(forLine requestedLine: Int, in text: String) -> Int {
        let value = text as NSString
        var offset = 0
        var line = 1
        while line < max(1, requestedLine), offset < value.length {
            let range = value.range(
                of: "\n",
                options: [],
                range: NSRange(location: offset, length: value.length - offset)
            )
            guard range.location != NSNotFound else { return value.length }
            offset = NSMaxRange(range)
            line += 1
        }
        return offset
    }

    static func lineNumber(at character: Int, in text: String) -> Int {
        let value = text as NSString
        let length = min(max(character, 0), value.length)
        var line = 1
        var offset = 0
        while offset < length {
            let range = value.range(
                of: "\n",
                options: [],
                range: NSRange(location: offset, length: length - offset)
            )
            guard range.location != NSNotFound else { break }
            line += 1
            offset = NSMaxRange(range)
        }
        return line
    }
}
