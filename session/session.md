- [CodeQL Workshop &#x2014; Using Data-Flow and Range Analysis to Find Out-Of-Bounds Accesses](#codeql-workshop--using-data-flow-and-range-analysis-to-find-out-of-bounds-accesses)
- [Acknowledgments](#acknowledgments)
- [Setup Instructions](#setup-instructions)
- [Introduction](#introduction)
- [A Note on the Scope of This Workshop](#a-note-on-the-scope-of-this-workshop)
- [Session/Workshop notes](#sessionworkshop-notes)
  - [Step 1](#exercise-1)
    - [Hints](#hints)
    - [Solution](#org2fc84f1)
  - [Step 2](#org81cc6bb)
    - [Hints](#hints)
    - [Solution](#orgd82dd3e)
    - [Results](#orgb9c5185)
  - [Step 3](#exercise-2)
    - [Solution](#orgbfcc6e8)
    - [Results](#org77d93e8)
  - [Step 4](#orgcac2df5)
    - [Hint](#orge73d8c3)
    - [Solution](#orgcce7aa5)
    - [Results](#org58fd83d)
  - [Step 4a &#x2013; some clean-up using predicates](#org1a3052f)
    - [Solution](#orgf922609)
  - [Step 5 &#x2013; SimpleRangeAnalysis](#org0df2f23)
    - [Solution](#orgb23c26e)
    - [First 5 results](#org921d64a)
  - [Step 6](#org2b0d3ac)
    - [Solution](#orgdd0881f)
    - [First 5 results](#org3e7d47c)
  - [Step 7](#org00edfe5)
    - [Solution:](#org8a3a4b1)
    - [First 5 results](#org2f15e3e)
  - [Step 7a](#orgfa97dcd)
    - [Solution:](#org3894df3)
    - [First 5 results](#orgcbdf216)
  - [Step 7b](#org58aba89)
    - [incoporate](#orgd60c31b)
    - [incoporate](#org3319200)
  - [Step 8](#orgcfcb55c)
    - [Solution:](#orgede6c66)
    - [Results](#orgfa54b95)
  - [Interim notes](#org68d8dfb)
  - [Step 9 &#x2013; Global Value Numbering](#orge1acc6c)
    - [incorporate](#orgb19cfc3)
    - [incorporate](#orgda109c3)
    - [incoporate](#org8d0c13d)
    - [incoporate](#org45411bb)
    - [incoporate](#org364861b)
    - [interim](#orgc0ae12b)
    - [interim](#orgb2f39ee)
  - [hashconsing](#org6332f3e)


<a id="codeql-workshop--using-data-flow-and-range-analysis-to-find-out-of-bounds-accesses"></a>

# CodeQL Workshop &#x2014; Using Data-Flow and Range Analysis to Find Out-Of-Bounds Accesses


<a id="acknowledgments"></a>

# Acknowledgments

This session-based workshop is based on the exercise/unit-test-based material at <https://github.com/kraiouchkine/codeql-workshop-runtime-values-c>, which in turn is based on a significantly simplified and modified version of the [OutOfBounds.qll library](https://github.com/github/codeql-coding-standards/blob/main/c/common/src/codingstandards/c/OutOfBounds.qll) from the [CodeQL Coding Standards repository](https://github.com/github/codeql-coding-standards).


<a id="setup-instructions"></a>

# Setup Instructions

-   Install [Visual Studio Code](https://code.visualstudio.com/).

-   Install the [CodeQL extension for Visual Studio Code](https://codeql.github.com/docs/codeql-for-visual-studio-code/setting-up-codeql-in-visual-studio-code/).

-   Install the latest version of the [CodeQL CLI](https://github.com/github/codeql-cli-binaries/releases).

-   Clone this repository:
    
    ```sh
    git clone https://github.com/hohn/codeql-workshop-runtime-values-c
    ```

-   Install the CodeQL pack dependencies using the command `CodeQL: Install Pack Dependencies` and select `exercises`, `solutions`, `exercises-tests`, `session`, `session-db` and `solutions-tests` from the list of packs.

-   If you have CodeQL on your PATH, build the database using `build-database.sh` and load the database with the VS Code CodeQL extension. It is at `session-db/cpp-runtime-values-db`.
    -   Alternatively, you can download [this pre-built database](https://drive.google.com/file/d/1N8TYJ6f4E33e6wuyorWHZHVCHBZy8Bhb/view?usp=sharing).

-   If you do **not** have CodeQL on your PATH, build the database using the unit test sytem. Choose the `TESTING` tab in VS Code, run the `session-db/DB/db.qlref` test. The test will fail, but it leaves a usable CodeQL database in `session-db/DB/DB.testproj`.

-   ❗Important❗: Run `initialize-qltests.sh` to initialize the tests. Otherwise, you will not be able to run the QLTests in `exercises-tests`.


<a id="introduction"></a>

# Introduction

This workshop focuses on analyzing and relating two values &#x2014; array access indices and memory allocation sizes &#x2014; in order to identify simple cases of out-of-bounds array accesses.

The following snippets demonstrate how an out-of-bounds array access can occur:

```cpp
char* buffer = malloc(10);
buffer[9] = 'a'; // ok
buffer[10] = 'b'; // out-of-bounds
```

A more complex example:

```cpp
char* buffer;
if(rand() == 1) {
    buffer = malloc(10);
}
else {
    buffer = malloc(11);
}
size_t index = 0;
if(rand() == 1) {
    index = 10;
}
buffer[index]; // potentially out-of-bounds depending on control-flow
```

Another common case *not* covered in this introductory workshop involves loops, as follows:

```cpp
int elements[5];
for (int i = 0; i <= 5; ++i) {
    elements[i] = 0;
}
```

To find these issues, we can implement an analysis that tracks the upper or lower bounds on an expression and, combined with data-flow analysis to reduce false-positives, identifies cases where the index of the array results in an access beyond the allocated size of the buffer.


<a id="a-note-on-the-scope-of-this-workshop"></a>

# A Note on the Scope of This Workshop

This workshop is not intended to be a complete analysis that is useful for real-world cases of out-of-bounds analyses for reasons including but not limited to:

-   Missing support for loops and recursion
-   No interprocedural analysis
-   Missing size calculation of arrays where the element size is not 1
-   No support for pointer arithmetic or in general, operations other than addition and subtraction
-   Overly specific modelling of a buffer access as an array expression

The goal of this workshop is rather to demonstrate the building blocks of analyzing run-time values and how to apply those building blocks to modelling a common class of vulnerability. A more comprehensive and production-appropriate example is the [OutOfBounds.qll library](https://github.com/github/codeql-coding-standards/blob/main/c/common/src/codingstandards/c/OutOfBounds.qll) from the [CodeQL Coding Standards repository](https://github.com/github/codeql-coding-standards).


<a id="sessionworkshop-notes"></a>

# Session/Workshop notes

Unlike the the [exercises](../README.md#org3b74422) which use the *collection* of test problems in `exercises-test`, this workshop is a sequential session following the actual process of writing CodeQL: use a *single* database built from a single, larger segment of code and inspect the query results as you write the query.

For this workshop, the larger segment of code is still simplified skeleton code, not a full source code repository.

The queries are embedded in \`session.md\` but can also be found in the \`example\*.ql\` files. They can all be run as test cases in VS Code.

To reiterate:

This workshop focuses on analyzing and relating two *static* values &#x2014; array access indices and memory allocation sizes &#x2014; in order to identify simple cases of out-of-bounds array accesses. We do not handle *dynamic* values but take advantage of special cases.

To find these issues,

1.  We can implement an analysis that tracks the upper or lower bounds on an expression.
2.  We then combine this with data-flow analysis to reduce false positives and identify cases where the index of the array results in an access beyond the allocated size of the buffer.
3.  We further extend these queries with rudimentary arithmetic support involving expressions common to the allocation and the array access.
4.  For cases where constant expressions are not available or are uncertain, we first try [range analysis](#org0df2f23) to expand the query's applicability.
5.  For cases where this is insufficient, we introduce global value numbering [GVN](https://codeql.github.com/docs/codeql-language-guides/hash-consing-and-value-numbering) in [Step 9 &#x2013; Global Value Numbering](#orge1acc6c), to detect values known to be equal at runtime.
6.  When *those* cases are insufficient, we handle the case of identical structure using [hashconsing](#org6332f3e).


<a id="exercise-1"></a>

## Step 1

In the first step we are going to

1.  identify a dynamic allocation with `malloc` and
2.  an access to that allocated buffer. The access is via an array expression; we are **not** going to cover pointer dereferencing.

The goal of this exercise is to then output the array access, array size, buffer, and buffer offset.

The focus here is on

    void test_const(void)

and

    void test_const_var(void)

in [db.c](file:///Users/hohn/local/codeql-workshop-runtime-values-c/session-db/DB/db.c).


<a id="hints"></a>

### Hints

1.  `Expr::getValue()::toInt()` can be used to get the integer value of a constant expression.


<a id="org2fc84f1"></a>

### Solution

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow

from AllocationExpr buffer, ArrayExpr access, int bufferSize, int accessIdx, Expr allocSizeExpr
where
  // malloc (100)
  // ^^^^^^  AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  //
  // buf[...]
  //     ^^^  int accessIdx
  //
  accessIdx = access.getArrayOffset().getValue().toInt() and
  //
  // malloc (100)
  //         ^^^ allocSizeExpr / bufferSize
  //
  allocSizeExpr = buffer.(Call).getArgument(0) and
  bufferSize = allocSizeExpr.getValue().toInt()
select buffer, access, accessIdx, access.getArrayOffset(), bufferSize, allocSizeExpr
```

This produces 12 results, with some cross-function pairs.


<a id="org81cc6bb"></a>

## Step 2

The previous query fails to connect the `malloc` calls with the array accesses, and in the results, `mallocs` from one function are paired with accesses in another.

To address these, take the query from the previous exercise and

1.  connect the allocation(s) with the
2.  array accesses


<a id="hints"></a>

### Hints

1.  Use `DataFlow::localExprFlow()` to relate the allocated buffer to the array base.
2.  The the array base is the `buf` part of `buf[0]`. Use the `Expr.getArrayBase()` predicate.


<a id="orgd82dd3e"></a>

### Solution

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow

// Step 2
// void test_const(void)
// void test_const_var(void)
from AllocationExpr buffer, ArrayExpr access, int bufferSize, int accessIdx, Expr allocSizeExpr
where
  // malloc (100)
  // ^^^^^^  AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  //
  // buf[...]
  //     ^^^  int accessIdx
  //
  accessIdx = access.getArrayOffset().getValue().toInt() and
  //
  // malloc (100)
  //         ^^^ allocSizeExpr / bufferSize
  //
  allocSizeExpr = buffer.(Call).getArgument(0) and
  bufferSize = allocSizeExpr.getValue().toInt() and
  //
  // Ensure alloc and buffer access are in the same function 
  // char *buf  = ... buf[0];
  //       ^^^  --->  ^^^
  // or
  // malloc(100);   buf[0]
  // ^^^  --------> ^^^
  //
  DataFlow::localExprFlow(buffer, access.getArrayBase())
select buffer, access, accessIdx, access.getArrayOffset(), bufferSize, allocSizeExpr
```


<a id="orgb9c5185"></a>

### Results

There are now 3 results. These are from only one function, the one using constants.


<a id="exercise-2"></a>

## Step 3

The previous results need to be extended to the case

```c++
void test_const_var(void)
{
    unsigned long size = 100;
    char *buf = malloc(size);
    buf[0];        // COMPLIANT
    ...
}
```

Here, the `malloc` argument is a variable with known value.

We include this result by removing the size-retrieval from the prior query.


<a id="orgbfcc6e8"></a>

### Solution

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow

// Step 3
// void test_const_var(void)
from AllocationExpr buffer, ArrayExpr access, int accessIdx, Expr allocSizeExpr
where
  // malloc (100)
  // ^^^^^^  AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  //
  // buf[...]
  //     ^^^  int accessIdx
  //
  accessIdx = access.getArrayOffset().getValue().toInt() and
  //
  // malloc (100)
  //         ^^^ allocSizeExpr / bufferSize
  //
  allocSizeExpr = buffer.(Call).getArgument(0) and
  // bufferSize = allocSizeExpr.getValue().toInt() and
  //
  // Ensure alloc and buffer access are in the same function   
  // char *buf  = ... buf[0];
  //       ^^^  --->  ^^^
  // or
  // malloc(100);   buf[0]
  // ^^^  --------> ^^^
  //
  DataFlow::localExprFlow(buffer, access.getArrayBase())
select buffer, access, accessIdx, access.getArrayOffset()
```


<a id="org77d93e8"></a>

### Results

Now, we get 12 results, including some from other test cases.


<a id="orgcac2df5"></a>

## Step 4

We are looking for out-of-bounds accesses, so we to need to include the bounds. But in a more general way than looking only at constant values.

Note the results for the cases in `test_const_var` which involve a variable access rather than a constant. The next goal is

1.  to handle the case where the allocation size or array index are variables (with constant values) rather than integer constants.

We have an expression `size` that flows into the `malloc()` call.


<a id="orge73d8c3"></a>

### Hint


<a id="orgcce7aa5"></a>

### Solution

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow

// Step 4
from AllocationExpr buffer, ArrayExpr access, int accessIdx, Expr allocSizeExpr, int bufferSize, Expr bse
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  //
  // buf[...]
  //     ^^^  int accessIdx
  //
  accessIdx = access.getArrayOffset().getValue().toInt() and
  //
  // malloc (100)
  //         ^^^ allocSizeExpr / bufferSize
  //
  allocSizeExpr = buffer.(Call).getArgument(0) and
  // bufferSize = allocSizeExpr.getValue().toInt() and
  //
  // unsigned long size = 100;
  // ...
  // char *buf = malloc(size);
  exists(Expr bufferSizeExpr |
    DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
    bufferSizeExpr.getValue().toInt() = bufferSize
    and bse = bufferSizeExpr
  ) and
  // Ensure alloc and buffer access are in the same function 
  // char *buf  = ... buf[0];
  //       ^^^  --->  ^^^
  // or
  // malloc(100);   buf[0]
  // ^^^  --------> ^^^
  //
  DataFlow::localExprFlow(buffer, access.getArrayBase())
select buffer, access, accessIdx, access.getArrayOffset(), bufferSize, bse
```


<a id="org58fd83d"></a>

### Results

Now, we get 15 results, limited to statically determined values.


<a id="org1a3052f"></a>

## Step 4a &#x2013; some clean-up using predicates

Note that the dataflow automatically captures/includes the

    allocSizeExpr = buffer.(Call).getArgument(0) 

so that's now redundant with `bufferSizeExpr` and can be removed.

```java

allocSizeExpr = buffer.(Call).getArgument(0) and
// bufferSize = allocSizeExpr.getValue().toInt() and
//
// unsigned long size = 100;
// ...
// char *buf = malloc(size);
DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and

```

Also, simplify the `from...where...select`:

1.  Remove unnecessary `exists` clauses.
2.  Use `DataFlow::localExprFlow` for the buffer and allocation sizes, with `getValue().toInt()` as one possibility (one predicate).


<a id="orgf922609"></a>

### Solution

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow

from AllocationExpr buffer, ArrayExpr access, int accessIdx, int bufferSize, Expr bufferSizeExpr
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  //
  // buf[...]
  //     ^^^  int accessIdx
  //
  accessIdx = access.getArrayOffset().getValue().toInt() and
  getAllocConstantExpr(bufferSizeExpr, bufferSize) and
  // Ensure alloc and buffer access are in the same function
  ensureSameFunction(buffer, access.getArrayBase()) and
  // Ensure size defintion and use are in same function, even for non-constant expressions.
  ensureSameFunction(bufferSizeExpr, buffer.getSizeExpr())
//
select buffer, access, accessIdx, access.getArrayOffset(), bufferSize, bufferSizeExpr

/** Ensure the two expressions are in the same function body. */
predicate ensureSameFunction(Expr a, Expr b) { DataFlow::localExprFlow(a, b) }

/**
 * Gets an expression that flows to the allocation (which includes those already in the allocation)
 * and has a constant value.
 */
predicate getAllocConstantExpr(Expr bufferSizeExpr, int bufferSize) {
  exists(AllocationExpr buffer |
    //
    // Capture BOTH with datflow:
    // 1.
    // malloc (100)
    //         ^^^ allocSizeExpr / bufferSize
    //
    // 2.
    // unsigned long size = 100;
    // ...
    // char *buf = malloc(size);
    DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
    bufferSizeExpr.getValue().toInt() = bufferSize
  )
}
```


<a id="org0df2f23"></a>

## Step 5 &#x2013; SimpleRangeAnalysis

Running the query from Step 2 against the database yields a significant number of missing or incorrect results. The reason is that although great at identifying compile-time constants and their use, data-flow analysis is not always the right tool for identifying the *range* of values an `Expr` might have, particularly when multiple potential constants might flow to an `Expr`.

The range analysis already handles conditional branches; we don't have to use guards on data flow &#x2013; don't implement your own interpreter if you can use the library.

The CodeQL standard library has several mechanisms for addressing this problem; in the remainder of this workshop we will explore two of them: `SimpleRangeAnalysis` and, later, `GlobalValueNumbering`.

Although not in the scope of this workshop, a standard use-case for range analysis is reliably identifying integer overflow and validating integer overflow checks.

Now, add the use of the `SimpleRangeAnalysis` library. Specifically, the relevant library predicates are `upperBound` and `lowerBound`, to be used with the buffer access argument.

Notes:

-   This requires the import
    
        import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis
-   We are not limiting the array access to integers any longer. Thus, we just use
    
        accessIdx = access.getArrayOffset()
-   To see the results in the order used in the C code, use
    
        select bufferSizeExpr, buffer, access, accessIdx, upperBound(accessIdx) as accessMax


<a id="orgb23c26e"></a>

### Solution

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis


from AllocationExpr buffer, ArrayExpr access, Expr accessIdx, int bufferSize, Expr bufferSizeExpr
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  //
  // buf[...]
  //     ^^^  int accessIdx
  //
  accessIdx = access.getArrayOffset() and
  //
  // malloc (100)
  //         ^^^ allocSizeExpr / bufferSize
  //
  getAllocConstantExpr(bufferSizeExpr, bufferSize) and
  // Ensure alloc and buffer access are in the same function
  ensureSameFunction(buffer, access.getArrayBase()) and
  // Ensure size defintion and use are in same function, even for non-constant expressions.
  ensureSameFunction(bufferSizeExpr, buffer.getSizeExpr())
//
select bufferSizeExpr, buffer, access, accessIdx, upperBound(accessIdx) as accessMax

/** Ensure the two expressions are in the same function body. */
predicate ensureSameFunction(Expr a, Expr b) { DataFlow::localExprFlow(a, b) }

/**
 * Gets an expression that flows to the allocation (which includes those already in the allocation)
 * and has a constant value.
 */
predicate getAllocConstantExpr(Expr bufferSizeExpr, int bufferSize) {
  exists(AllocationExpr buffer |
    //
    // Capture BOTH with datflow:
    // 1.
    // malloc (100)
    //         ^^^ allocSizeExpr / bufferSize
    //
    // 2.
    // unsigned long size = 100;
    // ...
    // char *buf = malloc(size);
    DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
    bufferSizeExpr.getValue().toInt() = bufferSize
  )
}
```


<a id="org921d64a"></a>

### First 5 results

| test.c:7:24:7:26   | 100 | test.c:7:17:7:22   | call to malloc | test.c:8:5:8:10   | access to array | test.c:8:9:8:9    | 0   | 0.0   |
| test.c:7:24:7:26   | 100 | test.c:7:17:7:22   | call to malloc | test.c:9:5:9:11   | access to array | test.c:9:9:9:10   | 99  | 99.0  |
| test.c:7:24:7:26   | 100 | test.c:7:17:7:22   | call to malloc | test.c:10:5:10:12 | access to array | test.c:10:9:10:11 | 100 | 100.0 |
| test.c:15:26:15:28 | 100 | test.c:16:17:16:22 | call to malloc | test.c:17:5:17:10 | access to array | test.c:17:9:17:9  | 0   | 0.0   |
| test.c:15:26:15:28 | 100 | test.c:16:17:16:22 | call to malloc | test.c:18:5:18:11 | access to array | test.c:18:9:18:10 | 99  | 99.0  |


<a id="org2b0d3ac"></a>

## Step 6

To finally determine (some) out-of-bounds accesses, we have to convert allocation units (usually in bytes) to size units. Then we are finally in a position to compare buffer allocation size to the access index to find out-of-bounds accesses &#x2013; at least for expressions with known values.

Add these to the query:

1.  Convert allocation units to size units.
2.  Convert access units to the same size units.

Hints:

1.  We need the size of the array element. Use `access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType()` to see the type and `access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize()` to get its size.

2.  Note from the docs: *The malloc() function allocates size bytes of memory and returns a pointer to the allocated memory.* So `size = 1`

3.  These test cases all use type `char`. What would happen for `int` or `double`?


<a id="orgdd0881f"></a>

### Solution

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis

from AllocationExpr buffer, ArrayExpr access, Expr accessIdx, int bufferSize, Expr bufferSizeExpr
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  //
  // buf[...]
  //     ^^^  int accessIdx
  //
  accessIdx = access.getArrayOffset() and
  //
  // malloc (100)
  //         ^^^ allocSizeExpr / bufferSize
  //
  getAllocConstantExpr(bufferSizeExpr, bufferSize) and
  // Ensure alloc and buffer access are in the same function
  ensureSameFunction(buffer, access.getArrayBase()) and
  // Ensure size defintion and use are in same function, even for non-constant expressions.
  ensureSameFunction(bufferSizeExpr, buffer.getSizeExpr())
//
select bufferSizeExpr, buffer, access, accessIdx, upperBound(accessIdx) as accessMax, bufferSize,
  access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType() as arrayBaseType,
  access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() as arrayTypeSize,
  1 as allocBaseSize

/** Ensure the two expressions are in the same function body. */
predicate ensureSameFunction(Expr a, Expr b) { DataFlow::localExprFlow(a, b) }

/**
 * Gets an expression that flows to the allocation (which includes those already in the allocation)
 * and has a constant value.
 */
predicate getAllocConstantExpr(Expr bufferSizeExpr, int bufferSize) {
  exists(AllocationExpr buffer |
    //
    // Capture BOTH with datflow:
    // 1.
    // malloc (100)
    //         ^^^ allocSizeExpr / bufferSize
    //
    // 2.
    // unsigned long size = 100;
    // ...
    // char *buf = malloc(size);
    DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
    bufferSizeExpr.getValue().toInt() = bufferSize
  )
}
```


<a id="org3e7d47c"></a>

### First 5 results

| test.c:7:24:7:26   | 100 | test.c:7:17:7:22   | call to malloc | test.c:8:5:8:10   | access to array | test.c:8:9:8:9    | 0   | 0.0   | 100 | <file://:0:0:0:0> | char | 1 | 1 |
| test.c:7:24:7:26   | 100 | test.c:7:17:7:22   | call to malloc | test.c:9:5:9:11   | access to array | test.c:9:9:9:10   | 99  | 99.0  | 100 | <file://:0:0:0:0> | char | 1 | 1 |
| test.c:7:24:7:26   | 100 | test.c:7:17:7:22   | call to malloc | test.c:10:5:10:12 | access to array | test.c:10:9:10:11 | 100 | 100.0 | 100 | <file://:0:0:0:0> | char | 1 | 1 |
| test.c:15:26:15:28 | 100 | test.c:16:17:16:22 | call to malloc | test.c:17:5:17:10 | access to array | test.c:17:9:17:9  | 0   | 0.0   | 100 | <file://:0:0:0:0> | char | 1 | 1 |
| test.c:15:26:15:28 | 100 | test.c:16:17:16:22 | call to malloc | test.c:18:5:18:11 | access to array | test.c:18:9:18:10 | 99  | 99.0  | 100 | <file://:0:0:0:0> | char | 1 | 1 |


<a id="org00edfe5"></a>

## Step 7

1.  Clean up the query.
2.  Compare buffer allocation size to the access index.
3.  Add expressions for `allocatedUnits` (from the malloc) and a `maxAccessedIndex` (from array accesses)
    1.  Calculate the `accessOffset` / `maxAccessedIndex` (from array accesses)
    2.  Calculate the `allocSize` / `allocatedUnits` (from the malloc)
    3.  Compare them


<a id="org8a3a4b1"></a>

### Solution:

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis

from
  AllocationExpr buffer, ArrayExpr access, Expr accessIdx, int bufferSize, Expr bufferSizeExpr,
  int arrayTypeSize, int allocBaseSize
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  // buf[...]
  // ^^^  ArrayExpr access
  // buf[...]
  //     ^^^  int accessIdx
  accessIdx = access.getArrayOffset() and
  //
  // malloc (100)
  //         ^^^ allocSizeExpr / bufferSize
  //
  getAllocConstantExpr(bufferSizeExpr, bufferSize) and
  // Ensure alloc and buffer access are in the same function
  ensureSameFunction(buffer, access.getArrayBase()) and
  // Ensure size defintion and use are in same function, even for non-constant expressions.
  ensureSameFunction(bufferSizeExpr, buffer.getSizeExpr()) and
  //
  arrayTypeSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() and
  1 = allocBaseSize
//
select bufferSizeExpr, buffer, access, accessIdx, upperBound(accessIdx) as accessMax, bufferSize,
  access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType() as arrayBaseType,
  allocBaseSize * bufferSize as allocatedUnits, arrayTypeSize * accessMax as maxAccessedIndex

/** Ensure the two expressions are in the same function body. */
predicate ensureSameFunction(Expr a, Expr b) { DataFlow::localExprFlow(a, b) }

/**
 * Gets an expression that flows to the allocation (which includes those already in the allocation)
 * and has a constant value.
 */
predicate getAllocConstantExpr(Expr bufferSizeExpr, int bufferSize) {
  exists(AllocationExpr buffer |
    // Capture BOTH with datflow:
    // 1.
    // malloc (100)
    //         ^^^ allocSizeExpr / bufferSize
    // 2.
    // unsigned long size = 100; ... ; char *buf = malloc(size);
    DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
    bufferSizeExpr.getValue().toInt() = bufferSize
  )
}
```


<a id="org2f15e3e"></a>

### First 5 results

| test.c:7:24:7:26   | 100 | test.c:7:17:7:22   | call to malloc | test.c:8:5:8:10   | access to array | test.c:8:9:8:9    | 0   | 0.0   | 100 | <file://:0:0:0:0> | char | 100 | 0.0   |
| test.c:7:24:7:26   | 100 | test.c:7:17:7:22   | call to malloc | test.c:9:5:9:11   | access to array | test.c:9:9:9:10   | 99  | 99.0  | 100 | <file://:0:0:0:0> | char | 100 | 99.0  |
| test.c:7:24:7:26   | 100 | test.c:7:17:7:22   | call to malloc | test.c:10:5:10:12 | access to array | test.c:10:9:10:11 | 100 | 100.0 | 100 | <file://:0:0:0:0> | char | 100 | 100.0 |
| test.c:15:26:15:28 | 100 | test.c:16:17:16:22 | call to malloc | test.c:17:5:17:10 | access to array | test.c:17:9:17:9  | 0   | 0.0   | 100 | <file://:0:0:0:0> | char | 100 | 0.0   |
| test.c:15:26:15:28 | 100 | test.c:16:17:16:22 | call to malloc | test.c:18:5:18:11 | access to array | test.c:18:9:18:10 | 99  | 99.0  | 100 | <file://:0:0:0:0> | char | 100 | 99.0  |


<a id="orgfa97dcd"></a>

## Step 7a

1.  Account for base sizes &#x2013; `char` in this case.
2.  Put all expressions into the select for review.


<a id="org3894df3"></a>

### Solution:

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis

from
  AllocationExpr buffer, ArrayExpr access, Expr accessIdx, int bufferSize, Expr bufferSizeExpr,
  int arrayTypeSize, int allocBaseSize
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  // buf[...]
  // ^^^^^^^^  ArrayExpr access
  //     ^^^  int accessIdx
  accessIdx = access.getArrayOffset() and
  getAllocConstantExpr(bufferSizeExpr, bufferSize) and
  // Ensure alloc and buffer access are in the same function
  ensureSameFunction(buffer, access.getArrayBase()) and
  // Ensure size defintion and use are in same function, even for non-constant expressions.
  ensureSameFunction(bufferSizeExpr, buffer.getSizeExpr()) and
  //
  arrayTypeSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() and
  1 = allocBaseSize
//
select bufferSizeExpr, buffer, access, accessIdx, upperBound(accessIdx) as accessMax, bufferSize,
  access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType() as arrayBaseType,
  buffer.getSizeMult() as bufferBaseTypeSize,
  arrayBaseType.getSize() as arrayBaseTypeSize,
  allocBaseSize * bufferSize as allocatedUnits, arrayTypeSize * accessMax as maxAccessedIndex

/** Ensure the two expressions are in the same function body. */
predicate ensureSameFunction(Expr a, Expr b) { DataFlow::localExprFlow(a, b) }

/**
 * Gets an expression that flows to the allocation (which includes those already in the allocation)
 * and has a constant value.
 */
predicate getAllocConstantExpr(Expr bufferSizeExpr, int bufferSize) {
  exists(AllocationExpr buffer |
    // Capture BOTH with datflow:
    // 1.
    // malloc (100)
    //         ^^^ bufferSize
    // 2.
    // unsigned long size = 100; ... ; char *buf = malloc(size);
    DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
    bufferSizeExpr.getValue().toInt() = bufferSize
  )
}
```


<a id="orgcbdf216"></a>

### First 5 results

| test.c:7:24:7:26   | 100 | test.c:7:17:7:22   | call to malloc | test.c:8:5:8:10   | access to array | test.c:8:9:8:9    | 0   | 0.0   | 100 | <file://:0:0:0:0> | char | 1 | 1 | 100 | 0.0   |
| test.c:7:24:7:26   | 100 | test.c:7:17:7:22   | call to malloc | test.c:9:5:9:11   | access to array | test.c:9:9:9:10   | 99  | 99.0  | 100 | <file://:0:0:0:0> | char | 1 | 1 | 100 | 99.0  |
| test.c:7:24:7:26   | 100 | test.c:7:17:7:22   | call to malloc | test.c:10:5:10:12 | access to array | test.c:10:9:10:11 | 100 | 100.0 | 100 | <file://:0:0:0:0> | char | 1 | 1 | 100 | 100.0 |
| test.c:15:26:15:28 | 100 | test.c:16:17:16:22 | call to malloc | test.c:17:5:17:10 | access to array | test.c:17:9:17:9  | 0   | 0.0   | 100 | <file://:0:0:0:0> | char | 1 | 1 | 100 | 0.0   |
| test.c:15:26:15:28 | 100 | test.c:16:17:16:22 | call to malloc | test.c:18:5:18:11 | access to array | test.c:18:9:18:10 | 99  | 99.0  | 100 | <file://:0:0:0:0> | char | 1 | 1 | 100 | 99.0  |


<a id="org58aba89"></a>

## Step 7b

Introduce more general predicates.

1.  Move these into a single predicate, `isOffsetOutOfBoundsConstant`


<a id="orgd60c31b"></a>

### TODO incoporate

```java
/**
 * Gets the smallest of the upper bound of `e` or the largest source value
 * (i.e. "stated value") that flows to `e`.  Because range-analysis can over-widen
 * bounds, take the minimum of range analysis and data-flow sources.
 *
 * If there is no source value that flows to `e`, this predicate does not hold.
 *
 * This predicate, if `e` is the `sz` arg to `malloc`, would return `20` for the
 * following:
 *
 * size_t sz = condition ? 10 : 20;
 * malloc(sz);
 *
 */
bindingset[e]
int getMaxStatedValue(Expr e) {
  result = upperBound(e).minimum(max(getSourceConstantExpr(e).getValue().toInt()))
}
```


<a id="org3319200"></a>

### TODO incoporate

```java
predicate isOffsetOutOfBoundsConstant(
  ArrayExpr access, FunctionCall source, int allocSize, int accessOffset
) {
  ensureSameFunction(access, source) and
  // allocatedBufferArrayAccess(access, source) and
  allocSize = getMaxStatedValue(source.getArgument(0)) and
  accessOffset = getFixedArrayOffset(access) and
  accessOffset >= allocSize
}
```


<a id="orgcfcb55c"></a>

## Step 8

1.  Clean up the query.
2.  Compare buffer allocation size to the access index.
3.  Report only the questionable entries.
4.  Use
    
    ```java
    /**
     * @kind problem
     */
    ```
    
    to get nicer reporting.


<a id="orgede6c66"></a>

### Solution:

```java
/**
 * @kind problem
 */

import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis

// Step 8
from
  AllocationExpr buffer, ArrayExpr access, Expr accessIdx, Expr allocSizeExpr, int bufferSize,
  int allocsize, Expr bufferSizeExpr, int arrayTypeSize, int allocBaseSize, int accessMax,
  int allocatedUnits, int maxAccessedIndex
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  // buf[...]
  //     ^^^  int accessIdx
  accessIdx = access.getArrayOffset() and
  //
  // malloc (100)
  //         ^^^ allocSizeExpr / bufferSize
  //
  // Not really:
  //   allocSizeExpr = buffer.(Call).getArgument(0) and
  //
  DataFlow::localExprFlow(allocSizeExpr, buffer.(Call).getArgument(0)) and
  allocsize = allocSizeExpr.getValue().toInt() and
  //
  // unsigned long size = 100;
  // ...
  // char *buf = malloc(size);
  DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
  bufferSizeExpr.getValue().toInt() = bufferSize and
  // char *buf  = ... buf[0];
  //       ^^^  --->  ^^^
  // or
  // malloc(100);   buf[0]
  // ^^^  --------> ^^^
  //
  arrayTypeSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() and
  1 = allocBaseSize and
  DataFlow::localExprFlow(buffer, access.getArrayBase()) and
  upperBound(accessIdx) = accessMax and
  allocBaseSize * allocsize = allocatedUnits and
  arrayTypeSize * accessMax =  maxAccessedIndex and
  // only consider out-of-bounds
  maxAccessedIndex >= allocatedUnits
select access, "Array access at or beyond size; have "+allocatedUnits + " units, access at "+ maxAccessedIndex
```


<a id="orgfa54b95"></a>

### Results

14 results in the much cleaner table

|                                                              |          |
|------------------------------------------------------------- |--------- |
| Array access at or beyond size; have 200 units, access at 200 | db.c:67:5 |


<a id="org68d8dfb"></a>

## Interim notes

A common issue with the `SimpleRangeAnalysis` library is handling of cases where the bounds are undeterminable at compile-time on one or more paths. For example, even though certain paths have clearly defined bounds, the range analysis library will define the `upperBound` and `lowerBound` of `val` as `INT_MIN` and `INT_MAX` respectively:

```cpp
int val = rand() ? rand() : 30;
```

A similar case is present in the `test_const_branch` and `test_const_branch2` test-cases. In these cases, it is necessary to augment range analysis with data-flow and restrict the bounds to the upper or lower bound of computable constants that flow to a given expression. Another approach is global value numbering, used next.


<a id="orge1acc6c"></a>

## Step 9 &#x2013; Global Value Numbering

Range analyis won't bound `sz * x * y`, so switch to global value numbering. This is the case in the last test case,

    void test_gvn_var(unsigned long x, unsigned long y, unsigned long sz)
    {
        char *buf = malloc(sz * x * y);
        buf[sz * x * y - 1]; // COMPLIANT
        buf[sz * x * y];     // NON_COMPLIANT
        buf[sz * x * y + 1]; // NON_COMPLIANT
    }

Reference: <https://codeql.github.com/docs/codeql-language-guides/hash-consing-and-value-numbering/>

Global value numbering only knows that runtime values are equal; they are not comparable (`<, >, <=` etc.), and the *actual* value is not known.

Global value numbering finds expressions with the same known value, independent of structure.

So, we look for and use *relative* values between allocation and use.

The relevant CodeQL constructs are

```java
import semmle.code.cpp.valuenumbering.GlobalValueNumbering
...
globalValueNumber(e) = globalValueNumber(sizeExpr) and
e != sizeExpr
...
```

We can use global value numbering to identify common values as first step, but for expressions like

    buf[sz * x * y - 1]; // COMPLIANT

we have to "evaluate" the expressions &#x2013; or at least bound them.


<a id="orgb19cfc3"></a>

### DONE incorporate

Done by `ensureSameFunction` instead.

```java
predicate allocatedBufferArrayAccess(ArrayExpr access, FunctionCall alloc) {
  alloc.getTarget().hasName("malloc") and
  DataFlow::localExprFlow(alloc, access.getArrayBase())
}
```


<a id="orgda109c3"></a>

### TODO incorporate

```java
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
```


<a id="org8d0c13d"></a>

### TODO incoporate

```java
int getFixedArrayOffset(ArrayExpr access) {
  exists(Expr base, int offset |
    offset = getExprOffsetValue(access.getArrayOffset(), base) and
    result = getMaxStatedValue(base) + offset
  )
}
```


<a id="org45411bb"></a>

### TODO incoporate

```java
predicate isOffsetOutOfBoundsGVN(ArrayExpr access, FunctionCall source) {
  ensureSameFunction(access, source) and
  not isOffsetOutOfBoundsConstant(access, source, _, _) and
  exists(Expr accessOffsetBase, int accessOffsetBaseValue |
    accessOffsetBaseValue = getExprOffsetValue(access.getArrayOffset(), accessOffsetBase) and
    globalValueNumber(source.getArgument(0)) = globalValueNumber(accessOffsetBase) and
    not accessOffsetBaseValue < 0
  )
}
```


<a id="org364861b"></a>

### TODO incoporate

```java
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
```


<a id="orgc0ae12b"></a>

### interim

```java
/**
 * @ kind problem
 */

import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis
import semmle.code.cpp.valuenumbering.GlobalValueNumbering

// Step 9
from
  AllocationExpr buffer, ArrayExpr access, Expr accessIdx, Expr allocSizeExpr, int bufferSize,
  int allocsize, Expr bufferSizeExpr, int arrayTypeSize, int allocBaseSize, int accessMax,
  int allocatedUnits, int maxAccessedIndex
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  // buf[...]
  //     ^^^  int accessIdx
  accessIdx = access.getArrayOffset() and
  //
  // malloc (100)
  //         ^^^ allocSizeExpr / bufferSize
  //
  // Not really:
  //   allocSizeExpr = buffer.(Call).getArgument(0) and
  //
  DataFlow::localExprFlow(allocSizeExpr, buffer.(Call).getArgument(0)) and
  allocsize = allocSizeExpr.getValue().toInt() and
  //
  // unsigned long size = 100;
  // ...
  // char *buf = malloc(size);
  DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
  bufferSizeExpr.getValue().toInt() = bufferSize and
  // char *buf  = ... buf[0];
  //       ^^^  --->  ^^^
  // or
  // malloc(100);   buf[0]
  // ^^^  --------> ^^^
  //
  arrayTypeSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() and
  1 = allocBaseSize and
  DataFlow::localExprFlow(buffer, access.getArrayBase()) and
  upperBound(accessIdx) = accessMax and
  allocBaseSize * allocsize = allocatedUnits and
  arrayTypeSize * accessMax = maxAccessedIndex and
  // only consider out-of-bounds
  maxAccessedIndex >= allocatedUnits
select access,
  "Array access at or beyond size; have " + allocatedUnits + " units, access at " + maxAccessedIndex,
  globalValueNumber(accessIdx) as gvnAccess, globalValueNumber(allocSizeExpr) as gvnAlloc
```


<a id="orgb2f39ee"></a>

### interim

Messy, start over.

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis
import semmle.code.cpp.valuenumbering.GlobalValueNumbering

// Step 9
from
  AllocationExpr buffer, ArrayExpr access, Expr accessIdx, Expr allocSizeExpr, GVN gvnAccess,
  GVN gvnAlloc
where
  // malloc (100)
  // ^^^^^^^^^^^^ AllocationExpr buffer
  //
  // buf[...]
  // ^^^  ArrayExpr access
  // buf[...]
  //     ^^^ accessIdx
  accessIdx = access.getArrayOffset() and
  //
  // malloc (100)
  //         ^^^ allocSizeExpr / bufferSize
  // unsigned long size = 100;
  // ...
  // char *buf = malloc(size);
  DataFlow::localExprFlow(allocSizeExpr, buffer.getSizeExpr()) and
  // char *buf  = ... buf[0];
  //       ^^^  --->  ^^^
  // or
  // malloc(100);   buf[0]
  // ^^^  --------> ^^^
  //
  DataFlow::localExprFlow(buffer, access.getArrayBase()) and
  //
  // Use GVN
  globalValueNumber(accessIdx) = gvnAccess and
  globalValueNumber(allocSizeExpr) = gvnAlloc and
  (
    gvnAccess = gvnAlloc
    or
    // buf[sz * x * y] above
    // buf[sz * x * y + 1];
    exists(AddExpr add |
      accessIdx = add and
      // add.getAnOperand() = accessIdx and
      add.getAnOperand().getValue().toInt() > 0 and
      globalValueNumber(add.getAnOperand()) = gvnAlloc
    )
  )
select access, gvnAccess, gvnAlloc
```


<a id="org6332f3e"></a>

## TODO hashconsing

import semmle.code.cpp.valuenumbering.HashCons

hashcons: every value gets a number based on structure. Fails on

    char *buf = malloc(sz * x * y);
    sz = 100;
    buf[sz * x * y - 1]; // COMPLIANT

The final exercise is to implement the `isOffsetOutOfBoundsGVN` predicate to [&#x2026;]
