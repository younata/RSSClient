import Muon
import Sinope

protocol ImportableFeed {
    var title: String { get }
    var link: NSURL { get }
    var description: String { get }
    var imageURL: NSURL? { get }
    var lastUpdated: NSDate { get }
    var importableArticles: [ImportableArticle] { get }
}

protocol ImportableArticle {
    var title: String { get }
    var url: NSURL { get }
    var summary: String { get }
    var content: String { get }
    var published: NSDate { get }
    var updated: NSDate? { get }
    var importableAuthors: [ImportableAuthor] { get }
}

protocol ImportableAuthor {
    var name: String { get }
    var email: NSURL? { get }
}
// MARK: Muon conformance
extension Muon.Feed: ImportableFeed {
    var importableArticles: [ImportableArticle] {
        return self.articles.map { $0 as ImportableArticle }
    }

    var lastUpdated: NSDate {
        return NSDate()
    }
}
extension Muon.Article: ImportableArticle {
    var url: NSURL {
        return self.link
    }

    var summary: String {
        return self.description
    }

    var importableAuthors: [ImportableAuthor] {
        return self.authors.map { $0 as ImportableAuthor }
    }
}
extension Muon.Author: ImportableAuthor {}

// MARK: Sinope conformance
extension Sinope.Feed: ImportableFeed {
    var link: NSURL { return self.url }
    var description: String { return self.summary }
    var imageURL: NSURL? { return self.imageUrl }

    var importableArticles: [ImportableArticle] {
        return self.articles.map { $0 as ImportableArticle }
    }
}

extension Sinope.Article: ImportableArticle {
    var importableAuthors: [ImportableAuthor] {
        return self.authors.map { $0 as ImportableAuthor }
    }
}

extension Sinope.Author: ImportableAuthor {}
