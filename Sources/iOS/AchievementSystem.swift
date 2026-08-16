import Foundation
import SwiftUI

// MARK: - 成就数据模型

/// 成就类型枚举
enum AchievementType: String, Codable, CaseIterable {
    case consecutiveDays = "consecutive_days"  // 连续使用天数
    case totalMinutes = "total_minutes"        // 累计放松时长
    case totalSessions = "total_sessions"      // 累计完成会话
    case earlyBird = "early_bird"             // 早起练习
    case nightOwl = "night_owl"               // 深夜放松
    case weekendWarrior = "weekend_warrior"    // 周末坚持
    case perfectWeek = "perfect_week"          // 完美一周
    case varietySeeker = "variety_seeker"      // 尝试多种方式
    case dedicatedPractitioner = "dedicated"   // 专注练习
    
    var displayName: String {
        switch self {
        case .consecutiveDays: return "坚持达人"
        case .totalMinutes: return "放松大师"
        case .totalSessions: return "勤奋之星"
        case .earlyBird: return "早起鸟儿"
        case .nightOwl: return "夜间守护"
        case .weekendWarrior: return "周末战士"
        case .perfectWeek: return "完美一周"
        case .varietySeeker: return "探索者"
        case .dedicatedPractitioner: return "专注修行"
        }
    }
    
    var icon: String {
        switch self {
        case .consecutiveDays: return "flame.fill"
        case .totalMinutes: return "clock.fill"
        case .totalSessions: return "star.fill"
        case .earlyBird: return "sunrise.fill"
        case .nightOwl: return "moon.stars.fill"
        case .weekendWarrior: return "flag.fill"
        case .perfectWeek: return "checkmark.seal.fill"
        case .varietySeeker: return "sparkles"
        case .dedicatedPractitioner: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .consecutiveDays: return Color(red: 247/255, green: 163/255, blue: 3/255) // 深橙
        case .totalMinutes: return Color(red: 209/255, green: 246/255, blue: 88/255)  // 柠檬绿
        case .totalSessions: return Color(red: 217/255, green: 242/255, blue: 255/255) // 淡蓝
        case .earlyBird: return .orange
        case .nightOwl: return .purple
        case .weekendWarrior: return .green
        case .perfectWeek: return Color(red: 255/255, green: 203/255, blue: 104/255) // 橙黄
        case .varietySeeker: return .pink
        case .dedicatedPractitioner: return .red
        }
    }
}

/// 成就等级
enum AchievementTier: Int, Codable, Comparable {
    case bronze = 1   // 铜牌
    case silver = 2   // 银牌
    case gold = 3     // 金牌
    case platinum = 4 // 白金
    
    var displayName: String {
        switch self {
        case .bronze: return "铜牌"
        case .silver: return "银牌"
        case .gold: return "金牌"
        case .platinum: return "白金"
        }
    }
    
    var color: Color {
        switch self {
        case .bronze: return Color(red: 205/255, green: 127/255, blue: 50/255)
        case .silver: return Color(red: 192/255, green: 192/255, blue: 192/255)
        case .gold: return Color(red: 255/255, green: 215/255, blue: 0/255)
        case .platinum: return Color(red: 229/255, green: 228/255, blue: 226/255)
        }
    }
    
    static func < (lhs: AchievementTier, rhs: AchievementTier) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// 成就数据结构
struct Achievement: Codable, Identifiable {
    let id: UUID
    let type: AchievementType
    let tier: AchievementTier
    let targetValue: Int
    var currentValue: Int
    let unlockedDate: Date?
    var isUnlocked: Bool
    var progress: Double {
        return min(1.0, Double(currentValue) / Double(targetValue))
    }
    
