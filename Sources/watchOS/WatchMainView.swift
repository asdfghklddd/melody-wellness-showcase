//
//  WatchMainView.swift
//  Melody for watchOS
//
//  Created on 2025
//

import SwiftUI

struct WatchMainView: View {
    // 同步的AI问候语/推荐文本
    @State private var greetingText: String = "下午好，欢迎来到Melody"
    
    // 当前时间
    @State private var currentTime = Date()
    
    // 日程数据（模拟，后续从iPhone同步）
    @State private var scheduleSegments: [ScheduleSegment] = []
    
    // 圆环旋转角度
    @State private var ringRotation: Double = 0
    
    var body: some View {
        ZStack {
            // 背景色 - 与iOS主页一致
            Color(red: 1.0, green: 0.953, blue: 0.847) // #FFF3D8
                .ignoresSafeArea()
            
            VStack(spacing: 6) {
                // 顶部：灵动岛样式的文本框
                topGreetingCard
                    .padding(.top, 8)
                
                // 上方拉伸，让中部区域整体更靠下
                Spacer(minLength: 4)
                
                // 中间：半圆环日程可视化
                scheduleRingView
                
                // 底部：小狗动画（暂用PNG）
                dogImageView
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 8)
        }
        .onAppear {
            startTimeUpdate()
            loadMockSchedule()
        }
    }
    
