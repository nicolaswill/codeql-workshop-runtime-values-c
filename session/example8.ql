/**
 * @kind problem
 */

import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis

// Step 8
from
  AllocationExpr buffer, ArrayExpr access, Expr accessIdx, Expr allocSizeExpr, int bufferSize,
  int allocsize, Expr bufferSizeExpr, int arrayTypeSize, int allocBaseSize, int accessMax,
  int allocatedUnits, int maxAccessedIndex
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  // buf[...]
  //     ^^^  int accessIdx
  accessIdx = access.getArrayOffset() and
  //
  // malloc (100)
  //         ^^^ allocSizeExpr / bufferSize
  //
  // Not really:
  //   allocSizeExpr = buffer.(Call).getArgument(0) and
  //
  DataFlow::localExprFlow(allocSizeExpr, buffer.(Call).getArgument(0)) and
  allocsize = allocSizeExpr.getValue().toInt() and
  //
  // unsigned long size = 100;
  // ...
  // char *buf = malloc(size);
  DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
  bufferSizeExpr.getValue().toInt() = bufferSize and
  // char *buf  = ... buf[0];
  //       ^^^  --->  ^^^
  // or
  // malloc(100);   buf[0]
  // ^^^  --------> ^^^
  //
  arrayTypeSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() and
  1 = allocBaseSize and
  DataFlow::localExprFlow(buffer, access.getArrayBase()) and
  upperBound(accessIdx) = accessMax and
  allocBaseSize * allocsize = allocatedUnits and
  arrayTypeSize * accessMax =  maxAccessedIndex and
  // only consider out-of-bounds
  maxAccessedIndex >= allocatedUnits
select access, "Array access at or beyond size; have "+allocatedUnits + " units, access at "+ maxAccessedIndex
