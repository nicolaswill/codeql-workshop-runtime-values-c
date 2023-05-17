import cpp
import semmle.code.cpp.dataflow.DataFlow

from AllocationExpr buffer, ArrayExpr access, int accessIdx, int bufferSize, Expr bufferSizeExpr
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  //
  // buf[...]
  //     ^^^  int accessIdx
  //
  accessIdx = access.getArrayOffset().getValue().toInt() and
  getAllocConstantExpr(bufferSizeExpr, bufferSize) and
  // Ensure alloc and buffer access are in the same function
  ensureSameFunction(buffer, access.getArrayBase()) and
  // Ensure size defintion and use are in same function, even for non-constant expressions.
  ensureSameFunction(bufferSizeExpr, buffer.getSizeExpr())
//
select buffer, access, accessIdx, access.getArrayOffset(), bufferSize, bufferSizeExpr

/** Ensure the two expressions are in the same function body. */
predicate ensureSameFunction(Expr a, Expr b) { DataFlow::localExprFlow(a, b) }

/**
 * Gets an expression that flows to the allocation (which includes those already in the allocation)
 * and has a constant value.
 */
predicate getAllocConstantExpr(Expr bufferSizeExpr, int bufferSize) {
  exists(AllocationExpr buffer |
    //
    // Capture BOTH with datflow:
    // 1.
    // malloc (100)
    //         ^^^ allocSizeExpr / bufferSize
    //
    // 2.
    // unsigned long size = 100;
    // ...
    // char *buf = malloc(size);
    DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
    bufferSizeExpr.getValue().toInt() = bufferSize
  )
}
