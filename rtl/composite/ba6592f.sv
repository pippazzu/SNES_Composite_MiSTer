// SPDX-License-Identifier: GPL-2.0-or-later
// BA6592F behavioural NTSC encoder, sampled at 12 times the subcarrier.
// Pin voltages are signed Q3.16, relative to the clamped black level.
// This is a datasheet model, not an extracted transistor netlist.
// The external YO->YI and colour-difference loops belong to the board.
module ba6592f (
    input wire clk, reset,
    input wire signed [18:0] ar, ag, ab,
    input wire sync_n, pcp_n, bfp_n,
    input wire [3:0] phase,
    input wire signed [18:0] yi, ryi, byi,
    output reg signed [18:0] yo, ryo, byo,
    output reg signed [18:0] vo, co
);
    // Conventional matrix; the datasheet specifies white and primary levels
    // but does not disclose its three individual luminance coefficients.
    wire signed [37:0] ym = ar * 18'sd19595 + ag * 18'sd38470 + ab * 18'sd7471;
    wire signed [18:0] y = ym >>> 16;
    wire signed [18:0] ry = ar - y;
    wire signed [18:0] by = ab - y;
    // Typical primary outputs: 0.42 V for red, 0.31 V for blue at 0.7 V in.
    wire signed [37:0] rym = ry * 18'sd56093;
    wire signed [37:0] bym = by * 18'sd32758;

    function automatic signed [13:0] sine(input [3:0] p);
        case(p)
            0,6: sine=0;
            1,5: sine=14'sd2048;
            2,4: sine=14'sd3547;
            3: sine=14'sd4096;
            7,11: sine=-14'sd2048;
            8,10: sine=-14'sd3547;
            9: sine=-14'sd4096;
            default: sine=0;
        endcase
    endfunction
    wire [3:0] quadrature = phase >= 9 ? phase - 4'd9 : phase + 4'd3;
    // Datasheet modulation gain is peak-to-peak output/input: amplitude
    // factors are 10^(10.5/20)/2 and 10^(11/20)/2. Ideal fundamental model.
    wire signed [37:0] rm = ryi * 18'sd109761;
    wire signed [37:0] bm = byi * 18'sd116265;
    wire signed [18:0] ra = rm >>> 16;
    wire signed [18:0] ba = bm >>> 16;
    wire signed [33:0] rmod = ra * sine(quadrature);
    wire signed [33:0] bmod = ba * sine(phase);
    wire signed [33:0] burst = -19'sd15073 * sine(phase); // 0.46 Vpp
    wire signed [18:0] chroma = bfp_n ? ((rmod + bmod) >>> 12) : (burst >>> 12);
    wire signed [38:0] lum = yi * 19'sd140434; // 1.5/0.7 typical YI->VO gain

    always @(posedge clk) begin
        if(reset) begin
            yo <= 0; ryo <= 0; byo <= 0; vo <= 0; co <= 0;
        end else begin
            yo <= sync_n ? (y <<< 1) : -19'sd36045; // 1.4 V white, -0.55 V sync
            ryo <= pcp_n ? (rym >>> 16) : 19'sd0;
            byo <= pcp_n ? (bym >>> 16) : 19'sd0;
            co <= chroma;
            vo <= (lum >>> 16) + chroma;
        end
    end
endmodule
