import 'package:flutter/material.dart';

class LoadingService extends ChangeNotifier {
  bool _isLoading = false;
  String _message = '';

  bool get isLoading => _isLoading;
  String get message => _message;

  void startLoading(String message) {
    _isLoading = true;
    _message = message;
    notifyListeners();
  }

  void stopLoading() {
    _isLoading = false;
    _message = '';
    notifyListeners();
  }
}
