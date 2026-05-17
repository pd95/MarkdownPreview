//
//  PrintAction.swift
//  MarkLens
//
//  Created by Philipp on 04.01.2026.
//
import SwiftUI

struct PrintAction {
    let run: () -> Void
}

private struct PrintActionKey: FocusedValueKey {
    typealias Value = PrintAction
}

extension FocusedValues {
    var printAction: PrintAction? {
        get { self[PrintActionKey.self] }
        set { self[PrintActionKey.self] = newValue }
    }
}
