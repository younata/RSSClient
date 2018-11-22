import Quick
import Nimble
import RealmSwift
@testable import TethysKit


final class RealmArticleServiceSpec: QuickSpec {
    override func spec() {
        let realmConf = Realm.Configuration(inMemoryIdentifier: "RealmArticleServiceSpec")
        var realm: Realm!

        var mainQueue: FakeOperationQueue!
        var workQueue: FakeOperationQueue!

        var subject: RealmArticleService!

        beforeEach {
            let realmProvider = DefaultRealmProvider(configuration: realmConf)
            realm = realmProvider.realm()
            try! realm.write {
                realm.deleteAll()
            }

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            workQueue = FakeOperationQueue()
            workQueue.runSynchronously = true

            subject = RealmArticleService(
                realmProvider: realmProvider,
                mainQueue: mainQueue,
                workQueue: workQueue
            )
        }

        describe("feed(of:)") {
            it("returns the feed of the article") {
                realm.beginWrite()
                let realmFeed = RealmFeed()
                realmFeed.title = "Feed1"
                realmFeed.url = "https://example.com/feed/feed1"

                let realmArticle = RealmArticle()
                realmArticle.title = "article"
                realmArticle.link = "https://example.com/article/article1"
                realmArticle.feed = realmFeed

                realm.add(realmFeed)
                realm.add(realmArticle)

                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }

                let article = Article(realmArticle: realmArticle, feed: nil)

                expect(subject.feed(of: article).value?.value).to(equal(Feed(realmFeed: realmFeed)))
            }

            it("returns a database error if no feed is found") {
                realm.beginWrite()

                let realmArticle = RealmArticle()
                realmArticle.title = "article"
                realmArticle.link = "https://example.com/article/article1"
                realm.add(realmArticle)

                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }

                let article = Article(realmArticle: realmArticle, feed: nil)

                expect(subject.feed(of: article).value?.error).to(equal(TethysError.database(.entryNotFound)))
            }
        }

        describe("authors(of:)") {
            context("with one author") {
                it("returns the author's name") {
                    let article = articleFactory(authors: [
                        Author("An Author")
                        ])
                    expect(subject.authors(of: article)).to(equal("An Author"))
                }

                it("returns the author's name and email, if present") {
                    let article = articleFactory(authors: [
                        Author(name: "An Author", email: URL(string: "mailto:an@author.com"))
                        ])
                    expect(subject.authors(of: article)).to(equal("An Author <an@author.com>"))
                }
            }

            context("with two authors") {
                it("returns both authors names") {
                    let article = articleFactory(authors: [
                        Author("An Author"),
                        Author("Other Author", email: URL(string: "mailto:other@author.com"))
                    ])

                    expect(subject.authors(of: article)).to(equal("An Author, Other Author <other@author.com>"))
                }
            }

            context("with more authors") {
                it("returns them combined with commas") {
                    let article = articleFactory(authors: [
                        Author("An Author"),
                        Author("Other Author", email: URL(string: "mailto:other@author.com")),
                        Author("Third Author", email: URL(string: "mailto:third@other.com"))
                    ])

                    expect(subject.authors(of: article)).to(equal(
                        "An Author, Other Author <other@author.com>, Third Author <third@other.com>"
                    ))
                }
            }
        }

        describe("date(for:)") {
            var realmArticle: RealmArticle!

            let publishedDate = Date(timeIntervalSinceReferenceDate: 10)
            let updatedDate = Date(timeIntervalSinceReferenceDate: 20)

            beforeEach {
                realm.beginWrite()

                realmArticle = RealmArticle()
                realmArticle.link = "https://example.com/article/article1"
                realmArticle.published = publishedDate

                realm.add(realmArticle)

                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }
            }

            it("returns the date the article was last updated, if available") {
                let article = Article(realmArticle: realmArticle, feed: nil)

                realm.beginWrite()
                realmArticle.updatedAt = updatedDate

                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }

                expect(subject.date(for: article)).to(equal(updatedDate))
            }

            it("returns the date the article was published, if last updated is unavailable") {
                let article = Article(realmArticle: realmArticle, feed: nil)

                expect(subject.date(for: article)).to(equal(publishedDate))
            }
        }

        describe("estimatedReadingTime(of:)") {
            var realmArticle: RealmArticle!

            beforeEach {
                realm.beginWrite()

                realmArticle = RealmArticle()
                realmArticle.link = "https://example.com/article/article1"

                realm.add(realmArticle)

                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }
            }

            context("if this was previously calculated") {
                beforeEach {
                    realm.beginWrite()
                    realmArticle.estimatedReadingTime = 300

                    do {
                        try realm.commitWrite()
                    } catch let exception {
                        dump(exception)
                        fail("Error writing to realm: \(exception)")
                    }
                }

                it("returns the estimated reading time in seconds") {
                    let article = Article(realmArticle: realmArticle, feed: nil)
                    expect(subject.estimatedReadingTime(of: article)).to(beCloseTo(300))
                }
            }

            context("if this wasn't previously calculated") {
                context("and the articla has content") {
                    beforeEach {
                        realm.beginWrite()
                        let body = (0..<450).map { _ in "foo " }.reduce("", +)
                        realmArticle.content = "<html><body>" + body + "</body></html>"

                        do {
                            try realm.commitWrite()
                        } catch let exception {
                            dump(exception)
                            fail("Error writing to realm: \(exception)")
                        }
                    }

                    it("returns the estimated reading time, calculated assuming 200 wpm reading speeds") {
                        let article = Article(realmArticle: realmArticle, feed: nil)
                        expect(subject.estimatedReadingTime(of: article)).to(beCloseTo(135))
                    }

                    it("stores the data so that we don't have to calculate it again later") {
                        _ = subject.estimatedReadingTime(of: Article(realmArticle: realmArticle, feed: nil))

                        expect(realmArticle.estimatedReadingTime).to(beCloseTo(135))
                    }
                }

                context("and the article has only a summary") {
                    beforeEach {
                        realm.beginWrite()
                        realmArticle.content = ""
                        let body = (0..<250).map { _ in "foo " }.reduce("", +)
                        realmArticle.summary = "<html><body>" + body + "</body></html>"

                        do {
                            try realm.commitWrite()
                        } catch let exception {
                            dump(exception)
                            fail("Error writing to realm: \(exception)")
                        }
                    }

                    it("returns the estimated reading time, calculated assuming 200 wpm reading speeds") {
                        let article = Article(realmArticle: realmArticle, feed: nil)
                        expect(subject.estimatedReadingTime(of: article)).to(beCloseTo(75))
                    }

                    it("stores the data for later use") {
                        _ = subject.estimatedReadingTime(of: Article(realmArticle: realmArticle, feed: nil))
                        expect(realmArticle.estimatedReadingTime).to(beCloseTo(75))
                    }
                }
            }
        }
    }
}
