@testable import TethysKit
import CBGPromise
import Result

class FakeUpdateService: UpdateServiceType {
    var updateFeedCalls: [Feed] = []
    var updateFeedPromises: [Promise<Result<Feed, TethysError>>] = []
    func updateFeed(_ feed: Feed) -> Future<Result<Feed, TethysError>> {
        self.updatedFeeds.append(feed)
        let promise = Promise<Result<Feed, TethysError>>()
        self.updateFeedPromises.append(promise)
        return promise.future
    }
}
