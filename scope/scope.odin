package scope

import "core:fmt"
import "core:os"

ContainerType :: enum {
    NUM,
    STR,
    CHAR,
    BOOL,
    FUNC,
    NONE
}

Function :: struct {
    entryLine: int,
    endLine: int,
    argument_types: [dynamic]ContainerType,
    argument_names: [dynamic]string,
    return_type: ContainerType,
    funcScope: Scope
}

Container :: struct {
    type: ContainerType,
    numVal: int,
    strVal: string,
    charVal: rune,
    boolVal: bool,
    funcVal: Function
}

Scope :: struct {
    containerMap: map[string]Container,
    instructionPtr: int,
    loops: [dynamic]Loop,
    loopBegin: int
}

Loop :: struct {
    loopScope: Scope,
    beginIndex: int,
    endIndex: int,
    boolExpression: string
}

ScopeStack :: struct {
    globalScope : Scope,
    scopes : [dynamic]Scope,
    validContainers : map[string]Container
}

program_entry_point :: proc(stack: ^ScopeStack, arguments: []string) {
    execute_function(stack, "Main", arguments)
}

get_container_ptr_in_scope :: proc(stack: ^ScopeStack, containerName: string) -> ^Container {
    cont, ok := stack.validContainers[containerName]
    if !ok {
        fmt.printfln("[ERROR] Could not find container with name %s in current scope", containerName)
        os.exit(1)
    }

    return &stack.validContainers[containerName]
}

get_container_in_scope :: proc(stack: ^ScopeStack, containerName: string) -> Container {
    cont, ok := stack.validContainers[containerName]
    if !ok {
        fmt.printfln("[ERROR] Could not find container with name %s in current scope", containerName)
        os.exit(1)
    }

    return cont
}

execute_function :: proc(stack: ^ScopeStack, functionName: string, arguments: []string) {
    funcCont, ok := stack.validContainers[functionName]
    if !ok {
        fmt.printfln("[ERROR] Could not find function with name %s in current scope", functionName)
        os.exit(1)
    }

    if funcCont.type != ContainerType.FUNC {
        fmt.printfln("[ERROR] %s is of type %v, and thus cannot be called as a function", functionName, funcCont.type)
        os.exit(1)
    }

    functionBody := funcCont.funcVal

    if len(arguments) != len(functionBody.argument_types) {
        fmt.printfln("[ERROR] Argument count mismatch: %s takes %v arguments, but only %v were provided", functionName, len(functionBody.argument_names), len(arguments))
        os.exit(1)
    }

    functionBody.funcScope.instructionPtr = functionBody.entryLine
    push_scope(stack, functionBody.funcScope)
}

load_globalScope :: proc(stack: ^ScopeStack) {
    for key, value in stack.globalScope.containerMap {
        stack.validContainers[key] = value
    }
    fmt.printfln("Loaded Global Scope: %v", stack.globalScope)
    fmt.println("-----------------------------------------------")
    fmt.printfln("Valid-Containers: %v", stack.validContainers)
}

push_scope :: proc(stack: ^ScopeStack, scope: Scope) {
    //fmt.printfln("Pushing scope: %v", scope.containerMap)
    append(&stack.scopes, scope)
    for key, value in scope.containerMap {
        _, ok := stack.validContainers[key]
        if ok {
            fmt.printfln("[ERROR] Container with name %s is already defined in previous scope... (Make dynamic array base and backward search for container with name => Voilá; Überlagerung)")
            os.exit(1)
        }

        stack.validContainers[key] = value
    }
}

pop_scope :: proc(stack: ^ScopeStack) -> Scope {
    scope := pop(&stack.scopes)
    for key, value in scope.containerMap {
        delete_key(&stack.validContainers, key)
    }
    return scope
}

destroy_scope :: proc(scope: Scope) {
    delete(scope.containerMap)
}

active_scope :: proc(stack: ^ScopeStack) -> ^Scope {
    if len(stack.scopes)-1 < 0 do return &stack.globalScope

    return &stack.scopes[len(stack.scopes)-1]
}

get_container_type :: proc(symbol: string) -> ContainerType {
    switch symbol {
        case "*":
            return ContainerType.NUM
        case "$":
            return ContainerType.STR
        case "&":
            return ContainerType.BOOL
        case "#":
            return ContainerType.FUNC
        case:
            return ContainerType.NONE
    }
}

get_generic_value :: proc(container: ^Container) -> any {
    switch container.type {
        case .BOOL:
            return container.boolVal
        case .NUM:
            return container.numVal
        case .CHAR:
            return container.charVal
        case .STR:
            return container.strVal
        case .FUNC:
            fallthrough
        case ContainerType.NONE: 
            return "NAN"
    }

    return "NAN"
}

set_default_value :: proc(type: ContainerType, container: ^Container) -> ^Container {
    switch type {
        case ContainerType.BOOL:
            container.boolVal = false
        case ContainerType.NUM:
            container.numVal = 0
        case ContainerType.FUNC:
            container.funcVal = {}
        case ContainerType.CHAR:
            container.charVal = ' '
        case ContainerType.STR:
            container.strVal = ""
        case ContainerType.NONE: 
            container.numVal = 0
    }

    return container
}

get_loop_by_begin :: proc(stack: ^ScopeStack, beginLine: int) -> ^Loop {
    index := 0
    for loop in active_scope(stack).loops {
        if loop.beginIndex == beginLine {
            return &active_scope(stack).loops[index]
        }
        index += 1
    }

    fmt.printfln("[ERROR] Cannot find loop with beginning at line: %s", beginLine)
    return nil
}

get_loop :: proc(stack: ^ScopeStack, endLine: int) -> ^Loop {
    index := 0
    for loop in active_scope(stack).loops {
        if loop.endIndex == endLine {
            return &active_scope(stack).loops[index]
        }
        index += 1
    }

    fmt.printfln("[ERROR] Cannot find loop with ending at line: %s", endLine)
    return nil
}