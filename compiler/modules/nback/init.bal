import wso2/nballerina.bir;
import wso2/nballerina.comm.err;
import wso2/nballerina.types as t;
import wso2/nballerina.print.llvm;

const USER_MAIN_NAME = "main";

// Need to guarantee alignment for subtypes, so we can lo bit to distinguish betweem
// bitsets and pointers to subtypes
const SUBTYPE_ALIGN = 8;

public type ProgramModule readonly & record {|
    bir:ModuleId id;
    TypeUsage typeUsage;
|};

type TypeDefnFields record {|
    readonly t:SemType semType;
    llvm:ConstPointerValue ptr;
    llvm:Type llType;
|};

type TypeDefn record {|
    *TypeDefnFields;
    int tid?;
|};

type ComplexTypeDefn record {|
    *TypeDefnFields;
    readonly t:ComplexSemType semType;
|};

type InherentTypeDefn record {|
    *TypeDefnFields;
    int tid;
|};

type SubtypeDefn record {|
    readonly t:ComplexSemType semType;
    readonly t:UniformTypeCode typeCode;
    llvm:ConstPointerValue ptr;
    llvm:StructType? structType;
|};

const TYPE_KIND_ARRAY = "array";
const TYPE_KIND_MAP = "map";
const TYPE_KIND_RECORD = "record";
const TYPE_KIND_PRECOMPUTED = "precomputed";

const STRUCTURE_LIST = 0;
const STRUCTURE_MAPPING = 1;

type StructureBasicType STRUCTURE_LIST|STRUCTURE_MAPPING;

type TypeKindArrayOrMap TYPE_KIND_ARRAY|TYPE_KIND_MAP;
type TypeKind TypeKindArrayOrMap|TYPE_KIND_RECORD|TYPE_KIND_PRECOMPUTED;

type FunctionRef llvm:FunctionDecl|llvm:ConstPointerValue;

type InitModuleContext record {|
    llvm:Context llContext;
    llvm:Module llMod;
    t:Context tc;
    int stringCount = 0;
    table<InherentTypeDefn> key(semType)[2] inherentTypeDefns = [table [], table[]];
    table<ComplexTypeDefn> key(semType) complexTypeDefns = table [];
    table<SubtypeDefn> key(typeCode, semType) subtypeDefns = table [];
    InitTypes llTypes;
    map<llvm:FunctionDecl> typeTestFuncs = {};
    map<llvm:FunctionDecl> runtimeFuncs = {};
    // subtype definitions cannot be completed before inherent types are complete,
    // because precomputed subtypes need to know all inherent types
    boolean inherentTypesComplete;
|};

public function buildInitModule(t:Env env, ProgramModule[] modules, map<bir:FunctionSignature> publicFuncs) returns llvm:Module|BuildError {
    llvm:Context llContext = new;
    llvm:Module llMod = llContext.createModule();
    buildInitTypes(llContext, llMod, env, modules);
    llvm:Builder builder = llContext.createBuilder();
    buildMain(modules[0].id, USER_MAIN_NAME, publicFuncs[USER_MAIN_NAME], llMod, builder);
    return llMod;
}

function buildMain(bir:ModuleId entryModId, string userMainName, bir:FunctionSignature? userMainSig, llvm:Module llMod, llvm:Builder builder) {
    llvm:FunctionType ty = { returnType: "void", paramTypes: [] };
    llvm:FunctionDefn func = llMod.addFunctionDefn("_bal_main", ty);
    builder.positionAtEnd(func.appendBasicBlock());

    if userMainSig != () {
        string userMainMangledName = mangleInternalSymbol(entryModId, { identifier: userMainName, isPublic: true });
        llvm:FunctionType userMainTy = buildFunctionSignature(userMainSig);
        llvm:FunctionDecl userMainDecl = llMod.addFunctionDecl(userMainMangledName, userMainTy);
        _ = builder.call(userMainDecl, []);
    }

    builder.ret();
}

function buildInitTypes(llvm:Context llContext, llvm:Module llMod, t:Env env, ProgramModule[] modules) {
    InitTypes llTypes = createInitTypes(llContext);
    InitModuleContext cx = {
        llContext,
        llMod,
        tc: t:typeContext(env),
        llTypes,
        inherentTypesComplete: false
    };
    buildInitTypesForUsage(cx, modules, USED_INHERENT_TYPE);
    cx.inherentTypesComplete = true;
    finishSubtypeDefns(cx);
    buildInitTypesForUsage(cx, modules, USED_EXACTIFY);
    buildInitTypesForUsage(cx, modules, USED_TYPE_TEST);
}

