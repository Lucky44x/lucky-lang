package luckyLangRuntime

import "../scope"
import "core:fmt"
import "core:strings"
import "core:os"
import "core:c/libc"

start_exec_loop :: proc(stack: ^scope.ScopeStack, lines: [dynamic]string) {

    for scope.active_scope(stack).instructionPtr < len(lines) && scope.active_scope(stack).instructionPtr > -1 {
        currentScope := scope.active_scope(stack)

        currentScope.instructionPtr += 1

        res, err := strings.split(lines[currentScope.instructionPtr], " ")

        if len(res) < 1 do continue

        if res[0] == "end" {
            if len(res) > 1 {
                if currentScope.loopBegin > -1 {
                    cond := parse_boolean_value(res[1:], stack)
                    //fmt.printfln("Found end: %v, %v", res[1:], cond)
                    if !cond {
                        //fmt.printfln("%v, %v", currentScope.loopBegin, len(currentScope.loops))
                        currentScope.instructionPtr = currentScope.loopBegin - 1
                        continue
                    }
                }
            }

            scope.pop_scope(stack)
        }

        switch(res[0]) {
            case "syscall":
                system_call(res, stack)
            case "call":
                function_call(res, stack)
            case "do":
                loop := scope.get_loop_by_begin(stack, currentScope.instructionPtr)
                //fmt.printfln("Found loop at line: %v... LOOP: %v pushing scope...", currentScope.instructionPtr, loop)
                currentScope.instructionPtr = loop.endIndex
                scope.push_scope(stack, loop.loopScope)
                scope.active_scope(stack).instructionPtr = loop.beginIndex
                continue
        }

        if len(res) < 2 do continue

        switch(res[1]) {
            case "=":
                fmt.printfln("Setting val")
                set_value_call(res, stack, lines[currentScope.instructionPtr])
            case "++":
                increment_value_call(res, stack)
            case "--":
                decrement_value_call(res, stack)
            case "-=":
                minus_call(res, stack)
            case "+=":
                sum_call(res, stack)
            case "*=":
                mult_call(res, stack)
            case "/=":
                div_call(res, stack)
        }

        //fmt.println(lines[currentScope.instructionPtr])
    }

    fmt.println("----------------------------------------")
    fmt.println("Program end... give any input to close...")
    fmt.println("----------------------------------------")

    buf: [256]byte
    n, err := os.read(os.stdin, buf[:])
    if err < 0 {
        fmt.printfln("Some error, idk %v", err)
        os.exit(1)
    }
}

parse_string :: proc(line: string) -> string {
    ret, _, _ := parse_string_internal(line)
    return ret
}

parse_string_internal :: proc(line: string) -> (string, int, int) {
    beginIndex := -1
    index := 0
    for token in line {
        if token == '\\'  { index += 2; continue; }
        if token == '"' {
            if beginIndex == -1 do beginIndex = index
            else if beginIndex > -1 do break;
        }
        index += 1;
    }

    fmt.printfln("Cutting line: %s at index: %v for %v runes", line, beginIndex + 1, index - beginIndex - 2)
    actString := strings.cut(line, beginIndex + 1, index - beginIndex - 1)
    return actString, beginIndex, index
}

parse_num_value :: proc(num: string) -> int {
    cstr : cstring = strings.clone_to_cstring(num)
    endptr : [^]u8
    return cast(int)libc.strtol(cstr, &endptr, 10)
}

parse_boolean_value :: proc(args: []string, stack: ^scope.ScopeStack) -> bool {
    if len(args) == 0 {
        fmt.printfln("Could not read boolean expression: %v", args)
        os.exit(1)
    }
    contName := args[0]
    cont := scope.get_container_in_scope(stack, contName)

    value := parse_num_value(args[2])
    
    switch(args[1]) {
        case ">":
            return cont.numVal > value
        case "<":
            return cont.numVal < value
        case "==":
            return cont.numVal == value
        case "!=":
            return cont.numVal != value
    }

    return false
}

div_call :: proc(args: []string, stack: ^scope.ScopeStack) {
    contName := args[0]
    cont := scope.get_container_in_scope(stack, contName)
}

mult_call :: proc(args: []string, stack: ^scope.ScopeStack) {
    contName := args[0]
    cont := scope.get_container_in_scope(stack, contName)
}

sum_call :: proc(args: []string, stack: ^scope.ScopeStack) {
    contName := args[0]
    cont := scope.get_container_in_scope(stack, contName)
}

minus_call :: proc(args: []string, stack: ^scope.ScopeStack) {
    contName := args[0]
    cont := scope.get_container_in_scope(stack, contName)
}

decrement_value_call :: proc(args: []string, stack: ^scope.ScopeStack) {
    contName := args[0]
    cont := scope.get_container_in_scope(stack, contName)

    if cont.type != scope.ContainerType.NUM {
        fmt.printfln("[ERROR] Cannot decrement value of %s because it is not of type NUM", contName)
        os.exit(1)
    }

    scope.get_container_ptr_in_scope(stack, contName).numVal -= 1
}

increment_value_call :: proc(args: []string, stack: ^scope.ScopeStack) {
    contName := args[0]
    cont := scope.get_container_in_scope(stack, contName)

    if cont.type != scope.ContainerType.NUM {
        fmt.printfln("[ERROR] Cannot increment value of %s because it is not of type NUM", contName)
        os.exit(1)
    }

    scope.get_container_ptr_in_scope(stack, contName).numVal += 1
}

set_value_call :: proc(args: []string, stack: ^scope.ScopeStack, line: string) {
    contName := args[0]
    cont := scope.get_container_ptr_in_scope(stack, contName)

    switch cont.type {
        case .STR:
            cont.strVal = parse_string(line)
        case .BOOL:
            cont.boolVal = parse_boolean_value(args, stack)
        case .CHAR:
            break
        case .FUNC:
            fmt.printfln("[ERROR] Cannot assign a value to a function container... (Name: %s)", contName)
            os.exit(1)
        case .NONE:
            fmt.printfln("[ERROR] Cannot assing a value to a NONE container... (Name: %s)", contName)
        case.NUM:
            cont.numVal = parse_num_value(args[2])
        case:
            break
    }
}

function_call :: proc(args: []string, stack: ^scope.ScopeStack) {
    funcName := args[1]

    scope.execute_function(stack, funcName, args[2:])
}

system_call :: proc(args: []string, stack: ^scope.ScopeStack) {
    switch(args[1]) {
        case "println":
            print_call(args, stack)
    }
}

print_call :: proc(args: []string, stack: ^scope.ScopeStack) {

    value : string

    if !strings.has_prefix(args[2], "\"") {
        varCont := scope.get_container_in_scope(stack, args[2])
        return
    }

    fmt.println(args[2:])
}

evaluate_bool_term :: proc(term: string) -> bool {
    return false
}

evaluate_arith_term :: proc(term: string) -> int {
    return 0
}