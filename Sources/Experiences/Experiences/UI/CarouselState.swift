// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import Combine
import RoverFoundation


final class CarouselState: ObservableObject {
    @Published var currentPageForCarousel: [ViewID: Int] = [:]
    @Published var currentNumberOfPagesForCarousel: [ViewID: Int] = [:]
    @Published var storyStyleStatusForCarousel: [ViewID: Bool] = [:]
    @Published var currentBarProgressForCarousel: [ViewID: [Double]] = [:]
    private let experienceUrl: String?
    
    private let persistedCarouselPositions = PersistedValue<[String: Int]>(storageKey: "io.rover.experience.carouselPositions")
    
    init(experienceUrl: String?) {
        self.experienceUrl = experienceUrl
    }
    
    private func persistenceKey(for viewID: ViewID) -> String {
        let urlBase64 = experienceUrl.flatMap { $0.data(using: .utf8)?.base64EncodedString() }
        return "\(urlBase64 ?? "unknown")-\(viewID.toString())"
    }
    
    func setPersistedPosition(for viewID: ViewID, newValue: Int) {
        let carouselIdentifier = persistenceKey(for: viewID)
        
        guard var carouselPositions = persistedCarouselPositions.value else {
            persistedCarouselPositions.value = [carouselIdentifier: newValue]
            return
        }
        
        carouselPositions[carouselIdentifier] = newValue
        persistedCarouselPositions.value = carouselPositions
    }
    
    func getPersistedPosition(for viewID: ViewID) -> Int {
        let carouselIdentifier = persistenceKey(for: viewID)
        guard let carouselPositions = persistedCarouselPositions.value,
              let value = carouselPositions[carouselIdentifier] else {
            return 0
        }
        
        return value
    }
    
    func getBarProgress(for viewID: ViewID, index: Int) -> Double {
        if self.currentBarProgressForCarousel[viewID] == nil {
            self.currentBarProgressForCarousel[viewID] = [Double](repeating: 0.0, count: currentNumberOfPagesForCarousel[viewID] ?? 1)
        }
        
        return self.currentBarProgressForCarousel[viewID]?[index] ?? 0.0
    }
    
    func setBarProgress(for viewID: ViewID, index: Int, value: Double) {
        if self.currentBarProgressForCarousel[viewID] == nil {
            self.currentBarProgressForCarousel[viewID] = [Double](repeating: 0.0, count: currentNumberOfPagesForCarousel[viewID] ?? 1)
        }
        
        self.currentBarProgressForCarousel[viewID]?.insert(value, at: index)
    }
    
    func addBarProgress(for viewID: ViewID, index: Int, value: Double) {
        let incremented = self.getBarProgress(for: viewID, index: index) + value
        setBarProgress(for: viewID, index: index, value: incremented)
    }
    
    func resetBarProgress(for viewID: ViewID) {
        if self.currentBarProgressForCarousel[viewID] == nil {
            self.currentBarProgressForCarousel[viewID] = [Double](repeating: 0.0, count: currentNumberOfPagesForCarousel[viewID] ?? 1)
            return
        }
        
        for index in 0...(currentNumberOfPagesForCarousel[viewID] ?? 1) {
            self.currentBarProgressForCarousel[viewID]?[index] = 0.0
        }
    }
}
