//
//  UIView+Extensions.swift
//  TreeAR
//

import UIKit

extension UIView {
    func addSubviews(views: [UIView]) {
        views.forEach { addSubview($0) }
    }
}

extension UILabel {
    func fadeIn(duration: TimeInterval = 1.0) {
        UIView.animate(withDuration: duration) {
            self.alpha = 1
        }
    }
}
