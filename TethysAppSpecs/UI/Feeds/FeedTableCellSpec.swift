import Quick
import Nimble
import UIKit
import Tethys
import TethysKit

class FeedTableCellSpec: QuickSpec {
    override func spec() {
        var subject: FeedTableCell! = nil
        beforeEach {
            subject = FeedTableCell(style: .default, reuseIdentifier: nil)
        }

        describe("theming") {
            it("sets the labels") {
                expect(subject.nameLabel.textColor).to(equal(Theme.textColor))
                expect(subject.summaryLabel.textColor).to(equal(Theme.textColor))
            }

            it("sets the background color") {
                expect(subject.backgroundColor).to(equal(Theme.backgroundColor))
            }

            it("sets the unreadCounter's colors") {
                expect(subject.unreadCounter.triangleColor).to(equal(Theme.highlightColor))
            }
        }

        sharedExamples("a standard feed cell") {(ctx: @escaping SharedExampleContext) in
            var subject: FeedTableCell! = nil
            it("sets the title") {
                subject = ctx()["subject"] as? FeedTableCell
                let title = ctx()["title"] as! String
                expect(subject.nameLabel.text).to(equal(title))
            }

            it("sets the summary") {
                subject = ctx()["subject"] as? FeedTableCell
                let summary = ctx()["summary"] as? String ?? ""
                expect(subject.summaryLabel.text).to(equal(summary))
            }
        }

        describe("setting feed") {
            var feed: Feed! = nil
            context("with a feed that has no unread articles") {
                beforeEach {
                    feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                        unreadCount: 0, image: nil)
                    subject.feed = feed
                }

                itBehavesLike("a standard feed cell") {
                    ["subject": subject!, "title": "Hello", "summary": "World"]
                }

                it("should hide the unread counter") {
                    expect(subject.unreadCounter.isHidden) == true
                    expect(subject.unreadCounter.unread).to(equal(0))
                }
            }

            context("with a feed that has some unread articles") {
                beforeEach {
                    feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                                unreadCount: 1, image: nil)
                    subject.feed = feed
                }
                itBehavesLike("a standard feed cell") {
                    ["subject": subject!, "title": "Hello", "summary": "World"]
                }

                it("should hide the unread counter") {
                    expect(subject.unreadCounter.isHidden) == false
                    expect(subject.unreadCounter.unread).to(equal(1))
                }
            }

            context("with a feed featuring an image") {
                var image: UIImage! = nil
                beforeEach {
                    image = UIImage(named: "GrayIcon")
                    feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                        unreadCount: 0, image: image)
                    subject.feed = feed
                }

                itBehavesLike("a standard feed cell") {
                    ["subject": subject!, "title": "Hello", "summary": "World"]
                }

                it("should show the image") {
                    expect(subject.iconView.image).to(equal(image))
                }

                it("should set the width or height constraint depending on the image size") {
                    // in this case, 60x60
                    expect(subject.iconWidth.constant).to(equal(60))
                    expect(subject.iconHeight.constant).to(equal(60))
                }
            }

            context("with a feed that doesn't have an image") {
                beforeEach {
                    feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                        unreadCount: 0, image: nil)
                    subject.feed = feed
                }

                itBehavesLike("a standard feed cell") {
                    ["subject": subject!, "title": "Hello", "summary": "World"]
                }

                it("should set an image of nil") {
                    expect(subject.iconView.image).to(beNil())
                }

                it("should set the width to 45 and the height to 0") {
                    expect(subject.iconWidth.constant).to(equal(45))
                    expect(subject.iconHeight.constant).to(equal(0))
                }
            }
        }
    }
}
