import Quick
import Nimble
import CoreData
import RealmSwift
@testable import rNewsKit

class EnclosureSpec: QuickSpec {
    override func spec() {
        var subject: Enclosure? = nil
        var realm: Realm!

        beforeEach {
            let realmConf = Realm.Configuration(inMemoryIdentifier: "EnclosureSpec")
            realm = try! Realm(configuration: realmConf)
            try! realm.write {
                realm.deleteAll()
            }

            subject = Enclosure(url: NSURL(string: "http://example.com")!, kind: "", article: nil)

            expect(subject).toNot(beNil())
        }

        describe("Equatable") {
            it("should report two enclosures created with a coredataenclosure with the same enclosureID as equal") {
                let ctx = managedObjectContext()
                let a = createEnclosure(ctx)
                let b = createEnclosure(ctx)

                expect(Enclosure(coreDataEnclosure: a, article: nil)).toNot(equal(Enclosure(coreDataEnclosure: b, article: nil)))
                expect(Enclosure(coreDataEnclosure: a, article: nil)).to(equal(Enclosure(coreDataEnclosure: a, article: nil)))
            }

            it("should report two enclosures created with a realmenclosure with the same enclosureID as equal") {
                let a = RealmEnclosure()
                let b = RealmEnclosure()

                expect(Enclosure(realmEnclosure: a, article: nil)).toNot(equal(Enclosure(realmEnclosure: b, article: nil)))
                expect(Enclosure(realmEnclosure: a, article: nil)).to(equal(Enclosure(realmEnclosure: a, article: nil)))
            }

            it("should report two enclosures not created with coredataenclosures with the same property equality as equal") {
                let a = Enclosure(url: NSURL(string: "http://example.com")!, kind: "", article: nil)
                let b = Enclosure(url: NSURL(string: "http://example.com")!, kind: "text/text", article: nil)
                let c = Enclosure(url: NSURL(string: "http://example.com")!, kind: "", article: nil)

                expect(a).toNot(equal(b))
                expect(a).to(equal(c))
            }
        }

        describe("changing article") {
            var article: Article! = nil

            beforeEach {
                article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])

                subject?.article = article
            }

            it("should add subject to the article's enclosures list") {
                if let sub = subject {
                    expect(article.enclosuresArray).to(contain(sub))
                }
            }

            it("should remove subject from the article's enclosures list when that gets unset") {
                subject?.article = nil
                if let sub = subject {
                    expect(article.enclosuresArray).toNot(contain(sub))
                }
            }

            it("should remove from the old and add to the new when changing articles") {
                let newArticle = Article(title: "bleh", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
                subject?.article = newArticle
                if let sub = subject {
                    expect(article.enclosuresArray).toNot(contain(sub))
                    expect(newArticle.enclosuresArray).to(contain(sub))
                }
            }
        }

        describe("the updated flag") {
            it("should start negative") {
                expect(subject?.updated) == false
            }

            describe("properties that change updated to positive") {
                it("url") {
                    subject?.url = NSURL(string: "http://example.com")!
                    expect(subject?.updated) == false
                    subject?.url = NSURL(string: "http://example.com/changed")!
                    expect(subject?.updated) == true
                }

                it("kind") {
                    subject?.kind = ""
                    expect(subject?.updated) == false
                    subject?.kind = "hello there"
                    expect(subject?.updated) == true
                }

                it("article") {
                    subject?.article = nil
                    expect(subject?.updated) == false
                    let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
                    subject?.article = article
                    expect(subject?.updated) == true
                }
            }
        }
    }
}
