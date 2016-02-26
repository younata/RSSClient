import Foundation
import CoreData
import JavaScriptCore

@objc public protocol ArticleJSExport: JSExport {
    var title: String { get }
    var link: NSURL? { get }
    var summary: String { get }
    var author: String { get }
    var published: NSDate { get }
    var updatedAt: NSDate? { get }
    var identifier: String { get }
    var content: String { get }
    var estimatedReadingTime: Int { get }
    var read: Bool { get set }
    weak var feed: Feed? { get }
    var flags: [String] { get }
    var enclosures: [Enclosure] { get }
}

@objc public class Article: NSObject, ArticleJSExport {
    dynamic public internal(set) var title: String {
        willSet {
            if newValue != title {
                self.updated = true
            }
        }
    }
    dynamic public internal(set) var link: NSURL? {
        willSet {
            if newValue != link {
                self.updated = true
            }
        }
    }
    dynamic public internal(set) var summary: String {
        willSet {
            if newValue != summary {
                self.updated = true
            }
        }
    }
    dynamic public internal(set) var author: String {
        willSet {
            if newValue != author {
                self.updated = true
            }
        }
    }
    dynamic public internal(set) var published: NSDate {
        willSet {
            if newValue != published {
                self.updated = true
            }
        }
    }
    dynamic public internal(set) var updatedAt: NSDate? {
        willSet {
            if newValue != updatedAt {
                self.updated = true
            }
        }
    }
    dynamic public internal(set) var identifier: String {
        willSet {
            if newValue != identifier {
                self.updated = true
            }
        }
    }
    dynamic public internal(set) var content: String {
        willSet {
            if newValue != content {
                self.updated = true
            }
        }
    }
    dynamic public internal(set) var estimatedReadingTime: Int {
        willSet {
            if newValue != estimatedReadingTime {
                self.updated = true
            }
        }
    }
    dynamic public var read: Bool {
        willSet {
            if newValue != read {
                self.updated = true
            }
        }
    }
    weak dynamic public internal(set) var feed: Feed? {
        willSet {
            if newValue != feed && newValue?.isQueryFeed != true {
                self.updated = true
                if let oldValue = feed where oldValue.articlesArray.contains(self) {
                    oldValue.removeArticle(self)
                }
                if let nv = newValue where !nv.articlesArray.contains(self) {
                    nv.addArticle(self)
                }
            }
        }
    }
    dynamic public private(set) var flags: [String] = []

    @available(*, deprecated=1.0, renamed="enclosuresArray")
    dynamic public var enclosures: [Enclosure] { return Array(self.enclosuresArray) }

    public internal(set) var enclosuresArray: DataStoreBackedArray<Enclosure>

    internal private(set) var updated: Bool = false

    public override var hashValue: Int {
        if let id = articleID as? NSManagedObjectID {
            return id.URIRepresentation().hash
        } else if let id = articleID as? String {
            return id.hash
        }
        let nonNilHashValues = title.hashValue ^ summary.hashValue ^ author.hashValue ^
            published.hash ^ identifier.hashValue ^ content.hashValue & read.hashValue &
            estimatedReadingTime.hashValue
        let flagsHashValues = flags.reduce(0) { $0 ^ $1.hashValue }
        var possiblyNilHashValues = 0
        if let link = link {
            possiblyNilHashValues ^= link.hashValue
        }
        if let updatedAt = updatedAt {
            possiblyNilHashValues ^= updatedAt.hash
        }
        return nonNilHashValues ^ flagsHashValues ^ possiblyNilHashValues
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        guard let b = object as? Article else {
            return false
        }
        if let aID = self.articleID as? NSManagedObjectID, let bID = b.articleID as? NSManagedObjectID {
            return aID.URIRepresentation() == bID.URIRepresentation()
        } else if let aID = self.articleID as? String, let bID = b.articleID as? String {
            return aID == bID
        }
        return self.title == b.title && self.link == b.link && self.summary == b.summary &&
            self.author == b.author && self.published == b.published && self.updatedAt == b.updatedAt &&
            self.identifier == b.identifier && self.content == b.content && self.read == b.read &&
            self.flags == b.flags && self.estimatedReadingTime == b.estimatedReadingTime
    }

    public override var description: String {
        // swiftlint:disable line_length
        return "(Article: title: \(title), link: \(link), summary: \(summary), author: \(author), published: \(published), updated: \(updatedAt), identifier: \(identifier), content: \(content), read: \(read), estimatedReadingTime: \(estimatedReadingTime))\n"
        // swiftlint:enable line_length
    }

