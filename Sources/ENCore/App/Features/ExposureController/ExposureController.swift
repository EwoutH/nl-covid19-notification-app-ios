/*
 * Copyright (c) 2020 De Staat der Nederlanden, Ministerie van Volksgezondheid, Welzijn en Sport.
 *  Licensed under the EUROPEAN UNION PUBLIC LICENCE v. 1.2
 *
 *  SPDX-License-Identifier: EUPL-1.2
 */

import Combine
import ENFoundation
import Foundation
import UIKit

final class ExposureController: ExposureControlling, Logging {

    init(mutableStateStream: MutableExposureStateStreaming,
         exposureManager: ExposureManaging,
         dataController: ExposureDataControlling,
         networkStatusStream: NetworkStatusStreaming,
         userNotificationCenter: UserNotificationCenter,
         mutableBluetoothStateStream: MutableBluetoothStateStreaming) {
        self.mutableStateStream = mutableStateStream
        self.exposureManager = exposureManager
        self.dataController = dataController
        self.networkStatusStream = networkStatusStream
        self.userNotificationCenter = userNotificationCenter
        self.mutableBluetoothStateStream = mutableBluetoothStateStream
    }

    deinit {
        disposeBag.forEach { $0.cancel() }
    }

    // MARK: - ExposureControlling

    var lastExposureDate: Date? {
        return dataController.lastExposure?.date
    }

    func activate() {
        guard isActivated == false else {
            assertionFailure("Should only activate ExposureController once")
            return
        }

        updatePushNotificationState {
            self.exposureManager.activate { _ in
                self.isActivated = true
                self.postExposureManagerActivation()
                self.updateStatusStream()
            }
        }
    }

    func deactivate() {
        exposureManager.deactivate()
    }

    func getAppVersionInformation(_ completion: @escaping (ExposureDataAppVersionInformation?) -> ()) {
        return dataController
            .getAppVersionInformation()
            .sink(
                receiveCompletion: { result in
                    guard case .failure = result else { return }

                    completion(nil)
                },
                receiveValue: completion)
            .store(in: &disposeBag)
    }

    func isAppDectivated() -> AnyPublisher<Bool, ExposureDataError> {
        return dataController.isAppDectivated()
    }

    func isTestPhase() -> AnyPublisher<Bool, Never> {
        return dataController.isTestPhase().replaceError(with: false).eraseToAnyPublisher()
    }

    func getAppRefreshInterval() -> AnyPublisher<Int, ExposureDataError> {
        return dataController.getAppRefreshInterval()
    }

    func getDecoyProbability() -> AnyPublisher<Float, ExposureDataError> {
        return dataController.getDecoyProbability()
    }

    func getPadding() -> AnyPublisher<Padding, ExposureDataError> {
        return dataController.getPadding()
    }

    func refreshStatus() {
        updatePushNotificationState {
            self.updateStatusStream()
        }
    }

    func updateWhenRequired() -> AnyPublisher<(), ExposureDataError> {
        // update when active, or when inactive due to no recent updates
        guard [.active, .inactive(.noRecentNotificationUpdates)].contains(mutableStateStream.currentExposureState?.activeState) else {
            return Just(()).setFailureType(to: ExposureDataError.self).eraseToAnyPublisher()
        }
        return fetchAndProcessExposureKeySets()
    }

    func processPendingUploadRequests() -> AnyPublisher<(), ExposureDataError> {
        return dataController
            .processPendingUploadRequests()
    }

    func notifyUserIfRequired() {
        let timeInterval = TimeInterval(60 * 60 * 24) // 24 hours
        guard
            let lastSuccessfulProcessingDate = dataController.lastSuccessfulProcessingDate,
            lastSuccessfulProcessingDate.advanced(by: timeInterval) < Date()
        else {
            return
        }
        guard let lastLocalNotificationExposureDate = dataController.lastLocalNotificationExposureDate else {
            // We haven't shown a notification to the user before so we should show one now
            return notifyUserAppNeedsUpdate()
        }
        guard lastLocalNotificationExposureDate.advanced(by: timeInterval) < Date() else {
            return
        }
        notifyUserAppNeedsUpdate()
    }

