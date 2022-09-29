//
//  YPCropVideoVC.swift
//  YPImagePicker
//
//  Created by kev on 9/28/22.
//  Copyright © 2022 Yummypets. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import VideoConverter

class YPCropVideoVC: UIViewController {
	
	public var didFinishCropping: ((YPMediaVideo) -> Void)?
	
	override var prefersStatusBarHidden: Bool { return YPConfig.hidesStatusBar }
	
	private let originalVideo: YPMediaVideo
	private let pinchGR = UIPinchGestureRecognizer()
	private let panGR = UIPanGestureRecognizer()
	
	private let v: YPCropVideoView
	override func loadView() { view = v }
	private var videoConverter: VideoConverter?
	
	required init(video: YPMediaVideo) {
		v = YPCropVideoView(video: video)
		originalVideo = video
		super.init(nibName: nil, bundle: nil)
		self.title = YPConfig.wordings.crop
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupToolbar()
		setupGestureRecognizers()
	}
	
	func setupToolbar() {
		let cancelButton = UIBarButtonItem(title: YPConfig.wordings.cancel,
										   style: .plain,
										   target: self,
										   action: #selector(cancel))
		cancelButton.tintColor = .ypLabel
		cancelButton.setFont(font: YPConfig.fonts.leftBarButtonFont, forState: .normal)
		
		let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		
		let saveButton = UIBarButtonItem(title: YPConfig.wordings.save,
										   style: .plain,
										   target: self,
										   action: #selector(done))
		saveButton.setFont(font: YPConfig.fonts.rightBarButtonFont, forState: .normal)
		saveButton.tintColor = .ypLabel
		v.toolbar.items = [cancelButton, flexibleSpace, saveButton]
	}
	
	func setupGestureRecognizers() {
		// Pinch Gesture
		pinchGR.addTarget(self, action: #selector(pinch(_:)))
		pinchGR.delegate = self
		v.videoView.addGestureRecognizer(pinchGR)
		
		// Pan Gesture
		panGR.addTarget(self, action: #selector(pan(_:)))
		panGR.delegate = self
		v.videoView.addGestureRecognizer(panGR)
	}
	
	@objc
	func cancel() {
		navigationController?.popViewController(animated: true)
	}
	
	@objc
	func done() {
		guard let thumbnail = v.videoView.previewImageView.image else {
			return
		}
		
		// crop image
		let xCrop = v.cropArea.frame.minX - v.videoView.frame.minX
		let yCrop = v.cropArea.frame.minY - v.videoView.frame.minY
		let widthCrop = v.cropArea.frame.width
		let heightCrop = v.cropArea.frame.height
		let scaleRatio = thumbnail.size.width / v.videoView.frame.width
		let scaledCropRect = CGRect(x: xCrop * scaleRatio,
									y: yCrop * scaleRatio,
									width: widthCrop * scaleRatio,
									height: heightCrop * scaleRatio)
		
		guard let cgImage = thumbnail.toCIImage()?.toCGImage(), let imageRef = cgImage.cropping(to: scaledCropRect) else {
			return
		}
		
		let croppedImage = UIImage(cgImage: imageRef)
		v.videoView.previewImageView.image = croppedImage
		
		// video crop
		guard let item = v.videoView.player.currentItem else {
			return
		}
		
		let frame = self.view.convert(v.cropArea.frame, to: v.videoView)
		self.videoConverter = VideoConverter(asset: item.asset)
		guard let videoConverter = self.videoConverter else { return }
		let videoConverterCrop = ConverterCrop(frame: frame, contrastSize: v.videoView.playerLayer.videoRect.size)
		
		let options = ConverterOption(
			trimRange: nil,
			convertCrop: videoConverterCrop,
			rotate: nil,
			quality: nil,
			isMute: false
		)
		videoConverter.convert(options) { [weak self] (url, error) in
			guard let `self` = self else { return }
			if let error = error {
				let alertController = UIAlertController(title: "Uh oh, something went wrong", message: error.localizedDescription, preferredStyle: .alert)
				alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
				self.present(alertController, animated: true)
			} else if let url = url {
				self.v.videoView.loadVideo(url)
				self.didFinishCropping?(YPMediaVideo(thumbnail: thumbnail, videoURL: url))
			}
		}
		
		
	}

}

extension YPCropVideoVC: UIGestureRecognizerDelegate {
	
	// MARK: - Pinch Gesture
	
	@objc
	func pinch(_ sender: UIPinchGestureRecognizer) {
		// TODO: Zoom where the fingers are (more user friendly)
		switch sender.state {
		case .began, .changed:
			var transform = v.videoView.transform
			// Apply zoom level.
			transform = transform.scaledBy(x: sender.scale,
											y: sender.scale)
			v.videoView.transform = transform
		case .ended:
			pinchGestureEnded()
		case .cancelled, .failed, .possible:
			()
		@unknown default:
			ypLog("unknown default reached. Check code.")
		}
		// Reset the pinch scale.
		sender.scale = 1.0
	}
	
	private func pinchGestureEnded() {
		var transform = v.videoView.transform
		let kMinZoomLevel: CGFloat = 1.0
		let kMaxZoomLevel: CGFloat = 3.0
		var wentOutOfAllowedBounds = false
		
		// Prevent zooming out too much
		if transform.a < kMinZoomLevel {
			transform = .identity
			wentOutOfAllowedBounds = true
		}
		
		// Prevent zooming in too much
		if transform.a > kMaxZoomLevel {
			transform.a = kMaxZoomLevel
			transform.d = kMaxZoomLevel
			wentOutOfAllowedBounds = true
		}
		
		// Animate coming back to the allowed bounds with a haptic feedback.
		if wentOutOfAllowedBounds {
			generateHapticFeedback()
			UIView.animate(withDuration: 0.3, animations: {
				self.v.videoView.transform = transform
			})
		}
	}
	
	func generateHapticFeedback() {
		if #available(iOS 10.0, *) {
			let generator = UIImpactFeedbackGenerator(style: .light)
			generator.impactOccurred()
		}
	}
	
	// MARK: - Pan Gesture
	
	@objc
	func pan(_ sender: UIPanGestureRecognizer) {
		let translation = sender.translation(in: view)
		let videoView = v.videoView
		
		// Apply the pan translation to the video.
		videoView.center = CGPoint(x: videoView.center.x + translation.x, y: videoView.center.y + translation.y)
		
		// Reset the pan translation.
		sender.setTranslation(CGPoint.zero, in: view)
		
		if sender.state == .ended {
			keepVideoIntoCropArea()
		}
	}
	
	private func keepVideoIntoCropArea() {
		let videoRect = v.videoView.frame
		let cropRect = v.cropArea.frame
		var correctedFrame = videoRect
		
		// Cap Top.
		if videoRect.minY > cropRect.minY {
			correctedFrame.origin.y = cropRect.minY
		}
		
		// Cap Bottom.
		if videoRect.maxY < cropRect.maxY {
			correctedFrame.origin.y = cropRect.maxY - videoRect.height
		}
		
		// Cap Left.
		if videoRect.minX > cropRect.minX {
			correctedFrame.origin.x = cropRect.minX
		}
		
		// Cap Right.
		if videoRect.maxX < cropRect.maxX {
			correctedFrame.origin.x = cropRect.maxX - videoRect.width
		}
		
		// Animate back to allowed bounds
		if videoRect != correctedFrame {
			UIView.animate(withDuration: 0.3, animations: {
				self.v.videoView.frame = correctedFrame
			})
		}
	}
	
	/// Allow both Pinching and Panning at the same time.
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
						   shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}
}
