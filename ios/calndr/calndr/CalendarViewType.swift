import Foundation

enum CalendarViewType {
    case year
    case month
    case week
    case threeDay
    case day
    
    var shortName: String {
        switch self {
        case .year:
            return "Year"
        case .month:
            return "Month"
        case .week:
            return "Week"
        case .threeDay:
            return "3-Day"
        case .day:
            return "Day"
        }
    }
} 