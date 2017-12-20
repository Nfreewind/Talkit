//
//  SpeechRecognizer.swift
//  SpeakSwiftly
//
//  Created by Daniel Leong on 5/8/15.
//  Copyright (c) 2015 Daniel Leong. All rights reserved.
//

import UIKit
import Speech

class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {

    private var speechRecognizer: SFSpeechRecognizer!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest!
    private var recognitionTask: SFSpeechRecognitionTask!
    private let audioEngine = AVAudioEngine()
    private let locale = Locale(identifier: "en-US")
    var resultStringTemp: String = ""
    var resultStrings: [String] = [String]()

    func load() {
        print("load")
        prepareRecognizer(locale: locale)
        
        authorize()
    }
    
    func start() {
        print("start")
        if !audioEngine.isRunning {
            try! startRecording()
        }
    }
    
    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
    }
    
    func getResultStrings() -> [String] {
        return resultStrings
    }
    
    func authorize() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            /*
             The callback may not be called on the main thread. Add an
             operation to the main queue to update the record button's state.
             */
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    print("Authorized!")
                case .denied:
                    print("Unauthorized!")
                case .restricted:
                    print("Unauthorized!")
                case .notDetermined:
                    print("Unauthorized!")
                }
            }
        }
    }

    private func prepareRecognizer(locale: Locale) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)!
        speechRecognizer.delegate = self
    }
    
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.resultStringTemp = result.bestTranscription.formattedString
                self.resultStrings.append(self.resultStringTemp)
                print(self.resultStringTemp)
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        try audioEngine.start()
        
    }

    // =========================================================================
    // MARK: - SFSpeechRecognizerDelegate
    
    /*public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordBtn.isEnabled = true
            recordBtn.setTitle("Start Recording", for: [])
        } else {
            recordBtn.isEnabled = false
            recordBtn.setTitle("Recognition not available", for: .disabled)
        }
    }*/
}

