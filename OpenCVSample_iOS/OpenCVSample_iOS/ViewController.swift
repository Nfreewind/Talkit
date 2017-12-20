//
//  Chilitags.m
//  OpenCVSample_iOS
//
//  Created by 张倬豪 on 2017/11/7.
//  Copyright © 2017年 Talkit. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

	@IBOutlet weak var imageView: UIImageView!
	
	var session: AVCaptureSession!
	var device: AVCaptureDevice!
	var output: AVCaptureVideoDataOutput!
    var speechRecognizer: SpeechRecognizer! = SpeechRecognizer()
	
	override func viewDidLoad() {
		super.viewDidLoad()
        
        print("load")
        speechRecognizer.load()
        speechRecognizer.start()

		// Prepare a video capturing session.
		self.session = AVCaptureSession()
		self.session.sessionPreset = AVCaptureSession.Preset.vga640x480 // not work in iOS simulator
        for device in AVCaptureDevice.devices() {
			if ((device as AnyObject).position == AVCaptureDevice.Position.back) {
				self.device = device 
			}
		}
		if (self.device == nil) {
			print("no device")
			return
		}
		do {
			let input = try AVCaptureDeviceInput(device: self.device)
			self.session.addInput(input)
		} catch {
			print("no device input")
			return
		}
		self.output = AVCaptureVideoDataOutput()
		self.output.videoSettings = [ kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA) ]
		let queue: DispatchQueue = DispatchQueue(label: "videocapturequeue", attributes: [])
		self.output.setSampleBufferDelegate(self, queue: queue)
		self.output.alwaysDiscardsLateVideoFrames = true
		if self.session.canAddOutput(self.output) {
			self.session.addOutput(self.output)
		} else {
			print("could not add a session output")
			return
		}
		do {
			try self.device.lockForConfiguration()
			self.device.activeVideoMinFrameDuration = CMTimeMake(1, 20) // 20 fps
			self.device.unlockForConfiguration()
		} catch {
			print("could not configure a device")
			return
		}

		self.session.startRunning()
        
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}

	override var shouldAutorotate : Bool {
		return false
	}
    
    //override func viewDidAppear(_ animated: Bool) {
        //super.viewDidAppear(animated)
        
        //speechRecognizer.start()
    //}

	func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		
		// Convert a captured image buffer to UIImage.
		guard let buffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
			print("could not get a pixel buffer")
			return
		}
		let capturedImage: UIImage
		do {
			CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags.readOnly)
			defer {
				CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags.readOnly)
			}
			let address = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)
			let bytes = CVPixelBufferGetBytesPerRow(buffer)
			let width = CVPixelBufferGetWidth(buffer)
			let height = CVPixelBufferGetHeight(buffer)
			let color = CGColorSpaceCreateDeviceRGB()
			let bits = 8
			let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
			guard let context = CGContext(data: address, width: width, height: height, bitsPerComponent: bits, bytesPerRow: bytes, space: color, bitmapInfo: info) else {
				print("could not create an CGContext")
				return
			}
			guard let image = context.makeImage() else {
				print("could not create an CGImage")
				return
			}
			capturedImage = UIImage(cgImage: image, scale: 1.0, orientation: UIImageOrientation.right)
		}
		
		// This is a filtering sample.
		
        // Detect QR code in the image
        var resultImage = myChilitags.detectQRCode(capturedImage)
        if let configFilePath = Bundle.main.path(forResource: "tagYAML", ofType: "yml") {
            myChilitags.estimate3D(capturedImage, second: configFilePath);
        }
        // Detect red fingers in the image
        //resultImage = myOpenCV.detectRed(resultImage)

		// Show the result.
		DispatchQueue.main.async(execute: {
			self.imageView.image = resultImage
		})
	}
}

