//
//  ISBNScannerView.swift
//  ReadingCompanion
//
//  Barcode scanner for ISBN detection using AVFoundation.
//

import SwiftUI
import AVFoundation

struct ISBNScannerView: UIViewControllerRepresentable {
    @Binding var isbn: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> ISBNScannerViewController {
        let controller = ISBNScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ISBNScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ISBNScannerViewControllerDelegate {
        let parent: ISBNScannerView

        init(_ parent: ISBNScannerView) {
            self.parent = parent
        }

        func didFindISBN(_ isbn: String) {
            parent.isbn = isbn
            parent.dismiss()
        }

        func didCancel() {
            parent.dismiss()
        }
    }
}

protocol ISBNScannerViewControllerDelegate: AnyObject {
    func didFindISBN(_ isbn: String)
    func didCancel()
}

class ISBNScannerViewController: UIViewController {
    weak var delegate: ISBNScannerViewControllerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var detectedISBN: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScanner()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupScanner() {
        let session = AVCaptureSession()

        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            showScannerUnavailable()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean13, .ean8]  // ISBN barcodes
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        self.captureSession = session
        self.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func setupUI() {
        // Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.tintColor = .white
        cancelButton.addTarget(self, action: #selector(cancelScan), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        // Instructions
        let instructionLabel = UILabel()
        instructionLabel.text = "Point at ISBN barcode"
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        instructionLabel.layer.cornerRadius = 8
        instructionLabel.clipsToBounds = true
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionLabel)

        // Scanning frame overlay
        let frameView = UIView()
        frameView.layer.borderColor = UIColor.white.cgColor
        frameView.layer.borderWidth = 2
        frameView.layer.cornerRadius = 8
        frameView.backgroundColor = .clear
        frameView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(frameView)

        NSLayoutConstraint.activate([
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),

            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            instructionLabel.widthAnchor.constraint(equalToConstant: 220),
            instructionLabel.heightAnchor.constraint(equalToConstant: 36),

            frameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frameView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            frameView.widthAnchor.constraint(equalToConstant: 280),
            frameView.heightAnchor.constraint(equalToConstant: 100),
        ])
    }

    private func showScannerUnavailable() {
        let label = UILabel()
        label.text = "Camera not available"
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    @objc private func cancelScan() {
        delegate?.didCancel()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}

extension ISBNScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard detectedISBN == nil,  // Only process first detection
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let isbn = object.stringValue else {
            return
        }

        // Validate ISBN format (10 or 13 digits)
        let cleanISBN = isbn.replacingOccurrences(of: "-", with: "")
        guard cleanISBN.count == 10 || cleanISBN.count == 13 else {
            return
        }

        detectedISBN = cleanISBN

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Stop scanning and report
        captureSession?.stopRunning()
        delegate?.didFindISBN(cleanISBN)
    }
}
