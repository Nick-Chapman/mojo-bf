
module mem_sim_delay #(parameter logsize = 1,
                       parameter steps = 1)
   (
    input             clk,
    input             init,
   
    input [1:logsize] addr,
    input [1:8]       wdata,
    input             wselect,
    input             doit,
    output            busy,
    output            rvalid,
    output [1:8]      rdata
    );
   
   localparam size = 2 ** logsize;

   always @(posedge clk) 
     begin
        if (init) mem = {size*8{1'b0}};
        else if (wselect & act) mem[addr*8 +: 8] = wdata;
     end
   reg [0:8*size-1]   mem;

   always @(posedge clk) count = xcount;
   reg [1:13]         count;
   wire [1:13]        xcount = act ? steps : count==0 ? 0 : count - 1;

   always @(posedge clk) data = xdata;
   reg [1:8]          data;
   wire [1:8]         xdata = act & !wselect ? mem[addr*8 +: 8] : data;

   always @(posedge clk) sav_wselect = xsav_wselect;
   reg                sav_wselect;
   wire               xsav_wselect = act ? wselect : sav_wselect;
   
   wire               act = doit & !busy;

   assign rdata = xdata;
   assign rvalid = !sav_wselect & (count == 1);
   assign busy = (count != 0);

endmodule 
