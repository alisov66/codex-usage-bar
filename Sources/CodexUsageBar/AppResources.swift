import Foundation

enum AppResources {
    /// SwiftPM's command-line accessor doesn't search a macOS app's Resources directory.
    static let bundle: Bundle = {
        for container in [Bundle.main.resourceURL, Bundle.main.bundleURL].compactMap({ $0 }) {
            let url = container.appendingPathComponent("CodexUsageBar_CodexUsageBar.bundle")
            if let bundle = Bundle(url: url) { return bundle }
        }
        return Bundle.module
    }()

    static func verifyPackagedLocation() throws {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        guard bundle.bundleURL.deletingLastPathComponent().standardizedFileURL == Bundle.main.resourceURL?.standardizedFileURL else {
            throw NSError(domain: "AppResources", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The app loaded resources outside its own bundle: \(bundle.bundleURL.path)"])
        }
    }
}
