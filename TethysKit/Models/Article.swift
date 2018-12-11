import Foundation

public final class Article: CustomStringConvertible, Hashable {
    public internal(set) var title: String
    public internal(set) var link: URL
    public internal(set) var summary: String

    public internal(set) var authors: [Author]
    @available(*, deprecated, message: "Use a service to get the article date")
    public internal(set) var published: Date
    @available(*, deprecated, message: "Use a service to get the article date")
    public internal(set) var updatedAt: Date?
    public internal(set) var identifier: String
    public internal(set) var content: String
    public internal(set) var read: Bool

    public var hashValue: Int {
        if let id = articleID as? String {
            return id.hash
        }
        let authorsHashValue = authors.reduce(0) { $0 ^ $1.hashValue }
        return title.hashValue ^ summary.hashValue ^ authorsHashValue ^
            published.hashValue ^ identifier.hashValue ^ content.hashValue ^ read.hashValue ^
            link.hashValue
    }

    public var description: String {
        // swiftlint:disable line_length
        return "(Article: title: \(title), link: \(link), summary: \(summary), author: \(authors), published: \(published), updated: \(String(describing: updatedAt)), identifier: \(identifier), content: \(content), read: \(read))\n"
        // swiftlint:enable line_length
    }

    public init(title: String, link: URL, summary: String, authors: [Author], published: Date,
                updatedAt: Date?, identifier: String, content: String, read: Bool) {
        self.title = title
        self.link = link
        self.summary = summary
        self.authors = authors
        self.published = published
        self.updatedAt = updatedAt
        self.identifier = identifier
        self.content = content
        self.read = read
    }

    internal private(set) var articleID: AnyObject?

    internal init(realmArticle article: RealmArticle) {
        title = article.title ?? ""
        link = URL(string: article.link)!
        summary = article.summary ?? ""

        self.authors = article.authors.map(Author.init)
        published = article.published
        updatedAt = article.updatedAt
        identifier = article.id
        content = article.content ?? ""
        read = article.read
        self.articleID = article.id as AnyObject?
    }
}

public func == (lhs: Article, rhs: Article) -> Bool {
    if let aID = lhs.articleID as? String, let bID = rhs.articleID as? String {
        return aID == bID
    }
    return lhs.title == rhs.title && lhs.link == rhs.link && lhs.summary == rhs.summary &&
        lhs.authors == rhs.authors && lhs.published == rhs.published && lhs.updatedAt == rhs.updatedAt &&
        lhs.identifier == rhs.identifier && lhs.content == rhs.content && lhs.read == rhs.read
}
