import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final _uint8Finalizer = Finalizer<Pointer<Uint8>>((p0) => calloc.free(p0));
final _int32Finalizer = Finalizer<Pointer<Int32>>((p0) => calloc.free(p0));
final _utf8Finalizer = Finalizer<Pointer<Utf8>>((p0) => calloc.free(p0));

extension StringPtr on String {
  Pointer<Utf8> asNativePointer(Arena arena) {
    final Pointer<Utf8> nativeString = toNativeUtf8(allocator: arena);
    return nativeString;
  }
}

extension Int32ListPtr on Int32List {
  (Pointer<Int32>, int) asNativePointer() {
    // 1. Allocate native memory (length)
    final Pointer<Int32> nativeBuffer = calloc<Int32>(length);

    // 2. Get a TypedData view of that native memory and copy
    final nativeView = nativeBuffer.asTypedList(length);
    nativeView.setAll(0, this);

    _int32Finalizer.attach(this, nativeBuffer, detach: this);
    return (nativeBuffer, length);
  }
}

extension ByteDataPtr on ByteData {
  (Pointer<Uint8>, int) asNativePointer() {
    // 1. Allocate native memory (data.lengthInBytes)
    final Pointer<Uint8> nativeBuffer = calloc<Uint8>(lengthInBytes);

    // 2. Get a TypedData view of that native memory and copy
    final nativeView = nativeBuffer.asTypedList(lengthInBytes);
    nativeView.setAll(0, buffer.asUint8List(offsetInBytes, lengthInBytes));

    _uint8Finalizer.attach(this, nativeBuffer, detach: this);

    return (nativeBuffer, lengthInBytes);
  }
}

extension VectorOfStringConv on List<String> {
  Pointer<Pointer<Utf8>> asNativePointer() {
    // 1. Allocate an array of pointers (Pointer<Pointer<Utf8>>)
    final Pointer<Pointer<Utf8>> ptrArray = calloc.allocate<Pointer<Utf8>>(
      sizeOf<Pointer<Utf8>>() * length
    );

    // 2. Convert each Dart string to a Native Utf8 string
    for (int i = 0; i < length; i++) {
      ptrArray[i] = this[i].toNativeUtf8();
    }

    return ptrArray;
  }

  static void cleanupPointer(Pointer<Pointer<Utf8>> ptr, int length) {
    // Free each individual string
    for (int i = 0; i < length; i++) {
      calloc.free(ptr[i]);
    }
    // Free the array of pointers
    calloc.free(ptr);
  }
}
