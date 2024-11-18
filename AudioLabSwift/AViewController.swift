//
//  AViewController.swift
//  AudioLabSwift
//
//  Created by Ruthiwik  on 10/8/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit

struct AudioConstants {
    static let AUDIO_BUFFER_SIZE = 1024 * 4
}

class AViewController: UIViewController {
    
    var audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    var frequencyLabel1: UILabel!
    var frequencyLabel2: UILabel!
    var vowelLabel: UILabel!  // To Label for vowel detection
    
    var lastFreq1: Float?
    var lastFreq2: Float?
    let magnitudeThreshold: Float = 0.01
    
    var noiseTimeoutCounter: Int = 0 // To detect if we've seen noise for a while
    let noiseTimeoutLimit: Int = 10

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Module A"
        
        // To initialize frequency and vowel labels
        setupFrequencyLabels()

        // To start microphone processing
        audio.startMicrophoneProcessing(withFps: 10)
        audio.play()
        

        // To setup a timer to update the UI with frequency data
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateFrequencyLabels), userInfo: nil, repeats: true)
        
    }
    
    func setupFrequencyLabels() {
         frequencyLabel1 = UILabel(frame: CGRect(x: 50, y: 350, width: 300, height: 40))
         frequencyLabel1.text = "Frequency 1: ---"
         frequencyLabel1.textAlignment = .center
         self.view.addSubview(frequencyLabel1)
         
         frequencyLabel2 = UILabel(frame: CGRect(x: 50, y: 400, width: 300, height: 40))
         frequencyLabel2.text = "Frequency 2: ---"
         frequencyLabel2.textAlignment = .center
         self.view.addSubview(frequencyLabel2)
         
         vowelLabel = UILabel(frame: CGRect(x: 50, y: 450, width: 300, height: 40))
         vowelLabel.text = "Vowel: ---"
         vowelLabel.textAlignment = .center
         self.view.addSubview(vowelLabel)
     }
     
     // This is a function that updates the frequency and vowel labels
     @objc func updateFrequencyLabels() {
         let (freq1, freq2) = audio.getTwoLoudestFrequencies(threshold: magnitudeThreshold)
         
         // If we are having both frequencies are significant (above threshold)
         if let f1 = freq1, let f2 = freq2 {
             lastFreq1 = f1
             lastFreq2 = f2
             frequencyLabel1.text = String(format: "Frequency 1: %.2f Hz", f1)
             frequencyLabel2.text = String(format: "Frequency 2: %.2f Hz", f2)
             noiseTimeoutCounter = 0 // Reset noise counter as valid frequencies are detected
         } else if let f1 = freq1 {
             // If only 1 frequency is significant
             lastFreq1 = f1
             frequencyLabel1.text = String(format: "Frequency 1: %.2f Hz", f1)
             frequencyLabel2.text = "Frequency 2: ---"
             noiseTimeoutCounter = 0
         } else if let f2 = freq2 {
             // If Only 1 frequency is significant
             lastFreq2 = f2
             frequencyLabel1.text = "Frequency 1: ---"
             frequencyLabel2.text = String(format: "Frequency 2: %.2f Hz", f2)
             noiseTimeoutCounter = 0
         } else {
             // If no significant frequencies detected
             noiseTimeoutCounter += 1
         }
         
         // If no significant frequencies detected for a while, show "Noise"
         if noiseTimeoutCounter >= noiseTimeoutLimit {
             frequencyLabel1.text = "Noise"
             frequencyLabel2.text = "Noise"
             vowelLabel.text = "Vowel: Noise"  // Also show "Noise" in vowel label
         }
         
         if let validFreq1 = lastFreq1, let validFreq2 = lastFreq2 {
             print("Classifying Vowel: F1: \(validFreq1), F2: \(validFreq2)") // Debug
             classifyVowelSound(f1: validFreq1, f2: validFreq2)
         }
     }
     
    // To classify vowel sounds based on the detected formant frequencies.
    func classifyVowelSound(f1: Float, f2: Float) {
        // To print detected formant frequencies for debugging
        print("Classifying Vowel: F1: \(f1), F2: \(f2)")
        
        if (f1 < 120 && f2 < 140) {
            vowelLabel.text = "Vowel: ahhh"
        } else if (f1 >= 170 && f2 >= 10) {
            vowelLabel.text = "Vowel: ooo"
        }
       
    }

    
    // To stop the audio processing when the view disappears
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        audio.stop()
    }
}


