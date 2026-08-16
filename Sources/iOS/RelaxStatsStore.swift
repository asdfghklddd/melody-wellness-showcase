import Foundation

// MARK: - 数据模型扩展
// 扩展SessionType以支持游戏类型
enum SessionType: String, CaseIterable, Codable {
    case breathing = "breathing"
    case music = "music"
    case meditation = "meditation"
    case stretch = "stretch"
    case bubble = "bubble"
    case appleCatcher = "appleCatcher"
    case whackAMole = "whackAMole"
    case drawing = "drawing"

    var displayName: String {
        switch self {
        case .breathing: return "深呼吸"
        case .music: return "音乐"
        case .meditation: return "冥想"
        case .stretch: return "拉伸"
        case .bubble: return "戳泡泡"
        case .appleCatcher: return "接苹果游戏"
        case .whackAMole: return "打地鼠游戏"
        case .drawing: return "自由绘画"
        }
    }
}

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

struct DayStats: Codable {
    let date: Date
    var totalMinutes: Int
    var sessionCount: Int
    var sessionsByType: [SessionType: Int]
    
    init(date: Date) {
        self.date = date
        self.totalMinutes = 0
        self.sessionCount = 0
        self.sessionsByType = [:]
    }
}

final class RelaxStatsStore {
    static let shared = RelaxStatsStore()
    
    // 存储键
    private let dailyStatsKey = "relax_daily_stats"
    private let sessionsKey = "relax_sessions"
    private let userPrefsKey = "relax_user_prefs"
    
    // 线程安全队列
    private let queue = DispatchQueue(label: "relax.store.queue", qos: .userInitiated)
    
    // 缓存
    private var cachedDailyStats: [String: DayStats] = [:]
    private var cachedSessions: [SessionRecord] = []
    private var lastCacheUpdate: Date = Date.distantPast
    private let cacheValidityInterval: TimeInterval = 300 // 5分钟缓存
    
    private init() {
        loadCache()
    }
    
    // MARK: - 公共接口
    
    /// 添加会话记录
    func addSession(type: SessionType, duration: Int, date: Date = Date()) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let session = SessionRecord(type: type, duration: duration, date: date)
            
            // 更新会话记录
            var sessions = self.loadSessions()
            sessions.append(session)
            self.saveSessions(sessions)
            
            // 更新日统计
            self.updateDayStats(for: date, session: session)
            
            // 更新缓存
            self.cachedSessions = sessions
            self.lastCacheUpdate = Date()
            
