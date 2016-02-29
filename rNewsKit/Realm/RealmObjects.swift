import RealmSwift
import Foundation
#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

class RealmString: Object {
    dynamic var string = ""
}

class RealmFeed: Object {
    dynamic var title: String?
    dynamic var url: String?
    dynamic var summary: String?
    dynamic var query: String?
    let tags = List<RealmString>()
    dynamic var waitPeriod: Int = 0
    dynamic var remainingWait: Int = 0
    var articles: [RealmArticle] {
        return linkingObjects(RealmArticle.self, forProperty: "feed").sort {
            let aDate: NSDate
            let bDate: NSDate
            if let date = $0.updatedAt {
                aDate = date
            } else {
                aDate = $0.published
            }
            if let date = $1.updatedAt {
                bDate = date
            } else {
                bDate = $0.published
            }
            return aDate.timeIntervalSince1970 > bDate.timeIntervalSince1970
        }
    }
    dynamic var imageData: NSData?

    dynamic var id: String = NSUUID().UUIDString
    override static func primaryKey() -> String? {
        return "id"
    }
}

class RealmArticle: Object {
    dynamic var title: String?
    dynamic var link = ""
    dynamic var summary: String?
    dynamic var author: String?
    dynamic var published = NSDate(timeIntervalSinceNow: 0)
    dynamic var updatedAt: NSDate?
    dynamic var identifier: String?
    dynamic var content: String?
    dynamic var read = false
    dynamic var estimatedReadingTime = 0
    let flags = List<RealmString>()
    dynamic var feed: RealmFeed?
    var enclosures: [RealmEnclosure] {
        return linkingObjects(RealmEnclosure.self, forProperty: "article")
    }
    let relatedArticles = List<RealmArticle>()

    dynamic var id: String = NSUUID().UUIDString
    override static func primaryKey() -> String? {
        return "id"
    }
}

class RealmEnclosure: Object {
    dynamic var url = "https://example.com/enclosure"
    dynamic var kind: String?
    dynamic var data: NSData?
    dynamic var article: RealmArticle?

    dynamic var id: String = NSUUID().UUIDString
    override static func primaryKey() -> String? {
        return "id"
    }
}
