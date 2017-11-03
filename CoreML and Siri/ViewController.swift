//
//  ViewController.swift
//  CoreML and Siri
//
//  Created by 新闻 on 2017/11/2.
//  Copyright © 2017年 Lvmama. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    @IBOutlet var captureView: UIView!
    @IBOutlet var textView: UITextView!  // 显示识别结果
    
    var synthe = AVSpeechSynthesizer()
    var uttrence = AVSpeechUtterance()
    var predicte = ""
    
    var captureSession : AVCaptureSession!
    var cameraOutput : AVCapturePhotoOutput!
    var previewLayer : AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureView.backgroundColor = UIColor.red
        setupCamera()
    }

    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        cameraOutput = AVCapturePhotoOutput()
        
        let device = AVCaptureDevice.default(for: .video)
        if let input = try? AVCaptureDeviceInput.init(device: device!) {
            if(captureSession.canAddInput(input)) {
                captureSession.addInput(input)
                
                if(captureSession.canAddOutput(cameraOutput)) {
                    captureSession.addOutput(cameraOutput)
                }
                
                previewLayer = AVCaptureVideoPreviewLayer.init(session: captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = captureView.frame
                captureView.layer.addSublayer(previewLayer)
                captureSession.startRunning()
            }
        }
        
        launchUI()
    }
    
    func launchUI() {
        let setting = AVCapturePhotoSettings()
        // xcode9的Bug（availablePreviewPhotoPixelFormatTypes前需加上双下划线）
        let previewPixelType = setting.__availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [ kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                              kCVPixelBufferWidthKey as String: "\(captureView.bounds.size.width)",
                              kCVPixelBufferHeightKey as String: "\(captureView.bounds.size.height)"] as [String : Any]
        setting.previewPhotoFormat = previewFormat
        cameraOutput.capturePhoto(with: setting, delegate: self)
    }
    
    // AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            print("error occured: \(error!.localizedDescription)")
        }

        if let imageData = photo.fileDataRepresentation(),let image = UIImage.init(data: imageData) {
           self.predict(image: image)
        }
    }
    
    // 预测
    func predict(image:UIImage) {
//        if let data = UIImagePNGRepresentation(image) {
//            let fileName = getDocumentsDirectory().appendingPathComponent("captureImage")
//            print("fleName:\(fileName)")
//            try? data.write(to: fileName)
//        }
        let model = try! VNCoreMLModel.init(for: VGG16().model)
        let request = VNCoreMLRequest.init(model: model, completionHandler: { (request:VNRequest, error:Error?) in
            weak var weakSelf = self
            guard let results = request.results as? [VNClassificationObservation] else {
                fatalError("no result")
            }
            var bestPrediction = ""
            var bestConfidence:VNConfidence = 0
            
            // 获取最优值
            for classfication:VNClassificationObservation in results {
                if classfication.confidence > bestConfidence {
                    bestConfidence = classfication.confidence
                    bestPrediction = classfication.identifier
                }
            }
            
            // 显示分析结果
            weakSelf!.textView.text = weakSelf!.textView.text + "\n" + bestPrediction
            let stringLength: Int = weakSelf!.textView.text.characters.count
            weakSelf!.textView.scrollRangeToVisible(NSMakeRange(stringLength-1, 0))
            
            // 语音播报
            weakSelf!.say(string: "我猜这是\(bestPrediction)")
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5, execute: {
                weakSelf!.launchUI()
            })
            
        })
        let handler = VNImageRequestHandler.init(cgImage: image.cgImage!)
        try? handler.perform([request])
    }
    
    
    
    func say(string: String) {
        uttrence = AVSpeechUtterance.init(string: string)
        // 播放速度
        uttrence.rate = 0.3
        // 选择语音发音(不管设置什么 英文都支持)
        uttrence.voice = AVSpeechSynthesisVoice.init(language: "zh_CN")
        // 音调(0.5~2)
        uttrence.pitchMultiplier = 0.8
        // 在播放下一句的时候设置暂停时间
        uttrence.postUtteranceDelay = 0.2

        synthe.speak(uttrence)
    }

    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }

}

