//
//  AssetViewController.swift
//  VideoVault
//
//  Created by ljk on 2017/5/23.
//  Copyright © 2017年 flow. All rights reserved.
//

import UIKit
import Photos

public protocol AssetViewControllerDelegate: class {
    func configureLayout(_ layout: UICollectionViewFlowLayout, for assetViewController: AssetViewController) -> Void
    func assets(for assetViewController: AssetViewController) -> PHFetchResult<PHAsset>
    func cellTypeForAssetViewController(_ assetViewController: AssetViewController) -> UICollectionViewCell.Type
    func assetViewController(_ assetViewController: AssetViewController, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath, assetImage: UIImage, asset: PHAsset)
    func assetViewController(_ assetViewController: AssetViewController, didSelectItemAt indexPath: IndexPath)
    
}

public class AssetViewController: UIViewController {
    
    var assets: PHFetchResult<PHAsset>!
    
    public weak var delegate: AssetViewControllerDelegate?
    
    public lazy var collectionView: UICollectionView = { [unowned self] in
        let layout = UICollectionViewFlowLayout()
        
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = UIColor.white
        view.delegate = self
        view.dataSource = self
        view.alwaysBounceVertical = true
        view.showsHorizontalScrollIndicator = false
        return view
        }()
    
    var countLabel: UILabel?
    
    fileprivate let imageManager = PHCachingImageManager()
    fileprivate var thumbnailSize: CGSize!
    fileprivate var previousPreheatRect = CGRect.zero
    
    lazy var options: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        return options
    }()
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        assert(delegate != nil, "必须设置delegate")
        
        assets = self.delegate?.assets(for: self)
        
        self.setupUI()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let cellSize = (collectionView.collectionViewLayout as! UICollectionViewFlowLayout).itemSize
        thumbnailSize = CGSize(width: cellSize.width * UIScreen.main.scale, height: cellSize.height * UIScreen.main.scale)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        updateCachedAssets()
    }
    
    private func setupUI() {
        
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        self.delegate?.configureLayout(layout, for: self)
        
        view.addSubview(collectionView)
        
        let classType = delegate?.cellTypeForAssetViewController(self)
        collectionView.register(classType, forCellWithReuseIdentifier: "cell")
        
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: "footer")
        
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        collectionView.frame = view.bounds
    }
    
}

extension AssetViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        
        return cell
        
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let asset = assets[indexPath.item]
        
        imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: options) { (image, _) in
            guard let image = image else { return }
            self.delegate?.assetViewController(self, willDisplay: cell, forItemAt: indexPath, assetImage: image, asset: asset)
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "footer", for: indexPath)
        let label = view.viewWithTag(110)
        if label == nil, let countLabel = countLabel {
            view.addSubview(countLabel)
        }
        
        return view
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.assetViewController(self, didSelectItemAt: indexPath)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
    }
}

extension AssetViewController {
    func updateCachedAssets() {
        let isVisible = isViewLoaded && view.window != nil
        guard isVisible else { return }
        guard assets.count != 0 else { return }
        
        let preheatRect = view.bounds.insetBy(dx: 0, dy:  -0.5 * view.bounds.height)
        
        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        guard delta > view.bounds.height/3 else { return }
        
        let (addedRects, removedRects) = differencesBetweenRects(previousPreheatRect, preheatRect)
        
        let addedAssets = addedRects
            .flatMap { rect in collectionView.indexPathsForElements(in: rect) }
            .map { indexPath in assets.object(at: indexPath.item) }
        let removedAssets = removedRects
            .flatMap { rect in collectionView.indexPathsForElements(in: rect) }
            .map { indexPath in assets.object(at: indexPath.item) }
        
        imageManager.startCachingImages(for: addedAssets,
                                        targetSize: thumbnailSize, contentMode: .aspectFill, options: options)
        imageManager.stopCachingImages(for: removedAssets,
                                       targetSize: thumbnailSize, contentMode: .aspectFill, options: options)
        
        previousPreheatRect = preheatRect
        
    }
    
    func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: [CGRect], removed: [CGRect]) {
        if old.intersects(new) {
            var added = [CGRect]()
            if new.maxY > old.maxY {
                added += [CGRect(x: new.origin.x, y: old.maxY,
                                 width: new.width, height: new.maxY - old.maxY)]
            }
            if old.minY > new.minY {
                added += [CGRect(x: new.origin.x, y: new.minY,
                                 width: new.width, height: old.minY - new.minY)]
            }
            var removed = [CGRect]()
            if new.maxY < old.maxY {
                removed += [CGRect(x: new.origin.x, y: new.maxY,
                                   width: new.width, height: old.maxY - new.maxY)]
            }
            if old.minY < new.minY {
                removed += [CGRect(x: new.origin.x, y: old.minY,
                                   width: new.width, height: new.minY - old.minY)]
            }
            return (added, removed)
        } else {
            return ([new], [old])
        }
    }
}

private extension UICollectionView {
    func indexPathsForElements(in rect: CGRect) -> [IndexPath] {
        let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect)!
        return allLayoutAttributes.map { $0.indexPath }
    }
}

