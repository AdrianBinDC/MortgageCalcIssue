//
//  MortgageCalcIssueTests.swift
//  MortgageCalcIssueTests
//
//  Created by Adrian Bolinger on 9/21/21.
//

import Combine
import XCTest
@testable import MortgageCalcIssue

class MortgageCalcIssueTests: XCTestCase {

    private var calculator: MortgageCalculator {
        MortgageCalculator(principalAmount: 100_000)
    }
    
    private var subscriptions: Set<AnyCancellable> = []

    func testTermPublisher() {
        let sut = calculator
        
        let exp = expectation(description: #function)
        
        let termsAllCases = MortgageTerm.allCases
        
        var publishedValues: [MortgageTerm] = []
        
        sut.$mortgageTerm.sink { completion in
            // nothing for now
        } receiveValue: { term in
            publishedValues.append(term)
            if publishedValues.count == termsAllCases.count {
                exp.fulfill()
            }
        }
        .store(in: &subscriptions)

        termsAllCases.forEach { term in
            sut.mortgageTerm = term
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testPrincipalAmountPublisher() {
        let sut = calculator
        
        let exp = expectation(description: #function)
                
        let expectedAmounts: [Double] = [100_000, 200_000, 300_000]
                
        sut.$principalAmount
            .collect(4)
            .sink { actualValues in
                // We drop the first because principalAmount is set in the initializer
                XCTAssertEqual(Array(actualValues.dropFirst()), expectedAmounts)
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        expectedAmounts.forEach { expectedAmount in
            sut.principalAmount = expectedAmount
        }
                
        waitForExpectations(timeout: 1.0, handler: nil)
    }
        
    func testDownPaymentAmount() {
        let sut = calculator
        
        let exp = expectation(description: #function)
        
        let downPaymentAmounts: [Double] = [0,
                                            20_000,
                                            50_000,
                                            80_000,
                                            100_000]
        let expectedPercentages: [Double] = [0.0, 0.2, 0.5, 0.8, 1.0]
        
        sut.downPaymentPercentage
            .collect(6)
            .sink { actualPercentages in
                XCTAssertEqual(Array(actualPercentages.dropFirst()), expectedPercentages)
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        downPaymentAmounts.forEach { amount in
            sut.downPaymentAmount = amount
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testFinancedAmount() {
        // Initialized w/ $100,000 principalAmount
        let sut = calculator
        
        let exp = expectation(description: #function)
        
        let actualDownPaymentAmounts: [Double] = [0,
                                            20_000,
                                            50_000,
                                            80_000,
                                            100_000]
        
        let expectedFinancedAmounts = actualDownPaymentAmounts.map { 100_000 - $0 }
        
        sut.financedAmount
            .print()
            .collect(6)
            .sink { actualFinancedAmounts in
                XCTAssertEqual(Array(actualFinancedAmounts.dropFirst()), expectedFinancedAmounts)
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        actualDownPaymentAmounts.forEach { amount in
            sut.downPaymentAmount = amount
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testMortgageTypes() {
        let expectedMortgageTypeDescriptions = [
            "10 Year Fixed",
            "15 Year Fixed",
            "20 Year Fixed",
            "30 Year Fixed"
        ]
        
        XCTAssertEqual(MortgageTerm.allCases.map { $0.description },
                       expectedMortgageTypeDescriptions)
    }
    
    func testMonthlyPayment() {
        // sut is initialized w/ principalAmount of $100,000 & downPaymentAmount of $20,000
        let sut = calculator
        
        let expectation = expectation(description: #function)
        
        // TODO: Not deterministic. Eventually gets right values, but publishers aren't in sync. Determine root cause
        // FIXME: extra value is getting thrown in, likely due to mismatch on publishers
        // FIXME: likely need another publisher that returns a boolean indicating everything is done and it's ready to do the final computation
        let expectedPayments = [339.62, 433.97, 542.46]
        
        sut.monthlyPayment
            .collect(3)
            .sink { actualMonthlyPayment in
                XCTAssertEqual(actualMonthlyPayment.map { $0.roundTo(places: 2) }, expectedPayments)
                expectation.fulfill()
            }
            .store(in: &subscriptions)
        
        // Initialized with 30 year fix with 20% down
        // Change term to 20 years
        sut.mortgageTerm = .twentyYear

        // Change the financedAmount
        sut.downPaymentAmount = 0.0
        
        waitForExpectations(timeout: 1, handler: nil)
        
        // TODO: Add more tests to pound the shit out of the class and identify holes in coverage.
   }
}

extension Double {
    func roundTo(places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        
        return (self * divisor).rounded() / divisor
    }
    
    var nsDecimalNumber: NSDecimalNumber {
        NSDecimalNumber(value: self)
    }
}
