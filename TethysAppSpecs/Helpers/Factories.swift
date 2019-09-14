import Tethys
import TethysKit
import AuthenticationServices

func splitViewControllerFactory() -> SplitViewController {
    return SplitViewController()
}

func findFeedViewControllerFactory(
    importUseCase: ImportUseCase = FakeImportUseCase(),
    analytics: Analytics = FakeAnalytics(),
    notificationCenter: NotificationCenter = NotificationCenter()
    ) -> FindFeedViewController {
    return FindFeedViewController(
        importUseCase: importUseCase,
        analytics: analytics,
        notificationCenter: notificationCenter
    )
}

func feedViewControllerFactory(
    feed: Feed = feedFactory(),
    feedService: FeedService = FakeFeedService(),
    tagEditorViewController: @escaping () -> TagEditorViewController = { tagEditorViewControllerFactory() }
    ) -> FeedViewController {
    return FeedViewController(
        feed: feed,
        feedService: feedService,
        tagEditorViewController: tagEditorViewController
    )
}

func tagEditorViewControllerFactory(
    feedService: FeedService = FakeFeedService()
    ) -> TagEditorViewController {
    return TagEditorViewController(
        feedService: feedService
    )
}

func feedsTableViewControllerFactory(
    feedService: FeedService = FakeFeedService(),
    settingsRepository: SettingsRepository = settingsRepositoryFactory(),
    mainQueue: FakeOperationQueue = FakeOperationQueue(),
    notificationCenter: NotificationCenter = NotificationCenter(),
    findFeedViewController: @escaping () -> FindFeedViewController = { findFeedViewControllerFactory() },
    feedViewController: @escaping (Feed) -> FeedViewController = { feed in feedViewControllerFactory(feed: feed) },
    settingsViewController: @escaping () -> SettingsViewController = { settingsViewControllerFactory() },
    articleListController: @escaping (Feed) -> ArticleListController = { feed in articleListControllerFactory(feed: feed) }
    ) -> FeedListController {
    return FeedListController(
        feedService: feedService,
        settingsRepository: SettingsRepository(userDefaults: nil),
        mainQueue: mainQueue,
        notificationCenter: notificationCenter,
        findFeedViewController: findFeedViewController,
        feedViewController: feedViewController,
        settingsViewController: settingsViewController,
        articleListController: articleListController
    )
}

func articleViewControllerFactory(
    article: Article = articleFactory(),
    articleUseCase: ArticleUseCase = FakeArticleUseCase(),
    htmlViewController: @escaping () -> HTMLViewController = { htmlViewControllerFactory() }
    ) -> ArticleViewController {
    return ArticleViewController(
        article: article,
        articleUseCase: articleUseCase,
        htmlViewController: htmlViewController
    )
}

func htmlViewControllerFactory() -> HTMLViewController {
    return HTMLViewController()
}

func articleListControllerFactory(
    feed: Feed = feedFactory(),
    feedService: FeedService = FakeFeedService(),
    articleService: ArticleService = FakeArticleService(),
    notificationCenter: NotificationCenter = NotificationCenter(),
    articleCellController: ArticleCellController = FakeArticleCellController(),
    articleViewController: @escaping (Article) -> ArticleViewController = { article in articleViewControllerFactory(article: article) }
    ) -> ArticleListController {
    return ArticleListController(
        feed: feed,
        feedService: feedService,
        articleService: articleService,
        notificationCenter: notificationCenter,
        articleCellController: articleCellController,
        articleViewController: articleViewController
    )
}

func settingsViewControllerFactory(
    settingsRepository: SettingsRepository = settingsRepositoryFactory(),
    opmlService: OPMLService = FakeOPMLService(),
    mainQueue: FakeOperationQueue = FakeOperationQueue(),
    accountService: AccountService = FakeAccountService(),
    messenger: Messenger = FakeMessenger(),
    loginController: LoginController = FakeLoginController(),
    documentationViewController: @escaping (Documentation) -> DocumentationViewController = { docs in documentationViewControllerFactory(documentation: docs) }
    ) -> SettingsViewController {
    return SettingsViewController(
        settingsRepository: settingsRepository,
        opmlService: opmlService,
        mainQueue: mainQueue,
        accountService: accountService,
        messenger: messenger,
        loginController: loginController,
        documentationViewController: documentationViewController
    )
}

func documentationViewControllerFactory(
    documentation: Documentation = .libraries,
    htmlViewController: HTMLViewController = htmlViewControllerFactory()
    ) -> DocumentationViewController {
    return DocumentationViewController(
        documentation: documentation,
        htmlViewController: htmlViewController
    )
}

func blankViewControllerFactory() -> BlankViewController {
    return BlankViewController()
}

// Workflows

func bootstrapWorkFlowFactory(
    window: UIWindow = UIWindow(),
    splitViewController: SplitViewController = splitViewControllerFactory(),
    feedsTableViewController: @escaping () -> FeedListController = { feedsTableViewControllerFactory() },
    blankViewController: @escaping () -> BlankViewController = { blankViewControllerFactory() }
    ) -> BootstrapWorkFlow {
    return BootstrapWorkFlow(
        window: window,
        splitViewController: splitViewController,
        feedsTableViewController: feedsTableViewController,
        blankViewController: blankViewController
    )
}

// Repositories

func settingsRepositoryFactory(userDefaults: UserDefaults? = nil) -> SettingsRepository {
    return SettingsRepository(userDefaults: userDefaults)
}
