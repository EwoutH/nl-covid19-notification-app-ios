/*
 * Copyright (c) 2020 De Staat der Nederlanden, Ministerie van Volksgezondheid, Welzijn en Sport.
 *  Licensed under the EUROPEAN UNION PUBLIC LICENCE v. 1.2
 *
 *  SPDX-License-Identifier: EUPL-1.2
 */

import ENFoundation
import Lottie
import UIKit

final class OnboardingConsentStep: NSObject {
    enum Index: Int {
        case en = 0
        case bluetooth
        case share
    }

    enum Illustration {
        case none
        case image(image: UIImage?)
        case animation(named: String, repeatFromFrame: Int? = nil, defaultFrame: CGFloat? = nil)
    }

    var step: Index
    var attributedTitle: NSAttributedString = NSAttributedString(string: "")
    var attributedContent: NSAttributedString = NSAttributedString(string: "")
    var illustration: Illustration
    var primaryButtonTitle: String = ""
    var secondaryButtonTitle: String?
    var hasNavigationBarSkipButton: Bool = false

    init(step: Index,
         theme: Theme,
         title: String,
         content: String,
         illustration: Illustration,
         primaryButtonTitle: String,
         secondaryButtonTitle: String?,
         hasNavigationBarSkipButton: Bool) {

        self.step = step
        self.illustration = illustration
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
        self.hasNavigationBarSkipButton = hasNavigationBarSkipButton

        self.attributedTitle = .makeFromHtml(text: title, font: theme.fonts.title2, textColor: .black, textAlignment: Localization.isRTL ? .right : .left)
        self.attributedContent = .makeFromHtml(text: content, font: theme.fonts.body, textColor: theme.colors.gray, textAlignment: Localization.isRTL ? .right : .left)
    }
}
