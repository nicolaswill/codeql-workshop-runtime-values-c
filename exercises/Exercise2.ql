import cpp
import semmle.code.cpp.dataflow.DataFlow

/**
 * Gets an expression that flows to `dest` and has a constant value.
 */
bindingset[dest]
Expr getSourceConstantExpr(Expr dest) { none() }

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

from AllocationCall alloc, AccessExpr access
where access.getSource() = alloc
select access, access.getFixedArrayOffset(), alloc, alloc.getFixedSize()
