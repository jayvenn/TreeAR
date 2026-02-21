//
//  CombatHUDView.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import UIKit

/// Screen-space combat overlay: boss HP bar, player HP hearts, range indicator.
///
/// All elements are anchored to screen edges — never world-anchored — to prevent
/// motion sickness and tracking jitter. The HUD fades in/out as a unit via `alpha`.
final class CombatHUDView: UIView {

    // MARK: - Subviews

    private let bossHPContainer = UIView()
    private let bossHPBar = UIView()
    private let bossHPFill = UIView()
    private let bossNameLabel = UILabel()

    private let playerHPStack = UIStackView()
    private var heartViews: [UIImageView] = []

    private let rangeIndicator = UIView()
    private let rangeIcon = UILabel()
    private let rangeLabel = UILabel()

    private let phaseLabel = UILabel()

    private let retryButton = UIButton(type: .system)
    var onRetryTapped: (() -> Void)?

    // MARK: - Constants

    private let heartCount = 5
    private let hpPerHeart = 20

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        setupBossHP()
        setupPlayerHP()
        setupRangeIndicator()
        setupPhaseLabel()
        setupRetryButton()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    // MARK: - Public API

    func updateBossHP(fraction: Float, animated: Bool = true) {
        let clamped = max(0, min(1, CGFloat(fraction)))
        let newWidth = bossHPBar.bounds.width * clamped

        if animated {
            UIView.animate(withDuration: 0.3) {
                self.bossHPFill.frame.size.width = newWidth
            }
        } else {
            bossHPFill.frame.size.width = newWidth
        }

        let color: UIColor
        if fraction > 0.6 {
            color = DesignSystem.Colors.primary
        } else if fraction > 0.3 {
            color = .systemYellow
        } else {
            color = .systemRed
        }
        bossHPFill.backgroundColor = color
    }

    func updatePlayerHP(current: Int, max: Int) {
        for (i, heart) in heartViews.enumerated() {
            let threshold = (i + 1) * hpPerHeart
            if current >= threshold {
                heart.tintColor = .systemRed
                heart.image = UIImage(systemName: "heart.fill")
            } else if current >= threshold - hpPerHeart {
                heart.tintColor = .systemRed
                heart.image = UIImage(systemName: "heart.lefthalf.fill")
            } else {
                heart.tintColor = .systemGray3
                heart.image = UIImage(systemName: "heart")
            }
        }
    }

    func updateRangeIndicator(inRange: Bool) {
        let color: UIColor = inRange ? DesignSystem.Colors.primary : .systemGray
        rangeIndicator.backgroundColor = color.withAlphaComponent(0.75)
        rangeIcon.text = inRange ? "◉" : "○"
        rangeLabel.text = inRange ? "IN RANGE" : "TOO FAR"
    }

