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

import RoverData
import RoverFoundation
import SwiftUI
import UIKit

open class RoverSettingsViewController: UIHostingController<RoverSettingsView> {
    public let isTestDevice = PersistedValue<Bool>(storageKey: "io.rover.RoverDebug.isTestDevice")

    public let controller = RoverSDKController()

    override open var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    init() {
        super.init(rootView: RoverSettingsView(controller: controller) {})
        rootView = RoverSettingsView(controller: controller) { self.dismiss(animated: true) }
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public struct RoverSettingsView: View {

    @ObservedObject internal var controller: RoverSDKController

    public let dismiss: () -> Void

    public var body: some View {
        NavigationView {
            List {
                BooleanRow(label: "Test Device", value: controller.isTestDevice)
                PrivacyModeView(value: controller.trackingMode)
                StringRow(label: "Device Name", value: controller.deviceName)
                StringRow(
                    label: "Device Identifier",
                    value: .constant(
                        UIDevice.current.identifierForVendor?.uuidString ?? "Unknown Identifier"
                    ), readOnly: true)
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle("Rover Settings")
            .navigationBarItems(
                trailing: Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                })
        }
    }

}

public class RoverSDKController: ObservableObject {
    internal var deviceName: Binding<String> {
        Binding {
            Rover.shared.resolve(StaticContextProvider.self)?.deviceName ?? UIDevice.current.name
        } set: { newValue in
            self.objectWillChange.send()
            Rover.shared.resolve(DeviceNameManager.self)?.setDeviceName(newValue)
        }
    }

    internal var isTestDevice: Binding<Bool> {
        Binding {
            self.isTestDeviceField.value ?? false
        } set: { newValue in
            self.objectWillChange.send()
            self.isTestDeviceField.value = newValue
        }
    }

    internal var trackingMode: Binding<PrivacyService.TrackingMode> {
        Binding {
            Rover.shared.trackingMode
        } set: { value in
            self.objectWillChange.send()
            Rover.shared.trackingMode = value
        }
    }

    internal let isTestDeviceField = PersistedValue<Bool>(storageKey: "io.rover.RoverDebug.isTestDevice")
}

private struct PrivacyModeView: View {
    @Binding var value: PrivacyService.TrackingMode

    var body: some View {
        Picker("Tracking Mode", selection: $value) {
            Text("Default").tag(PrivacyService.TrackingMode.default)
            Text("Anonymized").tag(PrivacyService.TrackingMode.anonymized)
        }
    }
}

struct BooleanRow: View {
    var label: String
    @Binding var value: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 19))
            Spacer()
            Toggle("", isOn: $value)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
        }
    }
}

struct StringRow: View {
    var label: String
    @Binding var value: String
    var readOnly: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.system(size: 15))
            HStack {
                TextField("", text: $value)
                    .font(.system(size: 19))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(readOnly)
                if readOnly {
                    Button {
                        UIPasteboard.general.string = value
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}
