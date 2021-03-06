/*
 * Copyright (c) 2020 De Staat der Nederlanden, Ministerie van Volksgezondheid, Welzijn en Sport.
 *  Licensed under the EUROPEAN UNION PUBLIC LICENCE v. 1.2
 *
 *  SPDX-License-Identifier: EUPL-1.2
 */

@testable import ENCore
import Foundation
import SnapshotTesting
import XCTest

final class EnableSettingViewControllerSnapshotTests: TestCase {
    private var viewController: EnableSettingViewController!
    private var bluetoothStateStream = BluetoothStateStreamingMock()
    private var environmentController = EnvironmentControllingMock()

    override func setUp() {
        super.setUp()

        recordSnapshots = false
    }

    func test_enableBluetooth() {
        viewController = EnableSettingViewController(listener: EnableSettingListenerMock(),
                                                     theme: theme,
                                                     setting: .enableBluetooth,
                                                     bluetoothStateStream: bluetoothStateStream,
                                                     environmentController: environmentController)

        snapshots(matching: viewController)
    }

    func test_enableExposureNotifications() {
        environmentController.isiOS137orHigher = false
        viewController = EnableSettingViewController(listener: EnableSettingListenerMock(),
                                                     theme: theme,
                                                     setting: .enableExposureNotifications,
                                                     bluetoothStateStream: bluetoothStateStream,
                                                     environmentController: environmentController)

        snapshots(matching: viewController)
    }

    func test_enableExposureNotifications_extended() {
        environmentController.isiOS137orHigher = true
        viewController = EnableSettingViewController(listener: EnableSettingListenerMock(),
                                                     theme: theme,
                                                     setting: .enableExposureNotifications,
                                                     bluetoothStateStream: bluetoothStateStream,
                                                     environmentController: environmentController)

        snapshots(matching: viewController)
    }

    func test_enableLocalNotifications() {
        viewController = EnableSettingViewController(listener: EnableSettingListenerMock(),
                                                     theme: theme,
                                                     setting: .enableLocalNotifications,
                                                     bluetoothStateStream: bluetoothStateStream,
                                                     environmentController: environmentController)

        snapshots(matching: viewController)
    }
}
