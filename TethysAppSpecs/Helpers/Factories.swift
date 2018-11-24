import Tethys
import TethysKit

//func SettingsViewControllerFactory() -> SettingsViewController {
//
//}

// View Controllers

func splitViewControllerFactory(themeRepository: ThemeRepository = themeRepositoryFactory()) -> SplitViewController {
    return SplitViewController(themeRepository: themeRepository)
}

func findFeedViewControllerFactory(
    importUseCase: ImportUseCase = FakeImportUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    analytics: Analytics = FakeAnalytics()
    ) -> FindFeedViewController {
    return FindFeedViewController(importUseCase: importUseCase, themeRepository: themeRepository, analytics: analytics)
}

func feedViewControllerFactory(
    feedRepository: DatabaseUseCase = FakeDatabaseUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    tagEditorViewController: @escaping () -> TagEditorViewController = { tagEditorViewControllerFactory() }
    ) -> FeedViewController {
    return FeedViewController(
        feedRepository: feedRepository,
        themeRepository: themeRepository,
        tagEditorViewController: tagEditorViewController
    )
}

func tagEditorViewControllerFactory(
    feedRepository: DatabaseUseCase = FakeDatabaseUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory()
    ) -> TagEditorViewController {
    return TagEditorViewController(
        feedRepository: feedRepository,
        themeRepository: themeRepository
    )
}

func feedsTableViewControllerFactory(
    feedRepository: DatabaseUseCase = FakeDatabaseUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    settingsRepository: SettingsRepository = settingsRepositoryFactory(),
    mainQueue: FakeOperationQueue = FakeOperationQueue(),
    findFeedViewController: @escaping () -> FindFeedViewController = { findFeedViewControllerFactory() },
    feedViewController: @escaping () -> FeedViewController = { feedViewControllerFactory() },
    settingsViewController: @escaping () -> SettingsViewController = { settingsViewControllerFactory() },
    articleListController: @escaping () -> ArticleListController = { articleListControllerFactory() }
    ) -> FeedsTableViewController {
    return FeedsTableViewController(
        feedRepository: feedRepository,
        themeRepository: themeRepository,
        settingsRepository: SettingsRepository(userDefaults: nil),
        mainQueue: FakeOperationQueue(),
        findFeedViewController: findFeedViewController,
        feedViewController: feedViewController,
        settingsViewController: settingsViewController,
        articleListController: articleListController
    )
}

func articleViewControllerFactory(
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    articleUseCase: ArticleUseCase = FakeArticleUseCase(),
    htmlViewController: @escaping () -> HTMLViewController = { htmlViewControllerFactory() },
    articleListController: @escaping () -> ArticleListController = { articleListControllerFactory() }
    ) -> ArticleViewController {
    return ArticleViewController(
        themeRepository: themeRepository,
        articleUseCase: articleUseCase,
        htmlViewController: htmlViewController,
        articleListController: articleListController
    )
}

func htmlViewControllerFactory(themeRepository: ThemeRepository = themeRepositoryFactory()) -> HTMLViewController {
    return HTMLViewController(
        themeRepository: themeRepository
    )
}

func articleListControllerFactory(
    mainQueue: FakeOperationQueue = FakeOperationQueue(),
    articleService: ArticleService = FakeArticleService(),
    feedRepository: DatabaseUseCase = FakeDatabaseUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    settingsRepository: SettingsRepository = settingsRepositoryFactory(),
    articleCellController: ArticleCellController = FakeArticleCellController(),
    articleViewController: @escaping () -> ArticleViewController = { articleViewControllerFactory() },
    generateBookViewController: @escaping () -> GenerateBookViewController = { generateBookViewControllerFactory() }
    ) -> ArticleListController {
    return ArticleListController(
        mainQueue: mainQueue,
        articleService: articleService,
        feedRepository: feedRepository,
        themeRepository: themeRepository,
        settingsRepository: settingsRepository,
        articleCellController: articleCellController,
        articleViewController: articleViewController,
        generateBookViewController: generateBookViewController
    )
}

