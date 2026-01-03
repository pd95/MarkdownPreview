//
//  DefaultSize.swift
//  MarkdownPreview
//
//  Created by Philipp on 03.01.2026.
//
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension CGSize {
    static var defaultWindowSize: CGSize {
        #if os(macOS)
        let height = NSScreen.main?.visibleFrame.height
        #else
        let height: CGFloat? = UIScreen.main.bounds.height
        #endif

        let scaledHeight = height.map { $0 * 0.8 } ?? 800
        return .init(width: 900, height: max(scaledHeight, 800))
    }
}
