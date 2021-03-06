import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP
import Foundation

@testable import TethysKit

final class InoreaderFeedServiceSpec: QuickSpec {
    override func spec() {
        var subject: InoreaderFeedService!
        var httpClient: FakeHTTPClient!

        let baseURL = URL(string: "https://example.com")!

        beforeEach {
            httpClient = FakeHTTPClient()

            subject = InoreaderFeedService(httpClient: httpClient, baseURL: baseURL)
        }

        describe("feeds()") {
            var future: Future<Result<AnyCollection<Feed>, TethysError>>!
            let url = URL(string: "https://example.com/reader/api/0/subscription/list")!

            beforeEach {
                future = subject.feeds()
            }

            it("asks inoreader for the list of feeds") {
                expect(httpClient.requests).to(haveCount(1))
                expect(httpClient.requests.last?.url).to(equal(
                    url
                ))
                expect(httpClient.requests.last?.httpMethod).to(equal("GET"))
            }

            describe("when the request succeeds with valid data") {
                let receivedData: [[String: Any]] = [[
                    "id": "feed/http://www.example.com/feed1/",
                    "title": "Feed 1 - Title",
                    "categories": [[
                        "id": "user/1005921515/label/Animation",
                        "label": "Animation"
                        ]],
                    "sortid": "00DA6134",
                    "firstitemmsec": 1424501776942006,
                    "url": "http://www.example.com/feed1/",
                    "htmlUrl": "http://www.example.com/",
                    "iconUrl": ""
                    ], [
                        "id": "feed/http://example1.net/blog/feed/",
                        "title": "Example 1 - Title",
                        "categories": [[
                            "id": "user/1005921515/label/MUST READ",
                            "label": "MUST READ"
                            ]],
                        "sortid": "0136BF30",
                        "firstitemmsec": 1424330872170656,
                        "url": "http://example1.net/blog/feed/",
                        "htmlUrl": "http://example1.net/blog",
                        "iconUrl": "https://www.inoreader.com/cache/favicons/a/m/a/example1_net_16x16.png"
                    ], [
                        "id": "feed/http://example.com/2/feed",
                        "title": "Example2 - Title",
                        "categories": [[
                            "id": "user/1005921515/label/Example2",
                            "label": "Example2"
                            ]],
                        "sortid": "00F54F6B",
                        "firstitemmsec": 1424502014872507,
                        "url": "http://example.com/2/feed",
                        "htmlUrl": "http://example.com/2",
                        "iconUrl": "https://www.inoreader.com/cache/favicons/y/o/u/example2-com_16x16.png"
                    ], [
                        "id": "feed/http://example.com/3/feed",
                        "title": "Example 3 - Title",
                        "categories": [[
                            "id": "user/1005921515/label/Example3",
                            "label": "Example3"
                            ]],
                        "sortid": "00F54F5F",
                        "firstitemmsec": 1424502014872507,
                        "url": "http://example.com/3/feed",
                        "htmlUrl": "http://www.example.com/3/",
                        "iconUrl": "https://www.inoreader.com/cache/favicons/y/o/u/example3_com_16x16.png"
                    ], [
                        "id": "feed/http://example.com/4/feed/",
                        "title": "example 4 - Title",
                        "categories": [[
                            "id": "user/1005921515/label/Databases",
                            "label": "Databases"
                            ], [
                                "id": "user/1005921515/label/MUST READ",
                                "label": "MUST READ"
                            ]],
                        "sortid": "009BC5E6",
                        "firstitemmsec": 1424501919304951,
                        "url": "http://example.com/4/feed/",
                        "htmlUrl": "http://example.com/4",
                        "iconUrl": "https://www.inoreader.com/cache/favicons/d/o/m/example_com_16x16.png"
                    ], [
                        "id": "feed/http://example.com/5/feed",
                        "title": "Example 5 - Title",
                        "categories": [[
                            "id": "user/1005921515/label/MUST READ",
                            "label": "MUST READ"
                            ], [
                                "id": "user/1005921515/label/Animation",
                                "label": "Animation"
                            ]],
                        "sortid": "00D42F97",
                        "firstitemmsec": 1424501776942006,
                        "url": "http://example.com/5/feed",
                        "htmlUrl": "http://example.com/5/",
                        "iconUrl": "https://www.inoreader.com/cache/favicons/a/r/t/example_com_16x16.png"
                    ]]

                beforeEach {
                    httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                        body: try! JSONSerialization.data(withJSONObject: ["subscriptions": receivedData], options: []),
                        status: .ok,
                        mimeType: "Application/JSON",
                        headers: [:]
                    )))
                }

