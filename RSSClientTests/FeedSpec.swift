import Quick
import Nimble
@testable import rNewsKit

class FeedSpec: QuickSpec {
    override func spec() {
        var subject : Feed! = nil

        beforeEach {
            subject = Feed(title: "", url: nil, summary: "", query: nil, tags: [],
                waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
        }

        describe("waitPeriodInRefreshes") {
            func feedWithWaitPeriod(waitPeriod: Int) -> Feed {
                return Feed(title: "", url: nil, summary: "", query: nil, tags: [],
                    waitPeriod: waitPeriod, remainingWait: 0, articles: [], image: nil)
            }

            it("should return a number based on the fibonacci sequence offset by 2") {
                subject = feedWithWaitPeriod(0)
                expect(subject.waitPeriodInRefreshes()).to(equal(0))
                subject = feedWithWaitPeriod(1)
                expect(subject.waitPeriodInRefreshes()).to(equal(0))
                subject = feedWithWaitPeriod(2)
                expect(subject.waitPeriodInRefreshes()).to(equal(0))
                subject = feedWithWaitPeriod(3)
                expect(subject.waitPeriodInRefreshes()).to(equal(1))
                subject = feedWithWaitPeriod(4)
                expect(subject.waitPeriodInRefreshes()).to(equal(1))
                subject = feedWithWaitPeriod(5)
                expect(subject.waitPeriodInRefreshes()).to(equal(2))
                subject = feedWithWaitPeriod(6)
                expect(subject.waitPeriodInRefreshes()).to(equal(3))
                subject = feedWithWaitPeriod(7)
                expect(subject.waitPeriodInRefreshes()).to(equal(5))
                subject = feedWithWaitPeriod(8)
                expect(subject.waitPeriodInRefreshes()).to(equal(8))
            }
        }

        it("correctly identifies itself as a query feed or not") {
            let regularFeed = Feed(title: "", url: nil, summary: "", query: nil, tags: [],
                waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            let queryFeed = Feed(title: "", url: nil, summary: "", query: "", tags: [],
                waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            expect(regularFeed.isQueryFeed).to(beFalsy())
            expect(queryFeed.isQueryFeed).to(beTruthy())
        }

        it("unreadArticles() should return articles with read->false") {
            func article(name: String, read: Bool) -> Article {
                return Article(title: name, link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: read, feed: nil, flags: [], enclosures: [])
            }

            let a = article("a", read: true)
            let b = article("b", read: false)
            let c = article("c", read: false)
            let d = article("d", read: true)

            subject.addArticle(a)
            subject.addArticle(b)
            subject.addArticle(c)
            subject.addArticle(d)

            expect(subject.unreadArticles()).to(equal([b, c]))
        }

        describe("Equatable") {
            it("should report two feeds created with a coredatafeed with the same feedID as equal") {
                let ctx = managedObjectContext()
                let a = createFeed(ctx)
                let b = createFeed(ctx)

                expect(Feed(feed: a)).toNot(equal(Feed(feed: b)))
                expect(Feed(feed: a)).to(equal(Feed(feed: a)))
            }

            it("should report two feeds not created with coredatafeeds with the same property equality as equal") {
                let a = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let b = Feed(title: "blah", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let c = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                expect(a).toNot(equal(b))
                expect(a).to(equal(c))
            }
        }

        describe("Hashable") {
            it("should report two feeds created with a coredatafeed with the same feedID as having the same hashValue") {
                let ctx = managedObjectContext()
                let a = createFeed(ctx)
                let b = createFeed(ctx)

                expect(Feed(feed: a).hashValue).toNot(equal(Feed(feed: b).hashValue))
                expect(Feed(feed: a).hashValue).to(equal(Feed(feed: a).hashValue))
            }

            it("should report two feeds not created with coredatafeeds with the same property equality as having the same hashValue") {
                let a = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let b = Feed(title: "blah", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let c = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                expect(a.hashValue).toNot(equal(b.hashValue))
                expect(a.hashValue).to(equal(c.hashValue))
            }
        }

        describe("adding an article") {
            var article: Article! = nil
            beforeEach {
                article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])
            }

            context("when the article is not associated with any article") {
                it("should add the article and set the article's feed if it's not set already") {
                    subject.addArticle(article)

                    expect(subject.updated).to(beTruthy())
                    expect(article.updated).to(beTruthy())
                    expect(article.feed).to(equal(subject))
                    expect(subject.articles).to(contain(article))
                }
            }

            context("when the article is already associated with this feed") {
                beforeEach {
                    subject = Feed(title: "", url: nil, summary: "", query: nil, tags: [],
                        waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)
                }

                it("essentially no-ops") {
                    subject.addArticle(article)
                    expect(subject.updated).to(beFalsy())
                    expect(article.feed).to(equal(subject))
                    expect(subject.articles).to(contain(article))
                }
            }

            context("when the article is associated with a different feed") {
                var otherFeed : Feed! = nil
                beforeEach {
                    otherFeed = Feed(title: "blah", url: nil, summary: "", query: nil, tags: [],
                        waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)
                }

                it("should remove the article from the other feed and add it to this feed") {
                    subject.addArticle(article)

                    expect(subject.updated).to(beTruthy())
                    expect(article.updated).to(beTruthy())
                    expect(otherFeed.updated).to(beTruthy())
                    expect(article.feed).to(equal(subject))
                    expect(subject.articles).to(contain(article))
                    expect(otherFeed.articles).toNot(contain(article))
                }
            }
        }

        describe("removing an article") {
            var article: Article! = nil
            beforeEach {
                article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])
            }

            context("when the article is not associated with any article") {
                it("essentially no-ops") {
                    subject.removeArticle(article)
                    expect(subject.updated).to(beFalsy())
                }
            }

            context("when the article is associated with this feed") {
                beforeEach {
                    subject = Feed(title: "", url: nil, summary: "", query: nil, tags: [],
                        waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)
                }

                it("removes the article and unsets the article's feed") {
                    subject.removeArticle(article)
                    expect(subject.updated).to(beTruthy())
                    expect(article.feed).to(beNil())
                    expect(subject.articles).toNot(contain(article))
                }
            }

            context("when the article is associated with a different feed") {
                var otherFeed : Feed! = nil
                beforeEach {
                    otherFeed = Feed(title: "blah", url: nil, summary: "", query: nil, tags: [],
                        waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)
                }

                it("essentially no-ops") {
                    subject.removeArticle(article)
                    expect(subject.updated).to(beFalsy())
                    expect(otherFeed.updated).to(beFalsy())
                }
            }
        }

        describe("adding a tag") {
            it("should add the tag") {
                subject.addTag("tag")

                expect(subject.tags).to(contain("tag"))
                expect(subject.updated).to(beTruthy())
            }

            context("trying to add the same flag again") {
                beforeEach {
                    subject = Feed(title: "", url: nil, summary: "", query: nil, tags: ["tag"],
                        waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                }

                it("should no-op") {
                    subject.addTag("tag")

                    expect(subject.updated).to(beFalsy())
                }
            }

            describe("Adding a tag that starts with '~'") {
                beforeEach {
                    subject.addTag("~newTag")
                }

                it("should now report the title as the new tag minus the prefix'd '~'") {
                    expect(subject.displayTitle).to(equal("newTag"))
                }
            }

            xdescribe("Adding a tag that starts with '_'") {
                beforeEach {
                    subject.addTag("_newTag")
                }

                it("should now report the summary as the new tag minus the prefix'd '_'") {
                    expect(subject.displaySummary).to(equal("newTag"))
                }
            }
        }

        describe("removing a tag") {
            context("that is already a flag in the article") {
                it("should remove the flag") {
                    subject = Feed(title: "", url: nil, summary: "", query: nil, tags: ["tag"],
                        waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                    subject.removeTag("tag")

                    expect(subject.tags).toNot(contain("tags"))
                    expect(subject.updated).to(beTruthy())
                }
            }

            context("that isn't in a flag in the article") {
                it("should no-op") {
                    expect(subject.tags).toNot(contain("tag"))
                    subject.removeTag("tag")

                    expect(subject.tags).toNot(contain("tag"))
                    expect(subject.updated).to(beFalsy())
                }
            }
        }

        describe("the updated flag") {
            it("should start negative") {
                expect(subject.updated).to(beFalsy())
            }

            describe("properties that change updated to positive") {
                it("title") {
                    subject.title = ""
                    expect(subject.updated).to(beFalsy())
                    subject.title = "title"
                    expect(subject.updated).to(beTruthy())
                }

                it("url") {
                    subject.title = ""
                    expect(subject.updated).to(beFalsy())
                    subject.title = "title"
                    expect(subject.updated).to(beTruthy())
                }

                it("summary") {
                    subject.summary = ""
                    expect(subject.updated).to(beFalsy())
                    subject.summary = "summary"
                    expect(subject.updated).to(beTruthy())
                }

                it("query") {
                    subject.query = nil
                    expect(subject.updated).to(beFalsy())
                    subject.query = "query"
                    expect(subject.updated).to(beTruthy())
                }

                it("tags") {
                    subject.addTag("tag")
                    expect(subject.updated).to(beTruthy())
                }

                it("waitPeriod") {
                    subject.waitPeriod = 0
                    expect(subject.updated).to(beFalsy())
                    subject.waitPeriod = 1
                    expect(subject.updated).to(beTruthy())
                }

                it("remainingWait") {
                    subject.remainingWait = 0
                    expect(subject.updated).to(beFalsy())
                    subject.remainingWait = 1
                    expect(subject.updated).to(beTruthy())
                }

                it("articles") {
                    let article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])
                    subject.addArticle(article)
                    expect(subject.updated).to(beTruthy())
                }

                it("image") {
                    subject.image = nil
                    expect(subject.updated).to(beFalsy())
                    subject.image = Image()
                    expect(subject.updated).to(beTruthy())
                }
            }
        }
    }
}
