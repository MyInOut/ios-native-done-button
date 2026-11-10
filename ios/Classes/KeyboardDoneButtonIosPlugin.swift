
import Flutter
import UIKit

public class KeyboardDoneButtonIosPlugin: NSObject, FlutterPlugin {

  // MARK: - Properties

  private var toolbarWindow: UIWindow?
  private var toolbar: UIToolbar?

  private var pendingToolbarRequest = false
  private var isObserversRegistered = false
  private var isToolbarActive = false

  // Keyboard state
  private var keyboardIsVisible = false
  private var currentKeyboardFrame: CGRect = .zero
  private var lastScreenBounds: CGRect = .zero

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
    guard UIDevice.current.userInterfaceIdiom != .pad else { return }
    guard !isObserversRegistered else { return }

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
    guard UIDevice.current.userInterfaceIdiom != .pad else { return }

    pendingToolbarRequest = true

    // Important:
    // The keyboard may already be visible when Flutter requests
    // the toolbar. In that case, keyboardWillShow will not fire again.
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
    guard UIDevice.current.userInterfaceIdiom != .pad else { return }

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

  // MARK: - Toolbar Creation

  private func createToolbar() -> UIToolbar {
    let toolbar = UIToolbar()

    toolbar.barStyle = .default
    toolbar.isTranslucent = true
    toolbar.backgroundColor = .clear
    toolbar.autoresizingMask = [.flexibleWidth]

    // Remove the default toolbar background.
    toolbar.setBackgroundImage(
      UIImage(),
      forToolbarPosition: .any,
      barMetrics: .default
    )

    toolbar.setShadowImage(
      UIImage(),
      forToolbarPosition: .any
    )

    // Flexible space pushes the Done button to the right.
    let flexSpace = UIBarButtonItem(
      barButtonSystemItem: .flexibleSpace,
      target: nil,
      action: nil
    )

    // Custom button.
    // Use .custom to avoid the system button appearance.
    let doneButton = UIButton(type: .custom)

    doneButton.frame = CGRect(
      x: 0,
      y: 0,
      width: 72,
      height: 36
    )

    doneButton.setTitle("Done", for: .normal)
    doneButton.setTitleColor(.white, for: .normal)

    doneButton.titleLabel?.font = UIFont.systemFont(
      ofSize: 15,
      weight: .semibold
    )

    doneButton.backgroundColor = UIColor(
      red: 35.0 / 255.0,
      green: 103.0 / 255.0,
      blue: 209.0 / 255.0,
      alpha: 1.0
    )

    doneButton.layer.cornerRadius = 8
    doneButton.layer.masksToBounds = true

    doneButton.contentHorizontalAlignment = .center
    doneButton.contentVerticalAlignment = .center

    doneButton.addTarget(
      self,
      action: #selector(doneButtonTapped),
      for: .touchUpInside
    )

    doneButton.accessibilityLabel = "Done"
    doneButton.accessibilityIdentifier = "keyboardDoneButton"

    let doneBarButton = UIBarButtonItem(
      customView: doneButton
    )

    let fixedSpace = UIBarButtonItem(
      barButtonSystemItem: .fixedSpace,
      target: nil,
      action: nil
    )

    fixedSpace.width = 16

    toolbar.items = [
      flexSpace,
      doneBarButton,
      fixedSpace
    ]

    toolbar.sizeToFit()

    return toolbar
  }

  // MARK: - Show Toolbar

  private func showToolbar(
    toKeyboardFrame endFrame: CGRect,
    duration: TimeInterval,
    animationCurve: UIView.AnimationOptions
  ) {
    if toolbar == nil {
      toolbar = createToolbar()
    }

    if toolbarWindow == nil {
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

      window.windowLevel = UIWindow.Level(
        rawValue: UIWindow.Level.alert.rawValue - 1
      )

      window.backgroundColor = .clear
      window.isUserInteractionEnabled = true

      toolbarWindow = window
    } else {
      toolbarWindow?.layer.removeAllAnimations()
    }

    guard
      let toolbarWindow = toolbarWindow,
      let toolbar = toolbar
    else {
      return
    }

    let screenWidth = UIScreen.main.bounds.width
    let toolbarHeight = toolbar.frame.height

    let finalY = endFrame.origin.y - toolbarHeight

    if toolbar.superview == nil {
      toolbar.frame = CGRect(
        x: 0,
        y: 0,
        width: screenWidth,
        height: toolbarHeight
      )

      toolbarWindow.addSubview(toolbar)
    }

    toolbar.frame = CGRect(
      x: 0,
      y: 0,
      width: screenWidth,
      height: toolbarHeight
    )

    // Avoid flickering when the toolbar is already visible.
    let isAlreadyVisible =
      !toolbarWindow.isHidden &&
      toolbarWindow.alpha == 1

    if isAlreadyVisible {
      toolbarWindow.frame = CGRect(
        x: 0,
        y: finalY,
        width: screenWidth,
        height: toolbarHeight
      )

      return
    }

    UIView.performWithoutAnimation {
      toolbarWindow.frame = CGRect(
        x: 0,
        y: finalY,
        width: screenWidth,
        height: toolbarHeight
      )

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
    guard let toolbarWindow = toolbarWindow else { return }

    UIView.animate(
      withDuration: duration,
      animations: {
        toolbarWindow.alpha = 0
      }
    ) { finished in
      guard finished else { return }

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