                it("doesn't resolve the future yet") {
                    expect(future).toNot(beResolved())
                }

                it("makes a request for the unread counts") {
                    let unreadCountsURL = URL(string: "https://example.com/reader/api/0/unread-count")!
                    expect(httpClient.requests).to(haveCount(2))
                    expect(httpClient.requests.last?.url).to(equal(
                        unreadCountsURL
                    ))
                    expect(httpClient.requests.last?.httpMethod).to(equal("GET"))
                }

                describe("when the request succeeds with valid data") {
                    let unreadCountData: [String: Any] = [
                        "max": "1000",
                        "unreadcounts": [
                            [
                                "id": "user/1005921515/state/com.google/reading-list",
                                "count": "4",
                                "newestItemTimestampUsec": "1415620910006331"
                            ], [
                                "id": "feed/http://www.example.com/feed1/",
                                "count": "5",
                                "newestItemTimestampUsec": "1415620910006331"
                            ], [
                                "id": "feed/http://example.com/2/feed",
                                "count": "1",
                                "newestItemTimestampUsec": "1415620910006331"
                            ], [
                                "id": "feed/http://example.com/3/feed",
                                "count": "4",
                                "newestItemTimestampUsec": "1415620910006331"
                            ], [
                                "id": "feed/http://example.com/4/feed/",
                                "count": "2",
                                "newestItemTimestampUsec": "1415620910006331"
                            ], [
                                "id": "feed/http://example.com/5/feed",
                                "count": "8",
                                "newestItemTimestampUsec": "1415620910006331"
                            ], [
                                "id": "unknown",
                                "count": "7",
                                "newestItemTimestampUsec": "1415620910006331"
                            ]
                        ]
                    ]

                    beforeEach {
                        guard httpClient.requestPromises.last?.future.value == nil else {
                            return
                        }
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: try! JSONSerialization.data(withJSONObject: unreadCountData, options: []),
                            status: .ok,
                            mimeType: "Application/JSON",
                            headers: [:]
                        )))
                    }

                    it("returns a list of feeds") {
                        expect(future.value).toNot(beNil())
                        expect(future.value?.error).to(beNil())
                        guard let value = future.value?.value else {
                            fail("Expected future to have resolved successfully, didn't.")
                            return
                        }
                        let received = Array(value)
                        let expected = [
                            Feed(title: "Feed 1 - Title",
                                 url: URL(string: "http://www.example.com/feed1/")!,
                                 summary: "",
                                 tags: ["Animation"],
                                 unreadCount: 5,
                                 image: nil,
                                 identifier: "feed/http://www.example.com/feed1/",
                                 settings: nil
                            ),
                            Feed(title: "Example 1 - Title",
                                 url: URL(string: "http://example1.net/blog/feed/")!,
                                 summary: "",
                                 tags: ["MUST READ"],
                                 unreadCount: 0,
                                 image: nil,
                                 identifier: "feed/http://example1.net/blog/feed/",
                                 settings: nil
                            ),
                            Feed(title: "Example2 - Title",
                                 url: URL(string: "http://example.com/2/feed")!,
                                 summary: "",
                                 tags: ["Example2"],
                                 unreadCount: 1,
                                 image: nil,
                                 identifier: "feed/http://example.com/2/feed",
                                 settings: nil
                            ),
                            Feed(title: "Example 3 - Title",
                                 url: URL(string: "http://example.com/3/feed")!,
                                 summary: "",
                                 tags: ["Example3"],
                                 unreadCount: 4,
                                 image: nil,
                                 identifier: "feed/http://example.com/3/feed",
                                 settings: nil
                            ),
                            Feed(title: "example 4 - Title",
                                 url: URL(string: "http://example.com/4/feed/")!,
                                 summary: "",
                                 tags: ["Databases", "MUST READ"],
                                 unreadCount: 2,
                                 image: nil,
                                 identifier: "feed/http://example.com/4/feed/",
                                 settings: nil
                            ),
                            Feed(title: "Example 5 - Title",
                                 url: URL(string: "http://example.com/5/feed")!,
                                 summary: "",
                                 tags: ["MUST READ", "Animation"],
                                 unreadCount: 8,
                                 image: nil,
                                 identifier: "feed/http://example.com/5/feed",
                                 settings: nil
                            )
                        ]
                        expect(received).to(equal(expected))
                    }
                }

                itBehavesLikeTheRequestFailed(url: URL(string: "https://example.com/reader/api/0/unread-count")!, httpClient: { httpClient }, future: { future })
            }

            itBehavesLikeTheRequestFailed(url: url, httpClient: { httpClient }, future: { future })
        }

        describe("articles(of:)") {
            var future: Future<Result<AnyCollection<Article>, TethysError>>!
            let url = URL(string: "https://example.com/reader/api/0/stream/contents/feed%2Fhttp%3A%2F%2Fwww.example.com%2Ffeed1%2F")!

            let feed = Feed(title: "Whatever", url: URL(string: "http://www.example.com/feed1/")!,
                            summary: "", tags: [])

            beforeEach {
                future = subject.articles(of: feed)
            }

            it("asks inoreader for the contents of the stream") {
                expect(httpClient.requests).to(haveCount(1))
                expect(httpClient.requests.last?.url).to(equal(
                    url
                ))
                expect(httpClient.requests.last?.httpMethod).to(equal("GET"))
            }

            describe("when the request succeeds with valid data") {
                let receivedData: [String: Any] = [
                    "direction": "ltr",
                    "id": "feed/http://www.example.com/feed1/",
                    "title": "whatever",
                    "description": "A description",
                    "self": ["href": url.absoluteString],
                    "updated": 1234567890,
                    "updatedUsec": "1234567890123456",
                    "continuation": "continuation_token_1",
                    "items": [
                    [
                        "crawTimeMsec": "1234567880123",
                        "timestampUsec": " 1234567880123456",
                        "id": "whatever",
                        "categories": [
                            "user/1337/state/com.google/read",
                            "user/1337/label/foo",
                            "user/1337/label/bar",
                            "user/1337/label/baz"
                        ],
                        "title": "Article 1 - Title",
                        "published": 123456787,
                        "updated": 123456789,
                        "canonical": [[
                            "href": "http://www.example.com/1/articles/1"
                        ]],
                        "alternate": [[
                            "href": "http://www.example.com/1/articles/1",
                            "type": "text/html"
                        ]],
                        "summary": ["direction": "ltr", "content": "this is my article summary"],
                        "author": "Foo Bar",
                        "origin": [
                            "streamId": "feed/http://www.example.com/feed1/",
                            "title": "Whatever",
                            "htmlUrl": "http://www.example.com/"
                        ]
                    ], [
                        "crawlTimeMsec": "1422263983452",
                        "timestampUsec": "1422263983452401",
                        "id": "whatever2",
                        "categories": [
                            "user/1337/label/abc",
                            "user/1337/label/def",
                            "user/1337/label/hij"
                        ],
                        "title": "Article 2",
                        "published": 1422262271,
                        "updated": 1422538193,
                        "canonical": [[
                            "href": "http://www.example.com/1/articles/2"
                        ]],
                        "alternate": [[
                            "href": "http://www.example.com/1/articles/2",
                            "type": "text/html"
                        ]],
                        "summary": ["direction": "ltr", "content": "some more summary"],
                        "author": "First Last",
                        "likingUsers": [],
                        "comments": [],
                        "commentsNum": -1,
                        "annotations": [],
                        "origin": [
                            "streamId": "feed/http://www.example.com/feed1/",
                            "title": "Whatever",
                            "htmlUrl": "http://www.example.com/feed1/"
                        ]
                    ], [
                        "crawlTimeMsec": "1422283522174",
                        "timestampUsec": "1422283522173992",
                        "id": "whatever3",
                        "categories": [
                            "user/1337/label/aoeu",
                            "user/1337/label/snth",
                            "user/1337/label/;qjk"
                        ],
                        "title": "Article 3",
                        "published": 1422283440,
                        "updated": 1422554242,
                        "canonical": [[
                            "href": "http://www.example.com/1/articles/3"
                        ]],
                        "alternate": [[
                            "href": "http://www.example.com/1/articles/3",
                            "type": "text/html"
                        ]],
                        "summary": [
                            "direction": "ltr",
                            "content": "more summary"
                        ],
                        "author": "Jane Smith",
                        "likingUsers": [],
                        "comments": [],
                        "commentsNum": -1,
                        "annotations": [],
                        "origin": [
                            "streamId": "feed/http://www.example.com/feed1/",
                            "title": "Whatever",
                            "htmlUrl": "http://www.example.com/feed1/"
                        ]
                    ]]
                ]

                beforeEach {
                    httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                        body: try! JSONSerialization.data(withJSONObject: receivedData, options: []),
                        status: .ok,
                        mimeType: "Application/JSON",
                        headers: [:]
                    )))
                }

                it("resolves the promise with the articles") {
                    expect(future).to(beResolved())
                    expect(future.value?.error).to(beNil())
                    guard let articles = future.value?.value else {
                        return fail("Promise did not resolve successfully")
                    }

                    expect(articles).to(haveCount(3))
                    expect(articles[AnyIndex(0)]).to(equal(Article(
                        title: "Article 1 - Title",
                        link: URL(string: "http://www.example.com/1/articles/1")!,
                        summary: "this is my article summary",
                        authors: [Author("Foo Bar")],
                        identifier: "whatever",
                        content: "this is my article summary",
                        read: true,
                        published: Date(timeIntervalSince1970: 123456787),
                        updated: Date(timeIntervalSince1970: 123456789)

                    )))
                    expect(articles[AnyIndex(1)]).to(equal(Article(
                        title: "Article 2",
                        link: URL(string: "http://www.example.com/1/articles/2")!,
                        summary: "some more summary",
                        authors: [Author("First Last")],
                        identifier: "whatever2",
                        content: "some more summary",
                        read: false,
                        published: Date(timeIntervalSince1970: 1422262271),
                        updated: Date(timeIntervalSince1970: 1422538193)
                    )))
                    expect(articles[AnyIndex(2)]).to(equal(Article(
                        title: "Article 3",
                        link: URL(string: "http://www.example.com/1/articles/3")!,
                        summary: "more summary",
                        authors: [Author("Jane Smith")],
                        identifier: "whatever3",
                        content: "more summary",
                        read: false,
                        published: Date(timeIntervalSince1970: 1422283440),
                        updated: Date(timeIntervalSince1970: 1422554242)
                    )))
                }
            }
        }

        describe("subscribe(to:)") {
            var future: Future<Result<Feed, TethysError>>!
            let url = URL(string: "https://example.com/reader/api/0/subscription/quickadd?quickadd=feed/https://example.com/feed1")!

            let feedURL = URL(string: "https://example.com/feed1")!

            beforeEach {
                future = subject.subscribe(to: feedURL)
            }

            it("asks inoreader for the contents of the stream") {
                expect(httpClient.requests).to(haveCount(1))
                expect(httpClient.requests.last?.url).to(equal(
                    url
                ))
                expect(httpClient.requests.last?.httpMethod).to(equal("POST"))
                expect(httpClient.requests.last?.httpBody).to(equal(Data()))
            }

            describe("when the request succeeds with valid data") {
                let data: [String: Any] = [
                    "query": "feed/https://example.com/feed1.xml",
                    "numResults": 1,
                    "streamId": "feed/https://example.com/contents1",
                    "streamName": "Title of the feed"
                ]

                beforeEach {
                    httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                        body: try! JSONSerialization.data(withJSONObject: data, options: []),
                        status: .ok,
                        mimeType: "Application/JSON",
                        headers: [:]
                    )))
                }

                it("resolves the promise with a feed object") {
                    expect(future.value).toNot(beNil(), description: "Expected the future to be resolved")
                    expect(future.value?.value).to(equal(Feed(
                        title: "Title of the feed",
                        url: URL(string: "https://example.com/feed1.xml")!,
                        summary: "",
                        tags: []
                    )))
                }
            }

            itBehavesLikeTheRequestFailed(url: url, httpClient: { httpClient }, future: { future })
        }

        describe("tags()") {
            var future: Future<Result<AnyCollection<String>, TethysError>>!
            let url = URL(string: "https://example.com/reader/api/0/tag/list")!

            beforeEach {
                future = subject.tags()
            }

            it("asks inoreader for the tags") {
                expect(httpClient.requests).to(haveCount(1))
                expect(httpClient.requests.last?.url).to(equal(
                    url
                ))
                expect(httpClient.requests.last?.httpMethod).to(equal("GET"))
            }

            describe("when the request succeeds with valid data") {
                let data: [String: Any] = [
                    "tags": [
                        [
                            "id": "user/1005921515/state/com.google/starred",
                            "sortid": "FFFFFFFF"
                        ],
                        [
                            "id": "user/1005921515/state/com.google/broadcast",
                            "sortid": "FFFFFFFE"
                        ],
                        [
                            "id": "user/1005921515/state/com.google/blogger-following",
                            "sortid": "FFFFFFFD"
                        ],
                        [
                            "id": "user/1005921515/label/Google",
                            "sortid": "BEBC2063",
                            "type": "tag",
                            "unread_count": 0,
                            "unseen_count": 0
                        ],
                        [
                            "id": "user/1005921515/label/DIY",
                            "sortid": "BECC0BE1",
                            "type": "folder"
                        ],
                        [
                            "id": "user/1005921515/label/Feedly active search",
                            "sortid": "BECC502C",
                            "type": "active_search",
                            "unread_count": 0,
                            "unseen_count": 0
                        ]
                    ]
                ]

                beforeEach {
                    httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                        body: try! JSONSerialization.data(withJSONObject: data, options: []),
                        status: .ok,
                        mimeType: "Application/JSON",
                        headers: [:]
                    )))
                }

                it("resolves the promise with the names of the ids under labels") {
                    expect(future.value).toNot(beNil(), description: "Expected the future to be resolved")
                    expect(future.value?.value).toNot(beNil(), description: "Expected request to succeed")

                    guard let value = future.value?.value else { return }
                    expect(Array(value)).to(equal([
                        "Google",
                        "DIY",
                        "Feedly active search"
                    ]))
                }
            }

            itBehavesLikeTheRequestFailed(url: url, httpClient: { httpClient }, future: { future })
        }

        describe("set(tags:of:)") {
            var future: Future<Result<Feed, TethysError>>!

            let feed = Feed(title: "Whatever", url: URL(string: "http://www.example.com/feed1/")!,
                            summary: "", tags: [])

            beforeEach {
                future = subject.set(tags: ["a", "b", "c"], of: feed)
            }

            xit("asks inoreader to modify the tags with the feed") {
                expect(httpClient.requests).to(haveCount(1))
                expect(httpClient.requests.last?.url).to(equal(
                    URL(string: "https://example.com/dunno")!
                ))
                expect(httpClient.requests.last?.httpMethod).to(equal("GET"))
            }

            it("immediately resolves with a notSupported url") {
                expect(future).to(beResolved())
                expect(future.value?.error).to(equal(TethysError.notSupported))
            }
        }

        describe("set(url:on:)") {
            let feed = Feed(title: "Whatever", url: URL(string: "http://www.example.com/feed1/")!,
                            summary: "", tags: [])

            it("immediately resolves with a notSupported url") {
                let future = subject.set(url: URL(string: "https://example.com/feed2/")!, on: feed)

                expect(future).to(beResolved())
                expect(future.value?.error).to(equal(TethysError.notSupported))
            }
        }

        describe("readAll(of:)") {
            var future: Future<Result<Void, TethysError>>!
            let feed = Feed(title: "Whatever", url: URL(string: "http://www.example.com/feed1/")!,
                            summary: "", tags: [])

            let url = URL(string: "https://example.com/reader/api/0/mark-all-as-read?s=feed/http://www.example.com/feed1/")!

            beforeEach {
                future = subject.readAll(of: feed)
            }

            it("asks inoreader to mark all articles in the feed as read") {
                expect(httpClient.requests).to(haveCount(1))
                expect(httpClient.requests.last?.url).to(equal(
                    url
                ))
                expect(httpClient.requests.last?.httpMethod).to(equal("GET"))
            }

            describe("when the request succeeds") {
                beforeEach {
                    httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                        body: Data(),
                        status: .ok,
                        mimeType: "",
                        headers: [:]
                    )))
                }

                it("resolves the promise with the names of the ids under labels") {
                    expect(future.value).toNot(beNil(), description: "Expected the future to be resolved")
                    expect(future.value?.value).to(beVoid(), description: "Expected request to succeed")
                }
            }

            itBehavesLikeTheRequestFailed(url: url, httpClient: { httpClient }, future: { future })
        }

        describe("remove(feed:)") {
            var future: Future<Result<Void, TethysError>>!
            let feed = Feed(title: "Whatever", url: URL(string: "http://www.example.com/feed1/")!,
                            summary: "", tags: [])

            let url = URL(string: "https://example.com/reader/api/0/subscription/edit?ac=unsubscribe&s=feed/http://www.example.com/feed1/")!

            beforeEach {
                future = subject.remove(feed: feed)
            }

            it("asks inoreader to unsubscribe from the feed") {
                expect(httpClient.requests).to(haveCount(1))
                expect(httpClient.requests.last?.url).to(equal(
                    url
                ))
                expect(httpClient.requests.last?.httpMethod).to(equal("GET"))
            }

            describe("when the request succeeds") {
                beforeEach {
                    httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                        body: Data(),
                        status: .ok,
                        mimeType: "",
                        headers: [:]
                    )))
                }

                it("resolves the promise with the names of the ids under labels") {
                    expect(future.value).toNot(beNil(), description: "Expected the future to be resolved")
                    expect(future.value?.value).to(beVoid(), description: "Expected request to succeed")
                }
            }

            itBehavesLikeTheRequestFailed(url: url, httpClient: { httpClient }, future: { future })
        }
    }
}
