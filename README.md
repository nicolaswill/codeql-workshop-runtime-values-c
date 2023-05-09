# CodeQL Workshop — Using Data-Flow and Range Analysis to Find Out-Of-Bounds Accesses

## Acknowledgements
This workshop is based on a significantly simplified and modified version of the [OutOfBounds.qll library](https://github.com/github/codeql-coding-standards/blob/main/c/common/src/codingstandards/c/OutOfBounds.qll) from the [CodeQL Coding Standards repository](https://github.com/github/codeql-coding-standards).

## Setup Instructions
- Install [Visual Studio Code](https://code.visualstudio.com/).

- Install the [CodeQL extension for Visual Studio Code](https://codeql.github.com/docs/codeql-for-visual-studio-code/setting-up-codeql-in-visual-studio-code/).

- Install the latest version of the [CodeQL CLI](https://github.com/github/codeql-cli-binaries/releases).

- Clone this repository:
  ```bash
  git clone https://github.com/kraiouchkine/codeql-workshop-runtime-values-c
  ```

- Install the CodeQL pack dependencies using the command `CodeQL: Install Pack
  Dependencies` and select `exercises`, `solutions`, `exercises-tests`, `session`,
  `session-db` and `solutions-tests` from the list of packs.

- If you have CodeQL on your PATH, build the database using `build-database.sh`
  and load the database with the VS Code CodeQL extension.  It is at
  `session-db/cpp-runtime-values-db`.
  - Alternatively, you can download [this pre-built database](https://drive.google.com/file/d/1N8TYJ6f4E33e6wuyorWHZHVCHBZy8Bhb/view?usp=sharing).

- If you do **not** have CodeQL on your PATH, build the database using the unit
  test sytem.  Choose the `TESTING` tab in VS Code, run the
  `session-db/DB/db.qlref` test.  The test will fail, but it leaves a usable CodeQL
  database in `session-db/DB/DB.testproj`.  

- :exclamation:Important:exclamation:: Run `initialize-qltests.sh` to initialize the tests. Otherwise, you will not be able to run the QLTests in `exercises-tests`.

## Introduction
This workshop focuses on analyzing and relating two values — array access indices and memory allocation sizes — in order to identify simple cases of out-of-bounds array accesses.

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

## A Note on the Scope of This Workshop
This workshop is not intended to be a complete analysis that is useful for real-world cases of out-of-bounds analyses for reasons including but not limited to:
- Missing support for loops and recursion
- No interprocedural analysis
- Missing size calculation of arrays where the element size is not 1
- No support for pointer arithmetic or in general, operations other than addition and subtraction
- Overly specific modelling of a buffer access as an array expression

The goal of this workshop is rather to demonstrate the building blocks of analyzing run-time values and how to apply those building blocks to modelling a common class of vulnerability. A more comprehensive and production-appropriate example is the [OutOfBounds.qll library](https://github.com/github/codeql-coding-standards/blob/main/c/common/src/codingstandards/c/OutOfBounds.qll) from the [CodeQL Coding Standards repository](https://github.com/github/codeql-coding-standards).

## Session/Workshop notes
Unlike the the [exercises](#org3b74422) which use the *collection* of test
problems in `exercises-test`, a workshop follows `session/session.ql` and uses a
*single* database built from a single, larger segment of code.

<a id="org3b74422"></a>
## Exercises 
These exercises use the collection of test problems in `exercises-test`.

### Exercise 1
In the first exercise we are going to start by modelling a dynamic allocation with `malloc` and an access to that allocated buffer with an array expression. The goal of this exercise is to then output the array access, buffer, array size, and buffer offset.

The [first test-case](solutions-tests/Exercise1/test.c) is a simple one, as both the allocation size and array offsets are constants.

For this exercise, connect the allocation(s), the array accesses, and the sizes in each.

Run the query and ensure that you have three results.

#### Hints
1. `Expr::getValue()::toInt()` can be used to get the integer value of a constant expression.
2. Use `DataFlow::localExprFlow()` to relate the allocated buffer to the array base.

### Exercise 2
This exercise uses the same C source code with an addition: a constant array size
propagated [via a variable](solutions-tests/Exercise2/test.c).

Hints:
1. start with plain `from...where...select` query.
2. use
   `elementSize = access.getArrayBase().getUnspecifiedType().(PointerType).getBaseType().getSize()`
2. convert your query to predicate or use classes as outlined below, if desired.

#### Task 1
With the basic elements of the analysis in place, refactor the query into two classes: `AllocationCall` and `ArrayAccess`. The `AllocationCall` class should model a call to `malloc` and the `ArrayAccess` class should model an array access expression (`ArrayExpr`).

#### Task 2
Next, note the missing results for the cases in `test_const_var` which involve a variable access rather than a constant. The goal of this task is to implement the `getSourceConstantExpr`, `getFixedSize`, and `getFixedArrayOffset` predicates to handle the case where the allocation size or array index are variables rather than integer constants.

Use local data-flow analysis to complete the `getSourceConstantExpr` predicate. The `getFixedSize` and `getFixedArrayOffset` predicates can be completed using `getSourceConstantExpr`.


### Exercise 3
This exercise has slightly more C source code [here](solutions-tests/Exercise3/test.c).

Note: the `test_const_branch` has `buf[100]` with size == 100

Running the query from Exercise 2 against the database yields a significant number of missing or incorrect results. The reason is that although great at identifying compile-time constants and their use, data-flow analysis is not always the right tool for identifying the *range* of values an `Expr` might have, particularly when multiple potential constants might flow to an `Expr`.

The CodeQL standard library several mechanisms for addressing this problem; in the remainder of this workshop we will explore two of them: `SimpleRangeAnalysis` and, later, `GlobalValueNumbering`.

Although not in the scope of this workshop, a standard use-case for range analysis is reliably identifying integer overflow and validating integer overflow checks.

#### Task 1
Change the implementation of the `getFixedSize` and `getFixedArrayOffset` predicates to use the `SimpleRangeAnalysis` library rather than data-flow. Specifically, the relevant predicates are `upperBound` and `lowerBound`. Decide which to use for this exercise (`upperBound`, `lowerBound`, or both).

Experiment with different combinations of the `upperBound` and `lowerBound` predicates to see how they impact the results.

Hint:    
Use `upperBound` for both predicates.

#### Task 2
Implement the `isOffsetOutOfBoundsConstant` predicate to check if the array offset is out-of-bounds. A template has been provided for you. For the purpose of this workshop, you may omit handling of negative indices as none exist in this workshop's test-cases. In a real-world analysis, you would need to handle negative indices.

You should now have five results in the test (six in the built database).

### Exercise 4
Note: We *could* evolve this code to handle `size`s inside conditionals using
guards on data flow.  But this amounts to implementing a small interpreter.
The range analysis library already handles conditional branches; we don't
have to use guards on data flow -- don't implement your own interpreter if you can
use the library.

Again, a slight longer C [source snippet](solutions-tests/Exercise4/test.c).

A common issue with the `SimpleRangeAnalysis` library is handling of cases where the bounds are undeterminable at compile-time on one or more paths. For example, even though certain branches have clearly defined bounds, the range analysis library will define the `upperBound` and `lowerBound` of `val` as `INT_MIN` and `INT_MAX` respectively:
```cpp
int val = test ? non_computable_int_value : 30;
```

A similar case is present in the `test_const_branch2` test-case. Note the issues with your Exercise 3 implementation for these test-cases. To handle those cases, it is necessary to augment range analysis with data-flow and restrict the bounds to the upper or lower bound of computable constants that flow to a given expression. 

#### Task 1
To refine the bounds used for validation, start by implementing `getSourceConstantExpr`. Then, implement `getMaxStatedValue` according to the [QLDoc](https://codeql.github.com/docs/ql-language-reference/ql-language-specification/#qldoc-qldoc) documentation in `Exercise4.ql`.

You should now have six results. However, some results annotated as `NON_COMPLIANT` in the test-case are still missing. Why is that?

Hints:
- Which expression is passed to the `getMaxStatedValue` predicate?
- Use .minimum to get the smaller of its qualifier and its argument (the upper bound and the source constants)
- Use max(...) to get the maximum value of a set of values (the source constants)

Answer:
The missing results involve arithmetic offsets (right operand) from a base value (left operand). The `getMaxStatedValue` predicate should only be called on the base expression, not any `AddExpr` or `SubExpr`, as `getMaxStatedValue` relies on data-flow analysis.

### Exercise 5
The [source snippet](solutions-tests/Exercise5/test.c) is unchanged but replicated
for the test.

Since we aren't using pure range analysis via the `upperBound` and/or `lowerBound` predicates, handling `getMaxStatedValue` for `AddExpr` and `SubExpr` is necessary. 

In the interest of time and deduplicating work in this workshop, only implement that check in `getFixedArrayOffset`. In a real-world scenario, it would be necessary to analyze offsets of both the buffer allocation size and array index.

Complete the following predicates:
- `getExprOffsetValue`
- `getFixedArrayOffset`

You should now see nine results.

### Exercise 6
Up until now, we have identified computable expressions — that is, expressions with a value we can determine the bounds of — and related those computable expressions to find array indices greater than or equal to a linked allocation size. But in patterns such as the following, no such bound computation or even data-flow analysis is possible:
```cpp
void string_oob(char* str) {
    char *buf = (char *)malloc(strlen(str) + 1);
    buf[strlen(str) + 1] = 0;
}
```

CodeQL provides a library, `GlobalValueNumbering` implementing *Global Value Numbering*, which is an SSA-based analysis that assigns a unique *value number* to each computation of a value. Each expression has a value number, but multiple expressions can have the same value number. Multiple expressions with the same value number are equivalent. To get the value number for an `Expr` `e`, use `globalValueNumber(e)`. 

In this final exercise, implement the `isOffsetOutOfBoundsGVN` predicate to relate the value numbers of the array index and the buffer allocation size. Make sure to account and array index offset in your implementation.

Hint:
Do not compute the GVN of the entire array index expression; use the base of an offset expression.

Exclude duplicate results by only reporting `isOffsetOutOfBoundsGVN` for `access`/`source` pairs that are not already reported by `isOffsetOutOfBoundsConstant`.

You should now see thirteen results.

Some notes:

Global value numbering only knows that runtime values are equal; they are not
comparable (`<, >, <=` etc.), and the *actual* value is not known.
Reference: https://codeql.github.com/docs/codeql-language-guides/hash-consing-and-value-numbering/


In the query, look for and use *relative* values between allocation and use.  To
do this, use GVN.
This is the case in 

    void test_gvn_var(unsigned long x, unsigned long y, unsigned long sz)
    {
        char *buf = malloc(sz * x * y);
        buf[sz * x * y - 1]; // COMPLIANT
        buf[sz * x * y];     // NON_COMPLIANT
        buf[sz * x * y + 1]; // NON_COMPLIANT
    }

Range analyis won't bound `sz * x * y`, so switch to global value numbering.
<!-- Or use hashcons. -->
Global value numbering finds expressions that are known to have the same runtime
value, independent of structure.  To get the Global Value Number in CodeQL: 

    ...
    globalValueNumber(e) = globalValueNumber(sizeExpr) and
    e != sizeExpr
    ...

We can use global value numbering to identify common values as first step, but for
expressions like

    buf[sz * x * y - 1]; // COMPLIANT

we have to "evaluate" the expressions -- or at least bound them.
