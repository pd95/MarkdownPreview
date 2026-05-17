//
//  PageSetupAction.swift
//  MarkLens
//
//  Created by Philipp on 04.01.2026.
//
import SwiftUI

struct PageSetupAction {
    let run: () -> Void
}

private struct PageSetupActionKey: FocusedValueKey {
    typealias Value = PageSetupAction
}

extension FocusedValues {
    var pageSetupAction: PageSetupAction? {
        get { self[PageSetupActionKey.self] }
        set { self[PageSetupActionKey.self] = newValue }
    }
}

