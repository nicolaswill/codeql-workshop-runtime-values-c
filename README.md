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
- Install the CodeQL pack dependencies using the command `CodeQL: Install Pack Dependencies` and select `exercises`, `solutions`, `exercises-tests`, and `solutions-tests` from the list of packs.
- If you have CodeQL on your PATH, build the database using `build-database.sh` and load the database with the VS Code CodeQL extension. 
  - Alternatively, you can download [this pre-built database](https://drive.google.com/file/d/1N8TYJ6f4E33e6wuyorWHZHVCHBZy8Bhb/view?usp=sharing).
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

## Exercises
### Exercise 1
In the first exercise we are going to start by modelling a dynamic allocation with `malloc` and an access to that allocated buffer with an array expression. The goal of this exercise is to then output the array access, buffer, array size, and buffer offset.

The first test-case is a simple one, as both the allocation size and array offsets are constants.

Run the query and ensure that you have three results.

#### Hints
1. `Expr::getValue()::toInt()` can be used to get the integer value of a constant expression.
2. Use `DataFlow::localExprFlow()` to relate the allocated buffer to the array base.

### Exercise 2

#### Task 1
With the basic elements of the analysis in place, refactor the query into two classes: `AllocationCall` and `ArrayAccess`. The `AllocationCall` class should model a call to `malloc` and the `ArrayAccess` class should model an array access expression (`ArrayExpr`).

#### Task 2
Next, note the missing results for the cases in `test_const_var` which involve a variable access rather than a constant. The goal of this task is to implement the `getSourceConstantExpr`, `getFixedSize`, and `getFixedArrayOffset` predicates to handle the case where the allocation size or array index are variables rather than integer constants.

Use local data-flow analysis to complete the `getSourceConstantExpr` predicate. The `getFixedSize` and `getFixedArrayOffset` predicates can be completed using `getSourceConstantExpr`.

### Exercise 3
Running the query from Exercise 2 against the database yields a significant number of missing or incorrect results. The reason is that although great at identifying compile-time constants and their use, data-flow analysis is not always the right tool for identifying the *range* of values an `Expr` might have, particularly when multiple potential constants might flow to an `Expr`.

The CodeQL standard library several mechanisms for addressing this problem; in the remainder of this workshop we will explore two of them: `SimpleRangeAnalysis` and, later, `GlobalValueNumbering`.

Although not in the scope of this workshop, a standard use-case for range analysis is reliably identifying integer overflow and validating integer overflow checks.

#### Task 1
Change the implementation of the `getFixedSize` and `getFixedArrayOffset` predicates to use the `SimpleRangeAnalysis` library rather than data-flow. Specifically, the relevant predicates are `upperBound` and `lowerBound`. Decide which to use for this exercise (`upperBound`, `lowerBound`, or both).

Experiment with different combinations of the `upperBound` and `lowerBound` predicates to see how they impact the results.

<details>
<summary>Hint</summary>
    
    Use `upperBound` for both predicates.

</details>

#### Task 2
Implement the `isOffsetOutOfBoundsConstant` predicate to check if the array offset is out-of-bounds. A template has been provided for you.

You should now have five results.

### Exercise 4

A common issue with the `SimpleRangeAnalysis` library is handling of cases where the bounds are undeterminable at compile-time on one or more paths. For example, even though certain paths have clearly defined bounds, the range analysis library will define the `upperBound` and `lowerBound` of `val` as `INT_MIN` and `INT_MAX` respectively:
```cpp
int val = rand() ? rand() : 30;
```

A similar case is present in the `test_const_branch` and `test_const_branch2` test-cases in the `Exercise3` test case. Note the issues with your Exercise 3 for these test-cases. In these cases, it is necessary to augment range analysis with data-flow and restrict the bounds to the upper or lower bound of computable constants that flow to a given expression. 

#### Task 1
To refine the bounds used for validation, start by implementing `getSourceConstantExpr`. Then, implement `getMaxStatedValue` according to the [QLDoc](https://codeql.github.com/docs/ql-language-reference/ql-language-specification/#qldoc-qldoc) documentation in `Exercise4.ql`.

### Task 2
Update the `getFixedSize` and `getFixedArrayOffset` predicates to use the `getMaxStatedValue` predicate.

You should now have six results. However, some results annotated as `NON_COMPLIANT` in the test-case are still missing. Why is that?

<details>
<summary>Hint</summary>
    
    Which expression is passed to the `getMaxStatedValue` predicate?

</details>

<details>
<summary>Answer</summary>
    
    The missing results involve arithmetic offsets (right operand) from a base value (left operand). The `getMaxStatedValue` predicate should only be called on the base expression, not any `AddExpr` or `SubExpr`, as `getMaxStatedValue` relies on data-flow analysis.

</details>

### Exercise 5
Since we aren't using pure range analysis via the `upperBound` and/or `lowerBound` predicates, handling `getMaxStatedValue` for `AddExpr` and `SubExpr` is necessary. 

In the interest of time and deduplicating work in this workshop, only implement that check in `getFixedArrayOffset`. In a real-world scenario, it would be necessary to analyze offsets of both the buffer allocation size and array index.

Complete the following predicates:
- `getExprOffsetValue`
- `getFixedArrayOffset`

You should now see nine results.

### Exercise 6
TODO: intro to GVN write-up here
TODO: finish below instructions

The final exercise is to implement the `isOffsetOutOfBoundsGVN` predicate to [...]