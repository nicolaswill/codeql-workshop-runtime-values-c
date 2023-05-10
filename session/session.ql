/**
 * @ kind problem
 */

import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis
import semmle.code.cpp.valuenumbering.GlobalValueNumbering

// Step 9
from
  AllocationExpr buffer, ArrayExpr access, Expr accessIdx, Expr allocSizeExpr, GVN gvnAccess,
  GVN gvnAlloc
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  // buf[...]
  //     ^^^ accessIdx
  accessIdx = access.getArrayOffset() and
  //
  // malloc (100)
  //         ^^^ allocSizeExpr / bufferSize
  // unsigned long size = 100;
  // ...
  // char *buf = malloc(size);
  DataFlow::localExprFlow(allocSizeExpr, buffer.getSizeExpr()) and
  // char *buf  = ... buf[0];
  //       ^^^  --->  ^^^
  // or
  // malloc(100);   buf[0]
  // ^^^  --------> ^^^
  //
  DataFlow::localExprFlow(buffer, access.getArrayBase()) and
  //
  // Use GVN
  globalValueNumber(accessIdx) = gvnAccess and
  globalValueNumber(allocSizeExpr) = gvnAlloc and
  (
    gvnAccess = gvnAlloc
    or
    // buf[sz * x * y] above
    // buf[sz * x * y + 1];
    exists(AddExpr add |
      accessIdx = add and
      // add.getAnOperand() = accessIdx and
      add.getAnOperand().getValue().toInt() > 0 and
      globalValueNumber(add.getAnOperand()) = gvnAlloc
    )
  )
select access, gvnAccess, gvnAlloc
