//
//  YPCropVideoView.swift
//  YPImagePicker
//
//  Created by kev on 9/28/22.
//  Copyright © 2022 Yummypets. All rights reserved.
//

import UIKit
import Stevia

final class YPCropVideoView: UIView {
	
	let containerView = UIView()
	let videoView = YPVideoView()
	let topCurtain = UIView()
	let bottomCurtain = UIView()
	let leadingCurtain = UIView()
	let trailingCurtain = UIView()
	let toolbar = UIToolbar()
	let cropArea = YPCropAreaView()
	let grid = YPGridView()

	private let defaultCurtainPadding: CGFloat = 15
	private var isCircle: Bool {
		if case YPCropType.circle = YPConfig.showsVideoCropper {
			return true
		}
		return false
	}

	convenience init(video: YPMediaVideo) {
		
		self.init(frame: .zero)
		
		let ratio: Double
		switch YPConfig.showsVideoCropper {
		case .rectangle(ratio: let configuredRatio):
			ratio = configuredRatio
		default:
			ratio = 1
		}
		
		setupViewHierarchy()
		setupLayout(with: video.thumbnail, ratio: ratio)
		setupImage(video.thumbnail, with: ratio)
		applyStyle()
		videoView.previewImageView.image = video.thumbnail
		videoView.loadVideo(video)
		containerView.clipsToBounds = true
		grid.isCircle = isCircle
		grid.isHidden = !YPConfig.showsCropGridOverlay
	}
		
	private func setupViewHierarchy() {
		
		subviews(
			containerView.subviews(
				videoView,
				topCurtain,
				leadingCurtain,
				trailingCurtain,
				bottomCurtain,
				cropArea,
				grid
			),
			toolbar
		)
	}
	
	private func setupLayout(with image: UIImage, ratio: Double) {
		
		let horizontalCurtainMinWidth: CGFloat = ratio < 1 ? defaultCurtainPadding : 0
		
		containerView.leading(0)
		containerView.trailing(0)
		
		topCurtain.height(>=defaultCurtainPadding)
		bottomCurtain.height(>=defaultCurtainPadding)
		
		leadingCurtain.width(>=horizontalCurtainMinWidth)
		leadingCurtain.Top == topCurtain.Bottom
		leadingCurtain.Bottom == bottomCurtain.Top
		
		trailingCurtain.width(>=horizontalCurtainMinWidth)
		trailingCurtain.Top == topCurtain.Bottom
		trailingCurtain.Bottom == bottomCurtain.Top
	
		cropArea.Top == topCurtain.Bottom
		cropArea.Bottom == bottomCurtain.Top
		  
		|leadingCurtain--0--cropArea--0--trailingCurtain|

		grid.followEdges(cropArea)
		
		layout(
			0,
			|containerView|,
			|toolbar| ~ 44
		)
		
		layout(
			0,
			|topCurtain|,
			|cropArea|,
			|bottomCurtain|,
			0
		)
	
		if #available(iOS 11.0, *) {
			toolbar.Bottom == safeAreaLayoutGuide.Bottom
		} else {
			toolbar.bottom(0)
		}
				
		let complementRatio: CGFloat = CGFloat(1.0 / ratio)
		cropArea.Height == cropArea.Width * complementRatio
		cropArea.centerInContainer()
	}
	
	private func setupImage(_ image: UIImage, with ratio: Double) {
		
		// Fit image differently depnding on its ratio.
		let imageRatio: Double = Double(image.size.width / image.size.height)
		if ratio > imageRatio {
			let screenWidth = YPImagePickerConfiguration.screenWidth
			let scaledDownRatio = screenWidth / image.size.width
			videoView.width(image.size.width * scaledDownRatio)
			videoView.centerInContainer()
		} else if ratio < imageRatio {
			videoView.Height == cropArea.Height
			videoView.centerInContainer()
		} else {
			videoView.followEdges(cropArea)
		}
		
		// Fit videoView to image's bounds
		videoView.Width == videoView.Height * CGFloat(imageRatio)
	}
	
	private func applyStyle() {
		
		backgroundColor = .ypSystemBackground
		clipsToBounds = true
		
		videoView.style { i in
			i.isUserInteractionEnabled = true
			i.isMultipleTouchEnabled = true
		}
		
		topCurtain.style(curtainStyle)
		bottomCurtain.style(curtainStyle)
		leadingCurtain.style(curtainStyle)
		trailingCurtain.style(curtainStyle)
		
		cropArea.style { v in
			v.backgroundColor =  isCircle ? YPConfig.colors.cropOverlayColor : .clear
			v.isCircle = isCircle
			v.isUserInteractionEnabled = false
		}
		
		toolbar.style { t in
			t.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
			t.setShadowImage(UIImage(), forToolbarPosition: .any)
		}
	}
	
	private func curtainStyle(v: UIView) {
		
		v.backgroundColor = YPConfig.colors.cropOverlayColor
		v.isUserInteractionEnabled = false
	}
}
