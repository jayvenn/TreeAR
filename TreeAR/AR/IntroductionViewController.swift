//
//  IntroductionViewController.swift
//  TreeAR
//
//  AR adventure - Plant a seed and watch it grow!
//

import UIKit
import AVFoundation

class IntroductionViewController: UIViewController {
    
    private let gradientLayer = CAGradientLayer()
    
    private let sproutContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.alpha = 0
        return view
    }()
    
    private let sproutView = AnimatedSproutView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Hello there"
        label.textAlignment = .center
        label.font = DesignSystem.Typography.largeTitle
        label.textColor = DesignSystem.Colors.textPrimary
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Are you ready to plant a seed?"
        label.textAlignment = .center
        label.font = DesignSystem.Typography.body
        label.textColor = DesignSystem.Colors.textSecondary
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.numberOfLines = 2
        return label
    }()
    
    private lazy var beginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Begin AR Adventure", for: .normal)
        button.titleLabel?.font = DesignSystem.Typography.headline
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = DesignSystem.Colors.primary
        button.layer.cornerRadius = DesignSystem.Radius.lg
        button.translatesAutoresizingMaskIntoConstraints = false
        button.alpha = 0
        button.addTarget(self, action: #selector(didTapBegin), for: .touchUpInside)
        button.contentEdgeInsets = UIEdgeInsets(top: DesignSystem.Spacing.md, left: DesignSystem.Spacing.xl, bottom: DesignSystem.Spacing.md, right: DesignSystem.Spacing.xl)
        DesignSystem.Shadow.applySubtle(to: button)
        return button
    }()
    
    private let hintLabel: UILabel = {
        let label = UILabel()
        label.text = "Tap anywhere to begin"
        label.textAlignment = .center
        label.font = DesignSystem.Typography.footnote
        label.textColor = DesignSystem.Colors.textTertiary
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    var viewModel: IntroductionViewModel?
    
    private lazy var introductionPlayer: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "introduction", withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.volume = 1
        player.prepareToPlay()
        return player
    }()
    
    override func loadView() {
        super.loadView()
        view.backgroundColor = DesignSystem.Colors.background
        view.insetsLayoutMarginsFromSafeArea = false
        setupGradient()
        setupLayouts()
        introductionPlayer?.play()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }
    
    private func setupGradient() {
        gradientLayer.colors = [DesignSystem.Colors.gradientTop, DesignSystem.Colors.gradientBottom]
        gradientLayer.locations = [0, 1]
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func setupLayouts() {
        sproutView.translatesAutoresizingMaskIntoConstraints = false
        sproutContainerView.addSubview(sproutView)
        
        view.addSubviews(views: [
            sproutContainerView,
            titleLabel,
            subTitleLabel,
            beginButton,
            hintLabel
        ])
        
        let safe = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            sproutContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sproutContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            sproutContainerView.widthAnchor.constraint(equalToConstant: 140),
            sproutContainerView.heightAnchor.constraint(equalToConstant: 200),
            
            sproutView.topAnchor.constraint(equalTo: sproutContainerView.topAnchor),
            sproutView.leadingAnchor.constraint(equalTo: sproutContainerView.leadingAnchor),
            sproutView.trailingAnchor.constraint(equalTo: sproutContainerView.trailingAnchor),
            sproutView.bottomAnchor.constraint(equalTo: sproutContainerView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: sproutContainerView.bottomAnchor, constant: DesignSystem.Spacing.xl),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignSystem.Spacing.lg),
            
            subTitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignSystem.Spacing.sm),
            subTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spacing.xl),
            subTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignSystem.Spacing.xl),
            
            beginButton.topAnchor.constraint(equalTo: subTitleLabel.bottomAnchor, constant: DesignSystem.Spacing.xxl),
            beginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spacing.lg),
            beginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignSystem.Spacing.lg),
            beginButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            
            hintLabel.topAnchor.constraint(equalTo: beginButton.bottomAnchor, constant: DesignSystem.Spacing.md),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -DesignSystem.Spacing.lg)
        ])
        
        animateEntrance()
    }
    
    private func animateEntrance() {
        sproutContainerView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        
        // 1. Sprout container scales in; SVG loads and runs its built-in animation (~2.35s)
        UIView.animate(withDuration: 0.7, delay: 0.2, usingSpringWithDamping: 0.78, initialSpringVelocity: 0) {
            self.sproutContainerView.transform = .identity
            self.sproutContainerView.alpha = 1
        }
        
        // 2. Title fades in as stem grows
        UIView.animate(withDuration: 0.5, delay: 1.2, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
        }
        
        // 3. Subtitle fades in as leaves pop
        UIView.animate(withDuration: 0.5, delay: 1.8, options: .curveEaseOut) {
            self.subTitleLabel.alpha = 1
        }
        
        // 4. CTA and hint after sprout animation completes
        UIView.animate(withDuration: 0.5, delay: 2.6, options: .curveEaseOut) {
            self.beginButton.alpha = 1
            self.hintLabel.alpha = 1
        } completion: { _ in
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.didTapView(_:)))
            self.view.addGestureRecognizer(tapGesture)
        }
    }
    
    @objc private func didTapView(_ recognizer: UITapGestureRecognizer) {
        viewModel?.beginTapped()
    }
    
    @objc private func didTapBegin() {
        viewModel?.beginTapped()
    }
}
