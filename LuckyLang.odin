package Interpreter

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:path/filepath"
import "vendor:varg"
import "scope"
import "runtime"

programLines := [dynamic]string{}
scopeStack : scope.ScopeStack

main::proc() {
    Options :: struct {
        file: string `args:"pos=0,required" usage:"input file"`,
        max_loop: uint `args:"name=Max-Iterations" usage:"The max amouunt of iteratiosn before the parser will crash"`
    }

    opt: Options
    program: string
    args: []string

    switch len(os.args){
        case 0:
            varg.print_usage(&opt)
            os.exit(0)
        case:
            program = filepath.base(os.args[0])
            args = os.args[1:]
    }

    err := varg.parse(&opt, args)
    switch subtype in err {
        case mem.Allocator_Error:
            fmt.printfln("allocation error:", subtype)
            os.exit(1)
        case varg.Validation_Error:
            fmt.println(subtype.message)
            os.exit(1)
        case varg.Parse_Error:
            fmt.println(subtype.message)
            os.exit(1)
        case varg.Help_Request:
            varg.print_usage(&opt, program)
            os.exit(0)
    }

    scopeStack = scope.ScopeStack{
        validContainers = make(map[string]scope.Container),
        scopes = make([dynamic]scope.Scope)
    }

    read_file(opt.file)
    scopeStack.globalScope = generate_global_scope()
    scope.load_globalScope(&scopeStack)

    fmt.println("----------------------------------------")
    fmt.println("Starting Program")
    fmt.println("----------------------------------------")

    scope.program_entry_point(&scopeStack, {"Test123"})
    runtime.start_exec_loop(&scopeStack, programLines)
}

read_file :: proc(path: string) {
    data, ok := os.read_entire_file(path, context.allocator)
    if !ok {
        fmt.println("Could not open file...")
        os.exit(1)
    }
    //defer delete(data, context.allocator)

    it := string(data)
    for line in strings.split_lines_iterator(&it) {
        
        trimLine := strings.trim_null(line)
        trimLine = strings.trim_space(trimLine)
        append(&programLines, trimLine)
        fmt.println(trimLine)
    }
}

generate_global_scope :: proc() -> scope.Scope {
    fmt.println("Generating Global Scope...")
    newScope := scope.Scope {
        make(map[string]scope.Container),
        -1,
        {},
        -1
    }

    lineIndex := 0
    for lineIndex < len(programLines) {
        res, err := strings.split(programLines[lineIndex], " ")

        fmt.printfln("Split line %v of %v into array: %v", lineIndex, len(programLines), res)

        if len(res) <= 0 { lineIndex += 1; continue }
        //If comment, skip it
        if strings.has_prefix(res[0], "//") { lineIndex += 1; continue }
        //If not defining anything, skip it
        if res[0] != "def" { lineIndex += 1; continue }
        //Defining something

        newContainer, name := generate_container(res, lineIndex)

        if newContainer.type == scope.ContainerType.FUNC {
            fmt.println("Adjusting to function container...")

            functionBody, endIndex := generate_function_container(res, lineIndex)
            newContainer.funcVal = functionBody
            lineIndex = endIndex
            fmt.printfln("Continuing at index: %v for function: %v", endIndex, functionBody)
        }

        newScope.containerMap[name] = newContainer

        fmt.printfln("Cotainer: %s -- %v", name, newContainer)

        lineIndex += 1
    }

    fmt.printfln("Returning global scope: %v", newScope)
    return newScope
}

generate_loop_scope :: proc(startindex: int) -> (scope.Scope, int) {
    newScope, end := generate_scope(startindex)

    newScope.loopBegin = startindex
    fmt.printfln("------------ loop begin in scope: %v", newScope.loopBegin)
    return newScope, end
}

