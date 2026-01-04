//
//  Bundle-Extension.swift
//  MarkdownPreview
//
//  Created by Philipp on 04.01.2026.
//

import Foundation

nonisolated extension Bundle {

    func stringResource(from resource: String) -> String {
        guard let url = self.url(forResource: resource, withExtension: nil),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("Couldn't load \(resource) from bundle")
        }
        return content
    }

    func dataResource(from resource: String) -> Data {
        guard let url = self.url(forResource: resource, withExtension: nil),
              let content = try? Data(contentsOf: url) else {
            fatalError("Couldn't load \(resource) from bundle")
        }
        return content
    }
}