function buildInitTypesForUsage(InitModuleContext cx, ProgramModule[] modules, TypeHowUsed howUsed) {
    foreach var mod in modules {
        var { types, uses } = mod.typeUsage;
        bir:ModuleId id = mod.id;
        foreach int i in 0 ..< types.length() {
            if (uses[i] & howUsed) != 0 {
                t:SemType ty = types[i];
                string sym = mangleTypeSymbol(id, howUsed, i);
                if howUsed == USED_INHERENT_TYPE {
                    addInherentTypeSymbol(cx, sym, ty);
                }
                else if howUsed == USED_EXACTIFY {
                    addExactifyTypeSymbol(cx, sym, ty);
                }
                else {
                    addTypeTestTypeSymbol(cx, sym, <t:ComplexSemType>ty);
                }
            }       
        }
    }    
}

function addInherentTypeSymbol(InitModuleContext cx, string symbol, t:SemType semType)  {
    StructureBasicType basic = <StructureBasicType>structureBasicType(semType);
    InherentTypeDefn? existingDefn = cx.inherentTypeDefns[basic][semType];
    if existingDefn != () {
        addTypeAlias(cx, symbol, existingDefn);
    }
    else {
        _ = addInherentTypeDefn(cx, symbol, semType, basic, "external");
    }
}

function addInherentTypeDefn(InitModuleContext cx, string symbol, t:SemType semType, StructureBasicType basic, llvm:Linkage linkage) returns llvm:ConstPointerValue {
    table<InherentTypeDefn> key(semType) defns = cx.inherentTypeDefns[basic];
    int tid = defns.length();
    llvm:StructType llType;
    llvm:ConstValue? initValue;
    if basic == STRUCTURE_LIST {
        llType = llListDescType;
        // The initializer is set later, because of the possibility of
        // recursion via `getFillerDesc`.
        initValue = ();
    }
    else {
        t:MappingAtomicType mat = <t:MappingAtomicType>t:mappingAtomicTypeRw(cx.tc, semType);
        llType = createMappingDescType(tid, mat);
        // SUBSET move this later, when we do filling of mapping values
        initValue = createMappingDescInit(cx, tid, mat);
    }
    llvm:ConstPointerValue ptr = cx.llMod.addGlobal(llType, symbol, initializer=initValue, isConstant=true, linkage=linkage);
    defns.add({ llType, ptr, semType, tid });
    if basic == STRUCTURE_LIST {
        cx.llMod.setInitializer(ptr, createListDescInit(cx, tid, <t:SemType>t:arrayMemberType(cx.tc, semType)));
    }
    return ptr;
}

function createListDescInit(InitModuleContext cx, int tid, t:SemType memberType) returns llvm:ConstValue {
    FunctionRef[] functionRefs = getListDescFunctionRefs(cx, memberType);
    llvm:Value[] initStructValues = [llvm:constInt(LLVM_TID, tid)];
    foreach FunctionRef fr in functionRefs {
        initStructValues.push(fr);
    }
    initStructValues.push(getMemberType(cx, memberType));
    initStructValues.push(getFillerDesc(cx, memberType)); 
    return cx.llContext.constStruct(initStructValues);    
}

// Type of the value should be llStructureDescPtrType
function getFillerDesc(InitModuleContext cx, t:SemType memberType) returns llvm:ConstPointerValue {
    StructureBasicType? basic = fillableStructureBasicType(cx.tc, memberType);
    // JBUG narrowing does not work if you say `== ()`
    if basic is () {
        return llvm:constNull(llStructureDescPtrType);
    }
    table<InherentTypeDefn> key(semType) defns = cx.inherentTypeDefns[basic];
    InherentTypeDefn? existingDefn = defns[memberType];
    llvm:ConstPointerValue desc;
    if existingDefn != () {
        desc = existingDefn.ptr;
    }
    else {
        desc = addInherentTypeDefn(cx, fillerDescSymbol(basic, defns.length()), memberType, basic, "internal");
    }
    return cx.llContext.constBitCast(desc, llStructureDescPtrType);
}

