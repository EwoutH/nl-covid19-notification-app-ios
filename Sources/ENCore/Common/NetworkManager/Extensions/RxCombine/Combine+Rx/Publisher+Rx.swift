/*
 * Copyright (c) 2020 De Staat der Nederlanden, Ministerie van Volksgezondheid, Welzijn en Sport.
 *  Licensed under the EUROPEAN UNION PUBLIC LICENCE v. 1.2
 *
 *  SPDX-License-Identifier: EUPL-1.2
 */

#if canImport(Combine)
    import Combine
    import RxSwift

    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public extension Publisher {
        /// Returns an Observable<Output> representing the underlying
        /// Publisher. Upon subscription, the Publisher's sink pushes
        /// events into the Observable. Upon disposing of the subscription,
        /// the sink is cancelled.
        ///
        /// - returns: Observable<Output>
        func asObservable() -> Observable<Output> {
            Observable<Output>.create { observer in
                let cancellable = self.sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            observer.onCompleted()
                        case let .failure(error):
                            observer.onError(error)
                        }
                    },
                    receiveValue: { value in
                        observer.onNext(value)
                })

                return Disposables.create { cancellable.cancel() }
            }
        }
    }
#endif
