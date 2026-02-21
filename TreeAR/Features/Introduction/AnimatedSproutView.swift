//
//  AnimatedSproutView.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//
//  Uses pause-then-play: SVG loads with animations paused, then we unpause
//  when visible so the animation runs in sync with the fade-in.
//

import UIKit
import WebKit

final class AnimatedSproutView: UIView {

    /// Total duration for the full grow animation (stem + all leaves).
    /// The default (1.75s) matches the original SVG keyframe timings.
    /// Set before calling `playAnimation()` to scale proportionally.
    var animationDuration: TimeInterval = 1.75

    private static let originalDuration: TimeInterval = 1.75

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.scrollView.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.navigationDelegate = self
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    /// Loads the SVG and starts the animation when the sprout becomes visible.
    /// Unpause happens in didFinish once the page is ready.
    func playAnimation() {
        loadSVG()
    }
    
    private func loadSVG() {
        guard let url = Bundle.main.url(forResource: "AnimatedSprout", withExtension: "svg")
            ?? Bundle.main.url(forResource: "AnimatedSprout", withExtension: "svg", subdirectory: "Resources"),
              let svgString = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        
        // Pause via class – playAnimation() removes it to unpause (can't override !important with JS)
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body { width: 100%; height: 100%; background: transparent; overflow: hidden; }
        body { display: flex; justify-content: center; align-items: center; }
        .svg-wrap { width: 100%; height: 100%; display: flex; justify-content: center; align-items: center; }
        .svg-wrap svg { width: 100%; height: 100%; object-fit: contain; }
        body.paused .svg-wrap svg .stem,
        body.paused .svg-wrap svg .leaf-anim,
        body.paused .svg-wrap svg .leaf-2,
        body.paused .svg-wrap svg .leaf-3,
        body.paused .svg-wrap svg .leaf-4,
        body.paused .svg-wrap svg .leaf-1-container { animation-play-state: paused; }
        </style>
        </head>
        <body class="paused">
        <div class="svg-wrap">\(svgString)</div>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
    }
}

extension AnimatedSproutView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let scale = animationDuration / Self.originalDuration
        let js = """
        (function() {
            var s = \(scale);
            var stem = document.querySelector('.stem');
            if (stem) { stem.style.animationDuration = (1.5 * s) + 's'; }
            var l1 = document.querySelector('.leaf-1-container');
            if (l1) { l1.style.animationDuration = (0.8 * s) + 's'; }
            var l2 = document.querySelector('.leaf-2');
            if (l2) { l2.style.animationDuration = (0.6 * s) + 's'; l2.style.animationDelay = (0.35 * s) + 's'; }
            var l3 = document.querySelector('.leaf-3');
            if (l3) { l3.style.animationDuration = (0.6 * s) + 's'; l3.style.animationDelay = (0.7 * s) + 's'; }
            var l4 = document.querySelector('.leaf-4');
            if (l4) { l4.style.animationDuration = (0.6 * s) + 's'; l4.style.animationDelay = (1.15 * s) + 's'; }
            document.body.classList.remove('paused');
        })();
        """
        webView.evaluateJavaScript(js)
    }
}

