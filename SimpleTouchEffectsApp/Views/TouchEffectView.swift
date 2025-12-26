#if canImport(UIKit)
import UIKit

class TouchEffectView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
            showTouchEffect(at: location)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
            showTouchEffect(at: location)
        }
    }
    
    private func showTouchEffect(at point: CGPoint) {
        let effectView = UIView(frame: CGRect(x: point.x - 25, y: point.y - 25, width: 50, height: 50))
        effectView.backgroundColor = UIColor(white: 1, alpha: 0.5)
        effectView.layer.cornerRadius = 25
        self.addSubview(effectView)
        
        TouchAnimator.animateEffect(view: effectView)
    }

    // Public API used by ViewController
    func showEffect(at point: CGPoint) {
        showTouchEffect(at: point)
    }
}
#endif