    func requestExposureNotificationPermission(_ completion: ((ExposureManagerError?) -> ())?) {
        exposureManager.setExposureNotificationEnabled(true) { result in
            // wait for 0.2s, there seems to be a glitch in the framework
            // where after successful activation it returns '.disabled' for a
            // split second
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if case let .failure(error) = result {
                    completion?(error)
                } else {
                    completion?(nil)
                }

                self.updateStatusStream()
            }
        }
    }

    func requestPushNotificationPermission(_ completion: @escaping (() -> ())) {
        func request() {
            userNotificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                DispatchQueue.main.async {
                    completion()
                }
            }
        }

        userNotificationCenter.getAuthorizationStatus { authorizationStatus in
            if authorizationStatus == .authorized {
                completion()
            } else {
                request()
            }
        }
    }

    func fetchAndProcessExposureKeySets() -> AnyPublisher<(), ExposureDataError> {
        if let exposureKeyUpdateStream = exposureKeyUpdateStream {
            // already fetching
            return exposureKeyUpdateStream.eraseToAnyPublisher()
        }

        let stream = dataController
            .fetchAndProcessExposureKeySets(exposureManager: exposureManager)
            .handleEvents(
                receiveCompletion: { completion in
                    self.updateStatusStream()
                    self.exposureKeyUpdateStream = nil
                },
                receiveCancel: {
                    self.updateStatusStream()
                    self.exposureKeyUpdateStream = nil
                })
            .eraseToAnyPublisher()

        exposureKeyUpdateStream = stream

        return stream
    }

    func confirmExposureNotification() {
        dataController
            .removeLastExposure()
            .sink { [weak self] _ in
                self?.updateStatusStream()
            }
            .store(in: &disposeBag)
    }

    func requestLabConfirmationKey(completion: @escaping (Result<ExposureConfirmationKey, ExposureDataError>) -> ()) {
        let receiveCompletion: (Subscribers.Completion<ExposureDataError>) -> () = { result in
            if case let .failure(error) = result {
                completion(.failure(error))
            }
        }

        let receiveValue: (ExposureConfirmationKey) -> () = { key in
            completion(.success(key))
        }

        dataController
            .requestLabConfirmationKey()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: receiveCompletion, receiveValue: receiveValue)
            .store(in: &disposeBag)
    }

    func requestUploadKeys(forLabConfirmationKey labConfirmationKey: ExposureConfirmationKey,
                           completion: @escaping (ExposureControllerUploadKeysResult) -> ()) {
        let receiveCompletion: (Subscribers.Completion<ExposureManagerError>) -> () = { result in
            if case let .failure(error) = result {
                let result: ExposureControllerUploadKeysResult
                switch error {
                case .notAuthorized:
                    result = .notAuthorized
                default:
                    result = .inactive
                }

                completion(result)
            }
        }

        guard let labConfirmationKey = labConfirmationKey as? LabConfirmationKey else {
            completion(.invalidConfirmationKey)
            return
        }

        let receiveValue: ([DiagnosisKey]) -> () = { keys in
            self.upload(diagnosisKeys: keys,
                        labConfirmationKey: labConfirmationKey,
                        completion: completion)
        }

        requestDiagnosisKeys()
            .sink(receiveCompletion: receiveCompletion,
                  receiveValue: receiveValue)
            .store(in: &disposeBag)
    }

    func updateLastLaunch() {
        dataController.setLastAppLaunchDate(Date())
    }

    func updateAndProcessPendingUploads(activateIfNeeded: Bool) -> AnyPublisher<(), ExposureDataError> {
        guard exposureManager.authorizationStatus == .authorized else {
            return Fail(error: .notAuthorized).eraseToAnyPublisher()
        }

        if case .inactive = exposureManager.getExposureNotificationStatus(), activateIfNeeded {
            // framework is inactive and if should be activate, activate and try again
            // this call won't loop as it passes in activateIfNeeded false for the recursive
            // one and therefore it will not get in this if statement again
            return Future { resolve in
                self.exposureManager.activate { _ in
                    resolve(.success(()))
                }
            }
            .setFailureType(to: ExposureDataError.self)
            .flatMap { self.updateAndProcessPendingUploads(activateIfNeeded: false) }
            .eraseToAnyPublisher()
        }

        let sequence: [() -> AnyPublisher<(), ExposureDataError>] = [
            self.updateWhenRequired,
            self.processPendingUploadRequests
        ]

        // Combine all processes together, the sequence will be exectued in the order they are in the `sequence` array
        return Publishers.Sequence<[AnyPublisher<(), ExposureDataError>], ExposureDataError>(sequence: sequence.map { $0() })
            // execute them one by one
            .flatMap(maxPublishers: .max(1)) { $0 }
            // collect them
            .collect()
            // merge
            .compactMap { _ in () }
            // notify the user if required
            .handleEvents(receiveCompletion: { [weak self] result in
                switch result {
                case .finished:
                    self?.logDebug("--- Finished `updateAndProcessPendingUploads` ---")
                    self?.notifyUserIfRequired()
                case let .failure(error):
                    self?.logError("Error completing sequence \(error.localizedDescription)")
                }
            })
            .eraseToAnyPublisher()
    }

    func exposureNotificationStatusCheck() -> AnyPublisher<(), Never> {
        return Deferred {
            Future { promise in

                let now = Date()
                let status = self.exposureManager.getExposureNotificationStatus()

                guard status != .active else {
                    self.dataController.setLastENStatusCheckDate(now)
                    self.logDebug("`exposureNotificationStatusCheck` skipped as it is `active`")
                    return promise(.success(()))
                }

                guard let lastENStatusCheckDate = self.dataController.lastENStatusCheckDate else {
                    self.dataController.setLastENStatusCheckDate(now)
                    self.logDebug("No `lastENStatusCheck`, skipping")
                    return promise(.success(()))
                }

                let timeInterval = TimeInterval(60 * 60 * 24) // 24 hours

                guard lastENStatusCheckDate.advanced(by: timeInterval) < Date() else {
                    promise(.success(()))
                    return self.logDebug("`exposureNotificationStatusCheck` skipped as it hasn't been 24h")
                }

                self.logDebug("EN Status Check not active within 24h: \(status)")
                self.dataController.setLastENStatusCheckDate(now)

                let content = UNMutableNotificationContent()
                content.body = .notificationEnStatusNotActive
                content.sound = .default
                content.badge = 0

                self.sendNotification(content: content, identifier: .enStatusDisabled) { _ in
                    promise(.success(()))
                }
            }
        }.eraseToAnyPublisher()
    }

    func lastOpenedNotificationCheck() -> AnyPublisher<(), Never> {
        return Deferred {
            Future { promise in

                guard let lastAppLaunch = self.dataController.lastAppLaunchDate else {
                    self.logDebug("`lastOpenedNotificationCheck` skipped as there is no `lastAppLaunchDate`")
                    return promise(.success(()))
                }
                guard let lastExposure = self.dataController.lastExposure else {
                    self.logDebug("`lastOpenedNotificationCheck` skipped as there is no `lastExposureDate`")
                    return promise(.success(()))
                }

                let timeInterval = TimeInterval(60 * 60 * 3) // 3 hours

                guard lastAppLaunch.advanced(by: timeInterval) < Date() else {
                    promise(.success(()))
                    return self.logDebug("`lastOpenedNotificationCheck` skipped as it hasn't been 3h")
                }

                self.logDebug("User has not opened the app in 3 hours.")

                let calendar = Calendar.current

                let today = calendar.startOfDay(for: Date())
                let lastExposureDate = calendar.startOfDay(for: lastExposure.date)

                let components = calendar.dateComponents([.day], from: today, to: lastExposureDate)
                let days = components.day ?? 0

                let content = UNMutableNotificationContent()
                content.body = .exposureNotificationReminder(.exposureNotificationUserExplanation(.statusNotifiedDaysAgo(days: days)))
                content.sound = .default
                content.badge = 0

                self.sendNotification(content: content, identifier: .enStatusDisabled) { _ in
                    promise(.success(()))
                }
            }
        }.eraseToAnyPublisher()
    }

    // MARK: - Private

    private func postExposureManagerActivation() {
        mutableStateStream
            .exposureState
            .combineLatest(networkStatusStream.networkStatusStream) { (exposureState, networkState) -> Bool in
                return [.active, .inactive(.noRecentNotificationUpdates)].contains(exposureState.activeState)
                    && networkState
            }
            .filter { $0 }
            .first()
            .handleEvents(receiveOutput: { [weak self] _ in self?.updateStatusStream() })
            .flatMap { [weak self] (_) -> AnyPublisher<(), Never> in
                return self?
                    .updateWhenRequired()
                    .replaceError(with: ())
                    .eraseToAnyPublisher() ?? Just(()).eraseToAnyPublisher()
            }
            .sink(receiveValue: { _ in })
            .store(in: &disposeBag)

        networkStatusStream
            .networkStatusStream
            .handleEvents(receiveOutput: { [weak self] _ in self?.updateStatusStream() })
            .filter { networkStatus in return true } // only update when internet is active
            .flatMap { [weak self] (_) -> AnyPublisher<(), Never> in
                return self?
                    .updateWhenRequired()
                    .replaceError(with: ())
                    .eraseToAnyPublisher() ?? Just(()).eraseToAnyPublisher()
            }
            .sink(receiveValue: { _ in })
            .store(in: &disposeBag)
    }

    private func updateStatusStream() {
        guard isActivated else {
            return
        }

        let noInternetIntervalForShowingWarning = TimeInterval(60 * 60 * 24) // 24 hours
        let hasBeenTooLongSinceLastUpdate: Bool

        if let lastSuccessfulProcessingDate = dataController.lastSuccessfulProcessingDate {
            hasBeenTooLongSinceLastUpdate = lastSuccessfulProcessingDate.advanced(by: noInternetIntervalForShowingWarning) < Date()
        } else {
            hasBeenTooLongSinceLastUpdate = false
        }

        let activeState: ExposureActiveState
        let exposureManagerStatus = exposureManager.getExposureNotificationStatus()

        switch exposureManagerStatus {
        case .active where hasBeenTooLongSinceLastUpdate:
            activeState = .inactive(.noRecentNotificationUpdates)
        case .active where !isPushNotificationsEnabled:
            activeState = .inactive(.pushNotifications)
        case .active:
            activeState = .active
        case .inactive(_) where hasBeenTooLongSinceLastUpdate:
            activeState = .inactive(.noRecentNotificationUpdates)
        case let .inactive(error) where error == .bluetoothOff:
            activeState = .inactive(.bluetoothOff)
        case let .inactive(error) where error == .disabled || error == .restricted:
            activeState = .inactive(.disabled)
        case let .inactive(error) where error == .notAuthorized:
            activeState = .notAuthorized
        case let .inactive(error) where error == .unknown || error == .internalTypeMismatch:
            // Most likely due to code signing issues
            activeState = .inactive(.disabled)
        case .inactive where !isPushNotificationsEnabled:
            activeState = .inactive(.pushNotifications)
        case .inactive:
            activeState = .inactive(.disabled)
        case .notAuthorized:
            activeState = .notAuthorized
        case .authorizationDenied:
            activeState = .authorizationDenied
        }

        mutableStateStream.update(state: .init(notifiedState: notifiedState, activeState: activeState))
    }

    private var notifiedState: ExposureNotificationState {
        guard let exposureReport = dataController.lastExposure else {
            return .notNotified
        }

        return .notified(exposureReport.date)
    }

    private func requestDiagnosisKeys() -> AnyPublisher<[DiagnosisKey], ExposureManagerError> {
        return Future { promise in
            self.exposureManager.getDiagnonisKeys(completion: promise)
        }
        .share()
        .eraseToAnyPublisher()
    }

    private func upload(diagnosisKeys keys: [DiagnosisKey],
                        labConfirmationKey: LabConfirmationKey,
                        completion: @escaping (ExposureControllerUploadKeysResult) -> ()) {
        let mapExposureDataError: (ExposureDataError) -> ExposureControllerUploadKeysResult = { error in
            switch error {
            case .internalError, .networkUnreachable, .serverError:
                // No network request is done (yet), these errors can only mean
                // an internal error
                return .internalError
            case .inactive, .signatureValidationFailed:
                return .inactive
            case .notAuthorized:
                return .notAuthorized
            case .responseCached:
                return .responseCached
            }
        }

        let receiveCompletion: (Subscribers.Completion<ExposureDataError>) -> () = { result in
            switch result {
            case let .failure(error):
                completion(mapExposureDataError(error))
            default:
                break
            }
        }

        self.dataController
            .upload(diagnosisKeys: keys, labConfirmationKey: labConfirmationKey)
            .map { _ in return ExposureControllerUploadKeysResult.success }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: receiveCompletion,
                  receiveValue: completion)
            .store(in: &disposeBag)
    }

    private func notifyUserAppNeedsUpdate() {
        let content = UNMutableNotificationContent()
        content.title = .statusAppStateInactiveTitle
        content.body = String(format: .statusAppStateInactiveDescription)
        content.sound = UNNotificationSound.default
        content.badge = 0

        sendNotification(content: content, identifier: .inactive) { success in
            if success {
                self.dataController.updateLastLocalNotificationExposureDate(Date())
            }
        }
    }

    private func updatePushNotificationState(completition: @escaping () -> ()) {
        userNotificationCenter.getAuthorizationStatus { authorizationStatus in
            self.isPushNotificationsEnabled = authorizationStatus == .authorized
            completition()
        }
    }

    private func sendNotification(content: UNNotificationContent, identifier: PushNotificationIdentifier, completion: @escaping (Bool) -> ()) {
        userNotificationCenter.getAuthorizationStatus { status in
            guard status == .authorized else {
                completion(false)
                return self.logError("Not authorized to post notifications")
            }

            let request = UNNotificationRequest(identifier: identifier.rawValue,
                                                content: content,
                                                trigger: nil)

            self.userNotificationCenter.add(request) { error in
                guard let error = error else {
                    completion(true)
                    return
                }
                self.logError("Error posting notification: \(identifier.rawValue) \(error.localizedDescription)")
                completion(false)
            }
        }
    }

    private let mutableBluetoothStateStream: MutableBluetoothStateStreaming
    private let mutableStateStream: MutableExposureStateStreaming
    private let exposureManager: ExposureManaging
    private let dataController: ExposureDataControlling
    private var disposeBag = Set<AnyCancellable>()
    private var exposureKeyUpdateStream: AnyPublisher<(), ExposureDataError>?
    private let networkStatusStream: NetworkStatusStreaming
    private var isActivated = false
    private var isPushNotificationsEnabled = false
    private let userNotificationCenter: UserNotificationCenter
}

extension LabConfirmationKey: ExposureConfirmationKey {
    var key: String {
        return identifier
    }

    var expiration: Date {
        return validUntil
    }
}