func migrationViewControllerFactory(
    migrationUseCase: MigrationUseCase = FakeMigrationUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    mainQueue: FakeOperationQueue = FakeOperationQueue()
    ) -> MigrationViewController {
    return MigrationViewController(
        migrationUseCase: migrationUseCase,
        themeRepository: themeRepository,
        mainQueue: mainQueue
    )
}

func generateBookViewControllerFactory(
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    generateBookUseCase: GenerateBookUseCase = FakeGenerateBookUseCase(),
    chapterOrganizer: ChapterOrganizerController = chapterOrganizerControllerFactory()
    ) -> GenerateBookViewController {
    return GenerateBookViewController(
        themeRepository: themeRepository,
        generateBookUseCase: generateBookUseCase,
        chapterOrganizer: chapterOrganizer
    )
}

func chapterOrganizerControllerFactory(
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    settingsRepository: SettingsRepository = settingsRepositoryFactory(),
    articleCellController: ArticleCellController = FakeArticleCellController(),
    articleListController: @escaping () -> ArticleListController = { articleListControllerFactory() }
    ) -> ChapterOrganizerController {
    return ChapterOrganizerController(
        themeRepository: themeRepository,
        settingsRepository: settingsRepository,
        articleCellController: articleCellController,
        articleListController: articleListController
    )
}

func settingsViewControllerFactory(
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    settingsRepository: SettingsRepository = settingsRepositoryFactory(),
    quickActionRepository: QuickActionRepository = FakeQuickActionRepository(),
    databaseUseCase: DatabaseUseCase = FakeDatabaseUseCase(),
    opmlService: OPMLService = FakeOPMLService(),
    mainQueue: FakeOperationQueue = FakeOperationQueue(),
    documentationViewController: @escaping () -> DocumentationViewController = { documentationViewControllerFactory() }
    ) -> SettingsViewController {
    return SettingsViewController(
        themeRepository: themeRepository,
        settingsRepository: settingsRepository,
        quickActionRepository: quickActionRepository,
        databaseUseCase: databaseUseCase,
        opmlService: opmlService,
        mainQueue: mainQueue,
        documentationViewController: documentationViewController
    )
}

func documentationViewControllerFactory(
    documentationUseCase: DocumentationUseCase = FakeDocumentationUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    htmlViewController: HTMLViewController = htmlViewControllerFactory()
    ) -> DocumentationViewController {
    return DocumentationViewController(
        documentationUseCase: documentationUseCase,
        themeRepository: themeRepository,
        htmlViewController: htmlViewController
    )
}

// Workflows

func bootstrapWorkFlowFactory(
    window: UIWindow = UIWindow(),
    feedRepository: DatabaseUseCase = FakeDatabaseUseCase(),
    migrationUseCase: MigrationUseCase = FakeMigrationUseCase(),
    splitViewController: SplitViewController = splitViewControllerFactory(),
    migrationViewController: @escaping () -> MigrationViewController = { migrationViewControllerFactory() },
    feedsTableViewController: @escaping () -> FeedsTableViewController = { feedsTableViewControllerFactory() },
    articleViewController: @escaping () -> ArticleViewController = { articleViewControllerFactory() }
    ) -> BootstrapWorkFlow {
    return BootstrapWorkFlow(
        window: window,
        feedRepository: feedRepository,
        migrationUseCase: migrationUseCase,
        splitViewController: splitViewController,
        migrationViewController: migrationViewController,
        feedsTableViewController: feedsTableViewController,
        articleViewController: articleViewController
    )
}

// Repositories

func themeRepositoryFactory(userDefaults: UserDefaults? = nil) -> ThemeRepository {
    return ThemeRepository(userDefaults: userDefaults)
}

func settingsRepositoryFactory(userDefaults: UserDefaults? = nil) -> SettingsRepository {
    return SettingsRepository(userDefaults: userDefaults)
}
