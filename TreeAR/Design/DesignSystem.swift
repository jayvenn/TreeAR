//
//  DesignSystem.swift
//  TreeAR
//
//  Mobile-first design tokens for consistent, polished UI.
//

import UIKit

enum DesignSystem {
    
    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 999
    }
    
    // MARK: - Typography
    enum Typography {
        static let largeTitle = UIFont.systemFont(ofSize: 34, weight: .bold)
        static let title1 = UIFont.systemFont(ofSize: 28, weight: .bold)
        static let title2 = UIFont.systemFont(ofSize: 22, weight: .semibold)
        static let title3 = UIFont.systemFont(ofSize: 20, weight: .semibold)
        static let headline = UIFont.systemFont(ofSize: 17, weight: .semibold)
        static let body = UIFont.systemFont(ofSize: 17, weight: .regular)
        static let callout = UIFont.systemFont(ofSize: 16, weight: .regular)
        static let subheadline = UIFont.systemFont(ofSize: 15, weight: .regular)
        static let footnote = UIFont.systemFont(ofSize: 13, weight: .regular)
        static let caption1 = UIFont.systemFont(ofSize: 12, weight: .regular)
    }
    
    // MARK: - Colors (Nature-inspired palette)
    enum Colors {
        // Primary - Forest & Growth
        static let primary = UIColor(red: 0.18, green: 0.55, blue: 0.34, alpha: 1)      // #2E8B57
        static let primaryLight = UIColor(red: 0.35, green: 0.68, blue: 0.48, alpha: 1)
        static let primaryDark = UIColor(red: 0.12, green: 0.40, blue: 0.26, alpha: 1)
        
        // Accent - Earth & Warmth
        static let accent = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1)       // Amber
        static let accentLight = UIColor(red: 0.95, green: 0.82, blue: 0.36, alpha: 1)
        
        // Neutrals
        static let background = UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1)
        static let surface = UIColor.white
        static let textPrimary = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1)
        static let textSecondary = UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1)
        static let textTertiary = UIColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1)
        
        // Overlays (AR)
        static let overlayLight = UIColor.white.withAlphaComponent(0.92)
        static let overlayDark = UIColor.black.withAlphaComponent(0.75)
        static let overlayBlur = UIColor.white.withAlphaComponent(0.85)
        
        // Gradients (for CAGradientLayer)
        static let gradientTop = UIColor(red: 0.95, green: 0.98, blue: 0.95, alpha: 1).cgColor
        static let gradientBottom = UIColor(red: 0.88, green: 0.95, blue: 0.90, alpha: 1).cgColor
    }
    
    // MARK: - Shadows
    enum Shadow {
        static func apply(to view: UIView, radius: CGFloat = 8, opacity: Float = 0.12) {
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOffset = CGSize(width: 0, height: 2)
            view.layer.shadowRadius = radius
            view.layer.shadowOpacity = opacity
        }
        
        static func applySubtle(to view: UIView) {
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOffset = CGSize(width: 0, height: 1)
            view.layer.shadowRadius = 4
            view.layer.shadowOpacity = 0.08
        }
    }
}
