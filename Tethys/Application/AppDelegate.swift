import UIKit
import Swinject
import TethysKit
import Result
import CoreSpotlight

@UIApplicationMain
public final class AppDelegate: UIResponder, UIApplicationDelegate {
    public var window: UIWindow?

    public lazy var container: Container = {
        let container = Container()
        TethysKit.configure(container: container)
        Tethys.configure(container: container)
        return container
    }()

    private lazy var feedRepository: DatabaseUseCase = {
        return self.container.resolve(DatabaseUseCase.self)!
    }()

    private lazy var analytics: Analytics = {
        self.container.resolve(Analytics.self)!
    }()

    private lazy var importUseCase: ImportUseCase = {
        self.container.resolve(ImportUseCase.self)!
    }()

    internal lazy var splitView: SplitViewController = {
        self.container.resolve(SplitViewController.self)!
    }()

    private lazy var bootstrapper: Bootstrapper = {
        self.container.resolve(Bootstrapper.self, arguments: self.getWindow(), self.splitView)!
    }()

    private func getWindow() -> UIWindow {
        if let window = self.window {
            return window
        }
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = UIColor.white
        window.makeKeyAndVisible()
        self.window = window
        return window
    }

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?
        ) -> Bool {
        UINavigationBar.appearance().tintColor = UIColor.darkGreen()
        UIBarButtonItem.appearance().tintColor = UIColor.darkGreen()
        UITabBar.appearance().tintColor = UIColor.darkGreen()

        if NSClassFromString("XCTestCase") != nil &&
            launchOptions?[UIApplicationLaunchOptionsKey("test")] as? Bool != true {
            self.getWindow().rootViewController = UIViewController()
            return true
        }

        self.createControllerHierarchy()

        self.feedRepository.addSubscriber(application)

        if launchOptions == nil || launchOptions?.isEmpty == true ||
            (launchOptions?.count == 1 && launchOptions?[UIApplicationLaunchOptionsKey("test")] as? Bool == true) {
            self.analytics.logEvent("SessionBegan", data: nil)
        }

        application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)

        return true
    }

    public func application(_ app: UIApplication,
                            open url: URL,
                            options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
        _ = self.importUseCase.scanForImportable(url).then { item in
            if case let .opml(url, _) = item {
                _ = self.importUseCase.importItem(url)
            }
        }
        return true
    }

    // MARK: Quick Actions

    @available(iOS 9, *)
    public func application(_ application: UIApplication,
                            performActionFor shortcutItem: UIApplicationShortcutItem,
                            completionHandler: @escaping (Bool) -> Void) {
        let splitView = self.getWindow().rootViewController as? UISplitViewController
        guard let navigationController = splitView?.viewControllers.first as? UINavigationController else {
            completionHandler(false)
            return
        }
        navigationController.popToRootViewController(animated: false)

        guard let feedsViewController = navigationController.topViewController as? FeedsTableViewController else {
            completionHandler(false)
            return
        }

        if shortcutItem.type == "com.rachelbrindle.rssclient.newfeed" {
            feedsViewController.importFromWeb()
            self.analytics.logEvent("QuickActionUsed", data: ["kind": "Add New Feed"])
            completionHandler(true)
        } else if shortcutItem.type == "com.rachelbrindle.rssclient.viewfeed" {
            let feedTitle = shortcutItem.userInfo?["feed"] as? String ?? shortcutItem.localizedTitle
            // swiftlint:disable conditional_binding_cascade
            _ = self.feedRepository.feeds().then {
                if case let Result.success(feeds) = $0,
                    let feed = feeds.objectPassingTest({ return $0.title == feedTitle }) {
                    _ = feedsViewController.showFeed(feed, animated: false)
                    self.analytics.logEvent("QuickActionUsed", data: ["kind": "View Feed"])
                    completionHandler(true)
                } else {
                    completionHandler(false)
                }
            }
            // swiftlint:enable conditional_binding_cascade
        } else {
            completionHandler(false)
        }
    }

    // MARK: - Private

    private func createControllerHierarchy(_ feed: Feed? = nil, article: Article? = nil) {
        let feedAndArticle: (Feed, Article)?
        if let feed = feed, let article = article {
            feedAndArticle = (feed, article)
        } else {
            feedAndArticle = nil
        }
        self.bootstrapper.begin(feedAndArticle)
    }
}
