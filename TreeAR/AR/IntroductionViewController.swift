//
//  IntroductionViewController.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import UIKit
import AVFoundation

class IntroductionViewController: UIViewController, AVAudioPlayerDelegate {
    
    private let gradientLayer = CAGradientLayer()
    
    private let sproutContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.alpha = 0
        return view
    }()
    
    private let sproutView = AnimatedSproutView()

    private let difficultySegmentedControl: UISegmentedControl = {
        let items = ["DEMO", "4REAL"]
        let control = UISegmentedControl(items: items)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = Constants.isDemoMode ? 0 : 1
        control.selectedSegmentTintColor = DesignSystem.Colors.primary
        control.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: DesignSystem.Typography.subheadline], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: DesignSystem.Colors.textSecondary, .font: DesignSystem.Typography.subheadline], for: .normal)
        control.alpha = 0
        control.addTarget(self, action: #selector(difficultyChanged), for: .valueChanged)
        return control
    }()

    private lazy var beginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Enter the Jungle", for: .normal)
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
    
    var viewModel: IntroductionViewModel?
    
    private lazy var introductionPlayer: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "Intro", withExtension: "mp3"),
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
        introductionPlayer?.delegate = self
        introductionPlayer?.play()

        if introductionPlayer == nil {
            showBeginButton(afterDelay: 3.0)
        }
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
            difficultySegmentedControl,
            beginButton
        ])
        
        let safe = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            sproutContainerView.topAnchor.constraint(equalTo: safe.topAnchor, constant: DesignSystem.Spacing.xxl),
            sproutContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spacing.lg),
            sproutContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignSystem.Spacing.lg),
            sproutContainerView.bottomAnchor.constraint(equalTo: difficultySegmentedControl.topAnchor, constant: -DesignSystem.Spacing.xxl),
            
            sproutView.topAnchor.constraint(equalTo: sproutContainerView.topAnchor),
            sproutView.leadingAnchor.constraint(equalTo: sproutContainerView.leadingAnchor),
            sproutView.trailingAnchor.constraint(equalTo: sproutContainerView.trailingAnchor),
            sproutView.bottomAnchor.constraint(equalTo: sproutContainerView.bottomAnchor),
            
            difficultySegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spacing.lg),
            difficultySegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignSystem.Spacing.lg),
            difficultySegmentedControl.bottomAnchor.constraint(equalTo: beginButton.topAnchor, constant: -DesignSystem.Spacing.md),
            difficultySegmentedControl.heightAnchor.constraint(equalToConstant: 36),
            
            beginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spacing.lg),
            beginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignSystem.Spacing.lg),
            beginButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -DesignSystem.Spacing.xl),
            beginButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
        ])
        
        animateEntrance()
    }
    
    private func animateEntrance() {
        let audioDuration = introductionPlayer?.duration ?? 3.0
        sproutView.animationDuration = max(audioDuration - 0.6, 1.75)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.sproutView.playAnimation()
        }
        UIView.animate(withDuration: 1.2, delay: 0.6, options: .curveEaseOut) {
            self.sproutContainerView.alpha = 1
        }
    }

    private func showBeginButton(afterDelay delay: TimeInterval = 0) {
        UIView.animate(withDuration: 1.0, delay: delay, options: .curveEaseOut) {
            self.difficultySegmentedControl.alpha = 1
            self.beginButton.alpha = 1
        }
    }

    @objc private func difficultyChanged() {
        Constants.isDemoMode = (difficultySegmentedControl.selectedSegmentIndex == 0)
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        showBeginButton()
    }
    
    @objc private func didTapBegin() {
        viewModel?.beginTapped()
    }
}
