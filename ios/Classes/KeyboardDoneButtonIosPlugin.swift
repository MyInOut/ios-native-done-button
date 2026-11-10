
import Flutter
import UIKit

public class KeyboardDoneButtonIosPlugin: NSObject, FlutterPlugin {

  // MARK: - Properties

  private var toolbarWindow: UIWindow?
  private var toolbarContainer: UIView?
  private var doneButton: UIButton?

  private var pendingToolbarRequest = false
  private var isObserversRegistered = false
  private var isToolbarActive = false

  private var keyboardIsVisible = false
  private var currentKeyboardFrame: CGRect = .zero
  private var lastScreenBounds: CGRect = .zero

  private let toolbarHeight: CGFloat = 56
  private let buttonWidth: CGFloat = 72
  private let buttonHeight: CGFloat = 36
  private let buttonRightPadding: CGFloat = 16

  // Keyboard background approximation from the supplied screenshot.
  private let keyboardBackgroundColor = UIColor(
    red: 210.0 / 255.0,
    green: 211.0 / 255.0,
    blue: 216.0 / 255.0,
    alpha: 1.0
  )

  // MyInOut blue: #0099FF
  private let myInOutBlue = UIColor(
    red: 0.0,
    green: 153.0 / 255.0,
    blue: 1.0,
    alpha: 1.0
  )

