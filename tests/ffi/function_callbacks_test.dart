// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// Dart test program for testing dart:ffi function pointers with callbacks.
//
// VMOptions=--enable-testing-pragmas
// VMOptions=--enable-testing-pragmas --stacktrace-every=100
// VMOptions=--enable-testing-pragmas --write-protect-code --no-dual-map-code
// VMOptions=--enable-testing-pragmas --write-protect-code --no-dual-map-code --stacktrace-every=100
// VMOptions=--use-slow-path --enable-testing-pragmas
// VMOptions=--use-slow-path --enable-testing-pragmas --stacktrace-every=100
// VMOptions=--use-slow-path --enable-testing-pragmas --write-protect-code --no-dual-map-code
// VMOptions=--use-slow-path --enable-testing-pragmas --write-protect-code --no-dual-map-code --stacktrace-every=100
// SharedObjects=ffi_test_functions

library FfiTest;

import 'dart:io';
import 'dart:ffi';
import 'dart:isolate';
import 'dylib_utils.dart';

import "package:expect/expect.dart";

import 'ffi_test_helpers.dart';

typedef NativeCallbackTest = Int32 Function(Pointer);
typedef NativeCallbackTestFn = int Function(Pointer);

final DynamicLibrary testLibrary = dlopenPlatformSpecific("ffi_test_functions");

class Test {
  final String name;
  final Pointer callback;
  final bool skip;

  Test(this.name, this.callback, {bool skipIf: false}) : skip = skipIf {}

  void run() {
    if (skip) return;

    final NativeCallbackTestFn tester = testLibrary
        .lookupFunction<NativeCallbackTest, NativeCallbackTestFn>("Test$name");
    final int testCode = tester(callback);
    if (testCode != 0) {
      Expect.fail("Test $name failed.");
    }
  }
}

typedef SimpleAdditionType = Int32 Function(Int32, Int32);
int simpleAddition(int x, int y) => x + y;

typedef IntComputationType = Int64 Function(Int8, Int16, Int32, Int64);
int intComputation(int a, int b, int c, int d) => d - c + b - a;

typedef UintComputationType = Uint64 Function(Uint8, Uint16, Uint32, Uint64);
int uintComputation(int a, int b, int c, int d) => d - c + b - a;

typedef SimpleMultiplyType = Double Function(Double);
double simpleMultiply(double x) => x * 1.337;

typedef SimpleMultiplyFloatType = Float Function(Float);
double simpleMultiplyFloat(double x) => x * 1.337;

typedef ManyIntsType = IntPtr Function(IntPtr, IntPtr, IntPtr, IntPtr, IntPtr,
    IntPtr, IntPtr, IntPtr, IntPtr, IntPtr);
int manyInts(
    int a, int b, int c, int d, int e, int f, int g, int h, int i, int j) {
  return a + b + c + d + e + f + g + h + i + j;
}

typedef ManyDoublesType = Double Function(Double, Double, Double, Double,
    Double, Double, Double, Double, Double, Double);
double manyDoubles(double a, double b, double c, double d, double e, double f,
    double g, double h, double i, double j) {
  return a + b + c + d + e + f + g + h + i + j;
}

typedef ManyArgsType = Double Function(
    IntPtr,
    Float,
    IntPtr,
    Double,
    IntPtr,
    Float,
    IntPtr,
    Double,
    IntPtr,
    Float,
    IntPtr,
    Double,
    IntPtr,
    Float,
    IntPtr,
    Double,
    IntPtr,
    Float,
    IntPtr,
    Double);
double manyArgs(
    int _1,
    double _2,
    int _3,
    double _4,
    int _5,
    double _6,
    int _7,
    double _8,
    int _9,
    double _10,
    int _11,
    double _12,
    int _13,
    double _14,
    int _15,
    double _16,
    int _17,
    double _18,
    int _19,
    double _20) {
  return _1 +
      _2 +
      _3 +
      _4 +
      _5 +
      _6 +
      _7 +
      _8 +
      _9 +
      _10 +
      _11 +
      _12 +
      _13 +
      _14 +
      _15 +
      _16 +
      _17 +
      _18 +
      _19 +
      _20;
}

