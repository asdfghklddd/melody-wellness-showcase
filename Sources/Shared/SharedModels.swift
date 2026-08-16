import Foundation

// MARK: - 共享数据模型（iOS & watchOS 通用）

/// 会话类型枚举
enum SessionType: String, CaseIterable, Codable {
    case breathing = "breathing"
    case meditation = "meditation"
    case music = "music"
    case stretch = "stretch"
    case bubble = "bubble"
    
    var displayName: String {
        switch self {
        case .breathing: return "深呼吸"
        case .meditation: return "冥想"
        case .music: return "音乐"
        case .stretch: return "拉伸"
        case .bubble: return "戳泡泡"
        }
    }
    
    var watchDisplayName: String {
        switch self {
        case .breathing: return "呼吸"
        case .meditation: return "冥想"
        case .music: return "音乐"
        case .stretch: return "拉伸"
        case .bubble: return "泡泡"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .breathing: return "wind"
        case .meditation: return "leaf"
        case .music: return "music.note"
        case .stretch: return "figure.walk"
        case .bubble: return "circle.fill"
        }
    }
    
    var watchColor: WatchColor {
        switch self {
        case .breathing: return .green
        case .meditation: return .blue
        case .music: return .orange
        case .stretch: return .purple
        case .bubble: return .pink
        }
    }
}

/// watchOS 颜色枚举
enum WatchColor: String, CaseIterable, Codable {
    case green, blue, orange, purple, pink, cyan, yellow
    
    #if canImport(SwiftUI)
    import SwiftUI
    
    var color: Color {
        switch self {
        case .green: return .green
        case .blue: return .blue
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return .pink
        case .cyan: return .cyan
        case .yellow: return .yellow
        }
    }
    #endif
}

/// 会话记录
struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let type: SessionType
    let duration: Int // 分钟
    let date: Date
    let completed: Bool
    
    init(type: SessionType, duration: Int, date: Date = Date(), completed: Bool = true) {
        self.id = UUID()
        self.type = type
        self.duration = duration
        self.date = date
        self.completed = completed
    }
}

/// 统计数据
struct StatsData: Codable {
    let todayMinutes: Int
    let todaySessions: Int
    let streakDays: Int
    let lastSessionTime: Date?
    
    init(todayMinutes: Int = 0, todaySessions: Int = 0, streakDays: Int = 0, lastSessionTime: Date? = nil) {
        self.todayMinutes = todayMinutes
        self.todaySessions = todaySessions
        self.streakDays = streakDays
        self.lastSessionTime = lastSessionTime
    }
}

// MARK: - Watch Connectivity 消息类型

/// 消息类型枚举
enum WCMessageType: String, CaseIterable {
    case sessionCompleted = "session_completed"
    case requestStats = "request_stats"
    case statsUpdate = "stats_update"
    case quickStart = "quick_start"
}

/// Watch Connectivity 消息
struct WCMessage: Codable {
    let type: WCMessageType
    let sessionRecord: SessionRecord?
    let statsData: StatsData?
    let timestamp: Date
    
    init(type: WCMessageType, sessionRecord: SessionRecord? = nil, statsData: StatsData? = nil) {
        self.type = type
        self.sessionRecord = sessionRecord
        self.statsData = statsData
        self.timestamp = Date()
    }
}
