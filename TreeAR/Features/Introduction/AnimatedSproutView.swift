//
//  AnimatedSproutView.swift
//  TreeAR
//
//  Displays AnimatedSprout.svg in a WKWebView to preserve CSS animations.
//

import UIKit
import WebKit

final class AnimatedSproutView: UIView {
    
    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.scrollView.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
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
        loadSVG()
    }
    
    private func loadSVG() {
        guard let url = Bundle.main.url(forResource: "AnimatedSprout", withExtension: "svg")
            ?? Bundle.main.url(forResource: "AnimatedSprout", withExtension: "svg", subdirectory: "Resources"),
              let svgString = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        
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
        </style>
        </head>
        <body>
        <div class="svg-wrap">\(svgString)</div>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }
}

