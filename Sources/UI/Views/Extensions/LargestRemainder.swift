//
//  LargestRemainder.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-08-01.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

// MARK: Largest Remainder Method

extension Dictionary where Value == Int {
    /// Calculates percentages for each Value in the Dictionary, given the total as denominator.  Yields whole-number percentages as the result.  Uses the Largest Remainder Method to ensure they evenly add up to 100%.  Operates on values associated in a dictionary, allowing you to track which percentage value is associated with which input value.
    func percentagesWithDistributedRemainder() -> [Key: Int] {
        // Largest Remainder Method in order to enable us to produce nice integer percentage values for each option that all add up to 100%.
        let counts = self.map { $1 }
        
        let totalVotes = counts.reduce(0, +)
        
        let voteFractions = counts.map { votes in
            Double(votes) / Double(totalVotes)
        }
        
        let totalWithoutRemainders = voteFractions.map { value in
            Int(value.rounded(.down))
        }.reduce(0, +)
        
        let remainder = 100 - totalWithoutRemainders
        
        typealias OptionIdAndCount = (Key, Int)
        
        let optionsSortedByDecimal: [OptionIdAndCount] = self.sorted { (firstOption, secondOption) -> Bool in
            let firstOptionFraction = Double(firstOption.value) / Double(totalVotes)
            let secondOptionFraction = Double(secondOption.value) / Double(totalVotes)

            return secondOptionFraction > firstOptionFraction
        }

        // now to distribute the remainder (as whole integers) across the options.
        let distributed = optionsSortedByDecimal.enumerated().map { tuple -> OptionIdAndCount in
            let (offset, (optionId, voteCount)) = tuple
            if offset < remainder {
                return (optionId, voteCount + 1)
            } else {
                return (optionId, voteCount)
            }
        }
        
        // and turn it back into a dictionary:
        return distributed.reduce(into: [Key: Int]()) { (dictionary, optionIdAndCount) in
            let (optionId, voteCount) = optionIdAndCount
            dictionary[optionId] = voteCount
        }
    }
}
