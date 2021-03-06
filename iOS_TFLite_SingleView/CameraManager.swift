//
//  CameraManager.swift
//  iOS_SingleView_1
//
//  Created by 横山裕樹 on 2020/06/08.
//  Copyright © 2020 HirokiYokoyama. All rights reserved.
//

import UIKit
import AVFoundation

enum CameraConfiguration {
    case success
    case failed
    case permissionDenied
}

class CameraManager: NSObject {

    // MARK: Camera Related Instance Variables
    let session: AVCaptureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var cameraConfiguration: CameraConfiguration = .failed
    private lazy var videoDataOutput = AVCaptureVideoDataOutput()
    private var isSessionRunning = false


    // MARK: CameraFeedManagerDelegate
    var sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate? = nil
    //weak var delegate: CameraFeedManagerDelegate?

    init(sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?) {
        super.init()
        self.sampleBufferDelegate = sampleBufferDelegate

        // Initializes the session
        session.sessionPreset = .high
        attemptToConfigureSession()
    }

  // MARK: Session Start and End methods

  /**
   This method stops a running an AVCaptureSession.
   */
    func stopSession() {
        //self.removeObservers()
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }

    }

  /**
   This method resumes an interrupted AVCaptureSession.
   */
    func resumeInterruptedSession(withCompletion completion: @escaping (Bool) -> ()) {

        sessionQueue.async {
            self.startSession()

            DispatchQueue.main.async {
                completion(self.isSessionRunning)
            }
        }
    }

  /**
 This method starts the AVCaptureSession
 **/
    func startSession() {
        sessionQueue.async {
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
        }
    }

  // MARK: Session Configuration Methods.
  /**
 This method requests for camera permissions and handles the configuration of the session and stores the result of configuration.
 */
  private func attemptToConfigureSession() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      self.cameraConfiguration = .success
    case .notDetermined:
      self.sessionQueue.suspend()
      self.requestCameraAccess(completion: { (granted) in
        self.sessionQueue.resume()
      })
    case .denied:
      self.cameraConfiguration = .permissionDenied
    default:
      break
    }

    self.sessionQueue.async {
      self.configureSession()
    }
  }

  /**
   This method requests for camera permissions.
   */
  private func requestCameraAccess(completion: @escaping (Bool) -> ()) {
    AVCaptureDevice.requestAccess(for: .video) { (granted) in
      if !granted {
        self.cameraConfiguration = .permissionDenied
      }
      else {
        self.cameraConfiguration = .success
      }
      completion(granted)
    }
  }


  /**
   This method handles all the steps to configure an AVCaptureSession.
   */
  private func configureSession() {

    guard cameraConfiguration == .success else {
      return
    }
    session.beginConfiguration()

    // Tries to add an AVCaptureDeviceInput.
    guard addVideoDeviceInput() == true else {
      self.session.commitConfiguration()
      self.cameraConfiguration = .failed
      return
    }

    // Tries to add an AVCaptureVideoDataOutput.
    guard addVideoDataOutput() else {
      self.session.commitConfiguration()
      self.cameraConfiguration = .failed
      return
    }

    session.commitConfiguration()
    self.cameraConfiguration = .success
  }

  /**
 This method tries to an AVCaptureDeviceInput to the current AVCaptureSession.
 */
  private func addVideoDeviceInput() -> Bool {

    /**Tries to get the default back camera.
     */
    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
      return false
    }

    do {
      let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
      if session.canAddInput(videoDeviceInput) {
        session.addInput(videoDeviceInput)
        return true
      }
      else {
        return false
      }
    }
    catch {
      fatalError("Cannot create video device input")
    }
  }

  /**
   This method tries to an AVCaptureVideoDataOutput to the current AVCaptureSession.
   */
  private func addVideoDataOutput() -> Bool {

    let sampleBufferQueue = DispatchQueue(label: "sampleBufferQueue")
    videoDataOutput.setSampleBufferDelegate(sampleBufferDelegate, queue: sampleBufferQueue)
    videoDataOutput.alwaysDiscardsLateVideoFrames = true
    videoDataOutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]

    if session.canAddOutput(videoDataOutput) {
      session.addOutput(videoDataOutput)
      //videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
      return true
    }
    return false
  }
}