function fillableStructureBasicType(t:Context tc, t:SemType semType) returns StructureBasicType? {
    StructureBasicType? basic = structureBasicType(semType);
    if basic == STRUCTURE_LIST {
        if t:listAtomicTypeRw(tc, semType) != () {
            return basic;
        }
    }
    if basic == STRUCTURE_MAPPING {
        if t:mappingAtomicTypeRw(tc, semType) != () {
            return basic;
        }
    }
    return ();
}

function createMappingDescType(int tid, t:MappingAtomicType mat) returns llvm:StructType {
    // tid, fieldCount, restField, individualFields...
    return llvm:structType([LLVM_TID, "i32", LLVM_MEMBER_TYPE, llvm:arrayType(LLVM_MEMBER_TYPE, mat.names.length())]);
}

function createMappingDescInit(InitModuleContext cx, int tid, t:MappingAtomicType mat) returns llvm:ConstValue {    
    llvm:ConstValue[] llFields = from var ty in mat.types select getMemberType(cx, ty);
    return cx.llContext.constStruct([
        llvm:constInt(LLVM_TID, tid),
        llvm:constInt("i32", llFields.length()),
        getMemberType(cx, mat.rest),
        cx.llContext.constArray(LLVM_MEMBER_TYPE, llFields)
    ]);
}

function getMemberType(InitModuleContext cx, t:SemType memberType) returns llvm:ConstValue {
    if memberType is t:UniformTypeBitSet {
        return llvm:constInt(LLVM_MEMBER_TYPE, (memberType << 1)|1);
    }
    else {
        llvm:ConstPointerValue ptr;
        ComplexTypeDefn? existing = cx.complexTypeDefns[memberType];
        if existing != () {
            ptr = existing.ptr;
        }
        else {
            ptr = addComplexTypeDefn(cx, memberTypeSymbol(cx.complexTypeDefns.length()), memberType, "internal");
        }
        return cx.llContext.constPtrToInt(ptr, LLVM_MEMBER_TYPE);
    }
}

function addExactifyTypeSymbol(InitModuleContext cx, string symbol, t:SemType semType) {
    StructureBasicType basic = <StructureBasicType>structureBasicType(semType);
    InherentTypeDefn? existingDefn = cx.inherentTypeDefns[basic][semType];
    llvm:ConstValue initValue = llvm:constInt(LLVM_TID, existingDefn == () ? -1 : existingDefn.tid);
    _ = cx.llMod.addGlobal(LLVM_TID, symbol, initializer=initValue, isConstant=true);
}

function addTypeTestTypeSymbol(InitModuleContext cx, string symbol, t:ComplexSemType semType) {
    ComplexTypeDefn? existingDefn = cx.complexTypeDefns[semType];
    if existingDefn != () {
        addTypeAlias(cx, symbol, existingDefn);
    }
    else {
        _ = addComplexTypeDefn(cx, symbol, semType, "external");
    }
}

function addComplexTypeDefn(InitModuleContext cx, string symbol, t:ComplexSemType semType, llvm:Linkage linkage) returns llvm:ConstPointerValue {
    t:SplitSemType { all, some } = t:split(semType);
    int someBits = 0;
    llvm:ConstValue[] llSubtypes = [];
    foreach var [code, subtype] in some {
        if code == t:UT_LIST_RO || code == t:UT_MAPPING_RO || code == t:UT_TABLE_RO || code == t:UT_TABLE_RW {
            // these cannot occur for now, so ignore them
            continue;
        }
        someBits |= 1 << code;
        llSubtypes.push(getUniformSubtype(cx, code, subtype));
    }
    llvm:ConstValue subtypeArray = cx.llContext.constArray(cx.llTypes.uniformSubtypePtr, llSubtypes);
    llvm:ConstValue initValue = cx.llContext.constStruct([llvm:constInt(LLVM_BITSET, all), llvm:constInt(LLVM_BITSET, someBits), subtypeArray]);
    llvm:StructType llType = llvm:structType([LLVM_BITSET, LLVM_BITSET, llvm:arrayType(cx.llTypes.uniformSubtypePtr, llSubtypes.length())]);
    llvm:ConstPointerValue ptr = cx.llMod.addGlobal(llType, symbol, initializer=initValue, isConstant=true, linkage=linkage);
    cx.complexTypeDefns.add({ llType, ptr, semType });
    return ptr;
}

type SubtypeStruct record {|
    llvm:Type[] types;
    llvm:Value[] values;
|};

