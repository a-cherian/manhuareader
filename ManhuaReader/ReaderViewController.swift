//
//  ReaderViewController.swift
//  ManhuaReader
//
//  Created by AC on 12/16/23.
//

import UIKit
import Vision
import SwiftyTesseract

class ReaderViewController: UIViewController, ImageScrollViewDelegate {
    
    private var dataSource: [UIImage] = [UIImage(systemName: "calendar") ?? UIImage(), UIImage(systemName: "plus.diamond") ?? UIImage(), UIImage(systemName: "calendar") ?? UIImage()]
    var position = 0
    var book: Book
    
    var ocrEnabled = false
    var unprocessedImage: UIImage? = nil
    var zoomedRect: CGRect? = nil
    var clusters: [[CGRect]] = []
    var textRegions: [CGRect] = []
    var detectedText: [(String?, CGRect)] = []
    var detectVertical = false
    let tesseract = Tesseract(language: .custom("chi_tra_vert"))
    
    var pinchGesture: UIPinchGestureRecognizer? = nil
    var tapGesture: UITapGestureRecognizer? = nil
    
    lazy var reader: ImageScrollView = {
        let view = ImageScrollView()
        view.imageScrollViewDelegate = self
        return view
    }()
    
    lazy var ocrButton: UIButton = {
        let button = UIButton()
        
        button.setImage(UIImage(systemName: "rectangle.and.text.magnifyingglass"), for: .normal)
        button.backgroundColor = .black
        button.tintColor = .white
        button.layer.cornerRadius = 10
        button.layer.borderColor = Constants.accentColor.cgColor
        button.layer.borderWidth = 2
        
        button.addTarget(self, action: #selector(didTapOCR), for: .touchUpInside)
        
        return button
    }()
    
    lazy var ocrSwitch: UISwitch = {
        let button = UISwitch()
        
        button.tintColor = Constants.accentColor
        button.onTintColor = Constants.accentColor
        
        button.addTarget(self, action: #selector(didTapOCRSwitch(_:)), for: .valueChanged)

        return button
    }()
    
    lazy var ocrView: UIView = {
        let newView = UIView(frame: CGRect(x: 0, y: 0, width: 250, height: 35))
        
        newView.addSubview(ocrButton)
        newView.addSubview(ocrSwitch)
        
        return newView
    }()
    
    lazy var backButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 40, height: 35))
        
        button.setImage(UIImage(systemName: "arrow.left")?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        button.tintColor = .white
        
        button.addTarget(self, action: #selector(didTapBack(_:)), for: .touchUpInside)
        
        return button
    }()
    
    init(images: [UIImage] = [], book: Book) {
        self.dataSource = images
        self.position = Int(book.lastPage)
        self.book = book
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tesseract.pageSegMode = .singleBlockVerticalText
        
        view.backgroundColor = .black
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: ocrView)
        
        addSubviews()
        configureUI()
        
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    func addSubviews() {
        view.addSubview(reader)
    }
    
    func configureUI() {
        configureReader()
        configureOCRButton()
        configureOCRSwitch()
    }
    
    func configureReader() {
        reader.setup()
        let image = dataSource[position]
        reader.display(image: image)
        reader.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            reader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            reader.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            reader.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            reader.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    func configureOCRButton() {
        ocrButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ocrButton.topAnchor.constraint(equalTo: ocrView.topAnchor),
            ocrButton.bottomAnchor.constraint(equalTo: ocrView.bottomAnchor),
            ocrButton.trailingAnchor.constraint(equalTo: ocrView.trailingAnchor),
            ocrButton.widthAnchor.constraint(equalTo: ocrButton.heightAnchor)
        ])
    }
    