generate_scope :: proc(startIndex: int) -> (scope.Scope, int) {
    fmt.printfln("Generating new Scope from index: %v", startIndex)
    newScope := scope.Scope{
        containerMap = make(map[string]scope.Container),
        instructionPtr = startIndex + 1,
        loopBegin = -1
    }
    lineIndex := startIndex + 1

    for true {
        res, err := strings.split(programLines[lineIndex], " ")
        fmt.printfln("Split line %v into: %v", lineIndex, res)

        if len(res) <= 0 { lineIndex += 1; continue }
        //If comment, skip it
        if strings.has_prefix(res[0], "//") { lineIndex += 1; continue }

        switch res[0] {
            case "def":
                newContainer, name := generate_container(res, lineIndex)
                if newContainer.type == scope.ContainerType.FUNC {
                    functionBody, endIndex := generate_function_container(res, lineIndex)
                    newContainer.funcVal = functionBody
                    lineIndex = endIndex
                }

                fmt.printfln("found defintion at: %v; name: %v, container: %v", lineIndex, name, newContainer)

                newScope.containerMap[name] = newContainer
                break
            case "do":
                newLoop, continueLine := generate_loop(lineIndex)
                fmt.printfln("found loop at line: %v, loop: %v, loopScope: %v", lineIndex, newLoop, newLoop.loopScope)
                append(&newScope.loops, newLoop)
                lineIndex = continueLine
                fmt.printfln("Continouing on line: %v", lineIndex)
                break;
            case "end":
                fmt.printfln("Found end of function/loop at index: %v", lineIndex)
                return newScope, lineIndex;
        }

        lineIndex += 1
    }

    return newScope, lineIndex
}

generate_loop :: proc(startIndex: int) -> (scope.Loop, int) {
    fmt.printfln("Generating loop from index: %v", startIndex)
    new_loop := scope.Loop{
        beginIndex = startIndex
    }

    lineIndex := startIndex + 1
    loopScope, endIndex := generate_loop_scope(lineIndex)
    
    fmt.printfln("Generated loop-scope: %v... loop ends at index: %v", loopScope, endIndex)

    new_loop.loopScope = loopScope
    new_loop.endIndex = endIndex
    
    expression := strings.cut(programLines[endIndex], 3)
    fmt.printfln("Boolean expression at index: %v is: %s",endIndex, expression)
    new_loop.boolExpression = expression
    
    fmt.printfln("Returning new loop-data: %v", new_loop)

    return new_loop, endIndex
}

generate_function_container :: proc(args: []string, lineIndex: int) -> (scope.Function, int) {
    fmt.printfln("Generating new Function Body...")
    functionBody := scope.Function{ return_type = scope.ContainerType.NONE, entryLine = lineIndex }
    index := 2

    fmt.printfln("Checking function parameters: %v, with length: %v", args, len(args))
    for index < len(args) {
        if args[index] == ">" {
            fmt.printfln("Found return symbol at: %v", index)
            if len(args) <= index+1 {
                fmt.printfln("Function cannot return an empty type... please provide a valid return type. Line: %v", lineIndex)
                os.exit(1)
            }

            functionBody.return_type = scope.get_container_type(args[index + 1])
            fmt.printfln("Set function returntype to %v", functionBody.return_type)
            break
        }

        type := strings.cut(args[index], 0, 1)
        name := strings.cut(args[index], 1, len(args[index]))
        conType : scope.ContainerType = scope.get_container_type(type)

        fmt.printfln("Found Parameter: %v, name: %v, type: %v", index, name, type)

        append(&functionBody.argument_names, name)
        append(&functionBody.argument_types, conType)

        index += 1
    }

    index = lineIndex
    fmt.printfln("Finished parameter search... generating scope from line: %v", index)
    funcScope, endLine := generate_scope(index)
    functionBody.funcScope = funcScope
    functionBody.endLine = endLine
    fmt.printfln("Finished Scope gen: %v, endLine: %v", funcScope, endLine)

    return functionBody, endLine
}

generate_container :: proc(args: []string, lineIndex: int) -> (scope.Container, string) {
    fmt.printfln("Generating Container for line %v with array %v", lineIndex, args)

    if len(args) < 2 || len(args[1]) < 2 {
        fmt.printfln("[ERROR] Definition must have a valid type and a name, which is at least 1 character long: line %v", lineIndex+1)
        os.exit(1)
    }

    type := strings.cut(args[1], 0, 1)
    name := strings.cut(args[1], 1, len(args[1]))

    fmt.printfln("Found type: %v and name: %v", type, name)

    conType : scope.ContainerType = scope.get_container_type(type)

    container := scope.Container {
        type = conType   
    }

    scope.set_default_value(conType, &container)

    if len(args) > 2 {
        switch conType {
            case .STR:
                container.strVal = runtime.parse_string(programLines[lineIndex])
            case .BOOL:
                container.boolVal = runtime.parse_boolean_value(args, &scopeStack)
            case .NUM:
                container.numVal = runtime.parse_num_value(args[2])
            case .CHAR:
                fallthrough
            case .FUNC:
                fallthrough
            case .NONE:
                fallthrough
            case:
                break
        }
    }

    return container, name
}