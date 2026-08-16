import SwiftUI
import UIKit

// 绘画路径数据结构
struct DrawingPath {
    var points: [CGPoint]
    var pressures: [CGFloat] // 存储每个点的压力值
    var color: Color
    var baseLineWidth: CGFloat
    
    init(color: Color, baseLineWidth: CGFloat = 2.0) {
        self.points = []
        self.pressures = []
        self.color = color
        self.baseLineWidth = baseLineWidth
    }
}

// 用于获取真实触摸力度的UIView包装器
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var paths: [DrawingPath]
    @Binding var currentPath: DrawingPath?
    @Binding var currentColorIndex: Int
    @Binding var strokeCount: Int
    @Binding var lastTouchTime: Date?
    let colorThemes: [[Color]]
    let canvasSize: CGSize
    
    func makeUIView(context: Context) -> DrawingCanvas {
        let canvas = DrawingCanvas()
        canvas.delegate = context.coordinator
        canvas.backgroundColor = UIColor(red: 1.0, green: 0.953, blue: 0.847, alpha: 1.0)
        return canvas
    }
    
    func updateUIView(_ uiView: DrawingCanvas, context: Context) {
        uiView.paths = paths
        uiView.currentPath = currentPath
        uiView.setNeedsDisplay()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, DrawingCanvasDelegate {
        var parent: DrawingCanvasView
        
        init(_ parent: DrawingCanvasView) {
            self.parent = parent
        }
        
        func didStartDrawing(at point: CGPoint, force: CGFloat) {
            parent.lastTouchTime = Date()
            let currentTheme = parent.colorThemes[parent.currentColorIndex % parent.colorThemes.count]
            let colorInTheme = currentTheme.randomElement() ?? Color.blue
            
            parent.currentPath = DrawingPath(color: colorInTheme, baseLineWidth: 3.0)
            parent.currentPath?.points.append(point)
            parent.currentPath?.pressures.append(force)
            
            parent.strokeCount += 1
            if parent.strokeCount >= 3 {
                parent.strokeCount = 0
                parent.currentColorIndex += 1
            }
        }
        
        func didContinueDrawing(at point: CGPoint, force: CGFloat) {
            parent.lastTouchTime = Date()
            parent.currentPath?.points.append(point)
            parent.currentPath?.pressures.append(force)
        }
        
        func didFinishDrawing() {
            if let path = parent.currentPath {
                parent.paths.append(path)
                parent.currentPath = nil
            }
        }
    }
}

protocol DrawingCanvasDelegate: AnyObject {
    func didStartDrawing(at point: CGPoint, force: CGFloat)
    func didContinueDrawing(at point: CGPoint, force: CGFloat)
    func didFinishDrawing()
}

class DrawingCanvas: UIView {
    weak var delegate: DrawingCanvasDelegate?
    var paths: [DrawingPath] = []
    var currentPath: DrawingPath?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 获取真实触摸力度，如果不支持则使用默认值
        let force = touch.force > 0 ? max(0.3, min(2.0, touch.force)) : 0.8
        delegate?.didStartDrawing(at: location, force: force)
        setNeedsDisplay()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 获取真实触摸力度，如果不支持则使用默认值
        let force = touch.force > 0 ? max(0.3, min(2.0, touch.force)) : 0.8
        delegate?.didContinueDrawing(at: location, force: force)
        setNeedsDisplay()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.didFinishDrawing()
        setNeedsDisplay()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.didFinishDrawing()
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let centerX = bounds.width / 2
        
        // 绘制所有完成的路径
        for path in paths {
            drawPath(context: context, path: path, centerX: centerX)
        }
        
