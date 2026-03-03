import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case chineseSimplified = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"

    var id: String { rawValue }

    var localizedNameKey: String {
        switch self {
        case .english:
            return "language.english"
        case .spanish:
            return "language.spanish"
        case .french:
            return "language.french"
        case .chineseSimplified:
            return "language.chinese_simplified"
        case .japanese:
            return "language.japanese"
        case .korean:
            return "language.korean"
        }
    }
}
