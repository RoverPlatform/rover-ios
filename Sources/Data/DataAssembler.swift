//
//  DataAssembler.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-06-01.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData

public class DataAssembler: Assembler {

    public init() { }

    public func assemble(container: Container) {

        // MARK: Core Data

        container.register(NSManagedObjectContext.self, name: "backgroundContext") { resolver in
            let container = resolver.resolve(NSPersistentContainer.self)!
            let context = container.newBackgroundContext()
            context.mergePolicy = NSOverwriteMergePolicy
            return context
        }

        container.register(NSManagedObjectContext.self, name: "viewContext") { resolver in
            let container = resolver.resolve(NSPersistentContainer.self)!
            return container.viewContext
        }

        container.register(NSPersistentContainer.self) { _ in
            let bundles = [Bundle(for: DataAssembler.self)]
            guard let model = NSManagedObjectModel.mergedModel(from: bundles) else {
                fatalError("Model not found")
            }

            let container = NSPersistentContainer(name: "Rover", managedObjectModel: model)
            container.loadPersistentStores { _, error in
                guard error == nil else {
                    fatalError("Failed to load store: \(error!)")
                }
            }

            return container
        }

        // MARK: Event Pipeline

        container.register(EventPipeline.self) { resolver in
            return EventPipeline(
                managedObjectContext: resolver.resolve(NSManagedObjectContext.self, name: "backgroundContext")!
            )
        }

        // MARK: ExperienceStore

        container.register(ExperienceStore.self) { _ in
            return ExperienceStore()
        }
    }

    public func containerDidAssemble(resolver: Resolver) {
        resolver.resolve(EventPipeline.self)!.deviceInfoProvider = resolver.resolve(DeviceInfoProvider.self)!
    }
}
