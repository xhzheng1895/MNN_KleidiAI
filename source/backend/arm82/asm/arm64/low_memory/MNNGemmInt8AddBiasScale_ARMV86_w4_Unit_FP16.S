//
//  MNNGemmInt8AddBiasScale_ARMV86_w4_Unit_FP16.S
//  MNN
//
//  Created by MNN on 2022/09/26.
//  Copyright © 2018, Alibaba Group Holding Limited
//

#if defined(__aarch64__)
#include "MNNAsmGlobal.h"

.text
.align 5

.macro SET_0_5 d0, d1, d2, d3, d4
    movi \d0\().16b, #0
    movi \d1\().16b, #0
    movi \d2\().16b, #0
    movi \d3\().16b, #0
    movi \d4\().16b, #0
.endm

.macro SET_0_4 d0, d1, d2, d3
    movi \d0\().16b, #0
    movi \d1\().16b, #0
    movi \d2\().16b, #0
    movi \d3\().16b, #0
.endm

.macro SET_0_2 d0, d1
    movi \d0\().16b, #0
    movi \d1\().16b, #0
.endm

.macro ADD_BIAS_FLOAT d0, d1, d2, d3, z0
    fadd \d0\().4s, \d0\().4s, \z0\().4s
    fadd \d1\().4s, \d1\().4s, \z0\().4s
    fadd \d2\().4s, \d2\().4s, \z0\().4s
    fadd \d3\().4s, \d3\().4s, \z0\().4s
.endm

.macro ReLU_FP16 s0, s1, s2, s3, z0, z1 // z0:min z1:max
    fmin \s0\().8h, \s0\().8h, \z1\().8h
    fmin \s1\().8h, \s1\().8h, \z1\().8h
    fmin \s2\().8h, \s2\().8h, \z1\().8h
    fmin \s3\().8h, \s3\().8h, \z1\().8h
    fmax \s0\().8h, \s0\().8h, \z0\().8h
    fmax \s1\().8h, \s1\().8h, \z0\().8h
    fmax \s2\().8h, \s2\().8h, \z0\().8h
    fmax \s3\().8h, \s3\().8h, \z0\().8h
.endm

.macro ReLU_FP16_2 s0, s1, z0, z1 // z0:min z1:max
    fmin \s0\().8h, \s0\().8h, \z1\().8h
    fmin \s1\().8h, \s1\().8h, \z1\().8h
    fmax \s0\().8h, \s0\().8h, \z0\().8h
    fmax \s1\().8h, \s1\().8h, \z0\().8h
.endm
.macro Int32ToFloat z0, z1, z2, z3
    scvtf \z0\().4s, \z0\().4s
    scvtf \z1\().4s, \z1\().4s
    scvtf \z2\().4s, \z2\().4s
    scvtf \z3\().4s, \z3\().4s
.endm
.macro MUL_SCALE s, d0, d1, d2, d3
    fmul \d0\().4s, \d0\().4s, \s\().4s
    fmul \d1\().4s, \d1\().4s, \s\().4s
    fmul \d2\().4s, \d2\().4s, \s\().4s
    fmul \d3\().4s, \d3\().4s, \s\().4s
.endm
.macro MUL_EXTRA_SCALE s, d0, d1, d2, d3
    fmul \d0\().4s, \d0\().4s, \s\().s[0]
    fmul \d1\().4s, \d1\().4s, \s\().s[1]
    fmul \d2\().4s, \d2\().4s, \s\().s[2]
    fmul \d3\().4s, \d3\().4s, \s\().s[3]
.endm
.macro MLA_WEIGHTZERO d0, s0, s1, idx // idx for xKernelSum
    fmla \d0\().4s, \s1\().4s, \s0\().s[\idx]
.endm
.macro Float32ToHalf s0, s1, s2, s3, d0, d1
    fcvtn \d0\().4h,  \s0\().4s
    fcvtn2 \d0\().8h, \s1\().4s
    fcvtn \d1\().4h,  \s2\().4s
    fcvtn2 \d1\().8h, \s3\().4s
.endm

asm_function MNNGemmInt8AddBiasScale_ARMV86_w4_Unit_FP16
/* 
struct QuanPostTreatParameters {
    const float* scale;
    const float* biasFloat;
    int32_t maxValue;
    int32_t minValue;
    int32_t useInt8 = 1; // Save result as int8_t dataType; otherwise float32.
    float roundValuePos = 0.5f;
    float roundValueNeg = -0.5f;
    float* srcKernelSum;
    float* weightQuanBias;
    float* fp32minmax;
    ssize_t blockNum = 1;
    const int32_t* bias;
    const float* extraScale = nullptr;
};
*/
//void MNNGemmInt8AddBiasScale_ARMV86_w4_Unit(int8_t* dst, const int8_t* src,
//    const int8_t* weight, size_t src_depth_quad, size_t dst_step, size_t dst_depth_quad,
// const QuanPostTreatParameters* parameters, size_t realDstCount);

//Auto: x0:dst, x1:src, x2:weight, x3:src_depth_quad, x4:dst_step
//x5:dst_depth_quad, x6: parameters, x7: realDstCount

//Load from x7: x8: scale, x9: biasFloat, x27: srcKernelSum, x28: weightQuanBias, x14: fp32minmax
/* For FP16
UNIT = 8;
SRC_UNIT = 8;
DST_XUNIT = 10;
 */
