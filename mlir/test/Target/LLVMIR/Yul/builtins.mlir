// RUN: mlir-translate --mlir-to-llvmir %s | FileCheck %s

// CHECK-LABEL: define void @__entry(
// CHECK-SAME: ) #{{[0-9]+}} {
// CHECK-NEXT: call void @llvm.evm.stop()
// CHECK-NEXT: unreachable
// CHECK-NEXT: }
// CHECK-LABEL: define private void @binary(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]], i256 %[[V2:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V4:[0-9]+]] = add i256 %[[V0]], %[[V1]]
// CHECK-NEXT: %[[V5:[0-9]+]] = sub i256 %[[V4]], %[[V1]]
// CHECK-NEXT: %[[V6:[0-9]+]] = mul i256 %[[V5]], %[[V1]]
// CHECK-NEXT: %[[V7:[0-9]+]] = and i256 %[[V6]], %[[V1]]
// CHECK-NEXT: %[[V8:[0-9]+]] = or i256 %[[V7]], %[[V1]]
// CHECK-NEXT: %[[V9:[0-9]+]] = xor i256 %[[V8]], %[[V1]]
// CHECK-NEXT: %[[V10:[0-9]+]] = xor i256 %[[V9]], -1
// CHECK-NEXT: %[[V11:[0-9]+]] = shl i256 %[[V10]], %[[V1]]
// CHECK-NEXT: %[[V12:[0-9]+]] = lshr i256 %[[V11]], %[[V1]]
// CHECK-NEXT: %[[V13:[0-9]+]] = ashr i256 %[[V12]], %[[V1]]
// CHECK-NEXT: %[[V14:[0-9]+]] = udiv i256 %[[V13]], %[[V1]]
// CHECK-NEXT: %[[V15:[0-9]+]] = sdiv i256 %[[V14]], %[[V1]]
// CHECK-NEXT: %[[V16:[0-9]+]] = urem i256 %[[V15]], %[[V1]]
// CHECK-NEXT: %[[V17:[0-9]+]] = srem i256 %[[V16]], %[[V1]]
// CHECK-NEXT: %[[V18:[0-9]+]] = icmp ne i256 %[[V2]], 0
// CHECK-NEXT: %[[V19:[0-9]+]] = select i1 %[[V18]], i256 %[[V17]], i256 %[[V0]]
// CHECK-NEXT: %[[V20:[0-9]+]] = icmp slt i256 %[[V19]], %[[V1]]
// CHECK-NEXT: %[[V21:[0-9]+]] = zext i1 %[[V20]] to i256
// CHECK-NEXT: %[[V22:[0-9]+]] = select i1 %[[V20]], i256 %[[V19]], i256 %[[V1]]
// CHECK-NEXT: %[[V23:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(5)
// CHECK-NEXT: store i256 %[[V22]], ptr addrspace(5) %[[V23]], align 1
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @selfdestruct(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: call void @llvm.evm.selfdestruct(i256 %[[V0]])
// CHECK-NEXT: unreachable
// CHECK-NEXT: }
// CHECK-LABEL: define private void @arith(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]], i256 %[[V2:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V4:[0-9]+]] = call i256 @llvm.evm.div(i256 %[[V0]], i256 %[[V1]])
// CHECK-NEXT: %[[V5:[0-9]+]] = call i256 @llvm.evm.sdiv(i256 %[[V0]], i256 %[[V1]])
// CHECK-NEXT: %[[V6:[0-9]+]] = call i256 @llvm.evm.mod(i256 %[[V0]], i256 %[[V1]])
// CHECK-NEXT: %[[V7:[0-9]+]] = call i256 @llvm.evm.smod(i256 %[[V0]], i256 %[[V1]])
// CHECK-NEXT: %[[V8:[0-9]+]] = call i256 @llvm.evm.shl(i256 %[[V0]], i256 %[[V1]])
// CHECK-NEXT: %[[V9:[0-9]+]] = call i256 @llvm.evm.shr(i256 %[[V0]], i256 %[[V1]])
// CHECK-NEXT: %[[V10:[0-9]+]] = call i256 @llvm.evm.sar(i256 %[[V0]], i256 %[[V1]])
// CHECK-NEXT: %[[V11:[0-9]+]] = call i256 @llvm.evm.exp(i256 %[[V0]], i256 %[[V1]])
// CHECK-NEXT: %[[V12:[0-9]+]] = call i256 @llvm.evm.addmod(i256 %[[V0]], i256 %[[V1]], i256 %[[V2]])
// CHECK-NEXT: %[[V13:[0-9]+]] = call i256 @llvm.evm.mulmod(i256 %[[V0]], i256 %[[V1]], i256 %[[V2]])
// CHECK-NEXT: %[[V14:[0-9]+]] = call i256 @llvm.evm.signextend(i256 %[[V0]], i256 %[[V1]])
// CHECK-NEXT: %[[V15:[0-9]+]] = call i256 @llvm.evm.byte(i256 %[[V0]], i256 %[[V1]])
// CHECK-NEXT: %[[V16:[0-9]+]] = call i256 @llvm.ctlz.i256(i256 %[[V0]], i1 false)
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @context(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = call i256 @llvm.evm.address()
// CHECK-NEXT: %[[V3:[0-9]+]] = call i256 @llvm.evm.balance(i256 %[[V0]])
// CHECK-NEXT: %[[V4:[0-9]+]] = call i256 @llvm.evm.selfbalance()
// CHECK-NEXT: %[[V5:[0-9]+]] = call i256 @llvm.evm.caller()
// CHECK-NEXT: %[[V6:[0-9]+]] = call i256 @llvm.evm.gas()
// CHECK-NEXT: %[[V7:[0-9]+]] = call i256 @llvm.evm.chainid()
// CHECK-NEXT: %[[V8:[0-9]+]] = call i256 @llvm.evm.basefee()
// CHECK-NEXT: %[[V9:[0-9]+]] = call i256 @llvm.evm.blobbasefee()
// CHECK-NEXT: %[[V10:[0-9]+]] = call i256 @llvm.evm.origin()
// CHECK-NEXT: %[[V11:[0-9]+]] = call i256 @llvm.evm.gasprice()
// CHECK-NEXT: %[[V12:[0-9]+]] = call i256 @llvm.evm.blockhash(i256 %[[V0]])
// CHECK-NEXT: %[[V13:[0-9]+]] = call i256 @llvm.evm.blobhash(i256 %[[V0]])
// CHECK-NEXT: %[[V14:[0-9]+]] = call i256 @llvm.evm.coinbase()
// CHECK-NEXT: %[[V15:[0-9]+]] = call i256 @llvm.evm.timestamp()
// CHECK-NEXT: %[[V16:[0-9]+]] = call i256 @llvm.evm.number()
// CHECK-NEXT: %[[V17:[0-9]+]] = call i256 @llvm.evm.difficulty()
// CHECK-NEXT: %[[V18:[0-9]+]] = call i256 @llvm.evm.gaslimit()
// CHECK-NEXT: %[[V19:[0-9]+]] = call i256 @llvm.evm.callvalue()
// CHECK-NEXT: %[[V20:[0-9]+]] = call i256 @llvm.evm.calldatasize()
// CHECK-NEXT: %[[V21:[0-9]+]] = call i256 @llvm.evm.returndatasize()
// CHECK-NEXT: %[[V22:[0-9]+]] = call i256 @llvm.evm.codesize()
// CHECK-NEXT: %[[V23:[0-9]+]] = call i256 @llvm.evm.extcodesize(i256 %[[V0]])
// CHECK-NEXT: %[[V24:[0-9]+]] = call i256 @llvm.evm.extcodehash(i256 %[[V0]])
// CHECK-NEXT: %[[V25:[0-9]+]] = call i256 @llvm.evm.msize()
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @memory(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]], i256 %[[V2:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V4:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: %[[V5:[0-9]+]] = load i256, ptr addrspace(1) %[[V4]], align 1
// CHECK-NEXT: %[[V6:[0-9]+]] = inttoptr i256 %[[V1]] to ptr addrspace(1)
// CHECK-NEXT: store i256 %[[V5]], ptr addrspace(1) %[[V6]], align 1
// CHECK-NEXT: %[[V7:[0-9]+]] = inttoptr i256 %[[V1]] to ptr addrspace(1)
// CHECK-NEXT: call void @llvm.evm.mstore8(ptr addrspace(1) %[[V7]], i256 %[[V5]])
// CHECK-NEXT: %[[V8:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: %[[V9:[0-9]+]] = inttoptr i256 %[[V1]] to ptr addrspace(1)
// CHECK-NEXT: call void @llvm.memmove.p1.p1.i256(ptr addrspace(1) %[[V8]], ptr addrspace(1) %[[V9]], i256 %[[V2]], i1 false)
// CHECK-NEXT: %[[V10:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(2)
// CHECK-NEXT: %[[V11:[0-9]+]] = load i256, ptr addrspace(2) %[[V10]], align 1
// CHECK-NEXT: %[[V12:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: %[[V13:[0-9]+]] = inttoptr i256 %[[V1]] to ptr addrspace(2)
// CHECK-NEXT: call void @llvm.memcpy.p1.p2.i256(ptr addrspace(1) %[[V12]], ptr addrspace(2) %[[V13]], i256 %[[V2]], i1 false)
// CHECK-NEXT: %[[V14:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: %[[V15:[0-9]+]] = inttoptr i256 %[[V1]] to ptr addrspace(3)
// CHECK-NEXT: call void @llvm.memcpy.p1.p3.i256(ptr addrspace(1) %[[V14]], ptr addrspace(3) %[[V15]], i256 %[[V2]], i1 false)
// CHECK-NEXT: %[[V16:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: %[[V17:[0-9]+]] = inttoptr i256 %[[V1]] to ptr addrspace(4)
// CHECK-NEXT: call void @llvm.memcpy.p1.p4.i256(ptr addrspace(1) %[[V16]], ptr addrspace(4) %[[V17]], i256 %[[V2]], i1 false)
// CHECK-NEXT: %[[V18:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: %[[V19:[0-9]+]] = inttoptr i256 %[[V1]] to ptr addrspace(4)
// CHECK-NEXT: call void @llvm.evm.extcodecopy(i256 %[[V11]], ptr addrspace(1) %[[V18]], ptr addrspace(4) %[[V19]], i256 %[[V2]])
// CHECK-NEXT: %[[V20:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(5)
// CHECK-NEXT: %[[V21:[0-9]+]] = load i256, ptr addrspace(5) %[[V20]], align 1
// CHECK-NEXT: %[[V22:[0-9]+]] = inttoptr i256 %[[V1]] to ptr addrspace(5)
// CHECK-NEXT: store i256 %[[V21]], ptr addrspace(5) %[[V22]], align 1
// CHECK-NEXT: %[[V23:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(6)
// CHECK-NEXT: %[[V24:[0-9]+]] = load i256, ptr addrspace(6) %[[V23]], align 1
// CHECK-NEXT: %[[V25:[0-9]+]] = inttoptr i256 %[[V1]] to ptr addrspace(6)
// CHECK-NEXT: store i256 %[[V24]], ptr addrspace(6) %[[V25]], align 1
// CHECK-NEXT: %[[V26:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: %[[V27:[0-9]+]] = call i256 @llvm.evm.sha3(ptr addrspace(1) %[[V26]], i256 %[[V2]])
// CHECK-NEXT: %[[V28:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: call void @llvm.evm.log0(ptr addrspace(1) %[[V28]], i256 %[[V2]])
// CHECK-NEXT: %[[V29:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: call void @llvm.evm.log1(ptr addrspace(1) %[[V29]], i256 %[[V2]], i256 %[[V27]])
// CHECK-NEXT: %[[V30:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: call void @llvm.evm.log2(ptr addrspace(1) %[[V30]], i256 %[[V2]], i256 %[[V27]], i256 %[[V27]])
// CHECK-NEXT: %[[V31:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: call void @llvm.evm.log3(ptr addrspace(1) %[[V31]], i256 %[[V2]], i256 %[[V27]], i256 %[[V27]], i256 %[[V27]])
// CHECK-NEXT: %[[V32:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(1)
// CHECK-NEXT: call void @llvm.evm.log4(ptr addrspace(1) %[[V32]], i256 %[[V2]], i256 %[[V27]], i256 %[[V27]], i256 %[[V27]], i256 %[[V27]])
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @calls(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]], i256 %[[V2:[0-9]+]], i256 %[[V3:[0-9]+]], i256 %[[V4:[0-9]+]], i256 %[[V5:[0-9]+]], i256 %[[V6:[0-9]+]], i256 %[[V7:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V9:[0-9]+]] = inttoptr i256 %[[V3]] to ptr addrspace(1)
// CHECK-NEXT: %[[V10:[0-9]+]] = inttoptr i256 %[[V5]] to ptr addrspace(1)
// CHECK-NEXT: %[[V11:[0-9]+]] = call i256 @llvm.evm.call(i256 %[[V0]], i256 %[[V1]], i256 %[[V2]], ptr addrspace(1) %[[V9]], i256 %[[V4]], ptr addrspace(1) %[[V10]], i256 %[[V6]])
// CHECK-NEXT: %[[V12:[0-9]+]] = inttoptr i256 %[[V3]] to ptr addrspace(1)
// CHECK-NEXT: %[[V13:[0-9]+]] = inttoptr i256 %[[V5]] to ptr addrspace(1)
// CHECK-NEXT: %[[V14:[0-9]+]] = call i256 @llvm.evm.callcode(i256 %[[V0]], i256 %[[V1]], i256 %[[V2]], ptr addrspace(1) %[[V12]], i256 %[[V4]], ptr addrspace(1) %[[V13]], i256 %[[V6]])
// CHECK-NEXT: %[[V15:[0-9]+]] = inttoptr i256 %[[V3]] to ptr addrspace(1)
// CHECK-NEXT: %[[V16:[0-9]+]] = inttoptr i256 %[[V5]] to ptr addrspace(1)
// CHECK-NEXT: %[[V17:[0-9]+]] = call i256 @llvm.evm.staticcall(i256 %[[V0]], i256 %[[V1]], ptr addrspace(1) %[[V15]], i256 %[[V4]], ptr addrspace(1) %[[V16]], i256 %[[V6]])
// CHECK-NEXT: %[[V18:[0-9]+]] = inttoptr i256 %[[V3]] to ptr addrspace(1)
// CHECK-NEXT: %[[V19:[0-9]+]] = inttoptr i256 %[[V5]] to ptr addrspace(1)
// CHECK-NEXT: %[[V20:[0-9]+]] = call i256 @llvm.evm.delegatecall(i256 %[[V0]], i256 %[[V1]], ptr addrspace(1) %[[V18]], i256 %[[V4]], ptr addrspace(1) %[[V19]], i256 %[[V6]])
// CHECK-NEXT: %[[V21:[0-9]+]] = inttoptr i256 %[[V3]] to ptr addrspace(1)
// CHECK-NEXT: %[[V22:[0-9]+]] = call i256 @llvm.evm.create(i256 %[[V2]], ptr addrspace(1) %[[V21]], i256 %[[V4]])
// CHECK-NEXT: %[[V23:[0-9]+]] = inttoptr i256 %[[V3]] to ptr addrspace(1)
// CHECK-NEXT: %[[V24:[0-9]+]] = call i256 @llvm.evm.create2(i256 %[[V2]], ptr addrspace(1) %[[V23]], i256 %[[V4]], i256 %[[V7]])
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private void @data(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V3:[0-9]+]] = call i256 @llvm.evm.dataoffset(metadata !1)
// CHECK-NEXT: %[[V4:[0-9]+]] = call i256 @llvm.evm.datasize(metadata !1)
// CHECK-NEXT: %[[V5:[0-9]+]] = call i256 @llvm.evm.loadimmutable(metadata !2)
// CHECK-NEXT: %[[V6:[0-9]+]] = call i256 @llvm.evm.linkersymbol(metadata !3)
// CHECK-NEXT: call void @llvm.evm.setimmutable(i256 %[[V0]], i256 %[[V1]], metadata !2)
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private i256 @stack(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = alloca i256, i256 1, align 32
// CHECK-NEXT: store i256 %[[V0]], ptr %[[V2]], align 32
// CHECK-NEXT: %[[V3:[0-9]+]] = load i256, ptr %[[V2]], align 32
// CHECK-NEXT: ret i256 %[[V3]]
// CHECK-NEXT: }
// CHECK: declare void @llvm.evm.stop()
// CHECK: declare void @llvm.evm.selfdestruct(i256)
// CHECK: declare i256 @llvm.evm.div(i256, i256)
// CHECK: declare i256 @llvm.evm.sdiv(i256, i256)
// CHECK: declare i256 @llvm.evm.mod(i256, i256)
// CHECK: declare i256 @llvm.evm.smod(i256, i256)
// CHECK: declare i256 @llvm.evm.shl(i256, i256)
// CHECK: declare i256 @llvm.evm.shr(i256, i256)
// CHECK: declare i256 @llvm.evm.sar(i256, i256)
// CHECK: declare i256 @llvm.evm.exp(i256, i256)
// CHECK: declare i256 @llvm.evm.addmod(i256, i256, i256)
// CHECK: declare i256 @llvm.evm.mulmod(i256, i256, i256)
// CHECK: declare i256 @llvm.evm.signextend(i256, i256)
// CHECK: declare i256 @llvm.evm.byte(i256, i256)
// CHECK: declare i256 @llvm.ctlz.i256(i256, i1 immarg)
// CHECK: declare i256 @llvm.evm.address()
// CHECK: declare i256 @llvm.evm.balance(i256)
// CHECK: declare i256 @llvm.evm.selfbalance()
// CHECK: declare i256 @llvm.evm.caller()
// CHECK: declare i256 @llvm.evm.gas()
// CHECK: declare i256 @llvm.evm.chainid()
// CHECK: declare i256 @llvm.evm.basefee()
// CHECK: declare i256 @llvm.evm.blobbasefee()
// CHECK: declare i256 @llvm.evm.origin()
// CHECK: declare i256 @llvm.evm.gasprice()
// CHECK: declare i256 @llvm.evm.blockhash(i256)
// CHECK: declare i256 @llvm.evm.blobhash(i256)
// CHECK: declare i256 @llvm.evm.coinbase()
// CHECK: declare i256 @llvm.evm.timestamp()
// CHECK: declare i256 @llvm.evm.number()
// CHECK: declare i256 @llvm.evm.difficulty()
// CHECK: declare i256 @llvm.evm.gaslimit()
// CHECK: declare i256 @llvm.evm.callvalue()
// CHECK: declare i256 @llvm.evm.calldatasize()
// CHECK: declare i256 @llvm.evm.returndatasize()
// CHECK: declare i256 @llvm.evm.codesize()
// CHECK: declare i256 @llvm.evm.extcodesize(i256)
// CHECK: declare i256 @llvm.evm.extcodehash(i256)
// CHECK: declare i256 @llvm.evm.msize()
// CHECK: declare void @llvm.evm.mstore8(ptr addrspace(1) captures(none), i256)
// CHECK: declare void @llvm.memmove.p1.p1.i256(ptr addrspace(1) writeonly captures(none), ptr addrspace(1) readonly captures(none), i256, i1 immarg)
// CHECK: declare void @llvm.memcpy.p1.p2.i256(ptr addrspace(1) noalias writeonly captures(none), ptr addrspace(2) noalias readonly captures(none), i256, i1 immarg)
// CHECK: declare void @llvm.memcpy.p1.p3.i256(ptr addrspace(1) noalias writeonly captures(none), ptr addrspace(3) noalias readonly captures(none), i256, i1 immarg)
// CHECK: declare void @llvm.memcpy.p1.p4.i256(ptr addrspace(1) noalias writeonly captures(none), ptr addrspace(4) noalias readonly captures(none), i256, i1 immarg)
// CHECK: declare void @llvm.evm.extcodecopy(i256, ptr addrspace(1) writeonly captures(none), ptr addrspace(4) readonly captures(none), i256)
// CHECK: declare i256 @llvm.evm.sha3(ptr addrspace(1) captures(none), i256)
// CHECK: declare void @llvm.evm.log0(ptr addrspace(1) readonly captures(none), i256)
// CHECK: declare void @llvm.evm.log1(ptr addrspace(1) readonly captures(none), i256, i256)
// CHECK: declare void @llvm.evm.log2(ptr addrspace(1) readonly captures(none), i256, i256, i256)
// CHECK: declare void @llvm.evm.log3(ptr addrspace(1) readonly captures(none), i256, i256, i256, i256)
// CHECK: declare void @llvm.evm.log4(ptr addrspace(1) readonly captures(none), i256, i256, i256, i256, i256)
// CHECK: declare i256 @llvm.evm.call(i256, i256, i256, ptr addrspace(1) readonly captures(none), i256, ptr addrspace(1) writeonly captures(none), i256)
// CHECK: declare i256 @llvm.evm.callcode(i256, i256, i256, ptr addrspace(1) readonly captures(none), i256, ptr addrspace(1) writeonly captures(none), i256)
// CHECK: declare i256 @llvm.evm.staticcall(i256, i256, ptr addrspace(1) readonly captures(none), i256, ptr addrspace(1) writeonly captures(none), i256)
// CHECK: declare i256 @llvm.evm.delegatecall(i256, i256, ptr addrspace(1) readonly captures(none), i256, ptr addrspace(1) writeonly captures(none), i256)
// CHECK: declare i256 @llvm.evm.create(i256, ptr addrspace(1) readonly captures(none), i256)
// CHECK: declare i256 @llvm.evm.create2(i256, ptr addrspace(1) readonly captures(none), i256, i256)
// CHECK: declare i256 @llvm.evm.dataoffset(metadata)
// CHECK: declare i256 @llvm.evm.datasize(metadata)
// CHECK: declare i256 @llvm.evm.loadimmutable(metadata)
// CHECK: declare i256 @llvm.evm.linkersymbol(metadata)
// CHECK: declare void @llvm.evm.setimmutable(i256, i256, metadata)
// CHECK: !llvm.module.flags = !{!0}
// CHECK: !0 = !{i32 2, !"Debug Info Version", i32 3}
// CHECK: !1 = !{!"Test_deployed"}
// CHECK: !2 = !{!"imm"}
// CHECK: !3 = !{!"lib.sol:L"}

module {
  yul.object @Test {
    yul.func @__entry : () -> () {
      yul.stop
    }

    // A comparison feeding a select is selected on directly.
    yul.func @binary : (i256, i256, i256) -> () {
    ^bb0(%a: i256, %b: i256, %c: i256):
      %0 = yul.add %a, %b
      %1 = yul.sub %0, %b
      %2 = yul.mul %1, %b
      %3 = yul.and %2, %b
      %4 = yul.or %3, %b
      %5 = yul.xor %4, %b
      %6 = yul.not %5
      %7 = yul.arith_shl %6, %b
      %8 = yul.arith_shr %7, %b
      %9 = yul.arith_sar %8, %b
      %10 = yul.arith_div %9, %b
      %11 = yul.arith_sdiv %10, %b
      %12 = yul.arith_mod %11, %b
      %13 = yul.arith_smod %12, %b
      %14 = yul.arith_select %c, %13, %a
      %15 = yul.cmp slt, %14, %b
      %16 = yul.arith_select %15, %14, %b
      yul.sstore %a, %16
      yul.func_return
    }

    yul.func @selfdestruct : (i256) -> () {
    ^bb0(%a: i256):
      yul.selfdestruct %a
    }

    yul.func @arith : (i256, i256, i256) -> () {
    ^bb0(%a: i256, %b: i256, %m: i256):
      %0 = yul.div %a, %b
      %1 = yul.sdiv %a, %b
      %2 = yul.mod %a, %b
      %3 = yul.smod %a, %b
      %4 = yul.shl %a, %b
      %5 = yul.shr %a, %b
      %6 = yul.sar %a, %b
      %7 = yul.exp %a, %b
      %8 = yul.addmod %a, %b, %m
      %9 = yul.mulmod %a, %b, %m
      %10 = yul.signextend %a, %b
      %11 = yul.byte %a, %b
      %12 = yul.clz %a
      yul.func_return
    }

    yul.func @context : (i256) -> () {
    ^bb0(%a: i256):
      %0 = yul.address
      %1 = yul.balance %a
      %2 = yul.selfbalance
      %3 = yul.caller
      %4 = yul.gas
      %5 = yul.chainid
      %6 = yul.basefee
      %7 = yul.blobbasefee
      %8 = yul.origin
      %9 = yul.gasprice
      %10 = yul.blockhash %a
      %11 = yul.blobhash %a
      %12 = yul.coinbase
      %13 = yul.timestamp
      %14 = yul.number
      %15 = yul.prevrandao
      %16 = yul.gaslimit
      %17 = yul.callvalue
      %18 = yul.calldatasize
      %19 = yul.returndatasize
      %20 = yul.codesize
      %21 = yul.extcodesize %a
      %22 = yul.extcodehash %a
      %23 = yul.msize
      yul.func_return
    }

    yul.func @memory : (i256, i256, i256) -> () {
    ^bb0(%p: i256, %q: i256, %n: i256):
      %0 = yul.mload %p
      yul.mstore %q, %0
      yul.mstore8 %q, %0
      yul.mcopy %p, %q, %n
      %1 = yul.calldataload %p
      yul.calldatacopy %p, %q, %n
      yul.returndatacopy %p, %q, %n
      yul.codecopy %p, %q, %n
      yul.extcodecopy %1, %p, %q, %n
      %2 = yul.sload %p
      yul.sstore %q, %2
      %3 = yul.tload %p
      yul.tstore %q, %3
      %4 = yul.keccak256 %p, %n
      yul.log %p, %n
      yul.log %p, %n topics(%4)
      yul.log %p, %n topics(%4, %4)
      yul.log %p, %n topics(%4, %4, %4)
      yul.log %p, %n topics(%4, %4, %4, %4)
      yul.func_return
    }

    // Every argument is a distinct value, so the operand order is pinned.
    yul.func @calls : (i256, i256, i256, i256, i256, i256, i256, i256) -> () {
    ^bb0(%gas: i256, %addr: i256, %val: i256, %in: i256, %inSize: i256,
         %out: i256, %outSize: i256, %salt: i256):
      %0 = yul.call %gas, %addr, %val, %in, %inSize, %out, %outSize
      %1 = yul.callcode %gas, %addr, %val, %in, %inSize, %out, %outSize
      %2 = yul.static_call %gas, %addr, %in, %inSize, %out, %outSize
      %3 = yul.delegate_call %gas, %addr, %in, %inSize, %out, %outSize
      %4 = yul.create %val, %in, %inSize
      %5 = yul.create2 %val, %in, %inSize, %salt
      yul.func_return
    }

    yul.func @data : (i256, i256) -> () {
    ^bb0(%p: i256, %v: i256):
      %0 = yul.dataoffset {obj = @Test_deployed}
      %1 = yul.datasize {obj = @Test_deployed}
      %2 = yul.loadimmutable "imm"
      %3 = yul.linkersymbol "lib.sol:L"
      yul.setimmutable %p, "imm", %v
      yul.func_return
    }

    yul.func @stack : (i256) -> i256 {
    ^bb0(%v: i256):
      %0 = yul.alloca : !yul.ptr
      yul.store %v, %0 : i256, !yul.ptr
      %1 = yul.load %0 : !yul.ptr -> i256
      yul.func_return %1 : i256
    }
  }
}
