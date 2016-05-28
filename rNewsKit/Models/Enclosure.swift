import Foundation
import CoreData
import JavaScriptCore

@objc public protocol EnclosureJSExport: JSExport {
    var url: NSURL { get set }
    var kind: String { get set }
    weak var article: Article? { get set }
}

@objc public final class Enclosure: NSObject, EnclosureJSExport {
    dynamic public var url: NSURL {
        willSet {
            if newValue != url {
                self.updated = true
            }
        }
    }
    dynamic public var kind: String {
        willSet {
            if newValue != kind {
                self.updated = true
            }
        }
    }
    weak dynamic public var article: Article? {
        didSet {
            if article != oldValue {
                self.updated = true
                if let oldValue = oldValue where oldValue.enclosuresArray.contains(self) {
                    oldValue.removeEnclosure(self)
                }
                if let nv = article where !nv.enclosuresArray.contains(self) {
                    nv.addEnclosure(self)
                }
            }
        }
    }

    public private(set) var updated: Bool = false

    public override func isEqual(object: AnyObject?) -> Bool {
        guard let b = object as? Enclosure else {
            return false
        }
        if let aEID = self.enclosureID as? NSManagedObjectID, bEID = b.enclosureID as? NSManagedObjectID {
            return aEID.URIRepresentation() == bEID.URIRepresentation()
        } else if let aEID = self.enclosureID as? String, bEID = b.enclosureID as? String {
            return aEID == bEID
        }
        return self.url == b.url && self.kind == b.kind
    }

    public init(url: NSURL, kind: String, article: Article?) {
        self.url = url
        self.kind = kind
        self.article = article
    }

    public private(set) var enclosureID: AnyObject? = nil

    internal init(coreDataEnclosure enclosure: CoreDataEnclosure, article: Article?) {
        url = NSURL(string: enclosure.url ?? "") ?? NSURL()
        kind = enclosure.kind ?? ""
        self.article = article
        enclosureID = enclosure.objectID
    }

    internal init(realmEnclosure enclosure: RealmEnclosure, article: Article?) {
        url = NSURL(string: enclosure.url) ?? NSURL()
        kind = enclosure.kind ?? ""
        self.article = article
        enclosureID = enclosure.id
    }
}