ldr x9, [x6, #8]

stp d14, d15, [sp, #(-16 * 10)]!
stp d12, d13, [sp, #(16 * 1)]
stp d10, d11, [sp, #(16 * 2)]
stp d8,  d9,  [sp, #(16 * 3)]
stp x21, x22, [sp, #(16 * 4)]
stp x19, x20, [sp, #(16 * 5)]
stp x23, x24, [sp, #(16 * 6)]
stp x25, x26, [sp, #(16 * 7)]
stp x27, x28, [sp, #(16 * 8)]
ldr x27, [x6, #40] // srcKernelSum
ldr x14, [x6, #56]  // fp32minmax

lsl x22, x7, #3 // eDest * GEMM_INT8_SRC_UNIT
mov x21, #16 // sizeof(float16_t) * UNIT
ldr x23, [x6, #80] // extra scale
ldr x15, [x6, #96]
mov x10, x15 // tag dst address
mov x25, x23

TILE_10:
    cmp x7, #10
    blt TILE_8
sub x4, x4, #128 // For Tile10
LoopDz_TILE_10:
    mov x11, x1 // src
    mov x13, x3 // src_depth_quad
    
    movi v2.16b, #15

    SET_0_5 v12, v16, v20, v24, v28 // oc:0,1,0,1
    SET_0_5 v13, v17, v21, v25, v29 // oc:2,3,2,3
    SET_0_5 v14, v18, v22, v26, v30 // oc:4,5,4,5
    SET_0_5 v15, v19, v23, v27, v31 // oc:6,7,6,7

LoopSz_TILE_10:
    ld1 {v0.16b, v1.16b}, [x2], #32                    // weight
    ld1 {v3.16b, v4.16b, v5.16b, v6.16b}, [x11], #64    // src: E0-E9
    ld1 {v7.16b}, [x11], #16
    // int4->int8
    ushr v8.16b, v0.16b, #4 // oc:0-1
    ushr v9.16b, v1.16b, #4 // oc:2-3
    and v10.16b, v0.16b, v2.16b // oc:4-5
    and v11.16b, v1.16b, v2.16b // oc:6-7

    subs x13, x13, #1
    .inst 0x4e88a46c // smmla v12.4s, v3.16b, v8.16b // tile0-oc0, tile0-oc1, tile1-oc0, tile1-oc1
    .inst 0x4e89a46d // smmla v13.4s, v3.16b, v9.16b // tile0-oc2, tile0-oc3, tile1-oc2, tile1-oc3
    .inst 0x4e8aa46e // smmla v14.4s, v3.16b, v10.16b // tile0-oc4, tile0-oc5, tile1-oc4, tile1-oc5
    .inst 0x4e8ba46f // smmla v15.4s, v3.16b, v11.16b // tile0-oc6, tile0-oc7, tile1-oc6, tile1-oc7
    
    .inst 0x4e88a490 // smmla v16.4s, v4.16b, v8.16b // tile2-oc0, tile2-oc1, tile3-oc0, tile3-oc1
    .inst 0x4e89a491 // smmla v17.4s, v4.16b, v9.16b // tile2-oc2, tile2-oc3, tile3-oc2, tile3-oc3
    .inst 0x4e8aa492 // smmla v18.4s, v4.16b, v10.16b // tile2-oc4, tile2-oc5, tile3-oc4, tile3-oc5
    .inst 0x4e8ba493 // smmla v19.4s, v4.16b, v11.16b // tile2-oc6, tile2-oc7, tile3-oc6, tile3-oc7
    
    .inst 0x4e88a4b4 // smmla v20.4s, v5.16b, v8.16b // tile4-oc0, tile4-oc1, tile5-oc0, tile5-oc1
    .inst 0x4e89a4b5 // smmla v21.4s, v5.16b, v9.16b // tile4-oc2, tile4-oc3, tile5-oc2, tile5-oc3
    .inst 0x4e8aa4b6 // smmla v22.4s, v5.16b, v10.16b // tile4-oc4, tile4-oc5, tile5-oc4, tile5-oc5
    .inst 0x4e8ba4b7 // smmla v23.4s, v5.16b, v11.16b // tile4-oc6, tile4-oc7, tile5-oc6, tile5-oc7

    .inst 0x4e88a4d8 // smmla v24.4s, v6.16b, v8.16b // tile6-oc0, tile6-oc1, tile7-oc0, tile7-oc1
    .inst 0x4e89a4d9 // smmla v25.4s, v6.16b, v9.16b // tile6-oc2, tile6-oc3, tile7-oc2, tile7-oc3
    .inst 0x4e8aa4da // smmla v26.4s, v6.16b, v10.16b // tile6-oc4, tile6-oc5, tile7-oc4, tile7-oc5
    .inst 0x4e8ba4db // smmla v27.4s, v6.16b, v11.16b // tile6-oc6, tile6-oc7, tile7-oc6, tile7-oc7

    .inst 0x4e88a4fc // smmla v28.4s, v7.16b, v8.16b // tile8-oc0, tile8-oc1, tile9-oc0, tile9-oc1
    .inst 0x4e89a4fd // smmla v29.4s, v7.16b, v9.16b // tile8-oc2, tile8-oc3, tile9-oc2, tile9-oc3
    .inst 0x4e8aa4fe // smmla v30.4s, v7.16b, v10.16b // tile8-oc4, tile8-oc5, tile9-oc4, tile9-oc5
    .inst 0x4e8ba4ff // smmla v31.4s, v7.16b, v11.16b // tile8-oc6, tile8-oc7, tile9-oc6, tile9-oc7
    bne LoopSz_TILE_10
LoopSzEnd_TILE_10:
    // transpose
    uzp1 v0.2d, v12.2d, v13.2d // E0: oc:0-3
    uzp2 v1.2d, v12.2d, v13.2d // E1: oc:0-3
    uzp1 v2.2d, v14.2d, v15.2d // E0: oc:4-7
    uzp2 v3.2d, v14.2d, v15.2d // E1: oc:4-7

    uzp1 v4.2d, v16.2d, v17.2d
    uzp2 v5.2d, v16.2d, v17.2d
    uzp1 v6.2d, v18.2d, v19.2d
    uzp2 v7.2d, v18.2d, v19.2d

    uzp1 v8.2d, v20.2d, v21.2d
    uzp2 v9.2d, v20.2d, v21.2d
    uzp1 v10.2d, v22.2d, v23.2d
    uzp2 v11.2d, v22.2d, v23.2d

    uzp1 v12.2d, v24.2d, v25.2d
    uzp2 v13.2d, v24.2d, v25.2d
    uzp1 v14.2d, v26.2d, v27.2d
    uzp2 v15.2d, v26.2d, v27.2d

    uzp1 v16.2d, v28.2d, v29.2d
    uzp2 v17.2d, v28.2d, v29.2d
    uzp1 v18.2d, v30.2d, v31.2d
    uzp2 v19.2d, v30.2d, v31.2d
    Int32ToFloat v0, v1, v2, v3
    Int32ToFloat v4, v5, v6, v7
    Int32ToFloat v8, v9, v10, v11
    Int32ToFloat v12, v13, v14, v15
    Int32ToFloat v16, v17, v18, v19

Tile10Quan:
    ld1 {v20.4s, v21.4s}, [x2], #32  // scale
    ld1 {v22.4s, v23.4s}, [x27], #32 // x kernel sum
    ld1 {v24.d}[0], [x27]
    sub x27, x27, #32
    ld1 {v25.4s, v26.4s}, [x2], #32 // weight quan zeropoint
    MUL_SCALE v20, v0, v1, v4, v5
    MUL_SCALE v21, v2, v3, v6, v7
    MUL_SCALE v20, v8, v9, v12, v13
    MUL_SCALE v21, v10, v11, v14, v15
    fmul v16.4s, v16.4s, v20.4s
    fmul v17.4s, v17.4s, v20.4s
    fmul v18.4s, v18.4s, v21.4s
    fmul v19.4s, v19.4s, v21.4s

    cbz x25, TILE10_MLA
    ld1 {v27.4s, v28.4s}, [x23], #32
    ld1 {v29.d}[0], [x23]
    MUL_EXTRA_SCALE v27, v0, v1, v4, v5
    MUL_EXTRA_SCALE v28, v8, v9, v12, v13
    MUL_EXTRA_SCALE v27, v2, v3, v6, v7
    MUL_EXTRA_SCALE v28, v10, v11, v14, v15
    fmul v16.4s, v16.4s, v29.s[0]
    fmul v17.4s, v17.4s, v29.s[1]
    fmul v18.4s, v18.4s, v29.s[0]
    fmul v19.4s, v19.4s, v29.s[1]
    sub x23, x23, #32
    
    TILE10_MLA:
    MLA_WEIGHTZERO v0, v22, v25, 0 // tile:0, oc:0-3
    MLA_WEIGHTZERO v1, v22, v25, 1 // tile:1, oc:0-3
    MLA_WEIGHTZERO v2, v22, v26, 0 // tile:0, oc:4-7
    MLA_WEIGHTZERO v3, v22, v26, 1 // tile:1, oc:4-7

    MLA_WEIGHTZERO v4, v22, v25, 2 // tile:2, oc:0-3
    MLA_WEIGHTZERO v5, v22, v25, 3 // tile:3, oc:0-3
    MLA_WEIGHTZERO v6, v22, v26, 2 // tile:2, oc:4-7
    MLA_WEIGHTZERO v7, v22, v26, 3 // tile:3, oc:4-7

    MLA_WEIGHTZERO v8,  v23, v25, 0 // tile:4, oc:0-3
    MLA_WEIGHTZERO v9,  v23, v25, 1 // tile:5, oc:0-3
    MLA_WEIGHTZERO v10, v23, v26, 0 // tile:4, oc:4-7
    MLA_WEIGHTZERO v11, v23, v26, 1 // tile:5, oc:4-7

    MLA_WEIGHTZERO v12, v23, v25, 2 // tile:6, oc:0-3
    MLA_WEIGHTZERO v13, v23, v25, 3 // tile:7, oc:0-3
    MLA_WEIGHTZERO v14, v23, v26, 2 // tile:6, oc:4-7
    MLA_WEIGHTZERO v15, v23, v26, 3 // tile:7, oc:4-7

    MLA_WEIGHTZERO v16, v24, v25, 0 // tile:8, oc:0-3
    MLA_WEIGHTZERO v17, v24, v25, 1 // tile:9, oc:0-3
    MLA_WEIGHTZERO v18, v24, v26, 0 // tile:8, oc:4-7
    MLA_WEIGHTZERO v19, v24, v26, 1 // tile:9, oc:4-7
    

    cbz x9, TILE10_ADD_DSTV
    TILE10_ADD_BIAS:
    ld1 {v20.4s, v21.4s}, [x9], #32  // bias
    ADD_BIAS_FLOAT v0, v1, v4, v5, v20
    ADD_BIAS_FLOAT v2, v3, v6, v7, v21
    ADD_BIAS_FLOAT v8, v9, v12, v13, v20
    ADD_BIAS_FLOAT v10, v11, v14, v15, v21
    fadd v16.4s, v16.4s, v20.4s
    fadd v17.4s, v17.4s, v20.4s
    fadd v18.4s, v18.4s, v21.4s
    fadd v19.4s, v19.4s, v21.4s
    cbnz x0, TILE10_POST // to Relu post
    b TILE10_TEMP_BUFFER

    TILE10_ADD_DSTV:
    ld1 {v20.4s, v21.4s, v22.4s, v23.4s}, [x10], #64
    ld1 {v24.4s, v25.4s, v26.4s, v27.4s}, [x10], #64
    ld1 {v28.4s, v29.4s, v30.4s, v31.4s}, [x10], #64
    fadd v0.4s, v0.4s, v20.4s
    fadd v1.4s, v1.4s, v21.4s
    fadd v2.4s, v2.4s, v22.4s
    fadd v3.4s, v3.4s, v23.4s
    fadd v4.4s, v4.4s, v24.4s
    fadd v5.4s, v5.4s, v25.4s
    fadd v6.4s, v6.4s, v26.4s
    fadd v7.4s, v7.4s, v27.4s
    ld1 {v20.4s, v21.4s, v22.4s, v23.4s}, [x10], #64
    ld1 {v24.4s, v25.4s, v26.4s, v27.4s}, [x10], #64
    fadd v8.4s, v8.4s, v28.4s
    fadd v9.4s, v9.4s, v29.4s
    fadd v10.4s, v10.4s, v30.4s
    fadd v11.4s, v11.4s, v31.4s
    fadd v12.4s, v12.4s, v20.4s
    fadd v13.4s, v13.4s, v21.4s
    fadd v14.4s, v14.4s, v22.4s
    fadd v15.4s, v15.4s, v23.4s
    fadd v16.4s, v16.4s, v24.4s
    fadd v17.4s, v17.4s, v25.4s
    fadd v18.4s, v18.4s, v26.4s
    fadd v19.4s, v19.4s, v27.4s
    cbnz x0, TILE10_POST

    TILE10_TEMP_BUFFER:
    st1 {v0.4s, v1.4s, v2.4s, v3.4s}, [x15], #64
    st1 {v4.4s, v5.4s, v6.4s, v7.4s}, [x15], #64
    st1 {v8.4s, v9.4s, v10.4s, v11.4s}, [x15], #64
    st1 {v12.4s, v13.4s, v14.4s, v15.4s}, [x15], #64
    st1 {v16.4s, v17.4s, v18.4s, v19.4s}, [x15], #64
    b Tile10LoopCheck

    TILE10_POST:
    // float32->float16
    Float32ToHalf v0, v2, v1, v3, v20, v21
    Float32ToHalf v4, v6, v5, v7, v22, v23
    Float32ToHalf v8, v10, v9, v11, v24, v25
    Float32ToHalf v12, v14, v13, v15, v26, v27
    Float32ToHalf v16, v18, v17, v19, v30, v31

    cbz x14, TILE10_STORE
    ld1r {v29.8h}, [x14], #2 // f32 min
    ld1r {v28.8h}, [x14] // f32 max
    sub x14, x14, #2

    ReLU_FP16 v20, v21, v22, v23, v29, v28
    ReLU_FP16 v24, v25, v26, v27, v29, v28
    ReLU_FP16_2 v30, v31, v29, v28

    TILE10_STORE:
    
    st1 {v20.8h, v21.8h, v22.8h, v23.8h}, [x0], #64
    st1 {v24.8h, v25.8h, v26.8h, v27.8h}, [x0], #64
    st1 {v30.8h, v31.8h}, [x0], x4

Tile10LoopCheck:
    subs x5, x5, #1  // dz--
    bne LoopDz_TILE_10
    b End

TILE_8:
    movi v30.16b, #15
    cmp x7, #8
    blt TILE_4
    sub x8, x4, #64 // just for Tile8, revert it when Tile8end
    mov x24, x5 // dst_depth_quad
    mov x26, x0 // dst
    mov x12, x2 // weight
    mov x20, x9 // bias
LoopDz_TILE_8:
    mov x11, x1 // src
    mov x13, x3 // src_depth_quad

    SET_0_4 v12, v16, v20, v24 // oc:0,1,0,1
    SET_0_4 v13, v17, v21, v25 // oc:2,3,2,3
    SET_0_4 v14, v18, v22, v26 // oc:4,5,4,5
    SET_0_4 v15, v19, v23, v27 // oc:6,7,6,7
LoopSz_TILE_8:
    ld1 {v0.16b, v1.16b}, [x12], #32                    // weight
    ld1 {v3.16b, v4.16b, v5.16b, v6.16b}, [x11], x22    // src: E0-E7

    // int4->int8
    subs x13, x13, #1
    ushr v8.16b, v0.16b, #4 // oc:0-1
    ushr v9.16b, v1.16b, #4 // oc:2-3
    and v10.16b, v0.16b, v30.16b // oc:4-5
    and v11.16b, v1.16b, v30.16b // oc:6-7

    .inst 0x4e88a46c // smmla v12.4s, v3.16b, v8.16b // tile0-oc0, tile0-oc1, tile1-oc0, tile1-oc1
    .inst 0x4e89a46d // smmla v13.4s, v3.16b, v9.16b // tile0-oc2, tile0-oc3, tile1-oc2, tile1-oc3
    .inst 0x4e8aa46e // smmla v14.4s, v3.16b, v10.16b // tile0-oc4, tile0-oc5, tile1-oc4, tile1-oc5
    .inst 0x4e8ba46f // smmla v15.4s, v3.16b, v11.16b // tile0-oc6, tile0-oc7, tile1-oc6, tile1-oc7
    
    .inst 0x4e88a490 // smmla v16.4s, v4.16b, v8.16b // tile2-oc0, tile2-oc1, tile3-oc0, tile3-oc1
    .inst 0x4e89a491 // smmla v17.4s, v4.16b, v9.16b // tile2-oc2, tile2-oc3, tile3-oc2, tile3-oc3
    .inst 0x4e8aa492 // smmla v18.4s, v4.16b, v10.16b // tile2-oc4, tile2-oc5, tile3-oc4, tile3-oc5
    .inst 0x4e8ba493 // smmla v19.4s, v4.16b, v11.16b // tile2-oc6, tile2-oc7, tile3-oc6, tile3-oc7
    
    .inst 0x4e88a4b4 // smmla v20.4s, v5.16b, v8.16b // tile4-oc0, tile4-oc1, tile5-oc0, tile5-oc1
    .inst 0x4e89a4b5 // smmla v21.4s, v5.16b, v9.16b // tile4-oc2, tile4-oc3, tile5-oc2, tile5-oc3
    .inst 0x4e8aa4b6 // smmla v22.4s, v5.16b, v10.16b // tile4-oc4, tile4-oc5, tile5-oc4, tile5-oc5
    .inst 0x4e8ba4b7 // smmla v23.4s, v5.16b, v11.16b // tile4-oc6, tile4-oc7, tile5-oc6, tile5-oc7

    .inst 0x4e88a4d8 // smmla v24.4s, v6.16b, v8.16b // tile6-oc0, tile6-oc1, tile7-oc0, tile7-oc1
    .inst 0x4e89a4d9 // smmla v25.4s, v6.16b, v9.16b // tile6-oc2, tile6-oc3, tile7-oc2, tile7-oc3
    .inst 0x4e8aa4da // smmla v26.4s, v6.16b, v10.16b // tile6-oc4, tile6-oc5, tile7-oc4, tile7-oc5
    .inst 0x4e8ba4db // smmla v27.4s, v6.16b, v11.16b // tile6-oc6, tile6-oc7, tile7-oc6, tile7-oc7
    
    bne LoopSz_TILE_8
LoopSzEnd_TILE_8:
    sub x24, x24, #1
    uzp1 v0.2d, v12.2d, v13.2d // E0: oc:0-3
    uzp2 v1.2d, v12.2d, v13.2d // E1: oc:0-3
    uzp1 v2.2d, v14.2d, v15.2d // E0: oc:4-7
    uzp2 v3.2d, v14.2d, v15.2d // E1: oc:4-7

    uzp1 v4.2d, v16.2d, v17.2d
    uzp2 v5.2d, v16.2d, v17.2d
    uzp1 v6.2d, v18.2d, v19.2d
    uzp2 v7.2d, v18.2d, v19.2d

    uzp1 v8.2d, v20.2d, v21.2d
    uzp2 v9.2d, v20.2d, v21.2d
    uzp1 v10.2d, v22.2d, v23.2d
    uzp2 v11.2d, v22.2d, v23.2d

    uzp1 v12.2d, v24.2d, v25.2d
    uzp2 v13.2d, v24.2d, v25.2d
    uzp1 v14.2d, v26.2d, v27.2d
    uzp2 v15.2d, v26.2d, v27.2d
    Int32ToFloat v0, v1, v2, v3
    Int32ToFloat v4, v5, v6, v7
    Int32ToFloat v8, v9, v10, v11
    Int32ToFloat v12, v13, v14, v15

Tile8Quan:
    ld1 {v20.4s, v21.4s}, [x12], #32  // scale
    ld1 {v22.4s, v23.4s}, [x27] // x kernel sum
    ld1 {v25.4s, v26.4s}, [x12], #32 // weight quan zeropoint
    MUL_SCALE v20, v0, v1, v4, v5
    MUL_SCALE v21, v2, v3, v6, v7
    MUL_SCALE v20, v8, v9, v12, v13
    MUL_SCALE v21, v10, v11, v14, v15

    cbz x25, TILE8_MLA
    ld1 {v27.4s, v28.4s}, [x23]
    MUL_EXTRA_SCALE v27, v0, v1, v4, v5
    MUL_EXTRA_SCALE v28, v8, v9, v12, v13
    MUL_EXTRA_SCALE v27, v2, v3, v6, v7
    MUL_EXTRA_SCALE v28, v10, v11, v14, v15

    TILE8_MLA:
    MLA_WEIGHTZERO v0, v22, v25, 0 // tile:0, oc:0-3
    MLA_WEIGHTZERO v1, v22, v25, 1 // tile:1, oc:0-3
    MLA_WEIGHTZERO v2, v22, v26, 0 // tile:0, oc:4-7
    MLA_WEIGHTZERO v3, v22, v26, 1 // tile:1, oc:4-7

    MLA_WEIGHTZERO v4, v22, v25, 2 // tile:2, oc:0-3
    MLA_WEIGHTZERO v5, v22, v25, 3 // tile:3, oc:0-3
    MLA_WEIGHTZERO v6, v22, v26, 2 // tile:2, oc:4-7
    MLA_WEIGHTZERO v7, v22, v26, 3 // tile:3, oc:4-7

    MLA_WEIGHTZERO v8,  v23, v25, 0 // tile:4, oc:0-3
    MLA_WEIGHTZERO v9,  v23, v25, 1 // tile:5, oc:0-3
    MLA_WEIGHTZERO v10, v23, v26, 0 // tile:4, oc:4-7
    MLA_WEIGHTZERO v11, v23, v26, 1 // tile:5, oc:4-7

    MLA_WEIGHTZERO v12, v23, v25, 2 // tile:6, oc:0-3
    MLA_WEIGHTZERO v13, v23, v25, 3 // tile:7, oc:0-3
    MLA_WEIGHTZERO v14, v23, v26, 2 // tile:6, oc:4-7
    MLA_WEIGHTZERO v15, v23, v26, 3 // tile:7, oc:4-7

    cbz x9, TILE8_ADD_DSTV
    TILE8_ADD_BIAS:
    ld1 {v16.4s, v17.4s}, [x20], #32 // bias
    ADD_BIAS_FLOAT v0, v1, v4, v5, v16
    ADD_BIAS_FLOAT v2, v3, v6, v7, v17
    ADD_BIAS_FLOAT v8, v9, v12, v13, v16
    ADD_BIAS_FLOAT v10, v11, v14, v15, v17
    cbnz x0, TILE8_POST
    b TILE8_TEMP_BUFFER
    
    TILE8_ADD_DSTV:
    ld1 {v16.4s, v17.4s, v18.4s, v19.4s}, [x10], #64
    ld1 {v20.4s, v21.4s, v22.4s, v23.4s}, [x10], #64
    ld1 {v24.4s, v25.4s, v26.4s, v27.4s}, [x10], #64
    fadd v0.4s, v0.4s, v16.4s
    fadd v1.4s, v1.4s, v17.4s
    fadd v2.4s, v2.4s, v18.4s
    fadd v3.4s, v3.4s, v19.4s
    ld1 {v16.4s, v17.4s, v18.4s, v19.4s}, [x10], #64
    fadd v4.4s, v4.4s, v20.4s
    fadd v5.4s, v5.4s, v21.4s
    fadd v6.4s, v6.4s, v22.4s
    fadd v7.4s, v7.4s, v23.4s
    fadd v8.4s, v8.4s, v24.4s
    fadd v9.4s, v9.4s, v25.4s
    fadd v10.4s, v10.4s, v26.4s
    fadd v11.4s, v11.4s, v27.4s
    fadd v12.4s, v12.4s, v16.4s
    fadd v13.4s, v13.4s, v17.4s
    fadd v14.4s, v14.4s, v18.4s
    fadd v15.4s, v15.4s, v19.4s
    cbnz x0, TILE8_POST

    TILE8_TEMP_BUFFER:
    st1 {v0.4s, v1.4s, v2.4s, v3.4s}, [x15], #64
    st1 {v4.4s, v5.4s, v6.4s, v7.4s}, [x15], #64
    st1 {v8.4s, v9.4s, v10.4s, v11.4s}, [x15], #64
    st1 {v12.4s, v13.4s, v14.4s, v15.4s}, [x15], #64
    b Tile8LoopCheck

    TILE8_POST:
    // float32->float16
    Float32ToHalf v0, v2, v1, v3, v20, v21
    Float32ToHalf v4, v6, v5, v7, v22, v23
    Float32ToHalf v8, v10, v9, v11, v24, v25
    Float32ToHalf v12, v14, v13, v15, v26, v27
    cbz x14, TILE8_STORE
    ld1r {v29.8h}, [x14], #2 // f32 min
    ld1r {v28.8h}, [x14] // f32 max
    sub x14, x14, #2
    ReLU_FP16 v20, v21, v22, v23, v29, v28
    ReLU_FP16 v24, v25, v26, v27, v29, v28

    TILE8_STORE:
    st1 {v20.8h, v21.8h, v22.8h, v23.8h}, [x26], #64
    st1 {v24.8h, v25.8h, v26.8h, v27.8h}, [x26], x8

Tile8LoopCheck:
    cmp x24, #1
    bge LoopDz_TILE_8
cbz x0, Tile8End
add x0, x0, x21, LSL #3
Tile8End:
    sub x7, x7, #8
    add x23, x23, #32
    add x1, x1, #64
    add x27, x27, #32

TILE_4:
    cmp x7, #4
    blt TILE_2
    mov x24, x5 // dst_depth_quad
    mov x26, x0 // dst
    mov x12, x2 // weight
    mov x20, x9 // bias
LoopDz_TILE_4:
    mov x11, x1 // src
    mov x13, x3 // src_depth_quad

    SET_0_2 v12, v16 // oc:0,1,0,1
    SET_0_2 v13, v17 // oc:2,3,2,3
    SET_0_2 v14, v18 // oc:4,5,4,5
    SET_0_2 v15, v19 // oc:6,7,6,7
LoopSz_TILE_4:
    ld1 {v2.16b, v3.16b}, [x12], #32   // weight
    ld1 {v4.16b, v5.16b}, [x11], x22   // src
    // int4->int8
    ushr v8.16b, v2.16b, #4
    ushr v9.16b, v3.16b, #4
    and v10.16b, v2.16b, v30.16b
    and v11.16b, v3.16b, v30.16b
    subs x13, x13, #1
    .inst 0x4e88a48c // smmla v12.4s, v4.16b, v8.16b // tile0-oc0, tile0-oc1, tile1-oc0, tile1-oc1
    .inst 0x4e89a48d // smmla v13.4s, v4.16b, v9.16b // tile0-oc2, tile0-oc3, tile1-oc2, tile1-oc3
    .inst 0x4e8aa48e // smmla v14.4s, v4.16b, v10.16b // tile0-oc4, tile0-oc5, tile1-oc4, tile1-oc5
    .inst 0x4e8ba48f // smmla v15.4s, v4.16b, v11.16b // tile0-oc6, tile0-oc7, tile1-oc6, tile1-oc7
    
    .inst 0x4e88a4b0 // smmla v16.4s, v5.16b, v8.16b // tile2-oc0, tile2-oc1, tile3-oc0, tile3-oc1
    .inst 0x4e89a4b1 // smmla v17.4s, v5.16b, v9.16b // tile2-oc2, tile2-oc3, tile3-oc2, tile3-oc3
    .inst 0x4e8aa4b2 // smmla v18.4s, v5.16b, v10.16b // tile2-oc4, tile2-oc5, tile3-oc4, tile3-oc5
    .inst 0x4e8ba4b3 // smmla v19.4s, v5.16b, v11.16b // tile2-oc6, tile2-oc7, tile3-oc6, tile3-oc7

    bne LoopSz_TILE_4
LoopSzEnd_TILE_4:
    sub x24, x24, #1
    uzp1 v0.2d, v12.2d, v13.2d // E0: oc:0-3
    uzp2 v1.2d, v12.2d, v13.2d // E1: oc:0-3
    uzp1 v2.2d, v14.2d, v15.2d // E0: oc:4-7
    uzp2 v3.2d, v14.2d, v15.2d // E1: oc:4-7

    uzp1 v4.2d, v16.2d, v17.2d
    uzp2 v5.2d, v16.2d, v17.2d
    uzp1 v6.2d, v18.2d, v19.2d
    uzp2 v7.2d, v18.2d, v19.2d
    Int32ToFloat v0, v1, v2, v3
    Int32ToFloat v4, v5, v6, v7

Tile4Quan:
    ld1 {v20.4s, v21.4s}, [x12], #32  // scale
    ld1 {v22.4s}, [x27] // x kernel sum
    ld1 {v25.4s, v26.4s}, [x12], #32 // weight quan zeropoint
    MUL_SCALE v20, v0, v1, v4, v5
    MUL_SCALE v21, v2, v3, v6, v7

    cbz x25, TILE4_MLA
    ld1 {v27.4s}, [x23]
    MUL_EXTRA_SCALE v27, v0, v1, v4, v5
    MUL_EXTRA_SCALE v27, v2, v3, v6, v7

    TILE4_MLA:
    MLA_WEIGHTZERO v0, v22, v25, 0 // tile:0, oc:0-3
    MLA_WEIGHTZERO v1, v22, v25, 1 // tile:1, oc:0-3
    MLA_WEIGHTZERO v2, v22, v26, 0 // tile:0, oc:4-7
    MLA_WEIGHTZERO v3, v22, v26, 1 // tile:1, oc:4-7

    MLA_WEIGHTZERO v4, v22, v25, 2 // tile:2, oc:0-3
    MLA_WEIGHTZERO v5, v22, v25, 3 // tile:3, oc:0-3
    MLA_WEIGHTZERO v6, v22, v26, 2 // tile:2, oc:4-7
    MLA_WEIGHTZERO v7, v22, v26, 3 // tile:3, oc:4-7

    cbz x9, TILE4_ADD_DSTV
    TILE4_ADD_BIAS:
    ld1 {v16.4s, v17.4s}, [x20], #32 // bias
    ADD_BIAS_FLOAT v0, v1, v4, v5, v16
    ADD_BIAS_FLOAT v2, v3, v6, v7, v17
    cbnz x0, TILE4_POST
    b TILE4_TEMP_BUFFER

    TILE4_ADD_DSTV:
    ld1 {v20.4s, v21.4s, v22.4s, v23.4s}, [x10], #64
    ld1 {v24.4s, v25.4s, v26.4s, v27.4s}, [x10], #64
    fadd v0.4s, v0.4s, v20.4s
    fadd v1.4s, v1.4s, v21.4s
    fadd v2.4s, v2.4s, v22.4s
    fadd v3.4s, v3.4s, v23.4s
    fadd v4.4s, v4.4s, v24.4s
    fadd v5.4s, v5.4s, v25.4s
    fadd v6.4s, v6.4s, v26.4s
    fadd v7.4s, v7.4s, v27.4s
    cbnz x0, TILE4_POST

    TILE4_TEMP_BUFFER:
    st1 {v0.4s, v1.4s, v2.4s, v3.4s}, [x15], #64
    st1 {v4.4s, v5.4s, v6.4s, v7.4s}, [x15], #64
    b Tile4LoopCheck

    TILE4_POST:
     // float32->float16
    Float32ToHalf v0, v2, v1, v3, v20, v21
    Float32ToHalf v4, v6, v5, v7, v22, v23
    cbz x14, TILE4_STORE
    ld1r {v29.8h}, [x14], #2 // f32 min
    ld1r {v28.8h}, [x14] // f32 max
    sub x14, x14, #2
    ReLU_FP16 v20, v21, v22, v23, v29, v28

    TILE4_STORE:
    st1 {v20.8h, v21.8h, v22.8h, v23.8h}, [x26], x4

Tile4LoopCheck:
    cmp x24, #1
    bge LoopDz_TILE_4
cbz x0, Tile4End
add x0, x0, x21, LSL #2
Tile4End:
    sub x7, x7, #4
    add x1, x1, #32
    add x27, x27, #16
    add x23, x23, #16

TILE_2:
    cmp x7, #2
    blt TILE_1
    mov x24, x5 // dst_depth_quad
    mov x26, x0 // dst
    mov x12, x2 // weight
    mov x20, x9 // bias
LoopDz_TILE_2:
    mov x11, x1 // src
    mov x13, x3 // src_depth_quad

    SET_0_4 v12, v13, v14, v15
LoopSz_TILE_2:
    ld1 {v2.16b, v3.16b}, [x12], #32   // weight
    ld1 {v4.16b}, [x11], x22           // src
    // int4->int8
    ushr v8.16b, v2.16b, #4
    ushr v9.16b, v3.16b, #4
    and v10.16b, v2.16b, v30.16b
    and v11.16b, v3.16b, v30.16b

    .inst 0x4e88a48c // smmla v12.4s, v4.16b, v8.16b // tile0-oc0, tile0-oc1, tile1-oc0, tile1-oc1
    .inst 0x4e89a48d // smmla v13.4s, v4.16b, v9.16b // tile0-oc2, tile0-oc3, tile1-oc2, tile1-oc3
    .inst 0x4e8aa48e // smmla v14.4s, v4.16b, v10.16b // tile0-oc4, tile0-oc5, tile1-oc4, tile1-oc5
    .inst 0x4e8ba48f // smmla v15.4s, v4.16b, v11.16b // tile0-oc6, tile0-oc7, tile1-oc6, tile1-oc7
    subs x13, x13, #1
    bne LoopSz_TILE_2
LoopSzEnd_TILE_2:
    sub x24, x24, #1
    uzp1 v0.2d, v12.2d, v13.2d // E0: oc:0-3
    uzp2 v1.2d, v12.2d, v13.2d // E1: oc:0-3
    uzp1 v2.2d, v14.2d, v15.2d // E0: oc:4-7
    uzp2 v3.2d, v14.2d, v15.2d // E1: oc:4-7
    Int32ToFloat v0, v1, v2, v3

Tile2Quan:
    ld1 {v20.4s, v21.4s}, [x12], #32  // scale
    ld1 {v22.d}[0], [x27] // x kernel sum
    ld1 {v25.4s, v26.4s}, [x12], #32 // weight quan zeropoint
    fmul v0.4s, v0.4s, v20.4s
    fmul v1.4s, v1.4s, v20.4s
    fmul v2.4s, v2.4s, v21.4s
    fmul v3.4s, v3.4s, v21.4s

    cbz x25, TILE2_MLA
    ld1 {v27.d}[0], [x23]
    fmul v0.4s, v0.4s, v27.s[0]
    fmul v1.4s, v1.4s, v27.s[1]
    fmul v2.4s, v2.4s, v27.s[0]
    fmul v3.4s, v3.4s, v27.s[1]

    TILE2_MLA:
    MLA_WEIGHTZERO v0, v22, v25, 0 // tile:0, oc:0-3
    MLA_WEIGHTZERO v1, v22, v25, 1 // tile:1, oc:0-3
    MLA_WEIGHTZERO v2, v22, v26, 0 // tile:0, oc:4-7
    MLA_WEIGHTZERO v3, v22, v26, 1 // tile:1, oc:4-7

    cbz x9, TILE2_ADD_DSTV
    TILE2_ADD_BIAS:
    ld1 {v16.4s, v17.4s}, [x20], #32 // bias
    fadd v0.4s, v0.4s, v16.4s
    fadd v1.4s, v1.4s, v16.4s
    fadd v2.4s, v2.4s, v17.4s
    fadd v3.4s, v3.4s, v17.4s
    cbnz x0, TILE2_POST
    b TILE2_TEMP_BUFFER

    TILE2_ADD_DSTV:
    ld1 {v4.4s, v5.4s, v6.4s, v7.4s}, [x10], #64
    fadd v0.4s, v0.4s, v4.4s
    fadd v1.4s, v1.4s, v5.4s
    fadd v2.4s, v2.4s, v6.4s
    fadd v3.4s, v3.4s, v7.4s
    cbnz x0, TILE2_POST

    TILE2_TEMP_BUFFER:
    st1 {v0.4s, v1.4s, v2.4s, v3.4s}, [x15], #64
    b Tile2LoopCheck

    TILE2_POST:
    // float32->float16
    Float32ToHalf v0, v2, v1, v3, v20, v21
    cbz x14, TILE2_STORE
    ld1r {v29.8h}, [x14], #2 // f32 min
    ld1r {v28.8h}, [x14] // f32 max
    sub x14, x14, #2
    fmax v20.8h, v20.8h, v29.8h
    fmax v21.8h, v21.8h, v29.8h
    fmin v20.8h, v20.8h, v28.8h
    fmin v21.8h, v21.8h, v28.8h

    TILE2_STORE:
    st1 {v20.8h, v21.8h}, [x26], x4

Tile2LoopCheck:
    cmp x24, #1
    bge LoopDz_TILE_2
cbz x0, Tile2End
add x0, x0, x21, LSL #1
Tile2End:
    sub x7, x7, #2
    add x1, x1, #16
    add x27, x27, #8
    add x23, x23, #8

TILE_1:

    cmp x7, #1
    blt End
    mov x24, x5 // dst_depth_quad
    mov x26, x0 // dst
    mov x12, x2 // weight
    mov x20, x9 // bias
LoopDz_TILE_1:
    mov x11, x1 // src
    mov x13, x3 // src_depth_quad

    movi v16.4s, #0 // oc:0,1,0,1
    movi v17.4s, #0 // oc:2,3,2,3
    movi v18.4s, #0 // oc:4,5,4,5
    movi v19.4s, #0 // oc:6,7,6,7

cmp x22, #8
bne LoopSz1_TILE_1_lu1
cmp x13, #4
blt LoopSz1_TILE_1_lu1

LoopSz1_TILE_1_lu4:
    ld1 {v5.16b, v6.16b, v7.16b, v8.16b}, [x12], #64     // weight
    ld1 {v9.16b, v10.16b, v11.16b, v12.16b}, [x12], #64
    ld1 {v0.8b, v1.8b, v2.8b, v3.8b}, [x11], #32         // src

    // int4->int8
    ushr v4.16b, v5.16b, #4
    ushr v14.16b, v6.16b, #4
    and v13.16b, v5.16b, v30.16b
    and v15.16b, v6.16b, v30.16b

    ushr v20.16b, v7.16b, #4
    ushr v21.16b, v8.16b, #4
    and v22.16b, v7.16b, v30.16b
    and v23.16b, v8.16b, v30.16b

    ushr v24.16b, v9.16b, #4
    ushr v25.16b, v10.16b, #4
    and v26.16b, v9.16b, v30.16b
    and v27.16b, v10.16b, v30.16b

    ushr v5.16b, v11.16b, #4
    ushr v6.16b, v12.16b, #4
    and v7.16b, v11.16b, v30.16b
    and v8.16b, v12.16b, v30.16b

    sub x13, x13, #4

    .inst 0x4e84a410 // smmla v16.4s, v0.16b, v4.16b
    .inst 0x4e8ea411 // smmla v17.4s, v0.16b, v14.16b
    .inst 0x4e8da412 // smmla v18.4s, v0.16b, v13.16b
    .inst 0x4e8fa413 // smmla v19.4s, v0.16b, v15.16b

    .inst 0x4e94a430 // smmla v16.4s, v1.16b, v20.16b
    .inst 0x4e95a431 // smmla v17.4s, v1.16b, v21.16b
    .inst 0x4e96a432 // smmla v18.4s, v1.16b, v22.16b
    .inst 0x4e97a433 // smmla v19.4s, v1.16b, v23.16b
    cmp x13, #4
    .inst 0x4e98a450 // smmla v16.4s, v2.16b, v24.16b
    .inst 0x4e99a451 // smmla v17.4s, v2.16b, v25.16b
    .inst 0x4e9aa452 // smmla v18.4s, v2.16b, v26.16b
    .inst 0x4e9ba453 // smmla v19.4s, v2.16b, v27.16b

    .inst 0x4e85a470 // smmla v16.4s, v3.16b, v5.16b
    .inst 0x4e86a471 // smmla v17.4s, v3.16b, v6.16b
    .inst 0x4e87a472 // smmla v18.4s, v3.16b, v7.16b
    .inst 0x4e88a473 // smmla v19.4s, v3.16b, v8.16b
    
    bge LoopSz1_TILE_1_lu4
    cbz x13, LoopSzEnd_TILE_1

LoopSz1_TILE_1_lu1:
    ld1 {v13.16b, v14.16b}, [x12], #32   // weight
    ld1 {v2.8b}, [x11], x22              // src
    // int4->int8
    ushr v0.16b, v13.16b, #4
    and v3.16b, v13.16b, v30.16b
    ushr v1.16b, v14.16b, #4
    and v4.16b, v14.16b, v30.16b
    subs x13, x13, #1

    .inst 0x4e80a450 // smmla v16.4s, v2.16b, v0.16b
    .inst 0x4e81a451 // smmla v17.4s, v2.16b, v1.16b
    .inst 0x4e83a452 // smmla v18.4s, v2.16b, v3.16b
    .inst 0x4e84a453 // smmla v19.4s, v2.16b, v4.16b
    
    bne LoopSz1_TILE_1_lu1

LoopSzEnd_TILE_1:
    sub x24, x24, #1
    uzp1 v25.2d, v16.2d, v17.2d
    uzp1 v26.2d, v18.2d, v19.2d
    scvtf v25.4s, v25.4s
    scvtf v26.4s, v26.4s

Tile1Quan:
    ld1 {v0.4s, v1.4s}, [x12], #32  // scale
    ld1 {v6.s}[0], [x27] // x kernel sum
    ld1 {v8.4s, v9.4s}, [x12], #32 // weight quan zeropoint
    fmul v25.4s, v25.4s, v0.4s
    fmul v26.4s, v26.4s, v1.4s

    cbz x25, TILE1_MLA
    ld1 {v4.s}[0], [x23]
    fmul v25.4s, v25.4s, v4.s[0]
    fmul v26.4s, v26.4s, v4.s[0]
    TILE1_MLA:
    MLA_WEIGHTZERO v25, v6, v8, 0 // tile:0, oc:0-3
    MLA_WEIGHTZERO v26, v6, v9, 0 // tile:0, oc:4-7

    cbz x9, TILE1_ADD_DSTV
    TILE1_ADD_BIAS:
    ld1 {v16.4s, v17.4s}, [x20], #32 // bias
    fadd v25.4s, v25.4s, v16.4s
    fadd v26.4s, v26.4s, v17.4s
    cbnz x0, TILE1_POST
    b TILE1_TEMP_BUFFER

    TILE1_ADD_DSTV:
    ld1 {v16.4s, v17.4s}, [x10], #32
    fadd v25.4s, v25.4s, v16.4s
    fadd v26.4s, v26.4s, v17.4s
    cbnz x0, TILE1_POST

    TILE1_TEMP_BUFFER:
    st1 {v25.4s, v26.4s}, [x15], #32
    b Tile1LoopEnd

    TILE1_POST:
    fcvtn v0.4h, v25.4s
    fcvtn2 v0.8h, v26.4s
    cbz x14, TILE1_STORE
    ld1r {v29.8h}, [x14], #2 // f32 min
    ld1r {v28.8h}, [x14] // f32 max
    sub x14, x14, #2
    fmax v0.8h, v0.8h, v29.8h
    fmin v0.8h, v0.8h, v28.8h
    TILE1_STORE:
    st1 {v0.8h}, [x26], x4

Tile1LoopEnd:
    cmp x24, #1
    bge LoopDz_TILE_1

End:
ldp x27, x28, [sp, #(16 * 8)]
ldp x25, x26, [sp, #(16 * 7)]
ldp x23, x24, [sp, #(16 * 6)]
ldp x19, x20, [sp, #(16 * 5)]
ldp x21, x22, [sp, #(16 * 4)]
ldp d8,  d9,  [sp, #(16 * 3)]
ldp d10, d11, [sp, #(16 * 2)]
ldp d12, d13, [sp, #(16 * 1)]
ldp d14, d15, [sp], #(16 * 10)
ret

#endif // __aarch64__
