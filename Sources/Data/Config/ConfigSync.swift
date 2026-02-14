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

public actor ConfigSync: SyncStandaloneParticipant {
    private let httpClient: HTTPClient
    private let configManager: ConfigManager

    public init(httpClient: HTTPClient, configManager: ConfigManager) {
        self.httpClient = httpClient
        self.configManager = configManager
    }

    public func sync() async -> Bool {
        let result = await httpClient.getConfig()

        switch result {
        case .success(let config):
            await MainActor.run {
                configManager.updateFromBackend(config)
            }
            os_log(.debug, log: .config, "Config sync completed successfully")
            return true
        case .failure(let error):
            os_log(
                .error, log: .config, "Config sync failed: %@",
                error.localizedDescription)
            return false
        }
    }
}
