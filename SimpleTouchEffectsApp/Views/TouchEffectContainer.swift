import SwiftUI
import UIKit

struct TouchEffectContainer: UIViewRepresentable {

    func makeUIView(context: Context) -> TouchEffectView {
        let view = TouchEffectView(frame: .zero)
        view.backgroundColor = .black   // 可选
        return view
    }

    func updateUIView(_ uiView: TouchEffectView, context: Context) {
        // 暂时不用更新
    }
}

