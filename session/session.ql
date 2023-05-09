/**
 * @ kind problem
 */

import cpp

// Ex.1
// void test_const(void)
// void test_const_var(void)

from AllocationExpr buffer, ArrayExpr access, int bufferSize, int accessIdx, Expr allocSizeExpr
where 
    // malloc (100)
    // ^^^^^^ in the AllocationExpr buffer

    // buf[...]
    // ^^^  ArrayExpr access

    accessIdx = access.getArrayOffset().getValue().toInt() and
    // malloc (100)
    //         ^^^
    allocSizeExpr.getValue().toInt() = bufferSize 
select buffer, access, accessIdx

// from AllocationExpr buffer, ArrayExpr access, int bufferSize, int accessOffset, int accessIdx, int elementSize, Expr allocSizeExpr
// where 
//     // malloc (100)
//     // ^^^^^^ in the AllocationExpr buffer

//     // buf[...]
//     // ^^^  ArrayExpr access

//     accessIdx = access.getArrayOffset().getValue().toInt() and
//     elementSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() and
//     accessOffset = accessIdx * elementSize and
//     // malloc (100)
//     //         ^^^
//     allocSizeExpr.getValue().toInt() = bufferSize 
// select buffer, access


/*
 * char *buf = malloc(100);
 *    buf[0];   // COMPLIANT
 *    buf[99];  // COMPLIANT
 *    buf[100]; // NON_COMPLIANT
 *
 *    #define FACTOR 2
 *    ...
 *    unsigned long size = 100 * FACTOR;
 *    char *buf = malloc(size);
 *    buf[0];        // COMPLIANT
 *    buf[99];       // COMPLIANT
 *    buf[size - 1]; // COMPLIANT
 *    buf[100];      // NON_COMPLIANT
 *    buf[size];     // NON_COMPLIANT
 */

import semmle.code.cpp.dataflow.DataFlow

class BufferAccess extends ArrayExpr {
    AllocationExpr buffer;
    int bufferSize;
    Expr offsetExpr;
    BufferAccess() {
        exists(Expr allocSizeExpr |
        DataFlow::localExprFlow(buffer, this.getArrayBase()) and
        offsetExpr = this.getArrayOffset() and
        allocSizeExpr.getValue().toInt() = bufferSize and
        DataFlow::localExprFlow(allocSizeExpr, buffer.getSizeExpr()))
    }

    AllocationExpr getBuffer() {
        result = buffer
    }
 
    Expr getAccessExpr() {
        result = offsetExpr
    }

    int getBufferSize() {
        result = bufferSize
    }
}

// predicate bufferAccess(AllocationExpr buffer, ArrayExpr access, int bufferSize, int accessOffset) {
//   exists(int accessIdx, int elementSize, Expr allocSizeExpr |
//     DataFlow::localExprFlow(buffer, access.getArrayBase()) and
//     accessIdx = access.getArrayOffset().getValue().toInt() and
//     elementSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() and
//     accessOffset = accessIdx * elementSize and
//     allocSizeExpr.getValue().toInt() = bufferSize and
//     DataFlow::localExprFlow(allocSizeExpr, buffer.getSizeExpr())
//   )
// }



// from BufferAccess ba,  int accessOffset, int bufferSize
// where upperBound(ba.getAccessExpr()) = accessOffset and
// bufferSize = ba.getBufferSize() and 
// accessOffset >= bufferSize
// select ba, "Possible out of bounds access with offset " + accessOffset + " and size " + bufferSize

// from AllocationExpr alloc, ArrayExpr access, Expr sizeExpr, Expr partOfAccess
// where alloc.getSizeExpr() = sizeExpr and
// (
//     // malloc(sz * x * y);
//     // ...
//     // buf[sz * x * y];
//     access.getArrayOffset() = partOfAccess
//     or
//     // buf[sz * x * y + 1];
//     exists(AddExpr add |
//         access.getArrayOffset() = add and
//         add.getAnOperand() = partOfAccess and
//         add.getAnOperand().getValue().toInt() > 0
//     )
// )
// and
// partOfAccess != sizeExpr and
// globalValueNumber(partOfAccess) = globalValueNumber(sizeExpr)
// select sizeExpr, partOfAccess

// import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis
// import semmle.code.cpp.valuenumbering.GlobalValueNumbering
