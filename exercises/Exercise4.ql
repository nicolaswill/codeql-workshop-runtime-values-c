/**
 * @name cpp/array-access-out-of-bounds
 * @description Access of an array with an index that is greater or equal to the element num.
 * @kind problem
 */

import cpp
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis
import semmle.code.cpp.dataflow.DataFlow

/**
 * Gets an expression that flows to `dest` and has a constant value.
 */
bindingset[dest]
Expr getSourceConstantExpr(Expr dest) { none() }

/**
 * Gets the smallest of the upper bound of `e` or the largest source value (i.e. "stated value") that flows to `e`.
 * Because range-analysis can over-widen bounds, take the minimum of range analysis and data-flow sources.
 *
 * If there is no source value that flows to `e`, this predicate does not hold.
 *
 * This predicate, if `e` is the `sz` arg to `malloc`, would return `20` for the following:
 * ```
 * size_t sz = condition ? 10 : 20;
 * malloc(sz);
 * ```
 */
bindingset[e]
int getMaxStatedValue(Expr e) { none() }

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

  int getFixedSize() { result = getMaxStatedValue(this.getSizeExpr()) }
}

class AccessExpr extends ArrayExpr {
  AllocationCall source;

  AccessExpr() { DataFlow::localExprFlow(source.getBuffer(), this.getArrayBase()) }

  AllocationCall getSource() { result = source }

  int getFixedArrayOffset() { result = getMaxStatedValue(this.getArrayOffset()) }
}

predicate isOffsetOutOfBoundsConstant(
  AccessExpr access, AllocationCall source, int allocSize, int accessOffset
) {
  source = access.getSource() and
  allocSize = source.getFixedSize() and
  accessOffset = access.getFixedArrayOffset() and
  accessOffset >= allocSize
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