        // 绘制当前路径
        if let currentPath = currentPath {
            drawPath(context: context, path: currentPath, centerX: centerX)
        }
    }
    
    private func drawPath(context: CGContext, path: DrawingPath, centerX: CGFloat) {
        guard path.points.count > 1 else { return }
        
        // 绘制原始路径
        drawSinglePath(context: context, points: path.points, pressures: path.pressures, color: path.color, baseLineWidth: path.baseLineWidth)
        
        // 绘制镜像路径
        let mirroredPoints = path.points.map { point in
            CGPoint(x: centerX * 2 - point.x, y: point.y)
        }
        drawSinglePath(context: context, points: mirroredPoints, pressures: path.pressures, color: path.color, baseLineWidth: path.baseLineWidth)
    }
    
    private func drawSinglePath(context: CGContext, points: [CGPoint], pressures: [CGFloat], color: Color, baseLineWidth: CGFloat) {
        guard points.count > 1, pressures.count == points.count else { return }
        
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        for i in 0..<(points.count - 1) {
            let startPoint = points[i]
            let endPoint = points[i + 1]
            let startPressure = pressures[i]
            let endPressure = pressures[i + 1]
            
            let avgWidth = baseLineWidth * (startPressure + endPressure) / 2
            
            context.setLineWidth(avgWidth)
            context.setStrokeColor(UIColor(color).withAlphaComponent(0.7).cgColor)
            
            context.beginPath()
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }
    }
}

struct DrawingSessionView: View {
    @State private var showLoadingScreen = true
    @State private var showDrawingCanvas = false
    @State private var paths: [DrawingPath] = []
    @State private var currentPath: DrawingPath?
    @State private var currentColorIndex = 0
    @State private var strokeCount = 0
    @State private var lastTouchTime: Date?
    @State private var showClearButton = false
    @State private var buttonCheckTimer: Timer?
    @State private var sessionStart: Date = Date()
    @State private var hasRecorded: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    // 缤纷色系主题 - 更加梦幻绚烂的颜色
    private let colorThemes: [[Color]] = [
        // 梦幻粉紫色系 - 少女心
        [Color(red: 1.0, green: 0.4, blue: 0.8), Color(red: 0.9, green: 0.3, blue: 0.9), Color(red: 1.0, green: 0.6, blue: 0.9)],
        // 海洋蓝绿色系 - 清新海洋
        [Color(red: 0.0, green: 0.7, blue: 1.0), Color(red: 0.2, green: 0.9, blue: 0.8), Color(red: 0.0, green: 0.8, blue: 0.9)],
        // 温暖橙黄色系 - 夕阳温暖
        [Color(red: 1.0, green: 0.5, blue: 0.0), Color(red: 1.0, green: 0.8, blue: 0.2), Color(red: 1.0, green: 0.6, blue: 0.1)],
        // 森林绿色系 - 自然生机
        [Color(red: 0.2, green: 0.8, blue: 0.3), Color(red: 0.4, green: 0.9, blue: 0.5), Color(red: 0.1, green: 0.7, blue: 0.4)],
        // 浪漫红色系 - 热情如火
        [Color(red: 1.0, green: 0.2, blue: 0.4), Color(red: 0.9, green: 0.1, blue: 0.3), Color(red: 1.0, green: 0.3, blue: 0.5)],
        // 神秘紫色系 - 魔幻紫罗兰
        [Color(red: 0.6, green: 0.2, blue: 0.9), Color(red: 0.5, green: 0.0, blue: 0.8), Color(red: 0.7, green: 0.3, blue: 1.0)],
        // 彩虹混合色系 - 绚烂多彩
        [Color(red: 1.0, green: 0.0, blue: 0.5), Color(red: 0.0, green: 1.0, blue: 0.5), Color(red: 0.5, green: 0.0, blue: 1.0)],
        // 极光色系 - 梦幻极光
        [Color(red: 0.3, green: 1.0, blue: 0.8), Color(red: 0.8, green: 0.3, blue: 1.0), Color(red: 1.0, green: 0.8, blue: 0.3)]
    ]
    
