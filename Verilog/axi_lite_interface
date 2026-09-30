//DUT FILE
module axi_slave_dut (
input logic ACLK,
input logic ARESETn,
input logic [31:0] AWADDR,
input logic AWVALID,
output logic AWREADY,
input logic [31:0] WDATA,
input logic WVALID,
output logic WREADY,
output logic [1:0] BRESP,
output logic BVALID,
input logic BREADY,
input logic [31:0] ARADDR,
input logic ARVALID,
output logic ARREADY,
output logic [31:0] RDATA,
output logic [1:0] RRESP,
output logic RVALID,
input logic RREADY
);
logic [31:0] mem [0:31];
// Internal pipeline registers
logic [31:0] awaddr_latched;
logic aw_done;
logic w_done;
localparam RESP_OKAY = 2'b00;
localparam RESP_SLVERR = 2'b10;
// WRITE TRANSACTION LOGIC
always_ff @(posedge ACLK or negedge ARESETn) begin
if (!ARESETn) begin
AWREADY <= 1'b0;
WREADY <= 1'b0;
BVALID <= 1'b0;
BRESP <= 2'b00;
aw_done <= 1'b0;
w_done <= 1'b0;
awaddr_latched <= '0;
for (int i = 0; i < 32; i++) mem[i] <= 32'h0;
end else begin
if (AWVALID && !AWREADY && !aw_done) begin
AWREADY <= 1'b1;
awaddr_latched <= AWADDR;
aw_done <= 1'b1;
end else begin
AWREADY <= 1'b0;
end

// Data Handshake
if (WVALID && !WREADY && !w_done) begin
WREADY <= 1'b1;

w_done <= 1'b1; // Fixed typo here
end else begin
WREADY <= 1'b0;
end
// Write Execution
if ((aw_done || (AWVALID && AWREADY)) && (w_done || (WVALID && WREADY)) &&
!BVALID) begin
if (awaddr_latched[6:2] < 32) begin
mem[awaddr_latched[6:2]] <= WDATA;
BRESP <= RESP_OKAY;
end else begin
BRESP <= RESP_SLVERR;
end
BVALID <= 1'b1;
aw_done <= 1'b0;
w_done <= 1'b0;
end
// Response Handshake
if (BVALID && BREADY) begin
BVALID <= 1'b0;
end
end
end
// READ TRANSACTION LOGIC
always_ff @(posedge ACLK or negedge ARESETn) begin
if (!ARESETn) begin
ARREADY <= 1'b0;
RVALID <= 1'b0;
RDATA <= 32'h0;
RRESP <= 2'b00;
end else begin
// Address Handshake
if (ARVALID && !ARREADY) begin
ARREADY <= 1'b1;
if (ARADDR[6:2] < 32) begin
RDATA <= mem[ARADDR[6:2]];
RRESP <= RESP_OKAY;
end else begin
RDATA <= 32'hDEADBEEF;
RRESP <= RESP_SLVERR;
end
end else begin
ARREADY <= 1'b0;
end

// Data Transfer
if (ARREADY && ARVALID) begin
RVALID <= 1'b1;
end else if (RVALID && RREADY) begin
RVALID <= 1'b0;
end
end
end
endmodule
