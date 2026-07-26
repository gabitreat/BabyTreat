import SwiftUI

struct FormulaView: View {
    private let maxMilliliters: Double = 300
    private let scaleVar: CGFloat = 1.5 // Change this to scale the square (1.0 = 300pt, 1.67 ≈ 500pt)
    @State private var milliliters: Double = 30

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.teal.opacity(0.3)
                    .ignoresSafeArea()

                VStack {
                    // Title at top
                    Text("Formula")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 60)

                    // Milliliters Display
                    Text("\(Int(milliliters)) ml")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.bottom, 20)

                    Spacer()

                    // Baby bottle container
                    ZStack {
                        // Bottle outline components
                        VStack(spacing: bottleSpacing) {
                            // Upper nipple (circle)
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: upperNippleSize, height: upperNippleSize)
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    .frame(width: upperNippleSize, height: upperNippleSize)
                            }

                            // Base nipple (horizontal rounded rectangle)
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white)
                                    .frame(width: baseNippleWidth, height: baseNippleHeight)
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    .frame(width: baseNippleWidth, height: baseNippleHeight)
                            }

                            // Bottle body (main container)
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    .frame(width: bottleWidth, height: bottleHeight)

                                // Fill area within bottle body
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.teal)
                                    .frame(width: bottleWidth - 4, height: fillHeightInBottle)
                            }
                        }

                        // Bottle body with measurement lines (positioned inside)
                        VStack(spacing: bottleSpacing) {
                            // Empty space for nipples
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: upperNippleSize + bottleSpacing + baseNippleHeight)

                            // Bottle body area with lines
                            ZStack {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: bottleWidth, height: bottleHeight)

                                // Major measurement lines (every 30ml) - only in bottle area
                                ForEach(Array(stride(from: 30, through: Int(maxMilliliters), by: 30)), id: \.self) { value in
                                    HStack {
                                        Spacer()
                                        Rectangle()
                                            .fill(Color.white.opacity(0.9))
                                            .frame(width: 40, height: 2)
                                        Text("\(value)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 30, alignment: .leading)
                                            .padding(.leading, 3)
                                    }
                                    .frame(width: bottleWidth)
                                    .offset(y: (bottleHeight / 2) - (CGFloat(value) / maxMilliliters * bottleHeight))
                                }

                                // Minor measurement lines (every 5ml) - only in bottle area
                                ForEach(Array(stride(from: 5, through: Int(maxMilliliters), by: 5).filter { $0 % 30 != 0 }), id: \.self) { value in
                                    HStack {
                                        Spacer()
                                        Rectangle()
                                            .fill(Color.white.opacity(0.5))
                                            .frame(width: 20, height: 1)
                                        Spacer()
                                            .frame(width: 60)
                                    }
                                    .frame(width: bottleWidth)
                                    .offset(y: (bottleHeight / 2) - (CGFloat(value) / maxMilliliters * bottleHeight))
                                }
                            }
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                updateMilliliters(from: value.location.y)
                            }
                    )

                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }

    // Bottle dimensions
    private var bottleWidth: CGFloat {
        200 * scaleVar
    }

    private var bottleHeight: CGFloat {
        280 * scaleVar
    }

    private var baseNippleWidth: CGFloat {
        160 * scaleVar
    }

    private var baseNippleHeight: CGFloat {
        40 * scaleVar
    }

    private var upperNippleSize: CGFloat {
        30 * scaleVar
    }

    private var bottleSpacing: CGFloat {
        10 * scaleVar
    }

    private var totalBottleHeight: CGFloat {
        upperNippleSize + bottleSpacing + baseNippleHeight + bottleSpacing + bottleHeight
    }

    private var fillHeightInBottle: CGFloat {
        let percentage = milliliters / maxMilliliters
        return bottleHeight * CGFloat(percentage)
    }

    private func updateMilliliters(from yPosition: CGFloat) {
        // Convert drag position relative to bottle body only
        let bottleStartY = upperNippleSize + bottleSpacing + baseNippleHeight + bottleSpacing
        let adjustedY = yPosition - bottleStartY
        let percentage = max(0, min(1, (bottleHeight - adjustedY) / bottleHeight))
        let rawValue = percentage * maxMilliliters
        // Snap to nearest 5ml increment
        milliliters = round(rawValue / 5.0) * 5.0
    }
}
