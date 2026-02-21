//
//  CombatHUDView.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import UIKit

/// Full-screen combat overlay with dark-glass aesthetic.
///
/// All elements are screen-anchored. Never world-anchored (prevents motion sickness).
/// The HUD provides: boss HP with glow, player hearts, range ring, phase banners,
/// damage vignette, and screen shake.
final class CombatHUDView: UIView {

    // MARK: - Callbacks

    var onRetryTapped: (() -> Void)?

    // MARK: - Boss HP

    private let bossHPTrack = UIView()
    private let bossHPFill = GradientView()
    private let bossHPGlow = UIView()
    private let bossNameLabel = UILabel()
    private let bossSubtitle = UILabel()
    private var hpFillWidthConstraint: NSLayoutConstraint?

    // MARK: - Player HP

    private let playerHPStack = UIStackView()
    private var heartViews: [UIImageView] = []
    private let heartCount = 5
    private let hpPerHeart = 20

    // MARK: - Range

    private let rangeRing = UIView()
    private let rangeLabel = UILabel()

    // MARK: - Effects

    private let vignetteTop = GradientView()
    private let vignetteBottom = GradientView()
    private let vignetteLeft = GradientView()
    private let vignetteRight = GradientView()
    private let damageFlash = UIView()
    private let phaseLabel = UILabel()
    private let phaseBanner = UIView()

    // MARK: - Retry

