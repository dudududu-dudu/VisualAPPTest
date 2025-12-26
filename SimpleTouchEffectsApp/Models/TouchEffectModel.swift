import UIKit

class TouchEffectModel {
    var touchLocation: CGPoint
    var effectIntensity: CGFloat
    var effectColor: UIColor

    init(touchLocation: CGPoint, effectIntensity: CGFloat, effectColor: UIColor) {
        self.touchLocation = touchLocation
        self.effectIntensity = effectIntensity
        self.effectColor = effectColor
    }
}