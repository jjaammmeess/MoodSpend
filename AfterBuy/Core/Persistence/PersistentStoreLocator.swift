import CoreData
import SwiftData

enum PersistentStoreLocator {
    static func cloudKitContainer(in modelContainer: ModelContainer) -> NSPersistentCloudKitContainer? {
        findCloudKitContainer(in: modelContainer)
    }

    private static func findCloudKitContainer(in object: Any) -> NSPersistentCloudKitContainer? {
        if let container = object as? NSPersistentCloudKitContainer {
            return container
        }
        let mirror = Mirror(reflecting: object)
        for child in mirror.children {
            if let found = findCloudKitContainer(in: child.value) {
                return found
            }
        }
        return nil
    }
}
