/*
 * Copyright (c) 2020 De Staat der Nederlanden, Ministerie van Volksgezondheid, Welzijn en Sport.
 *  Licensed under the EUROPEAN UNION PUBLIC LICENCE v. 1.2
 *
 *  SPDX-License-Identifier: EUPL-1.2
 */

import ENFoundation
import Foundation
import UIKit

/// @mockable
protocol UpdateOperatingSystemRouting: Routing {}

final class UpdateOperatingSystemViewController: ViewController, UpdateOperatingSystemViewControllable {

    var router: LaunchScreenRouting?

    // MARK: - Lifecycle

    override init(theme: Theme) {
        super.init(theme: theme)

        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    override func loadView() {
        self.view = internalView
        self.view.frame = UIScreen.main.bounds
    }

    // MARK: - Setups

    private func setupViews() {
        self.view.backgroundColor = theme.colors.viewControllerBackground

        internalView.button.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)

        internalView.titleLabel.text = .updateSoftwareOSTitle
        internalView.titleLabel.font = theme.fonts.title2

        internalView.contentLabel.text = .updateSoftwareOSDescription
        internalView.contentLabel.font = theme.fonts.body
    }

    // MARK: - Functions

    @objc func buttonPressed() {
        present(UpdateOperatingSystemInstructionsViewController(theme: theme), animated: true, completion: nil)
    }

    // MARK: - Private

    private lazy var internalView: RequiresUpdateView = RequiresUpdateView(theme: theme)
}

final class RequiresUpdateView: UIView {

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.image = UIImage(named: "UpdateApp")
        return imageView
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    lazy var button: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(.updateButtonUpdate, for: .normal)
        button.titleLabel?.font = theme.fonts.bodyBold
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        button.backgroundColor = theme.colors.primary
        button.setTitleColor(.white, for: .normal)
        return button
    }()

    private lazy var viewsInDisplayOrder = [imageView, titleLabel, contentLabel, button]

    // MARK: - Live cycle

    init(theme: Theme) {
        self.theme = theme
        super.init(frame: .zero)

        setupViews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .white
        viewsInDisplayOrder.forEach { addSubview($0) }
    }

    private func setupConstraints() {

        var constraints = [[NSLayoutConstraint]()]

        constraints.append([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 50),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            imageView.heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.83, constant: 1)
        ])

        constraints.append([
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])

        constraints.append([
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            contentLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            contentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            contentLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])

        let bottomMargin: CGFloat = UIWindow().safeAreaInsets.bottom == 0 ? -20 : 0
        constraints.append([
            button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: bottomMargin),
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])

        constraints.forEach { NSLayoutConstraint.activate($0) }

        self.contentLabel.sizeToFit()
    }

    private let theme: Theme
}