typedef StoreType = Pointer<Int64> Function(Pointer<Int64>);
Pointer<Int64> store(Pointer<Int64> ptr) => ptr.elementAt(1)..value = 1337;

typedef NullPointersType = Pointer<Int64> Function(Pointer<Int64>);
Pointer<Int64> nullPointers(Pointer<Int64> ptr) => ptr.elementAt(1);

typedef ReturnNullType = Int32 Function();
int returnNull() {
  return null;
}

typedef ReturnVoid = Void Function();
void returnVoid() {}

void throwException() {
  throw "Exception.";
}

typedef ThrowExceptionInt = IntPtr Function();
int throwExceptionInt() {
  throw "Exception.";
}

typedef ThrowExceptionDouble = Double Function();
double throwExceptionDouble() {
  throw "Exception.";
}

typedef ThrowExceptionPointer = Pointer<Void> Function();
Pointer<Void> throwExceptionPointer() {
  throw "Exception.";
}

void testGC() {
  triggerGc();
}

typedef WaitForHelper = Void Function(Pointer<Void>);
void waitForHelper(Pointer<Void> helper) {
  print("helper: $helper");
  testLibrary
      .lookupFunction<WaitForHelper, WaitForHelper>("WaitForHelper")(helper);
}

final List<Test> testcases = [
  Test("SimpleAddition",
      Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 0)),
  Test("IntComputation",
      Pointer.fromFunction<IntComputationType>(intComputation, 0)),
  Test("UintComputation",
      Pointer.fromFunction<UintComputationType>(uintComputation, 0)),
  Test("SimpleMultiply",
      Pointer.fromFunction<SimpleMultiplyType>(simpleMultiply, 0.0)),
  Test("SimpleMultiplyFloat",
      Pointer.fromFunction<SimpleMultiplyFloatType>(simpleMultiplyFloat, 0.0)),
  Test("ManyInts", Pointer.fromFunction<ManyIntsType>(manyInts, 0)),
  Test("ManyDoubles", Pointer.fromFunction<ManyDoublesType>(manyDoubles, 0.0)),
  Test("ManyArgs", Pointer.fromFunction<ManyArgsType>(manyArgs, 0.0)),
  Test("Store", Pointer.fromFunction<StoreType>(store)),
  Test("NullPointers", Pointer.fromFunction<NullPointersType>(nullPointers)),
  Test("ReturnNull", Pointer.fromFunction<ReturnNullType>(returnNull, 42)),
  Test("ReturnVoid", Pointer.fromFunction<ReturnVoid>(returnVoid)),
  Test("ThrowExceptionDouble",
      Pointer.fromFunction<ThrowExceptionDouble>(throwExceptionDouble, 42.0)),
  Test("ThrowExceptionPointer",
      Pointer.fromFunction<ThrowExceptionPointer>(throwExceptionPointer)),
  Test("ThrowException",
      Pointer.fromFunction<ThrowExceptionInt>(throwExceptionInt, 42)),
  Test("GC", Pointer.fromFunction<ReturnVoid>(testGC)),
  Test("UnprotectCode", Pointer.fromFunction<WaitForHelper>(waitForHelper)),
];

testCallbackWrongThread() =>
    Test("CallbackWrongThread", Pointer.fromFunction<ReturnVoid>(returnVoid))
        .run();

testCallbackOutsideIsolate() =>
    Test("CallbackOutsideIsolate", Pointer.fromFunction<ReturnVoid>(returnVoid))
        .run();

isolateHelper(int callbackPointer) {
  final Pointer<Void> ptr = Pointer.fromAddress(callbackPointer);
  final NativeCallbackTestFn tester =
      testLibrary.lookupFunction<NativeCallbackTest, NativeCallbackTestFn>(
          "TestCallbackWrongIsolate");
  Expect.equals(0, tester(ptr));
}

testCallbackWrongIsolate() async {
  final int callbackPointer =
      Pointer.fromFunction<ReturnVoid>(returnVoid).address;
  final ReceivePort exitPort = ReceivePort();
  await Isolate.spawn(isolateHelper, callbackPointer,
      errorsAreFatal: true, onExit: exitPort.sendPort);
  await exitPort.first;
}

