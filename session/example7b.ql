import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis

from
  AllocationExpr buffer, ArrayExpr access, int bufferSize, Expr bufferSizeExpr,
  int maxAccessedIndex, int allocatedUnits
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  getAllocConstantExpr(bufferSizeExpr, bufferSize) and
  // Ensure buffer access is to the correct allocation.
  DataFlow::localExprFlow(buffer, access.getArrayBase()) and
  // Ensure use refers to the correct size defintion, even for non-constant
  // expressions.  
  DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
  // computeIndices(access, buffer, bufferSize, allocatedUnits, maxAccessedIndex)
  computeAllocationSize(buffer, bufferSize, allocatedUnits) and
  computeMaxAccess(access, maxAccessedIndex)
  // only consider out-of-bounds
  and 
  maxAccessedIndex >= allocatedUnits
select access,
  "Array access at or beyond size; have " + allocatedUnits + " units, access at " + maxAccessedIndex

// select bufferSizeExpr, buffer, access, allocatedUnits, maxAccessedIndex

/**
 * Compute the maximum accessed index.
 */
predicate computeMaxAccess(ArrayExpr access, int maxAccessedIndex) {
  exists(
    int arrayTypeSize, int accessMax, Type arrayBaseType, int arrayBaseTypeSize, Expr accessIdx
  |
    // buf[...]
    // ^^^^^^^^  ArrayExpr access
    //     ^^^
    accessIdx = access.getArrayOffset() and
    upperBound(accessIdx) = accessMax and
    arrayBaseType.getSize() = arrayBaseTypeSize and
    access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType() = arrayBaseType and
    arrayTypeSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() and
    arrayTypeSize * accessMax = maxAccessedIndex
  )
}

/**
 * Compute the allocation size.
 */
bindingset[bufferSize]
predicate computeAllocationSize(AllocationExpr buffer, int bufferSize, int allocatedUnits) {
  exists(int bufferBaseTypeSize, Type arrayBaseType, int arrayBaseTypeSize |
    // buf[...]
    // ^^^^^^^^  ArrayExpr access
    //     ^^^
    buffer.getSizeMult() = bufferBaseTypeSize and
    arrayBaseType.getSize() = arrayBaseTypeSize and
    bufferSize * bufferBaseTypeSize = allocatedUnits
  )
}

/**
 * Compute the allocation size and the maximum accessed index for the allocation and access.
 */
bindingset[bufferSize]
predicate computeIndices(
  ArrayExpr access, AllocationExpr buffer, int bufferSize, int allocatedUnits, int maxAccessedIndex
) {
  exists(
    int arrayTypeSize, int accessMax, int bufferBaseTypeSize, Type arrayBaseType,
    int arrayBaseTypeSize, Expr accessIdx
  |
    // buf[...]
    // ^^^^^^^^  ArrayExpr access
    //     ^^^
    accessIdx = access.getArrayOffset() and
    upperBound(accessIdx) = accessMax and
    buffer.getSizeMult() = bufferBaseTypeSize and
    arrayBaseType.getSize() = arrayBaseTypeSize and
    bufferSize * bufferBaseTypeSize = allocatedUnits and
    access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType() = arrayBaseType and
    arrayTypeSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() and
    arrayTypeSize * accessMax = maxAccessedIndex
  )
}

/**
 * Gets an expression that flows to the allocation (which includes those already in the allocation)
 * and has a constant value.
 */
predicate getAllocConstantExpr(Expr bufferSizeExpr, int bufferSize) {
  exists(AllocationExpr buffer |
    // Capture BOTH with datflow:
    // 1. malloc (100)
    //            ^^^ bufferSize
    // 2. unsigned long size = 100; ... ; char *buf = malloc(size);
    DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
    bufferSizeExpr.getValue().toInt() = bufferSize
  )
}
