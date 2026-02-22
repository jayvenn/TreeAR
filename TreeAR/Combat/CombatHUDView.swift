//
//  CombatHUDView.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import UIKit

/// Full-screen combat overlay with frosted-glass backdrop plates for AR legibility.
///
/// All elements are screen-anchored. Never world-anchored (prevents motion sickness).
/// Uses `UIVisualEffectView` plates behind HUD zones and text shadows on all labels
/// to guarantee readability against any real-world camera background.
final class CombatHUDView: UIView {

    // MARK: - Callbacks

    var onRetryTapped: (() -> Void)?

    // MARK: - Backdrop Plates

    private let topPlate = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let bottomPlate = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))

    // MARK: - Boss HP

    private let bossHPTrack = UIView()
    private let bossHPFill = GradientView()
    private let bossNameLabel = UILabel()
    private let bossSubtitle = UILabel()
    private var hpFillWidthConstraint: NSLayoutConstraint?

    // MARK: - Player HP

    private static let heartCount = 5

    private let playerHPStack = UIStackView()
    private let playerHPLabel = UILabel()
    private var heartViews: [UIImageView] = []

    // MARK: - Effects

    private let vignetteTop = GradientView()
    private let vignetteBottom = GradientView()
    private let vignetteLeft = GradientView()
    private let vignetteRight = GradientView()
    private let damageFlash = UIView()
    private let phaseLabel = UILabel()
    private let phaseBanner = UIView()

    // MARK: - Powerup

    private let powerupBar = UIView()
    private let powerupFill = GradientView()
    private let powerupLabel = UILabel()
    private var powerupFillWidth: NSLayoutConstraint?

    private let pickupBanner = UILabel()

    // MARK: - Combat Tips

    private let tipLabel = UILabel()
    private let tipBackdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private var tipDismissWork: DispatchWorkItem?
    private var shownTipKeys = Set<String>()

    // MARK: - Chase Timer

    private let chaseTimerLabel = UILabel()
    private let chaseSubtitle = UILabel()
    private let chaseBackdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))

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
        setupDamageFlash()
        setupPhaseBanner()
        setupPowerupBar()
        setupPickupBanner()
        setupCombatTips()
        setupChaseTimer()
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
        let total = Swift.max(max, 1)
        let hpPerHeart = Float(total) / Float(heartViews.count)

        for (i, heart) in heartViews.enumerated() {
            let heartFloor = Float(i) * hpPerHeart
            let heartCeil  = Float(i + 1) * hpPerHeart
            let hp = Float(current)

            if hp >= heartCeil {
                heart.image = UIImage(systemName: "heart.fill")
                heart.tintColor = .systemRed
            } else if hp > heartFloor {
                heart.image = UIImage(systemName: "heart.lefthalf.fill")
                heart.tintColor = .systemRed
            } else {
                heart.image = UIImage(systemName: "heart.fill")
                heart.tintColor = UIColor.white.withAlphaComponent(0.15)
            }
        }

        playerHPLabel.text = "\(current) / \(max)"
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

    // MARK: - Powerup

    func updateMachineGunTimer(fraction: Float) {
        let show = fraction > 0
        powerupBar.isHidden = !show
        powerupLabel.isHidden = !show

        powerupFillWidth?.isActive = false
        powerupFillWidth = powerupFill.widthAnchor.constraint(
            equalTo: powerupBar.widthAnchor, multiplier: max(CGFloat(fraction), 0.001))
        powerupFillWidth?.isActive = true
        layoutIfNeeded()
    }

    func showPickupBanner(text: String, color: UIColor) {
        pickupBanner.text = text
        pickupBanner.textColor = color
        pickupBanner.alpha = 0
        pickupBanner.transform = CGAffineTransform(translationX: 0, y: 8)
        UIView.animate(withDuration: 0.3) {
            self.pickupBanner.alpha = 1
            self.pickupBanner.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.4, delay: 1.2) {
                self.pickupBanner.alpha = 0
            }
        }
    }

    // MARK: - Combat Tips

    /// Shows a one-time tip keyed by `id`. Each `id` displays at most once per fight.
    func showTip(_ text: String, id: String, duration: TimeInterval = 3.5) {
        guard !shownTipKeys.contains(id) else { return }
        shownTipKeys.insert(id)

        tipDismissWork?.cancel()
        tipLabel.text = text
        tipBackdrop.transform = CGAffineTransform(translationX: 0, y: 12)
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut) {
            self.tipBackdrop.alpha = 1
            self.tipBackdrop.transform = .identity
        }

        let dismiss = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.3) { self?.tipBackdrop.alpha = 0 }
        }
        tipDismissWork = dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: dismiss)
    }

    func resetTips() {
        shownTipKeys.removeAll()
        tipBackdrop.alpha = 0
        tipDismissWork?.cancel()
    }

    // MARK: - Chase Timer

    func showChaseTimer() {
        chaseBackdrop.alpha = 0
        chaseBackdrop.isHidden = false
        UIView.animate(withDuration: 0.5) {
            self.chaseBackdrop.alpha = 1
        }
    }

    func updateChaseTimer(secondsLeft: Int) {
        chaseTimerLabel.text = "\(secondsLeft)"
        if secondsLeft <= 5 {
            chaseTimerLabel.textColor = .systemRed
            chaseSubtitle.textColor = UIColor.systemRed.withAlphaComponent(0.8)
        } else {
            chaseTimerLabel.textColor = .white
            chaseSubtitle.textColor = UIColor.white.withAlphaComponent(0.7)
        }
    }

    func hideChaseTimer() {
        UIView.animate(withDuration: 0.4) { self.chaseBackdrop.alpha = 0 } completion: { _ in
            self.chaseBackdrop.isHidden = true
        }
    }

    func flashPickup(color: UIColor) {
        let overlay = UIView(frame: bounds)
        overlay.backgroundColor = color.withAlphaComponent(0.15)
        overlay.isUserInteractionEnabled = false
        addSubview(overlay)
        UIView.animate(withDuration: 0.35, animations: { overlay.alpha = 0 }) { _ in
            overlay.removeFromSuperview()
        }
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
        topPlate.translatesAutoresizingMaskIntoConstraints = false
        topPlate.layer.cornerRadius = 16
        topPlate.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        topPlate.clipsToBounds = true
        addSubview(topPlate)

        bossNameLabel.translatesAutoresizingMaskIntoConstraints = false
        bossNameLabel.text = "T H E   H O L L O W"
        bossNameLabel.font = .systemFont(ofSize: 13, weight: .heavy)
        bossNameLabel.textColor = .white
        bossNameLabel.textAlignment = .center
        applyShadow(to: bossNameLabel)
        addSubview(bossNameLabel)

        bossSubtitle.translatesAutoresizingMaskIntoConstraints = false
        bossSubtitle.text = "Ancient Guardian"
        bossSubtitle.font = .systemFont(ofSize: 10, weight: .semibold)
        bossSubtitle.textColor = UIColor.white.withAlphaComponent(0.6)
        bossSubtitle.textAlignment = .center
        applyShadow(to: bossSubtitle)
        addSubview(bossSubtitle)

        bossHPTrack.translatesAutoresizingMaskIntoConstraints = false
        bossHPTrack.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        bossHPTrack.layer.cornerRadius = 4
        bossHPTrack.clipsToBounds = true
        addSubview(bossHPTrack)

        bossHPFill.translatesAutoresizingMaskIntoConstraints = false
        bossHPFill.layer.cornerRadius = 4
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
            topPlate.topAnchor.constraint(equalTo: topAnchor),
            topPlate.leadingAnchor.constraint(equalTo: leadingAnchor),
            topPlate.trailingAnchor.constraint(equalTo: trailingAnchor),
            topPlate.bottomAnchor.constraint(equalTo: bossSubtitle.bottomAnchor, constant: 12),

            bossNameLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            bossNameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            bossHPTrack.topAnchor.constraint(equalTo: bossNameLabel.bottomAnchor, constant: 7),
            bossHPTrack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            bossHPTrack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            bossHPTrack.heightAnchor.constraint(equalToConstant: 8),

            bossHPFill.topAnchor.constraint(equalTo: bossHPTrack.topAnchor),
            bossHPFill.leadingAnchor.constraint(equalTo: bossHPTrack.leadingAnchor),
            bossHPFill.bottomAnchor.constraint(equalTo: bossHPTrack.bottomAnchor),
            widthC,

            bossSubtitle.topAnchor.constraint(equalTo: bossHPTrack.bottomAnchor, constant: 4),
            bossSubtitle.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    private func setupPlayerHP() {
        bottomPlate.translatesAutoresizingMaskIntoConstraints = false
        bottomPlate.layer.cornerRadius = 18
        bottomPlate.clipsToBounds = true
        addSubview(bottomPlate)

        playerHPStack.translatesAutoresizingMaskIntoConstraints = false
        playerHPStack.axis = .horizontal
        playerHPStack.spacing = 8
        addSubview(playerHPStack)

        for _ in 0..<Self.heartCount {
            let iv = UIImageView(image: UIImage(systemName: "heart.fill"))
            iv.tintColor = .systemRed
            iv.contentMode = .scaleAspectFit
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.widthAnchor.constraint(equalToConstant: 26).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 26).isActive = true
            heartViews.append(iv)
            playerHPStack.addArrangedSubview(iv)
        }

        playerHPLabel.translatesAutoresizingMaskIntoConstraints = false
        playerHPLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        playerHPLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        playerHPLabel.textAlignment = .center
        applyShadow(to: playerHPLabel)
        addSubview(playerHPLabel)

        NSLayoutConstraint.activate([
            playerHPLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            playerHPLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -10),

            playerHPStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            playerHPStack.bottomAnchor.constraint(equalTo: playerHPLabel.topAnchor, constant: -4),

            bottomPlate.centerXAnchor.constraint(equalTo: playerHPStack.centerXAnchor),
            bottomPlate.topAnchor.constraint(equalTo: playerHPStack.topAnchor, constant: -8),
            bottomPlate.bottomAnchor.constraint(equalTo: playerHPLabel.bottomAnchor, constant: 8),
            bottomPlate.widthAnchor.constraint(equalTo: playerHPStack.widthAnchor, constant: 28),
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
        phaseBanner.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        phaseBanner.alpha = 0
        addSubview(phaseBanner)

        phaseLabel.translatesAutoresizingMaskIntoConstraints = false
        phaseLabel.font = .systemFont(ofSize: 22, weight: .heavy)
        phaseLabel.textColor = UIColor(red: 1, green: 0.4, blue: 0.1, alpha: 1)
        phaseLabel.textAlignment = .center
        phaseLabel.alpha = 0
        applyShadow(to: phaseLabel)
        addSubview(phaseLabel)

        NSLayoutConstraint.activate([
            phaseBanner.centerYAnchor.constraint(equalTo: centerYAnchor),
            phaseBanner.leadingAnchor.constraint(equalTo: leadingAnchor),
            phaseBanner.trailingAnchor.constraint(equalTo: trailingAnchor),
            phaseBanner.heightAnchor.constraint(equalToConstant: 54),
            phaseLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            phaseLabel.centerYAnchor.constraint(equalTo: phaseBanner.centerYAnchor),
        ])
    }

    private func setupPowerupBar() {
        powerupBar.translatesAutoresizingMaskIntoConstraints = false
        powerupBar.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        powerupBar.layer.cornerRadius = 4
        powerupBar.clipsToBounds = true
        powerupBar.isHidden = true
        addSubview(powerupBar)

        powerupFill.translatesAutoresizingMaskIntoConstraints = false
        powerupFill.setColors([UIColor(red: 0.55, green: 0.15, blue: 1.0, alpha: 1),
                               UIColor(red: 0.7, green: 0.3, blue: 1.0, alpha: 1)])
        powerupFill.direction = .horizontal
        powerupFill.layer.cornerRadius = 4
        powerupFill.clipsToBounds = true
        powerupBar.addSubview(powerupFill)

        powerupLabel.translatesAutoresizingMaskIntoConstraints = false
        powerupLabel.text = "WIZARD GUN"
        powerupLabel.font = .systemFont(ofSize: 11, weight: .heavy)
        powerupLabel.textColor = UIColor(red: 0.85, green: 0.6, blue: 1.0, alpha: 1)
        powerupLabel.textAlignment = .center
        powerupLabel.isHidden = true
        applyShadow(to: powerupLabel)
        addSubview(powerupLabel)

        let fillWidth = powerupFill.widthAnchor.constraint(equalTo: powerupBar.widthAnchor, multiplier: 1.0)
        powerupFillWidth = fillWidth

        NSLayoutConstraint.activate([
            powerupBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            powerupBar.topAnchor.constraint(equalTo: topPlate.bottomAnchor, constant: 12),
            powerupBar.widthAnchor.constraint(equalToConstant: 160),
            powerupBar.heightAnchor.constraint(equalToConstant: 8),

            powerupFill.leadingAnchor.constraint(equalTo: powerupBar.leadingAnchor),
            powerupFill.topAnchor.constraint(equalTo: powerupBar.topAnchor),
            powerupFill.bottomAnchor.constraint(equalTo: powerupBar.bottomAnchor),
            fillWidth,

            powerupLabel.centerXAnchor.constraint(equalTo: powerupBar.centerXAnchor),
            powerupLabel.topAnchor.constraint(equalTo: powerupBar.bottomAnchor, constant: 3),
        ])
    }

    private func setupPickupBanner() {
        pickupBanner.translatesAutoresizingMaskIntoConstraints = false
        pickupBanner.font = .systemFont(ofSize: 18, weight: .heavy)
        pickupBanner.textAlignment = .center
        pickupBanner.alpha = 0
        applyShadow(to: pickupBanner)
        addSubview(pickupBanner)

        NSLayoutConstraint.activate([
            pickupBanner.centerXAnchor.constraint(equalTo: centerXAnchor),
            pickupBanner.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 60),
        ])
    }

    private func setupCombatTips() {
        tipBackdrop.translatesAutoresizingMaskIntoConstraints = false
        tipBackdrop.layer.cornerRadius = 14
        tipBackdrop.clipsToBounds = true
        tipBackdrop.alpha = 0
        addSubview(tipBackdrop)

        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        tipLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        tipLabel.textColor = .white
        tipLabel.textAlignment = .center
        tipLabel.numberOfLines = 2
        applyShadow(to: tipLabel)
        tipBackdrop.contentView.addSubview(tipLabel)

        NSLayoutConstraint.activate([
            tipBackdrop.centerXAnchor.constraint(equalTo: centerXAnchor),
            tipBackdrop.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            tipBackdrop.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -64),

            tipLabel.topAnchor.constraint(equalTo: tipBackdrop.contentView.topAnchor, constant: 12),
            tipLabel.bottomAnchor.constraint(equalTo: tipBackdrop.contentView.bottomAnchor, constant: -12),
            tipLabel.leadingAnchor.constraint(equalTo: tipBackdrop.contentView.leadingAnchor, constant: 20),
            tipLabel.trailingAnchor.constraint(equalTo: tipBackdrop.contentView.trailingAnchor, constant: -20),
        ])
    }

    private func setupChaseTimer() {
        chaseBackdrop.translatesAutoresizingMaskIntoConstraints = false
        chaseBackdrop.layer.cornerRadius = 16
        chaseBackdrop.clipsToBounds = true
        chaseBackdrop.isHidden = true
        addSubview(chaseBackdrop)

        chaseTimerLabel.translatesAutoresizingMaskIntoConstraints = false
        chaseTimerLabel.font = .monospacedDigitSystemFont(ofSize: 48, weight: .heavy)
        chaseTimerLabel.textColor = .white
        chaseTimerLabel.textAlignment = .center
        chaseTimerLabel.text = "20"
        applyShadow(to: chaseTimerLabel)
        chaseBackdrop.contentView.addSubview(chaseTimerLabel)

        chaseSubtitle.translatesAutoresizingMaskIntoConstraints = false
        chaseSubtitle.font = .systemFont(ofSize: 14, weight: .heavy)
        chaseSubtitle.textColor = UIColor.white.withAlphaComponent(0.7)
        chaseSubtitle.textAlignment = .center
        chaseSubtitle.text = "R U N"
        applyShadow(to: chaseSubtitle)
        chaseBackdrop.contentView.addSubview(chaseSubtitle)

        NSLayoutConstraint.activate([
            chaseBackdrop.centerXAnchor.constraint(equalTo: centerXAnchor),
            chaseBackdrop.centerYAnchor.constraint(equalTo: centerYAnchor),
            chaseBackdrop.widthAnchor.constraint(equalToConstant: 120),

            chaseTimerLabel.topAnchor.constraint(equalTo: chaseBackdrop.contentView.topAnchor, constant: 14),
            chaseTimerLabel.centerXAnchor.constraint(equalTo: chaseBackdrop.contentView.centerXAnchor),

            chaseSubtitle.topAnchor.constraint(equalTo: chaseTimerLabel.bottomAnchor, constant: 2),
            chaseSubtitle.centerXAnchor.constraint(equalTo: chaseBackdrop.contentView.centerXAnchor),
            chaseSubtitle.bottomAnchor.constraint(equalTo: chaseBackdrop.contentView.bottomAnchor, constant: -14),
        ])
    }

    private func setupRetry() {
        retryContainer.translatesAutoresizingMaskIntoConstraints = false
        retryContainer.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        retryContainer.layer.cornerRadius = 20
        retryContainer.isHidden = true
        addSubview(retryContainer)

        deathLabel.translatesAutoresizingMaskIntoConstraints = false
        deathLabel.text = "Y O U   D I E D"
        deathLabel.font = .systemFont(ofSize: 30, weight: .heavy)
        deathLabel.textColor = UIColor(red: 0.9, green: 0.15, blue: 0.1, alpha: 1)
        deathLabel.textAlignment = .center
        applyShadow(to: deathLabel)
        retryContainer.addSubview(deathLabel)

        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("  RETRY  ", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        retryButton.layer.cornerRadius = 10
        retryButton.layer.borderWidth = 1.5
        retryButton.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryContainer.addSubview(retryButton)

        NSLayoutConstraint.activate([
            retryContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            retryContainer.widthAnchor.constraint(equalToConstant: 300),

            deathLabel.topAnchor.constraint(equalTo: retryContainer.topAnchor, constant: 28),
            deathLabel.centerXAnchor.constraint(equalTo: retryContainer.centerXAnchor),

            retryButton.topAnchor.constraint(equalTo: deathLabel.bottomAnchor, constant: 24),
            retryButton.centerXAnchor.constraint(equalTo: retryContainer.centerXAnchor),
            retryButton.heightAnchor.constraint(equalToConstant: 48),
            retryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            retryButton.bottomAnchor.constraint(equalTo: retryContainer.bottomAnchor, constant: -24),
        ])
    }

    @objc private func retryTapped() { onRetryTapped?() }

    // MARK: - Helpers

    private func applyShadow(to label: UILabel) {
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowOpacity = 0.9
        label.layer.shadowRadius = 3
    }
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
