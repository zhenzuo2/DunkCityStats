import Foundation

enum L10n {
    static func string(_ key: String, locale: Locale) -> String {
        localizedBundle(for: locale).localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, locale: Locale, _ args: CVarArg...) -> String {
        String(format: string(key, locale: locale), locale: locale, arguments: args)
    }

    static func format(_ key: String, locale: Locale, arguments: [CVarArg]) -> String {
        String(format: string(key, locale: locale), locale: locale, arguments: arguments)
    }

    private static func localizedBundle(for locale: Locale) -> Bundle {
        let identifier = locale.identifier
        if let bundle = bundle(forResourceCode: identifier) {
            return bundle
        }

        let normalized = identifier.replacingOccurrences(of: "_", with: "-")
        if let bundle = bundle(forResourceCode: normalized) {
            return bundle
        }

        let codeParts = normalized
            .split(separator: "-")
            .map(String.init)
        if let languageCode = codeParts.first,
           let bundle = bundle(forResourceCode: languageCode) {
            return bundle
        }

        return .main
    }

    private static func bundle(forResourceCode code: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
