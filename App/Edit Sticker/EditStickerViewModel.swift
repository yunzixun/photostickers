//
//  EditStickerViewModel.swift
//  PhotoStickers
//
//  Created by Jochen Pfeiffer on 23/02/2017.
//  Copyright © 2017 Jochen Pfeiffer. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import Log

protocol EditStickerViewModelType {

    var saveButtonItemDidTap: PublishSubject<Void> { get }
    var cancelButtonItemDidTap: PublishSubject<Void> { get }
    var deleteButtonItemDidTap: PublishSubject<Void> { get }
    var photosButtonItemDidTap: PublishSubject<Void> { get }
    var didPickImage: PublishSubject<UIImage?> { get }
    var scrollViewBoundsDidChange: PublishSubject<CGRect> { get }
    var maskViewBoundsDidChange: PublishSubject<CGRect> { get }
    var stickerTitleDidChange: PublishSubject<String?> { get }

    var stickerTitlePlaceholder: String { get }
    var stickerTitle: String { get }
    var saveButtonItemEnabled: Driver<Bool> { get }
    var deleteButtonItemEnabled: Driver<Bool> { get }
    var stickerPlaceholderHidden: Driver<Bool> { get }
    var image: Driver<UIImage?> { get }
    var contentInset: Driver<UIEdgeInsets> { get }
    var maximumZoomScale: Driver<CGFloat> { get }
    var minimumZoomScale: Driver<CGFloat> { get }
    var zoomScale: Driver<CGFloat> { get }
    var contentOffset: Driver<CGPoint> { get }
    var maskPath: Driver<UIBezierPath> { get }
    var presentImagePicker: Driver<UIImagePickerControllerSourceType> { get }
    var dismiss: Driver<Void> { get }
}

class EditStickerViewModel: BaseViewModel, EditStickerViewModelType {

    let disposeBag = DisposeBag()
    let backgroundScheduler = SerialDispatchQueueScheduler(qos: .default)

    // MARK: Dependencies
    fileprivate let stickerInfo: StickerInfo
    fileprivate let imageStoreService: ImageStoreServiceType
    fileprivate let stickerService: StickerServiceType
    fileprivate let stickerRenderService: StickerRenderServiceType

    // MARK: Input
    let saveButtonItemDidTap = PublishSubject<Void>()
    let cancelButtonItemDidTap = PublishSubject<Void>()
    let deleteButtonItemDidTap = PublishSubject<Void>()
    let photosButtonItemDidTap = PublishSubject<Void>()
    let didPickImage = PublishSubject<UIImage?>()
    let scrollViewBoundsDidChange = PublishSubject<CGRect>()
    let maskViewBoundsDidChange = PublishSubject<CGRect>()
    let stickerTitleDidChange = PublishSubject<String?>()

    // MARK: Output
    let stickerTitlePlaceholder: String
    let stickerTitle: String
    let saveButtonItemEnabled: Driver<Bool>
    let deleteButtonItemEnabled: Driver<Bool>
    let stickerPlaceholderHidden: Driver<Bool>
    var image: Driver<UIImage?>
    var contentInset: Driver<UIEdgeInsets>
    var maximumZoomScale: Driver<CGFloat>
    var minimumZoomScale: Driver<CGFloat>
    var zoomScale: Driver<CGFloat>
    var contentOffset: Driver<CGPoint>
    let maskPath: Driver<UIBezierPath>
    let presentImagePicker: Driver<UIImagePickerControllerSourceType>
    let dismiss: Driver<Void>

    // MARK: Internal
    fileprivate let stickerWasDeleted = PublishSubject<Void>()
    fileprivate let maskRect: Observable<CGRect>
    fileprivate let scrollViewBoundsSizeDidChange: Observable<CGSize>
    fileprivate let originalImageWasSetToNil: Observable<Void>
    fileprivate let stickerWasRendered: Observable<Void>
    fileprivate let stickerWasSaved: Observable<Void>

