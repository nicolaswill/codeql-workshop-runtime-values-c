import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis

from
  AllocationExpr buffer, ArrayExpr access, Expr bufferSizeExpr,
  // ---
  // int maxAccessedIndex, int allocatedUnits,
  // int bufferSize
  int accessOffset, Expr accessBase, Expr bufferBase, int bufferOffset, Variable bufInit,
  Variable accessInit
where
  // malloc (...)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  // ---
  // getAllocConstExpr(...)
  // +++
  bufferSizeExpr = buffer.getSizeExpr() and
  // Ensure buffer access refers to the matching allocation
  DataFlow::localExprFlow(buffer, access.getArrayBase()) and
  // Ensure buffer access refers to the matching allocation
  DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
  //
  // +++
  // base+offset
  extractBaseAndOffset(bufferSizeExpr, bufferBase, bufferOffset) and
  extractBaseAndOffset(access.getArrayOffset(), accessBase, accessOffset) and
  // +++
  // Same initializer variable
  bufferBase.(VariableAccess).getTarget() = bufInit and
  accessBase.(VariableAccess).getTarget() = accessInit and
  bufInit = accessInit
// +++
// Identify questionable differences
select buffer, bufferBase, bufferOffset, access, accessBase, accessOffset, bufInit, accessInit

/**
 * Extract base and offset from y = base+offset and y = base-offset.  For others, get y and 0.
 *
 * For cases like
 *     buf[alloc_size + 1];
 *
 * The more general
 *     buf[sz * x * y - 1];
 * requires other tools.
 */
bindingset[expr]
predicate extractBaseAndOffset(Expr expr, Expr base, int offset) {
  offset = expr.(AddExpr).getRightOperand().getValue().toInt() and
  base = expr.(AddExpr).getLeftOperand()
  or
  offset = -expr.(SubExpr).getRightOperand().getValue().toInt() and
  base = expr.(SubExpr).getLeftOperand()
  or
  not expr instanceof AddExpr and
  not expr instanceof SubExpr and
  base = expr and
  offset = 0
}
