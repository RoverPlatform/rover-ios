//
//  MatchDomainPattern.swift
//  Rover
//
//  Created by Andrew Clunis on 2025-02-27.
//

func matchDomainPattern(string: String, pattern: String) -> Bool {
    guard string.split(separator: ".").count >= 2 else {
        return false
    }
    
    let wildcardAndRoot = pattern.components(separatedBy: "*.")
    guard let root = wildcardAndRoot.last, wildcardAndRoot.count <= 2 else {
        return false
    }
    
    let hasWildcard = wildcardAndRoot.count > 1
    
    return (!hasWildcard && string == pattern) || (hasWildcard && (string == root || string.hasSuffix(".\(root)")))
    
}
