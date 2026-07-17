//
//  PrintAction.swift
//  MarkLens
//
//  Created by Philipp on 04.01.2026.
//
import SwiftUI

struct PrintAction {
    let isEnabled: Bool
    let run: () -> Void

    init(isEnabled: Bool = true, _ run: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.run = run
    }
}

struct ExportAction {
    let isEnabled: Bool
    let run: () -> Void

    init(isEnabled: Bool = true, _ run: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.run = run
    }
}

struct OpenInPreviewAction {
    let isEnabled: Bool
    let run: () -> Void

    init(isEnabled: Bool = true, _ run: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.run = run
    }
}

private struct PrintActionKey: FocusedValueKey {
    typealias Value = PrintAction
}

private struct ExportActionKey: FocusedValueKey {
    typealias Value = ExportAction
}

private struct OpenInPreviewActionKey: FocusedValueKey {
    typealias Value = OpenInPreviewAction
}

extension FocusedValues {
    var printAction: PrintAction? {
        get { self[PrintActionKey.self] }
        set { self[PrintActionKey.self] = newValue }
    }

    var exportAction: ExportAction? {
        get { self[ExportActionKey.self] }
        set { self[ExportActionKey.self] = newValue }
    }

    var openInPreviewAction: OpenInPreviewAction? {
        get { self[OpenInPreviewActionKey.self] }
        set { self[OpenInPreviewActionKey.self] = newValue }
    }
}