    // MARK: - 顶部问候卡片（灵动岛样式）
    private var topGreetingCard: some View {
        Text(greetingText)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.black)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15) // 15%圆角
                    .fill(Color(red: 0.988, green: 0.898, blue: 0.737)) // #FCE5BC 橙色
            )
            .padding(.horizontal, 4)
    }
    
    // MARK: - 中间半圆环日程可视化
    private var scheduleRingView: some View {
        ZStack {
            // 背景半圆环（浅色底）
            Circle()
                .trim(from: 0, to: 0.5) // 只显示上半部分
                .stroke(
                    Color(red: 0.968, green: 0.639, blue: 0.0).opacity(0.15), // 浅橙色底
                    style: StrokeStyle(lineWidth: 28, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90)) // 让半圆朝上
            
            // 日程色块段（可旋转）
            ForEach(scheduleSegments) { segment in
                Circle()
                    .trim(from: segment.startFraction, to: segment.endFraction)
                    .stroke(
                        segment.isBreak ? 
                            Color.gray.opacity(0.35) : // 休息时间半透明灰色
                            segment.color.opacity(0.85), // 日程时间有颜色
                        style: StrokeStyle(lineWidth: 28, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90 + ringRotation)) // 圆环旋转
            }
            
            // 固定的指针（在12点钟方向，不移动）
            pointerView
        }
        .frame(height: 130)
    }
    
    // 固定指针视图（在12点钟方向，不移动）
    private var pointerView: some View {
        VStack(spacing: 2) {
            // 指针三角形（向下指）
            Triangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.796, blue: 0.408), // #FFCB68
                            Color(red: 0.968, green: 0.639, blue: 0.0)  // #F7A300
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 14, height: 16)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            
            // 指针小圆点
            Circle()
                .fill(Color(red: 0.968, green: 0.639, blue: 0.0)) // #F7A300
                .frame(width: 6, height: 6)
                .shadow(color: .orange.opacity(0.4), radius: 2)
        }
        .offset(y: -94) // 放在更大的圆环外侧上方
    }
    
    // MARK: - 底部小狗图片
    private var dogImageView: some View {
        Image("dog") // 使用小狗png
            .resizable()
            .scaledToFit()
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
    }
    
    // MARK: - 时间更新
    private func startTimeUpdate() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            currentTime = Date()
            updateRingRotation()
        }
        updateRingRotation()
    }
    
    // 更新圆环旋转角度
    private func updateRingRotation() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        
        // 计算当前时间在24小时中的位置 (0-1)
        let timeOfDay = (hour + minute / 60.0) / 24.0
        
        // 转换为圆环旋转角度（逆时针旋转，让当前时间段移动到指针位置）
        // 指针在12点钟（-90度），我们需要让当前时间转到这个位置
        withAnimation(.linear(duration: 1.0)) {
            ringRotation = -(timeOfDay * 360.0) + 90 // 逆时针旋转
        }
    }
    
    // MARK: - 模拟日程数据
    private func loadMockSchedule() {
        let now = Date()
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        
        // 模拟一天的日程（7:00-22:00）
        // 早晨: 7:00-9:00 (空闲)
        let morning1Start = calendar.date(byAdding: .hour, value: 7, to: dayStart)!
        let morning1End = calendar.date(byAdding: .hour, value: 2, to: morning1Start)!
        
        // 工作: 9:00-11:30
        let work1Start = morning1End
        let work1End = calendar.date(byAdding: .minute, value: 150, to: work1Start)!
        
        // 午休: 11:30-13:00
        let lunchStart = work1End
        let lunchEnd = calendar.date(byAdding: .minute, value: 90, to: lunchStart)!
        
        // 工作: 13:00-15:00
        let work2Start = lunchEnd
        let work2End = calendar.date(byAdding: .hour, value: 2, to: work2Start)!
        
        // 休息: 15:00-15:30
        let break1Start = work2End
        let break1End = calendar.date(byAdding: .minute, value: 30, to: break1Start)!
        
        // 会议: 15:30-17:30
        let meetingStart = break1End
        let meetingEnd = calendar.date(byAdding: .hour, value: 2, to: meetingStart)!
        
        // 空闲: 17:30-19:00
        let evening1Start = meetingEnd
        let evening1End = calendar.date(byAdding: .minute, value: 90, to: evening1Start)!
        
        // 学习: 19:00-21:00
        let study1Start = evening1End
        let study1End = calendar.date(byAdding: .hour, value: 2, to: study1Start)!
        
        scheduleSegments = [
            ScheduleSegment(start: morning1Start, end: morning1End, isBreak: true, color: .gray),
            ScheduleSegment(start: work1Start, end: work1End, isBreak: false, color: Color(red: 0.3, green: 0.6, blue: 1.0)), // 蓝色-工作
            ScheduleSegment(start: lunchStart, end: lunchEnd, isBreak: true, color: .gray),
            ScheduleSegment(start: work2Start, end: work2End, isBreak: false, color: Color(red: 0.3, green: 0.8, blue: 0.4)), // 绿色-工作
            ScheduleSegment(start: break1Start, end: break1End, isBreak: true, color: .gray),
            ScheduleSegment(start: meetingStart, end: meetingEnd, isBreak: false, color: Color(red: 1.0, green: 0.639, blue: 0.0)), // 橙色-会议
            ScheduleSegment(start: evening1Start, end: evening1End, isBreak: true, color: .gray),
            ScheduleSegment(start: study1Start, end: study1End, isBreak: false, color: Color(red: 0.8, green: 0.3, blue: 0.8)) // 紫色-学习
        ]
    }
}

// MARK: - 日程段数据模型
struct ScheduleSegment: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let isBreak: Bool // 是否为休息时间
    let color: Color
    
    // 计算在圆环中的位置（0-0.5，因为只显示上半圆）
    var startFraction: Double {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: start)
        let secondsSinceMidnight = start.timeIntervalSince(dayStart)
        let totalSeconds: Double = 24 * 3600
        let fraction = secondsSinceMidnight / totalSeconds
        
        // 只使用上半圆 (0-0.5 对应 0-12点，0.5-1.0 对应 12-24点)
        // 但我们需要映射到整个圆环再只显示上半部分
        return fraction
    }
    
    var endFraction: Double {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: end)
        let secondsSinceMidnight = end.timeIntervalSince(dayStart)
        let totalSeconds: Double = 24 * 3600
        let fraction = secondsSinceMidnight / totalSeconds
        return fraction
    }
}

// MARK: - 三角形形状
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    WatchMainView()
}
