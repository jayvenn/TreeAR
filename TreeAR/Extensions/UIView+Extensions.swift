//
//  UIView+Extensions.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import UIKit

extension UIView {

    func addSubviews(views: [UIView]) {
        views.forEach { addSubview($0) }
    }

    func fadeIn(duration: TimeInterval = 1.0) {
        alpha = 0
        UIView.animate(withDuration: duration) { self.alpha = 1 }
    }

    func fadeOut(duration: TimeInterval = 1.0) {
        UIView.animate(withDuration: duration) { self.alpha = 0 }
    }

    func fadeAndAway() {
        alpha = 0
        UIView.animate(withDuration: 1) {
            self.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2, options: .curveEaseOut) {
                self.alpha = 0
            }
        }
    }

    func fadeOutAndRemove(view: UIView) {
        UIView.animate(withDuration: 1, animations: {
            view.alpha = 0
        }) { _ in
            view.removeFromSuperview()
        }
    }

    /// Pins `targetView` to all four edges of the receiver using Auto Layout.
    func fillSuperview(withTargetView targetView: UIView) {
        targetView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            targetView.leadingAnchor.constraint(equalTo: leadingAnchor),
            targetView.trailingAnchor.constraint(equalTo: trailingAnchor),
            targetView.topAnchor.constraint(equalTo: topAnchor),
            targetView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
