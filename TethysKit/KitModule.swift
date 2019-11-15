import Foundation
import Swinject
#if os(iOS)
    import CoreSpotlight
#endif
import FutureHTTP
import Reachability
import RealmSwift
import SwiftKeychainWrapper

public let kMainQueue = "kMainQueue"
public let kBackgroundQueue = "kBackgroundQueue"
private let kRealmQueue = "kRealmQueue"

public func configure(container: Container) {
    container.register(OperationQueue.self, name: kMainQueue) { _ in OperationQueue.main}
    container.register(OperationQueue.self, name: kBackgroundQueue) { _ in
        let backgroundQueue = OperationQueue()
        backgroundQueue.qualityOfService = QualityOfService.utility
        backgroundQueue.maxConcurrentOperationCount = 1
        return backgroundQueue
    }.inObjectScope(.container)

    container.register(OperationQueue.self, name: kRealmQueue) { _ in
        let realmQueue = OperationQueue()
        realmQueue.qualityOfService = .userInitiated
        realmQueue.maxConcurrentOperationCount = 1
        return realmQueue
    }.inObjectScope(.container)

    container.register(FileManager.self) { _ in FileManager.default }
    container.register(UserDefaults.self) { _ in UserDefaults.standard }
    container.register(Bundle.self) { _ in Bundle(for: WebPageParser.classForCoder() )}

    container.register(HTTPClient.self) { _ in URLSession.shared }
    container.register(HTTPClient.self) { r, account in
        return AuthenticatedHTTPClient(
            client: r.resolve(HTTPClient.self)!,
            credentialService: r.resolve(CredentialService.self)!,
            refreshURL: URL(string: "https://www.inoreader.com/oauth2/token")!,
            clientId: Bundle.main.infoDictionary?["InoreaderClientID"] as? String ?? "",
            clientSecret: Bundle.main.infoDictionary?["InoreaderClientSecret"] as? String ?? "",
            accountId: account,
            dateOracle: Date.init
        )
    }

    container.register(Analytics.self) { _ in BadAnalytics() }.inObjectScope(.container)

    container.register(Reachable.self) { _ in
        do {
            return try Reachability()

        } catch let error {
            fatalError("Error getting reachability: \(error)")
        }
    }

    RealmMigrator.beginMigration()

    container.register(BackgroundStateMonitor.self) { _ in BackgroundStateMonitor(notificationCenter: .default) }

    configureServices(container: container)
    configureUseCases(container: container)
}

private func configureServices(container: Container) {
    container.register(AccountService.self) { r in
        return InoreaderAccountService(
            clientId: Bundle.main.infoDictionary?["InoreaderClientID"] as? String ?? "",
            clientSecret: Bundle.main.infoDictionary?["InoreaderClientSecret"] as? String ?? "",
            credentialService: r.resolve(CredentialService.self)!,
            httpClient: r.resolve(HTTPClient.self)!,
            dateOracle: Date.init
        )
    }

    container.register(ArticleService.self) { r in
        return RealmArticleService(
            realmProvider: r.resolve(RealmProvider.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            workQueue: r.resolve(OperationQueue.self, name: kRealmQueue)!
        )
    }

    container.register(ArticleService.self, name: "local") { r in
        return r.resolve(ArticleService.self)!
    }

    container.register(ArticleService.self, name: "network") { r in
        guard let credential = r.resolve(CredentialService.self)?.credentials()
            .wait()?.value?.first(where: { $0.accountType == .inoreader }) else {
                return r.resolve(ArticleService.self)!
        }
        return InoreaderArticleService(
            httpClient: r.resolve(HTTPClient.self, argument: credential.accountId)!,
            baseURL: URL(string: "https://www.inoreader.com")!
        )
    }

    container.register(ArticleCoordinator.self) { r in
        return ArticleCoordinator(
            localArticleService: r.resolve(ArticleService.self, name: "local")!,
            networkArticleServiceProvider: { r.resolve(ArticleService.self, name: "network")! }
        )
    }.inObjectScope(.container)

    container.register(CredentialService.self) { _ in
        return KeychainCredentialService(keychain: KeychainWrapper.standard)
    }

    container.register(FeedService.self) { r in
        guard let credential = r.resolve(CredentialService.self)?.credentials()
            .wait()?.value?.first(where: { $0.accountType == .inoreader }) else {
                return RealmFeedService(
                    realmProvider: r.resolve(RealmProvider.self)!,
                    updateService: r.resolve(UpdateService.self)!,
                    mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
                    workQueue: r.resolve(OperationQueue.self, name: kRealmQueue)!
                )
        }
        return InoreaderFeedService(
            httpClient: r.resolve(HTTPClient.self, argument: credential.accountId)!,
            baseURL: URL(string: "https://www.inoreader.com")!
        )
    }

    container.register(FeedCoordinator.self) { r in
        return FeedCoordinator(
            localFeedService: r.resolve(LocalFeedService.self)!,
            networkFeedServiceProvider: { r.resolve(FeedService.self)! }
        )
    }.inObjectScope(.container)

    container.register(LocalFeedService.self) { r in
        return LocalRealmFeedService(
            realmProvider: r.resolve(RealmProvider.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            workQueue: r.resolve(OperationQueue.self, name: kRealmQueue)!
        )
    }

    container.register(OPMLService.self) { r in
        return LeptonOPMLService(
            feedService: r.resolve(LocalFeedService.self)!,
            feedCoordinator: r.resolve(FeedCoordinator.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            importQueue: r.resolve(OperationQueue.self, name: kBackgroundQueue)!
        )
    }.inObjectScope(.container)

    container.register(RealmProvider.self) { _ in
        return DefaultRealmProvider(configuration: Realm.Configuration.defaultConfiguration)
    }

    container.register(UpdateService.self) { r in
        return RealmRSSUpdateService(
            httpClient: r.resolve(HTTPClient.self)!,
            realmProvider: r.resolve(RealmProvider.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            workQueue: r.resolve(OperationQueue.self, name: kRealmQueue)!
        )
    }
}

private func configureUseCases(container: Container) {
    container.register(ImportUseCase.self) { r in
        return DefaultImportUseCase(
            httpClient: r.resolve(HTTPClient.self)!,
            feedCoordinator: r.resolve(FeedCoordinator.self)!,
            opmlService: r.resolve(OPMLService.self)!,
            fileManager: r.resolve(FileManager.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!
        )
    }

    container.register(UpdateUseCase.self) { r in
        return DefaultUpdateUseCase(
            updateService: r.resolve(UpdateService.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            userDefaults: r.resolve(UserDefaults.self)!
        )
    }.inObjectScope(.container)
}
