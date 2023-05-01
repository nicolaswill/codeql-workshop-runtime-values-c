import cpp
import semmle.code.cpp.dataflow.DataFlow

from FunctionCall alloc, ArrayExpr access, int allocSize, int accessOffset
where
  alloc.getTarget() instanceof AllocationFunction and
  DataFlow::localExprFlow(alloc, access.getArrayBase()) and
  allocSize = alloc.getArgument(0).getValue().toInt() and
  accessOffset = access.getArrayOffset().getValue().toInt()
select access, accessOffset, alloc, allocSize
