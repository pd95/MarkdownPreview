//
//  BuildInfo.swift
//  MarkLens
//

import Foundation

enum BuildInfo {
    static let releaseTag = "local"
    static let tagVersion = "local"
    static let shortCommit = "unknown"

    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static var displayVersion: String {
        "\(marketingVersion) (\(buildNumber))"
    }

    static var releaseDescription: String {
        "Release: \(releaseTag)\nCommit: \(shortCommit)"
    }
}
