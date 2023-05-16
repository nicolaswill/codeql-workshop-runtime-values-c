import cpp

bindingset[expr]
int getExprOffsetValue(Expr expr, Expr base) {
  result = expr.(AddExpr).getRightOperand().getValue().toInt() and
  base = expr.(AddExpr).getLeftOperand()
  or
  result = -expr.(SubExpr).getRightOperand().getValue().toInt() and
  base = expr.(SubExpr).getLeftOperand()
  or
  // currently only AddExpr and SubExpr are supported: else, fall-back to 0
  not expr instanceof AddExpr and
  not expr instanceof SubExpr and
  base = expr and
  result = 0
}