    var description: String {
        switch type {
        case .consecutiveDays:
            return "连续使用\(targetValue)天"
        case .totalMinutes:
            return "累计放松\(targetValue)分钟"
        case .totalSessions:
            return "完成\(targetValue)次会话"
        case .earlyBird:
            return "早上6-9点完成\(targetValue)次放松"
        case .nightOwl:
            return "晚上21-24点完成\(targetValue)次放松"
        case .weekendWarrior:
            return "周末坚持放松\(targetValue)次"
        case .perfectWeek:
            return "连续\(targetValue)周每天都放松"
        case .varietySeeker:
            return "尝试\(targetValue)种不同的放松方式"
        case .dedicatedPractitioner:
            return "单日放松时长达到\(targetValue)分钟"
        }
    }
    
    init(type: AchievementType, tier: AchievementTier, targetValue: Int, currentValue: Int = 0) {
        self.id = UUID()
        self.type = type
        self.tier = tier
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unlockedDate = nil
        self.isUnlocked = false
    }
    
    mutating func updateProgress(value: Int) -> Bool {
        currentValue = value
        if currentValue >= targetValue && !isUnlocked {
            isUnlocked = true
            return true // 返回true表示新解锁
        }
        return false
    }
}

// MARK: - 成就管理器

class AchievementManager: ObservableObject {
    static let shared = AchievementManager()
    
    @Published var achievements: [Achievement] = []
    @Published var recentlyUnlocked: [Achievement] = []
    
    private let achievementsKey = "user_achievements"
    private let queue = DispatchQueue(label: "achievement.manager.queue", qos: .userInitiated)
    
    private init() {
        loadAchievements()
    }
    
    // MARK: - 初始化默认成就
    
    private func initializeDefaultAchievements() -> [Achievement] {
        var defaultAchievements: [Achievement] = []
        
        // 连续使用天数成就
        defaultAchievements.append(Achievement(type: .consecutiveDays, tier: .bronze, targetValue: 3))
        defaultAchievements.append(Achievement(type: .consecutiveDays, tier: .silver, targetValue: 7))
        defaultAchievements.append(Achievement(type: .consecutiveDays, tier: .gold, targetValue: 30))
        defaultAchievements.append(Achievement(type: .consecutiveDays, tier: .platinum, targetValue: 100))
        
        // 累计时长成就
        defaultAchievements.append(Achievement(type: .totalMinutes, tier: .bronze, targetValue: 60))
        defaultAchievements.append(Achievement(type: .totalMinutes, tier: .silver, targetValue: 300))
        defaultAchievements.append(Achievement(type: .totalMinutes, tier: .gold, targetValue: 1000))
        defaultAchievements.append(Achievement(type: .totalMinutes, tier: .platinum, targetValue: 5000))
        
        // 累计会话成就
        defaultAchievements.append(Achievement(type: .totalSessions, tier: .bronze, targetValue: 10))
        defaultAchievements.append(Achievement(type: .totalSessions, tier: .silver, targetValue: 50))
        defaultAchievements.append(Achievement(type: .totalSessions, tier: .gold, targetValue: 200))
        defaultAchievements.append(Achievement(type: .totalSessions, tier: .platinum, targetValue: 1000))
        
        // 早起练习成就
        defaultAchievements.append(Achievement(type: .earlyBird, tier: .bronze, targetValue: 5))
        defaultAchievements.append(Achievement(type: .earlyBird, tier: .silver, targetValue: 20))
        defaultAchievements.append(Achievement(type: .earlyBird, tier: .gold, targetValue: 50))
        
        // 深夜放松成就
        defaultAchievements.append(Achievement(type: .nightOwl, tier: .bronze, targetValue: 5))
        defaultAchievements.append(Achievement(type: .nightOwl, tier: .silver, targetValue: 20))
        defaultAchievements.append(Achievement(type: .nightOwl, tier: .gold, targetValue: 50))
        
        // 周末战士成就
        defaultAchievements.append(Achievement(type: .weekendWarrior, tier: .bronze, targetValue: 5))
        defaultAchievements.append(Achievement(type: .weekendWarrior, tier: .silver, targetValue: 20))
        
        // 完美一周成就
        defaultAchievements.append(Achievement(type: .perfectWeek, tier: .bronze, targetValue: 1))
        defaultAchievements.append(Achievement(type: .perfectWeek, tier: .silver, targetValue: 4))
        defaultAchievements.append(Achievement(type: .perfectWeek, tier: .gold, targetValue: 12))
        
        // 探索者成就
        defaultAchievements.append(Achievement(type: .varietySeeker, tier: .bronze, targetValue: 3))
        defaultAchievements.append(Achievement(type: .varietySeeker, tier: .silver, targetValue: 5))
        
        // 专注修行成就
        defaultAchievements.append(Achievement(type: .dedicatedPractitioner, tier: .bronze, targetValue: 30))
        defaultAchievements.append(Achievement(type: .dedicatedPractitioner, tier: .silver, targetValue: 60))
        defaultAchievements.append(Achievement(type: .dedicatedPractitioner, tier: .gold, targetValue: 120))
        
        return defaultAchievements
    }
    
