//
//  Sticker+CoreDataProperties.swift
//  PhotoStickers
//
//  Created by Jochen Pfeiffer on 01/01/2017.
//  Copyright © 2017 Jochen Pfeiffer. All rights reserved.
//

import Foundation
import CoreData
import RxDataSources
import RxCoreData
import Log

func == (lhs: Sticker, rhs: Sticker) -> Bool {
    return lhs.uuid == rhs.uuid
}

extension Sticker: Equatable {}

extension Sticker: IdentifiableType {
    typealias Identity = String

    var identity: Identity { return uuid }
}

extension Sticker: Persistable {
    typealias T = NSManagedObject

    static var entityName: String {
        return "Sticker"
    }

    static var primaryAttributeName: String {
        return "uuid"
    }

    init(entity: T) {
        uuid = entity.value(forKey: "uuid") as! String
        stickerPath = entity.value(forKey: "stickerPath") as? String
        stickerDescription = entity.value(forKey: "stickerDescription") as? String
        sortOrder = entity.value(forKey: "sortOrder") as! Int
    }

    func update(_ entity: T) {
        entity.setValue(uuid, forKey: "uuid")
        entity.setValue(stickerPath, forKey: "stickerPath")
        entity.setValue(stickerDescription, forKey: "stickerDescription")
        entity.setValue(sortOrder, forKey: "sortOrder")

        do {
            try entity.managedObjectContext?.save()
        } catch let e {
            Logger.shared.error(e)
        }
    }
}