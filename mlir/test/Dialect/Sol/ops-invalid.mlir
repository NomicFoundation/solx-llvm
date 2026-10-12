// RUN: mlir-opt %s -split-input-file -verify-diagnostics

#Contract = #sol<ContractKind Contract>

// Only the runtime code calls through a pointer the creation code stored.
// expected-error @below {{'sol.contract' op expects creation func refs only in runtime code}}
sol.contract @C {
} {creation_func_refs = [@g], kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// A creation func ref is a dispatch case, which needs the function's id.
// expected-error @below {{'sol.contract' op expects creation func ref 'g' to be a sol.func with an id}}
sol.contract @C {
  sol.func @g() attributes {state_mutability = #NonPayable} {
    sol.return
  }
} {creation_func_refs = [@g], kind = #Contract, runtime}

// -----

#Contract = #sol<ContractKind Contract>

// expected-error @below {{'sol.contract' op expects creation func ref 'g' to be a sol.func with an id}}
sol.contract @C {
} {creation_func_refs = [@g], kind = #Contract, runtime}

// -----

#Contract = #sol<ContractKind Contract>

// expected-error @below {{'sol.contract' op expects creation func ref 'g' to be a sol.func with an id}}
sol.contract @C {
  sol.state_var @g slot 0 offset 0 : ui256
} {creation_func_refs = [@g], kind = #Contract, runtime}

// -----

#Contract = #sol<ContractKind Contract>

// A module is lowered to one object, whose entry code the module's becomes.
// expected-error @below {{'sol.contract' op expects no other sol.contract in its module, found 'D'}}
sol.contract @C {
} {kind = #Contract}
// expected-error @below {{'sol.contract' op expects no other sol.contract in its module, found 'C'}}
sol.contract @D {
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>

// A contract is lowered into an object in the module holding it.
sol.contract @C {
  // expected-error @below {{'sol.contract' op expects parent op 'builtin.module'}}
  sol.contract @D {
  } {kind = #Contract}
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>

// The creation code keeps the immutables in consecutive memory cells.
// expected-error @below {{'sol.contract' op expects immutable 'y' to carry index 1, not 0}}
sol.contract @C {
  sol.immutable @x index 0 : ui256
  sol.immutable @y index 0 : ui256
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>

// expected-error @below {{'sol.contract' op expects immutable 'x' to carry index 0, not 1}}
sol.contract @C {
  sol.immutable @x index 1 : ui256
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// The creation code dispatches no call.
// expected-error @below {{'sol.contract' op expects function 'f' in creation code to have no selector}}
sol.contract @C {
  sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    sol.return
  }
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#Receive = #sol<FunctionKind Receive>

// Receive and fallback run in the runtime code.
// expected-error @below {{'sol.contract' op expects function 'r' of kind Receive in runtime code}}
sol.contract @C {
  sol.func @r() attributes {kind = #Receive} {
    sol.return
  }
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#Fallback = #sol<FunctionKind Fallback>

// expected-error @below {{'sol.contract' op expects function 'f' of kind Fallback in runtime code}}
sol.contract @C {
  sol.func @f() attributes {kind = #Fallback} {
    sol.return
  }
} {kind = #Contract}

// -----

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>

// A constructor runs in the creation code.
// expected-error @below {{'sol.contract' op expects function 'c' of kind Constructor in creation code}}
sol.contract @C {
  sol.func @c() attributes {kind = #Constructor} {
    sol.return
  }
} {kind = #Contract, runtime}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

sol.contract @C {
  sol.func @get() -> ui256 attributes {state_mutability = #NonPayable} {
    // expected-error @below {{'sol.load_immutable' op expects 'x' to reference a sol.immutable}}
    %0 = sol.load_immutable @x : ui256
    sol.return %0 : ui256
  }
} {kind = #Contract, runtime}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

sol.contract @C {
  sol.func @x() attributes {state_mutability = #NonPayable} {
    sol.return
  }
  sol.func @get() -> ui256 attributes {state_mutability = #NonPayable} {
    // expected-error @below {{'sol.load_immutable' op expects 'x' to reference a sol.immutable}}
    %0 = sol.load_immutable @x : ui256
    sol.return %0 : ui256
  }
} {kind = #Contract, runtime}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// A load reads the value of the immutable's type.
sol.contract @C {
  sol.immutable @x index 0 : ui256
  sol.func @get() -> ui8 attributes {state_mutability = #NonPayable} {
    // expected-error @below {{'sol.load_immutable' op expects type 'ui256' of 'x', not 'ui8'}}
    %0 = sol.load_immutable @x : ui8
    sol.return %0 : ui8
  }
} {kind = #Contract, runtime}

// -----

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// The creation code reads an immutable from its memory cell.
sol.contract @C {
  sol.immutable @x index 0 : ui256
  sol.func @ctor() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
    // expected-error @below {{'sol.load_immutable' op expects to load 'x' in runtime code}}
    %0 = sol.load_immutable @x : ui256
    sol.return
  }
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// A pointer's target is a dispatch case, which needs the function's id.
sol.contract @C {
  sol.func @f() attributes {state_mutability = #NonPayable} {
    // expected-error @below {{'sol.func_constant' op expects 'g' to be a sol.func with an id}}
    %0 = sol.func_constant @g : !sol.func_ref<() -> ()>
    sol.return
  }
} {kind = #Contract, runtime}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

sol.contract @C {
  sol.func @g() attributes {state_mutability = #NonPayable} {
    sol.return
  }
  sol.func @f() attributes {state_mutability = #NonPayable} {
    // expected-error @below {{'sol.func_constant' op expects 'g' to be a sol.func with an id}}
    %0 = sol.func_constant @g : !sol.func_ref<() -> ()>
    sol.return
  }
} {kind = #Contract, runtime}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// A pointer's type is its target's, which the dispatch calls through it.
sol.contract @C {
  sol.func @k(%arg0: ui256) attributes {id = 10 : i64, state_mutability = #NonPayable} {
    sol.return
  }
  sol.func @f() attributes {state_mutability = #NonPayable} {
    // expected-error @below {{'sol.func_constant' op expects type '(ui256) -> ()' of 'k', not '() -> ()'}}
    %0 = sol.func_constant @k : !sol.func_ref<() -> ()>
    sol.return
  }
} {kind = #Contract, runtime}

// -----

#NonPayable = #sol<StateMutability NonPayable>

// A function is code of the contract holding it, which lowers to an object.
// expected-error @below {{'sol.func' op expects parent op 'sol.contract'}}
sol.func @free() attributes {state_mutability = #NonPayable} {
  sol.return
}

// -----

// expected-error @below {{'sol.modifier' op expects parent op 'sol.contract'}}
sol.modifier @m() {
  sol.placeholder
  sol.return
}
