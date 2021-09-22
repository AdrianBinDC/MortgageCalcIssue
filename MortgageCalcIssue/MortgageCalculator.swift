//
//  MortgageCalculator.swift
//  MortgageCalcIssue
//
//  Created by Adrian Bolinger on 9/21/21.
//

import Combine
import Foundation

// MARK: - Structs
struct AverageRate: Codable {
    let thirtyYearFha: Double
    let thirtyYearVa: Double
    let tenYearFix: Double
    let fifteenYearFix: Double
    let thirtyYearFix: Double
    let fiveOneArm: Double
    let sevenOneArm: Double
    let twentyYearFix: Double
    
    enum CodingKeys: String, CodingKey {
        case thirtyYearFha = "thirty_year_fha"
        case thirtyYearVa = "thirty_year_va"
        case tenYearFix = "ten_year_fix"
        case fifteenYearFix = "fifteen_year_fix"
        case thirtyYearFix = "thirty_year_fix"
        case fiveOneArm = "five_one_arm"
        case sevenOneArm = "seven_one_arm"
        case twentyYearFix = "twenty_year_fix"
    }
}

// MARK: - Enums
public enum MortgageTerm: Int, CaseIterable, CustomStringConvertible {
    case tenYear      = 10
    case fifteenYear = 15
    case twentyYear  = 20
    case thirtyYear  = 30
    
    public var description: String {
        switch self {
        case .tenYear:
            return "10 Year Fixed"
        case .fifteenYear:
            return "15 Year Fixed"
        case .twentyYear:
            return "20 Year Fixed"
        case .thirtyYear:
            return "30 Year Fixed"
        }
    }
}

class MortgageCalculator: ObservableObject {
    
    // MARK: - Publishers
    @Published var principalAmount: Double
    @Published var mortgageTerm: MortgageTerm = .thirtyYear
    @Published var downPaymentAmount: Double = 0.0
    
    // Combine equivalent of a computed var
    public lazy var downPaymentPercentage: AnyPublisher<Double, Never> = {
        // observe the down payment amount
        $downPaymentAmount
        // map the observed value to observed value divided by principalAmount
            .map { $0 / self.principalAmount }
            .eraseToAnyPublisher()
    }()
    
    public lazy var financedAmount: AnyPublisher<Double, Never> = {
        Publishers.CombineLatest($principalAmount, $downPaymentAmount)
            .map { principal, downPayment in
                principal - downPayment
            }
            .eraseToAnyPublisher()
    }()
    
    public lazy var monthlyPayment: AnyPublisher<Double, Never> = {
        Publishers.CombineLatest3(financedAmount, monthlyRate, numberOfPayments)
            .print("montlyPayment: ", to: nil)
            .map { financedAmount, monthlyRate, numberOfPayments in
                let numerator = monthlyRate * pow((1 + monthlyRate), Double(numberOfPayments))
                let denominator = pow((1 + monthlyRate), Double(numberOfPayments)) - 1
                
                return financedAmount * (numerator / denominator)
            }
            .eraseToAnyPublisher()
    }()
        
    public lazy var annualRate: AnyPublisher<Double, Never> = {
        $mortgageTerm
            .print("annualRate: ", to: nil)
            .map { value -> Double in
                switch value {
                case .tenYear:
                    return self.rates.tenYearFix
                case .fifteenYear:
                    return self.rates.fifteenYearFix
                case .twentyYear:
                    return self.rates.twentyYearFix
                case .thirtyYear:
                    return self.rates.thirtyYearFix
                }
            }
            .map { $0 * 0.01 }
            .eraseToAnyPublisher()
    }()
    
    public lazy var numberOfPayments: AnyPublisher<Double, Never> = {
        $mortgageTerm
            .print("numberOfPayments: ", to: nil)
            .map {
                Double($0.rawValue * 12)
            }
            .eraseToAnyPublisher()
    }()
    
    internal lazy var monthlyRate: AnyPublisher<Double, Never> = {
        annualRate
            .print("monthlyRate: ", to: nil)
            .map { rate in
                rate / 12
            }
            .eraseToAnyPublisher()
    }()
    
    // TODO: CREATE A SINGLETON RATE INFO CLASS THAT'S ALWAYS LIVE
    /*
     - Create a singleton class that's always hanging around w/ rate info.
     - Persist rates in CoreData to avoid unnecessary API calls
     - Grab rate info off the singleton
     */    
    private lazy var rates: AverageRate = {
        let rateMock = AverageRate(thirtyYearFha: 2.873,
                                   thirtyYearVa: 2.858,
                                   tenYearFix: 2.068,
                                   fifteenYearFix: 2.358,
                                   thirtyYearFix: 3.054,
                                   fiveOneArm: 2.898,
                                   sevenOneArm: 2.972,
                                   twentyYearFix: 2.756)
        
        return rateMock
    }()
    
    private var subscriptions: Set<AnyCancellable> = []
    
    // MARK: - Initializer
    init(principalAmount: Double) {
        self.principalAmount = principalAmount
        self.downPaymentAmount = principalAmount * 0.2
    }
}
