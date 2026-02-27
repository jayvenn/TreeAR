//
//  SurfaceScanningStyleKit.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import UIKit

public class SurfaceScanningStyleKit: NSObject {

    @objc dynamic public class func drawSurfaceScanning(
        frame targetFrame: CGRect = CGRect(x: 0, y: 0, width: 120, height: 120),
        resizing: ResizingBehavior = .aspectFit
    ) {
        let context = UIGraphicsGetCurrentContext()!
        context.saveGState()
        let resized = resizing.apply(rect: CGRect(x: 0, y: 0, width: 120, height: 120),
                                     target: targetFrame)
        context.translateBy(x: resized.minX, y: resized.minY)
        context.scaleBy(x: resized.width / 120, y: resized.height / 120)

        let outline = UIBezierPath()
        outline.move(to: CGPoint(x: 39.13, y: 53.5))
        outline.addLine(to: CGPoint(x: 20.22, y: 78.73))
        outline.addLine(to: CGPoint(x: 98.22, y: 78.57))
        outline.addLine(to: CGPoint(x: 79.31, y: 53.5))
        UIColor.black.setStroke()
        outline.lineWidth = 1
        outline.lineCapStyle = .round
        outline.lineJoinStyle = .bevel
        outline.stroke()

        let front = UIBezierPath(roundedRect: CGRect(x: 19.7, y: 77.5, width: 79.1, height: 3),
                                 cornerRadius: 1)
        UIColor(red: 0, green: 0, blue: 0, alpha: 1).setFill()
        front.fill()

        let back = UIBezierPath()
        back.move(to: CGPoint(x: 39.1, y: 53.35))
        back.addLine(to: CGPoint(x: 79.35, y: 53.35))
        UIColor.black.setStroke()
        back.lineWidth = 0.75
        back.lineCapStyle = .round
        back.stroke()

        context.restoreGState()
    }

    @objc dynamic public class func drawIPad(
        frame targetFrame: CGRect = CGRect(x: 0, y: 0, width: 120, height: 120),
        resizing: ResizingBehavior = .aspectFit,
        iPadXPosition: CGFloat = 45
    ) {
        let context = UIGraphicsGetCurrentContext()!
        context.saveGState()
        let resized = resizing.apply(rect: CGRect(x: 0, y: 0, width: 120, height: 120),
                                     target: targetFrame)
        context.translateBy(x: resized.minX, y: resized.minY)
        context.scaleBy(x: resized.width / 120, y: resized.height / 120)

        context.saveGState()
        context.translateBy(x: iPadXPosition, y: 65)

        let screen = UIBezierPath(rect: CGRect(x: 1, y: 1, width: 29, height: 20))
        UIColor.white.setFill()
        screen.fill()

        let bezel = UIBezierPath()
        bezel.move(to: CGPoint(x: 28.72, y: 1.26))
        bezel.addLine(to: CGPoint(x: 2.28, y: 1.26))
        bezel.addCurve(to: CGPoint(x: 1.7, y: 1.3),
                       controlPoint1: CGPoint(x: 1.99, y: 1.26), controlPoint2: CGPoint(x: 1.85, y: 1.26))
        bezel.addCurve(to: CGPoint(x: 1.34, y: 1.65),
                       controlPoint1: CGPoint(x: 1.53, y: 1.36), controlPoint2: CGPoint(x: 1.4, y: 1.49))
        bezel.addCurve(to: CGPoint(x: 1.29, y: 2.22),
                       controlPoint1: CGPoint(x: 1.29, y: 1.8),  controlPoint2: CGPoint(x: 1.29, y: 1.94))
        bezel.addLine(to: CGPoint(x: 1.29, y: 19.78))
        bezel.addCurve(to: CGPoint(x: 1.34, y: 20.35),
                       controlPoint1: CGPoint(x: 1.29, y: 20.06), controlPoint2: CGPoint(x: 1.29, y: 20.2))
        bezel.addCurve(to: CGPoint(x: 1.7, y: 20.7),
                       controlPoint1: CGPoint(x: 1.4, y: 20.51),  controlPoint2: CGPoint(x: 1.53, y: 20.64))
        bezel.addCurve(to: CGPoint(x: 2.28, y: 20.74),
                       controlPoint1: CGPoint(x: 1.85, y: 20.74), controlPoint2: CGPoint(x: 1.99, y: 20.74))
        bezel.addLine(to: CGPoint(x: 28.72, y: 20.74))
        bezel.addCurve(to: CGPoint(x: 29.3, y: 20.7),
                       controlPoint1: CGPoint(x: 29.01, y: 20.74), controlPoint2: CGPoint(x: 29.15, y: 20.74))
        bezel.addCurve(to: CGPoint(x: 29.66, y: 20.35),
                       controlPoint1: CGPoint(x: 29.47, y: 20.64), controlPoint2: CGPoint(x: 29.6, y: 20.51))
        bezel.addCurve(to: CGPoint(x: 29.71, y: 19.78),
                       controlPoint1: CGPoint(x: 29.71, y: 20.2),  controlPoint2: CGPoint(x: 29.71, y: 20.06))
        bezel.addLine(to: CGPoint(x: 29.71, y: 2.22))
        bezel.addCurve(to: CGPoint(x: 29.66, y: 1.65),
                       controlPoint1: CGPoint(x: 29.71, y: 1.94), controlPoint2: CGPoint(x: 29.71, y: 1.8))
        bezel.addCurve(to: CGPoint(x: 29.3, y: 1.3),
                       controlPoint1: CGPoint(x: 29.6, y: 1.49),  controlPoint2: CGPoint(x: 29.47, y: 1.36))
        bezel.addCurve(to: CGPoint(x: 28.72, y: 1.26),
                       controlPoint1: CGPoint(x: 29.15, y: 1.26), controlPoint2: CGPoint(x: 29.01, y: 1.26))
        bezel.close()
        UIColor.black.setFill()
        bezel.fill()

        context.restoreGState()
        context.restoreGState()
    }

    @objc(SurfaceScanningStyleKitResizingBehavior)
    public enum ResizingBehavior: Int {
        case aspectFit, aspectFill, stretch, center

        public func apply(rect: CGRect, target: CGRect) -> CGRect {
            if rect == target || target == .zero { return rect }
            var scales = CGSize(width: abs(target.width / rect.width),
                                height: abs(target.height / rect.height))
            switch self {
            case .aspectFit:   scales.width = min(scales.width, scales.height); scales.height = scales.width
            case .aspectFill:  scales.width = max(scales.width, scales.height); scales.height = scales.width
            case .stretch:     break
            case .center:      scales = CGSize(width: 1, height: 1)
            }
            var result = rect.standardized
            result.size.width  *= scales.width
            result.size.height *= scales.height
            result.origin.x = target.minX + (target.width  - result.width)  / 2
            result.origin.y = target.minY + (target.height - result.height) / 2
            return result
        }
    }
}
