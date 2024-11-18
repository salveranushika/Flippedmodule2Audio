//
//  BViewController.swift
//  AudioLabSwift
//
//  Created by Ruthiwik on 10/8/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit



class BViewController: UIViewController {

    var audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    
    // To store the last frequency to detect Doppler shifts
    var lastFrequency: Float = 0.0
    
    // To create a slider to control tone frequency
    let frequencySlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 17000 // Min frequency
        slider.maximumValue = 20000 // Max frequency
        slider.value = 18000        // Def frequency
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    // These are the labels for the min, max and current frequency
    let minFrequencyLabel: UILabel = {
        let label = UILabel()
        label.text = "17kHz"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
       
    let maxFrequencyLabel: UILabel = {
        let label = UILabel()
        label.text = "20kHz"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
       
    let currentFrequencyLabel: UILabel = {
        let label = UILabel()
        label.text = "18kHz"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    // These are two labels for FFT data
    let fftLabel1: UILabel = {
        let label = UILabel()
        label.text = "FFT Magnitude (dB)"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
        
    let fftLabel2: UILabel = {
        let label = UILabel()
        label.text = "Peak Frequency"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    // To show gesture detection result
    let gestureLabel: UILabel = {
        let label = UILabel()
        label.text = "No gesture detected"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .blue
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Module B"

        // To add slider to the view
        view.addSubview(frequencySlider)
        view.addSubview(minFrequencyLabel)
        view.addSubview(maxFrequencyLabel)
        view.addSubview(currentFrequencyLabel)
        
        // To add FFT labels to the view
        view.addSubview(fftLabel1)
        view.addSubview(fftLabel2)
        view.addSubview(gestureLabel)
        
        frequencySlider.addTarget(self, action: #selector(frequencyChanged(_:)), for: .valueChanged)
        
        // To setup a constraints for the slider
        NSLayoutConstraint.activate([
            frequencySlider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frequencySlider.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            frequencySlider.widthAnchor.constraint(equalToConstant: 300),
            
            // Min frequency label constraints
            minFrequencyLabel.leadingAnchor.constraint(equalTo: frequencySlider.leadingAnchor),
            minFrequencyLabel.topAnchor.constraint(equalTo: frequencySlider.bottomAnchor, constant: 8),
                        
            // Max frequency label constraints
            maxFrequencyLabel.trailingAnchor.constraint(equalTo: frequencySlider.trailingAnchor),
            maxFrequencyLabel.topAnchor.constraint(equalTo: frequencySlider.bottomAnchor, constant: 8),
                        
            // Current frequency label constraints
            currentFrequencyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            currentFrequencyLabel.topAnchor.constraint(equalTo: frequencySlider.topAnchor, constant: -30),
            
            // FFT label 1 constraints
            fftLabel1.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            fftLabel1.topAnchor.constraint(equalTo: view.topAnchor, constant: 150),
                        
            // FFT label 2 constraints
            fftLabel2.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            fftLabel2.topAnchor.constraint(equalTo: fftLabel1.bottomAnchor, constant: 10),
            
            // Gesture label constraints
            gestureLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gestureLabel.topAnchor.constraint(equalTo: fftLabel2.bottomAnchor, constant: 20)
        ])
        
        
        // To start microphone processing
        audio.startMicrophoneProcessing(withFps: 10)
        audio.startProcessingSinewaveForPlayback(withFreq: frequencySlider.value)
        audio.play()
        
        // To regularly update the FFT peak information
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateLabels), userInfo: nil, repeats: true)
        }
        
    
        
    // To update frequency as the slider changes
    @objc func frequencyChanged(_ sender: UISlider) {
        let frequency = sender.value
        audio.startProcessingSinewaveForPlayback(withFreq: frequency)
        
        // To update the current frequency label to show the current slider value
        currentFrequencyLabel.text = String(format: "%.2fkHz", frequency / 1000)
        
    }
    
    var frequencyHistory: [Float] = []
    let historySize = 5 // No. of samples to average

    func smoothFrequency(frequency: Float) -> Float {
        let weight: Float = 0.7 // Adjust the weight to emphasize recent data
        if frequencyHistory.isEmpty {
            frequencyHistory.append(frequency)
            return frequency
        }
        let smoothedFrequency = weight * frequency + (1 - weight) * frequencyHistory.last!
        frequencyHistory.append(smoothedFrequency)
        if frequencyHistory.count > historySize {
            frequencyHistory.removeFirst()
        }
        return smoothedFrequency
    }
    
    // To declare last update time and hysteresis threshold
    var lastUpdate: Date = Date()
    let hysteresisThreshold: Float = 3.0 // Adjust this value as needed
    
    // To update FFT labels dynamically based on audio data
    @objc func updateLabels() {
        let (peakMagnitude, peakFrequency) = self.audio.getMaxFrequencyMagnitude()
        
        DispatchQueue.main.async {
                    self.fftLabel1.text = "Peak Magnitude: \(peakMagnitude) dB"
                    self.fftLabel2.text = "Peak Frequency: \(peakFrequency) Hz"
                }
        // To check if enough time has passed since last update
        let currentDate = Date()
        if currentDate.timeIntervalSince(lastUpdate) > 0.5 { // 500 ms debounce
           
            let smoothedFrequency = smoothFrequency(frequency: peakFrequency)
            var frequencyChange = smoothedFrequency - lastFrequency

            if abs(smoothedFrequency - peakFrequency) < hysteresisThreshold {
                // To ignore outliers that differ too much from the smoothed value
                 frequencyChange = smoothedFrequency - lastFrequency
                // To gesture detection logic
            }
                        
            // To use Float instead of Double for comparisons
            if frequencyChange > 5.0 {
                gestureLabel.text = "User is gesturing toward"
                gestureLabel.textColor = .green
            } else if frequencyChange < -5.0 {
                gestureLabel.text = "User is gesturing away"
                gestureLabel.textColor = .red
            } else if abs(frequencyChange) < hysteresisThreshold {
                gestureLabel.text = "User is not gesturing"
                gestureLabel.textColor = .blue
            }
            
            lastFrequency = smoothedFrequency
            lastUpdate = currentDate // To Update last update time
        }
    }



}