const double zeroPointZero = 0.0;

// Correct type of exceptionalReturn argument to Pointer.fromFunction.
double testExceptionalReturn() {
  Pointer.fromFunction<Double Function()>(testExceptionalReturn, 0.0);
  Pointer.fromFunction<Double Function()>(testExceptionalReturn, zeroPointZero);

  Pointer.fromFunction<Double Function()>(returnVoid, null);  //# 59: compile-time error
  Pointer.fromFunction<Void Function()>(returnVoid, 0);  //# 60: compile-time error
  Pointer.fromFunction<Double Function()>(testExceptionalReturn, "abc");  //# 61: compile-time error
  Pointer.fromFunction<Double Function()>(testExceptionalReturn, 0);  //# 62: compile-time error
  Pointer.fromFunction<Double Function()>(testExceptionalReturn);  //# 63: compile-time error
}

void main() async {
  testcases.forEach((t) => t.run()); //# 00: ok
  testExceptionalReturn(); //# 00: ok

  // These tests terminate the process after successful completion, so we have
  // to run them separately.
  //
  // Since they use signal handlers they only run on Linux.
  if (Platform.isLinux && !const bool.fromEnvironment("dart.vm.product")) {
    testCallbackWrongThread(); //# 01: ok
    testCallbackOutsideIsolate(); //# 02: ok
    await testCallbackWrongIsolate(); //# 03: ok
  }

  testManyCallbacks(); //# 04: ok
}

