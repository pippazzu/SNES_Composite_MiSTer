// SPDX-License-Identifier: GPL-2.0-or-later
// Initial NTSC board model, 42.95454 MHz. See model/DESIGN.md outside the core.
// Emitter followers are ideal; impedances and capacitor tolerances are nominal.
// Q3.16 pin voltages, with coupling-capacitor DC removed by ideal clamps.
module snes_av_board (
    input wire clk, reset,
    input wire signed [18:0] yo, ryo, byo, vo,
    output wire signed [18:0] yi, ryi, byi,
    output wire signed [23:0] cvbs
);
    reg signed [18:0] rf, bf, yf, vf;
    wire signed [18:0] rd = $signed(ryo) - $signed(rf);
    wire signed [18:0] bd = $signed(byo) - $signed(bf);
    // Exact ZOH: colour 270 ohm / 220 pF. Luma and VO each have
    // 470 ohm series, 10 kohm shunt and 10 pF shunt: DC gain 10000/10470,
    // time constant (470 || 10000) * 10 pF. Ideal emitter followers.
    wire signed [38:0] rp = rd * 18'sd21250;
    wire signed [38:0] bp = bd * 18'sd21250;
    wire signed [38:0] yp = yo * 18'sd62244 + yf * 18'sd367;
    // C21 (51 pF) loads the VO pin. Datasheet p.8: VO is an NPN emitter
    // follower with R1 = 6.0 kohm to ground, so it charges C21 freely but
    // only R1 || (R30 + R31) = 3.81 kohm discharges it: tau = 194 ns.
    // Falling edges decay toward 0 V by at most exp(-Ts/tau) = 0.8872 per
    // sample (1 - 1/8 + 1/128 + 1/256 = 0.8867); rising edges follow.
    // Absolute pin voltage assumes the typical 2.0 V VO DC level at black.
    localparam signed [19:0] VO_DC = 20'sd131072;
    reg signed [19:0] vpin;
    wire signed [19:0] vo_abs = $signed(vo) + VO_DC;
    wire signed [19:0] vdecay = vpin - (vpin >>> 3) + (vpin >>> 7) + (vpin >>> 8);
    wire signed [19:0] vo_rel = vpin - VO_DC;
    wire signed [18:0] vo_pin = vo_rel[18:0];
    wire signed [38:0] vp = vo_pin * 18'sd62244 + vf * 18'sd367;
    wire signed [18:0] vf_next = vp >>> 16;
    // 75 ohm receiver behind the composite output's 56 ohm resistor.
    // Registered from vf's next value, so jack always equals the termination
    // of the current vf: no added latency, but the decoder no longer sees
    // this multiplier in its sync-tip cycle.
    wire signed [37:0] terminated = vf_next * 18'sd37521;
    reg signed [18:0] jack;
    always @(posedge clk) begin
        if(reset) begin rf<=0; bf<=0; yf<=0; vf<=0; vpin<=VO_DC; jack<=0; end
        else begin
            vpin <= vo_abs > vdecay ? vo_abs : vdecay;
            rf <= rf + (rp >>> 16);
            bf <= bf + (bp >>> 16);
            yf <= yp >>> 16;
            vf <= vf_next;
            jack <= terminated >>> 16;
        end
    end
    assign ryi = rf;
    assign byi = bf;
    // Feedback is taken at Q11's emitter BEFORE C59 and R42. R40/R41
    // divide by two; the external S-video termination is not in this loop.
    assign yi = yf >>> 1;
    assign cvbs = $signed(jack) <<< 5;
endmodule
