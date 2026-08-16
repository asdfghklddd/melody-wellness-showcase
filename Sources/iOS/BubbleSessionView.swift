import SwiftUI

// 定义泡泡的数据结构
struct Bubble: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var color: Color
    var isPopped: Bool = false
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
    
    // 物理运动属性
    var velocity: CGVector // 速度向量
    var acceleration: CGVector = CGVector(dx: 0, dy: 0) // 加速度
    var bounceCount: Int = 0 // 反弹次数，用于增加随机性
    
    init(position: CGPoint, size: CGFloat, color: Color) {
        self.position = position
        self.size = size
        self.color = color
        
        // 随机初始速度
        let speed: CGFloat = CGFloat.random(in: 30...80)
        let angle = CGFloat.random(in: 0...(2 * .pi))
        self.velocity = CGVector(
            dx: speed * cos(angle),
            dy: speed * sin(angle)
        )
    }
}

struct BubbleSessionView: View {
    @Environment(\.dismiss) private var dismiss
    
    // 游戏状态变量
    @State private var bubbles: [Bubble] = []
    @State private var score: Int = 0
    @State private var timeRemaining: Int = 60
    @State private var isGameActive: Bool = false
    @State private var sessionStart: Date = Date()
    @State private var hasRecorded: Bool = false
    @State private var showEndView: Bool = false
    
    // 定时器
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let bubbleTimer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()
    private let animationTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect() // 60fps动画
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色
                Color(red: 1, green: 0.97, blue: 0.45)
                    .ignoresSafeArea(.all, edges: .all)
                
