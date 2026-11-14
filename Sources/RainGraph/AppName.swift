import Foundation

public extension Bundle {
    /// The name under the app's icon, in the wearer's language: RainWatch in English, BuienWatch in
    /// Dutch (`App/Shared/InfoPlist.xcstrings`).
    var displayName: String {
        localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? infoDictionary?["CFBundleDisplayName"] as? String
            ?? "RainWatch"
    }
}
