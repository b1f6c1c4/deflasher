module shift_reg #(
   parameter DELAYS = 2,
   parameter WIDTH = 1
) (
   input clk_i,
   input cen_i,
   input [WIDTH-1:0] d_i,
   output [WIDTH-1:0] d_o
);

   reg [WIDTH-1:0] delay[0:DELAYS-1];
   genvar i;
   generate
      for (i = 0; i < DELAYS; i = i + 1) begin : g
         always @(posedge clk_i) begin
            if (cen_i) begin
               delay[i] <= (i == 0) ? d_i : delay[i - 1];
            end
         end
      end
   endgenerate

   assign d_o = delay[DELAYS-1];

endmodule