    var body: some View {
        ZStack {
            if showLoadingScreen {
                // 缓冲页面
                loadingView
            } else if showDrawingCanvas {
                // 绘画画布页面
                drawingCanvasView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden)
        .onAppear {
            sessionStart = Date()
            startLoadingSequence()
        }
        .onDisappear {
            buttonCheckTimer?.invalidate()
        }
    }
    
    // MARK: - 缓冲页面
    private var loadingView: some View {
        ZStack {
            // 背景色 - 严格按照要求的颜色 #FFF3D8
            Color(red: 1.0, green: 0.953, blue: 0.847) // #FFF3D8
                .ignoresSafeArea(.all)
            
            VStack(spacing: 30) {
                // 中间图标 - 使用绘画相关的图标
                ZStack {
                    // 外圈装饰 - 使用柠檬绿 #D0F657
                    Circle()
                        .stroke(Color(red: 0.819, green: 0.965, blue: 0.345).opacity(0.3), lineWidth: 4)
                        .frame(width: 120, height: 120)
                    
                    // 内圈背景 - 使用柠檬绿 #D0F657
                    Circle()
                        .fill(Color(red: 0.819, green: 0.965, blue: 0.345))
                        .frame(width: 80, height: 80)
                    
                    // 绘画图标
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                .scaleEffect(showLoadingScreen ? 1.0 : 0.8)
                .opacity(showLoadingScreen ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: showLoadingScreen)
                
                // 加载文字 - 使用橙黄色 #FFCB68
                Text("准备绘画...")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(red: 1.0, green: 0.796, blue: 0.408)) // #FFCB68
                    .opacity(showLoadingScreen ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.3), value: showLoadingScreen)
            }
        }
    }
    
    // MARK: - 绘画画布页面
    private var drawingCanvasView: some View {
        GeometryReader { geometry in
            ZStack {
                // 纯色背景 - 严格按照要求的颜色 #FFF3D8
                Color(red: 1.0, green: 0.953, blue: 0.847)
                    .ignoresSafeArea(.all)
                
                // 使用UIKit包装的绘画画布（支持真实压力感应）
                DrawingCanvasView(
                    paths: $paths,
                    currentPath: $currentPath,
                    currentColorIndex: $currentColorIndex,
                    strokeCount: $strokeCount,
                    lastTouchTime: $lastTouchTime,
                    colorThemes: colorThemes,
                    canvasSize: geometry.size
                )
                
                // 左上角返回按钮（统一组件与位置）
                VStack {
                    HStack {
                        BackButton.defaultStyle {
                            completeSession()
                        }
                        .padding(.leading, 20)
                        .padding(.top, 50)
                        Spacer()
                    }
                    Spacer()
                }
                
                // 底部清屏按钮
                VStack {
                    Spacer()
                    
                    if showClearButton {
                        Button(action: {
                            clearCanvas()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 14, weight: .medium))
                                Text("清除画布")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                // 磨砂玻璃效果背景
                                ZStack {
                                    // 半透明背景
                                    RoundedRectangle(cornerRadius: 6) // 15% 圆角（按钮高度约40，40*0.15≈6）
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.95)
                                    
                                    // 渐变叠加层增强视觉效果
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.1)
                                                ]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
    
    // MARK: - Session 完成

    private func completeSession() {
        guard !hasRecorded else {
            dismiss()
            return
        }
        hasRecorded = true
        buttonCheckTimer?.invalidate()

        let durationMinutes = max(1, Int((Date().timeIntervalSince(sessionStart) / 60.0).rounded()))
        RelaxStatsStore.shared.addSession(
            type: .drawing,
            duration: durationMinutes,
            date: Date()
        )

        dismiss()
    }

    // MARK: - 绘画功能

    private func clearCanvas() {
        withAnimation(.easeInOut(duration: 0.3)) {
            paths.removeAll()
            currentPath = nil
            strokeCount = 0
            currentColorIndex = 0
            showClearButton = false
        }
    }
    
    private func startButtonCheckTimer() {
        buttonCheckTimer?.invalidate()
        buttonCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            checkButtonVisibility()
        }
    }
    
    private func checkButtonVisibility() {
        guard let lastTime = lastTouchTime else {
            // 如果从未触摸过，不显示按钮
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showClearButton = false
            }
            return
        }
        
        let timeSinceLastTouch = Date().timeIntervalSince(lastTime)
        
        if timeSinceLastTouch >= 3.0 {
            // 停止绘画超过3秒，显示按钮
            if !showClearButton && !paths.isEmpty {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showClearButton = true
                }
            }
        } else {
            // 正在绘画，隐藏按钮
            if showClearButton {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    showClearButton = false
                }
            }
        }
    }
    
    // MARK: - 加载序列
    private func startLoadingSequence() {
        // 1秒后隐藏图标，再0.3秒后显示绘画画布
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showLoadingScreen = false
            }
            
            // 图标消失后显示画布
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showDrawingCanvas = true
                // 启动按钮显示检查定时器
                startButtonCheckTimer()
            }
        }
    }
}

#Preview {
    DrawingSessionView()
}