  // MARK: - Plugin Registration

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "keyboard_done_button_ios",
      binaryMessenger: registrar.messenger()
    )

    let instance = KeyboardDoneButtonIosPlugin()
    instance.registerKeyboardObservers()

    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  // MARK: - Flutter Method Handler

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "showDoneButton":
      showDoneButton()
      result(true)

    case "hideDoneButton":
      hideDoneButton()
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Keyboard Observers

  private func registerKeyboardObservers() {
    guard UIDevice.current.userInterfaceIdiom != .pad else {
      return
    }

    guard !isObserversRegistered else {
      return
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillShow(_:)),
      name: UIResponder.keyboardWillShowNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillHide(_:)),
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )

    isObserversRegistered = true
  }

  // MARK: - Show / Hide Requests

  private func showDoneButton() {
    guard UIDevice.current.userInterfaceIdiom != .pad else {
      return
    }

    pendingToolbarRequest = true

    // Handle requests made after the keyboard is already visible.
    if keyboardIsVisible && currentKeyboardFrame != .zero {
      isToolbarActive = true

      showToolbar(
        toKeyboardFrame: currentKeyboardFrame,
        duration: 0.15,
        animationCurve: .curveEaseInOut
      )
    }
  }

  private func hideDoneButton() {
    guard UIDevice.current.userInterfaceIdiom != .pad else {
      return
    }

    pendingToolbarRequest = false
    isToolbarActive = false

    hideToolbar()
  }

  // MARK: - Keyboard Handlers

  @objc private func keyboardWillShow(_ notification: Notification) {
    guard
      let keyboardFrame = notification.userInfo?[
        UIResponder.keyboardFrameEndUserInfoKey
      ] as? CGRect
    else {
      return
    }

    keyboardIsVisible = true
    currentKeyboardFrame = keyboardFrame

    // Detect screen rotation.
    let currentScreenBounds = UIScreen.main.bounds

    let didRotate =
      isToolbarActive &&
      lastScreenBounds != .zero &&
      lastScreenBounds != currentScreenBounds

    lastScreenBounds = currentScreenBounds

    let shouldShowToolbar =
      pendingToolbarRequest || didRotate || isToolbarActive

    pendingToolbarRequest = false

    guard shouldShowToolbar else {
      isToolbarActive = false
      hideToolbar()
      return
    }

    let animationDuration =
      notification.userInfo?[
        UIResponder.keyboardAnimationDurationUserInfoKey
      ] as? TimeInterval ?? 0.25

    let animationCurveRaw =
      notification.userInfo?[
        UIResponder.keyboardAnimationCurveUserInfoKey
      ] as? NSNumber ?? NSNumber(value: 7)

    let animationCurve = UIView.AnimationOptions(
      rawValue: animationCurveRaw.uintValue << 16
    )

    isToolbarActive = true

    showToolbar(
      toKeyboardFrame: keyboardFrame,
      duration: animationDuration,
      animationCurve: animationCurve
    )
  }

  @objc private func keyboardWillHide(_ notification: Notification) {
    keyboardIsVisible = false
    currentKeyboardFrame = .zero
    isToolbarActive = false

    let duration =
      notification.userInfo?[
        UIResponder.keyboardAnimationDurationUserInfoKey
      ] as? TimeInterval ?? 0.25

    hideToolbar(duration: duration)
  }

  // MARK: - Create Done Button

  private func createDoneButton() -> UIButton {
    let button = UIButton(type: .custom)

    button.translatesAutoresizingMaskIntoConstraints = false

    // MyInOut blue: #0099FF
    button.backgroundColor = myInOutBlue

    button.setTitle("Done", for: .normal)
    button.setTitleColor(.white, for: .normal)

    button.titleLabel?.font = UIFont.systemFont(
      ofSize: 15,
      weight: .semibold
    )

    button.layer.cornerRadius = 8
    button.layer.masksToBounds = true

    button.contentHorizontalAlignment = .center
    button.contentVerticalAlignment = .center

    button.addTarget(
      self,
      action: #selector(doneButtonTapped),
      for: .touchUpInside
    )

    button.accessibilityLabel = "Done"
    button.accessibilityIdentifier = "keyboardDoneButton"

    NSLayoutConstraint.activate([
      button.widthAnchor.constraint(
        equalToConstant: buttonWidth
      ),

      button.heightAnchor.constraint(
        equalToConstant: buttonHeight
      )
    ])

    return button
  }

  // MARK: - Create Toolbar Container

  private func createToolbarContainer() -> UIView {
    let container = UIView()

    container.translatesAutoresizingMaskIntoConstraints = false

    container.backgroundColor = UIColor(
      red: 210.0 / 255.0,
      green: 211.0 / 255.0,
      blue: 216.0 / 255.0,
      alpha: 0.7,
    )

    container.isOpaque = false

    container.layer.cornerRadius = 0
    container.layer.masksToBounds = false

    // Keep the container rectangular.
    container.layer.cornerRadius = 0
    container.layer.masksToBounds = true

    let button = createDoneButton()

    container.addSubview(button)

    NSLayoutConstraint.activate([
      button.trailingAnchor.constraint(
        equalTo: container.trailingAnchor,
        constant: -buttonRightPadding
      ),

      button.centerYAnchor.constraint(
        equalTo: container.centerYAnchor
      )
    ])

    self.doneButton = button

    return container
  }

  // MARK: - Create Native Window

  private func createToolbarWindow() -> UIWindow {
    let window: UIWindow

    if #available(iOS 13.0, *) {
      let activeScene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }

      if let activeScene = activeScene {
        window = UIWindow(windowScene: activeScene)
      } else {
        window = UIWindow(frame: .zero)
      }
    } else {
      window = UIWindow(frame: .zero)
    }

    let rootViewController = UIViewController()

    rootViewController.view.backgroundColor = .clear
    rootViewController.view.isOpaque = false

    window.rootViewController = rootViewController

    window.windowLevel = UIWindow.Level(
      rawValue: UIWindow.Level.alert.rawValue - 1
    )

    // Keep the window transparent.
    // Only the toolbar container has an opaque background.
    window.backgroundColor = .clear
    window.isOpaque = false
    window.isUserInteractionEnabled = true

    return window
  }

  // MARK: - Show Toolbar

  private func showToolbar(
    toKeyboardFrame keyboardFrame: CGRect,
    duration: TimeInterval,
    animationCurve: UIView.AnimationOptions
  ) {
    if toolbarWindow == nil {
      toolbarWindow = createToolbarWindow()
    }

    if toolbarContainer == nil {
      let container = createToolbarContainer()

      toolbarContainer = container

      guard
        let rootView = toolbarWindow?.rootViewController?.view
      else {
        return
      }

      rootView.addSubview(container)

      NSLayoutConstraint.activate([
        container.leadingAnchor.constraint(
          equalTo: rootView.leadingAnchor
        ),

        container.trailingAnchor.constraint(
          equalTo: rootView.trailingAnchor
        ),

        container.topAnchor.constraint(
          equalTo: rootView.topAnchor
        ),

        container.bottomAnchor.constraint(
          equalTo: rootView.bottomAnchor
        )
      ])
    }

    guard let toolbarWindow = toolbarWindow else {
      return
    }

    toolbarWindow.layer.removeAllAnimations()

    let screenWidth = UIScreen.main.bounds.width

    let finalY = keyboardFrame.origin.y - toolbarHeight

    let finalFrame = CGRect(
      x: 0,
      y: finalY,
      width: screenWidth,
      height: toolbarHeight
    )

    let isAlreadyVisible =
      !toolbarWindow.isHidden &&
      toolbarWindow.alpha == 1

    if isAlreadyVisible {
      toolbarWindow.frame = finalFrame
      return
    }

    UIView.performWithoutAnimation {
      toolbarWindow.frame = finalFrame
      toolbarWindow.alpha = 0
      toolbarWindow.isHidden = false
    }

    UIView.animate(
      withDuration: duration,
      delay: 0,
      options: [animationCurve],
      animations: {
        toolbarWindow.alpha = 1
      },
      completion: nil
    )
  }

  // MARK: - Hide Toolbar

  private func hideToolbar(duration: TimeInterval = 0.25) {
    guard let toolbarWindow = toolbarWindow else {
      return
    }

    toolbarWindow.layer.removeAllAnimations()

    UIView.animate(
      withDuration: duration,
      animations: {
        toolbarWindow.alpha = 0
      }
    ) { finished in
      guard finished else {
        return
      }

      toolbarWindow.isHidden = true
    }
  }

  // MARK: - Button Actions

  @objc private func doneButtonTapped() {
    pendingToolbarRequest = false
    isToolbarActive = false

    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder),
      to: nil,
      from: nil,
      for: nil
    )
  }

  // MARK: - Deinitialization

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
