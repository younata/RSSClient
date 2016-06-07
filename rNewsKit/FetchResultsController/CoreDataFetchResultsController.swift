import CoreData

private let cacheName = "CoreDataFetchResultsController"

struct CoreDataFetchResultsController<T: NSManagedObject>: FetchResultsController {
    typealias Element = T

    private let fetchResultsController: NSFetchedResultsController

    private let initialError: RNewsError?

    var count: Int {
        return fetchResultsController.sections?.first?.numberOfObjects ?? 0
    }

    init(entityName: String, managedObjectContext: NSManagedObjectContext,
         sortDescriptors: [NSSortDescriptor], predicate: NSPredicate) {
        let fetchRequest = NSFetchRequest(entityName: entityName)
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.predicate = predicate

        self.fetchResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                 managedObjectContext: managedObjectContext,
                                                                 sectionNameKeyPath: nil,
                                                                 cacheName: cacheName)
        do {
            try self.fetchResultsController.performFetch()
            self.initialError = nil
        } catch {
            self.initialError = .Database(DatabaseError.Unknown)
        }
    }

    func get(index: Int) throws -> Element {
        if let error = self.initialError {
            throw error
        }
        if index < 0 || index >= self.count {
            throw RNewsError.Database(.EntryNotFound)
        }
        let indexPath = NSIndexPath(forRow: index, inSection: 0)
        return self.fetchResultsController.objectAtIndexPath(indexPath) as! T
    }

    mutating func insert(item: Element) throws {
        fatalError("Not implemented")
    }

    mutating func delete(index: Int) throws {
        do {
            let object = try self.get(index)

            self.fetchResultsController.managedObjectContext.deleteObject(object)

            NSFetchedResultsController.deleteCacheWithName(cacheName)
            _ = try? self.fetchResultsController.performFetch()
        } catch RNewsError.Database(let error) {
            throw error
        } catch {
            throw RNewsError.Database(.Unknown)
        }
    }

    func filter(predicate: NSPredicate) -> CoreDataFetchResultsController<T> {
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [self.predicate, predicate])
        return self.applyPredicate(compoundPredicate)
    }

    func combine(fetchResultsController: CoreDataFetchResultsController<T>) -> CoreDataFetchResultsController<T> {
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [self.predicate,
            fetchResultsController.predicate])
        return self.applyPredicate(compoundPredicate)
    }

    private var predicate: NSPredicate {
        return self.fetchResultsController.fetchRequest.predicate ?? NSPredicate(value: true)
    }

    private func applyPredicate(predicate: NSPredicate) -> CoreDataFetchResultsController<T> {
        let fetchRequest = self.fetchResultsController.fetchRequest
        return CoreDataFetchResultsController<T>(entityName: fetchRequest.entityName ?? "",
                                                 managedObjectContext: self.fetchResultsController.managedObjectContext,
                                                 sortDescriptors: fetchRequest.sortDescriptors ?? [],
                                                 predicate: predicate)
    }
}