    // swiftlint:disable function_parameter_count
    public init(title: String, link: NSURL?, summary: String, author: String, published: NSDate,
        updatedAt: NSDate?, identifier: String, content: String, read: Bool, estimatedReadingTime: Int,
        feed: Feed?, flags: [String], enclosures: [Enclosure]) {
            self.title = title
            self.link = link
            self.summary = summary
            self.author = author
            self.published = published
            self.updatedAt = updatedAt
            self.identifier = identifier
            self.content = content
            self.read = read
            self.feed = feed
            self.flags = flags
            self.estimatedReadingTime = estimatedReadingTime
            self.enclosuresArray = DataStoreBackedArray(enclosures)
            super.init()
            for enclosure in self.enclosuresArray {
                enclosure.article = self
            }
            self.updated = false
    }
    // swiftlint:enable function_parameter_count

    internal private(set) var articleID: AnyObject? = nil

    internal init(coreDataArticle article: CoreDataArticle, feed: Feed?) {
        title = article.title ?? ""
        if let articleLink = article.link {
            link = NSURL(string: articleLink)
        } else {
            link = nil
        }

        summary = article.summary ?? ""
        author = article.author ?? ""
        published = article.published ?? NSDate()
        updatedAt = article.updatedAt
        identifier = article.objectID.URIRepresentation().absoluteString ?? ""
        content = article.content ?? ""
        read = article.read
        if let readingTime = article.estimatedReadingTime?.integerValue {
            estimatedReadingTime = readingTime
        } else {
            let readingTime = estimateReadingTime(article.content ?? article.summary ?? "")
            article.estimatedReadingTime = NSNumber(integer: readingTime)
            estimatedReadingTime = readingTime
        }
        self.feed = feed
        self.flags = article.flags
        self.enclosuresArray = DataStoreBackedArray()
        super.init()
        self.enclosuresArray = DataStoreBackedArray(entityName: "Enclosure",
            predicate: NSPredicate(format: "article == %@", article),
            managedObjectContext: article.managedObjectContext!,
            conversionFunction: {
                return Enclosure(coreDataEnclosure: $0 as! CoreDataEnclosure, article: self)
        })

        self.articleID = article.objectID

        self.updated = false
    }

    internal init(realmArticle article: RealmArticle, feed: Feed?) {
        title = article.title ?? ""
        link = NSURL(string: article.link)

        summary = article.summary ?? ""
        author = article.author ?? ""
        published = article.published ?? NSDate()
        updatedAt = article.updatedAt
        identifier = article.id
        content = article.content ?? ""
        read = article.read
        estimatedReadingTime = article.estimatedReadingTime
        self.feed = feed
        self.flags = article.flags.map { $0.string }
        self.enclosuresArray = DataStoreBackedArray()
        super.init()
        let enclosures = article.enclosures.map { Enclosure(realmEnclosure: $0, article: self) }
        if let realm = article.realm {
            self.enclosuresArray = DataStoreBackedArray(realmDataType: RealmEnclosure.self,
                predicate: NSPredicate(format: "article.id == %@", article.id),
                realm: realm,
                conversionFunction: { Enclosure(realmEnclosure: $0 as! RealmEnclosure, article: self) } )
        } else {
            self.enclosuresArray = DataStoreBackedArray(enclosures)
        }
        self.articleID = article.id
        self.updated = false
    }

    public func addFlag(flag: String) {
        if !self.flags.contains(flag) {
            self.flags.append(flag)
            self.updated = true
        }
    }

    public func removeFlag(flag: String) {
        if self.flags.contains(flag) {
            self.flags = self.flags.filter { $0 != flag }
            self.updated = true
        }
    }

    public func addEnclosure(enclosure: Enclosure) {
        if !self.enclosuresArray.contains(enclosure) {
            self.enclosuresArray.append(enclosure)
            if let otherArticle = enclosure.article {
                otherArticle.removeEnclosure(enclosure)
            }
            enclosure.article = self
            self.updated = true
        }
    }

    public func removeEnclosure(enclosure: Enclosure) {
        if self.enclosuresArray.contains(enclosure) {
            self.enclosuresArray.remove(enclosure)
            if enclosure.article == self {
                enclosure.article = nil
            }
            self.updated = true
        }
    }
}