/**
 * @name cpp/array-access-out-of-bounds
 * @description Access of an array with an index that is greater or equal to the element num.
 * @kind problem
 */

import cpp
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis
import semmle.code.cpp.dataflow.DataFlow

class AllocationCall extends FunctionCall {
  AllocationCall() { this.getTarget() instanceof AllocationFunction }

  Expr getBuffer() { result = this }

  Expr getSizeExpr() {
    // AllocationExpr may sometimes return a subexpression of the size expression
    // in order to separate the size from a sizeof expression in a MulExpr.
    exists(AllocationFunction f |
      f = this.(FunctionCall).getTarget() and
      result = this.(FunctionCall).getArgument(f.getSizeArg())
    )
  }

  int getFixedSize() { none() }
}

class AccessExpr extends ArrayExpr {
  AllocationCall source;

  AccessExpr() { DataFlow::localExprFlow(source.getBuffer(), this.getArrayBase()) }

  AllocationCall getSource() { result = source }

  int getFixedArrayOffset() { none() }
}

predicate isOffsetOutOfBoundsConstant(
  AccessExpr access, AllocationCall source, int allocSize, int accessOffset
) {
  none()
}

from AllocationCall source, AccessExpr access, string message
where
  exists(int allocSize, int accessOffset |
    isOffsetOutOfBoundsConstant(access, source, allocSize, accessOffset) and
    message =
      "Array access out of bounds: " + access.toString() + " with offset " + accessOffset.toString()
        + " on $@ with size " + allocSize.toString()
  )
select access, message, source, "allocation"
