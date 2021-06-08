import ballerina/test;

function stmtReturn() returns Module {
    Builder builder = new ();
    Module m = new ();
    FunctionDefn foo1 = m.addFunction("foo1", {returnType: "i64", paramTypes: []});
    BasicBlock bb1 = foo1.appendBasicBlock();
    builder.positionAtEnd(bb1);
    builder.ret(constInt("i64",42));

    FunctionDefn foo2 = m.addFunction("foo2", {returnType: "i64", paramTypes: []});
    BasicBlock bb2 = foo2.appendBasicBlock();
    builder.positionAtEnd(bb2);
    PointerValue R1 = builder.alloca("i64",8);
    Value c = constInt("i64",42);
    builder.store(c, R1);
    Value R2 = builder.load(R1);
    builder.ret(R2);
    return m;
}

@test:Config {}
function testStmtReturn() returns error? {
    return runTest(stmtReturn, "stmt_return.ll");
}
