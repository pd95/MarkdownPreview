import Foundation

enum AppearancePreferences {
    static let customCSSKey = "CustomCSSOverrides"

    static let starterCSS = """
    /* MarkLens custom styles.
       Edit the values below.
       Delete a rule to use its default. */

    body {
        font-family: system-ui, sans-serif;
        font-size: 16px;
    }

    h1, h2, h3, h4, h5, h6 {
        font-weight: 600;
    }

    a {
        color: #007aff;
    }

    @media (prefers-color-scheme: dark) {
        a {
            color: #58a6ff;
        }
    }
    """

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [customCSSKey: starterCSS])
    }
}
