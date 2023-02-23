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

import os

// MARK: Largest Remainder Method

extension Dictionary where Value == Int, Key: Comparable {
    /// Calculates percentages for each Value in the Dictionary, given the total as denominator.  Yields whole-number percentages as the result.  Uses the Largest Remainder Method to ensure they evenly add up to 100%.  Operates on values associated in a dictionary, allowing you to track which percentage value is associated with which input value.
    func percentagesWithDistributedRemainder() -> [Key: Int] {
        // Largest Remainder Method in order to enable us to produce nice integer percentage values for each option that all add up to 100%.
        let counts = self.map { $1 }
        let totalVotes = counts.reduce(0, +)
        
        if(totalVotes == 0) {
            os_log("Cannot perform largest remainder method when total is 0. Defaulting to zero percentages.", log: .rover, type: .fault)
            return self.mapValues { _ in 0 }
        }
        
        let asExactPercentages = self.mapValues { votes in
            (Double(votes) / Double(totalVotes)) * 100
        }
        
        let withRoundedDownPercentages: [Key:(Double, Int)] = asExactPercentages.mapValues { exactPercentage in
            return (exactPercentage, Int(exactPercentage.rounded(.down)))
        }
        
        let asRoundedDownPercentages: [Key: Int] = withRoundedDownPercentages.mapValues { $1 }
        
        let totalWithoutRemainders = asRoundedDownPercentages.values.reduce(0, +)
        
        let remainder = 100 - totalWithoutRemainders
        
        // before we sort the options by the decimal, which is the standard procedure for LRM, we'll pre-sort them by the string key (id) for each option in order to make the distribution of the remainder amongst the options in the last step more deterministic in the event of equal remainders between options.
        
        let optionsSortedById = withRoundedDownPercentages.sorted { (firstOption, secondOption) -> Bool in
            let (firstKey, (_, _)) = firstOption
            let (secondKey, (_, _)) = secondOption
            
            return firstKey < secondKey
        }
        
        let optionsSortedByDecimal = optionsSortedById.sorted { (firstOption, secondOption) -> Bool in
            let (_, (firstPercentage, firstRoundedDownPercentage)) = firstOption
            let (_, (secondPercentage, secondRoundedDownPercentage)) = secondOption
            
            let firstRemainder = firstPercentage - Double(firstRoundedDownPercentage)
            let secondRemainder = secondPercentage - Double(secondRoundedDownPercentage)
            
            return firstRemainder > secondRemainder
        }

        // now to distribute the remainder (as whole integers) across the options:
        let distributed = optionsSortedByDecimal.enumerated().map { tuple -> (Key, Int) in
            let (offset, keyWithPercentages) = tuple
            let (key, percentages) = keyWithPercentages
            let (_, roundedDownPercentage) = percentages
            if offset < remainder {
                return (key, roundedDownPercentage + 1)
            } else {
                return (key, roundedDownPercentage)
            }
        }
        
        // and turn it back into a dictionary:
        return distributed.reduce(into: [Key: Int]()) { (dictionary, optionIdAndCount) in
            let (optionID, voteCount) = optionIdAndCount
            dictionary[optionID] = voteCount
        }
    }
}
