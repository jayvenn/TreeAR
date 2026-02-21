//
//  UIColor+Extensions.swift
//  TreeAR
//

import UIKit

extension UIColor {
    
    static func rgb(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) -> UIColor {
        UIColor(red: red/255, green: green/255, blue: blue/255, alpha: alpha)
    }
    
    // Legacy aliases for compatibility
    static var transparentWhite: UIColor { DesignSystem.Colors.overlayLight }
    static var transparentTextBackgroundWhite: UIColor { DesignSystem.Colors.overlayBlur }
    static var transparentTextBackgroundBlack: UIColor { DesignSystem.Colors.overlayDark }
    static var plantButtonBackground: UIColor { DesignSystem.Colors.primary }
}