function getUniformSubtype(InitModuleContext cx, t:UniformTypeCode typeCode, t:ComplexSemType semType) returns llvm:ConstPointerValue {
    llvm:ConstPointerValue ptr;
    SubtypeDefn? existingDefn = cx.subtypeDefns[typeCode, semType];
    if existingDefn != () {
        ptr = existingDefn.ptr;
    }
    else {
        string symbol = subtypeDefnSymbol(cx.subtypeDefns.length());
        llvm:ConstValue? init = ();
        llvm:StructType llStructTy;
        if cx.inherentTypesComplete {
            SubtypeStruct sub = createSubtypeStruct(cx, typeCode, semType);
            llStructTy = llvm:structType(sub.types);
            init = cx.llContext.constStruct(sub.values);
        }
        else {
            llStructTy = cx.llContext.structCreateNamed(subtypeTypeDefnSymbol(cx.subtypeDefns.length()));
        }
        ptr = cx.llMod.addGlobal(llStructTy, symbol, initializer=init, align=SUBTYPE_ALIGN, isConstant=true, linkage="internal");
        SubtypeDefn newDefn = { typeCode, semType, ptr, structType: cx.inherentTypesComplete ? () : llStructTy };
        cx.subtypeDefns.add(newDefn);
    }
    return cx.llContext.constBitCast(ptr, cx.llTypes.uniformSubtypePtr); 
}

function finishSubtypeDefns(InitModuleContext cx) {
    foreach SubtypeDefn defn in cx.subtypeDefns {
        llvm:StructType? structType = defn.structType;
        if structType != () {
            SubtypeStruct sub = createSubtypeStruct(cx, defn.typeCode, defn.semType);
            cx.llContext.structSetBody(structType, sub.types);
            cx.llMod.setInitializer(defn.ptr, cx.llContext.constStruct(sub.values));
        }
    }
}

function createSubtypeStruct(InitModuleContext cx, t:UniformTypeCode typeCode, t:ComplexSemType semType) returns SubtypeStruct {
    // JBUG if we use a match statement for this, then we get an error for `ptr` being uninitialized
    if typeCode == t:UT_LIST_RW {
        return createListSubtypeStruct(cx, semType); 
    }
    else if typeCode == t:UT_MAPPING_RW {
        return createMappingSubtypeStruct(cx, semType); 
    }
    panic err:impossible(`subtypes of uniform type ${typeCode} are not implemented`);    
}

function createListSubtypeStruct(InitModuleContext cx, t:ComplexSemType semType) returns SubtypeStruct {
    t:ListAtomicType? lat = t:listAtomicTypeRw(cx.tc, semType);
    if lat != () {
        t:SemType rest = lat.rest;
        if rest is t:UniformTypeBitSet {
            return createArrayMapSubtypeStruct(cx, rest, TYPE_KIND_ARRAY);
        }
    }
    return createPrecomputedSubtypeStruct(cx, STRUCTURE_LIST, semType);
}

function createMappingSubtypeStruct(InitModuleContext cx, t:ComplexSemType semType) returns SubtypeStruct {
    t:MappingAtomicType? mat = t:mappingAtomicTypeRw(cx.tc, semType);
    if mat != () {
        t:SemType rest = mat.rest;
        if rest == t:NEVER {
            t:UniformTypeBitSet[] fieldTypes = [];
            foreach var ty in mat.types {
                if ty is t:UniformTypeBitSet {
                    fieldTypes.push(ty);
                }
                else {
                    break;
                }
            }
            if fieldTypes.length() == mat.types.length() {
                // all bitsets
                return createRecordSubtypeStruct(cx, mat.names, fieldTypes);     
            }
        }
        else if rest is t:UniformTypeBitSet && mat.names.length() == 0 {
            return createArrayMapSubtypeStruct(cx, rest, TYPE_KIND_MAP);
        }
    }
    return createPrecomputedSubtypeStruct(cx, STRUCTURE_MAPPING, semType);
}

function createPrecomputedSubtypeStruct(InitModuleContext cx, StructureBasicType basic, t:ComplexSemType ty) returns SubtypeStruct {
    llvm:ConstValue[] tids = from var itd in cx.inherentTypeDefns[basic] where t:isSubtype(cx.tc, itd.semType, ty) select llvm:constInt(LLVM_TID, itd.tid);
    return {
        types: [cx.llTypes.subtypeContainsFunctionPtr, "i32", llvm:arrayType(LLVM_TID, tids.length())],
        values: [getSubtypeContainsFunc(cx, TYPE_KIND_PRECOMPUTED), llvm:constInt("i32", tids.length()), cx.llContext.constArray(LLVM_TID, tids)]
    };
}

