//
//  ViewController.swift
//  SCMorse
//
//  Created by Nikola Andriiev on 11.11.16.
//  Copyright © 2016 Andriiev.Mykola. All rights reserved.
//

import UIKit
import RxSwift

class ViewController: UIViewController {
    
    @IBOutlet var textView: UITextView!
    @IBOutlet var onSpeachButton: UIButton!
    
    let disposeBag = DisposeBag()
    let speachRecognizer = SpeechRecognizerContext(locale: Locale(identifier: "ru_RU"))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.speachRecognizer.requestAutorization()
    }

    @IBAction func onSpeach(_ sender: UIButton) {
        if self.speachRecognizer.isRecording == true {
            self.speachRecognizer.stopRecording()
        } else {
            self.speachRecognizer.startRecording().subscribe {
                switch $0 {
                    case.next(let result): self.textView.text = result
                    case.error(let error): print("\(error)")
                    default: return
                }
            }.addDisposableTo(self.disposeBag)
        }
    }
}

