#map = affine_map<(d0) -> (d0 ceildiv STEP_PLACEHOLDER)>
func.func @matmul_broadcast_STEP_PLACEHOLDER(%a : memref<?x?xf32>, %b : memref<?x?xf32>, %c : memref<?x?xf32>) {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %step = arith.constant STEP_PLACEHOLDER : index
  %c0_f32 = arith.constant 0.0 : f32
  %c0_f32_vec = vector.splat %c0_f32 : vector<STEP_PLACEHOLDERxf32>

  %a_row = memref.dim %a, %c0 : memref<?x?xf32>
  %a_col = memref.dim %a, %c1 : memref<?x?xf32>
  %b_row = memref.dim %b, %c0 : memref<?x?xf32>
  %b_col = memref.dim %b, %c1 : memref<?x?xf32>

  affine.for %b_row_idx = 0 to %b_row {
    affine.for %a_row_idx = 0 to %a_row {
      affine.for %b_col_idx = 0 to #map(%b_col) {
        %a_ele = memref.load %a[%a_row_idx, %b_row_idx] : memref<?x?xf32>
        %a_vec = vector.broadcast %a_ele : f32 to vector<STEP_PLACEHOLDERxf32>
        // Check tail.
        %b_col_cur = arith.muli %b_col_idx, %step : index
        %tail_len = arith.subi %b_col, %b_col_cur : index
        %tail_flag = arith.cmpi sge, %tail_len, %step : index
        scf.if %tail_flag {
          %b_vec = affine.vector_load %b[%b_row_idx, %b_col_idx * STEP_PLACEHOLDER] : memref<?x?xf32>, vector<STEP_PLACEHOLDERxf32>
          %c_vec = affine.vector_load %c[%a_row_idx, %b_col_idx * STEP_PLACEHOLDER] : memref<?x?xf32>, vector<STEP_PLACEHOLDERxf32>
          %result_vec = vector.fma %a_vec, %b_vec, %c_vec : vector<STEP_PLACEHOLDERxf32>
          affine.vector_store %result_vec, %c[%a_row_idx, %b_col_idx * STEP_PLACEHOLDER] : memref<?x?xf32>, vector<STEP_PLACEHOLDERxf32>
        } else {
          %mask_vec = vector.create_mask %tail_len : vector<STEP_PLACEHOLDERxi1>
          %b_col_idx_tail = arith.muli %b_col_idx, %step : index
          %b_vec_tail = vector.maskedload %b[%b_row_idx, %b_col_idx_tail], %mask_vec, %c0_f32_vec : memref<?x?xf32>, vector<STEP_PLACEHOLDERxi1>, vector<STEP_PLACEHOLDERxf32> into vector<STEP_PLACEHOLDERxf32>
          %c_vec_tail = vector.maskedload %c[%a_row_idx, %b_col_idx_tail], %mask_vec, %c0_f32_vec : memref<?x?xf32>, vector<STEP_PLACEHOLDERxi1>, vector<STEP_PLACEHOLDERxf32> into vector<STEP_PLACEHOLDERxf32>
          %result_vec_tail = vector.fma %a_vec, %b_vec_tail, %c_vec_tail : vector<STEP_PLACEHOLDERxf32>
          vector.maskedstore %c[%a_row_idx, %b_col_idx_tail], %mask_vec, %result_vec_tail : memref<?x?xf32>, vector<STEP_PLACEHOLDERxi1>, vector<STEP_PLACEHOLDERxf32>
        }
      }
    }
  }
  return
}
