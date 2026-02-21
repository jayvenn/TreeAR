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
    
    private let iconContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignSystem.Colors.primary.withAlphaComponent(0.12)
        view.layer.cornerRadius = 56
        view.alpha = 0
        return view
    }()
    
    private let iconLabel: UILabel = {
        let label = UILabel()
        label.text = "🌱"
        label.font = UIFont.systemFont(ofSize: 48, weight: .regular)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
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
        view.addSubviews(views: [
            iconContainerView,
            iconLabel,
            titleLabel,
            subTitleLabel,
            beginButton,
            hintLabel
        ])
        
        let safe = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            iconContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -120),
            iconContainerView.widthAnchor.constraint(equalToConstant: 112),
            iconContainerView.heightAnchor.constraint(equalToConstant: 112),
            
            iconLabel.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconContainerView.bottomAnchor, constant: DesignSystem.Spacing.xl),
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
        iconContainerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.6, delay: 0.3, usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
            self.iconContainerView.transform = .identity
            self.iconContainerView.alpha = 1
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.8, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
        }
        
        UIView.animate(withDuration: 0.5, delay: 1.2, options: .curveEaseOut) {
            self.subTitleLabel.alpha = 1
        }
        
        UIView.animate(withDuration: 0.5, delay: 2.2, options: .curveEaseOut) {
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
