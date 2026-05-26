import CoreData
import SwiftData

extension ModelContext {
    func applyCloudKitMergeDefaults() {
        guard let managedObjectContext = underlyingManagedObjectContext else { return }
        managedObjectContext.automaticallyMergesChangesFromParent = true
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private var underlyingManagedObjectContext: NSManagedObjectContext? {
        Mirror(reflecting: self).children.lazy.compactMap { $0.value as? NSManagedObjectContext }.first
    }
}
