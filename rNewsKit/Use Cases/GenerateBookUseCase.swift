import CBGPromise
import Result
import Sponde

public protocol GenerateBookUseCase {
    func generateBook(title: String, author: String,
                      chapters: [Article], format: Book.Format) -> Future<Result<URL, RNewsError>>
}

struct DefaultGenerateBookUseCase: GenerateBookUseCase {
    let service: Sponde.Service
    let mainQueue: OperationQueue

    init(service: Sponde.Service, mainQueue: OperationQueue) {
        self.service = service
        self.mainQueue = mainQueue
    }

    func generateBook(title: String, author: String,
                      chapters: [Article], format: Book.Format) -> Future<Result<URL, RNewsError>> {
        let bookChapters = chapters.map {
            return Chapter(title: $0.title, html: $0.content)
        }
        let future = self.service.generateBook(title: title, imageURL: nil, author: author,
                                               chapters: bookChapters, format: format)
        return future.map { (result: Result<Book, SpondeError>) -> Future<Result<URL, RNewsError>> in
            let promise = Promise<Result<URL, RNewsError>>()
            self.mainQueue.addOperation {
                switch result {
                case let .success(book):
                    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
                    let bookURL = tempDirectory.appendingPathComponent(book.filename, isDirectory: false)
                    try? book.content.write(to: bookURL)
                    promise.resolve(.success(bookURL))
                case let .failure(error):
                    promise.resolve(.failure(RNewsError.book(error)))
                }
            }
            return promise.future
        }
    }
}
