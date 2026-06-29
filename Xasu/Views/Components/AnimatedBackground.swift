import SwiftUI

struct AnimatedBackground: View {

    @State private var phase: Double = 0

    var body: some View {
        ZStack {
            Color.xasuBackground.ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1/30)) { ctx in
                Canvas { context, size in
                    let t = ctx.date.timeIntervalSinceReferenceDate

                    func blob(x: CGFloat, y: CGFloat, r: CGFloat, color: Color, speed: Double, drift: CGFloat) {
                        let ox = x + cos(t * speed) * drift
                        let oy = y + sin(t * speed * 0.7) * drift * 0.8
                        var resolved = context
                        resolved.addFilter(.blur(radius: r * 0.55))
                        resolved.fill(
                            Path(ellipseIn: CGRect(x: ox - r, y: oy - r, width: r * 2, height: r * 2)),
                            with: .color(color)
                        )
                    }

                    let w = size.width, h = size.height

                    blob(x: w * 0.2, y: h * 0.3,  r: 160, color: Color.xasuPurple.opacity(0.28), speed: 0.18, drift: 40)
                    blob(x: w * 0.8, y: h * 0.25, r: 120, color: Color.xasuCyan.opacity(0.18),   speed: 0.13, drift: 55)
                    blob(x: w * 0.5, y: h * 0.7,  r: 200, color: Color.xasuPurple.opacity(0.15), speed: 0.10, drift: 35)
                    blob(x: w * 0.75,y: h * 0.65, r: 90,  color: Color.xasuCyan.opacity(0.12),   speed: 0.22, drift: 45)
                    blob(x: w * 0.15,y: h * 0.8,  r: 130, color: Color(red:0.6,green:0.2,blue:0.9).opacity(0.13), speed: 0.15, drift: 30)
                }
            }
            .ignoresSafeArea()
        }
    }
}

#Preview { AnimatedBackground() }
