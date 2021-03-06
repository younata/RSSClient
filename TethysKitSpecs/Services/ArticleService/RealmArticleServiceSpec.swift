import Quick
import Nimble
import Result
import CBGPromise
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

        describe("mark(article:asRead:)") {
            var future: Future<Result<Article, TethysError>>!
            context("when the article is already at the desired read state") {
                let article = articleFactory(read: true)

                beforeEach {
                    future = subject.mark(article: article, asRead: true)
                }

                it("immediately resolves the future with the article") {
                    expect(future.value?.value).to(equal(article))
                }
            }

            context("when the article is not already at the desired read state") {
                var realmArticle: RealmArticle!

                beforeEach {
                    realm.beginWrite()

                    realmArticle = RealmArticle()
                    realmArticle.title = "article"
                    realmArticle.link = "https://example.com/article/article1"
                    realmArticle.read = false

                    realm.add(realmArticle)

                    do {
                        try realm.commitWrite()
                    } catch let exception {
                        dump(exception)
                        fail("Error writing to realm: \(exception)")
                    }

                    future = subject.mark(article: Article(realmArticle: realmArticle), asRead: true)
                }

                it("marks the realm representation of the article as read") {
                    expect(realmArticle.read).to(beTrue())
                }

                it("resolves the future with a read version of the article") {
                    expect(future.value?.value).to(equal(Article(realmArticle: realmArticle)))
                }
            }
        }

        describe("remove(article:)") {
            var future: Future<Result<Void, TethysError>>!
            var realmArticle: RealmArticle!
            var articleIdentifier: String!

            beforeEach {
                realm.beginWrite()

                realmArticle = RealmArticle()
                realmArticle.title = "article"
                realmArticle.link = "https://example.com/article/article1"

                realm.add(realmArticle)

                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }

                articleIdentifier = realmArticle.id
            }

            context("and the article is associated with a feed") {
                var realmFeed: RealmFeed!

                beforeEach {
                    realm.beginWrite()

                    realmFeed = RealmFeed()

                    realmArticle.feed = realmFeed

                    realm.add(realmFeed)

                    do {
                        try realm.commitWrite()
                    } catch let exception {
                        dump(exception)
                        fail("Error writing to realm: \(exception)")
                    }

                    future = subject.remove(article: Article(realmArticle: realmArticle))
                }

                it("removes the article from the realmFeed's list of articles") {
                    expect(realmFeed.articles).to(haveCount(0))
                }

                it("removes the article from the database") {
                    expect(realm.object(ofType: RealmArticle.self, forPrimaryKey: articleIdentifier)).to(beNil())
                }

                it("resolves the future with success") {
                    expect(future.value?.value).to(beVoid())
                }
            }

            context("and the article is not associated with a feed") {
                beforeEach {
                    future = subject.remove(article: Article(realmArticle: realmArticle))
                }

                it("removes the article from the database") {
                    expect(realm.object(ofType: RealmArticle.self, forPrimaryKey: articleIdentifier)).to(beNil())
                }

                it("resolves the future with success") {
                    expect(future.value?.value).to(beVoid())
                }
            }
        }

        describe("authors(of:)") {
            articleService_authors_returnsTheAuthors { subject }
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
                let article = Article(realmArticle: realmArticle)

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
                let article = Article(realmArticle: realmArticle)

                expect(subject.date(for: article)).to(equal(publishedDate))
            }

            it("returns the updated time if it was specified") {
                let article = articleFactory(published: Date(timeIntervalSince1970: 0),
                                             updated: Date(timeIntervalSince1970: 1000))
                expect(subject.date(for: article)).to(equal(Date(timeIntervalSince1970: 1000)))
            }

            it("returns the published date if updated wasn't specified") {
                let article = articleFactory(published: Date(timeIntervalSince1970: 100),
                                             updated: nil)
                expect(subject.date(for: article)).to(equal(Date(timeIntervalSince1970: 100)))
            }

            it("returns the published date if it's after the updated date") {
                let article = articleFactory(published: Date(timeIntervalSince1970: 1000),
                                             updated: Date(timeIntervalSince1970: 0))
                expect(subject.date(for: article)).to(equal(Date(timeIntervalSince1970: 1000)))
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
                    let article = Article(realmArticle: realmArticle)
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
                        let article = Article(realmArticle: realmArticle)
                        expect(subject.estimatedReadingTime(of: article)).to(beCloseTo(135))
                    }

                    it("stores the data so that we don't have to calculate it again later") {
                        _ = subject.estimatedReadingTime(of: Article(realmArticle: realmArticle))

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
                        let article = Article(realmArticle: realmArticle)
                        expect(subject.estimatedReadingTime(of: article)).to(beCloseTo(75))
                    }

                    it("stores the data for later use") {
                        _ = subject.estimatedReadingTime(of: Article(realmArticle: realmArticle))
                        expect(realmArticle.estimatedReadingTime).to(beCloseTo(75))
                    }
                }
            }
        }
    }
}
