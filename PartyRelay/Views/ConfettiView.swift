import SwiftUI

/// 获胜撒花：Canvas + TimelineView 粒子动画
struct ConfettiView: View {
    private struct Particle {
        var x: Double          // 0~1 相对横坐标
        var speed: Double      // 下落速度
        var drift: Double      // 横向摆动幅度
        var phase: Double
        var size: Double
        var color: Color
        var spin: Double
        var delay: Double
    }

    private let particles: [Particle]
    private let startDate = Date()

    init(count: Int = 90) {
        let palette: [Color] = [.red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple, .pink]
        particles = (0..<count).map { _ in
            Particle(x: .random(in: 0...1),
                     speed: .random(in: 0.10...0.28),
                     drift: .random(in: 0.01...0.06),
                     phase: .random(in: 0...(2 * .pi)),
                     size: .random(in: 6...13),
                     color: palette.randomElement()!,
                     spin: .random(in: 1.5...5),
                     delay: .random(in: 0...2.5))
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(startDate)
                for p in particles {
                    let localT = t - p.delay
                    guard localT > 0 else { continue }
                    // 循环下落
                    let progress = (localT * p.speed).truncatingRemainder(dividingBy: 1.2)
                    let y = progress / 1.2 * (size.height + 60) - 30
                    let x = (p.x + sin(localT * 2 + p.phase) * p.drift) * size.width
                    let angle = localT * p.spin

                    var ctx = context
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(angle))
                    // 用宽高比+旋转模拟纸片翻飞
                    let w = p.size
                    let h = p.size * abs(sin(localT * 3 + p.phase)) * 0.8 + 2
                    let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(p.color))
                }
            }
        }
    }
}
