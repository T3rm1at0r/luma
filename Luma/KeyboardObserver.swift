#if canImport(UIKit)
import SwiftUI
import UIKit

@MainActor
@Observable
final class KeyboardObserver {
    private(set) var height: CGFloat = 0

    init() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let endFrame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
            Task { @MainActor in self?.apply(endFrame: endFrame) }
        }
        center.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.height = 0 }
        }
    }

    private func apply(endFrame: CGRect) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: \.isKeyWindow)
        else { return }
        let screenHeight = window.bounds.height
        let safeAreaBottom = window.safeAreaInsets.bottom
        height = max(0, screenHeight - endFrame.origin.y - safeAreaBottom)
    }
}
#endif
