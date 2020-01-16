`timescale 1ns/1ps

module test;

reg         rst, clk, start, vram_ok, rom_ok=1'b1;
reg  [ 7:0] v;

reg  [15:0] vram_base=16'h9000, hpos=16'hffc0, vpos=16'h0, vram_data;
reg  [31:0] rom_data;
wire        done, vram_cs, rom_cs, buf_wr;
wire [22:0] rom_addr;
wire [23:0] vram_addr;
reg  [23:0] last_vram;
wire [ 8:0] buf_addr;
wire [ 7:0] buf_data;
reg  [15:0] vram[0:98303]; // 17 bits
reg  [16:0] vram_dec;
wire [ 2:0] buf_cs;
wire [ 4:1] gfx_cen;

assign      buf_cs[0] = &{ vram_addr[23:16] ^ 8'b0110_1111 };
assign      buf_cs[1] = &{ vram_addr[23:16] ^ 8'b0110_1110 };
assign      buf_cs[2] = &{ vram_addr[23:16] ^ 8'b0110_1101 };

always @(*) begin
    case( buf_cs )
        3'b001: vram_dec[16:15] = 2'b00;
        3'b010: vram_dec[16:15] = 2'b01;
        3'b100: vram_dec[16:15] = 2'b10;
    endcase    
    vram_dec[14:0] = vram_addr[14:0];
end

jtcps1_tilemap UUT(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .v          ( {1'b0, v }    ),
    .vram_base  ( vram_base     ),
    .hpos       ( hpos          ),
    .vpos       ( vpos          ),
    .start      ( start         ),
    .done       ( done          ),
    .vram_addr  ( vram_addr     ),
    .vram_data  ( vram_data     ),
    .vram_ok    ( vram_ok       ),
    .vram_cs    ( vram_cs       ),
    .rom_addr   ( rom_addr      ),
    .rom_data   ( rom_data      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),
    .buf_addr   ( buf_addr      ),
    .buf_data   ( buf_data      ),
    .buf_wr     ( buf_wr        )
);

jtcps1_gfx_pal u_palb(
    .a  ( rom_addr[22:10] ),
    .cen( gfx_cen         )
);

initial begin
    rst = 1'b0;
    #20 rst = 1'b1;
    #400 rst = 1'b0;
end

initial begin
    clk = 1'b0;
    forever #10.417 clk = ~clk;
end

initial begin
    $readmemh("vram.hex",vram);
end

integer pxlcnt, framecnt;

always @(posedge clk, posedge rst) begin
    if(rst) begin
        pxlcnt <= 0;
        framecnt <= 0;
        v <= 8'd0;
        vram_data <= 16'd0;
        vram_ok   <= 1'b0;
        start     <= 1'b1;
    end else begin
        start <= 1'b0;
        last_vram <= vram_addr;
        vram_ok   <= last_vram == vram_addr;
        vram_data <= |buf_cs ?  vram[ vram_dec ] : ~16'h0;
        pxlcnt <= pxlcnt+1;
        if(pxlcnt==3124) begin
            pxlcnt <= 0;
            v     <= v+1;
            start <= 1;
            if(&v) begin
                framecnt <= framecnt+1;
            end
        end
        if ( framecnt==2 ) $finish;
    end
end

//`ifdef DUMP
`ifndef NCVERILOG
    initial begin
        $dumpfile("test.lxt");
        $dumpvars(0,test);
        $dumpon;
    end
`else
    initial begin
        $shm_open("test.shm");
        $shm_probe(test,"AS");
    end
`endif
//`endif

endmodule