    private let retryContainer = UIView()
    private let deathLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        setupVignette()
        setupBossHP()
        setupPlayerHP()
        setupRange()
        setupDamageFlash()
        setupPhaseBanner()
        setupRetry()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    func updateBossHP(fraction: Float, animated: Bool = true) {
        let clamped = CGFloat(max(0, min(1, fraction)))
        hpFillWidthConstraint?.isActive = false
        hpFillWidthConstraint = bossHPFill.widthAnchor.constraint(
            equalTo: bossHPTrack.widthAnchor, multiplier: max(clamped, 0.001))
        hpFillWidthConstraint?.isActive = true

        if fraction > 0.6 {
            bossHPFill.setColors([
                UIColor(red: 0.8, green: 0.25, blue: 0.1, alpha: 1),
                UIColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 1)
            ])
        } else if fraction > 0.3 {
            bossHPFill.setColors([
                UIColor(red: 0.9, green: 0.5, blue: 0.0, alpha: 1),
                UIColor(red: 1.0, green: 0.7, blue: 0.1, alpha: 1)
            ])
        } else {
            bossHPFill.setColors([
                UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1),
                UIColor(red: 1.0, green: 0.2, blue: 0.1, alpha: 1)
            ])
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                self.layoutIfNeeded()
            }
        } else {
            layoutIfNeeded()
        }
    }

    func updatePlayerHP(current: Int, max: Int) {
        for (i, heart) in heartViews.enumerated() {
            let threshold = (i + 1) * hpPerHeart
            if current >= threshold {
                heart.image = UIImage(systemName: "heart.fill")
                heart.tintColor = .systemRed
            } else if current > threshold - hpPerHeart {
                heart.image = UIImage(systemName: "heart.leadinghalf.fill")
                heart.tintColor = .systemRed
            } else {
                heart.image = UIImage(systemName: "heart")
                heart.tintColor = UIColor.white.withAlphaComponent(0.3)
            }
        }
    }

    func updateRangeIndicator(inRange: Bool) {
        let color: UIColor = inRange
            ? UIColor(red: 1.0, green: 0.35, blue: 0.05, alpha: 1)
            : UIColor.white.withAlphaComponent(0.25)
        rangeRing.layer.borderColor = color.cgColor
        rangeLabel.text = inRange ? "STRIKE" : ""
        rangeLabel.textColor = color
    }

    func flashDamage() {
        setVignetteIntensity(0.7)
        damageFlash.alpha = 0.2
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.setVignetteIntensity(0.0)
            self.damageFlash.alpha = 0
        }
    }

    func showPhaseTransition(_ phase: BossPhase) {
        let text: String
        switch phase {
        case .phase1: return
        case .phase2: text = "THE HOLLOW AWAKENS"
        case .phase3: text = "EMBRACE OBLIVION"
        }
        phaseLabel.text = text
        phaseBanner.alpha = 0
        phaseLabel.alpha = 0
        phaseLabel.transform = CGAffineTransform(translationX: 0, y: 10)

        UIView.animate(withDuration: 0.4) {
            self.phaseBanner.alpha = 1
            self.phaseLabel.alpha = 1
            self.phaseLabel.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.5, delay: 2.0) {
                self.phaseBanner.alpha = 0
                self.phaseLabel.alpha = 0
            }
        }
    }

    func showRetryPrompt() {
        retryContainer.alpha = 0
        retryContainer.isHidden = false
        UIView.animate(withDuration: 0.6, delay: 1.5) {
            self.retryContainer.alpha = 1
        }
    }

    func hideRetryPrompt() {
        retryContainer.isHidden = true
        retryContainer.alpha = 0
    }

    func triggerScreenShake() {
        let offset: CGFloat = 6
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.values = [0, offset, -offset, offset/2, -offset/2, 0]
        anim.keyTimes = [0, 0.15, 0.35, 0.55, 0.75, 1.0]
        anim.duration = 0.3
        layer.add(anim, forKey: "shake")
    }

    // MARK: - Private — Vignette

    private func setVignetteIntensity(_ v: CGFloat) {
        vignetteTop.alpha = v
        vignetteBottom.alpha = v
        vignetteLeft.alpha = v
        vignetteRight.alpha = v
    }

    // MARK: - Setup

    private func setupVignette() {
        let red = UIColor.systemRed

        for vig in [vignetteTop, vignetteBottom, vignetteLeft, vignetteRight] {
            vig.translatesAutoresizingMaskIntoConstraints = false
            vig.isUserInteractionEnabled = false
            vig.alpha = 0
            insertSubview(vig, at: 0)
        }

        vignetteTop.setColors([red.withAlphaComponent(0.6), .clear])
        vignetteTop.direction = .vertical
        vignetteBottom.setColors([.clear, red.withAlphaComponent(0.6)])
        vignetteBottom.direction = .vertical
        vignetteLeft.setColors([red.withAlphaComponent(0.4), .clear])
        vignetteLeft.direction = .horizontal
        vignetteRight.setColors([.clear, red.withAlphaComponent(0.4)])
        vignetteRight.direction = .horizontal

        let h: CGFloat = 120
        NSLayoutConstraint.activate([
            vignetteTop.topAnchor.constraint(equalTo: topAnchor),
            vignetteTop.leadingAnchor.constraint(equalTo: leadingAnchor),
            vignetteTop.trailingAnchor.constraint(equalTo: trailingAnchor),
            vignetteTop.heightAnchor.constraint(equalToConstant: h),

            vignetteBottom.bottomAnchor.constraint(equalTo: bottomAnchor),
            vignetteBottom.leadingAnchor.constraint(equalTo: leadingAnchor),
            vignetteBottom.trailingAnchor.constraint(equalTo: trailingAnchor),
            vignetteBottom.heightAnchor.constraint(equalToConstant: h),

            vignetteLeft.topAnchor.constraint(equalTo: topAnchor),
            vignetteLeft.bottomAnchor.constraint(equalTo: bottomAnchor),
            vignetteLeft.leadingAnchor.constraint(equalTo: leadingAnchor),
            vignetteLeft.widthAnchor.constraint(equalToConstant: 60),

            vignetteRight.topAnchor.constraint(equalTo: topAnchor),
            vignetteRight.bottomAnchor.constraint(equalTo: bottomAnchor),
            vignetteRight.trailingAnchor.constraint(equalTo: trailingAnchor),
            vignetteRight.widthAnchor.constraint(equalToConstant: 60),
        ])
    }

    private func setupBossHP() {
        bossNameLabel.translatesAutoresizingMaskIntoConstraints = false
        bossNameLabel.text = "T H E   H O L L O W"
        bossNameLabel.font = .systemFont(ofSize: 11, weight: .bold)
        bossNameLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        bossNameLabel.textAlignment = .center
        addSubview(bossNameLabel)

        bossSubtitle.translatesAutoresizingMaskIntoConstraints = false
        bossSubtitle.text = "Ancient Guardian"
        bossSubtitle.font = .systemFont(ofSize: 9, weight: .medium)
        bossSubtitle.textColor = UIColor.white.withAlphaComponent(0.35)
        bossSubtitle.textAlignment = .center
        addSubview(bossSubtitle)

        bossHPTrack.translatesAutoresizingMaskIntoConstraints = false
        bossHPTrack.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        bossHPTrack.layer.cornerRadius = 3
        bossHPTrack.clipsToBounds = true
        addSubview(bossHPTrack)

        bossHPFill.translatesAutoresizingMaskIntoConstraints = false
        bossHPFill.layer.cornerRadius = 3
        bossHPFill.clipsToBounds = true
        bossHPFill.setColors([
            UIColor(red: 0.8, green: 0.25, blue: 0.1, alpha: 1),
            UIColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 1)
        ])
        bossHPFill.direction = .horizontal
        bossHPTrack.addSubview(bossHPFill)

        let widthC = bossHPFill.widthAnchor.constraint(equalTo: bossHPTrack.widthAnchor, multiplier: 1.0)
        hpFillWidthConstraint = widthC

        NSLayoutConstraint.activate([
            bossNameLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            bossNameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            bossHPTrack.topAnchor.constraint(equalTo: bossNameLabel.bottomAnchor, constant: 6),
            bossHPTrack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            bossHPTrack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            bossHPTrack.heightAnchor.constraint(equalToConstant: 6),

            bossHPFill.topAnchor.constraint(equalTo: bossHPTrack.topAnchor),
            bossHPFill.leadingAnchor.constraint(equalTo: bossHPTrack.leadingAnchor),
            bossHPFill.bottomAnchor.constraint(equalTo: bossHPTrack.bottomAnchor),
            widthC,

            bossSubtitle.topAnchor.constraint(equalTo: bossHPTrack.bottomAnchor, constant: 3),
            bossSubtitle.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    private func setupPlayerHP() {
        playerHPStack.translatesAutoresizingMaskIntoConstraints = false
        playerHPStack.axis = .horizontal
        playerHPStack.spacing = 6
        addSubview(playerHPStack)

        for _ in 0..<heartCount {
            let iv = UIImageView(image: UIImage(systemName: "heart.fill"))
            iv.tintColor = .systemRed
            iv.contentMode = .scaleAspectFit
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.widthAnchor.constraint(equalToConstant: 20).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 20).isActive = true
            heartViews.append(iv)
            playerHPStack.addArrangedSubview(iv)
        }

        NSLayoutConstraint.activate([
            playerHPStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            playerHPStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func setupRange() {
        rangeRing.translatesAutoresizingMaskIntoConstraints = false
        rangeRing.layer.borderWidth = 2
        rangeRing.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        rangeRing.layer.cornerRadius = 22
        rangeRing.backgroundColor = .clear
        addSubview(rangeRing)

        rangeLabel.translatesAutoresizingMaskIntoConstraints = false
        rangeLabel.font = .systemFont(ofSize: 8, weight: .heavy)
        rangeLabel.textAlignment = .center
        rangeLabel.textColor = UIColor.white.withAlphaComponent(0.25)
        addSubview(rangeLabel)

        NSLayoutConstraint.activate([
            rangeRing.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            rangeRing.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -14),
            rangeRing.widthAnchor.constraint(equalToConstant: 44),
            rangeRing.heightAnchor.constraint(equalToConstant: 44),

            rangeLabel.centerXAnchor.constraint(equalTo: rangeRing.centerXAnchor),
            rangeLabel.topAnchor.constraint(equalTo: rangeRing.bottomAnchor, constant: 2),
        ])
    }

    private func setupDamageFlash() {
        damageFlash.translatesAutoresizingMaskIntoConstraints = false
        damageFlash.backgroundColor = UIColor.systemRed
        damageFlash.alpha = 0
        damageFlash.isUserInteractionEnabled = false
        insertSubview(damageFlash, at: 0)
        NSLayoutConstraint.activate([
            damageFlash.topAnchor.constraint(equalTo: topAnchor),
            damageFlash.bottomAnchor.constraint(equalTo: bottomAnchor),
            damageFlash.leadingAnchor.constraint(equalTo: leadingAnchor),
            damageFlash.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func setupPhaseBanner() {
        phaseBanner.translatesAutoresizingMaskIntoConstraints = false
        phaseBanner.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        phaseBanner.alpha = 0
        addSubview(phaseBanner)

        phaseLabel.translatesAutoresizingMaskIntoConstraints = false
        phaseLabel.font = .systemFont(ofSize: 20, weight: .heavy)
        phaseLabel.textColor = UIColor(red: 1, green: 0.35, blue: 0.05, alpha: 1)
        phaseLabel.textAlignment = .center
        phaseLabel.alpha = 0
        addSubview(phaseLabel)

        NSLayoutConstraint.activate([
            phaseBanner.centerYAnchor.constraint(equalTo: centerYAnchor),
            phaseBanner.leadingAnchor.constraint(equalTo: leadingAnchor),
            phaseBanner.trailingAnchor.constraint(equalTo: trailingAnchor),
            phaseBanner.heightAnchor.constraint(equalToConstant: 50),
            phaseLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            phaseLabel.centerYAnchor.constraint(equalTo: phaseBanner.centerYAnchor),
        ])
    }

    private func setupRetry() {
        retryContainer.translatesAutoresizingMaskIntoConstraints = false
        retryContainer.isHidden = true
        addSubview(retryContainer)

        deathLabel.translatesAutoresizingMaskIntoConstraints = false
        deathLabel.text = "Y O U   D I E D"
        deathLabel.font = .systemFont(ofSize: 28, weight: .heavy)
        deathLabel.textColor = UIColor(red: 0.8, green: 0.15, blue: 0.1, alpha: 1)
        deathLabel.textAlignment = .center
        retryContainer.addSubview(deathLabel)

        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("  RETRY  ", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        retryButton.layer.cornerRadius = 8
        retryButton.layer.borderWidth = 1
        retryButton.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryContainer.addSubview(retryButton)

        NSLayoutConstraint.activate([
            retryContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            retryContainer.widthAnchor.constraint(equalToConstant: 300),

            deathLabel.topAnchor.constraint(equalTo: retryContainer.topAnchor),
            deathLabel.centerXAnchor.constraint(equalTo: retryContainer.centerXAnchor),

            retryButton.topAnchor.constraint(equalTo: deathLabel.bottomAnchor, constant: 24),
            retryButton.centerXAnchor.constraint(equalTo: retryContainer.centerXAnchor),
            retryButton.heightAnchor.constraint(equalToConstant: 44),
            retryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            retryButton.bottomAnchor.constraint(equalTo: retryContainer.bottomAnchor),
        ])
    }

    @objc private func retryTapped() { onRetryTapped?() }
}

// MARK: - GradientView

/// Reusable UIView backed by a CAGradientLayer for HP fills and vignettes.
final class GradientView: UIView {

    enum Direction { case horizontal, vertical }
    var direction: Direction = .horizontal { didSet { updatePoints() } }

    override class var layerClass: AnyClass { CAGradientLayer.self }
    private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

    func setColors(_ colors: [UIColor]) {
        gradientLayer.colors = colors.map(\.cgColor)
    }

    private func updatePoints() {
        switch direction {
        case .horizontal:
            gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint   = CGPoint(x: 1, y: 0.5)
        case .vertical:
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint   = CGPoint(x: 0.5, y: 1)
        }
    }
}
