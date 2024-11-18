//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate
import AVFoundation

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    // thse properties are for interfaceing with the API
    // the user can access these arrays at any time and plot them if they like
    var timeData:[Float]
    var fftData:[Float]
    lazy var samplingRate:Int = {
        return Int(self.audioManager!.samplingRate)
    }()
    
    

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var fileBuffer: AVAudioPCMBuffer?
    private var processingTimer: Timer?
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
    }
    
    func applyWindowFunction(to data: inout [Float]) {
        var window = [Float](repeating: 0.0, count: data.count)
        vDSP_hamm_window(&window, vDSP_Length(data.count), 0)
        vDSP_vmul(data, 1, window, 1, &data, 1, vDSP_Length(data.count))
    }
    
    func getMaxFrequencyMagnitude() -> (Float, Float) {
        var maxValue: Float = -1000.0
        var maxIndex: vDSP_Length = 0
        
        if inputBuffer != nil {
            vDSP_maxvi(fftData, 1, &maxValue, &maxIndex, vDSP_Length(fftData.count))
        }
        
        let frequency = Float(maxIndex) / Float(BUFFER_SIZE) * Float(self.audioManager!.samplingRate)
        return (maxValue, frequency)
    }
    
    
    func startProcessingSinewaveForPlayback(withFreq: Float = 330.0) {
        sineFrequency = withFreq
        guard let audioManager = audioManager else {
            print("Audio Manager is not initialized.")
            return
        }
        audioManager.setOutputBlockToPlaySineWave(sineFrequency)
    }
    
    func processMicrophoneData() {
           // Apply window function to reduce spectral leakage
           applyWindowFunction(to: &timeData)
           
           // Perform FFT on the windowed time data
           fftHelper?.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)
       }

    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps:Double){
        if let manager = self.audioManager {
                   manager.inputBlock = self.handleMicrophone
                   
                   // Set up a timer to process audio data at the given FPS
                   Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
                       self.processMicrophoneData()  // Process microphone data at each interval
                       self.runEveryInterval()       // Periodic callback to process FFT
                   }
               }
    }
    
    
    // Function to stop the audio manager if it is running.
    func stop() {
        audioManager?.pause()

        // Clear the input block to stop microphone processing
        audioManager?.inputBlock = nil
    }
    


    
    private var currentFrameIndex: Int = 0
    
    private func updateData() {
        guard let fileBuffer = fileBuffer else { return }
         
         // Get audio samples and update timeData
         let frameLength = min(fileBuffer.frameLength, AVAudioFrameCount(BUFFER_SIZE), fileBuffer.frameLength - AVAudioFrameCount(currentFrameIndex))
         if frameLength == 0 {
             currentFrameIndex = 0
             return
         }
         
         let channelData = fileBuffer.floatChannelData![0]
         timeData = Array(UnsafeBufferPointer(start: channelData.advanced(by: Int(currentFrameIndex)), count: Int(frameLength)))
         
         // Apply FFT on the windowed time data
         applyWindowFunction(to: &timeData)
         fftHelper?.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)
         
         currentFrameIndex += Int(frameLength)
    }
    
    func getTwoLoudestFrequencies(threshold: Float = 0.01) -> (Float?, Float?) {
        var loudestFrequency: (magnitude: Float, frequency: Float)? = nil
         var secondLoudestFrequency: (magnitude: Float, frequency: Float)? = nil
         
         // Iterate through FFT data to find two loudest frequencies
         for i in 0..<fftData.count {
             let magnitude = fftData[i]
             let frequency = Float(i) * Float(samplingRate) / Float(fftData.count * 2)
             
             // Ignore very low frequencies (below 100Hz)
             if frequency < 100.0 {
                 continue
             }
             
             // Check if the magnitude is above the threshold
             if magnitude > threshold {
                 if loudestFrequency == nil || magnitude > loudestFrequency!.magnitude {
                     secondLoudestFrequency = loudestFrequency
                     loudestFrequency = (magnitude, frequency)
                 } else if secondLoudestFrequency == nil || magnitude > secondLoudestFrequency!.magnitude {
                     secondLoudestFrequency = (magnitude, frequency)
                 }
             }
         }
         
         return (loudestFrequency?.frequency, secondLoudestFrequency?.frequency)
    }
    
    
    

       
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager{
            manager.play()
        }
    }
    
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    private lazy var outputBuffer: CircularBuffer? = {
        return CircularBuffer(numChannels: Int64(self.audioManager!.numOutputChannels),
                              andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    private lazy var fileReader: AudioFileReader? = {
        if let url = Bundle.main.url(forResource: "satisfaction", withExtension: "mp3") {
            let tmpFileReader = AudioFileReader(audioFileURL: url,
                                                samplingRate: Float(audioManager!.samplingRate),
                                                numChannels: audioManager!.numOutputChannels)
            tmpFileReader?.currentTime = 0.0
            print("Audio file successfully loaded for \(url)")
            return tmpFileReader
        } else {
            print("Could not initialize audio input file")
            return nil
        }
    }()
    
    
    //==========================================
    // MARK: Private Methods
    // NONE for this model
    
    //==========================================
    // MARK: Model Callback Methods
    private func runEveryInterval(){
        
        guard let inputBuffer = inputBuffer else {
                    print("Input buffer is not initialized.")
                    return
                }

                // Fetch fresh data into timeData
                inputBuffer.fetchFreshData(&timeData, withNumSamples: Int64(BUFFER_SIZE))

            
            // Apply Hamming window and FFT
            applyWindowFunction(to: &timeData)
            fftHelper?.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)
    }
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }

    
    var sineFrequency: Float = 0.0 {
        didSet {
            self.audioManager?.sineFrequency = sineFrequency
        }
    }
    
    private var phase: Float = 0.0
    private var phaseIncrement: Float = 0.0
    private var sineWaveRepeatMax: Float = Float(2 * Double.pi)
    
    private func handleSpeakerQueryWithSinusoid(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        if let arrayData = data {
            var i = 0
            while i < numFrames {
                arrayData[i] = sin(phase)
                phase += phaseIncrement
                if phase >= sineWaveRepeatMax { phase -= sineWaveRepeatMax }
                i += 1
            }
        }
    }
}