    init(sticker: Sticker,
         imageStoreService: ImageStoreServiceType,
         stickerService: StickerServiceType,
         stickerRenderService: StickerRenderServiceType) {

        let stickerInfo = StickerInfo(sticker: sticker)
        self.stickerInfo = stickerInfo
        self.imageStoreService = imageStoreService
        self.stickerService = stickerService
        self.stickerRenderService = stickerRenderService

        stickerTitlePlaceholder = "Photo Sticker"
        stickerTitle = stickerInfo.localizedDescription.value

        saveButtonItemEnabled = Observable
            .combineLatest(stickerInfo.originalImageIsNil, stickerInfo.cropBoundsAreEmpty) { !$0 && !$1 }
            .startWith(false)
            .distinctUntilChanged()
            .asDriver(onErrorJustReturn: false)

        deleteButtonItemEnabled = stickerInfo
            .renderedStickerIsNil
            .map { !$0 }
            .startWith(false)
            .distinctUntilChanged()
            .asDriver(onErrorJustReturn: false)

        stickerPlaceholderHidden = self.stickerInfo
            .originalImageIsNil
            .map { !$0 }
            .startWith(true)
            .distinctUntilChanged()
            .asDriver(onErrorJustReturn: false)

        image = self.stickerInfo
            .originalImage
            .asDriver()

        scrollViewBoundsSizeDidChange = scrollViewBoundsDidChange
            .map { $0.size }
            .distinctUntilChanged()

        maskRect = scrollViewBoundsSizeDidChange
            .map { size in
                let boundsMinSideLength = size.minSideLength
                let sideLength = boundsMinSideLength * 0.85
                let inset = (boundsMinSideLength - sideLength) / 2.0
                return CGRect(x: inset, y: inset, width: sideLength, height: sideLength)
            }
            .distinctUntilChanged()

        maskPath = Observable
            .combineLatest(self.stickerInfo.mask.asObservable(),
                           maskViewBoundsDidChange,
                           maskRect)
            .map { mask, bounds, maskRect in
                return mask.maskPath(in: bounds, maskRect: maskRect)
            }
            .asDriver(onErrorJustReturn: UIBezierPath())

        contentInset = Observable
            .combineLatest(scrollViewBoundsDidChange,
                           maskRect)
            .map { bounds, maskRect in
                var contentInset = UIEdgeInsets()
                contentInset.top = maskRect.minY
                contentInset.left = maskRect.minX
                contentInset.right = bounds.width - maskRect.maxX
                contentInset.right = bounds.height - maskRect.maxY
                return contentInset
            }
            .distinctUntilChanged()
            .asDriver(onErrorJustReturn: UIEdgeInsets.zero)

        maximumZoomScale = maskRect
            .map { maskRect in
                let minimumZoomedImageSize = Sticker.renderedSize
                guard minimumZoomedImageSize.width > 0 && minimumZoomedImageSize.height > 0 else {
                    return 1
                }

                let xScale = maskRect.width / minimumZoomedImageSize.width
                let yScale = maskRect.height / minimumZoomedImageSize.height
                let maxScale = min(xScale, yScale)
                return maxScale
            }
            .distinctUntilChanged()
            .asDriver(onErrorJustReturn: 1)

        minimumZoomScale = Observable
            .combineLatest(self.stickerInfo.originalImage.asObservable(), maskRect)
            .map { image, maskRect in
                let imageSize = image?.size ?? .zero
                guard imageSize.width > 0 && imageSize.height > 0 else {
                    return 1
                }

                let xScale = maskRect.width / imageSize.width
                let yScale = maskRect.height / imageSize.height
                let minScale = max(xScale, yScale)
                return minScale
            }
            .distinctUntilChanged()
            .asDriver(onErrorJustReturn: 1)

        //
        //        self.originalImageDidChange = self.stickerInfo
        //            .originalImage
        //            .asObservable()
        //            .map { _ in Void() }

        zoomScale = Observable
            .combineLatest(self.stickerInfo.cropBounds.asObservable(),
                           maskRect,
                           minimumZoomScale.asObservable(),
                           maximumZoomScale.asObservable())
            .map { maskRect, cropBounds, minimumZoomScale, maximumZoomScale in
                guard cropBounds.width > 0 && cropBounds.height > 0 else {
                    return minimumZoomScale
                }

                let xScale = maskRect.width / cropBounds.width
                let yScale = maskRect.height / cropBounds.height
                var scale = min(xScale, yScale)
                scale = max(scale, minimumZoomScale)
                scale = min(scale, maximumZoomScale)
                return scale
            }
            .distinctUntilChanged()
            .asDriver(onErrorJustReturn: 1)

        contentOffset = Observable
            .combineLatest(self.stickerInfo.cropBounds.asObservable(),
                           maskRect,
                           zoomScale.asObservable())
            .map { maskRect, cropBounds, zoomScale in
                var contentOffset = CGPoint()
                contentOffset.x = cropBounds.minX * zoomScale - maskRect.minX
                contentOffset.y = cropBounds.minY * zoomScale - maskRect.minY
                return contentOffset
            }
            .distinctUntilChanged()
            .debug("contentOffset")
            .asDriver(onErrorJustReturn: .zero)

        originalImageWasSetToNil = self.stickerInfo
            .originalImageIsNil
            .filter { $0 }
            .map { _ in Void() }

        presentImagePicker = Observable
            .of(photosButtonItemDidTap, originalImageWasSetToNil)
            .merge()
            .map {
                return .photoLibrary
            }
            .asDriver(onErrorJustReturn: .photoLibrary)

        stickerWasRendered = self.stickerInfo
            .renderedSticker
            .asObservable()
            .skip(1)
            .map { _ in Void() }

        stickerWasSaved = stickerWasRendered
            .asObservable()
            .flatMap {
                return stickerService.storeSticker(withInfo: stickerInfo)
            }
            .map { _ in Void() }

        dismiss = Observable
            .of(cancelButtonItemDidTap, stickerWasSaved, stickerWasDeleted)
            .merge()
            .asDriver(onErrorJustReturn: Void())

        super.init()

        didPickImage
            .filterNil()
            .bindTo(stickerInfo.originalImage)
            .disposed(by: disposeBag)

        stickerTitleDidChange
            .map { title in
                return title?.trimmingCharacters(in: .whitespaces) ?? ""
            }
            .bindTo(stickerInfo.localizedDescription)
            .disposed(by: disposeBag)

        saveButtonItemDidTap
            .withLatestFrom(saveButtonItemEnabled)
            .filter { isEnabled in isEnabled }
            .observeOn(backgroundScheduler)
            .flatMap { _ in
                return stickerRenderService.render(stickerInfo).asDriver(onErrorJustReturn: nil)
            }
            .filterNil()
            .bindTo(self.stickerInfo.renderedSticker)
            .disposed(by: disposeBag)

        deleteButtonItemDidTap
            .withLatestFrom(deleteButtonItemEnabled)
            .filter { isEnabled in isEnabled }
            .observeOn(backgroundScheduler)
            .flatMap { _ in
                stickerService.deleteSticker(withUUID: stickerInfo.uuid).asDriver(onErrorJustReturn: Void())
            }
            .bindTo(stickerWasDeleted)
            .disposed(by: disposeBag)
    }
}
