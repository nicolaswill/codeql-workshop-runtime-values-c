- [CodeQL Workshop &#x2014; Using Data-Flow and Range Analysis to Find Out-Of-Bounds Accesses](#codeql-workshop--using-data-flow-and-range-analysis-to-find-out-of-bounds-accesses)
- [Acknowledgments](#acknowledgments)
- [Setup Instructions](#setup-instructions)
- [Introduction](#introduction)
- [A Note on the Scope of This Workshop](#a-note-on-the-scope-of-this-workshop)
- [Session/Workshop notes](#sessionworkshop-notes)
  - [Step 1](#exercise-1)
    - [Hints](#hints)
    - [Solution](#orgdb027c4)
  - [Step 2](#org103a4a0)
    - [Hints](#hints)
    - [Solution](#org9a38362)
    - [Results](#org0373f43)
  - [Step 3](#exercise-2)
    - [Solution](#org100e79f)
    - [Results](#orgc91557b)
  - [Step 4](#org5ed496c)
    - [Hint](#org353b905)
    - [Solution](#org5e7a90d)
    - [Results](#orgc376727)
  - [Step 4a &#x2013; some clean-up using predicates](#org5fbc890)
    - [Solution](#orgc0ef9cd)
  - [Step 5 &#x2013; SimpleRangeAnalysis](#org3250327)
    - [Solution](#orga42f2d0)
    - [Results](#org2dd5caf)
  - [Step 6](#org7bfbf7f)
    - [Solution](#orgbf7f580)
    - [Results](#orgc770d19)
  - [Step 7](#org27d428b)
    - [Solution:](#org1d7080e)
    - [Results](#orgcc04f97)
  - [Step 8](#orgd04e3b9)
    - [Solution:](#org6638628)
    - [Results](#org42712eb)
  - [Interim notes](#org4007937)
  - [Step 9 &#x2013; Global Value Numbering](#orgde8bf97)
    - [interim](#org08c13b9)
    - [interim](#org11a3f79)
  - [hashconsing](#orgc7ce1fc)


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
4.  For cases where this is insufficient, we introduce global value numbering [GVN](https://codeql.github.com/docs/codeql-language-guides/hash-consing-and-value-numbering) in [Step 9 &#x2013; Global Value Numbering](#orgde8bf97), to detect values known to be equal at runtime.
5.  When *those* cases are insufficient, and we handle the case of identical structure using [hashconsing](#orgc7ce1fc).


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


<a id="orgdb027c4"></a>

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


<a id="org103a4a0"></a>

## Step 2

The previous query fails to connect the `malloc` calls with the array accesses, and in the results, `mallocs` from one function are paired with accesses in another.

To address these, take the query from the previous exercise and

1.  connect the allocation(s) with the
2.  array accesses


<a id="hints"></a>

### Hints

1.  Use `DataFlow::localExprFlow()` to relate the allocated buffer to the array base.
2.  The the array base is the `buf` part of `buf[0]`. Use the `Expr.getArrayBase()` predicate.


<a id="org9a38362"></a>

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


<a id="org0373f43"></a>

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


<a id="org100e79f"></a>

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


<a id="orgc91557b"></a>

### Results

Now, we get 12 results, including some from other test cases.


<a id="org5ed496c"></a>

## Step 4

We are looking for out-of-bounds accesses, so we to need to include the bounds. But in a more general way than looking only at constant values.

Note the results for the cases in `test_const_var` which involve a variable access rather than a constant. The next goal is

1.  to handle the case where the allocation size or array index are variables (with constant values) rather than integer constants.

We have an expression `size` that flows into the `malloc()` call.


<a id="org353b905"></a>

### Hint


<a id="org5e7a90d"></a>

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


<a id="orgc376727"></a>

### Results

Now, we get 15 results, limited to statically determined values.

XX: Implement predicates `getSourceConstantExpr`, `getFixedSize`, and `getFixedArrayOffset` Use local data-flow analysis to complete the `getSourceConstantExpr` predicate. The `getFixedSize` and `getFixedArrayOffset` predicates can be completed using `getSourceConstantExpr`.

XX:

1.  start with query. `elementSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize()`
2.  convert to predicate.
3.  then use classes, if desired. `class BufferAccess extends ArrayExpr` is different from those below.


<a id="org5fbc890"></a>

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


<a id="orgc0ef9cd"></a>

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


<a id="org3250327"></a>

## Step 5 &#x2013; SimpleRangeAnalysis

Running the query from Step 2 against the database yields a significant number of missing or incorrect results. The reason is that although great at identifying compile-time constants and their use, data-flow analysis is not always the right tool for identifying the *range* of values an `Expr` might have, particularly when multiple potential constants might flow to an `Expr`.

The range analysis already handles conditional branches; we don't have to use guards on data flow &#x2013; don't implement your own interpreter if you can use the library.

The CodeQL standard library has several mechanisms for addressing this problem; in the remainder of this workshop we will explore two of them: `SimpleRangeAnalysis` and, later, `GlobalValueNumbering`.

Although not in the scope of this workshop, a standard use-case for range analysis is reliably identifying integer overflow and validating integer overflow checks.

First, simplify the `from...where...select`:

1.  Remove unnecessary `exists` clauses.
2.  Use `DataFlow::localExprFlow` for the buffer and allocation sizes, not `getValue().toInt()`

Then, add the use of the `SimpleRangeAnalysis` library. Specifically, the relevant library predicates are `upperBound` and `lowerBound`, to be used with the buffer access argument. Experiment and decide which to use for this exercise (`upperBound`, `lowerBound`, or both).

This requires the import

    import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis


<a id="orga42f2d0"></a>

### Solution

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis

// Step 5
from
  AllocationExpr buffer, ArrayExpr access, Expr accessIdx, Expr allocSizeExpr, int bufferSize,
  int allocsize, Expr bufferSizeExpr
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
  DataFlow::localExprFlow(buffer, access.getArrayBase())
select buffer, bufferSizeExpr, access, upperBound(accessIdx) as accessMax, accessIdx, allocsize, allocSizeExpr
```


<a id="org2dd5caf"></a>

### Results

Now, we get 48 results.


<a id="org7bfbf7f"></a>

## Step 6

To finally determine (some) out-of-bounds accesses, we have to convert allocation units (usually in bytes) to size units. Then we are finally in a position to compare buffer allocation size to the access index to find out-of-bounds accesses &#x2013; at least for expressions with known values.

Add these to the query:

1.  Convert allocation units to size units.
2.  Convert access units to the same size units.

Hints:

1.  We need the size of the array element. Use `access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType()` to see the type and `access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize()` to get its size.

2.  Note from the docs: *The malloc() function allocates size bytes of memory and returns a pointer to the allocated memory.* So `size = 1`

3.  Note that `allocSizeExpr.getUnspecifiedType() as allocBaseType` is wrong here.

4.  These test cases all use type `char`. What would happen for `int` or `double`?


<a id="orgbf7f580"></a>

### Solution

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis

// Step 6
from
  AllocationExpr buffer, ArrayExpr access, Expr accessIdx, Expr allocSizeExpr, int bufferSize,
  int allocsize, Expr bufferSizeExpr
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
  DataFlow::localExprFlow(buffer, access.getArrayBase())
select buffer, bufferSizeExpr, access, upperBound(accessIdx) as accessMax, accessIdx, allocsize, allocSizeExpr,  access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType() as arrayBaseType, access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() as arrayTypeSize,  1 as allocBaseSize
```


<a id="orgc770d19"></a>

### Results

48 results in the table

|    |               |    |                |    |    |    |    |     |    |    |
|--- |-------------- |--- |--------------- |--- |--- |--- |--- |---- |--- |--- |
| 1 | call to malloc | 200 | access to array | 0 | 0 | 200 | 200 | char | 1 | 1 |


<a id="org27d428b"></a>

## Step 7

1.  Clean up the query.
2.  Add expressions for `allocatedUnits` (from the malloc) and a `maxAccessedIndex` (from array accesses)
3.  Compare buffer allocation size to the access index.


<a id="org1d7080e"></a>

### Solution:

```java
import cpp
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis

// Step 7
from
  AllocationExpr buffer, ArrayExpr access, Expr accessIdx, Expr allocSizeExpr, int bufferSize,
  int allocsize, Expr bufferSizeExpr, int arrayTypeSize, int allocBaseSize
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
  arrayTypeSize =  access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() 
  and
  1 = allocBaseSize
  and
  DataFlow::localExprFlow(buffer, access.getArrayBase())
select buffer, bufferSizeExpr, access, upperBound(accessIdx) as accessMax, allocSizeExpr,   allocBaseSize * allocsize as allocatedUnits, arrayTypeSize * accessMax as maxAccessedIndex
```


<a id="orgcc04f97"></a>

### Results

48 results in the much cleaner table

| no. | buffer         | bufferSizeExpr | access          | accessMax | allocSizeExpr | allocatedUnits | maxAccessedIndex |  |
| 1   | call to malloc | 200            | access to array | 0         | 200           | 200            | 0                |  |


<a id="orgd04e3b9"></a>

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


<a id="org6638628"></a>

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


<a id="org42712eb"></a>

### Results

14 results in the much cleaner table

|                                                              |          |
|------------------------------------------------------------- |--------- |
| Array access at or beyond size; have 200 units, access at 200 | db.c:67:5 |


<a id="org4007937"></a>

## Interim notes

A common issue with the `SimpleRangeAnalysis` library is handling of cases where the bounds are undeterminable at compile-time on one or more paths. For example, even though certain paths have clearly defined bounds, the range analysis library will define the `upperBound` and `lowerBound` of `val` as `INT_MIN` and `INT_MAX` respectively:

```cpp
int val = rand() ? rand() : 30;
```

A similar case is present in the `test_const_branch` and `test_const_branch2` test-cases. In these cases, it is necessary to augment range analysis with data-flow and restrict the bounds to the upper or lower bound of computable constants that flow to a given expression. Another approach is global value numbering, used next.


<a id="orgde8bf97"></a>

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

XX: global value numbering finds expressions with the same known value, independent of structure.

So, we look for and use *relative* values between allocation and use. To do this, use GVN.

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


<a id="org08c13b9"></a>

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


<a id="org11a3f79"></a>

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


<a id="orgc7ce1fc"></a>

## TODO hashconsing

import semmle.code.cpp.valuenumbering.HashCons

hashcons: every value gets a number based on structure. Fails on

    char *buf = malloc(sz * x * y);
    sz = 100;
    buf[sz * x * y - 1]; // COMPLIANT

The final exercise is to implement the `isOffsetOutOfBoundsGVN` predicate to [&#x2026;]