    func showPhaseTransition(_ phase: BossPhase) {
        let text: String
        switch phase {
        case .phase1: return
        case .phase2: text = "THE HOLLOW GROWS ANGRY"
        case .phase3: text = "THE HOLLOW IS ENRAGED"
        }
        phaseLabel.text = text
        phaseLabel.alpha = 0
        phaseLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        UIView.animate(withDuration: 0.5) {
            self.phaseLabel.alpha = 1
            self.phaseLabel.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.5, delay: 1.5) {
                self.phaseLabel.alpha = 0
            }
        }
    }

    func showRetryPrompt() {
        retryButton.alpha = 0
        retryButton.isHidden = false
        UIView.animate(withDuration: 0.5, delay: 1.0) {
            self.retryButton.alpha = 1
        }
    }

    func hideRetryPrompt() {
        retryButton.isHidden = true
        retryButton.alpha = 0
    }

    func flashDamage() {
        let overlay = UIView(frame: bounds)
        overlay.backgroundColor = UIColor.systemRed.withAlphaComponent(0.3)
        overlay.isUserInteractionEnabled = false
        addSubview(overlay)
        UIView.animate(withDuration: 0.3, animations: {
            overlay.alpha = 0
        }) { _ in
            overlay.removeFromSuperview()
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        bossHPFill.frame = CGRect(x: 0, y: 0,
                                   width: bossHPBar.bounds.width,
                                   height: bossHPBar.bounds.height)
    }

    // MARK: - Setup

    private func setupBossHP() {
        bossHPContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bossHPContainer)

        bossHPBar.translatesAutoresizingMaskIntoConstraints = false
        bossHPBar.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        bossHPBar.layer.cornerRadius = 4
        bossHPBar.clipsToBounds = true
        bossHPContainer.addSubview(bossHPBar)

        bossHPFill.backgroundColor = DesignSystem.Colors.primary
        bossHPFill.layer.cornerRadius = 4
        bossHPBar.addSubview(bossHPFill)

        bossNameLabel.translatesAutoresizingMaskIntoConstraints = false
        bossNameLabel.text = "THE HOLLOW"
        bossNameLabel.font = DesignSystem.Typography.caption1
        bossNameLabel.textColor = .white
        bossNameLabel.textAlignment = .center
        bossHPContainer.addSubview(bossNameLabel)

        NSLayoutConstraint.activate([
            bossHPContainer.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: DesignSystem.Spacing.sm),
            bossHPContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignSystem.Spacing.xl),
            bossHPContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignSystem.Spacing.xl),

            bossHPBar.topAnchor.constraint(equalTo: bossHPContainer.topAnchor),
            bossHPBar.leadingAnchor.constraint(equalTo: bossHPContainer.leadingAnchor),
            bossHPBar.trailingAnchor.constraint(equalTo: bossHPContainer.trailingAnchor),
            bossHPBar.heightAnchor.constraint(equalToConstant: 8),

            bossNameLabel.topAnchor.constraint(equalTo: bossHPBar.bottomAnchor, constant: 2),
            bossNameLabel.centerXAnchor.constraint(equalTo: bossHPContainer.centerXAnchor),
            bossNameLabel.bottomAnchor.constraint(equalTo: bossHPContainer.bottomAnchor)
        ])
    }

    private func setupPlayerHP() {
        playerHPStack.translatesAutoresizingMaskIntoConstraints = false
        playerHPStack.axis = .horizontal
        playerHPStack.spacing = 4
        playerHPStack.alignment = .center
        addSubview(playerHPStack)

        for _ in 0..<heartCount {
            let heart = UIImageView(image: UIImage(systemName: "heart.fill"))
            heart.tintColor = .systemRed
            heart.contentMode = .scaleAspectFit
            heart.translatesAutoresizingMaskIntoConstraints = false
            heart.widthAnchor.constraint(equalToConstant: 22).isActive = true
            heart.heightAnchor.constraint(equalToConstant: 22).isActive = true
            heartViews.append(heart)
            playerHPStack.addArrangedSubview(heart)
        }

        NSLayoutConstraint.activate([
            playerHPStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignSystem.Spacing.md),
            playerHPStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -DesignSystem.Spacing.md)
        ])
    }

    private func setupRangeIndicator() {
        rangeIndicator.translatesAutoresizingMaskIntoConstraints = false
        rangeIndicator.backgroundColor = UIColor.systemGray.withAlphaComponent(0.75)
        rangeIndicator.layer.cornerRadius = DesignSystem.Radius.sm
        addSubview(rangeIndicator)

        rangeIcon.translatesAutoresizingMaskIntoConstraints = false
        rangeIcon.text = "○"
        rangeIcon.font = .systemFont(ofSize: 20)
        rangeIcon.textColor = .white
        rangeIndicator.addSubview(rangeIcon)

        rangeLabel.translatesAutoresizingMaskIntoConstraints = false
        rangeLabel.text = "TOO FAR"
        rangeLabel.font = DesignSystem.Typography.caption1
        rangeLabel.textColor = .white
        rangeIndicator.addSubview(rangeLabel)

        NSLayoutConstraint.activate([
            rangeIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignSystem.Spacing.md),
            rangeIndicator.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -DesignSystem.Spacing.md),
            rangeIndicator.heightAnchor.constraint(equalToConstant: 36),

            rangeIcon.leadingAnchor.constraint(equalTo: rangeIndicator.leadingAnchor, constant: 8),
            rangeIcon.centerYAnchor.constraint(equalTo: rangeIndicator.centerYAnchor),

            rangeLabel.leadingAnchor.constraint(equalTo: rangeIcon.trailingAnchor, constant: 4),
            rangeLabel.trailingAnchor.constraint(equalTo: rangeIndicator.trailingAnchor, constant: -8),
            rangeLabel.centerYAnchor.constraint(equalTo: rangeIndicator.centerYAnchor)
        ])
    }

    private func setupPhaseLabel() {
        phaseLabel.translatesAutoresizingMaskIntoConstraints = false
        phaseLabel.font = DesignSystem.Typography.title2
        phaseLabel.textColor = .white
        phaseLabel.textAlignment = .center
        phaseLabel.alpha = 0
        phaseLabel.layer.shadowColor = UIColor.black.cgColor
        phaseLabel.layer.shadowOffset = .zero
        phaseLabel.layer.shadowRadius = 6
        phaseLabel.layer.shadowOpacity = 0.8
        addSubview(phaseLabel)

        NSLayoutConstraint.activate([
            phaseLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            phaseLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func setupRetryButton() {
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("  TRY AGAIN  ", for: .normal)
        retryButton.titleLabel?.font = DesignSystem.Typography.headline
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.backgroundColor = DesignSystem.Colors.primary
        retryButton.layer.cornerRadius = DesignSystem.Radius.md
        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        addSubview(retryButton)

        NSLayoutConstraint.activate([
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryButton.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 60),
            retryButton.heightAnchor.constraint(equalToConstant: 48),
            retryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 160)
        ])
    }

    @objc private func retryTapped() {
        onRetryTapped?()
    }
}
