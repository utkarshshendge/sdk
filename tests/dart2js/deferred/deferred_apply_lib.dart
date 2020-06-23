// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library deferred_apply_lib;

String apply1(Function f) {
  return Function.apply(f, [], {#req1: 10});
}

String apply2(Function f) {
  return Function.apply(f, []);
}