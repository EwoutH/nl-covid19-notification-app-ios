/*
 * Copyright (c) 2020 De Staat der Nederlanden, Ministerie van Volksgezondheid, Welzijn en Sport.
 *  Licensed under the EUROPEAN UNION PUBLIC LICENCE v. 1.2
 *
 *  SPDX-License-Identifier: EUPL-1.2
 */

import Combine
import Foundation

enum ExposureDataError: Error, Equatable {
    case networkUnreachable
    case serverError
    case internalError
    case inactive(ExposureStateInactiveState)
    case notAuthorized
    case responseCached
    case signatureValidationFailed
}

struct ExposureDataAppVersionInformation {
    let minimumVersion: String
    let minimumVersionMessage: String
    let appStoreURL: String
}

/// @mockable
protocol ExposureDataControlling: AnyObject {

    // MARK: - Exposure Detection

    var lastExposure: ExposureReport? { get }
    var lastSuccessfulProcessingDate: Date? { get }
    var lastLocalNotificationExposureDate: Date? { get }
    var lastENStatusCheckDate: Date? { get }

    func removeLastExposure() -> AnyPublisher<(), Never>
    func fetchAndProcessExposureKeySets(exposureManager: ExposureManaging) -> AnyPublisher<(), ExposureDataError>
    func setLastENStatusCheckDate(_ date: Date)

    // MARK: - Lab Flow

    func processPendingUploadRequests() -> AnyPublisher<(), ExposureDataError>
    func requestLabConfirmationKey() -> AnyPublisher<LabConfirmationKey, ExposureDataError>
    func upload(diagnosisKeys: [DiagnosisKey], labConfirmationKey: LabConfirmationKey) -> AnyPublisher<(), ExposureDataError>

    // MARK: - Misc

    func getAppVersionInformation() -> AnyPublisher<ExposureDataAppVersionInformation?, ExposureDataError>
    func isAppDectivated() -> AnyPublisher<Bool, ExposureDataError>
    func getAppRefreshInterval() -> AnyPublisher<Int, ExposureDataError>
    func getDecoyProbability() -> AnyPublisher<Float, ExposureDataError>
    func getPadding() -> AnyPublisher<Padding, ExposureDataError>
    func updateLastLocalNotificationExposureDate(_ date: Date)
    var isFirstRun: Bool { get }
    var didCompleteOnboarding: Bool { get set }
}

protocol ExposureDataControllerBuildable {
    func build() -> ExposureDataControlling
}

protocol ExposureDataControllerDependency {
    var networkController: NetworkControlling { get }
    var storageController: StorageControlling { get }
}

private final class ExposureDataControllerDependencyProvider: DependencyProvider<ExposureDataControllerDependency>, ExposureDataOperationProviderDependency {

    // MARK: - ExposureDataOperationProviderDependency

    var networkController: NetworkControlling {
        return dependency.networkController
    }

    var storageController: StorageControlling {
        return dependency.storageController
    }

    // MARK: - Private Dependencies

    var operationProvider: ExposureDataOperationProvider {
        return ExposureDataOperationProviderBuilder(dependency: self).build()
    }
}

final class ExposureDataControllerBuilder: Builder<ExposureDataControllerDependency>, ExposureDataControllerBuildable {
    func build() -> ExposureDataControlling {
        let dependencyProvider = ExposureDataControllerDependencyProvider(dependency: dependency)

        return ExposureDataController(operationProvider: dependencyProvider.operationProvider,
                                      storageController: dependencyProvider.storageController)
    }
}
