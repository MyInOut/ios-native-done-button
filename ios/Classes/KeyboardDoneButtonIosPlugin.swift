import Flutter
import UIKit

/// Flutter plugin that displays a "Done" button toolbar above the iOS keyboard
public class KeyboardDoneButtonIosPlugin: NSObject, FlutterPlugin {

  // MARK: - 🔒 Properties ------------------------------------------------- //

  private var toolbarWindow: UIWindow?
  private var toolbar: UIToolbar?
  /// One-shot flag: shows toolbar on next keyboardWillShow, then auto-resets
  private var pendingToolbarRequest = false
  private var isObserversRegistered = false
  /// Tracks if toolbar is currently active (for rotation detection)
  private var isToolbarActive = false
  /// Last known screen bounds (for rotation detection)
  private var lastScreenBounds: CGRect = .zero

  // MARK: - 🔌 Plugin Registration ---------------------------------------- //

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "keyboard_done_button_ios",
      binaryMessenger: registrar.messenger())

    let instance = KeyboardDoneButtonIosPlugin()
    instance.registerKeyboardObservers()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  // MARK: - 📨 Flutter Method Handler ------------------------------------- //

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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

  // MARK: - ⚙️ Setup ------------------------------------------------------ //

  private func registerKeyboardObservers() {
    guard UIDevice.current.userInterfaceIdiom != .pad else { return }  // Skip iPad
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

  // ************************************************************************ //

  private func showDoneButton() {
    guard UIDevice.current.userInterfaceIdiom != .pad else { return }  // Skip iPad
    pendingToolbarRequest = true
  }

  private func hideDoneButton() {
    guard UIDevice.current.userInterfaceIdiom != .pad else { return }  // Skip iPad
    pendingToolbarRequest = false
    isToolbarActive = false
    hideToolbar()
  }

  // MARK: - ⌨️ Keyboard Handlers ------------------------------------------ //

  @objc private func keyboardWillShow(_ notification: Notification) {
    guard
      let keyboardFrameEnd = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
        as? CGRect
    else { return }

    // Detect rotation by comparing screen bounds
    let currentScreenBounds = UIScreen.main.bounds
    let didRotate =
      isToolbarActive && lastScreenBounds != .zero && lastScreenBounds != currentScreenBounds
    lastScreenBounds = currentScreenBounds

    // Show toolbar if: explicit request OR rotation OR toolbar already active
    let shouldShowToolbar = pendingToolbarRequest || didRotate || isToolbarActive
    pendingToolbarRequest = false

    guard shouldShowToolbar else {
      isToolbarActive = false
      hideToolbar()
      return
    }

    guard
      let animationDuration = notification.userInfo?[
        UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
      let animationCurveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey]
        as? NSNumber
    else { return }

    let animationCurve = UIView.AnimationOptions(rawValue: animationCurveRaw.uintValue << 16)

    isToolbarActive = true
    showToolbar(
      toKeyboardFrame: keyboardFrameEnd,
      duration: animationDuration,
      animationCurve: animationCurve)
  }

  // ************************************************************************ //

  @objc private func keyboardWillHide(_ notification: Notification) {
    let duration =
      notification.userInfo?[
        UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25

    hideToolbar(duration: duration)
  }

  // MARK: - 🔨 Toolbar Creation ------------------------------------------- //


private func createToolbar() -> UIToolbar {
    let toolbar = UIToolbar()
    toolbar.barStyle = .default
    toolbar.autoresizingMask = [.flexibleWidth]

    // Flexible space pushes the Done button to the right.
    let flexSpace = UIBarButtonItem(
        barButtonSystemItem: .flexibleSpace,
        target: nil,
        action: nil
    )

    // Custom Done button.
    let doneButton = UIButton(type: .system)

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

    // Replace this with the exact myinout ThemeColors.blue value.
    doneButton.backgroundColor = UIColor(
        red: 35.0 / 255.0,
        green: 103.0 / 255.0,
        blue: 209.0 / 255.0,
        alpha: 1.0
    )

    doneButton.layer.cornerRadius = 8
    doneButton.clipsToBounds = true

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

  // MARK: - 🎬 Show & Hide Toolbar ---------------------------------------- //

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
      if #available(iOS 13.0, *),
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
      {
        window = UIWindow(windowScene: windowScene)
      } else {
        window = UIWindow(frame: .zero)
      }

      window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue - 1)
      window.backgroundColor = .clear
      window.isUserInteractionEnabled = true
      toolbarWindow = window
    } else {
      toolbarWindow?.layer.removeAllAnimations()  // Cancel ongoing hide animation
    }

    guard let toolbarWindow = toolbarWindow, let toolbar = toolbar else { return }

    let screenWidth = UIScreen.main.bounds.width
    let toolbarHeight = toolbar.frame.height
    let finalY = endFrame.origin.y - toolbarHeight

    if toolbar.superview == nil {
      toolbar.frame = CGRect(x: 0, y: 0, width: screenWidth, height: toolbarHeight)
      toolbarWindow.addSubview(toolbar)
    }

    // If already visible, just update position (prevent flicker)
    let isAlreadyVisible = !toolbarWindow.isHidden && toolbarWindow.alpha == 1
    if isAlreadyVisible {
      toolbarWindow.frame = CGRect(x: 0, y: finalY, width: screenWidth, height: toolbarHeight)
      return
    }

    // Fade-in animation
    UIView.performWithoutAnimation {
      toolbarWindow.frame = CGRect(x: 0, y: finalY, width: screenWidth, height: toolbarHeight)
      toolbarWindow.alpha = 0
      toolbarWindow.isHidden = false
    }

    UIView.animate(
      withDuration: duration,
      delay: 0,
      options: [animationCurve],
      animations: { toolbarWindow.alpha = 1 },
      completion: nil)
  }

  // ************************************************************************ //

  private func hideToolbar(duration: TimeInterval = 0.25) {
    guard let toolbarWindow = toolbarWindow else { return }

    UIView.animate(
      withDuration: duration,
      animations: { toolbarWindow.alpha = 0 }
    ) { finished in
      guard finished else { return }  // Skip if animation was cancelled
      toolbarWindow.isHidden = true
    }
  }

  // MARK: - 👆 Button Actions --------------------------------------------- //

  @objc private func doneButtonTapped() {
    isToolbarActive = false  // Reset on explicit dismiss
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder),
      to: nil, from: nil, for: nil
    )
  }

  // MARK: - 🗑️ Deinitialization ------------------------------------------- //

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
