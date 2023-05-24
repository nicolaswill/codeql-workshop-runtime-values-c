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
  // Ensure buffer access refers to the matching allocation
  // ensureSameFunction(buffer, access.getArrayBase()) and
  DataFlow::localExprFlow(buffer, access.getArrayBase()) and
  // Ensure buffer access refers to the matching allocation
  // ensureSameFunction(bufferSizeExpr, buffer.getSizeExpr()) and
  DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) 
  //
select buffer, access, accessIdx, access.getArrayOffset(), bufferSize, bufferSizeExpr

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
