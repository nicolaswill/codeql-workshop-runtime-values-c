import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.valuenumbering.GlobalValueNumbering

from
  AllocationExpr buffer, ArrayExpr access,
  // ---
  // Expr bufferSizeExpr
  // int accessOffset, Expr accessBase, Expr bufferBase, int bufferOffset, Variable bufInit,
  // +++
  Expr allocSizeExpr, Expr accessIdx, GVN gvnAccessIdx, GVN gvnAllocSizeExpr, int accessOffset
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  // buf[...]
  // ^^^  ArrayExpr access
  // buf[...]
  //     ^^^ accessIdx
  accessIdx = access.getArrayOffset() and
  // Find allocation size expression flowing to the allocation.
  DataFlow::localExprFlow(allocSizeExpr, buffer.getSizeExpr()) and
  // Ensure buffer access refers to the matching allocation
  DataFlow::localExprFlow(buffer, access.getArrayBase()) and
  // Use GVN
  globalValueNumber(accessIdx) = gvnAccessIdx and
  globalValueNumber(allocSizeExpr) = gvnAllocSizeExpr and
  (
    // buf[size] or buf[100]
    gvnAccessIdx = gvnAllocSizeExpr and
    accessOffset = 0
    or
    // buf[sz * x * y + 1];
    exists(AddExpr add |
      accessIdx = add and
      accessOffset >= 0 and
      accessOffset = add.getRightOperand().(Literal).getValue().toInt() and
      globalValueNumber(add.getLeftOperand()) = gvnAllocSizeExpr
    )
  )
select access, gvnAllocSizeExpr, allocSizeExpr, buffer.getSizeExpr() as allocArg, gvnAccessIdx,
  accessIdx, accessOffset
