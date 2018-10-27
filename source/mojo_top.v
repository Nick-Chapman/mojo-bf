module mojo_top
  (
   input        clk,
   input        rst_n,
   input        cclk,
  
   output       spi_miso,
   input        spi_mosi,
   input        spi_ss,
   input        spi_sck,

   output [3:0] spi_channel,
   output       avr_rx,
   input        avr_tx, 
   input        avr_rx_busy,

   output [7:0] led
   );

   wire         rst = ~rst_n;

   wire         new_sample;
   wire [9:0]   sample;
   wire [3:0]   sample_channel;

   wire [1:8]   rx_data;
   wire         new_rx;

   //reg [7:0]    led; //watch rx_data on led
   //always @(posedge clk) led = new_rx ? rx_data : led;
   
   wire [1:8]   a_data;
   wire         a_send;
   wire         a_busy;
   
   avr_interface avr 
     (
      .clk(clk),
      .rst(rst),
      .cclk(cclk),
      
      .spi_miso(spi_miso),
      .spi_mosi(spi_mosi),
      .spi_sck(spi_sck),
      .spi_ss(spi_ss),

      .channel(4'hf),
      .new_sample(new_sample),
      .sample(sample),
      .sample_channel(sample_channel),
      
      .spi_channel(spi_channel),
      .tx(avr_rx),
      .rx(avr_tx),
      
      .tx_data(a_data),
      .new_tx_data(a_send),
      .tx_busy(a_busy),
      
      .rx_data(rx_data),
      .new_rx_data(new_rx),
      .tx_block(avr_rx_busy)
      );
   
   bf_top bt
     (.clk(clk),
      .rst(rst),
      .rx_data(rx_data),
      .new_rx(new_rx),
      .tx_data(a_data),
      .tx_send(a_send),
      .tx_busy(a_busy),
      .led(led)
      );

endmodule

