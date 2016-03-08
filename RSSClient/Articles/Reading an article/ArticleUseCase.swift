import UIKit
import Ra
import rNewsKit

public protocol ArticleUseCase {
    func articlesByAuthor(author: String, callback: DataStoreBackedArray<Article> -> Void)

    func readArticle(article: Article) -> String
    func userActivityForArticle(article: Article) -> NSUserActivity
    func toggleArticleRead(article: Article)
}

public final class DefaultArticleUseCase: NSObject, ArticleUseCase, Injectable {
    private let feedRepository: FeedRepository
    private let themeRepository: ThemeRepository
    private let bundle: NSBundle

    public init(feedRepository: FeedRepository,
                themeRepository: ThemeRepository,
                bundle: NSBundle) {
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        self.bundle = bundle
        super.init()
    }

    public required convenience init(injector: Injector) {
        self.init(
            feedRepository: injector.create(FeedRepository)!,
            themeRepository: injector.create(ThemeRepository)!,
            bundle: injector.create(NSBundle)!
        )
    }

    public func articlesByAuthor(author: String, callback: DataStoreBackedArray<Article> -> Void) {
        self.feedRepository.feeds { feeds in
            guard let initial = feeds.first?.articlesArray else { return callback(DataStoreBackedArray()) }

            let allArticles: DataStoreBackedArray<Article> = feeds[1..<feeds.count].reduce(initial) {
                return $0.combine($1.articlesArray)
            }

            callback(allArticles.filterWithPredicate(NSPredicate(format: "author = %@", author)))
        }
    }

    public func readArticle(article: Article) -> String {
        if !article.read { self.feedRepository.markArticle(article, asRead: true) }
        return self.htmlForArticle(article)
    }

    public func toggleArticleRead(article: Article) {
        self.feedRepository.markArticle(article, asRead: !article.read)
    }

    private lazy var userActivity: NSUserActivity = {
        let userActivity = NSUserActivity(activityType: "com.rachelbrindle.rssclient.article")
        if #available(iOS 9.0, *) {
            userActivity.requiredUserInfoKeys = ["feed", "article"]
            userActivity.eligibleForPublicIndexing = false
            userActivity.eligibleForSearch = true
        }
        userActivity.delegate = self
        return userActivity
    }()
    private weak var mostRecentArticle: Article?

    public func userActivityForArticle(article: Article) -> NSUserActivity {
        let title: String
        if let feedTitle = article.feed?.title {
            title = "\(feedTitle): \(article.title)"
        } else {
            title = article.title
        }
        self.mostRecentArticle = article
        self.userActivity.title = title
        self.userActivity.webpageURL = article.link
        if #available(iOS 9, *) {
            self.userActivity.keywords = Set([article.title, article.summary, article.author] + article.flags)
        }
        self.userActivity.becomeCurrent()
        self.userActivity.needsSave = true
        return self.userActivity
    }

    private lazy var prismJS: String = {
        if let prismURL = self.bundle.URLForResource("prism.js", withExtension: "html"),
            let prism = try? String(contentsOfURL: prismURL, encoding: NSUTF8StringEncoding) as String {
                return prism
        }
        return ""
    }()

    private func htmlForArticle(article: Article) -> String {
        let prefix: String
        let cssFileName = self.themeRepository.articleCSSFileName
        if let cssURL = self.bundle.URLForResource(cssFileName, withExtension: "css"),
            let css = try? String(contentsOfURL: cssURL, encoding: NSUTF8StringEncoding) {
                prefix = "<html><head>" +
                    "<style type=\"text/css\">\(css)</style>" +
                    "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                    "</head><body>"
        } else {
            prefix = "<html><body>"
        }

        let content = article.content.isEmpty ? article.summary : article.content

        let postfix = self.prismJS + "</body></html>"

        return prefix + "<h2>\(article.title)</h2>" + content + postfix
    }
}

extension DefaultArticleUseCase: NSUserActivityDelegate {
    public func userActivityWillSave(userActivity: NSUserActivity) {
        guard let article = self.mostRecentArticle else { return }
        userActivity.userInfo = [
            "feed": article.feed?.title ?? "",
            "article": article.identifier,
        ]
    }
}
