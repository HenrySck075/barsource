// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
part of "dart_ui.dart";

// If we actually run on big endian machines, we'll need to do something smarter
// here. We don't use [Endian.Host] because it's not a compile-time
// constant and can't propagate into the set/get calls.
const Endian _kFakeHostEndian = Endian.little;

const bool _kReleaseMode = bool.fromEnvironment('dart.vm.product');
