import SwiftUI

enum UserLeague: Int, CaseIterable, Identifiable {
    case bronze = 0
    case silver = 1
    case gold = 2
    case diamond = 3
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .bronze: return "Liga Brązowa"
        case .silver: return "Liga Srebrna"
        case .gold: return "Liga Złota"
        case .diamond: return "Liga Diamentowa"
        }
    }
    
    var icon: String {
        switch self {
        case .bronze: return "shield.fill"
        case .silver: return "shield.lefthalf.filled"
        case .gold: return "checkmark.shield.fill"
        case .diamond: return "diamond.fill"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .bronze:
            return [Color(red: 205/255, green: 127/255, blue: 50/255), Color(red: 160/255, green: 80/255, blue: 20/255)]
        case .silver:
            return [Color(red: 192/255, green: 192/255, blue: 192/255), Color(red: 128/255, green: 140/255, blue: 153/255)]
        case .gold:
            return [Color(red: 255/255, green: 215/255, blue: 0/255), Color(red: 230/255, green: 179/255, blue: 25/255)]
        case .diamond:
            return [Color.cyan, Color.blue]
        }
    }
    
    var nextLeague: UserLeague? {
        return UserLeague(rawValue: self.rawValue + 1)
    }
    
    var prevLeague: UserLeague? {
        return UserLeague(rawValue: self.rawValue - 1)
    }
    
    static func determineLeague(for xp: Int) -> UserLeague {
        switch xp {
        case 0..<1000: return .bronze
        case 1000..<2500: return .silver
        case 2500..<5000: return .gold
        default: return .diamond
        }
    }
}