function createArrayMapSubtypeStruct(InitModuleContext cx, t:UniformTypeBitSet bitSet, TypeKindArrayOrMap arrayOrMap) returns SubtypeStruct {
    return {
        types: [cx.llTypes.subtypeContainsFunctionPtr, LLVM_BITSET],
        values: [getSubtypeContainsFunc(cx, arrayOrMap), llvm:constInt("i32", bitSet)]
    };
}

function createRecordSubtypeStruct(InitModuleContext cx, string[] fieldNames, t:UniformTypeBitSet[] fieldTypes) returns SubtypeStruct {
    // 0, fieldCount, fields
    final llvm:StructType llFieldType = llvm:structType([LLVM_TAGGED_PTR, LLVM_BITSET]);
    final int nFields = fieldNames.length();
    llvm:ConstValue[] llFields = [];
    foreach int i in 0 ..< fieldNames.length() {
        llFields.push(cx.llContext.constStruct([addInitString(cx, fieldNames[i]), llvm:constInt(LLVM_BITSET, fieldTypes[i])]));
    }
    return {
        types: [cx.llTypes.subtypeContainsFunctionPtr, "i32", llvm:arrayType(llFieldType, nFields)],
        values: [getSubtypeContainsFunc(cx, TYPE_KIND_RECORD), llvm:constInt("i32", nFields), cx.llContext.constArray(llFieldType, llFields)]
    };
}

function getListDescFunctionRefs(InitModuleContext cx, t:SemType memberType) returns FunctionRef[] {
    FunctionRef[] functionRefs = [];
    string prefix = memberTypeToListReprPrefix(memberType);
    foreach int i in 0 ..< listDescFuncSuffixes.length() {
        string suffix = listDescFuncSuffixes[i];
        string name = prefix + "_" + suffix;
        llvm:FunctionType llType = llListDescFuncTypes[i];
        FunctionRef ref;
        if listDescNullFuncNames.indexOf(name) == () {
            ref = getInitRuntimeFunction(cx, mangleRuntimeSymbol("list_" + name), llType);
        }
        else {
            ref = llvm:constNull(llvm:pointerType(llType));
        }
        functionRefs.push(ref);
    }
    return functionRefs;
}

function getSubtypeContainsFunc(InitModuleContext cx, TypeKind tk) returns llvm:FunctionDecl {
    llvm:FunctionDecl? existing = cx.typeTestFuncs[tk];
    if existing == () {
        llvm:FunctionDecl decl = cx.llMod.addFunctionDecl(mangleRuntimeSymbol(tk + "_subtype_contains"), cx.llTypes.subtypeContainsFunction);
        cx.typeTestFuncs[tk] = decl;
        return decl;
    }
    else {
       return existing;
    }
}

function addInitString(InitModuleContext cx, string str) returns llvm:ConstPointerValue {
    int index = cx.stringCount;
    cx.stringCount += 1;
    return addStringDefn(cx.llContext, cx.llMod, index, str);
}

function addTypeAlias(InitModuleContext cx, string sym, TypeDefn defn) {
    _ = cx.llMod.addAlias(defn.llType, defn.ptr, sym);
}

function structureBasicType(t:SemType semType) returns StructureBasicType? {
    if t:isSubtypeSimple(semType, t:LIST) {
        return STRUCTURE_LIST;
    }
    if t:isSubtypeSimple(semType, t:MAPPING) {
        return STRUCTURE_MAPPING;
    }
    return ();
}

function fillerDescSymbol(StructureBasicType basic, int i) returns string {
    if basic == STRUCTURE_LIST {
        return memberListDescSymbol(i);
    }
    else {
        return memberMappingDescSymbol(i);
    }
}

function getInitRuntimeFunction(InitModuleContext cx, string symbol, llvm:FunctionType llType) returns llvm:FunctionDecl {
    llvm:FunctionDecl? existingDecl = cx.runtimeFuncs[symbol];
    if existingDecl != () {
        return existingDecl;
    }
    else {
        llvm:FunctionDecl newDecl = cx.llMod.addFunctionDecl(symbol, llType);
        cx.runtimeFuncs[symbol] = newDecl;
        return newDecl;
    }
}
