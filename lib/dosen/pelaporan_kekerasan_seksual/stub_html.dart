// This is a stub file that stands in for dart:html on non-web platforms
// Define minimal implementations of the classes and functions you need

class IFrameElement {
  set src(String value) {}
  final Style style = Style();
  void set height(String value) {}
  void set width(String value) {}
  void set border(String value) {}
}

class Style {
  void set height(String value) {}
  void set width(String value) {}
  void set border(String value) {}
}

class Window {
  void postMessage(dynamic message, String targetOrigin) {}
  Stream get onMessage => const Stream.empty();
}

Window get window => Window();
