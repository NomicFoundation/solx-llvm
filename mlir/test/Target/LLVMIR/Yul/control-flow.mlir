// RUN: mlir-translate --mlir-to-llvmir %s | FileCheck %s

// CHECK-LABEL: define void @__entry(
// CHECK-SAME: ) #{{[0-9]+}} {
// CHECK-NEXT: call void @llvm.evm.stop()
// CHECK-NEXT: unreachable
// CHECK-NEXT: }
// CHECK-LABEL: define private i256 @if_else(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V3:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V3]], label %[[V4:[0-9]+]], label %[[V6:[0-9]+]]
// CHECK: [[V4]]:
// CHECK-NEXT: %[[V5:[0-9]+]] = add i256 %[[V1]], 1
// CHECK-NEXT: br label %[[V8:[0-9]+]]
// CHECK: [[V6]]:
// CHECK-NEXT: %[[V7:[0-9]+]] = sub i256 %[[V1]], 1
// CHECK-NEXT: br label %[[V8]]
// CHECK: [[V8]]:
// CHECK-NEXT: %[[V9:[0-9]+]] = phi i256 [ %[[V5]], %[[V4]] ], [ %[[V7]], %[[V6]] ]
// CHECK-NEXT: ret i256 %[[V9]]
// CHECK-NEXT: }
// CHECK-LABEL: define private void @if_no_else(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V2]], label %[[V3:[0-9]+]], label %[[V4:[0-9]+]]
// CHECK: [[V3]]:
// CHECK-NEXT: store i256 %[[V0]], ptr addrspace(5) null, align 1
// CHECK-NEXT: br label %[[V4]]
// CHECK: [[V4]]:
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @halt(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V2]], label %[[V3:[0-9]+]], label %[[V4:[0-9]+]]
// CHECK: [[V3]]:
// CHECK-NEXT: call void @llvm.evm.revert(ptr addrspace(1) null, i256 0)
// CHECK-NEXT: unreachable
// CHECK: [[V4]]:
// CHECK-NEXT: call void @llvm.evm.invalid()
// CHECK-NEXT: unreachable
// CHECK-NEXT: }
// CHECK-LABEL: define private void @halt_call(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: call void @halt(i256 %[[V0]])
// CHECK-NEXT: unreachable
// CHECK-NEXT: }
// CHECK-LABEL: define private i256 @switch(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: switch i256 %[[V0]], label %[[V5:[0-9]+]] [
// CHECK-NEXT: i256 1, label %[[V2:[0-9]+]]
// CHECK-NEXT: i256 2, label %[[V3:[0-9]+]]
// CHECK-NEXT: ]
// CHECK: [[V2]]:
// CHECK-NEXT: br label %[[V6:[0-9]+]]
// CHECK: [[V3]]:
// CHECK-NEXT: %[[V4:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: call void @llvm.evm.revert(ptr addrspace(1) %[[V4]], i256 %[[V0]])
// CHECK-NEXT: unreachable
// CHECK: [[V5]]:
// CHECK-NEXT: br label %[[V6]]
// CHECK: [[V6]]:
// CHECK-NEXT: %[[V7:[0-9]+]] = phi i256 [ 2, %[[V2]] ], [ 1, %[[V5]] ]
// CHECK-NEXT: ret i256 %[[V7]]
// CHECK-NEXT: }
// CHECK-LABEL: define private void @switch_default(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: br label %[[V2:[0-9]+]]
// CHECK: [[V2]]:
// CHECK-NEXT: %[[V3:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(5)
// CHECK-NEXT: store i256 %[[V0]], ptr addrspace(5) %[[V3]], align 1
// CHECK-NEXT: br label %[[V4:[0-9]+]]
// CHECK: [[V4]]:
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private i256 @for(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: br label %[[V2:[0-9]+]]
// CHECK: [[V2]]:
// CHECK-NEXT: %[[V3:[0-9]+]] = phi i256 [ 0, %[[V1:[0-9]+]] ], [ %[[V14:[0-9]+]], %[[V11:[0-9]+]] ]
// CHECK-NEXT: %[[V4:[0-9]+]] = phi i256 [ 0, %[[V1]] ], [ %[[V13:[0-9]+]], %[[V11]] ]
// CHECK-NEXT: %[[V5:[0-9]+]] = icmp ult i256 %[[V3]], %[[V0]]
// CHECK-NEXT: %[[V6:[0-9]+]] = zext i1 %[[V5]] to i256
// CHECK-NEXT: br i1 %[[V5]], label %[[V7:[0-9]+]], label %[[V15:[0-9]+]]
// CHECK: [[V7]]:
// CHECK-NEXT: %[[V8:[0-9]+]] = phi i256 [ %[[V3]], %[[V2]] ]
// CHECK-NEXT: %[[V9:[0-9]+]] = phi i256 [ %[[V4]], %[[V2]] ]
// CHECK-NEXT: %[[V10:[0-9]+]] = add i256 %[[V9]], %[[V8]]
// CHECK-NEXT: br label %[[V11]]
// CHECK: [[V11]]:
// CHECK-NEXT: %[[V12:[0-9]+]] = phi i256 [ %[[V8]], %[[V7]] ]
// CHECK-NEXT: %[[V13]] = phi i256 [ %[[V10]], %[[V7]] ]
// CHECK-NEXT: %[[V14]] = add i256 %[[V12]], 1
// CHECK-NEXT: br label %[[V2]], !llvm.loop !1
// CHECK: [[V15]]:
// CHECK-NEXT: %[[V16:[0-9]+]] = phi i256 [ %[[V3]], %[[V2]] ]
// CHECK-NEXT: %[[V17:[0-9]+]] = phi i256 [ %[[V4]], %[[V2]] ]
// CHECK-NEXT: ret i256 %[[V17]]
// CHECK-NEXT: }
// CHECK-LABEL: define private void @break_continue(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: br label %[[V2:[0-9]+]]
// CHECK: [[V2]]:
// CHECK-NEXT: %[[V3:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V3]], label %[[V4:[0-9]+]], label %[[V14:[0-9]+]]
// CHECK: [[V4]]:
// CHECK-NEXT: %[[V5:[0-9]+]] = load i256, ptr addrspace(5) null, align 1
// CHECK-NEXT: %[[V6:[0-9]+]] = icmp ne i256 %[[V5]], 0
// CHECK-NEXT: br i1 %[[V6]], label %[[V7:[0-9]+]], label %[[V8:[0-9]+]]
// CHECK: [[V7]]:
// CHECK-NEXT: br label %[[V14]]
// CHECK: [[V8]]:
// CHECK-NEXT: %[[V9:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V9]], label %[[V10:[0-9]+]], label %[[V11:[0-9]+]]
// CHECK: [[V10]]:
// CHECK-NEXT: br label %[[V12:[0-9]+]]
// CHECK: [[V11]]:
// CHECK-NEXT: store i256 %[[V0]], ptr addrspace(5) null, align 1
// CHECK-NEXT: br label %[[V12]]
// CHECK: [[V12]]:
// CHECK-NEXT: %[[V13:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(5)
// CHECK-NEXT: store i256 0, ptr addrspace(5) %[[V13]], align 1
// CHECK-NEXT: br label %[[V2]]
// CHECK: [[V14]]:
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @dead_step(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: br label %[[V2:[0-9]+]]
// CHECK: [[V2]]:
// CHECK-NEXT: %[[V3:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V3]], label %[[V4:[0-9]+]], label %[[V5:[0-9]+]]
// CHECK: [[V4]]:
// CHECK-NEXT: br label %[[V5]]
// CHECK: [[V5]]:
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @halt_switch(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: switch i256 %[[V0]], label %[[V3:[0-9]+]] [
// CHECK-NEXT: i256 1, label %[[V2:[0-9]+]]
// CHECK-NEXT: ]
// CHECK: [[V2]]:
// CHECK-NEXT: call void @llvm.evm.stop()
// CHECK-NEXT: unreachable
// CHECK: [[V3]]:
// CHECK-NEXT: %[[V4:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: call void @llvm.evm.revert(ptr addrspace(1) %[[V4]], i256 %[[V0]])
// CHECK-NEXT: unreachable
// CHECK-NEXT: }
// CHECK-LABEL: define private void @halt_for_body(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: br label %[[V2:[0-9]+]]
// CHECK: [[V2]]:
// CHECK-NEXT: %[[V3:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V3]], label %[[V4:[0-9]+]], label %[[V5:[0-9]+]]
// CHECK: [[V4]]:
// CHECK-NEXT: call void @llvm.evm.invalid()
// CHECK-NEXT: unreachable
// CHECK: [[V5]]:
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @halt_do_while_body(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: br label %[[V2:[0-9]+]]
// CHECK: [[V2]]:
// CHECK-NEXT: call void @llvm.evm.stop()
// CHECK-NEXT: unreachable
// CHECK-NEXT: }
// CHECK-LABEL: define private i256 @while(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: br label %[[V2:[0-9]+]]
// CHECK: [[V2]]:
// CHECK-NEXT: %[[V3:[0-9]+]] = phi i256 [ %[[V0]], %[[V1:[0-9]+]] ], [ %[[V7:[0-9]+]], %[[V5:[0-9]+]] ]
// CHECK-NEXT: %[[V4:[0-9]+]] = icmp ne i256 %[[V3]], 0
// CHECK-NEXT: br i1 %[[V4]], label %[[V5]], label %[[V8:[0-9]+]]
// CHECK: [[V5]]:
// CHECK-NEXT: %[[V6:[0-9]+]] = phi i256 [ %[[V3]], %[[V2]] ]
// CHECK-NEXT: %[[V7]] = sub i256 %[[V6]], 1
// CHECK-NEXT: br label %[[V2]]
// CHECK: [[V8]]:
// CHECK-NEXT: %[[V9:[0-9]+]] = phi i256 [ %[[V3]], %[[V2]] ]
// CHECK-NEXT: ret i256 %[[V9]]
// CHECK-NEXT: }
// CHECK-LABEL: define private void @while_continue(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: br label %[[V2:[0-9]+]]
// CHECK: [[V2]]:
// CHECK-NEXT: %[[V3:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V3]], label %[[V4:[0-9]+]], label %[[V9:[0-9]+]]
// CHECK: [[V4]]:
// CHECK-NEXT: %[[V5:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V5]], label %[[V6:[0-9]+]], label %[[V7:[0-9]+]]
// CHECK: [[V6]]:
// CHECK-NEXT: br label %[[V2]]
// CHECK: [[V7]]:
// CHECK-NEXT: %[[V8:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(5)
// CHECK-NEXT: store i256 %[[V0]], ptr addrspace(5) %[[V8]], align 1
// CHECK-NEXT: br label %[[V2]]
// CHECK: [[V9]]:
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @unroll_step_return(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: br label %[[V2:[0-9]+]]
// CHECK: [[V2]]:
// CHECK-NEXT: %[[V3:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V3]], label %[[V4:[0-9]+]], label %[[V6:[0-9]+]]
// CHECK: [[V4]]:
// CHECK-NEXT: br label %[[V5:[0-9]+]]
// CHECK: [[V5]]:
// CHECK-NEXT: ret void
// CHECK: [[V6]]:
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @do_while(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: br label %[[V2:[0-9]+]]
// CHECK: [[V2]]:
// CHECK-NEXT: store i256 %[[V0]], ptr addrspace(5) null, align 1
// CHECK-NEXT: br label %[[V3:[0-9]+]]
// CHECK: [[V3]]:
// CHECK-NEXT: %[[V4:[0-9]+]] = load i256, ptr addrspace(5) null, align 1
// CHECK-NEXT: %[[V5:[0-9]+]] = icmp ne i256 %[[V4]], 0
// CHECK-NEXT: br i1 %[[V5]], label %[[V2]], label %[[V6:[0-9]+]]
// CHECK: [[V6]]:
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @scope(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V2]], label %[[V3:[0-9]+]], label %[[V4:[0-9]+]]
// CHECK: [[V3]]:
// CHECK-NEXT: br label %[[V5:[0-9]+]]
// CHECK: [[V4]]:
// CHECK-NEXT: store i256 %[[V0]], ptr addrspace(5) null, align 1
// CHECK-NEXT: br label %[[V5]]
// CHECK: [[V5]]:
// CHECK-NEXT: %[[V6:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(5)
// CHECK-NEXT: store i256 0, ptr addrspace(5) %[[V6]], align 1
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private i256 @early_return(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V2]], label %[[V3:[0-9]+]], label %[[V4:[0-9]+]]
// CHECK: [[V3]]:
// CHECK-NEXT: ret i256 0
// CHECK: [[V4]]:
// CHECK-NEXT: ret i256 %[[V0]]
// CHECK-NEXT: }
// CHECK-LABEL: define private void @nested_loops(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: br label %[[V2:[0-9]+]]
// CHECK: [[V2]]:
// CHECK-NEXT: %[[V3:[0-9]+]] = load i256, ptr addrspace(5) null, align 1
// CHECK-NEXT: %[[V4:[0-9]+]] = icmp ne i256 %[[V3]], 0
// CHECK-NEXT: br i1 %[[V4]], label %[[V5:[0-9]+]], label %[[V24:[0-9]+]]
// CHECK: [[V5]]:
// CHECK-NEXT: br label %[[V6:[0-9]+]]
// CHECK: [[V6]]:
// CHECK-NEXT: %[[V7:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(5)
// CHECK-NEXT: %[[V8:[0-9]+]] = load i256, ptr addrspace(5) %[[V7]], align 1
// CHECK-NEXT: %[[V9:[0-9]+]] = icmp ne i256 %[[V8]], 0
// CHECK-NEXT: br i1 %[[V9]], label %[[V10:[0-9]+]], label %[[V18:[0-9]+]]
// CHECK: [[V10]]:
// CHECK-NEXT: %[[V11:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(6)
// CHECK-NEXT: %[[V12:[0-9]+]] = load i256, ptr addrspace(6) %[[V11]], align 1
// CHECK-NEXT: %[[V13:[0-9]+]] = icmp ne i256 %[[V12]], 0
// CHECK-NEXT: br i1 %[[V13]], label %[[V14:[0-9]+]], label %[[V15:[0-9]+]]
// CHECK: [[V14]]:
// CHECK-NEXT: br label %[[V18]]
// CHECK: [[V15]]:
// CHECK-NEXT: %[[V16:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(5)
// CHECK-NEXT: store i256 0, ptr addrspace(5) %[[V16]], align 1
// CHECK-NEXT: br label %[[V17:[0-9]+]]
// CHECK: [[V17]]:
// CHECK-NEXT: store i256 %[[V0]], ptr addrspace(5) null, align 1
// CHECK-NEXT: br label %[[V6]]
// CHECK: [[V18]]:
// CHECK-NEXT: %[[V19:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: br i1 %[[V19]], label %[[V20:[0-9]+]], label %[[V21:[0-9]+]]
// CHECK: [[V20]]:
// CHECK-NEXT: br label %[[V22:[0-9]+]]
// CHECK: [[V21]]:
// CHECK-NEXT: store i256 0, ptr addrspace(5) null, align 1
// CHECK-NEXT: br label %[[V22]]
// CHECK: [[V22]]:
// CHECK-NEXT: %[[V23:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(5)
// CHECK-NEXT: store i256 %[[V0]], ptr addrspace(5) %[[V23]], align 1
// CHECK-NEXT: br label %[[V2]]
// CHECK: [[V24]]:
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @do_while_loop_cond(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: br label %[[V2:[0-9]+]]
// CHECK: [[V2]]:
// CHECK-NEXT: store i256 %[[V0]], ptr addrspace(5) null, align 1
// CHECK-NEXT: br label %[[V3:[0-9]+]]
// CHECK: [[V3]]:
// CHECK-NEXT: br label %[[V4:[0-9]+]]
// CHECK: [[V4]]:
// CHECK-NEXT: %[[V5:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(5)
// CHECK-NEXT: %[[V6:[0-9]+]] = load i256, ptr addrspace(5) %[[V5]], align 1
// CHECK-NEXT: %[[V7:[0-9]+]] = icmp ne i256 %[[V6]], 0
// CHECK-NEXT: br i1 %[[V7]], label %[[V8:[0-9]+]], label %[[V11:[0-9]+]]
// CHECK: [[V8]]:
// CHECK-NEXT: %[[V9:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(5)
// CHECK-NEXT: store i256 0, ptr addrspace(5) %[[V9]], align 1
// CHECK-NEXT: br label %[[V10:[0-9]+]]
// CHECK: [[V10]]:
// CHECK-NEXT: br label %[[V4]]
// CHECK: [[V11]]:
// CHECK-NEXT: %[[V12:[0-9]+]] = load i256, ptr addrspace(5) null, align 1
// CHECK-NEXT: %[[V13:[0-9]+]] = icmp ne i256 %[[V12]], 0
// CHECK-NEXT: br i1 %[[V13]], label %[[V2]], label %[[V14:[0-9]+]]
// CHECK: [[V14]]:
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK: declare void @llvm.evm.stop()
// CHECK: declare void @llvm.evm.revert(ptr addrspace(1) readonly, i256)
// CHECK: declare void @llvm.evm.invalid()
// CHECK: !llvm.module.flags = !{!0}
// CHECK: !0 = !{i32 2, !"Debug Info Version", i32 3}
// CHECK: !1 = distinct !{!1, !2}
// CHECK: !2 = !{!"llvm.loop.unroll.full"}

module {
  yul.object @Test {
    yul.func @__entry : () -> () {
      yul.stop
    }

    yul.func @if_else : (i256, i256) -> i256 {
    ^bb0(%c: i256, %x: i256):
      %c1 = yul.constant 1
      %0 = yul.if %c -> i256 {
        %1 = yul.add %x, %c1
        yul.yield %1 : i256
      } else {
        %1 = yul.sub %x, %c1
        yul.yield %1 : i256
      }
      yul.func_return %0 : i256
    }

    yul.func @if_no_else : (i256) -> () {
    ^bb0(%c: i256):
      %c0 = yul.constant 0
      yul.if %c {
        yul.sstore %c0, %c
        yul.yield
      } else {
      }
      yul.func_return
    }

    // Nothing reaches the ops after an if whose regions both halt.
    yul.func @halt : (i256) -> () {
    ^bb0(%c: i256):
      %c0 = yul.constant 0
      yul.if %c {
        yul.revert %c0, %c0
      } else {
        yul.invalid
      }
      yul.sstore %c0, %c0
      yul.func_return
    }

    // A call to a function that never returns ends its block.
    yul.func @halt_call : (i256) -> () {
    ^bb0(%c: i256):
      yul.func_call @halt(%c) : (i256) -> ()
      yul.unreachable
    }

    yul.func @switch : (i256) -> i256 {
    ^bb0(%x: i256):
      %c1 = yul.constant 1
      %c2 = yul.constant 2
      %0 = yul.switch %x : i256 -> i256
      case 1 {
        yul.yield %c2 : i256
      }
      case 2 {
        yul.revert %x, %x
      }
      default {
        yul.yield %c1 : i256
      }
      yul.func_return %0 : i256
    }

    yul.func @switch_default : (i256) -> () {
    ^bb0(%x: i256):
      yul.switch %x : i256
      default {
        yul.sstore %x, %x
        yul.yield
      }
      yul.func_return
    }

    // The loop-carried values are phis of the cond, body and step blocks.
    yul.func @for : (i256) -> i256 {
    ^bb0(%n: i256):
      %c0 = yul.constant 0
      %c1 = yul.constant 1
      %0:2 = yul.for %c0, %c0 : i256, i256 -> i256, i256 cond {
      ^bb0(%i: i256, %s: i256):
        %1 = yul.cmp ult, %i, %n
        yul.condition %1, %i, %s : i256, i256
      } body {
      ^bb0(%i: i256, %s: i256):
        %1 = yul.add %s, %i
        yul.yield %i, %1 : i256, i256
      } step {
      ^bb0(%i: i256, %s: i256):
        %1 = yul.add %i, %c1
        yul.yield %1, %s : i256, i256
      } {full_unroll}
      yul.func_return %0#1 : i256
    }

    yul.func @break_continue : (i256) -> () {
    ^bb0(%n: i256):
      %c0 = yul.constant 0
      yul.for cond {
        yul.condition %n
      } body {
        %0 = yul.sload %c0
        yul.if %0 {
          yul.break
        } else {
        }
        yul.if %n {
          yul.continue
        } else {
        }
        yul.sstore %c0, %n
        yul.yield
      } step {
        yul.sstore %n, %c0
        yul.yield
      }
      yul.func_return
    }

    // A body that only breaks leaves the step without a predecessor.
    yul.func @dead_step : (i256) -> () {
    ^bb0(%n: i256):
      yul.for cond {
        yul.condition %n
      } body {
        yul.break
      } step {
        yul.sstore %n, %n
        yul.yield
      }
      yul.func_return
    }

    // Nothing reaches the ops after a switch whose cases all halt.
    yul.func @halt_switch : (i256) -> () {
    ^bb0(%x: i256):
      yul.switch %x : i256
      case 1 {
        yul.stop
      }
      default {
        yul.revert %x, %x
      }
      yul.sstore %x, %x
      yul.func_return
    }

    // A halting body leaves the step without a predecessor.
    yul.func @halt_for_body : (i256) -> () {
    ^bb0(%n: i256):
      yul.for cond {
        yul.condition %n
      } body {
        yul.invalid
      } step {
        yul.sstore %n, %n
        yul.yield
      }
      yul.func_return
    }

    // A halting do-while body leaves the condition and the exit without a
    // predecessor.
    yul.func @halt_do_while_body : (i256) -> () {
    ^bb0(%n: i256):
      yul.do {
        yul.stop
      } while {
        %0 = yul.sload %n
        yul.condition %0
      }
      yul.sstore %n, %n
      yul.func_return
    }

    yul.func @while : (i256) -> i256 {
    ^bb0(%n: i256):
      %c1 = yul.constant 1
      %0 = yul.while %n : i256 -> i256 {
      ^bb0(%i: i256):
        yul.condition %i, %i : i256
      } do {
      ^bb0(%i: i256):
        %1 = yul.sub %i, %c1
        yul.yield %1 : i256
      }
      yul.func_return %0 : i256
    }

    // A continue in a loop without a step branches to the cond.
    yul.func @while_continue : (i256) -> () {
    ^bb0(%n: i256):
      yul.while {
        yul.condition %n
      } do {
        yul.if %n {
          yul.continue
        } else {
        }
        yul.sstore %n, %n
        yul.yield
      }
      yul.func_return
    }

    // A step that returns has no back edge to carry the unroll node.
    yul.func @unroll_step_return : (i256) -> () {
    ^bb0(%n: i256):
      yul.for cond {
        yul.condition %n
      } body {
        yul.yield
      } step {
        yul.func_return
      } {full_unroll}
      yul.func_return
    }

    // The body runs first and is placed first.
    yul.func @do_while : (i256) -> () {
    ^bb0(%n: i256):
      %c0 = yul.constant 0
      yul.do {
        yul.sstore %c0, %n
        yul.yield
      } while {
        %0 = yul.sload %c0
        yul.condition %0
      }
      yul.func_return
    }

    yul.func @scope : (i256) -> () {
    ^bb0(%n: i256):
      %c0 = yul.constant 0
      yul.scope {
        yul.if %n {
          yul.leave_scope
        } else {
        }
        yul.sstore %c0, %n
        yul.yield
      }
      yul.sstore %n, %c0
      yul.func_return
    }

    yul.func @early_return : (i256) -> i256 {
    ^bb0(%n: i256):
      %c0 = yul.constant 0
      yul.if %n {
        yul.func_return %c0 : i256
      } else {
      }
      yul.func_return %n : i256
    }

    // A break targets the inner loop's exit, a continue after it the outer
    // loop's step.
    yul.func @nested_loops : (i256) -> () {
    ^bb0(%n: i256):
      %c0 = yul.constant 0
      yul.for cond {
        %0 = yul.sload %c0
        yul.condition %0
      } body {
        yul.for cond {
          %0 = yul.sload %n
          yul.condition %0
        } body {
          %0 = yul.tload %n
          yul.if %0 {
            yul.break
          } else {
          }
          yul.sstore %n, %c0
          yul.yield
        } step {
          yul.sstore %c0, %n
          yul.yield
        }
        yul.if %n {
          yul.continue
        } else {
        }
        yul.sstore %c0, %c0
        yul.yield
      } step {
        yul.sstore %n, %n
        yul.yield
      }
      yul.func_return
    }

    // A loop in a do-while's cond is placed with the cond, after the body.
    yul.func @do_while_loop_cond : (i256) -> () {
    ^bb0(%n: i256):
      %c0 = yul.constant 0
      yul.do {
        yul.sstore %c0, %n
        yul.yield
      } while {
        yul.for cond {
          %0 = yul.sload %n
          yul.condition %0
        } body {
          yul.sstore %n, %c0
          yul.yield
        } step {
          yul.yield
        }
        %0 = yul.sload %c0
        yul.condition %0
      }
      yul.func_return
    }
  }
}
