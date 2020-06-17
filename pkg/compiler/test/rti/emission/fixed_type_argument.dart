// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart = 2.7

/*spec:nnbd-off|spec:nnbd-sdk.class: A:checkedInstance,checkedTypeArgument,checks=[],typeArgument*/
/*prod:nnbd-off|prod:nnbd-sdk.class: A:checkedTypeArgument,checks=[],typeArgument*/
class A {}

/*spec:nnbd-off|spec:nnbd-sdk.class: B:checkedInstance,checks=[$isA],typeArgument*/
/*prod:nnbd-off|prod:nnbd-sdk.class: B:checks=[$isA],typeArgument*/
class B implements A {}

/*class: C:checks=[],indirectInstance*/
class C<T> {
  @pragma('dart2js:noInline')
  method(void Function(T) f) {}
}

/*class: D:checks=[],instance*/
class D extends C<B> {}

main() {
  C<A> c = new D();
  c.method(
      /*spec:nnbd-off|spec:nnbd-sdk.checks=[$signature],instance*/
      /*prod:nnbd-off|prod:nnbd-sdk.checks=[],instance*/
      (A a) {});
}