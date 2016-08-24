import Quick
import Nimble
import RealmSwift
@testable import rNewsKit

class ArticleSpec: QuickSpec {
    override func spec() {
        var subject: Article! = nil
        var realm: Realm!

        beforeEach {
            let realmConf = Realm.Configuration(inMemoryIdentifier: "ArticleSpec")
            realm = try! Realm(configuration: realmConf)
            try! realm.write {
                realm.deleteAll()
            }

            subject = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])
        }

        describe("creating from a CoreDataArticle") {
            it("sets estimatedReadingTime when it's nil in CoreData estimatedReadingTime is nil") {
                let ctx = managedObjectContext()
                let a = createArticle(ctx)

                a.content = (0..<100).map({_ in "<p>this was a content space</p>"}).reduce("", combine: +)

                let article = Article(coreDataArticle: a, feed: nil)
                expect(article.estimatedReadingTime).to(equal(3))
                expect(a.estimatedReadingTime?.integerValue).to(equal(3))
            }
        }

        describe("Equatable") {
            it("should report two articles created with a coredataarticle with the same articleID as equal") {
                let ctx = managedObjectContext()
                let a = createArticle(ctx)
                let b = createArticle(ctx)

                expect(Article(coreDataArticle: a, feed: nil)).toNot(equal(Article(coreDataArticle: b, feed: nil)))
                expect(Article(coreDataArticle: a, feed: nil)).to(equal(Article(coreDataArticle: a, feed: nil)))
            }

            it("should report two articles created with a realmarticle with the same url as equal") {
                realm.beginWrite()
                let a = realm.create(RealmArticle)
                a.link = "https://example.com/article"

                let b = realm.create(RealmArticle)
                b.link = "https://example.com/article2"

                _ = try? realm.commitWrite()

                expect(Article(realmArticle: a, feed: nil)).toNot(equal(Article(realmArticle: b, feed: nil)))
                expect(Article(realmArticle: a, feed: nil)).to(equal(Article(realmArticle: a, feed: nil)))
            }

            it("should report two articles not created with datastore objects with the same property equality as equal") {
                let date = NSDate()
                let a = Article(title: "", link: nil, summary: "", authors: [], published: date, updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])
                let b = Article(title: "blah", link: NSURL(), summary: "hello", authors: [Author("anAuthor")], published: NSDate(timeIntervalSince1970: 0), updatedAt: nil, identifier: "hi", content: "hello there", read: true, estimatedReadingTime: 70, feed: nil, flags: ["flag"])
                let c = Article(title: "", link: nil, summary: "", authors: [], published: date, updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])

                expect(a).toNot(equal(b))
                expect(a).to(equal(c))
            }
        }

        describe("Hashable") {
            it("should report two articles created with a coredataarticle with the same articleID as having the same hashValue") {
                let ctx = managedObjectContext()
                let a = createArticle(ctx)
                let b = createArticle(ctx)

                expect(Article(coreDataArticle: a, feed: nil).hashValue).toNot(equal(Article(coreDataArticle: b, feed: nil).hashValue))
                expect(Article(coreDataArticle: a, feed: nil).hashValue).to(equal(Article(coreDataArticle: a, feed: nil).hashValue))
            }

            it("should report two articles created with a realmarticle with the same url as equal") {
                realm.beginWrite()
                let a = realm.create(RealmArticle)
                a.link = "https://example.com/article"

                let b = realm.create(RealmArticle)
                b.link = "https://example.com/article2"

                _ = try? realm.commitWrite()

                expect(Article(realmArticle: a, feed: nil).hashValue).toNot(equal(Article(realmArticle: b, feed: nil).hashValue))
                expect(Article(realmArticle: a, feed: nil).hashValue).to(equal(Article(realmArticle: a, feed: nil).hashValue))
            }

            it("should report two articles not created with coredataarticles with the same property equality as having the same hashValue") {
                let date = NSDate()
                let a = Article(title: "", link: nil, summary: "", authors: [], published: date, updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])
                let b = Article(title: "blah", link: NSURL(), summary: "hello", authors: [Author("anAuthor")], published: NSDate(timeIntervalSince1970: 0), updatedAt: nil, identifier: "hi", content: "hello there", read: true, estimatedReadingTime: 60, feed: nil, flags: ["flag"])
                let c = Article(title: "", link: nil, summary: "", authors: [], published: date, updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])

                expect(a.hashValue).toNot(equal(b.hashValue))
                expect(a.hashValue).to(equal(c.hashValue))
            }
        }

        describe("adding a flag") {

            it("should add the flag") {
                subject.addFlag("flag")

                expect(subject.flags).to(contain("flag"))
                expect(subject.updated) == true
            }

            context("trying to add the same flag again") {
                beforeEach {
                    subject = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: ["flag"])
                }

                it("should no-op") {
                    subject.addFlag("flag")

                    expect(subject.updated) == false
                }
            }
        }

        describe("removing a flag") {
            context("that is already a flag in the article") {
                it("should remove the flag") {
                    subject = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: ["flag"])
                    subject.removeFlag("flag")

                    expect(subject.flags).toNot(contain("flags"))
                    expect(subject.updated) == true
                }
            }

            context("that isn't in a flag in the article") {
                it("should no-op") {
                    expect(subject.flags).toNot(contain("flag"))
                    subject.removeFlag("flag")

                    expect(subject.flags).toNot(contain("flag"))
                    expect(subject.updated) == false
                }
            }
        }

        describe("changing feeds") {
            var feed: Feed! = nil

            beforeEach {
                feed = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                subject.feed = feed
            }

            it("should add subject to the feed's articles list") {
                expect(feed.articlesArray).to(contain(subject))
            }

            it("should remove subject from the feed's articls list when that gets unset") {
                subject.feed = nil

                expect(feed.articlesArray).toNot(contain(subject))
            }

            it("should remove from the old and add to the new when changing feeds") {
                let newFeed = Feed(title: "blah", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                subject.feed = newFeed

                expect(feed.articlesArray).toNot(contain(subject))
                expect(newFeed.articlesArray).to(contain(subject))
            }

            it("should no-op when trying to change the feed to a query feed") {
                let query = Feed(title: "blah", url: nil, summary: "", query: "true", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                subject.feed = query

                expect(feed.articlesArray).to(contain(subject))
            }
        }

        describe("relatedArticles") {
            var a: Article!
            var b: Article!

            beforeEach {
                a = Article(title: "a", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])
                b = Article(title: "b", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])
            }

            it("doesn't let itself be added as a related article") {
                a.addRelatedArticle(a)

                expect(a.relatedArticles).to(beEmpty())
            }

            it("adding sets a bidirectional relationship for the two related articles") {
                a.addRelatedArticle(b)
                expect(a.relatedArticles).to(contain(b))
                expect(b.relatedArticles).to(contain(a))
            }

            it("removing removes the relation from both articles") {
                a.addRelatedArticle(b)

                b.removeRelatedArticle(a)

                expect(a.relatedArticles).toNot(contain(b))
                expect(b.relatedArticles).toNot(contain(a))
            }
        }

        describe("the updated flag") {
            it("should start negative") {
                expect(subject.updated) == false
            }

            describe("properties that change updated to positive") {
                it("title") {
                    subject.title = ""
                    expect(subject.updated) == false
                    subject.title = "title"
                    expect(subject.updated) == true
                }

                it("link") {
                    subject.link = nil
                    expect(subject.updated) == false
                    subject.link = NSURL(string: "http://example.com")
                    expect(subject.updated) == true
                }

                it("summary") {
                    subject.summary = ""
                    expect(subject.updated) == false
                    subject.summary = "summary"
                    expect(subject.updated) == true
                }

                it("author") {
                    subject.authors = []
                    expect(subject.updated) == false
                    subject.authors = [Author("author")]
                    expect(subject.updated) == true
                }

                it("published") {
                    subject.published = subject.published
                    expect(subject.updated) == false
                    subject.published = NSDate(timeIntervalSince1970: 0)
                    expect(subject.updated) == true
                }

                it("updatedAt") {
                    subject.updatedAt = nil
                    expect(subject.updated) == false
                    subject.updatedAt = NSDate()
                    expect(subject.updated) == true
                }

                it("identifier") {
                    subject.identifier = ""
                    expect(subject.updated) == false
                    subject.identifier = "identifier"
                    expect(subject.updated) == true
                }

                it("content") {
                    subject.content = ""
                    expect(subject.updated) == false
                    subject.content = "content"
                    expect(subject.updated) == true
                }

                it("estimatedReadingTime") {
                    subject.estimatedReadingTime = 0
                    expect(subject.updated) == false
                    subject.estimatedReadingTime = 30
                    expect(subject.updated) == true
                }

                it("read") {
                    subject.read = false
                    expect(subject.updated) == false
                    subject.read = true
                    expect(subject.updated) == true
                }

                it("feed") {
                    subject.feed = nil
                    expect(subject.updated) == false
                    subject.feed = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    expect(subject.updated) == true
                }

                it("flags") {
                    subject.addFlag("flag")
                    expect(subject.updated) == true
                }

                it("relatedArticles") {
                    let a = Article(title: "a", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])
                    let b = Article(title: "b", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])

                    a.addRelatedArticle(b)

                    expect(a.updated) == true
                    expect(b.updated) == true
                }
            }
        }
    }
}
