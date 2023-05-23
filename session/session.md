
# Table of Contents

1.  [CodeQL Workshop &#x2014; Using Data-Flow and Range Analysis to Find Out-Of-Bounds Accesses](#codeql-workshop--using-data-flow-and-range-analysis-to-find-out-of-bounds-accesses)
2.  [Acknowledgments](#acknowledgments)
3.  [Setup Instructions](#setup-instructions)
4.  [Introduction](#introduction)
5.  [A Note on the Scope of This Workshop](#a-note-on-the-scope-of-this-workshop)
6.  [A short note on the structure of directories and their use](#org28d73fb)
7.  [Session/Workshop notes](#sessionworkshop-notes)
    1.  [Step 1](#exercise-1)
        1.  [Hints](#hints)
        2.  [Solution](#org4777775)
        3.  [First 5 results](#org1aa6a22)
    2.  [Step 2](#org1e52aa7)
        1.  [Hints](#hints)
        2.  [Solution](#org4ba1960)
        3.  [First 5 results](#org61872ef)
    3.  [Step 3](#exercise-2)
        1.  [Solution](#orgffef32c)
        2.  [First 5 results](#orga647c8f)
    4.  [Step 4](#orgd616664)
        1.  [Hint](#orga9ca0e1)
        2.  [Solution](#org072f835)
        3.  [First 5 results](#orgab7f021)
    5.  [Step 4a &#x2013; some clean-up using predicates](#org74d9df9)
        1.  [Solution](#orgd5a3519)
        2.  [First 5 results](#orga608103)
    6.  [Step 5 &#x2013; SimpleRangeAnalysis](#org426ad70)
        1.  [Solution](#org7c6288c)
        2.  [First 5 results](#org338b606)
    7.  [Step 6](#orgca8ff14)
        1.  [Solution](#orgb24ef12)
        2.  [First 5 results](#orgc3c6c20)
    8.  [Step 7](#orgeb7c62d)
        1.  [Solution](#org8b2cfc4)
        2.  [First 5 results](#orgdf5441f)
    9.  [Step 7a](#org980fc9e)
        1.  [Solution](#org7a58133)
        2.  [First 5 results](#org4d2ccdb)
    10. [Step 7b](#orgf204614)
        1.  [Solution](#orgb536ad8)
        2.  [First 5 results](#org91089f0)
    11. [Step 8](#orgf9da811)
        1.  [Solution](#org4d950d1)
        2.  [First 5 results](#org012e64b)
    12. [Interim notes](#orgd8277fd)
    13. [Step 8a](#orgdf6dd57)
        1.  [Solution](#org2cbb86e)
        2.  [First 5 results](#org0c626de)
    14. [Step 9 &#x2013; Global Value Numbering](#org8474dff)
        1.  [Solution](#orga7fc0bc)
        2.  [First 5 results](#orgb436331)
    15. [Step 9a &#x2013; hashconsing](#orgc768b64)
        1.  [Solution](#org370d1e6)
        2.  [First 5 results](#orgced1d9e)


<a id="codeql-workshop--using-data-flow-and-range-analysis-to-find-out-of-bounds-accesses"></a>

# CodeQL Workshop &#x2014; Using Data-Flow and Range Analysis to Find Out-Of-Bounds Accesses


<a id="acknowledgments"></a>

# Acknowledgments

This session-based workshop is based on the exercise/unit-test-based material at
<https://github.com/kraiouchkine/codeql-workshop-runtime-values-c>, which in turn is
based on a significantly simplified and modified version of the
[OutOfBounds.qll library](https://github.com/github/codeql-coding-standards/blob/main/c/common/src/codingstandards/c/OutOfBounds.qll) from the
[CodeQL Coding Standards
repository](https://github.com/github/codeql-coding-standards). 


<a id="setup-instructions"></a>

# Setup Instructions

-   Install [Visual Studio Code](https://code.visualstudio.com/).

-   Install the
    [CodeQL extension for Visual Studio Code](https://codeql.github.com/docs/codeql-for-visual-studio-code/setting-up-codeql-in-visual-studio-code/).

-   Install the latest version of the
    [CodeQL CLI](https://github.com/github/codeql-cli-binaries/releases).

-   Clone this repository:
    
        git clone https://github.com/hohn/codeql-workshop-runtime-values-c

-   Install the CodeQL pack dependencies using the command
    `CodeQL: Install Pack Dependencies` and select `exercises`,
    `solutions`, `exercises-tests`, `session`, `session-db` and
    `solutions-tests` from the list of packs.

-   If you have CodeQL on your PATH, build the database using
    `build-database.sh` and load the database with the VS Code CodeQL
    extension. It is at `session-db/cpp-runtime-values-db`.
    -   Alternatively, you can download
        [this
        pre-built database](https://drive.google.com/file/d/1N8TYJ6f4E33e6wuyorWHZHVCHBZy8Bhb/view?usp=sharing).

-   If you do **not** have CodeQL on your PATH, build the database using the
    unit test sytem. Choose the `TESTING` tab in VS Code, run the
    `session-db/DB/db.qlref` test. The test will fail, but it leaves a
    usable CodeQL database in `session-db/DB/DB.testproj`.

-   ❗Important❗: Run `initialize-qltests.sh` to initialize the tests.
    Otherwise, you will not be able to run the QLTests in
    `exercises-tests`.


<a id="introduction"></a>

# Introduction

This workshop focuses on analyzing and relating two values &#x2014; array
access indices and memory allocation sizes &#x2014; in order to identify
simple cases of out-of-bounds array accesses.

The following snippets demonstrate how an out-of-bounds array access can
occur:

    char* buffer = malloc(10);
    buffer[9] = 'a'; // ok
    buffer[10] = 'b'; // out-of-bounds

A more complex example:

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

Another common case *not* covered in this introductory workshop involves
loops, as follows:

    int elements[5];
    for (int i = 0; i <= 5; ++i) {
        elements[i] = 0;
    }

To find these issues, we can implement an analysis that tracks the upper
or lower bounds on an expression and, combined with data-flow analysis
to reduce false-positives, identifies cases where the index of the array
results in an access beyond the allocated size of the buffer.


<a id="a-note-on-the-scope-of-this-workshop"></a>

# A Note on the Scope of This Workshop

This workshop is not intended to be a complete analysis that is useful
for real-world cases of out-of-bounds analyses for reasons including but
not limited to:

-   Missing support for loops and recursion
-   No interprocedural analysis
-   Missing size calculation of arrays where the element size is not 1
-   No support for pointer arithmetic or in general, operations other than
    addition and subtraction
-   Overly specific modelling of a buffer access as an array expression

The goal of this workshop is rather to demonstrate the building blocks
of analyzing run-time values and how to apply those building blocks to
modelling a common class of vulnerability. A more comprehensive and
production-appropriate example is the
[OutOfBounds.qll
library](https://github.com/github/codeql-coding-standards/blob/main/c/common/src/codingstandards/c/OutOfBounds.qll) from the
[CodeQL Coding
Standards repository](https://github.com/github/codeql-coding-standards).


<a id="org28d73fb"></a>

# A short note on the structure of directories and their use

`exercises-tests` are identical to `solution-tests`, the `exercises` directories
are a convenience for developing the queries on your own so you can use the unit
tests as reference.  This is for full consistency with the workshop material &#x2013;
the session &#x2013; but you may veer off and experiment on your own.

In that case, a simpler option is to follow the session writeup using a single
`.ql` file; the writeup has full queries and (at most) the first 5 results for
reference.


<a id="sessionworkshop-notes"></a>

# Session/Workshop notes

Unlike the the [exercises](../README.md#org3b74422) which use the *collection* of test problems in
`exercises-test`, this workshop is a sequential session following the actual
process of writing CodeQL: use a *single* database built from a single, larger
segment of code and inspect the query results as you write the query.  

For this workshop, the larger segment of code is still simplified skeleton code,
not a full source code repository.

The queries are embedded in \`session.md\` but can also be found in the
\`example\*.ql\` files.  They can all be run as test cases in VS Code.

To reiterate:

This workshop focuses on analyzing and relating two *static* values &#x2014; array
access indices and memory allocation sizes &#x2014; in order to identify
simple cases of out-of-bounds array accesses.  We do not handle *dynamic* values
but take advantage of special cases.

To find these issues,

1.  We can implement an analysis that tracks the upper or lower bounds on an
    expression.
2.  We then combine this with data-flow analysis to reduce false positives and
    identify cases where the index of the array results in an access beyond the
    allocated size of the buffer.
3.  We further extend these queries with rudimentary arithmetic support involving
    expressions common to the allocation and the array access.
4.  For cases where constant expressions are not available or are uncertain, we
    first try [range analysis](#org426ad70) to expand the query's applicability.
5.  For cases where this is insufficient, we introduce global value numbering
    [GVN](https://codeql.github.com/docs/codeql-language-guides/hash-consing-and-value-numbering) in [Step 9 &#x2013; Global Value Numbering](#org8474dff), to detect values known to be equal
    at runtime.
6.  When *those* cases are insufficient, we handle the case of identical
    structure using [BROKEN LINK: \*hashconsing].


<a id="exercise-1"></a>

## Step 1

In the first step we are going to

1.  identify a dynamic allocation with `malloc` and
2.  an access to that allocated buffer.   The access is via an array expression;
    we are **not** going to cover pointer dereferencing.

The goal of this exercise is to then output the array access, array size,
buffer, and buffer offset.

The focus here is on

    void test_const(void)

and

    void test_const_var(void)

in [db.c](file:///Users/hohn/local/codeql-workshop-runtime-values-c/session-db/DB/db.c).


<a id="hints"></a>

### Hints

1.  `Expr::getValue()::toInt()` can be used to get the integer value of a
    constant expression.


<a id="org4777775"></a>

### Solution

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


<a id="org1aa6a22"></a>

### First 5 results

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-right" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:8:5:8:10</td>
<td class="org-left">access to array</td>
<td class="org-right">0</td>
<td class="org-left">test.c:8:9:8:9</td>
<td class="org-right">0</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:9:5:9:11</td>
<td class="org-left">access to array</td>
<td class="org-right">99</td>
<td class="org-left">test.c:9:9:9:10</td>
<td class="org-right">99</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:10:5:10:12</td>
<td class="org-left">access to array</td>
<td class="org-right">100</td>
<td class="org-left">test.c:10:9:10:11</td>
<td class="org-right">100</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:17:5:17:10</td>
<td class="org-left">access to array</td>
<td class="org-right">0</td>
<td class="org-left">test.c:17:9:17:9</td>
<td class="org-right">0</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:18:5:18:11</td>
<td class="org-left">access to array</td>
<td class="org-right">99</td>
<td class="org-left">test.c:18:9:18:10</td>
<td class="org-right">99</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>
</tbody>
</table>


<a id="org1e52aa7"></a>

## Step 2

The previous query fails to connect the `malloc` calls with the array accesses,
and in the results, `mallocs` from one function are paired with accesses in
another.

To address these, take the query from the previous exercise and

1.  connect the allocation(s) with the
2.  array accesses


<a id="hints"></a>

### Hints

1.  Use `DataFlow::localExprFlow()` to relate the allocated buffer to the
    array base.
2.  The the array base is the `buf` part of `buf[0]`.  Use the 
    `Expr.getArrayBase()` predicate.


<a id="org4ba1960"></a>

### Solution

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
      // Ensure buffer access is to the correct allocation.
      // char *buf  = ... buf[0];
      //       ^^^  --->  ^^^
      // or
      // malloc(100);   buf[0]
      // ^^^  --------> ^^^
      //
      DataFlow::localExprFlow(buffer, access.getArrayBase())
    select buffer, access, accessIdx, access.getArrayOffset(), bufferSize, allocSizeExpr


<a id="org61872ef"></a>

### First 5 results

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-right" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:8:5:8:10</td>
<td class="org-left">access to array</td>
<td class="org-right">0</td>
<td class="org-left">test.c:8:9:8:9</td>
<td class="org-right">0</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:9:5:9:11</td>
<td class="org-left">access to array</td>
<td class="org-right">99</td>
<td class="org-left">test.c:9:9:9:10</td>
<td class="org-right">99</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:10:5:10:12</td>
<td class="org-left">access to array</td>
<td class="org-right">100</td>
<td class="org-left">test.c:10:9:10:11</td>
<td class="org-right">100</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>
</tbody>
</table>


<a id="exercise-2"></a>

## Step 3

The previous results need to be extended to the case

    void test_const_var(void)
    {
        unsigned long size = 100;
        char *buf = malloc(size);
        buf[0];        // COMPLIANT
        ...
    }

Here, the `malloc` argument is a variable with known value.  

We include this result by removing the size-retrieval from the prior query.


<a id="orgffef32c"></a>

### Solution

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
      // Ensure buffer access is to the correct allocation.
      // char *buf  = ... buf[0];
      //       ^^^  --->  ^^^
      // or
      // malloc(100);   buf[0]
      // ^^^  --------> ^^^
      //
      DataFlow::localExprFlow(buffer, access.getArrayBase())
    select buffer, access, accessIdx, access.getArrayOffset()


<a id="orga647c8f"></a>

### First 5 results

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-right" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:8:5:8:10</td>
<td class="org-left">access to array</td>
<td class="org-right">0</td>
<td class="org-left">test.c:8:9:8:9</td>
<td class="org-right">0</td>
</tr>


<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:9:5:9:11</td>
<td class="org-left">access to array</td>
<td class="org-right">99</td>
<td class="org-left">test.c:9:9:9:10</td>
<td class="org-right">99</td>
</tr>


<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:10:5:10:12</td>
<td class="org-left">access to array</td>
<td class="org-right">100</td>
<td class="org-left">test.c:10:9:10:11</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:17:5:17:10</td>
<td class="org-left">access to array</td>
<td class="org-right">0</td>
<td class="org-left">test.c:17:9:17:9</td>
<td class="org-right">0</td>
</tr>


<tr>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:18:5:18:11</td>
<td class="org-left">access to array</td>
<td class="org-right">99</td>
<td class="org-left">test.c:18:9:18:10</td>
<td class="org-right">99</td>
</tr>
</tbody>
</table>


<a id="orgd616664"></a>

## Step 4

We are looking for out-of-bounds accesses, so we to need to include the
bounds.  But in a more general way than looking only at constant values.

Note the results for the cases in `test_const_var` which involve a variable
access rather than a constant. The next goal is

1.  to handle the case where the allocation size or array index are variables
    (with constant values) rather than integer constants.

We have an expression `size` that flows into the `malloc()` call.


<a id="orga9ca0e1"></a>

### Hint


<a id="org072f835"></a>

### Solution

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
      // Ensure buffer access is to the correct allocation.
      // char *buf  = ... buf[0];
      //       ^^^  --->  ^^^
      // or
      // malloc(100);   buf[0]
      // ^^^  --------> ^^^
      //
      DataFlow::localExprFlow(buffer, access.getArrayBase())
    select buffer, access, accessIdx, access.getArrayOffset(), bufferSize, bse


<a id="orgab7f021"></a>

### First 5 results

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-right" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:8:5:8:10</td>
<td class="org-left">access to array</td>
<td class="org-right">0</td>
<td class="org-left">test.c:8:9:8:9</td>
<td class="org-right">0</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:9:5:9:11</td>
<td class="org-left">access to array</td>
<td class="org-right">99</td>
<td class="org-left">test.c:9:9:9:10</td>
<td class="org-right">99</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:10:5:10:12</td>
<td class="org-left">access to array</td>
<td class="org-right">100</td>
<td class="org-left">test.c:10:9:10:11</td>
<td class="org-right">100</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:17:5:17:10</td>
<td class="org-left">access to array</td>
<td class="org-right">0</td>
<td class="org-left">test.c:17:9:17:9</td>
<td class="org-right">0</td>
<td class="org-right">100</td>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:18:5:18:11</td>
<td class="org-left">access to array</td>
<td class="org-right">99</td>
<td class="org-left">test.c:18:9:18:10</td>
<td class="org-right">99</td>
<td class="org-right">100</td>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-right">100</td>
</tr>
</tbody>
</table>


<a id="org74d9df9"></a>

## Step 4a &#x2013; some clean-up using predicates

Note that the dataflow automatically captures/includes the

    allocSizeExpr = buffer.(Call).getArgument(0) 

so that's now redundant with `bufferSizeExpr` and can be removed. 

    
    allocSizeExpr = buffer.(Call).getArgument(0) and
    // bufferSize = allocSizeExpr.getValue().toInt() and
    //
    // unsigned long size = 100;
    // ...
    // char *buf = malloc(size);
    DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and

Also, simplify the `from...where...select`:

1.  Remove unnecessary `exists` clauses.
2.  Use `DataFlow::localExprFlow` for the buffer and allocation sizes, with
    `getValue().toInt()` as one possibility (one predicate).


<a id="orgd5a3519"></a>

### Solution

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
      // Ensure buffer access refers to the matching allocation
      // ensureSameFunction(buffer, access.getArrayBase()) and
      DataFlow::localExprFlow(buffer, access.getArrayBase()) and
      // Ensure buffer access refers to the matching allocation
      // ensureSameFunction(bufferSizeExpr, buffer.getSizeExpr()) and
      DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) 
      //
    select buffer, access, accessIdx, access.getArrayOffset(), bufferSize, bufferSizeExpr
    
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


<a id="orga608103"></a>

### First 5 results

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-right" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:8:5:8:10</td>
<td class="org-left">access to array</td>
<td class="org-right">0</td>
<td class="org-left">test.c:8:9:8:9</td>
<td class="org-right">0</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:9:5:9:11</td>
<td class="org-left">access to array</td>
<td class="org-right">99</td>
<td class="org-left">test.c:9:9:9:10</td>
<td class="org-right">99</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:10:5:10:12</td>
<td class="org-left">access to array</td>
<td class="org-right">100</td>
<td class="org-left">test.c:10:9:10:11</td>
<td class="org-right">100</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:17:5:17:10</td>
<td class="org-left">access to array</td>
<td class="org-right">0</td>
<td class="org-left">test.c:17:9:17:9</td>
<td class="org-right">0</td>
<td class="org-right">100</td>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-right">100</td>
</tr>


<tr>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:18:5:18:11</td>
<td class="org-left">access to array</td>
<td class="org-right">99</td>
<td class="org-left">test.c:18:9:18:10</td>
<td class="org-right">99</td>
<td class="org-right">100</td>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-right">100</td>
</tr>
</tbody>
</table>


<a id="org426ad70"></a>

## Step 5 &#x2013; SimpleRangeAnalysis

Running the query from Step 2 against the database yields a
significant number of missing or incorrect results. The reason is that
although great at identifying compile-time constants and their use,
data-flow analysis is not always the right tool for identifying the
*range* of values an `Expr` might have, particularly when multiple
potential constants might flow to an `Expr`.

The range analysis already handles conditional branches; we don't
have to use guards on data flow &#x2013; don't implement your own interpreter
if you can use the library.

The CodeQL standard library has several mechanisms for addressing this
problem; in the remainder of this workshop we will explore two of them:
`SimpleRangeAnalysis` and, later, `GlobalValueNumbering`.

Although not in the scope of this workshop, a standard use-case for
range analysis is reliably identifying integer overflow and validating
integer overflow checks.

Now, add the use of the `SimpleRangeAnalysis` library.  Specifically, the
relevant library predicates are `upperBound` and `lowerBound`, to be used with
the buffer access argument.

Notes:

-   This requires the import
    
        import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis
-   We are not limiting the array access to integers any longer.  Thus, we just
    use 
    
        accessIdx = access.getArrayOffset()
-   To see the results in the order used in the C code, use
    
        select bufferSizeExpr, buffer, access, accessIdx, upperBound(accessIdx) as accessMax


<a id="org7c6288c"></a>

### Solution

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
      // Ensure buffer access is to the correct allocation.
      DataFlow::localExprFlow(buffer, access.getArrayBase()) and
      // Ensure use refers to the correct size defintion, even for non-constant
      // expressions.  
      DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr())
      //
    select bufferSizeExpr, buffer, access, accessIdx, upperBound(accessIdx) as accessMax
    
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


<a id="org338b606"></a>

### First 5 results

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-right" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:8:5:8:10</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:8:9:8:9</td>
<td class="org-right">0</td>
<td class="org-right">0.0</td>
</tr>


<tr>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:9:5:9:11</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:9:9:9:10</td>
<td class="org-right">99</td>
<td class="org-right">99.0</td>
</tr>


<tr>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:10:5:10:12</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:10:9:10:11</td>
<td class="org-right">100</td>
<td class="org-right">100.0</td>
</tr>


<tr>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-right">100</td>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:17:5:17:10</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:17:9:17:9</td>
<td class="org-right">0</td>
<td class="org-right">0.0</td>
</tr>


<tr>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-right">100</td>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:18:5:18:11</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:18:9:18:10</td>
<td class="org-right">99</td>
<td class="org-right">99.0</td>
</tr>
</tbody>
</table>


<a id="orgca8ff14"></a>

## Step 6

To finally determine (some) out-of-bounds accesses, we have to convert
allocation units (usually in bytes) to size units.  Then we are finally in a
position to compare buffer allocation size to the access index to find
out-of-bounds accesses &#x2013; at least for expressions with known values.

Add these to the query:

1.  Convert allocation units to size units.
2.  Convert access units to the same size units.

Hints:

1.  We need the size of the array element.  Use
    `access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType()`
    to see the type and 
    `access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize()`
    to get its size.

2.  Note from the docs:
    *The malloc() function allocates size bytes of memory and returns a pointer
    to the allocated memory.* 
    So `size = 1`

3.  These test cases all use type `char`.  What would happen for `int` or
    `double`?


<a id="orgb24ef12"></a>

### Solution

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
      // Ensure buffer access is to the correct allocation.
      DataFlow::localExprFlow(buffer, access.getArrayBase()) and
      // Ensure use refers to the correct size defintion, even for non-constant
      // expressions.  
      DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr())
      //
    select bufferSizeExpr, buffer, access, accessIdx, upperBound(accessIdx) as accessMax, bufferSize,
      access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType() as arrayBaseType,
      access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() as arrayTypeSize,
      1 as allocBaseSize
    
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


<a id="orgc3c6c20"></a>

### First 5 results

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-right" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:8:5:8:10</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:8:9:8:9</td>
<td class="org-right">0</td>
<td class="org-right">0.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:9:5:9:11</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:9:9:9:10</td>
<td class="org-right">99</td>
<td class="org-right">99.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:10:5:10:12</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:10:9:10:11</td>
<td class="org-right">100</td>
<td class="org-right">100.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-right">100</td>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:17:5:17:10</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:17:9:17:9</td>
<td class="org-right">0</td>
<td class="org-right">0.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-right">100</td>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:18:5:18:11</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:18:9:18:10</td>
<td class="org-right">99</td>
<td class="org-right">99.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>
</tbody>
</table>


<a id="orgeb7c62d"></a>

## Step 7

1.  Clean up the query.
2.  Compare buffer allocation size to the access index.
3.  Add expressions for `allocatedUnits` (from the malloc) and a
    `maxAccessedIndex` (from array accesses)
    1.  Calculate the `accessOffset` / `maxAccessedIndex` (from array accesses)
    2.  Calculate the `allocSize` / `allocatedUnits` (from the malloc)
    3.  Compare them


<a id="org8b2cfc4"></a>

### Solution

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
      // Ensure buffer access is to the correct allocation.
      DataFlow::localExprFlow(buffer, access.getArrayBase()) and 
      // Ensure use refers to the correct size defintion, even for non-constant
      // expressions.  
      DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and 
      //
      arrayTypeSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() and
      1 = allocBaseSize
    //
    select bufferSizeExpr, buffer, access, accessIdx, upperBound(accessIdx) as accessMax, bufferSize,
      access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType() as arrayBaseType,
      allocBaseSize * bufferSize as allocatedUnits, arrayTypeSize * accessMax as maxAccessedIndex
    
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


<a id="orgdf5441f"></a>

### First 5 results

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-right" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:8:5:8:10</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:8:9:8:9</td>
<td class="org-right">0</td>
<td class="org-right">0.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">100</td>
<td class="org-right">0.0</td>
</tr>


<tr>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:9:5:9:11</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:9:9:9:10</td>
<td class="org-right">99</td>
<td class="org-right">99.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">100</td>
<td class="org-right">99.0</td>
</tr>


<tr>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:10:5:10:12</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:10:9:10:11</td>
<td class="org-right">100</td>
<td class="org-right">100.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">100</td>
<td class="org-right">100.0</td>
</tr>


<tr>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-right">100</td>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:17:5:17:10</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:17:9:17:9</td>
<td class="org-right">0</td>
<td class="org-right">0.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">100</td>
<td class="org-right">0.0</td>
</tr>


<tr>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-right">100</td>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:18:5:18:11</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:18:9:18:10</td>
<td class="org-right">99</td>
<td class="org-right">99.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">100</td>
<td class="org-right">99.0</td>
</tr>
</tbody>
</table>


<a id="org980fc9e"></a>

## Step 7a

1.  Account for base sizes &#x2013; `char` in this case.
2.  Put all expressions into the select for review.


<a id="org7a58133"></a>

### Solution

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
      // Ensure buffer access is to the correct allocation.
      DataFlow::localExprFlow(buffer, access.getArrayBase()) and
      // Ensure use refers to the correct size defintion, even for non-constant
      // expressions.  
      DataFlow::localExprFlow(bufferSizeExpr, buffer.getSizeExpr()) and
      //
      arrayTypeSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize() and
      1 = allocBaseSize
    //
    select bufferSizeExpr, buffer, access, accessIdx, upperBound(accessIdx) as accessMax, bufferSize,
      access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType() as arrayBaseType,
      buffer.getSizeMult() as bufferBaseTypeSize,
      arrayBaseType.getSize() as arrayBaseTypeSize,
      allocBaseSize * bufferSize as allocatedUnits, arrayTypeSize * accessMax as maxAccessedIndex
    
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


<a id="org4d2ccdb"></a>

### First 5 results

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-right" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:8:5:8:10</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:8:9:8:9</td>
<td class="org-right">0</td>
<td class="org-right">0.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">100</td>
<td class="org-right">0.0</td>
</tr>


<tr>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:9:5:9:11</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:9:9:9:10</td>
<td class="org-right">99</td>
<td class="org-right">99.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">100</td>
<td class="org-right">99.0</td>
</tr>


<tr>
<td class="org-left">test.c:7:24:7:26</td>
<td class="org-right">100</td>
<td class="org-left">test.c:7:17:7:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:10:5:10:12</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:10:9:10:11</td>
<td class="org-right">100</td>
<td class="org-right">100.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">100</td>
<td class="org-right">100.0</td>
</tr>


<tr>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-right">100</td>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:17:5:17:10</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:17:9:17:9</td>
<td class="org-right">0</td>
<td class="org-right">0.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">100</td>
<td class="org-right">0.0</td>
</tr>


<tr>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-right">100</td>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:18:5:18:11</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:18:9:18:10</td>
<td class="org-right">99</td>
<td class="org-right">99.0</td>
<td class="org-right">100</td>
<td class="org-left"><a href="file://:0:0:0:0">file://:0:0:0:0</a></td>
<td class="org-left">char</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">100</td>
<td class="org-right">99.0</td>
</tr>
</tbody>
</table>


<a id="orgf204614"></a>

## Step 7b

1.  Introduce more general predicates.
2.  Compare buffer allocation size to the access index.
3.  Report only the questionable entries.


<a id="orgb536ad8"></a>

### Solution

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


<a id="org91089f0"></a>

### First 5 results

WARNING: Unused predicate computeIndices (/Users/hohn/local/codeql-workshop-runtime-values-c/session/example7b.ql:66,11-25)

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:10:5:10:12</td>
<td class="org-left">access to array</td>
<td class="org-left">Array access at or beyond size; have 100 units, access at 100</td>
</tr>


<tr>
<td class="org-left">test.c:20:5:20:12</td>
<td class="org-left">access to array</td>
<td class="org-left">Array access at or beyond size; have 100 units, access at 100</td>
</tr>


<tr>
<td class="org-left">test.c:21:5:21:13</td>
<td class="org-left">access to array</td>
<td class="org-left">Array access at or beyond size; have 100 units, access at 100</td>
</tr>


<tr>
<td class="org-left">test.c:37:5:37:17</td>
<td class="org-left">access to array</td>
<td class="org-left">Array access at or beyond size; have 100 units, access at 299</td>
</tr>
</tbody>
</table>


<a id="orgf9da811"></a>

## Step 8

Up to now, we have dealt with constant values

    char *buf = malloc(100);
    buf[0];   // COMPLIANT

or

    unsigned long size = 100;
    char *buf = malloc(size);
    buf[0];        // COMPLIANT

and statically determinable or boundable values

    char *buf = malloc(size);
    if (size < 199)
        {
            buf[size];     // COMPLIANT
            // ...
        }

There is another statically determinable case.  Examples are

1.  A simple expression
    
        char *buf = malloc(alloc_size);
        // ...
        buf[alloc_size - 1]; // COMPLIANT
        buf[alloc_size];     // NON_COMPLIANT
2.  A complex expression
    
        char *buf = malloc(sz * x * y);
        buf[sz * x * y - 1]; // COMPLIANT

These both have the form `malloc(e)`, `buf[e+c]`, where `e` is an `Expr` and
`c` is a constant, possibly 0.  Our existing queries only report known or
boundable results, but here `e` is neither.

Write a new query, re-using or modifying the existing one to handle the simple
expression (case 1).

Note:

-   We are looking at the allocation expression again, not its possible value.
-   This only handles very specific cases.  Constructing counterexamples is easy.
-   We will address this in the next section.


<a id="org4d950d1"></a>

### Solution

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


<a id="org012e64b"></a>

### First 5 results

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:16:24:16:27</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:19:5:19:17</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:19:9:19:12</td>
<td class="org-left">size</td>
<td class="org-right">-1</td>
<td class="org-left">test.c:15:19:15:22</td>
<td class="org-left">size</td>
<td class="org-left">test.c:15:19:15:22</td>
<td class="org-left">size</td>
</tr>


<tr>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:16:24:16:27</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:21:5:21:13</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:21:9:21:12</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:15:19:15:22</td>
<td class="org-left">size</td>
<td class="org-left">test.c:15:19:15:22</td>
<td class="org-left">size</td>
</tr>


<tr>
<td class="org-left">test.c:28:17:28:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:28:24:28:27</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:37:5:37:17</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:37:9:37:12</td>
<td class="org-left">size</td>
<td class="org-right">-1</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
</tr>


<tr>
<td class="org-left">test.c:28:17:28:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:28:24:28:27</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:39:5:39:13</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:39:9:39:12</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
</tr>


<tr>
<td class="org-left">test.c:28:17:28:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:28:24:28:27</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:43:9:43:17</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:43:13:43:16</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
</tr>
</tbody>
</table>


<a id="orgd8277fd"></a>

## Interim notes

A common issue with the `SimpleRangeAnalysis` library is handling of
cases where the bounds are undeterminable at compile-time on one or more
paths. For example, even though certain paths have clearly defined
bounds, the range analysis library will define the `upperBound` and
`lowerBound` of `val` as `INT_MIN` and `INT_MAX` respectively:

    int val = rand() ? rand() : 30;

A similar case is present in the `test_const_branch` and `test_const_branch2`
test-cases.  In these cases, it is necessary to augment range analysis with
data-flow and restrict the bounds to the upper or lower bound of computable
constants that flow to a given expression.  Another approach is global value
numbering, used next.


<a id="orgdf6dd57"></a>

## Step 8a

Find problematic accesses by reverting to some *simple* `var+const` checks using
`accessOffset` and `bufferOffset`.

Note:

-   These will flag some false positives.
-   The product expression `sz * x * y` is not easily checked for equality.

These are addressed in the next step.


<a id="org2cbb86e"></a>

### Solution

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
      // Find allocation size expression flowing to buffer.
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
      bufInit = accessInit and
      // +++
      // Identify questionable differences
      accessOffset >= bufferOffset
    select buffer, bufferBase, access, accessBase, bufInit, bufferOffset, accessInit, accessOffset
    
    /**
     * Extract base and offset from y = base+offset and y = base-offset.  For others, get y and 0.
     *
     * For cases like
     *     buf[alloc_size + 1];
     *         ^^^^^^^^^^^^^^ expr
     *         ^^^^^^^^^^ base
     *                    ^^^ offset
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


<a id="org0c626de"></a>

### First 5 results

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:16:17:16:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:16:24:16:27</td>
<td class="org-left">size</td>
<td class="org-left">test.c:21:5:21:13</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:21:9:21:12</td>
<td class="org-left">size</td>
<td class="org-left">test.c:15:19:15:22</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:15:19:15:22</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
</tr>


<tr>
<td class="org-left">test.c:28:17:28:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:28:24:28:27</td>
<td class="org-left">size</td>
<td class="org-left">test.c:39:5:39:13</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:39:9:39:12</td>
<td class="org-left">size</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
</tr>


<tr>
<td class="org-left">test.c:28:17:28:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:28:24:28:27</td>
<td class="org-left">size</td>
<td class="org-left">test.c:43:9:43:17</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:43:13:43:16</td>
<td class="org-left">size</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
</tr>


<tr>
<td class="org-left">test.c:28:17:28:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:28:24:28:27</td>
<td class="org-left">size</td>
<td class="org-left">test.c:44:9:44:21</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:44:13:44:16</td>
<td class="org-left">size</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">test.c:28:17:28:22</td>
<td class="org-left">call to malloc</td>
<td class="org-left">test.c:28:24:28:27</td>
<td class="org-left">size</td>
<td class="org-left">test.c:45:9:45:21</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:45:13:45:16</td>
<td class="org-left">size</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
<td class="org-left">test.c:26:19:26:22</td>
<td class="org-left">size</td>
<td class="org-right">2</td>
</tr>
</tbody>
</table>


<a id="org8474dff"></a>

## Step 9 &#x2013; Global Value Numbering

Range analyis won't bound `sz * x * y`, and simple equality checks don't work
at the structure level, so switch to global value numbering.

This is the case in the last test case, 

    void test_gvn_var(unsigned long x, unsigned long y, unsigned long sz)
    {
        char *buf = malloc(sz * x * y);
        buf[sz * x * y - 1]; // COMPLIANT
        buf[sz * x * y];     // NON_COMPLIANT
        buf[sz * x * y + 1]; // NON_COMPLIANT
    }

Global value numbering only knows that runtime values are equal; they
are not comparable (`<, >, <=` etc.), and the *actual* value is not
known.

Global value numbering finds expressions with the same known value,
independent of structure.

So, we look for and use *relative* values between allocation and use. 

The relevant CodeQL constructs are

    import semmle.code.cpp.valuenumbering.GlobalValueNumbering
    ...
    globalValueNumber(e) = globalValueNumber(sizeExpr) and
    e != sizeExpr
    ...

We can use global value numbering to identify common values as first step, but
for expressions like

    buf[sz * x * y - 1]; // COMPLIANT

we have to "evaluate" the expressions &#x2013; or at least bound them.


<a id="orga7fc0bc"></a>

### Solution

    import cpp
    import semmle.code.cpp.dataflow.DataFlow
    import semmle.code.cpp.valuenumbering.GlobalValueNumbering
    
    from
      AllocationExpr buffer, ArrayExpr access,
      // ---
      // Expr bufferSizeExpr
      // int accessOffset, Expr accessBase, Expr bufferBase, int bufferOffset, Variable bufInit,
      // +++
      Expr allocSizeExpr, Expr accessIdx, GVN gvnAccessIdx, GVN gvnAllocSizeExpr, int accessOffset
    where
      // malloc (100)
      // ^^^^^^^^^^^^ AllocationExpr buffer
      // buf[...]
      // ^^^  ArrayExpr access
      // buf[...]
      //     ^^^ accessIdx
      accessIdx = access.getArrayOffset() and
      // Find allocation size expression flowing to the allocation.
      DataFlow::localExprFlow(allocSizeExpr, buffer.getSizeExpr()) and
      // Ensure buffer access refers to the matching allocation
      DataFlow::localExprFlow(buffer, access.getArrayBase()) and
      // Use GVN
      globalValueNumber(accessIdx) = gvnAccessIdx and
      globalValueNumber(allocSizeExpr) = gvnAllocSizeExpr and
      (
        // buf[size] or buf[100]
        gvnAccessIdx = gvnAllocSizeExpr and
        accessOffset = 0
        or
        // buf[sz * x * y + 1];
        exists(AddExpr add |
          accessIdx = add and
          accessOffset >= 0 and
          accessOffset = add.getRightOperand().(Literal).getValue().toInt() and
          globalValueNumber(add.getLeftOperand()) = gvnAllocSizeExpr
        )
      )
    select access, gvnAllocSizeExpr, allocSizeExpr, buffer.getSizeExpr() as allocArg, gvnAccessIdx,
      accessIdx, accessOffset


<a id="orgb436331"></a>

### First 5 results

Results note:

-   The allocation size of 200 is never used in an access, so the GVN match
    eliminates it from the result list.
    
    <table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">
    
    
    <colgroup>
    <col  class="org-left" />
    
    <col  class="org-left" />
    
    <col  class="org-left" />
    
    <col  class="org-left" />
    
    <col  class="org-left" />
    
    <col  class="org-left" />
    
    <col  class="org-left" />
    
    <col  class="org-left" />
    
    <col  class="org-left" />
    
    <col  class="org-left" />
    
    <col  class="org-left" />
    
    <col  class="org-left" />
    
    <col  class="org-right" />
    </colgroup>
    <tbody>
    <tr>
    <td class="org-left">test.c:21:5:21:13</td>
    <td class="org-left">access to array</td>
    <td class="org-left">test.c:15:26:15:28</td>
    <td class="org-left">GVN</td>
    <td class="org-left">test.c:15:26:15:28</td>
    <td class="org-left">100</td>
    <td class="org-left">test.c:16:24:16:27</td>
    <td class="org-left">size</td>
    <td class="org-left">test.c:15:26:15:28</td>
    <td class="org-left">GVN</td>
    <td class="org-left">test.c:21:9:21:12</td>
    <td class="org-left">size</td>
    <td class="org-right">0</td>
    </tr>
    
    
    <tr>
    <td class="org-left">test.c:21:5:21:13</td>
    <td class="org-left">access to array</td>
    <td class="org-left">test.c:15:26:15:28</td>
    <td class="org-left">GVN</td>
    <td class="org-left">test.c:16:24:16:27</td>
    <td class="org-left">size</td>
    <td class="org-left">test.c:16:24:16:27</td>
    <td class="org-left">size</td>
    <td class="org-left">test.c:15:26:15:28</td>
    <td class="org-left">GVN</td>
    <td class="org-left">test.c:21:9:21:12</td>
    <td class="org-left">size</td>
    <td class="org-right">0</td>
    </tr>
    
    
    <tr>
    <td class="org-left">test.c:38:5:38:12</td>
    <td class="org-left">access to array</td>
    <td class="org-left">test.c:26:39:26:41</td>
    <td class="org-left">GVN</td>
    <td class="org-left">test.c:26:39:26:41</td>
    <td class="org-left">100</td>
    <td class="org-left">test.c:28:24:28:27</td>
    <td class="org-left">size</td>
    <td class="org-left">test.c:26:39:26:41</td>
    <td class="org-left">GVN</td>
    <td class="org-left">test.c:38:9:38:11</td>
    <td class="org-left">100</td>
    <td class="org-right">0</td>
    </tr>
    
    
    <tr>
    <td class="org-left">test.c:69:5:69:19</td>
    <td class="org-left">access to array</td>
    <td class="org-left">test.c:63:24:63:33</td>
    <td class="org-left">GVN</td>
    <td class="org-left">test.c:63:24:63:33</td>
    <td class="org-left">alloc<sub>size</sub></td>
    <td class="org-left">test.c:63:24:63:33</td>
    <td class="org-left">alloc<sub>size</sub></td>
    <td class="org-left">test.c:63:24:63:33</td>
    <td class="org-left">GVN</td>
    <td class="org-left">test.c:69:9:69:18</td>
    <td class="org-left">alloc<sub>size</sub></td>
    <td class="org-right">0</td>
    </tr>
    
    
    <tr>
    <td class="org-left">test.c:73:9:73:23</td>
    <td class="org-left">access to array</td>
    <td class="org-left">test.c:63:24:63:33</td>
    <td class="org-left">GVN</td>
    <td class="org-left">test.c:63:24:63:33</td>
    <td class="org-left">alloc<sub>size</sub></td>
    <td class="org-left">test.c:63:24:63:33</td>
    <td class="org-left">alloc<sub>size</sub></td>
    <td class="org-left">test.c:63:24:63:33</td>
    <td class="org-left">GVN</td>
    <td class="org-left">test.c:73:13:73:22</td>
    <td class="org-left">alloc<sub>size</sub></td>
    <td class="org-right">0</td>
    </tr>
    </tbody>
    </table>


<a id="orgc768b64"></a>

## Step 9a &#x2013; hashconsing

For the cases with variable `malloc` sizes, like `test_const_branch`, GVN
identifies same-value constant accesses, but we need a special case for
same-structure expression accesses.  Enter `hashCons`.

From the reference:
<https://codeql.github.com/docs/codeql-language-guides/hash-consing-and-value-numbering/> 

> The hash consing library (defined in semmle.code.cpp.valuenumbering.HashCons)
> provides a mechanism for identifying expressions that have the same syntactic
> structure.

Additions to the imports, and use:

    import semmle.code.cpp.valuenumbering.HashCons
        ...
    hashCons(expr)

This step illustrates some subtle meanings of equality.  In particular, there
is plain `=`, GVN, and `hashCons`:

    // 0 results:
    // (accessBase = allocSizeExpr or accessBase = allocArg)
    
    // Only 6 results:
    
    // (
    //   gvnAccessIdx = gvnAllocSizeExpr or
    //   gvnAccessIdx = globalValueNumber(allocArg)
    // )
    
    // 9 results:
    (
      hashCons(accessBase) = hashCons(allocSizeExpr) or
      hashCons(accessBase) = hashCons(allocArg)
    )


<a id="org370d1e6"></a>

### Solution

    import cpp
    import semmle.code.cpp.dataflow.DataFlow
    import semmle.code.cpp.valuenumbering.GlobalValueNumbering
    import semmle.code.cpp.valuenumbering.HashCons
    
    from
      AllocationExpr buffer, ArrayExpr access, Expr allocSizeExpr, Expr accessIdx, GVN gvnAccessIdx,
      GVN gvnAllocSizeExpr, int accessOffset,
      // +++
      Expr allocArg, Expr accessBase
    where
      // malloc (100)
      // ^^^^^^^^^^^^ AllocationExpr buffer
      // buf[...]
      // ^^^  ArrayExpr access
      // buf[...]
      //     ^^^ accessIdx
      accessIdx = access.getArrayOffset() and
      // Find allocation size expression flowing to the allocation.
      DataFlow::localExprFlow(allocSizeExpr, buffer.getSizeExpr()) and
      // Ensure buffer access refers to the matching allocation
      DataFlow::localExprFlow(buffer, access.getArrayBase()) and
      // Use GVN
      globalValueNumber(accessIdx) = gvnAccessIdx and
      globalValueNumber(allocSizeExpr) = gvnAllocSizeExpr and
      (
        // buf[size] or buf[100]
        gvnAccessIdx = gvnAllocSizeExpr and
        accessOffset = 0 and
        // +++
        accessBase = accessIdx
        or
        // buf[sz * x * y + 1];
        exists(AddExpr add |
          accessIdx = add and
          accessOffset >= 0 and
          accessOffset = add.getRightOperand().(Literal).getValue().toInt() and
          globalValueNumber(add.getLeftOperand()) = gvnAllocSizeExpr and
          // +++
          accessBase = add.getLeftOperand()
        )
      ) and
      buffer.getSizeExpr() = allocArg and
      (
        accessOffset >= 0 and
        // +++
        // Illustrating the subtle meanings of equality:    
        // 0 results:
        // (accessBase = allocSizeExpr or accessBase = allocArg)
        // Only 6 results:
        // (
        //   gvnAccessIdx = gvnAllocSizeExpr or
        //   gvnAccessIdx = globalValueNumber(allocArg)
        // )
        // 9 results:
        (
          hashCons(accessBase) = hashCons(allocSizeExpr) or
          hashCons(accessBase) = hashCons(allocArg)
        )
      )
    // gvnAccessIdx = globalValueNumber(allocArg))
    // +++ overview select:
    select access, gvnAllocSizeExpr, allocSizeExpr, allocArg, gvnAccessIdx, accessIdx, accessBase,
      accessOffset


<a id="orgced1d9e"></a>

### First 5 results

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />
</colgroup>
<tbody>
<tr>
<td class="org-left">test.c:21:5:21:13</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-left">GVN</td>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-left">100</td>
<td class="org-left">test.c:16:24:16:27</td>
<td class="org-left">size</td>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-left">GVN</td>
<td class="org-left">test.c:21:9:21:12</td>
<td class="org-left">size</td>
<td class="org-left">test.c:21:9:21:12</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
</tr>


<tr>
<td class="org-left">test.c:21:5:21:13</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-left">GVN</td>
<td class="org-left">test.c:16:24:16:27</td>
<td class="org-left">size</td>
<td class="org-left">test.c:16:24:16:27</td>
<td class="org-left">size</td>
<td class="org-left">test.c:15:26:15:28</td>
<td class="org-left">GVN</td>
<td class="org-left">test.c:21:9:21:12</td>
<td class="org-left">size</td>
<td class="org-left">test.c:21:9:21:12</td>
<td class="org-left">size</td>
<td class="org-right">0</td>
</tr>


<tr>
<td class="org-left">test.c:38:5:38:12</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:26:39:26:41</td>
<td class="org-left">GVN</td>
<td class="org-left">test.c:26:39:26:41</td>
<td class="org-left">100</td>
<td class="org-left">test.c:28:24:28:27</td>
<td class="org-left">size</td>
<td class="org-left">test.c:26:39:26:41</td>
<td class="org-left">GVN</td>
<td class="org-left">test.c:38:9:38:11</td>
<td class="org-left">100</td>
<td class="org-left">test.c:38:9:38:11</td>
<td class="org-left">100</td>
<td class="org-right">0</td>
</tr>


<tr>
<td class="org-left">test.c:69:5:69:19</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:63:24:63:33</td>
<td class="org-left">GVN</td>
<td class="org-left">test.c:63:24:63:33</td>
<td class="org-left">alloc<sub>size</sub></td>
<td class="org-left">test.c:63:24:63:33</td>
<td class="org-left">alloc<sub>size</sub></td>
<td class="org-left">test.c:63:24:63:33</td>
<td class="org-left">GVN</td>
<td class="org-left">test.c:69:9:69:18</td>
<td class="org-left">alloc<sub>size</sub></td>
<td class="org-left">test.c:69:9:69:18</td>
<td class="org-left">alloc<sub>size</sub></td>
<td class="org-right">0</td>
</tr>


<tr>
<td class="org-left">test.c:73:9:73:23</td>
<td class="org-left">access to array</td>
<td class="org-left">test.c:63:24:63:33</td>
<td class="org-left">GVN</td>
<td class="org-left">test.c:63:24:63:33</td>
<td class="org-left">alloc<sub>size</sub></td>
<td class="org-left">test.c:63:24:63:33</td>
<td class="org-left">alloc<sub>size</sub></td>
<td class="org-left">test.c:63:24:63:33</td>
<td class="org-left">GVN</td>
<td class="org-left">test.c:73:13:73:22</td>
<td class="org-left">alloc<sub>size</sub></td>
<td class="org-left">test.c:73:13:73:22</td>
<td class="org-left">alloc<sub>size</sub></td>
<td class="org-right">0</td>
</tr>
</tbody>
</table>

