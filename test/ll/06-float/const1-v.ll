@_bal_stack_guard = external global i8*
declare i8 addrspace(1)* @_bal_panic_construct(i64) cold
declare void @_bal_panic(i8 addrspace(1)*) noreturn cold
declare i8 addrspace(1)* @_bal_float_to_tagged(double)
declare void @_Bb02ioprintln(i8 addrspace(1)*)
define void @_B04rootmain() !dbg !5 {
  %1 = alloca i8 addrspace(1)*
  %2 = alloca i8 addrspace(1)*
  %3 = alloca i8 addrspace(1)*
  %4 = alloca i8 addrspace(1)*
  %5 = alloca i8 addrspace(1)*
  %6 = alloca i8 addrspace(1)*
  %7 = alloca i8 addrspace(1)*
  %8 = alloca i8
  %9 = load i8*, i8** @_bal_stack_guard
  %10 = icmp ult i8* %8, %9
  br i1 %10, label %19, label %11
11:
  %12 = call i8 addrspace(1)* @_bal_float_to_tagged(double 3.0), !dbg !8
  call void @_Bb02ioprintln(i8 addrspace(1)* %12), !dbg !8
  store i8 addrspace(1)* null, i8 addrspace(1)** %1, !dbg !8
  %13 = call i8 addrspace(1)* @_bal_float_to_tagged(double 2.0), !dbg !9
  call void @_Bb02ioprintln(i8 addrspace(1)* %13), !dbg !9
  store i8 addrspace(1)* null, i8 addrspace(1)** %2, !dbg !9
  %14 = call i8 addrspace(1)* @_bal_float_to_tagged(double 4.0), !dbg !10
  call void @_Bb02ioprintln(i8 addrspace(1)* %14), !dbg !10
  store i8 addrspace(1)* null, i8 addrspace(1)** %3, !dbg !10
  %15 = call i8 addrspace(1)* @_bal_float_to_tagged(double 8.0), !dbg !11
  call void @_Bb02ioprintln(i8 addrspace(1)* %15), !dbg !11
  store i8 addrspace(1)* null, i8 addrspace(1)** %4, !dbg !11
  %16 = call i8 addrspace(1)* @_bal_float_to_tagged(double 3.5), !dbg !12
  call void @_Bb02ioprintln(i8 addrspace(1)* %16), !dbg !12
  store i8 addrspace(1)* null, i8 addrspace(1)** %5, !dbg !12
  %17 = call i8 addrspace(1)* @_bal_float_to_tagged(double 2.5), !dbg !13
  call void @_Bb02ioprintln(i8 addrspace(1)* %17), !dbg !13
  store i8 addrspace(1)* null, i8 addrspace(1)** %6, !dbg !13
  %18 = call i8 addrspace(1)* @_bal_float_to_tagged(double 3.75), !dbg !14
  call void @_Bb02ioprintln(i8 addrspace(1)* %18), !dbg !14
  store i8 addrspace(1)* null, i8 addrspace(1)** %7, !dbg !14
  ret void
19:
  %20 = call i8 addrspace(1)* @_bal_panic_construct(i64 3076), !dbg !7
  call void @_bal_panic(i8 addrspace(1)* %20)
  unreachable
}
!llvm.module.flags = !{!0}
!llvm.dbg.cu = !{!2}
!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !DIFile(filename:"../../../compiler/testSuite/06-float/const1-v.bal", directory:"")
!2 = distinct !DICompileUnit(language: DW_LANG_C99, file: !1, isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false)
!3 = !DISubroutineType(types: !4)
!4 = !{}
!5 = distinct !DISubprogram(name:"main", linkageName:"_B04rootmain", scope: !1, file: !1, line: 12, type: !3, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !2, retainedNodes: !6)
!6 = !{}
!7 = !DILocation(line: 0, column: 0, scope: !5)
!8 = !DILocation(line: 13, column: 4, scope: !5)
!9 = !DILocation(line: 14, column: 4, scope: !5)
!10 = !DILocation(line: 15, column: 4, scope: !5)
!11 = !DILocation(line: 16, column: 4, scope: !5)
!12 = !DILocation(line: 17, column: 4, scope: !5)
!13 = !DILocation(line: 18, column: 4, scope: !5)
!14 = !DILocation(line: 19, column: 4, scope: !5)
