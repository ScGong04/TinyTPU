package tpu_pkg;
    localparam integer MAC_ARRAY_SIZE = 4; 
    localparam integer DATA_WIDTH = 16;
    localparam integer ACC_WIDTH = 32;
    localparam integer MEM_DEPTH = 4096;
    localparam integer ADDR_WIDTH = $clog2(MEM_DEPTH);

    localparam integer WEIGHT_BASE = 0;
    localparam integer ACT_BASE    = 1024;
    localparam integer RESULT_BASE = 2048;
endpackage