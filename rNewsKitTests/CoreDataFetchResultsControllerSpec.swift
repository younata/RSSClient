import Quick
import Nimble
import CoreData
@testable import rNewsKit

class CoreDataFetchResultsControllerSpec: QuickSpec {
    override func spec() {
        describe("CoreDataFetchResultsController") {
            var subject: CoreDataFetchResultsController<CoreDataArticle>!
            var objects: [CoreDataArticle] = []
            var moc: NSManagedObjectContext! = nil

            let totalObjectCount = 200

            beforeEach {
                moc = managedObjectContext()

                objects = []

                for i in 0..<totalObjectCount {
                    let article = createArticle(moc)
                    article.title = String(format: "%03d", i)
                    objects.append(article)
                }

                try! moc.save()

                let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)

                subject = CoreDataFetchResultsController(entityName: "Article", managedObjectContext: moc, sortDescriptors: [sortDescriptor], predicate: NSPredicate(value: true))
            }

            it("gets the count correctly") {
                expect(subject.count) == totalObjectCount
            }

            it("gets an item from the list") {
                for (idx, object) in objects.enumerate() {
                    expect{ try? subject.get(idx) }.to(equal(object))
                    expect(subject[idx]) == object
                }
            }

            it("throws an error if you get an object outside the range") {
                expect { try subject.get(-1) }.to(throwError())
                expect { try subject.get(totalObjectCount) }.to(throwError())
            }

            it("deletes an item from the core data store when you call 'delete'") {
                try! subject.delete(1)
                expect(subject.count) == totalObjectCount - 1
                let articles = coreDataEntities("Article", matchingPredicate: NSPredicate(value: true), managedObjectContext: moc)
                expect(articles).toNot(contain(objects[1]))
            }
        }
    }
}