    // MARK: - 数据持久化
    
    private func loadAchievements() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if let data = UserDefaults.standard.data(forKey: self.achievementsKey),
               let decoded = try? JSONDecoder().decode([Achievement].self, from: data) {
                DispatchQueue.main.async {
                    self.achievements = decoded
                }
            } else {
                // 首次使用，初始化默认成就
                let defaults = self.initializeDefaultAchievements()
                DispatchQueue.main.async {
                    self.achievements = defaults
                    self.saveAchievements()
                }
            }
        }
    }
    
    private func saveAchievements() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if let encoded = try? JSONEncoder().encode(self.achievements) {
                UserDefaults.standard.set(encoded, forKey: self.achievementsKey)
            }
        }
    }
    
    // MARK: - 成就更新
    
    /// 检查并更新所有成就
    func checkAndUpdateAchievements() {
        let store = RelaxStatsStore.shared
        let calendar = Calendar.current
        let now = Date()
        
        // 获取统计数据
        let streakDays = store.calculateStreakDays()
        let totalStats = store.getTotalStats()
        let allSessions = store.getAllSessions()
        
        var newlyUnlocked: [Achievement] = []
        
        for i in 0..<achievements.count {
            var achievement = achievements[i]
            let wasUnlocked = achievement.isUnlocked
            
            switch achievement.type {
            case .consecutiveDays:
                if achievement.updateProgress(value: streakDays) {
                    newlyUnlocked.append(achievement)
                }
                
            case .totalMinutes:
                if achievement.updateProgress(value: totalStats.totalMinutes) {
                    newlyUnlocked.append(achievement)
                }
                
            case .totalSessions:
                if achievement.updateProgress(value: totalStats.totalSessions) {
                    newlyUnlocked.append(achievement)
                }
                
            case .earlyBird:
                let earlyMorningSessions = allSessions.filter { session in
                    let hour = calendar.component(.hour, from: session.date)
                    return hour >= 6 && hour < 9
                }.count
                if achievement.updateProgress(value: earlyMorningSessions) {
                    newlyUnlocked.append(achievement)
                }
                
            case .nightOwl:
                let lateSessions = allSessions.filter { session in
                    let hour = calendar.component(.hour, from: session.date)
                    return hour >= 21 && hour <= 23
                }.count
                if achievement.updateProgress(value: lateSessions) {
                    newlyUnlocked.append(achievement)
                }
                
            case .weekendWarrior:
                let weekendSessions = allSessions.filter { session in
                    let weekday = calendar.component(.weekday, from: session.date)
                    return weekday == 1 || weekday == 7 // 周日=1, 周六=7
                }.count
                if achievement.updateProgress(value: weekendSessions) {
                    newlyUnlocked.append(achievement)
                }
                
            case .perfectWeek:
                let perfectWeeks = calculatePerfectWeeks(sessions: allSessions)
                if achievement.updateProgress(value: perfectWeeks) {
                    newlyUnlocked.append(achievement)
                }
                
            case .varietySeeker:
                let uniqueTypes = Set(allSessions.map { $0.type }).count
                if achievement.updateProgress(value: uniqueTypes) {
                    newlyUnlocked.append(achievement)
                }
                
            case .dedicatedPractitioner:
                let maxDailyMinutes = calculateMaxDailyMinutes(sessions: allSessions)
                if achievement.updateProgress(value: maxDailyMinutes) {
                    newlyUnlocked.append(achievement)
                }
            }
            
            achievements[i] = achievement
        }
        
        if !newlyUnlocked.isEmpty {
            DispatchQueue.main.async {
                self.recentlyUnlocked = newlyUnlocked
                // 发送通知
                for achievement in newlyUnlocked {
                    self.sendAchievementNotification(achievement)
                }
            }
        }

        saveAchievements()

        // 同步成就数据到 Widget
        let total = achievements.count
        let unlocked = achievements.filter { $0.isUnlocked }.count
        let progress = getOverallProgress()
        WidgetDataManager.shared.updateAchievementData(total: total, unlocked: unlocked, progress: progress)
    }
    
    // MARK: - 辅助计算方法
    
    private func calculatePerfectWeeks(sessions: [SessionRecord]) -> Int {
        let calendar = Calendar.current
        var weeklyActivity: [Date: Set<Date>] = [:]
        
        for session in sessions {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.date)?.start ?? session.date
            let dayStart = calendar.startOfDay(for: session.date)
            
            if weeklyActivity[weekStart] == nil {
                weeklyActivity[weekStart] = Set()
            }
            weeklyActivity[weekStart]?.insert(dayStart)
        }
        
        let perfectWeeks = weeklyActivity.values.filter { $0.count == 7 }.count
        return perfectWeeks
    }
    
    private func calculateMaxDailyMinutes(sessions: [SessionRecord]) -> Int {
        let calendar = Calendar.current
        var dailyMinutes: [String: Int] = [:]
        
        for session in sessions {
            let dayKey = calendar.startOfDay(for: session.date).timeIntervalSince1970
            let key = String(format: "%.0f", dayKey)
            dailyMinutes[key, default: 0] += session.duration
        }
        
        return dailyMinutes.values.max() ?? 0
    }
    
    // MARK: - 通知
    
    private func sendAchievementNotification(_ achievement: Achievement) {
        NotificationManager.shared.sendAchievementUnlocked(
            title: achievement.type.displayName,
            message: "\(achievement.tier.displayName) - \(achievement.description)"
        )
    }
    
    // MARK: - 查询方法
    
    func getUnlockedAchievements() -> [Achievement] {
        return achievements.filter { $0.isUnlocked }
    }
    
    func getInProgressAchievements() -> [Achievement] {
        return achievements.filter { !$0.isUnlocked && $0.currentValue > 0 }
    }
    
    func getAchievementsByType(_ type: AchievementType) -> [Achievement] {
        return achievements.filter { $0.type == type }.sorted { $0.tier < $1.tier }
    }
    
    func getTotalUnlockedCount() -> Int {
        return achievements.filter { $0.isUnlocked }.count
    }
    
    func getOverallProgress() -> Double {
        guard !achievements.isEmpty else { return 0 }
        let totalProgress = achievements.reduce(0.0) { $0 + $1.progress }
        return totalProgress / Double(achievements.count)
    }
}

// MARK: - 通知扩展

extension NotificationManager {
    func sendAchievementUnlocked(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "🎉 恭喜解锁新成就！"
        content.body = "\(title)\n\(message)"
        content.sound = .default
        content.categoryIdentifier = "ACHIEVEMENT_UNLOCKED"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "achievement_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 成就通知发送失败: \(error)")
            } else {
                print("✅ 成就通知已发送")
            }
        }
    }
}

