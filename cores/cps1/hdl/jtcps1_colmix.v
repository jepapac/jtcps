/*  This file is part of JTCPS1.
    JTCPS1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCPS1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCPS1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-1-2020 */

module jtcps1_colmix(
    input              rst,
    input              clk,
    input              pxl_cen,

    input   [ 3:0]     gfx_en,

    input   [10:0]     scr1_pxl,
    input   [10:0]     scr2_pxl,
    input   [10:0]     scr3_pxl,
    input   [ 6:0]     star0_pxl,
    input   [ 6:0]     star1_pxl,
    input   [ 8:0]     obj_pxl,

    // Layer has_priority
    input   [15:0]     layer_ctrl,
    input   [ 3:1]     scrdma_en,
    input   [ 7:0]     layer_mask0, // mask for enable bits
    input   [ 7:0]     layer_mask1,
    input   [ 7:0]     layer_mask2,
    input   [ 7:0]     layer_mask3,
    input   [ 7:0]     layer_mask4,
    input   [15:0]     prio0,
    input   [15:0]     prio1,
    input   [15:0]     prio2,
    input   [15:0]     prio3,

    output reg [ 1:0]  star_en,
    // Palette RAM
    output reg [11:0]  pxl
);

// These are the top four bits written by CPS-B to each
// pixel of the frame buffer. These are likely sent by CPS-A
// via pins XS[4:0] and CPS-B encodes them
// 000 = OBJ ?
// 001 = SCROLL 1
// 010 = SCROLL 2
// 011 = SCROLL 3
// 100 = STAR FIELD

localparam [2:0] OBJ=3'b0, SCR1=3'b1, SCR2=3'd2, SCR3=3'd3, STA0=3'd4, STA1=3'd5;

/////////////////////////// LAYER MUX ////////////////////////////////////////////
function [13:0] layer_mux;
    input [ 8:0] obj;
    input [10:0] scr1;
    input [10:0] scr2;
    input [10:0] scr3;
    input [ 1:0] sel;

    layer_mux =  sel==2'b00 ? {      2'b00,  OBJ, obj }   :
                (sel==2'b01 ? { scr1[10:9], SCR1, scr1[8:0]}   :
                (sel==2'b10 ? { scr2[10:9], SCR2, scr2[8:0]}   :
                (sel==2'b11 ? { scr3[10:9], SCR3, scr3[8:0]}   : 14'h3fff )));
endfunction

(*keep*) wire [4:0] lyren = {
    |(layer_mask4[5:0] & layer_ctrl[5:0]), // Star layer 1
    |(layer_mask3[5:0] & layer_ctrl[5:0]), // Star layer 0
    |(layer_mask2[5:0] & layer_ctrl[5:0]),
    |(layer_mask1[5:0] & layer_ctrl[5:0]),
    |(layer_mask0[5:0] & layer_ctrl[5:0])
};

always @(posedge clk) star_en <= lyren[4:3];

//reg [4:0] lyren2, lyren3;

// OBJ layer cannot be disabled by hardware
wire [ 8:0] obj_mask  = { obj_pxl[8:4],   obj_pxl[3:0]  | {4{~gfx_en[3]}} };
wire [10:0] scr1_mask = { scr1_pxl[10:4], scr1_pxl[3:0] | {4{~(lyren[0]& scrdma_en[1] & gfx_en[0])}} };
wire [10:0] scr2_mask = { scr2_pxl[10:4], scr2_pxl[3:0] | {4{~(lyren[1]& scrdma_en[2] & gfx_en[1])}} };
wire [10:0] scr3_mask = { scr3_pxl[10:4], scr3_pxl[3:0] | {4{~(lyren[2]& scrdma_en[3] & gfx_en[2])}} };
wire [ 6:0] sta0_mask = { star0_pxl[6:4], star0_pxl[3:0] | {4{~lyren[3]}} };
wire [ 6:0] sta1_mask = { star1_pxl[6:4], star1_pxl[3:0] | {4{~lyren[4]}} };

localparam QW = 14*5;
reg [13:0] lyr5, lyr4, lyr3, lyr2, lyr1, lyr0;
reg [QW-1:0] lyr_queue;
reg [11:0] pre_pxl;

`ifdef SIMULATION
wire [2:0] lyr0_code = lyr0[11:9];
wire [2:0] lyr1_code = lyr1[11:9];
wire [2:0] lyr2_code = lyr2[11:9];
wire [2:0] lyr3_code = lyr3[11:9];
`endif
always @(posedge clk) if(pxl_cen) begin
    lyr5 <= { 2'b00, STA1, 2'b0, sta1_mask };
    lyr4 <= { 2'b00, STA0, 2'b0, sta0_mask };
    lyr3 <= layer_mux( obj_mask, scr1_mask, scr2_mask, scr3_mask, layer_ctrl[ 7: 6] );
    lyr2 <= layer_mux( obj_mask, scr1_mask, scr2_mask, scr3_mask, layer_ctrl[ 9: 8] );
    lyr1 <= layer_mux( obj_mask, scr1_mask, scr2_mask, scr3_mask, layer_ctrl[11:10] );
    lyr0 <= layer_mux( obj_mask, scr1_mask, scr2_mask, scr3_mask, layer_ctrl[13:12] );
    //lyren2[5:4] <= lyren[5:4];
    //lyren2[3] <= lyren[ layer_ctrl[7:6] ];
    //lyren2[2] <= lyren[ layer_ctrl[7:6] ];
    //lyren2[1] <= lyren[ layer_ctrl[7:6] ];
    //lyren2[0] <= lyren[ layer_ctrl[7:6] ];
end

reg [13:0] below;
reg        has_priority;

always @(*) begin
    case( below[13:12] )
        0: has_priority = prio0[ below[3:0] ];
        1: has_priority = prio1[ below[3:0] ];
        2: has_priority = prio2[ below[3:0] ];
        3: has_priority = prio3[ below[3:0] ];
    endcase
    if( below[11] ) has_priority=0; // Stars never have has_priority over objects
end

`ifdef CPS2
localparam [13:0] BLANK_PXL = { 2'b11, 12'hBFF }; // according to DL-0921 RE but it doesn't look
// good on CPS1/CPS1.5 games. CPS2 is fine with that
`else
localparam [13:0] BLANK_PXL = ~14'd0;
`endif

always @(posedge clk) begin
    if(pxl_cen) begin
        pxl <= pre_pxl;
        case( OBJ )
            lyr0[11:9]: below <= lyr1;
            lyr1[11:9]: below <= lyr2;
            lyr2[11:9]: below <= lyr3;
            default: below <= ~14'h0;
        endcase
    end else begin
        if( lyr0[3:0]!=4'hf && (lyr0[11:9]!=OBJ || !has_priority) )
            pre_pxl <= lyr0[11:0];
        else if( lyr1[3:0]!=4'hf && (lyr1[11:9]!=OBJ || !has_priority) )
            pre_pxl <= lyr1[11:0];
        else if( lyr2[3:0]!=4'hf && (lyr2[11:9]!=OBJ || !has_priority) )
            pre_pxl <= lyr2[11:0];
        else if( lyr3[3:0]!=4'hf )
            pre_pxl <= lyr3[11:0];
        else if( lyr4[3:0]!=4'hf )
            pre_pxl <= lyr4[11:0];
        else if( lyr5[3:0]!=4'hf )
            pre_pxl <= lyr5[11:0];
        else
            pre_pxl <= BLANK_PXL[11:0];
    end
end

endmodule