    func configureOCRSwitch() {
        ocrSwitch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ocrSwitch.topAnchor.constraint(equalTo: ocrView.topAnchor),
            ocrSwitch.bottomAnchor.constraint(equalTo: ocrView.bottomAnchor),
            ocrSwitch.leadingAnchor.constraint(equalTo: ocrView.leadingAnchor),
            ocrSwitch.trailingAnchor.constraint(equalTo: ocrButton.leadingAnchor, constant: -20)
        ])
    }
    
    func presentDictionary(text: String) {
        let dictionaryViewController = DictionaryViewController(text: text)
        if let presentationController = dictionaryViewController.presentationController as? UISheetPresentationController {
            presentationController.detents = [.medium(), .large()]
            presentationController.prefersGrabberVisible = true
            presentationController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        
        self.present(dictionaryViewController, animated: true)
    }
    
    func pageLeft() {
        if(position + 1 < dataSource.count)
        {
            position += 1
            let image = dataSource[position]
            reader.display(image: image)
        }
        ocrEnabled = false
    }
    
    func pageRight() {
        if(position - 1 >= 0) {
            position -= 1
            let image = dataSource[position]
            reader.display(image: image)
        }
        ocrEnabled = false
    }
    
    @objc func didTapOCR() {
        ocrEnabled = true
        requestInitialVision()
    }
    
    @objc func didTapOCRSwitch(_ sender: UISwitch ) {
        detectVertical = sender.isOn
    }
    
    @objc func didPinch(_ sender: UIPinchGestureRecognizer) {
        reader.isUserInteractionEnabled = true
    }
    
    @objc func didTapBack(_ sender: UIButton) {
        book.lastPage = Int64(position)
        book.lastOpened = Date()
        CoreDataManager.shared.updateBook(book: book)
        self.navigationController?.popViewController(animated: true)
    }
    
    func didTapRegion(location: CGPoint) -> Bool {
        guard let zoomedRect = zoomedRect else { return false }
        if !(zoomedRect.contains(location)) { return false }
                                
        guard let regionIndex = textRegions.firstIndex(where: { $0.contains(location) }) else { return false }
        let region = textRegions[regionIndex]
        
        var text = ""
        
        if(!detectVertical) {
            text = requestHorizontalVision(on: unprocessedImage, region: region)
        }
        else {
            text = requestVerticalVision(image: unprocessedImage ?? dataSource[position], cluster: clusters[regionIndex])
        }
        
        self.presentDictionary(text: text)
        
        return true
    }
    
    func getBoxes(observations: [VNRecognizedTextObservation], image: UIImage, rect: CGRect?) -> [(String?, CGRect)] {
        let rect: CGRect = rect ?? CGRect(origin: CGPoint.zero, size: image.size)
        let boundingRects: [(String?, CGRect)] = observations.compactMap { observation in
            // Find the top observation.
            guard let candidate = observation.topCandidates(1).first else { return ("", .zero) }

            // Find the bounding-box observation for the string range.
            let stringRange = candidate.string.startIndex..<candidate.string.endIndex
            let boxObservation = try? candidate.boundingBox(for: stringRange)

            // Get the normalized CGRect value.
            let boundingBox = boxObservation?.boundingBox ?? .zero

            // Convert the rectangle from normalized coordinates to image coordinates.
            let normalizedToZoom = boundingBox.normalizeBoundingBox(for: image.crop(rect: rect))
            let normalized = CGRect(x: normalizedToZoom.minX + rect.minX, y: normalizedToZoom.minY + rect.minY, width: normalizedToZoom.width, height: normalizedToZoom.height)
            return (candidate.string, normalized)
        }
        return boundingRects
    }
    
    func getBoxClusters(boxes: [CGRect]) -> [[CGRect]] {
        var processing = boxes
        
        var clusters: [[CGRect]] = []
        
        while(processing.count > 0) {
            var cluster: [CGRect] = []
            cluster.append(processing[0])
            
            var clusterUnprocessed = cluster
            while(clusterUnprocessed.count > 0) {
                let curr = clusterUnprocessed[0]
                cluster.append(curr)
                clusterUnprocessed.removeAll(where: { $0 == curr })
                
                let thresholdArea = CGRect(x: curr.minX - curr.height, y: curr.minY - curr.height / 2, width: curr.width + curr.height * 2, height: curr.height * 2)

                var clusterSet = Set(clusterUnprocessed)
                clusterSet.formUnion(Set(processing.filter { $0.intersects(thresholdArea) }))
                clusterSet = clusterSet.subtracting(Set(cluster))
                clusterUnprocessed = Array(clusterSet)
            }
            clusters.append(cluster)
            processing = Array(Set(processing).subtracting(cluster))
        }
        
        return clusters
    }
    
    func getVerticalBoxes(cluster: [CGRect], original: [(String?, CGRect)]) -> [CGRect] {
        var joined = cluster[0]
        var longest: (String, CGRect) = ("", cluster[0])
        
        cluster.forEach { box in
            let sameRow = Set(cluster.filter({ $0 != box && abs($0.origin.y - box.origin.y) < box.height / 5 }))
            var rowBox = box
            var rowString = detectedText.first(where: { $0.1 == box })?.0 ?? ""
            sameRow.forEach { item in
                rowBox = rowBox.union(item)
                rowString += detectedText.first(where: { $0.1 == item })?.0 ?? ""
            }
            if(rowString.count > longest.0.count) { longest = (rowString, rowBox) }
            joined = joined.union(box)
        }
        
        var verticalCluster: [CGRect] = []
        
        let columnNum = CGFloat(longest.0.count)
        let columnSize = joined.width / columnNum
        for i in 0..<longest.0.count {
            var columnBox = CGRect(x: joined.minX + CGFloat(i) * columnSize, y: joined.minY, width: columnSize, height: joined.height)
            columnBox = columnBox.insetBy(dx: -(joined.width / columnNum) / 5, dy: -(joined.width / columnNum) / 5)
            verticalCluster.insert(columnBox, at: 0)
        }
        
        return verticalCluster
    }
    
    func joinBoxes(cluster: [CGRect]) -> CGRect {
        if cluster.count == 0 { return .zero }
        var joined = cluster[0]
        cluster.forEach { box in
            joined = joined.union(box)
        }
        return joined
    }
    
    func requestHorizontalVision(on image: UIImage?, region: CGRect) -> String {
        guard let unwrapped = image else { return "" }
        guard let cgImage = unwrapped.cgImage else { return "" }

        // Create a new image-request handler.
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        var result = ""

        // Create a new request to recognize text.
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else { return }
            let text = observations.compactMap({ $0.topCandidates(1).first?.string}).joined(separator: "")
            
            result = text
        }
        
        request.regionOfInterest = region.unnormalizeBoundingBox(for: unwrapped)
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hant"]
        
        do {
            // Perform the text-recognition request.
            try requestHandler.perform([request])
        } catch {
            print("Unable to perform the requests: \(error).")
        }
        
        return result
    }
    
    func requestInitialVision() {
        let image = dataSource[position]
        zoomedRect = image.getZoomedRect(from: reader)
        guard let cgImage = image.cgImage else { return }

        // Create a new image-request handler.
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Create a new request to recognize text.
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else { return }
            
            self.detectedText = self.getBoxes(observations: observations, image: image, rect: self.zoomedRect)
            self.clusters = self.getBoxClusters(boxes: self.detectedText.map { $0.1 })
            self.textRegions = self.clusters.map { self.joinBoxes(cluster: $0) }
            
            self.unprocessedImage = image
            
            self.reader.zoomView?.image = image.drawRectsOnImage(self.textRegions, color: .red, for: self.reader)
        }
        
        request.regionOfInterest = (zoomedRect ?? image.getZoomedRect(from: reader)).unnormalizeBoundingBox(for: image)
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hant"]

        do {
            // Perform the text-recognition request.
            try requestHandler.perform([request])
        } catch {
            print("Unable to perform the requests: \(error).")
        }
    }
    
    func requestVerticalVision(image: UIImage, cluster: [CGRect]) -> String {
        
        let boxes = getVerticalBoxes(cluster: cluster, original: detectedText)
        
        var results = [String](repeating: "", count: boxes.count)
        for i in 0..<boxes.count {
            let box = boxes[i]
            let column = image.crop(rect: box).noiseReducted()
            let result = tesseract.performOCR(on: column)
            do {
                results[i] = try result.get().replacingOccurrences(of: "\n", with: "")
            } catch {
                print("Error retrieving the value: \(error)")
            }
        }
        
        return results.joined()
    }
    
    func imageScrollViewDidChangeOrientation(imageScrollView: ImageScrollView) {
        
    }
}
