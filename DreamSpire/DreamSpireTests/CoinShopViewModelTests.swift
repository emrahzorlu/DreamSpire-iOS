//
//  CoinShopViewModelTests.swift
//  DreamSpireTests
//
//  Created by Emrah Zorlu on 2025.
//

import XCTest
@testable import DreamSpire

@MainActor
final class CoinShopViewModelTests: XCTestCase {
    
    var mockCoinService: MockCoinService!
    
    override func setUp() {
        super.setUp()
        mockCoinService = MockCoinService()
    }
    
    override func tearDown() {
        mockCoinService = nil
        super.tearDown()
    }
    
    // MARK: - Balance Tests
    
    func testInitialBalanceIsLoaded() async {
        // Given
        mockCoinService.mockBalance = 1000
        
        // When
        await mockCoinService.fetchBalance()
        
        // Then
        XCTAssertEqual(mockCoinService.balance, 1000)
        XCTAssertEqual(mockCoinService.fetchBalanceCallCount, 1)
    }
    
    func testBalanceUpdateAfterRefresh() async {
        // Given
        mockCoinService.mockBalance = 500
        await mockCoinService.fetchBalance()
        
        // When
        mockCoinService.mockBalance = 750
        await mockCoinService.refreshBalance()
        
        // Then
        XCTAssertEqual(mockCoinService.balance, 750)
        XCTAssertEqual(mockCoinService.fetchBalanceCallCount, 2)
    }
    
    // MARK: - Spending Tests
    
    func testSpendCoinsSuccess() async throws {
        // Given
        mockCoinService.mockBalance = 500
        await mockCoinService.fetchBalance()
        
        // When
        try await mockCoinService.spendCoins(amount: 100, reason: "Story creation")
        
        // Then
        XCTAssertEqual(mockCoinService.balance, 400)
        XCTAssertEqual(mockCoinService.spendCoinsCallCount, 1)
        XCTAssertEqual(mockCoinService.lastSpendAmount, 100)
        XCTAssertEqual(mockCoinService.lastSpendReason, "Story creation")
    }
    
    func testSpendCoinsFailsWithInsufficientBalance() async {
        // Given
        mockCoinService.mockBalance = 50
        await mockCoinService.fetchBalance()
        
        // When/Then
        do {
            try await mockCoinService.spendCoins(amount: 100, reason: "Story creation")
            XCTFail("Should have thrown insufficient coins error")
        } catch {
            XCTAssertEqual(mockCoinService.balance, 50) // Balance unchanged
        }
    }
    
    // MARK: - Cost Calculation Tests
    
    func testCostCalculationBasic() {
        // Given
        let duration = StoryDuration.medium
        let addons = StoryAddons(includeIllustrations: false, includeAudio: false)
        
        // When
        let cost = mockCoinService.calculateCost(duration: duration, addons: addons, isSubscriber: false)
        
        // Then
        XCTAssertEqual(cost, duration.baseCost)
    }
    
    func testCostCalculationWithAddons() {
        // Given
        let duration = StoryDuration.medium
        let addons = StoryAddons(includeIllustrations: true, includeAudio: true)
        
        // When
        let cost = mockCoinService.calculateCost(duration: duration, addons: addons, isSubscriber: false)
        
        // Then
        XCTAssertEqual(cost, duration.baseCost + 30) // +20 for illustrations, +10 for audio
    }
    
    func testCostCalculationWithSubscriberDiscount() {
        // Given
        let duration = StoryDuration.medium
        let addons = StoryAddons(includeIllustrations: false, includeAudio: false)
        
        // When
        let cost = mockCoinService.calculateCost(duration: duration, addons: addons, isSubscriber: true)
        
        // Then
        let expectedCost = Int(Double(duration.baseCost) * 0.8) // 20% discount
        XCTAssertEqual(cost, expectedCost)
    }
    
    // MARK: - Error Handling Tests
    
    func testFetchBalanceError() async {
        // Given
        mockCoinService.shouldFailFetch = true
        
        // When
        await mockCoinService.fetchBalance()
        
        // Then
        XCTAssertNotNil(mockCoinService.error)
    }
}
