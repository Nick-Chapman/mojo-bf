
module mem_sim_delay1 #(parameter logsize = 7)
   (
    input             clk,
    input             rst,
   
    input [1:logsize] addr,
    input [1:8]       wdata,
    input             wselect,
    input             doit,
    output            busy,
    output            rvalid,
    output reg [1:8]  rdata,
    output [7:0] m0
    );

   assign m0 = mem[0 +: 8];
   
   localparam size = 2 ** logsize;
   
   reg [0:8*size-1]   mem;
   
   assign rvalid = s;
   assign busy = s;
   reg                s; //0-idle, 1-done
   always @(posedge clk) s
     //This !wselect is wrong. We should take time even when wselect
     = s ? !s : (doit & !wselect);
   
   always @(posedge clk) rdata = mem[addr*8 +: 8];
   
   always @(posedge clk) 
     begin
        if (rst) mem = {size*8{1'b0}};
        else if (wselect & doit) mem[addr*8 +: 8] = wdata;
     end
   
endmodule 
