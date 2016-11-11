//
//  SpeechRecognizerContext.swift
//  Morse speech converter
//
//  Created by Nikola Andriiev on 11.11.16.
//  Copyright © 2016 Andriiev.Mykola. All rights reserved.
//

import UIKit
import Speech
import RxSwift
import RxCocoa

extension SpeechRecognizerContext: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        self.isRecognizerAvaliable = Driver.just(available)
    }
}

class SpeechRecognizerContext: NSObject {
    private let audioEngine = AVAudioEngine()
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: Public observable Variables
    public var isRecognizerAvaliable: Driver<Bool>?
    
    // MARK: Public variables
    public var isRecording: Bool { return audioEngine.isRunning }
    
    // MARK: Public methods
    public init( locale: Locale) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        super.init()
    }
    
    public func requestAutorization() {
        SFSpeechRecognizer.requestAuthorization {
            switch $0 {
                case.authorized: print("authorized")
                case.denied: print("denied")
                case.notDetermined: print("notDetermined")
                case.restricted: print("restricted")
            }
        }
    }
    
    public func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
    }
    
     //will notyfy when SpeechRecognizer convert model speach to string or Error result
    public func startRecording() -> Observable<String> {
        return Observable<String>.create{ observer -> Disposable in
            self.calcelTask()
            
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(AVAudioSessionCategoryRecord)
                try audioSession.setMode(AVAudioSessionModeMeasurement)
                try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
            } catch {
                let error = NSError(domain:"something wrong with audioSession", code: 1, userInfo: nil)
                observer.onError(error)
            }
            
            guard let inputNode = self.audioEngine.inputNode else {
                let error = NSError(domain:"Audio engine has no input node", code: 2, userInfo: nil)
                observer.onError(error)
                return Disposables.create()
            }
            
            let request = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest = request
        
            self.recognitionTask = self.speechRecognizer?.recognitionTask(with: request,
                resultHandler: { (result, error) in
                    if let error = error {
                        observer.onError(error)
                    }
                    
                    var isFinal = false
                    if result != nil {
                        if let string = result?.bestTranscription.formattedString {
                            observer.onNext(string)
                        }
                        
                        isFinal = (result?.isFinal)!
                    }
                
                    if error != nil || isFinal {
                        self.audioEngine.stop()
                        inputNode.removeTap(onBus: 0)
                        observer.onCompleted()
                        self.recognitionRequest = nil
                        self.recognitionTask = nil
                    }
                })

            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
                self.recognitionRequest?.append(buffer)
            }
            
            self.audioEngine.prepare()
            do {
                try self.audioEngine.start()
            } catch {
                let error = NSError(domain:"AudioEngine couldn't start because of an error.", code: 2, userInfo: nil)
                observer.onError(error)
            }
            
             return Disposables.create {
                self.stopRecording()
                self.calcelTask()
            }
            
        }.observeOn(MainScheduler.asyncInstance)
    }
    
    // MARK: Private methods
    private func calcelTask() {
        if  self.recognitionTask != nil {
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
        }
    }
}

