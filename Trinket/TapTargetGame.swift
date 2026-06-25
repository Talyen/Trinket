import CoreGraphics

struct TapTargetGame {
    private(set) var score = 0
    private(set) var targetPosition = CGPoint(x: 140, y: 160)

    mutating func hitTarget(in playfieldSize: CGSize) {
        score += 1
        moveTarget(in: playfieldSize)
    }

    mutating func reset(in playfieldSize: CGSize) {
        score = 0
        targetPosition = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)
    }

    private mutating func moveTarget(in playfieldSize: CGSize) {
        let radius: CGFloat = 36
        let xRange = radius...max(radius, playfieldSize.width - radius)
        let yRange = radius...max(radius, playfieldSize.height - radius)
        targetPosition = CGPoint(x: CGFloat.random(in: xRange), y: CGFloat.random(in: yRange))
    }
}
