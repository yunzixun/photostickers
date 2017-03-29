//
//  StickerInfo.swift
//  PhotoStickers
//
//  Created by Jochen Pfeiffer on 24/02/2017.
//  Copyright © 2017 Jochen Pfeiffer. All rights reserved.
//

import Foundation
import RxSwift

class StickerInfo {

    let uuid: String

    // MARK: initial values
    let initialLocalizedDescription: String
    let initialOriginalImage: UIImage?
    let initialRenderedSticker: UIImage?
    let initialCropBounds: CGRect
    let initialMask: Mask
    let initialSortOrder: Int

    // MARK: updated values
    let localizedDescription: Variable<String>
    let originalImage: Variable<UIImage?>
    let renderedSticker: Variable<UIImage?>
    let cropBounds: Variable<CGRect>
    let mask: Variable<Mask>
    let sortOrder: Variable<Int>

    // MARK: initilizer
    init(uuid: String,
         localizedDescription: String,
         originalImage: UIImage?,
         renderedSticker: UIImage?,
         cropBounds: CGRect,
         mask: Mask,
         sortOrder: Int) {

        self.uuid = uuid

        initialLocalizedDescription = localizedDescription
        initialOriginalImage = originalImage
        initialRenderedSticker = renderedSticker
        initialCropBounds = cropBounds
        initialMask = mask
        initialSortOrder = sortOrder

        self.localizedDescription = Variable(localizedDescription)
        self.originalImage = Variable(originalImage)
        self.renderedSticker = Variable(renderedSticker)
        self.cropBounds = Variable(cropBounds)
        self.mask = Variable(mask)
        self.sortOrder = Variable(sortOrder)
    }

    convenience init() {
        self.init(uuid: "",
                  localizedDescription: "",
                  originalImage: nil,
                  renderedSticker: nil,
                  cropBounds: CGRect.zero,
                  mask: Mask.circle,
                  sortOrder: 0)
    }

    convenience init(sticker: Sticker) {
        self.init(uuid: sticker.uuid,
                  localizedDescription: sticker.localizedDescription,
                  originalImage: sticker.originalImage,
                  renderedSticker: sticker.renderedSticker,
                  cropBounds: sticker.cropBounds,
                  mask: sticker.mask,
                  sortOrder: sticker.sortOrder)
    }

    // MARK: Observers
    var originalImageIsNil: Observable<Bool> {
        return originalImage
            .asObservable()
            .map { $0 == nil }
    }

    var renderedStickerIsNil: Observable<Bool> {
        return renderedSticker
            .asObservable()
            .map { $0 == nil }
    }

    var cropBoundsAreEmpty: Observable<Bool> {
        return cropBounds
            .asObservable()
            .map { $0.isNull || $0.isEmpty }
    }

    // MARK: canges

    var localizedDescriptionDidChange: Bool {
        return localizedDescription.value != initialLocalizedDescription
    }

    var originalImageDidChange: Bool {
        return originalImage.value != initialOriginalImage
    }

    var renderedStickerDidChange: Bool {
        return renderedSticker.value != initialRenderedSticker
    }

    var cropBoundsDidChange: Bool {
        return cropBounds.value != initialCropBounds
    }

    var maskDidChange: Bool {
        return mask.value != initialMask
    }

    var sortOrderDidChange: Bool {
        return sortOrder.value != initialSortOrder
    }
}
