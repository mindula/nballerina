@_bal_stack_guard = external global i8*
@_Bi04root0 = external constant {i32}
declare i8 addrspace(1)* @_bal_panic_construct(i64) cold
declare void @_bal_panic(i8 addrspace(1)*) noreturn cold
declare i8 addrspace(1)* @_bal_mapping_construct({i32}*, i64)
declare void @_bal_mapping_init_member(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)*)
declare i8 addrspace(1)* @_bal_int_to_tagged(i64)
declare i64 @_bal_mapping_inexact_set(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)*)
define void @_B04rootmain() !dbg !5 {
  %c = alloca i8 addrspace(1)*
  %1 = alloca i8 addrspace(1)*
  %m = alloca i8 addrspace(1)*
  %2 = alloca i8 addrspace(1)*
  %3 = alloca i8
  %4 = load i8*, i8** @_bal_stack_guard
  %5 = icmp ult i8* %3, %4
  br i1 %5, label %17, label %6
6:
  %7 = call i8 addrspace(1)* @_bal_mapping_construct({i32}* @_Bi04root0, i64 1)
  %8 = call i8 addrspace(1)* @_bal_int_to_tagged(i64 0)
  call void @_bal_mapping_init_member(i8 addrspace(1)* %7, i8 addrspace(1)* getelementptr(i8, i8 addrspace(1)* null, i64 3098476543630901097), i8 addrspace(1)* %8)
  store i8 addrspace(1)* %7, i8 addrspace(1)** %1
  %9 = load i8 addrspace(1)*, i8 addrspace(1)** %1
  store i8 addrspace(1)* %9, i8 addrspace(1)** %c
  store i8 addrspace(1)* getelementptr(i8, i8 addrspace(1)* null, i64 3098476543630901098), i8 addrspace(1)** %m
  %10 = load i8 addrspace(1)*, i8 addrspace(1)** %m
  %11 = load i8 addrspace(1)*, i8 addrspace(1)** %c
  %12 = call i8 addrspace(1)* @_bal_int_to_tagged(i64 8)
  %13 = call i64 @_bal_mapping_inexact_set(i8 addrspace(1)* %11, i8 addrspace(1)* %10, i8 addrspace(1)* %12)
  %14 = icmp eq i64 %13, 0
  br i1 %14, label %19, label %20
15:
  %16 = load i8 addrspace(1)*, i8 addrspace(1)** %2
  call void @_bal_panic(i8 addrspace(1)* %16)
  unreachable
17:
  %18 = call i8 addrspace(1)* @_bal_panic_construct(i64 1284), !dbg !7
  call void @_bal_panic(i8 addrspace(1)* %18)
  unreachable
19:
  ret void
20:
  %21 = or i64 %13, 2048
  %22 = call i8 addrspace(1)* @_bal_panic_construct(i64 %21), !dbg !7
  store i8 addrspace(1)* %22, i8 addrspace(1)** %2
  br label %15
}
!llvm.module.flags = !{!0}
!llvm.dbg.cu = !{!2}
!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !DIFile(filename:"../../../compiler/testSuite/11-nested/exact5-p.bal", directory:"")
!2 = distinct !DICompileUnit(language: DW_LANG_C99, file: !1, isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false)
!3 = !DISubroutineType(types: !4)
!4 = !{}
!5 = distinct !DISubprogram(name:"main", linkageName:"_B04rootmain", scope: !1, file: !1, line: 5, type: !3, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !2, retainedNodes: !6)
!6 = !{}
!7 = !DILocation(line: 0, column: 0, scope: !5)
