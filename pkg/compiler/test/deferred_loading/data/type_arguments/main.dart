// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/*library: 
 output_units=[
  f1: {units: [1{lib1}], usedBy: [], needs: []},
  f2: {units: [2{lib3}], usedBy: [], needs: []}],
 steps=[
  lib1=(f1),
  lib3=(f2)]
*/

// @dart = 2.7

import 'lib1.dart' deferred as lib1;
import 'lib2.dart' as lib2;
import 'lib3.dart' deferred as lib3;

/*member: main:
 constants=[
  ConstructedConstant(A<B*>())=1{lib1},
  ConstructedConstant(A<F*>())=1{lib1},
  ConstructedConstant(C<D*>())=main{},
  ConstructedConstant(E<F*>())=2{lib3}],
 member_unit=main{}
*/
main() async {
  await lib1.loadLibrary();
  lib1.field1;
  lib1.field2;
  lib2.field;
  lib3.field;
}
