//
//  PaddedLabel.swift
//  TreeAR
//
//  UILabel with configurable content insets for polished cards.
//

import UIKit

final class PaddedLabel: UILabel {
    
    var contentInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16) {
        didSet { setNeedsLayout() }
    }
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}
