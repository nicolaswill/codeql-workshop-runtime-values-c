/**
 * @id cpp/array-access-out-of-bounds
 * @description Access of an array with an index that is greater or equal to the element num.
 * @kind problem
 * @problem.severity error
 */

import cpp
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.valuenumbering.GlobalValueNumbering
import RuntimeValues

/**
 * Gets an expression that flows to `dest` and has a constant value.
 */
bindingset[dest]
Expr getSourceConstantExpr(Expr dest) {
  exists(result.getValue().toInt()) and
  DataFlow::localExprFlow(result, dest)
}

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
int getMaxStatedValue(Expr e) {
  result = upperBound(e).minimum(max(getSourceConstantExpr(e).getValue().toInt()))
}

predicate allocatedBufferArrayAccess(ArrayExpr access, FunctionCall alloc) {
  alloc.getTarget().hasName("malloc") and
  DataFlow::localExprFlow(alloc, access.getArrayBase())
}

int getFixedArrayOffset(ArrayExpr access) {
  exists(Expr base, int offset |
    offset = getExprOffsetValue(access.getArrayOffset(), base) and
    result = getMaxStatedValue(base) + offset
  )
}

predicate isOffsetOutOfBoundsConstant(
  ArrayExpr access, FunctionCall source, int allocSize, int accessOffset
) {
  allocatedBufferArrayAccess(access, source) and
  allocSize = getMaxStatedValue(source.getArgument(0)) and
  accessOffset = getFixedArrayOffset(access) and
  accessOffset >= allocSize
}

predicate isOffsetOutOfBoundsGVN(ArrayExpr access, FunctionCall source) {
  allocatedBufferArrayAccess(access, source) and
  not isOffsetOutOfBoundsConstant(access, source, _, _) and
  exists(Expr accessOffsetBase, int accessOffsetBaseValue |
    accessOffsetBaseValue = getExprOffsetValue(access.getArrayOffset(), accessOffsetBase) and
    globalValueNumber(source.getArgument(0)) = globalValueNumber(accessOffsetBase) and
    not accessOffsetBaseValue < 0
  )
}

from FunctionCall source, ArrayExpr access, string message
where
  exists(int allocSize, int accessOffset |
    isOffsetOutOfBoundsConstant(access, source, allocSize, accessOffset) and
    message =
      "Array access out of bounds: " + access.toString() + " with offset " + accessOffset.toString()
        + " on $@ with size " + allocSize.toString()
  )
  or
  isOffsetOutOfBoundsGVN(access, source) and
  message = "Array access with index that is greater or equal to the size of the $@."
select access, message, source, "allocation"