            // 发送通知
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .relaxStatsUpdated, object: nil)
            }
            
            // 同步Widget数据：必须在本串行队列之外调用，避免在队列内再次 queue.sync 造成自锁
            DispatchQueue.global(qos: .utility).async {
                self.syncWidgetData()
            }
        }
    }
    
    /// 兼容性方法：添加分钟数（自动分类为呼吸练习）
    func add(minutes: Int, on date: Date = Date()) {
        addSession(type: .breathing, duration: minutes, date: date)
    }
    
    /// 获取指定日期的分钟数
    func minutes(on date: Date) -> Int {
        return queue.sync {
            let stats = getDayStats(for: date)
            return stats.totalMinutes
        }
    }
    
    /// 获取指定日期的会话数
    func sessionsCount(on date: Date) -> Int {
        return queue.sync {
            let stats = getDayStats(for: date)
            return stats.sessionCount
        }
    }
    
    /// 获取最近7天统计
    func last7DaysStats(from now: Date = Date()) -> [DayStat] {
        return queue.sync {
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: now)
            
            return (0..<7).reversed().map { offset in
                let date = calendar.date(byAdding: .day, value: -offset, to: startDate)!
                let stats = getDayStats(for: date)
                return DayStat(date: date, minutes: stats.totalMinutes)
            }
        }
    }
    
    /// 获取最近30天统计
    func last30DaysStats(from now: Date = Date()) -> [DayStat] {
        return queue.sync {
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: now)
            
            return (0..<30).reversed().map { offset in
                let date = calendar.date(byAdding: .day, value: -offset, to: startDate)!
                let stats = getDayStats(for: date)
                return DayStat(date: date, minutes: stats.totalMinutes)
            }
        }
    }
    
    /// 计算连续使用天数
    func calculateStreakDays(from now: Date = Date()) -> Int {
        return queue.sync {
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: now)
            var streak = 0
            
            for offset in 0..<365 { // 最多检查一年
                let date = calendar.date(byAdding: .day, value: -offset, to: startDate)!
                let stats = getDayStats(for: date)
                
                if stats.totalMinutes > 0 {
                    streak += 1
                } else {
                    break
                }
            }
            
            return max(streak, 0)
        }
    }
    
    /// 获取会话类型统计
    func getSessionTypeStats(in dateRange: DateInterval) -> [SessionType: Int] {
        return queue.sync {
            let sessions = getSessionsInRange(dateRange)
            var stats: [SessionType: Int] = [:]
            
            for session in sessions {
                stats[session.type, default: 0] += 1
            }
            
            return stats
        }
    }
    
    /// 获取总统计信息
    func getTotalStats() -> (totalMinutes: Int, totalSessions: Int, averageDaily: Double) {
        return queue.sync {
            let allStats = loadDailyStats()
            let totalMinutes = allStats.values.reduce(0) { $0 + $1.totalMinutes }
            let totalSessions = allStats.values.reduce(0) { $0 + $1.sessionCount }
            let activeDays = allStats.values.filter { $0.totalMinutes > 0 }.count
            let averageDaily = activeDays > 0 ? Double(totalMinutes) / Double(activeDays) : 0
            
            return (totalMinutes, totalSessions, averageDaily)
        }
    }

    /// 返回全部会话记录（按时间降序）。注意：包含近一年内的记录。
    func getAllSessions() -> [SessionRecord] {
        return queue.sync {
            return loadSessions()
        }
    }
    
    /// 计算趋势比较
    func getTrendComparison(for metric: String, days: Int = 7) -> Double {
        return queue.sync {
            let calendar = Calendar.current
            let now = Date()
            
            // 当前周期
            let currentPeriodEnd = calendar.startOfDay(for: now)
            let currentPeriodStart = calendar.date(byAdding: .day, value: -(days-1), to: currentPeriodEnd)!
            let currentRange = DateInterval(start: currentPeriodStart, end: currentPeriodEnd)
            
            // 上个周期
            let previousPeriodEnd = calendar.date(byAdding: .day, value: -days, to: currentPeriodEnd)!
            let previousPeriodStart = calendar.date(byAdding: .day, value: -(days-1), to: previousPeriodEnd)!
            let previousRange = DateInterval(start: previousPeriodStart, end: previousPeriodEnd)
            
            let currentValue = getMetricValue(metric: metric, in: currentRange)
            let previousValue = getMetricValue(metric: metric, in: previousRange)
            
            guard previousValue > 0 else { return 0 }
            return ((currentValue - previousValue) / previousValue) * 100
        }
    }
    
    // MARK: - 私有方法
    
    private func loadCache() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.cachedDailyStats = self.loadDailyStats()
            self.cachedSessions = self.loadSessions()
            self.lastCacheUpdate = Date()
        }
    }
    
    private func getDayStats(for date: Date) -> DayStats {
        let key = dayKey(date)
        
        if Date().timeIntervalSince(lastCacheUpdate) < cacheValidityInterval,
           let cached = cachedDailyStats[key] {
            return cached
        }
        
        let allStats = loadDailyStats()
        cachedDailyStats = allStats
        lastCacheUpdate = Date()
        
        return allStats[key] ?? DayStats(date: date)
    }
    
    private func updateDayStats(for date: Date, session: SessionRecord) {
        let key = dayKey(date)
        var allStats = loadDailyStats()
        
        var dayStats = allStats[key] ?? DayStats(date: date)
        dayStats.totalMinutes += session.duration
        dayStats.sessionCount += 1
        dayStats.sessionsByType[session.type, default: 0] += 1
        
        allStats[key] = dayStats
        saveDailyStats(allStats)
        
        // 更新缓存
        cachedDailyStats[key] = dayStats
    }
    
    private func getSessionsInRange(_ range: DateInterval) -> [SessionRecord] {
        let sessions = loadSessions()
        return sessions.filter { range.contains($0.date) }
    }
    
    private func getMetricValue(metric: String, in range: DateInterval) -> Double {
        let sessions = getSessionsInRange(range)
        
        switch metric {
        case "minutes":
            return Double(sessions.reduce(0) { $0 + $1.duration })
        case "sessions":
            return Double(sessions.count)
        default:
            return 0
        }
    }
    
    // MARK: - 数据持久化
    
    private func loadDailyStats() -> [String: DayStats] {
        guard let data = UserDefaults.standard.data(forKey: dailyStatsKey),
              let stats = try? JSONDecoder().decode([String: DayStats].self, from: data) else {
            return [:]
        }
        return stats
    }
    
    private func saveDailyStats(_ stats: [String: DayStats]) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        UserDefaults.standard.set(data, forKey: dailyStatsKey)
    }
    
    private func loadSessions() -> [SessionRecord] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([SessionRecord].self, from: data) else {
            return []
        }
        return sessions.sorted { $0.date > $1.date }
    }
    
    private func saveSessions(_ sessions: [SessionRecord]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: sessionsKey)
    }
    
    private func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    // MARK: - 数据迁移和维护
    
    /// 迁移旧数据格式
    func migrateOldData() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查是否有旧格式数据
            let oldKey = "relax_minutes_by_day"
            guard let oldData = UserDefaults.standard.dictionary(forKey: oldKey) as? [String: Int] else {
                return
            }
            
            // 转换为新格式
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for (dateString, minutes) in oldData {
                guard let date = dateFormatter.date(from: dateString), minutes > 0 else { continue }
                
                // 估算会话数（假设平均5分钟一个会话）
                let sessionCount = max(1, minutes / 5)
                
                // 创建估算的会话记录
                for i in 0..<sessionCount {
                    let sessionDate = Calendar.current.date(byAdding: .minute, value: i * 5, to: date) ?? date
                    let duration = min(5, minutes - i * 5)
                    if duration > 0 {
                        let session = SessionRecord(type: .breathing, duration: duration, date: sessionDate)
                        
                        // 更新统计
                        self.updateDayStats(for: date, session: session)
                    }
                }
            }
            
            // 删除旧数据
            UserDefaults.standard.removeObject(forKey: oldKey)
        }
    }
    
    /// 清理过期数据（保留一年）
    func cleanupOldData() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let calendar = Calendar.current
            let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date())!
            
            // 清理会话记录
            let sessions = self.loadSessions()
            let recentSessions = sessions.filter { $0.date >= oneYearAgo }
            self.saveSessions(recentSessions)
            
            // 清理日统计
            let allStats = self.loadDailyStats()
            let recentStats = allStats.filter { (key, stats) in
                stats.date >= oneYearAgo
            }
            self.saveDailyStats(recentStats)
            
            // 清理缓存
            self.cachedDailyStats = recentStats
            self.cachedSessions = recentSessions
        }
    }
    
    // MARK: - Widget数据同步
    
    /// 同步数据到Widget
    private func syncWidgetData() {
        let today = Date()
        let todayMinutes = minutes(on: today)
        let todaySessions = sessionsCount(on: today)
        let streakDays = calculateStreakDays()
        
        // 更新Widget数据
        WidgetDataManager.shared.updateTodayData(minutes: todayMinutes, sessions: todaySessions)
        WidgetDataManager.shared.updateStreakDays(streakDays)
        
        // 更新最后会话时间
        if let lastSession = getAllSessions().first {
            WidgetDataManager.shared.updateLastSessionTime(lastSession.date)
        }
    }
    
    /// 初始化Widget数据（在App启动时调用）
    func initializeWidgetData() {
        syncWidgetData()
        
        // 如果没有数据，初始化示例数据用于展示
        let (minutes, sessions) = WidgetDataManager.shared.getTodayData()
        if minutes == 0 && sessions == 0 {
            WidgetDataManager.shared.initializeSampleData()
        }
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let relaxStatsUpdated = Notification.Name("relaxStatsUpdated")
    static let startSessionFromWidget = Notification.Name("startSessionFromWidget")
}