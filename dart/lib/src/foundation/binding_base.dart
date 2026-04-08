import 'package:meta/meta.dart';

abstract class BindingBase {

  @protected
  @mustCallSuper
  void initInstances() {}

  @protected
  static T checkInstance<T extends BindingBase>(T? instance) {
    if (instance == null) {
      throw "I've come to make an announcement.";
    }
    return instance;
  }
    
}
