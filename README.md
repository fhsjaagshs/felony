## Silence

Lisp dialect written in Haskell. Silence has three goals:

1. Simplicity
	- Be as simple as Scheme
	- Maintain a simple set of evaluation semantics
2. Capability & Completeness
	- Provide as much functionality as possible
3. Usability
	- Be usable anywhere you'd use Ruby

Silence is not a finished language, and will probably remain a toy; unless someone cares a whole lot!

The idea is to remain as brief as possible; under 1000 lines of code, ideally under 400-500 with primitives. The core syntax and semantics come in at ~300 lines.

## What's implemented:

- Primitives
	- Anything you'd need to write a solipsistic program 
	- IO will be implemented soon
		- Files
		- Handles
		- And more! (*maybe networking!*)
- Basic semantics (see Silence.Semantics module)
	- Environment lookup
	- Expression evaluation
- Syntax
	- Vectors will be added if they are implemented

## What will be implemented:

If I find the time (!!), I will implement the TODO in `src/Felony/Semantics.hs`.

In addition to that, a package manager might also be implemented (in Silence?)

Lastly, a Silence-to-C compiler will eventually be implemented.