import Foundation
import Combine

typealias Authorizers = [Authorizer]

// MARK: Authorizers

struct Authorizer {
    var pattern: String
    var callback: RoverAuthorizer
    
    func authorize(_ request: inout URLRequest) async {
        await callback.authorize(request: &request)
    }
}

/// If you wish to use a asynchronous authorizer routine adding custom headers to oubound data source requests, implement this protocol with a struct or object, and register it with ``Rover.shared.authorizeAsync``.
///
/// If you don't need an async, you can use ``Rover.shared.authorize`` to use a simple closure instead.
public protocol RoverAuthorizer {
    /// Modify the given outbound Rover experiences data sources REST request, adding custom headers (eg., for Authorization) as needed.
    func authorize(request: inout URLRequest) async
}

/// This wrapper type allows us to register non-async authorizers with a closure.
private struct SynchronousAuthorizer: RoverAuthorizer {
    let block: (inout URLRequest) -> Void
    
    func authorize(request: inout URLRequest) async {
        block(&request)
    }
}

private struct AsyncAuthorizer: RoverAuthorizer {
    let block: (inout URLRequest) async -> Void
    
    func authorize(request: inout URLRequest) async {
        await block(&request)
    }
}

extension Authorizers {
    public mutating func authorize(_ pattern: String, with block: @escaping (inout URLRequest) -> Void) {
        let synchronousAuthorizer = SynchronousAuthorizer(block: block)
        
        append(
            Authorizer(pattern: pattern, callback: synchronousAuthorizer)
        )
    }
    
    public mutating func authorizeAsync(_ pattern: String, with block: @escaping (inout URLRequest) async -> Void) {
        let asyncAuthorizer = AsyncAuthorizer(block: block)
        append(
            Authorizer(pattern: pattern, callback: asyncAuthorizer)
        )
    }
    
    func authorize(_ request: inout URLRequest) async {
        guard let host = request.url?.host else {
            return
        }
                
        for authorizer in self {
            if matchDomainPattern(string: host, pattern: authorizer.pattern) {
                await authorizer.authorize(&request)
            }
        }
    }
}

// MARK: Combine Support

extension Authorizers {
    func authorizePublisher(_ request: URLRequest) -> AnyPublisher<URLRequest, Never> {
        var request = request
        return Future<URLRequest, Never> { promise in
            Task {
                await self.authorize(&request)
                promise(.success(request))
            }
        }.eraseToAnyPublisher()
    }
}
