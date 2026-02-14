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
import os.log

extension HTTPClient {
    func getConfig() async -> Result<RoverConfig, Error> {
        let endpoint = engageEndpoint.appendingPathComponent("config")
        let request = downloadRequest(url: endpoint)

        os_log(.debug, log: .config, "Retrieving config")

        let result = await download(with: request)

        let jsonData: Data
        switch result {
        case .success(let data, _):
            os_log(.debug, log: .config, "Successfully retrieved config")
            jsonData = data
        case .error(let error, _):
            os_log(
                .error, log: .config, "Failed to fetch config from %@: %@",
                endpoint.absoluteString, error?.localizedDescription ?? "unknown reason")
            return .failure(
                ConfigSyncError(message: error?.localizedDescription ?? "unknown reason"))
        }

        do {
            let config = try JSONDecoder().decode(RoverConfig.self, from: jsonData)
            return .success(config)
        } catch {
            let responseBodyString = String(data: jsonData, encoding: .utf8) ?? "none"
            os_log(
                .error, log: .config,
                "Failed to decode config response: %@, response body: %@",
                error.localizedDescription, responseBodyString)
            return .failure(ConfigSyncError(message: error.localizedDescription))
        }
    }
}

struct ConfigSyncError: Error {
    let message: String
}
