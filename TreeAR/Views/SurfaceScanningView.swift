//
//  SurfaceScanningView.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import UIKit

final class SurfaceScanningView: UIView {

    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.opacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let surfaceView    = SurfaceView()
    private let iPadDeviceView = IPadDeviceView()

    override func layoutSubviews() {
        super.layoutSubviews()
        animateDeviceMoveLeftAndRight()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupView()
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    private func setupView() {
        addSubview(backgroundView)
        addSubview(surfaceView)
        addSubview(iPadDeviceView)
        fillSuperview(withTargetView: backgroundView)
        fillSuperview(withTargetView: surfaceView)
        fillSuperview(withTargetView: iPadDeviceView)
    }

    func animateDeviceMoveLeftAndRight() {
        iPadDeviceView.isHidden = false
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let difference: CGFloat = 88
            self.iPadDeviceView.center.x += difference / 2
            UIView.animate(withDuration: 1,
                           delay: 0,
                           options: [.curveEaseInOut, .autoreverse, .repeat]) { [weak self] in
                self?.iPadDeviceView.center.x -= difference
            }
        }
    }
}

private class SurfaceView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        SurfaceScanningStyleKit.drawSurfaceScanning(frame: bounds,
                                                    resizing: .aspectFit)
    }
}

private class IPadDeviceView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
        isHidden = true
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        SurfaceScanningStyleKit.drawIPad(frame: bounds, resizing: .aspectFit)
    }
}