                VStack(spacing: 0) {
                    
                    // 游戏状态栏
                    HStack {
                        // 返回按钮
                        BackButton.defaultStyle {
                            dismiss()
                        }
                        
                        VStack(alignment: .leading) {
                            Text("得分: \(score)")
                                .font(.subheadline)
                                .foregroundColor(.black)
                            Text("时间: \(timeRemaining)s")
                                .font(.subheadline)
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isGameActive.toggle()
                        }) {
                            Text(isGameActive ? "暂停" : "开始")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isGameActive ? Color.orange : Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    
                    Spacer()
                }
                
                // 泡泡区域
                ZStack {
                    ForEach(bubbles) { bubble in
                        if !bubble.isPopped {
                            // 增强的泡泡视觉效果
                            ZStack {
                                // 主泡泡
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                bubble.color.opacity(0.8),
                                                bubble.color.opacity(0.3),
                                                bubble.color.opacity(0.1)
                                            ]),
                                            center: UnitPoint(x: 0.3, y: 0.3),
                                            startRadius: 1,
                                            endRadius: bubble.size / 2
                                        )
                                    )
                                    .frame(width: bubble.size, height: bubble.size)
                                    .overlay(
                                        // 光泽效果
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color.white.opacity(0.6),
                                                        Color.white.opacity(0.2),
                                                        Color.clear
                                                    ]),
                                                    startPoint: UnitPoint(x: 0.2, y: 0.2),
                                                    endPoint: UnitPoint(x: 0.8, y: 0.8)
                                                )
                                            )
                                            .frame(width: bubble.size * 0.6, height: bubble.size * 0.6)
                                            .offset(x: -bubble.size * 0.15, y: -bubble.size * 0.15)
                                    )
                                    .shadow(color: bubble.color.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .position(bubble.position)
                            .opacity(bubble.opacity)
                            .scaleEffect(bubble.scale)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: bubble.scale)
                            .animation(.linear(duration: 0), value: bubble.position) // 平滑位置动画
                            .onTapGesture {
                                popBubble(bubble)
                            }
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            checkBubbleTap(at: value.location)
                        }
                )
                
                // 游戏结束提示和按钮
                if timeRemaining <= 0 {
                    VStack(spacing: 20) {
                        Text("游戏结束!")
                            .font(.title)
                            .foregroundColor(.black)
                        
                        Text("最终得分: \(score)")
                            .font(.title2)
                            .foregroundColor(.black)
                        
                        HStack(spacing: 20) {
                            Button("重新开始") {
                                resetGame()
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            // 修正后的“结束”按钮，使用 NavigationLink 跳转
                            Button(action: {
                                completeAndDismiss()
                            }) {
                                Text("结束")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                    // 调整 padding 以增加宽度。原来的 padding 是 40，现在增加 30% 就是 40 * 1.3 = 52
                    .padding(52) // 调整此值以使白色方框更宽
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)
                }
            }
        }
        .onAppear {
            startGame()
            // 预加载泡泡破裂音效
            SoundEffectManager.shared.preloadPopIfNeeded()
        }
        .onReceive(timer) { _ in
            if isGameActive && timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
        .onReceive(bubbleTimer) { _ in
            if isGameActive && timeRemaining > 0 {
                addRandomBubble()
            }
        }
        .onReceive(animationTimer) { _ in
            if isGameActive {
                updateBubblePositions()
            }
        }
        .navigationBarHidden(true) // 隐藏原生导航栏，使用自定义返回按钮
        #if os(iOS)
        .navigationDestination(isPresented: $showEndView) {
            SessionEndView(
                sessionType: "戳泡泡",
                duration: max(1, Int((Date().timeIntervalSince(sessionStart) / 60.0).rounded())),
                score: score,
                onComplete: {
                    dismiss()
                }
            )
        }
        #endif
    }
    
    private func startGame() {
        isGameActive = true
        score = 0
        timeRemaining = 60
        sessionStart = Date()
        bubbles.removeAll()
        
        // 初始生成几个泡泡
        for _ in 0..<2 {
            addRandomBubble()
        }
    }
    
    private func resetGame() {
        startGame()
    }

    private func completeAndDismiss() {
        if !hasRecorded {
            hasRecorded = true
            let minutes = max(1, Int((Date().timeIntervalSince(sessionStart) / 60.0).rounded()))
            RelaxStatsStore.shared.addSession(type: .bubble, duration: minutes, date: Date())
        }
        // 触觉反馈
        #if canImport(UIKit)
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        #endif
        // 结束后先进入小狗欢呼页，由欢呼页的返回按钮再回主页
        showEndView = true
    }
    
    private func addRandomBubble() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height - 200
        
        let randomX = CGFloat.random(in: 80...(screenWidth - 80))
        let randomY = CGFloat.random(in: 180...(screenHeight - 80))
        let randomSize = CGFloat.random(in: 60...120)
        
        let colors: [Color] = [
            Color(red: 1.0, green: 0.3, blue: 0.3),    // 鲜红色
            Color(red: 0.2, green: 0.8, blue: 1.0),    // 亮蓝色
            Color(red: 1.0, green: 0.6, blue: 0.0),    // 橙色
            Color(red: 0.4, green: 1.0, blue: 0.4),    // 鲜绿色
            Color(red: 1.0, green: 0.2, blue: 0.8),    // 品红色
            Color(red: 0.8, green: 0.4, blue: 1.0),    // 紫色
            Color(red: 1.0, green: 0.8, blue: 0.0),    // 金黄色
            Color(red: 0.0, green: 0.9, blue: 0.7)     // 青绿色
        ]
        
        let randomColor = colors.randomElement() ?? Color.orange
        
        let newBubble = Bubble(
            position: CGPoint(x: randomX, y: randomY),
            size: randomSize,
            color: randomColor
        )
        
        bubbles.append(newBubble)
        
        if bubbles.count > 6 {
            bubbles.removeFirst()
        }
    }
    
    // 更新泡泡位置和处理边界碰撞
    private func updateBubblePositions() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height - 100
        
        for index in bubbles.indices {
            if bubbles[index].isPopped { continue }
            
            var bubble = bubbles[index]
            let radius = bubble.size / 2
            
            // 更新位置
            bubble.position.x += bubble.velocity.dx * 0.016
            bubble.position.y += bubble.velocity.dy * 0.016
            
            // 边界碰撞检测和反弹
            var bounced = false
            
            // 左右边界
            if bubble.position.x - radius <= 0 || bubble.position.x + radius >= screenWidth {
                bubble.velocity.dx = -bubble.velocity.dx
                bubble.position.x = max(radius, min(screenWidth - radius, bubble.position.x))
                bounced = true
            }
            
            // 上下边界
            if bubble.position.y - radius <= 100 || bubble.position.y + radius >= screenHeight {
                bubble.velocity.dy = -bubble.velocity.dy
                bubble.position.y = max(100 + radius, min(screenHeight - radius, bubble.position.y))
                bounced = true
            }
            
            // 反弹后添加一些随机性
            if bounced {
                bubble.bounceCount += 1
                if bubble.bounceCount % 3 == 0 {
                    // 每3次反弹后稍微调整角度，增加趣味性
                    let randomAngleChange = CGFloat.random(in: -0.3...0.3)
                    let currentAngle = atan2(bubble.velocity.dy, bubble.velocity.dx)
                    let newAngle = currentAngle + randomAngleChange
                    let speed = sqrt(bubble.velocity.dx * bubble.velocity.dx + bubble.velocity.dy * bubble.velocity.dy)
                    
                    bubble.velocity.dx = speed * cos(newAngle)
                    bubble.velocity.dy = speed * sin(newAngle)
                }
                
                // 添加轻微的速度衰减，更真实
                bubble.velocity.dx *= 0.98
                bubble.velocity.dy *= 0.98
            }
            
            // 确保最小速度，防止泡泡停下来
            let minSpeed: CGFloat = 20
            let currentSpeed = sqrt(bubble.velocity.dx * bubble.velocity.dx + bubble.velocity.dy * bubble.velocity.dy)
            if currentSpeed < minSpeed {
                let speedMultiplier = minSpeed / currentSpeed
                bubble.velocity.dx *= speedMultiplier
                bubble.velocity.dy *= speedMultiplier
            }
            
            bubbles[index] = bubble
        }
    }
    
    private func popBubble(_ bubble: Bubble) {
        guard let index = bubbles.firstIndex(where: { $0.id == bubble.id }) else { return }
        
        // 增强的爆破效果
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            bubbles[index].isPopped = true
            bubbles[index].scale = 1.5 // 先放大
            bubbles[index].opacity = 0.8
        }

        // 播放泡泡破裂音效
        SoundEffectManager.shared.playPop()
        
        // 然后快速缩小消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                if index < bubbles.count {
                    bubbles[index].scale = 0
                    bubbles[index].opacity = 0
                }
            }
        }
        
        score += Int(bubble.size / 10) + 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            bubbles.removeAll { $0.id == bubble.id }
        }
        
        // 减少生成新泡泡的频率
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if isGameActive && bubbles.count < 4 {
                addRandomBubble()
            }
        }
    }
    
    private func checkBubbleTap(at location: CGPoint) {
        for bubble in bubbles {
            let distance = sqrt(
                pow(location.x - bubble.position.x, 2) +
                pow(location.y - bubble.position.y, 2)
            )
            
            if distance <= bubble.size / 2 {
                popBubble(bubble)
                break
            }
        }
    }
}

#Preview {
    BubbleSessionView()
}
