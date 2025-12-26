import UIKit

class ViewController: UIViewController {

    private var touchEffectView: TouchEffectView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTouchEffectView()
        setupGestureRecognizers()
    }

    private func setupTouchEffectView() {
        touchEffectView = TouchEffectView(frame: view.bounds)
        touchEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(touchEffectView)
    }

    private func setupGestureRecognizers() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: touchEffectView)
        touchEffectView.showEffect(at: location)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: touchEffectView)
        touchEffectView.showEffect(at: location)
    }
}