void testManyCallbacks() {
  // Create enough callbacks (1000) to overflow one page of the JIT callback
  // trampolines. The use of distinct exceptional return values forces separate
  // trampolines.
  final List<Pointer> pointers = [];

  // All the parameters of 'fromFunction' are forced to be constant so that we
  // only need to generate one trampoline per 'fromFunction' call-site.
  //
  // As a consequence, to force the creation of 1000 trampolines (and prevent
  // any possible caching), we need literally 1000 call-sites.
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 0));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 1));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 2));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 3));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 4));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 5));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 6));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 7));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 8));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 9));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 10));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 11));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 12));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 13));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 14));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 15));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 16));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 17));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 18));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 19));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 20));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 21));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 22));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 23));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 24));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 25));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 26));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 27));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 28));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 29));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 30));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 31));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 32));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 33));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 34));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 35));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 36));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 37));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 38));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 39));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 40));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 41));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 42));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 43));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 44));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 45));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 46));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 47));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 48));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 49));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 50));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 51));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 52));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 53));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 54));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 55));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 56));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 57));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 58));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 59));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 60));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 61));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 62));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 63));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 64));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 65));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 66));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 67));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 68));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 69));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 70));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 71));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 72));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 73));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 74));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 75));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 76));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 77));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 78));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 79));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 80));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 81));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 82));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 83));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 84));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 85));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 86));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 87));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 88));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 89));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 90));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 91));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 92));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 93));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 94));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 95));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 96));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 97));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 98));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 99));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 100));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 101));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 102));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 103));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 104));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 105));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 106));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 107));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 108));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 109));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 110));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 111));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 112));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 113));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 114));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 115));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 116));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 117));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 118));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 119));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 120));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 121));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 122));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 123));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 124));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 125));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 126));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 127));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 128));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 129));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 130));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 131));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 132));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 133));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 134));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 135));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 136));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 137));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 138));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 139));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 140));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 141));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 142));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 143));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 144));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 145));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 146));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 147));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 148));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 149));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 150));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 151));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 152));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 153));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 154));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 155));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 156));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 157));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 158));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 159));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 160));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 161));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 162));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 163));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 164));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 165));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 166));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 167));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 168));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 169));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 170));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 171));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 172));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 173));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 174));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 175));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 176));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 177));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 178));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 179));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 180));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 181));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 182));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 183));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 184));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 185));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 186));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 187));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 188));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 189));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 190));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 191));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 192));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 193));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 194));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 195));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 196));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 197));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 198));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 199));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 200));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 201));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 202));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 203));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 204));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 205));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 206));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 207));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 208));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 209));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 210));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 211));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 212));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 213));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 214));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 215));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 216));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 217));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 218));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 219));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 220));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 221));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 222));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 223));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 224));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 225));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 226));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 227));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 228));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 229));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 230));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 231));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 232));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 233));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 234));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 235));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 236));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 237));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 238));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 239));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 240));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 241));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 242));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 243));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 244));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 245));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 246));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 247));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 248));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 249));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 250));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 251));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 252));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 253));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 254));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 255));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 256));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 257));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 258));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 259));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 260));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 261));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 262));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 263));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 264));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 265));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 266));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 267));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 268));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 269));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 270));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 271));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 272));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 273));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 274));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 275));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 276));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 277));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 278));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 279));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 280));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 281));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 282));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 283));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 284));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 285));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 286));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 287));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 288));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 289));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 290));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 291));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 292));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 293));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 294));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 295));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 296));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 297));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 298));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 299));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 300));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 301));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 302));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 303));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 304));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 305));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 306));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 307));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 308));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 309));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 310));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 311));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 312));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 313));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 314));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 315));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 316));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 317));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 318));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 319));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 320));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 321));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 322));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 323));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 324));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 325));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 326));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 327));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 328));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 329));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 330));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 331));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 332));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 333));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 334));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 335));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 336));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 337));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 338));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 339));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 340));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 341));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 342));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 343));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 344));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 345));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 346));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 347));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 348));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 349));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 350));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 351));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 352));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 353));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 354));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 355));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 356));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 357));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 358));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 359));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 360));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 361));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 362));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 363));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 364));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 365));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 366));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 367));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 368));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 369));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 370));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 371));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 372));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 373));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 374));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 375));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 376));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 377));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 378));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 379));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 380));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 381));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 382));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 383));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 384));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 385));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 386));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 387));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 388));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 389));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 390));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 391));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 392));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 393));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 394));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 395));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 396));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 397));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 398));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 399));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 400));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 401));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 402));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 403));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 404));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 405));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 406));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 407));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 408));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 409));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 410));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 411));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 412));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 413));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 414));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 415));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 416));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 417));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 418));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 419));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 420));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 421));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 422));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 423));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 424));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 425));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 426));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 427));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 428));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 429));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 430));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 431));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 432));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 433));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 434));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 435));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 436));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 437));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 438));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 439));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 440));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 441));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 442));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 443));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 444));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 445));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 446));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 447));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 448));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 449));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 450));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 451));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 452));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 453));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 454));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 455));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 456));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 457));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 458));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 459));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 460));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 461));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 462));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 463));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 464));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 465));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 466));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 467));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 468));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 469));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 470));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 471));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 472));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 473));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 474));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 475));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 476));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 477));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 478));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 479));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 480));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 481));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 482));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 483));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 484));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 485));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 486));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 487));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 488));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 489));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 490));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 491));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 492));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 493));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 494));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 495));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 496));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 497));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 498));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 499));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 500));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 501));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 502));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 503));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 504));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 505));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 506));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 507));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 508));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 509));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 510));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 511));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 512));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 513));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 514));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 515));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 516));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 517));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 518));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 519));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 520));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 521));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 522));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 523));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 524));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 525));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 526));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 527));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 528));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 529));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 530));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 531));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 532));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 533));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 534));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 535));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 536));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 537));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 538));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 539));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 540));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 541));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 542));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 543));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 544));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 545));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 546));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 547));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 548));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 549));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 550));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 551));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 552));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 553));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 554));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 555));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 556));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 557));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 558));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 559));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 560));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 561));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 562));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 563));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 564));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 565));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 566));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 567));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 568));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 569));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 570));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 571));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 572));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 573));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 574));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 575));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 576));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 577));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 578));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 579));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 580));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 581));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 582));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 583));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 584));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 585));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 586));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 587));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 588));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 589));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 590));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 591));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 592));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 593));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 594));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 595));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 596));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 597));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 598));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 599));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 600));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 601));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 602));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 603));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 604));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 605));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 606));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 607));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 608));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 609));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 610));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 611));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 612));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 613));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 614));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 615));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 616));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 617));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 618));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 619));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 620));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 621));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 622));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 623));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 624));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 625));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 626));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 627));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 628));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 629));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 630));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 631));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 632));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 633));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 634));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 635));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 636));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 637));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 638));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 639));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 640));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 641));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 642));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 643));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 644));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 645));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 646));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 647));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 648));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 649));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 650));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 651));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 652));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 653));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 654));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 655));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 656));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 657));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 658));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 659));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 660));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 661));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 662));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 663));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 664));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 665));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 666));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 667));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 668));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 669));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 670));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 671));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 672));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 673));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 674));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 675));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 676));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 677));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 678));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 679));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 680));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 681));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 682));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 683));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 684));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 685));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 686));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 687));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 688));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 689));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 690));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 691));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 692));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 693));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 694));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 695));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 696));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 697));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 698));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 699));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 700));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 701));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 702));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 703));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 704));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 705));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 706));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 707));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 708));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 709));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 710));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 711));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 712));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 713));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 714));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 715));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 716));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 717));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 718));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 719));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 720));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 721));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 722));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 723));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 724));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 725));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 726));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 727));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 728));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 729));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 730));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 731));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 732));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 733));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 734));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 735));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 736));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 737));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 738));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 739));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 740));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 741));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 742));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 743));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 744));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 745));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 746));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 747));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 748));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 749));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 750));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 751));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 752));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 753));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 754));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 755));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 756));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 757));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 758));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 759));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 760));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 761));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 762));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 763));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 764));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 765));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 766));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 767));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 768));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 769));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 770));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 771));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 772));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 773));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 774));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 775));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 776));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 777));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 778));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 779));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 780));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 781));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 782));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 783));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 784));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 785));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 786));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 787));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 788));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 789));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 790));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 791));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 792));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 793));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 794));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 795));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 796));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 797));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 798));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 799));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 800));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 801));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 802));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 803));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 804));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 805));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 806));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 807));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 808));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 809));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 810));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 811));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 812));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 813));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 814));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 815));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 816));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 817));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 818));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 819));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 820));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 821));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 822));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 823));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 824));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 825));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 826));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 827));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 828));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 829));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 830));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 831));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 832));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 833));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 834));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 835));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 836));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 837));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 838));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 839));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 840));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 841));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 842));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 843));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 844));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 845));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 846));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 847));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 848));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 849));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 850));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 851));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 852));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 853));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 854));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 855));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 856));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 857));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 858));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 859));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 860));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 861));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 862));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 863));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 864));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 865));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 866));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 867));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 868));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 869));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 870));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 871));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 872));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 873));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 874));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 875));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 876));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 877));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 878));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 879));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 880));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 881));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 882));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 883));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 884));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 885));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 886));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 887));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 888));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 889));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 890));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 891));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 892));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 893));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 894));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 895));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 896));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 897));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 898));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 899));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 900));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 901));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 902));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 903));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 904));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 905));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 906));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 907));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 908));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 909));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 910));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 911));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 912));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 913));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 914));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 915));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 916));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 917));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 918));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 919));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 920));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 921));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 922));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 923));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 924));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 925));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 926));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 927));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 928));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 929));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 930));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 931));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 932));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 933));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 934));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 935));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 936));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 937));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 938));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 939));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 940));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 941));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 942));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 943));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 944));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 945));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 946));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 947));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 948));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 949));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 950));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 951));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 952));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 953));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 954));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 955));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 956));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 957));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 958));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 959));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 960));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 961));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 962));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 963));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 964));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 965));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 966));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 967));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 968));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 969));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 970));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 971));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 972));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 973));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 974));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 975));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 976));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 977));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 978));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 979));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 980));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 981));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 982));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 983));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 984));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 985));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 986));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 987));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 988));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 989));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 990));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 991));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 992));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 993));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 994));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 995));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 996));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 997));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 998));
  pointers.add(Pointer.fromFunction<SimpleAdditionType>(simpleAddition, 999));

  for (final pointer in pointers) {
    Test("SimpleAddition", pointer).run();
  }
}
