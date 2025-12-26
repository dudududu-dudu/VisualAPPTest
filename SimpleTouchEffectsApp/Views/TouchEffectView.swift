#if canImport(UIKit)
import UIKit
import AVFoundation

class TouchEffectView: UIView {

    private struct Node {
        var pos: CGPoint
        var radius: CGFloat
        var color: UIColor
        var life: CGFloat // 1.0 -> 0.0
        var seed: CGFloat
        var id: Int
    }

    private var nextNodeID: Int = 1

    private var nodes: [Node] = []
    private let linesLayer = CAShapeLayer()
    private let nodesLayer = CAShapeLayer()
    private let emitter = CAEmitterLayer()
    private var dotImageCache: [Int: UIImage] = [:]
    private var emitterCellPrototype: CAEmitterCell?
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isUserInteractionEnabled = true

        linesLayer.frame = bounds
        linesLayer.strokeColor = UIColor.white.withAlphaComponent(0.35).cgColor
        linesLayer.fillColor = UIColor.clear.cgColor
        linesLayer.lineWidth = 1.0
        layer.addSublayer(linesLayer)

        nodesLayer.frame = bounds
        nodesLayer.fillColor = UIColor.white.cgColor
        nodesLayer.opacity = 1.0
        layer.addSublayer(nodesLayer)

        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        layer.addSublayer(emitter)

        displayLink = CADisplayLink(target: self, selector: #selector(step(link:)))
        // reduce frequency to save CPU when many particles present
        if #available(iOS 10.0, *) {
            displayLink?.preferredFramesPerSecond = 30
        }
        displayLink?.add(to: .main, forMode: .common)

        // prepare a reusable emitter cell to avoid allocating every tap
        let proto = CAEmitterCell()
        proto.birthRate = 0
        proto.lifetime = 0.6
        proto.velocity = 80
        proto.velocityRange = 40
        proto.emissionRange = .pi * 2
        proto.scale = 0.02
        proto.scaleRange = 0.02
        emitterCellPrototype = proto
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        linesLayer.frame = bounds
        nodesLayer.frame = bounds
        emitter.frame = bounds
    }

    // MARK: - Touch handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        showTouchEffect(at: p)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        showTouchEffect(at: p)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // no-op: per-node notes stop when node life ends
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // no-op: per-node notes stop when node life ends
    }

    // Public API used by ViewController
    func showEffect(at point: CGPoint) {
        showTouchEffect(at: point)
    }

    // MARK: - Core effect
    private func showTouchEffect(at point: CGPoint) {
        // create node
        let radius = CGFloat(8 + arc4random_uniform(20))
        let hue = CGFloat(arc4random_uniform(100)) / 100.0
        let color = UIColor(hue: hue, saturation: 0.7, brightness: 1.0, alpha: 1.0)
        let seed = CGFloat(arc4random()) / CGFloat(UInt32.max)
        let id = nextNodeID
        nextNodeID += 1
        let node = Node(pos: point, radius: radius, color: color, life: 1.0, seed: seed, id: id)
        nodes.append(node)

        // start audio tied to this node id
        WindChimePlayer.shared.startNote(id: id)

        // emit some particles
        emitParticles(at: point, color: color)

        // haptic
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
    }

    private func emitParticles(at point: CGPoint, color: UIColor) {
        guard let proto = emitterCellPrototype else { return }
        // reuse prototype but make a light copy by creating a new cell and copying key properties
        let cell = CAEmitterCell()
        cell.birthRate = 200
        cell.lifetime = proto.lifetime
        cell.velocity = proto.velocity
        cell.velocityRange = proto.velocityRange
        cell.emissionRange = proto.emissionRange
        cell.scale = proto.scale
        cell.scaleRange = proto.scaleRange
        cell.contents = cachedDotCGImage(for: color)

        emitter.emitterPosition = point
        emitter.emitterSize = CGSize(width: 10, height: 10)
        emitter.emitterCells = [cell]

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.emitter.emitterCells = []
        }
    }

    private func cachedDotCGImage(for color: UIColor) -> CGImage? {
        // bucket colors by hue*100 to avoid creating many images
        var hue: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getHue(&hue, saturation: &s, brightness: &b, alpha: &a)
        let key = Int(hue * 100)
        if let img = dotImageCache[key]?.cgImage {
            return img
        }
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(origin: .zero, size: size))
        let ui = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        dotImageCache[key] = ui
        return ui.cgImage
    }

    // MARK: - Animation step
    @objc private func step(link: CADisplayLink) {
        if lastTimestamp == 0 { lastTimestamp = link.timestamp; return }
        let dt = CGFloat(link.timestamp - lastTimestamp)
        lastTimestamp = link.timestamp

        var needsRedraw = false

        // update life and limit node count
        var removedNodeIDs: [Int] = []
        for i in (0..<nodes.count).reversed() {
            nodes[i].life -= dt * 0.6
            if nodes[i].life <= 0 {
                removedNodeIDs.append(nodes[i].id)
                nodes.remove(at: i)
                needsRedraw = true
            } else {
                needsRedraw = true
            }
        }

        // stop audio for removed nodes (allow their last scheduled buffer to finish)
        for id in removedNodeIDs {
            WindChimePlayer.shared.stopNote(id: id)
        }

        // cap nodes to avoid unbounded growth
        let maxNodes = 60
        if nodes.count > maxNodes {
            let removeCount = nodes.count - maxNodes
            let removed = nodes.prefix(removeCount).map { $0.id }
            nodes.removeFirst(removeCount)
            needsRedraw = true
            for id in removed { WindChimePlayer.shared.stopNote(id: id) }
        }

        if needsRedraw {
            redrawLayers(time: CGFloat(link.timestamp))
        }
    }

    private func redrawLayers(time: CGFloat) {
        // build CG paths directly to reduce allocations
        guard !nodes.isEmpty else {
            linesLayer.path = nil
            nodesLayer.path = nil
            return
        }

        let linePath = CGMutablePath()
        var isFirst = true
        let nodesPath = CGMutablePath()

        for n in nodes {
            let jitter = sin(time * 6.0 + n.seed * 10.0) * (8.0 * n.life)
            let pos = CGPoint(x: n.pos.x + jitter, y: n.pos.y + jitter * 0.5)
            if isFirst {
                linePath.move(to: pos)
                isFirst = false
            } else {
                linePath.addLine(to: pos)
            }

            let r = n.radius * (1.0 + (1.0 - n.life) * 0.8)
            let rect = CGRect(x: pos.x - r/2, y: pos.y - r/2, width: r, height: r)
            nodesPath.addEllipse(in: rect)
        }

        linesLayer.strokeColor = UIColor.white.withAlphaComponent(0.25).cgColor
        linesLayer.lineWidth = 1.0
        linesLayer.path = linePath

        nodesLayer.fillColor = UIColor.white.cgColor
        nodesLayer.opacity = 1.0
        nodesLayer.path = nodesPath
    }
}
#endif