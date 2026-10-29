// SPDX-License-Identifier: GPL-2.0-or-later
// Shared multi-chip PPU2 response. Controls track the two source registers;
// the separate presentation register does not slow console execution.
module snes_rgb_output (
    input wire clk, reset,
    input wire [7:0] r, g, b,
    input wire hs, vs, hde, vde, burst_n, field_in,
    output wire signed [18:0] ar, ag, ab,
    output wire sync_n, gate_n,
    output wire [3:0] phase,
    output reg pix, hs_out, vs_out, hb_out, vb_out, field_out,
    output reg pix2,   // every second clock, pix included: the composite pixel
    output reg [7:0] r_out, g_out, b_out
);
    reg [7:0] rp, gp, bp;
    reg [1:0] hp, vp, hd, vd, gate, fields;
    reg [3:0] carrier, phase_1, phase_2;
    always @(posedge clk) begin
        if(reset) begin
            rp<=0;gp<=0;bp<=0;hp<=0;vp<=0;hd<=0;vd<=0;gate<=2'b11;
            carrier<=0;phase_1<=0;phase_2<=0;fields<=0;
        end else begin
            rp<=hde && vde ? r : 8'd0;
            gp<=hde && vde ? g : 8'd0;
            bp<=hde && vde ? b : 8'd0;
            hp<={hp[0],hs};vp<={vp[0],vs};
            hd<={hd[0],hde};vd<={vd[0],vde};
            gate<={gate[0],burst_n | vs};fields<={fields[0],field_in};
            carrier<=carrier==11 ? 4'd0 : carrier+4'd1;
            phase_1<=carrier;phase_2<=phase_1;
        end
    end
    snes_ppu2_rgb response(.clk(clk),.reset(reset),.r(rp),.g(gp),.b(bp),
        .ar(ar),.ag(ag),.ab(ab));
    assign sync_n=~(hp[1]^vp[1]);
    assign gate_n=gate[1];
    assign phase=phase_2;
    // Exact nearest integer voltage/180 for every reachable 0..45900 state.
    // Constant multipliers use logic, conserving the core's scarce DSPs.
    (* multstyle = "logic" *) wire [29:0] rq=ar[15:0]*14'd11651+30'd1048576;
    (* multstyle = "logic" *) wire [29:0] gq=ag[15:0]*14'd11651+30'd1048576;
    (* multstyle = "logic" *) wire [29:0] bq=ab[15:0]*14'd11651+30'd1048576;
    reg [1:0] pixel_count;
    reg hs_old;
    always @(posedge clk) begin
        if(reset) begin
            pixel_count<=0;hs_old<=0;pix<=0;pix2<=0;
            hs_out<=0;vs_out<=0;hb_out<=1;vb_out<=1;field_out<=0;
            r_out<=0;g_out<=0;b_out<=0;
        end else begin
            hs_old<=hp[1];
            pixel_count<=hp[1] && !hs_old ? 2'd0 : pixel_count+2'd1;
            pix<=pixel_count==3;
            pix2<=pixel_count[0];
            r_out<=rq[28:21];g_out<=gq[28:21];b_out<=bq[28:21];
            hs_out<=hp[1];vs_out<=vp[1];hb_out<=~hd[1];vb_out<=~vd[1];field_out<=fields[1];
        end
    end
endmodule
