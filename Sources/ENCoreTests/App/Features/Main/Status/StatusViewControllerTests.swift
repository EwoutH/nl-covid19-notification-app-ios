/*
 * Copyright (c) 2020 De Staat der Nederlanden, Ministerie van Volksgezondheid, Welzijn en Sport.
 *  Licensed under the EUROPEAN UNION PUBLIC LICENCE v. 1.2
 *
 *  SPDX-License-Identifier: EUPL-1.2
 */

import Combine
@testable import ENCore
import ENFoundation
import Foundation
import RxSwift
import SnapshotTesting
import XCTest

final class StatusViewControllerTests: TestCase {
    private var exposureStateStream = ExposureStateStreamingMock()
    private var interfaceOrientationStream = InterfaceOrientationStreamingMock()
    private var viewController: StatusViewController!
    private let router = StatusRoutingMock()
    private let cardBuilder = CardBuildableMock()
    private var mockExposureDataController: ExposureDataControllingMock!
    private var mockCardListener: CardListeningMock!
    private var mockWebViewBuildable: WebviewBuildableMock!

    override func setUp() {
        super.setUp()

        recordSnapshots = false

        mockCardListener = CardListeningMock()
        mockExposureDataController = ExposureDataControllingMock()
        mockExposureDataController.seenAnnouncements = [.interopAnnouncement]
        mockWebViewBuildable = WebviewBuildableMock()

        AnimationTestingOverrides.animationsEnabled = false
        DateTimeTestingOverrides.overriddenCurrentDate = Date(timeIntervalSince1970: 1593290000) // 27/06/20 20:33
        interfaceOrientationStream.isLandscape = BehaviorSubject(value: false)

        cardBuilder.buildHandler = { listener, cardTypes in
            return CardRouter(viewController: CardViewController(listener: self.mockCardListener,
                                                                 theme: self.theme,
                                                                 types: cardTypes,
                                                                 dataController: self.mockExposureDataController),
                              enableSettingBuilder: EnableSettingBuildableMock(),
                              webviewBuilder: self.mockWebViewBuildable)
        }

        viewController = StatusViewController(exposureStateStream: exposureStateStream,
                                              interfaceOrientationStream: interfaceOrientationStream,
                                              cardBuilder: cardBuilder,
                                              listener: StatusListenerMock(),
                                              theme: theme,
                                              topAnchor: nil,
                                              dataController: mockExposureDataController)
        viewController.router = router
    }

    func test_snapshot_active_not_notified() {
        set(activeState: .active, notified: false)
        snapshots(matching: viewController)
    }

    func test_snapshot_active_notified() {
        set(activeState: .active, notified: true)
        snapshots(matching: viewController)
    }

    func test_snapshot_active_notified_days_ago() {
        DateTimeTestingOverrides.overriddenCurrentDate = Date(timeIntervalSince1970: 1593538088) // 30/06/20 17:28
        set(activeState: .active, notified: true)
        snapshots(matching: viewController)
    }

    func test_snapshot_authorized_denied_notNotified() {
        set(activeState: .authorizationDenied, notified: false)
        snapshots(matching: viewController)
    }

    func test_snapshot_authorized_denied_notified() {
        set(activeState: .authorizationDenied, notified: true)
        snapshots(matching: viewController)
    }

    func test_snapshot_authorized_denied_notified_whith_announcement() {
        mockExposureDataController.seenAnnouncements = []
        set(activeState: .authorizationDenied, notified: true)
        snapshots(matching: viewController)
    }

    func test_snapshot_not_authorized_notified() {
        set(activeState: .notAuthorized, notified: true)
        snapshots(matching: viewController)
    }

    func test_snapshot_not_authorized_not_notified() {
        set(activeState: .notAuthorized, notified: false)
        snapshots(matching: viewController)
    }

    func test_snapshot_no_recent_updates_notified() {
        set(activeState: .inactive(.noRecentNotificationUpdates), notified: true)
        snapshots(matching: viewController)
    }

    func test_snapshot_no_recent_updates_not_notified() {
        set(activeState: .inactive(.noRecentNotificationUpdates), notified: false)
        snapshots(matching: viewController)
    }

    // MARK: - Private

    private func set(activeState: ExposureActiveState, notified: Bool) {
        // 27/06/20 12:46
        let notifiedState: ExposureNotificationState = notified ? .notified(Date(timeIntervalSince1970: 1593260000)) : .notNotified
        let state = ExposureState(notifiedState: notifiedState, activeState: activeState)

        exposureStateStream.exposureState = .just(state)
    }
}
