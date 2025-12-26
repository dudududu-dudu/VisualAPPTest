import UIKit

class TouchAnimator {
    
    static func animateTouchEffect(on view: UIView, at point: CGPoint) {
        let effectView = UIView(frame: CGRect(x: point.x - 50, y: point.y - 50, width: 100, height: 100))
        effectView.backgroundColor = UIColor.clear
        effectView.layer.borderColor = UIColor.white.cgColor
        effectView.layer.borderWidth = 2
        effectView.layer.cornerRadius = 50
        effectView.alpha = 0.8

        view.addSubview(effectView)

        UIView.animate(withDuration: 0.6, animations: {
            effectView.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
            effectView.alpha = 0
        }) { _ in
            effectView.removeFromSuperview()
        }
    }

    // Convenience: animate an existing effect view (used by TouchEffectView)
    static func animateEffect(view effectView: UIView) {
        effectView.alpha = 0.8
        effectView.transform = .identity
        UIView.animate(withDuration: 0.6, animations: {
            effectView.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
            effectView.alpha = 0
        }) { _ in
            effectView.removeFromSuperview()
        }
    }
}