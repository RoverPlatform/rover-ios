//
//  SettingsViewController.swift
//  RoverDebug
//
//  Created by Sean Rucker on 2018-06-25.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

#if !COCOAPODS
import RoverFoundation
#endif

open class SettingsViewController: UIViewController {
    public let isTestDevice = PersistedValue<Bool>(storageKey: "io.rover.RoverDebug.isTestDevice")
    
    public private(set) var navigationBar: UINavigationBar?
    public private(set) var tableView = UITableView()
    
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Rover Settings"
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = UIColor(red: 93 / 255, green: 93 / 255, blue: 93 / 255, alpha: 1.0)
        tableView.tableFooterView = UIView()
        tableView.separatorColor = UIColor(red: 129 / 255, green: 129 / 255, blue: 129 / 255, alpha: 1.0)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        makeNavigationBar()
        configureConstraints()
    }
    
    // MARK: Layout
    
    open func makeNavigationBar() {
        if let existingNavigationBar = self.navigationBar {
            existingNavigationBar.removeFromSuperview()
        }
        
        if navigationController != nil {
            self.navigationBar = nil
            return
        }
        
        let navigationBar = UINavigationBar()
        navigationBar.delegate = self
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.barTintColor = UIColor(red: 50 / 255, green: 50 / 255, blue: 50 / 255, alpha: 1.0)
        navigationBar.tintColor = UIColor(red: 42 / 255, green: 197 / 255, blue: 214 / 255, alpha: 1.0)
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]

        let navigationItem = makeNavigationItem()
        navigationBar.items = [navigationItem]
        
        view.addSubview(navigationBar)
        self.navigationBar = navigationBar
    }
    
    open func makeNavigationItem() -> UINavigationItem {
        let navigationItem = UINavigationItem()
        navigationItem.title = title
        
        if presentingViewController != nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done(_:)))
        }
        
        return navigationItem
    }
    
    open func configureConstraints() {
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        if let navigationBar = navigationBar {
            NSLayoutConstraint.activate([
                navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }
        
        if #available(iOS 11, *) {
            let layoutGuide = view.safeAreaLayoutGuide
            tableView.bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor).isActive = true
            
            if let navigationBar = navigationBar {
                NSLayoutConstraint.activate([
                    navigationBar.topAnchor.constraint(equalTo: layoutGuide.topAnchor),
                    tableView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor)
                ])
            } else {
                tableView.topAnchor.constraint(equalTo: layoutGuide.topAnchor).isActive = true
            }
        } else {
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            
            if let navigationBar = navigationBar {
                NSLayoutConstraint.activate([
                    navigationBar.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
                    tableView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor)
                ])
            } else {
                tableView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor).isActive = true
            }
        }
    }
    
    // MARK: Actions
    
    @objc
    func done(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = TestDeviceCell()
            cell.toggle.isOn = isTestDevice.value ?? false
            cell.toggle.addTarget(self, action: #selector(toggleTestDevice(_:)), for: .valueChanged)
            return cell
        case 1:
            let cell = LabelAndValueCell()
            cell.label.text = "Device Name"
            cell.value.text = UIDevice.current.name
            return cell
        case 2:
            let cell = LabelAndValueCell()
            cell.label.text = "Device Identifier"
            cell.value.text = UIDevice.current.identifierForVendor?.uuidString
            return cell
        default:
            fatalError("Non-existent column asked for in SettingsViewController.")
        }
    }
    
    @objc
    func toggleTestDevice(_ sender: Any) {
        guard let toggle = sender as? UISwitch else {
            return
        }
        
        isTestDevice.value = toggle.isOn
    }
    
    class TestDeviceCell: UITableViewCell {
        let label = UILabel()
        let toggle = UISwitch()
        
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            self.configure()
        }
        
        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func configure() {
            backgroundColor = UIColor(red: 93 / 255, green: 93 / 255, blue: 93 / 255, alpha: 1.0)
            selectionStyle = .none
            
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 19)
            label.textColor = UIColor(red: 216 / 255, green: 216 / 255, blue: 216 / 255, alpha: 1.0)
            label.text = "Test Device"
            contentView.addSubview(label)
            
            toggle.translatesAutoresizingMaskIntoConstraints = false
            toggle.onTintColor = UIColor(red: 42 / 255, green: 197 / 255, blue: 214 / 255, alpha: 1.0)
            contentView.addSubview(toggle)
            
            NSLayoutConstraint.activate([
                label.heightAnchor.constraint(equalToConstant: 24.0),
                label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24.0),
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24.0),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24.0)
            ])
            
            let bottomConstraint = label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24.0)
            bottomConstraint.priority = UILayoutPriority.defaultLow
            bottomConstraint.isActive = true
            
            toggle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24.0).isActive = true
            toggle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        }
    }
    
    class LabelAndValueCell: UITableViewCell {
        let label = UILabel()
        let value = UILabel()
        
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            self.configure()
        }
        
        func configure() {
            backgroundColor = UIColor(red: 93 / 255, green: 93 / 255, blue: 93 / 255, alpha: 1.0)
            selectionStyle = .none
            
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 15)
            label.textColor = UIColor(red: 216 / 255, green: 216 / 255, blue: 216 / 255, alpha: 1.0)
            contentView.addSubview(label)
            
            value.translatesAutoresizingMaskIntoConstraints = false
            value.font = UIFont.systemFont(ofSize: 19)
            value.textColor = UIColor.white
            contentView.addSubview(value)
            
            NSLayoutConstraint.activate([
                label.heightAnchor.constraint(equalToConstant: 24.0),
                label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24.0),
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24.0),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24.0)
            ])
            
            NSLayoutConstraint.activate([
                value.heightAnchor.constraint(equalToConstant: 24.0),
                value.topAnchor.constraint(equalTo: label.bottomAnchor),
                value.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24.0),
                value.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24.0)
            ])
            
            let bottomConstraint = value.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -23.0)
            bottomConstraint.priority = UILayoutPriority.defaultLow
            bottomConstraint.isActive = true
        }
        
        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

// MARK: UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row == 2
    }
    
    public func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(copy(_:)):
            return true
        default:
            return false
        }
    }
    
    public func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        guard let cell = tableView.cellForRow(at: indexPath) as? LabelAndValueCell else {
            return
        }
        
        UIPasteboard.general.string = cell.value.text
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) as? TestDeviceCell {
            cell.toggle.setOn(!cell.toggle.isOn, animated: true)
        }
        
        tableView.deselectRow(at: indexPath, animated: false)
    }
}

// MARK: UINavigationBarDelegate

extension SettingsViewController: UINavigationBarDelegate {
    public func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}
