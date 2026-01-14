package tpu_pkg
    localparam integer MAC_ARRAY_SIZE = 4; // 4x4 pe array
    localparam integer DATA_WIDTH = 16;
    localparam integer ACC_WIDTH = 32;
    localparam integer MEM_DEPTH = 4096;
    localparam integer MEM_WIDTH = $clog2(MEM_DEPTH);
endpackage