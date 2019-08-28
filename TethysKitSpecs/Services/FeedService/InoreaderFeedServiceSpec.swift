import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP

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

        func itBehavesLikeTheRequestFailed<T>(url: URL, future: @escaping () -> Future<Result<T, TethysError>>) {
            describe("when the request succeeds") {
                context("and the data is not valid") {
                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: "[\"bad\": \"data\"]".data(using: .utf8)!,
                            status: .ok,
                            mimeType: "Application/JSON",
                            headers: [:]
                        )))
                    }

                    it("resolves the future with a bad response error") {
                        expect(future().value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future().value?.error).to(equal(TethysError.network(url, .badResponse)))
                    }
                }
            }

            describe("when the request fails") {
                context("when the request fails with a 400 level error") {
                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: "403".data(using: .utf8)!,
                            status: HTTPStatus.init(rawValue: 403)!,
                            mimeType: "Application/JSON",
                            headers: [:]
                        )))
                    }

                    it("resolves the future with the error") {
                        expect(future().value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future().value?.error).to(equal(
                            TethysError.network(url, .http(.forbidden))
                        ))
                    }
                }

                context("when the request fails with a 500 level error") {
                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: "502".data(using: .utf8)!,
                            status: HTTPStatus.init(rawValue: 502)!,
                            mimeType: "Application/JSON",
                            headers: [:]
                        )))
                    }

                    it("resolves the future with the error") {
                        expect(future().value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future().value?.error).to(equal(
                            TethysError.network(url, .http(.badGateway))
                        ))
                    }
                }

                context("when the request fails with an error") {
                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.failure(HTTPClientError.network(.timedOut)))
                    }

                    it("resolves the future with an error") {
                        expect(future().value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future().value?.error).to(equal(
                            TethysError.network(url, .timedOut)
                        ))
                    }
                }
            }
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
                             unreadCount: 0,
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
                             unreadCount: 0,
                             image: nil,
                             identifier: "feed/http://example.com/2/feed",
                             settings: nil
                        ),
                        Feed(title: "Example 3 - Title",
                             url: URL(string: "http://example.com/3/feed")!,
                             summary: "",
                             tags: ["Example3"],
                             unreadCount: 0,
                             image: nil,
                             identifier: "feed/http://example.com/3/feed",
                             settings: nil
                        ),
                        Feed(title: "example 4 - Title",
                             url: URL(string: "http://example.com/4/feed/")!,
                             summary: "",
                             tags: ["Databases", "MUST READ"],
                             unreadCount: 0,
                             image: nil,
                             identifier: "feed/http://example.com/4/feed/",
                             settings: nil
                        ),
                        Feed(title: "Example 5 - Title",
                             url: URL(string: "http://example.com/5/feed")!,
                             summary: "",
                             tags: ["MUST READ", "Animation"],
                             unreadCount: 0,
                             image: nil,
                             identifier: "feed/http://example.com/5/feed",
                             settings: nil
                        )
                    ]
                    expect(received).to(equal(expected))
                }
            }

            itBehavesLikeTheRequestFailed(url: url, future: { future })
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
                        "categories": ["foo", "bar", "baz"],
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
                            "abc",
                            "def",
                            "hij"
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
                            "aoeu",
                            "snth",
                            ";qjk"
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

                it("doesn't yet resolve the promise") {
                    expect(future.value).to(beNil())
                }

                it("makes another request for the next set of articles, using the continuation token it was given") {
                    var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                    urlComponents.queryItems = [URLQueryItem(name: "c", value: "continuation_token_1")]
                    expect(httpClient.requests).to(haveCount(2))
                    expect(httpClient.requests.last?.url).to(equal(
                        urlComponents.url!
                    ))
                    expect(httpClient.requests.last?.httpMethod).to(equal("GET"))
                }

                itBehavesLikeTheRequestFailed(url: url, future: { future })
            }

            itBehavesLikeTheRequestFailed(url: url, future: { future })
        }

        describe("subscribe(to:)") {
            it("needs to be implemented") {
                fail("Implement me!")
            }
        }

        describe("tags()") {
            it("needs to be implemented") {
                fail("Implement me!")
            }
        }

        describe("set(tags:of:)") {
            it("needs to be implemented") {
                fail("Implement me!")
            }
        }

        describe("set(url:on:)") {
            it("needs to be implemented") {
                fail("Implement me!")
            }
        }

        describe("readAll(of:)") {
            it("needs to be implemented") {
                fail("Implement me!")
            }
        }

        describe("remove(feed:)") {
            it("needs to be implemented") {
                fail("Implement me!")
            }
        }
    }
}
