import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis

from
  AllocationExpr buffer, ArrayExpr access, Expr accessIdx, int bufferSize, Expr bufferSizeExpr,
  int arrayTypeSize, int allocBaseSize
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  // buf[...]
  // ^^^^^^^^  ArrayExpr access
  //     ^^^  int accessIdx
  accessIdx = access.getArrayOffset() and
  getAllocConstantExpr(bufferSizeExpr, bufferSize) and
  // Ensure alloc and buffer access are in the same function
  ensureSameFunction(buffer, access.getArrayBase()) and
  // Ensure size defintion and use are in same function, even for non-constant expressions.
  ensureSameFunction(bufferSizeExpr, buffer.getSizeExpr()) and
  //
  arrayTypeSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() and
  1 = allocBaseSize
//
select bufferSizeExpr, buffer, access, accessIdx, upperBound(accessIdx) as accessMax, bufferSize,
  access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType() as arrayBaseType,
  buffer.getSizeMult() as bufferBaseTypeSize,
  arrayBaseType.getSize() as arrayBaseTypeSize,
  allocBaseSize * bufferSize as allocatedUnits, arrayTypeSize * accessMax as maxAccessedIndex

/** Ensure the two expressions are in the same function body. */
predicate ensureSameFunction(Expr a, Expr b) { DataFlow::localExprFlow(a, b) }

/**
 * Gets an expression that flows to the allocation (which includes those already in the allocation)
 * and has a constant value.
 */
predicate getAllocConstantExpr(Expr bufferSizeExpr, int bufferSize) {
  exists(AllocationExpr buffer |
    // Capture BOTH with datflow:
    // 1.
    // malloc (100)
    //         ^^^ bufferSize
    // 2.
    // unsigned long size = 100; ... ; char *buf = malloc(size);
    DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
    bufferSizeExpr.getValue().toInt() = bufferSize
  )
}
