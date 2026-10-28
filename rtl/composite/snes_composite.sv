// SPDX-License-Identifier: GPL-2.0-or-later
// Streaming NTSC encode/decode path. Input and output share CLK_VIDEO.
module snes_composite (
    input wire clk, reset,
    input wire [7:0] r, g, b,
    input wire hs, vs, hde, vde, burst_n,
    input wire premium, field_in,
    input wire signed [15:0] brightness,
    input wire [3:0] sharpness,
    output wire rgb_pix, rgb_hs, rgb_vs, rgb_hb, rgb_vb, rgb_field,
    output wire field_out,
    output wire [7:0] rgb_r, rgb_g, rgb_b,
    output wire pix, hs_out, vs_out, hb_out, vb_out,
    output wire [7:0] r_out, g_out, b_out
);
    wire signed [18:0] ar, ag, ab;
    wire sync_n, gate_n;
    wire [3:0] phase;
    snes_rgb_output source(
        .clk(clk),.reset(reset),.r(r),.g(g),.b(b),
        .hs(hs),.vs(vs),.hde(hde),.vde(vde),.burst_n(burst_n),.field_in(field_in),
        .ar(ar),.ag(ag),.ab(ab),.sync_n(sync_n),.gate_n(gate_n),.phase(phase),
        .pix(rgb_pix),.hs_out(rgb_hs),.vs_out(rgb_vs),.hb_out(rgb_hb),.vb_out(rgb_vb),.field_out(rgb_field),
        .r_out(rgb_r),.g_out(rgb_g),.b_out(rgb_b));
    wire signed [18:0] yo,ryo,byo,vo,co,yi,ryi,byi;
    wire signed [23:0] cvbs;
    ba6592f encoder(
        .clk(clk), .reset(reset), .ar(ar), .ag(ag), .ab(ab),
        .sync_n(sync_n), .pcp_n(gate_n), .bfp_n(gate_n),
        .phase(phase), .yi(yi), .ryi(ryi), .byi(byi),
        .yo(yo), .ryo(ryo), .byo(byo), .vo(vo), .co(co)
    );
    snes_av_board board(.*);
    composite_decoder #(
        .SPC(12), .HCNT_W(12), .LUMA_LP(6), .PK_SPAN(7), .PIX_DIV(4),
        .BURST_GATE_TENTHS(21), .CLAMP_GATE_TENTHS(49),
        .LINE_RAM_STYLE("M10K, no_rw_check")
    ) decoder(
        .clk(clk), .reset(reset), .ce(1'b1), .comp(cvbs),
        .sat(8'd128), .hue(8'd0), .chroma_trail(4'd0), .sharpness(sharpness),
        .black_stretch(2'd0), .brightness(brightness), .contrast(16'd2604),
        .comb_mode(premium ? 2'd2 : 2'd0), .ce_out(), .pix_out(),
        .hs_out(), .vs_out(), .hb_out(), .vb_out(),
        .r_out(r_out), .g_out(g_out), .b_out(b_out)
    );
    // Keep the PPU's native field geometry in every NTSC resolution. The TV
    // still recovers burst/clamp internally; it does not redefine picture rows.
    // Nominal notch-luma center is 30 source samples from raw pins (including
    // the VO pin register): the shared RGB presentation has three, so delay
    // that complete timing tuple by 27.
    localparam integer PRESENT_DELAY=27;
    reg [5:0] timing [0:PRESENT_DELAY-1];
    integer i;
    always @(posedge clk) begin
        if(reset) begin
            for(i=0;i<PRESENT_DELAY;i=i+1) timing[i]<=6'b000110;
        end else begin
            timing[0]<={rgb_pix,rgb_hs,rgb_vs,rgb_hb,rgb_vb,rgb_field};
            for(i=1;i<PRESENT_DELAY;i=i+1) timing[i]<=timing[i-1];
        end
    end
    assign {pix,hs_out,vs_out,hb_out,vb_out,field_out}=timing[PRESENT_DELAY-1];
endmodule
