import CoreData
import Foundation
import SwiftData

final class PersistenceController {
    static let shared = PersistenceController()

    let modelContainer: ModelContainer

    private init(inMemory: Bool = false) {
        let schema = Schema([
            TransactionRecord.self,
            CustomOption.self,
            RecordAttachment.self,
            UserProfile.self,
            AppPreferences.self,
            SyncedAppNotification.self
        ])

        if inMemory {
            do {
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Could not create in-memory ModelContainer: \(error)")
            }
            return
        }

        if PersistenceConfiguration.cloudKitSyncEnabled {
            CloudKitLegacyStoreMigrator.migrateIfNeeded()
        }

        let storeURL = PersistenceConfiguration.activeStoreURL

        do {
            let configuration = Self.makeStoreConfiguration(schema: schema, storeURL: storeURL)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            #if DEBUG
            print("ModelContainer load failed, attempting store repair: \(error)")
            #endif
            SwiftDataStoreRepair.removeStoreFiles(at: storeURL)
            CloudKitLegacyStoreMigrator.migrateIfNeeded()
            do {
                let configuration = Self.makeStoreConfiguration(schema: schema, storeURL: storeURL)
                modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Could not create ModelContainer after repair: \(error)")
            }
        }
    }

    static func inMemoryForPreviews() -> PersistenceController {
        PersistenceController(inMemory: true)
    }

    @MainActor
    func newBackgroundContext() -> ModelContext {
        let context = ModelContext(modelContainer)
        context.applyCloudKitMergeDefaults()
        return context
    }

    @MainActor
    func configure(_ context: ModelContext) {
        context.applyCloudKitMergeDefaults()
    }

    var persistentCloudKitContainer: NSPersistentCloudKitContainer? {
        guard PersistenceConfiguration.cloudKitSyncEnabled else { return nil }
        return PersistentStoreLocator.cloudKitContainer(in: modelContainer)
    }

    #if DEBUG && targetEnvironment(simulator)
    func initializeCloudKitSchemaForSimulatorDebugging() throws {
        guard PersistenceConfiguration.cloudKitSyncEnabled else { return }
        guard let container = persistentCloudKitContainer else { return }
        try container.initializeCloudKitSchema()
    }
    #endif

    private static func makeStoreConfiguration(schema: Schema, storeURL: URL) -> ModelConfiguration {
        if PersistenceConfiguration.cloudKitSyncEnabled {
            return ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .private(PersistenceConfiguration.cloudKitContainerIdentifier)
            )
        }
        return ModelConfiguration(schema: schema, url: storeURL)
    }
}
