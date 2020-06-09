/*
* Copyright (c) 2020 De Staat der Nederlanden, Ministerie van Volksgezondheid, Welzijn en Sport.
*  Licensed under the EUROPEAN UNION PUBLIC LICENCE v. 1.2
*
*  SPDX-License-Identifier: EUPL-1.2
*/

@testable import EN
import Foundation
import XCTest

final class InfectedInfoRouterTests: XCTestCase {
    private let viewController = InfectedInfoViewControllableMock()
    private let listener = InfectedInfoListenerMock()
    
    private var router: InfectedInfoRouter!
    
    override func setUp() {
        super.setUp()
        
        // TODO: Add other dependencies
        router = InfectedInfoRouter(listener: listener,
                                    viewController: viewController)
    }
    
    func test_init_setsRouterOnViewController() {
        XCTAssertEqual(viewController.routerSetCallCount, 1)
    }
    
    // TODO: Add more tests
}