declare {i64, i1} @llvm.sadd.with.overflow.i64 (i64, i64)
declare void @_Bio__println (i64)
declare void @_bal_panic (i64)
define void @_B_main () {
  %R0 = alloca i64, align 8
  %R1 = alloca i64, align 8
  %R2 = alloca i1, align 8
  %R3 = alloca i64, align 8
  %R4 = alloca i1, align 8
  %R5 = alloca i64, align 8
  %R6 = call i64 @_B_add (i64 2, i64 3)
  store i64 %R6, i64* %R0, align 8
  %R7 = load i64, i64* %R0, align 8
  store i64 %R7, i64* %R1, align 8
  %R8 = load i64, i64* %R1, align 8
  call void @_Bio__println (i64 %R8)
  store i1 0, i1* %R2, align 8
  %R9 = call i64 @_B_add (i64 20, i64 30)
  store i64 %R9, i64* %R3, align 8
  %R10 = load i64, i64* %R3, align 8
  call void @_Bio__println (i64 %R10)
  store i1 0, i1* %R4, align 8
  ret void
  %R11 = load i64, i64* %R5, align 8
  call void @_bal_panic (i64 %R11)
  unreachable
}
define internal i64 @_B_add (i64 %R0, i64 %R1) {
  %R2 = alloca i64, align 8
  %R3 = alloca i64, align 8
  %R4 = alloca i64, align 8
  %R5 = alloca i64, align 8
  store i64 %R0, i64* %R2, align 8
  store i64 %R1, i64* %R3, align 8
  %R6 = load i64, i64* %R2, align 8
  %R7 = load i64, i64* %R3, align 8
  %R8 = call {i64, i1} @llvm.sadd.with.overflow.i64 (i64 %R6, i64 %R7)
  %R9 = extractvalue {i64, i1} %R8, 1
  br i1 %R9, label %L3, label %L2
L1:
  %R12 = load i64, i64* %R5, align 8
  call void @_bal_panic (i64 %R12)
  unreachable
L2:
  %R10 = extractvalue {i64, i1} %R8, 0
  store i64 %R10, i64* %R4, align 8
  %R11 = load i64, i64* %R4, align 8
  ret i64 %R11
L3:
  store i64 1, i64* %R5, align 8
  br label %L1
}
