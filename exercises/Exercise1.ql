import cpp
import semmle.code.cpp.dataflow.DataFlow

from FunctionCall alloc, ArrayExpr access, int allocSize, int accessOffset
where none()
select access, accessOffset, alloc, allocSize
