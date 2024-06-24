import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.valuenumbering.GlobalValueNumbering
import semmle.code.cpp.valuenumbering.HashCons

from
  AllocationExpr buffer, ArrayExpr access, Expr allocSizeExpr, Expr accessIdx, GVN gvnAccessIdx,
  GVN gvnAllocSizeExpr, int accessOffset,
  // +++
  Expr allocArg, Expr accessBase
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
    accessOffset = 0 and
    // +++
    accessBase = accessIdx
    or
    // buf[sz * x * y + 1];
    exists(AddExpr add |
      accessIdx = add and
      accessOffset >= 0 and
      accessOffset = add.getRightOperand().(Literal).getValue().toInt() and
      globalValueNumber(add.getLeftOperand()) = gvnAllocSizeExpr and
      // +++
      accessBase = add.getLeftOperand()
    )
  ) and
  buffer.getSizeExpr() = allocArg and
  (
    accessOffset >= 0 and
    // +++
    // Illustrating the subtle meanings of equality:    
    // 0 results:
    // (accessBase = allocSizeExpr or accessBase = allocArg)
    // Only 6 results:
    // (
    //   gvnAccessIdx = gvnAllocSizeExpr or
    //   gvnAccessIdx = globalValueNumber(allocArg)
    // )
    // 9 results:
    (
      hashCons(accessBase) = hashCons(allocSizeExpr) or
      hashCons(accessBase) = hashCons(allocArg)
    )
  )
// gvnAccessIdx = globalValueNumber(allocArg))
// +++ overview select:
select access, gvnAllocSizeExpr, allocSizeExpr, allocArg, gvnAccessIdx, accessIdx, accessBase,
  accessOffset
