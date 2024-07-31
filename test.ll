def $morninMSG "Mornin World"
def $myMSG "Hello World x"
def $sep "--=| |=--"
def $endMSG "Goodbye World"
def *myNUM 0

def #Main $arg
    syscall println morninMSG
    syscall println sep

    do
        call sayHello
        myNUM ++
    end myNUM > 4

    syscall println sep
    syscall println endMSG
end

def #sayHello
    syscall println myMSG
    syscall println myNUM
end