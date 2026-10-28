// SPDX-License-Identifier: GPL-2.0-or-later
// Empirical multi-chip S-PPU2 RGB settling, at 42.95454 MHz.
// Covell's output traces show slower settling toward intermediate levels.
// This is a provisional envelope fit, NOT a DAC netlist: 55 ns endpoint
// time constant, 140 ns at midscale, smooth symmetric interpolation.
// It omits code-dependent glitches, ringing and brightness-reference dynamics.
// See COMPOSITE.md for measurement provenance and calibration limits.
module snes_ppu2_rgb (
    input wire clk, reset,
    input wire [7:0] r, g, b,
    output wire signed [18:0] ar, ag, ab
);
    snes_ppu2_channel red   (.clk(clk), .reset(reset), .code(r), .voltage(ar));
    snes_ppu2_channel green (.clk(clk), .reset(reset), .code(g), .voltage(ag));
    snes_ppu2_channel blue  (.clk(clk), .reset(reset), .code(b), .voltage(ab));
endmodule

module snes_ppu2_channel (
    input wire clk, reset,
    input wire [7:0] code,
    output wire signed [18:0] voltage
);
    // Fold the 32 target-level bins around midscale. Coefficients are
    // round(65536*(1-exp(-Ts/tau))), tau=55+340*x*(1-x) ns, x=bin/31.
    wire [3:0] level = code[7] ? ~code[6:3] : code[6:3];
    reg signed [16:0] alpha;
    always_comb begin
        case(level)
            4'd0: alpha=17'sd22617;
            4'd1: alpha=17'sd19575;
            4'd2: alpha=17'sd17385;
            4'd3: alpha=17'sd15747;
            4'd4: alpha=17'sd14484;
            4'd5: alpha=17'sd13492;
            4'd6: alpha=17'sd12701;
            4'd7: alpha=17'sd12064;
            4'd8: alpha=17'sd11548;
            4'd9: alpha=17'sd11132;
            4'd10: alpha=17'sd10799;
            4'd11: alpha=17'sd10536;
            4'd12: alpha=17'sd10334;
            4'd13: alpha=17'sd10188;
            4'd14: alpha=17'sd10093;
            4'd15: alpha=17'sd10046;
        endcase
    end
    reg [15:0] state;
    wire [15:0] target = code * 16'd180; // nominal encoder range, 0..0.7 V
    wire signed [16:0] delta = $signed({1'b0,target}) - $signed({1'b0,state});
    wire signed [33:0] step = delta * alpha;
    wire signed [33:0] rounded = step + 34'sd32768;
    always @(posedge clk) begin
        if(reset) state <= 0;
        else state <= $signed({1'b0,state}) + (rounded >>> 16);
    end
    assign voltage = $signed({3'b000,state});
endmodule

