import Foundation
import RealmSwift
import Result

final class RealmFetchResultsController: FetchResultsController {
    typealias Element=Object

    let predicate: NSPredicate
    private let realmConfiguration: Realm.Configuration
    private let sortDescriptors: [SortDescriptor]
    private let model: Object.Type

    private func realm() throws -> Realm {
        return try Realm(configuration: realmConfiguration)
    }

    private var realmObjects: Result<Results<Element>, RNewsError> {
        get {
            do {
                let realm = try Realm(configuration: self.realmConfiguration)
                let objects = realm.objects(self.model).filter(self.predicate).sorted(self.sortDescriptors)
                return .Success(objects)
            } catch {
                return Result.Failure(.Database(.Unknown))
            }
        }
    }

    init(configuration: Realm.Configuration, model: Object.Type, sortDescriptors: [SortDescriptor], predicate: NSPredicate) {
        self.realmConfiguration = configuration
        self.model = model
        self.sortDescriptors = sortDescriptors
        self.predicate = predicate
    }

    var count: Int {
        switch self.realmObjects {
        case let .Success(objects):
            return objects.count
        case .Failure(_):
            return 0
        }
    }

    func get(index: Int) throws -> Element {
        switch self.realmObjects {
        case let .Success(objects):
            if index < 0 || index >= self.count {
                throw RNewsError.Database(.EntryNotFound)
            }
            return objects[index]
        case let .Failure(error):
            throw error
        }
    }

    func insert(item: Element) throws {
        do {
            let realm = try Realm(configuration: self.realmConfiguration)
            if realm.inWriteTransaction {
                realm.add(item)
            } else {
                try realm.write {
                    realm.add(item)
                }
            }
        } catch {
            throw RNewsError.Database(.Unknown)
        }
    }

    func delete(index: Int) throws {
        let object = try self.get(index)

        do {
            let realm = try Realm(configuration: self.realmConfiguration)
            if realm.inWriteTransaction {
                realm.delete(object)
            } else {
                try realm.write {
                    realm.delete(object)
                }
            }
        } catch {
            throw RNewsError.Database(.Unknown)
        }
    }

    func replacePredicate(predicate: NSPredicate) -> RealmFetchResultsController {
        return RealmFetchResultsController(configuration: self.realmConfiguration,
                                           model: self.model,
                                           sortDescriptors: self.sortDescriptors,
                                           predicate: predicate)
    }
}

func == (lhs: RealmFetchResultsController, rhs: RealmFetchResultsController) -> Bool {
    return lhs.model == rhs.model &&
        lhs.sortDescriptors == rhs.sortDescriptors &&
        lhs.predicate == rhs.predicate
}
