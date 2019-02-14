library verilog;
use verilog.vl_types.all;
entity sdram_controller is
    generic(
        ROW_WIDTH       : integer := 13;
        COL_WIDTH       : integer := 9;
        BANK_WIDTH      : integer := 2;
        SDRADDR_WIDTH   : vl_notype;
        HADDR_WIDTH     : vl_notype;
        CLK_FREQUENCY   : integer := 133;
        REFRESH_TIME    : integer := 32;
        REFRESH_COUNT   : integer := 8192
    );
    port(
        wr_addr         : in     vl_logic_vector;
        wr_data         : in     vl_logic_vector(15 downto 0);
        wr_enable       : in     vl_logic;
        rd_addr         : in     vl_logic_vector;
        rd_data         : out    vl_logic_vector(15 downto 0);
        rd_ready        : out    vl_logic;
        rd_enable       : in     vl_logic;
        busy            : out    vl_logic;
        rst_n           : in     vl_logic;
        clk             : in     vl_logic;
        addr            : out    vl_logic_vector;
        bank_addr       : out    vl_logic_vector;
        data            : inout  vl_logic_vector(15 downto 0);
        clock_enable    : out    vl_logic;
        cs_n            : out    vl_logic;
        ras_n           : out    vl_logic;
        cas_n           : out    vl_logic;
        we_n            : out    vl_logic;
        data_mask_low   : out    vl_logic;
        data_mask_high  : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of ROW_WIDTH : constant is 1;
    attribute mti_svvh_generic_type of COL_WIDTH : constant is 1;
    attribute mti_svvh_generic_type of BANK_WIDTH : constant is 1;
    attribute mti_svvh_generic_type of SDRADDR_WIDTH : constant is 3;
    attribute mti_svvh_generic_type of HADDR_WIDTH : constant is 3;
    attribute mti_svvh_generic_type of CLK_FREQUENCY : constant is 1;
    attribute mti_svvh_generic_type of REFRESH_TIME : constant is 1;
    attribute mti_svvh_generic_type of REFRESH_COUNT : constant is 1;
end sdram_controller;
