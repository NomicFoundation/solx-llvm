// RUN: mlir-opt -sol-licm %s | FileCheck %s

// CHECK-LABEL: sol.func @f(
// CHECK-SAME:    %[[A:.*]]: !sol.ptr<ui256, Storage>
// CHECK:         sol.load %[[A]]
// CHECK-NEXT:    scf.for
// CHECK-NEXT:    }
// A zero-trip loop's load is not hoisted.
// CHECK-NEXT:    scf.for %{{.*}} = %[[C5:.*]] to %[[C5]] step
// CHECK-NEXT:      sol.load %[[A]]
// CHECK-NEXT:    }
// A store to the loaded slot keeps the load in the loop.
// CHECK-NEXT:    scf.for
// CHECK-NEXT:      sol.load %[[A]]
// CHECK-NEXT:      sol.store %{{.*}}, %[[A]]
// CHECK-NEXT:    }

module {

sol.func @f(%a: !sol.ptr<ui256, Storage>) {
  %c0 = sol.constant 0 : ui256
  %c1 = arith.constant 1 : index
  %c5 = arith.constant 5 : index
  scf.for %i = %c1 to %c5 step %c1 {
    %a.ld = sol.load %a : !sol.ptr<ui256, Storage>, ui256
  }
  scf.for %i = %c5 to %c5 step %c1 {
    %a.ld = sol.load %a : !sol.ptr<ui256, Storage>, ui256
  }
  scf.for %i = %c1 to %c5 step %c1 {
    %a.ld = sol.load %a : !sol.ptr<ui256, Storage>, ui256
    sol.store %c0, %a : ui256, !sol.ptr<ui256, Storage>
  }
  sol.return
}

}
