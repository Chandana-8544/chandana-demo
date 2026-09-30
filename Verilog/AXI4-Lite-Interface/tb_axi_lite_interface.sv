// AXI4-LITE LAYERED SYSTEMVERILOG TESTBENCH
// 1. GLOBAL TYPES & ENUMS
typedef enum logic {WRITE_TRANS = 1'b0, READ_TRANS = 1'b1} trans_type_e;
// 2. INTERFACE
interface axil_if(input logic ACLK);
logic ARESETn;
logic [31:0] AWADDR;
logic AWVALID;
logic AWREADY;
logic [31:0] WDATA;
logic WVALID;
logic WREADY;
logic [1:0] BRESP;
logic BVALID;
logic BREADY;
logic [31:0] ARADDR;
logic ARVALID;
logic ARREADY;
logic [31:0] RDATA;
logic [1:0] RRESP;
logic RVALID;
logic RREADY;
endinterface
// 3. TRANSACTION CLASS
class axil_transaction;
rand trans_type_e trans_type;
rand bit [31:0] awaddr;
rand bit [31:0] wdata;
rand bit [31:0] araddr;
bit [1:0] bresp;
bit [31:0] rdata;
bit [1:0] rresp;
constraint addr_c {
awaddr[31:7] == 25'h0;
awaddr[1:0] == 2'b00;
araddr[31:7] == 25'h0;
araddr[1:0] == 2'b00;
}
function void display(string name);
if (trans_type == WRITE_TRANS) begin
$display("[%0s] [WRITE] AWADDR=0x%0h WDATA=0x%0h BRESP=%b",
name, awaddr, wdata, bresp);
end else begin
$display("[%0s] [READ] ARADDR=0x%0h RDATA=0x%0h RRESP=%b",
name, araddr, rdata, rresp);
end
endfunction
endclass
// 4. GENERATOR CLASS
class axil_generator;
mailbox #(axil_transaction) gen2drv;
int num_transactions;
function new(mailbox #(axil_transaction) gen2drv, int num_transactions);
this.gen2drv = gen2drv;
this.num_transactions = num_transactions;
endfunction
task run();
axil_transaction tr;
repeat (num_transactions) begin
tr = new();
if (!tr.randomize()) begin
$display("[GENERATOR] ERROR: Randomization failed!");
end else begin
tr.display("GENERATOR");
gen2drv.put(tr);
end
end
endtask
endclass
// 5. DRIVER CLASS
class axil_driver;
virtual axil_if vif;
mailbox #(axil_transaction) gen2drv;
int num_transactions;
function new(virtual axil_if vif, mailbox #(axil_transaction) gen2drv, int num_transactions);
this.vif = vif;
this.gen2drv = gen2drv;
this.num_transactions = num_transactions;
endfunction
task run();
axil_transaction tr;
repeat (num_transactions) begin
gen2drv.get(tr);
@(posedge vif.ACLK);
if (tr.trans_type == WRITE_TRANS) begin
vif.AWADDR <= tr.awaddr;
vif.AWVALID <= 1'b1;
vif.WDATA <= tr.wdata;
vif.WVALID <= 1'b1;
vif.BREADY <= 1'b1;
fork
begin
wait(vif.AWREADY && vif.AWVALID);
@(posedge vif.ACLK);
vif.AWVALID <= 1'b0;
end
begin
wait(vif.WREADY && vif.WVALID);
@(posedge vif.ACLK);
vif.WVALID <= 1'b0;
end
join
wait(vif.BVALID);
tr.bresp = vif.BRESP;
@(posedge vif.ACLK);
vif.BREADY <= 1'b0;
end else begin
vif.ARADDR <= tr.araddr;
vif.ARVALID <= 1'b1;
vif.RREADY <= 1'b1;
wait(vif.ARREADY && vif.ARVALID);
@(posedge vif.ACLK);
vif.ARVALID <= 1'b0;
wait(vif.RVALID);
tr.rdata = vif.RDATA;
tr.rresp = vif.RRESP;
@(posedge vif.ACLK);
vif.RREADY <= 1'b0;
end
tr.display("DRIVER");
end
endtask
endclass
// 6. MONITOR CLASS
class axil_monitor;
virtual axil_if vif;
mailbox #(axil_transaction) mon2scb;
mailbox #(axil_transaction) mon2cov;
int num_transactions;
function new(virtual axil_if vif, mailbox #(axil_transaction) mon2scb, mailbox #(axil_transaction)
mon2cov, int num_transactions);
this.vif = vif;
this.mon2scb = mon2scb;
this.mon2cov = mon2cov;
this.num_transactions = num_transactions;
endfunction
task run();
axil_transaction tr;
repeat (num_transactions) begin
tr = new();
forever begin
@(posedge vif.ACLK);
#1;
if (vif.BVALID && vif.BREADY) begin
tr.trans_type = WRITE_TRANS;
tr.awaddr = vif.AWADDR;
tr.wdata = vif.WDATA;
tr.bresp = vif.BRESP;
break;
end
if (vif.RVALID && vif.RREADY) begin
tr.trans_type = READ_TRANS;
tr.araddr = vif.ARADDR;
tr.rdata = vif.RDATA;
tr.rresp = vif.RRESP;
break;
end
end
tr.display("MONITOR");
mon2scb.put(tr);
mon2cov.put(tr);
end
endtask
endclass
// 7. SCOREBOARD CLASS
class axil_scoreboard;
mailbox #(axil_transaction) mon2scb;
int num_transactions;
int pass_count;
int fail_count;
bit [31:0] ref_mem [0:31];
function new(mailbox #(axil_transaction) mon2scb, int num_transactions);
this.mon2scb = mon2scb;
this.num_transactions = num_transactions;
pass_count = 0;
fail_count = 0;
for (int i = 0; i < 32; i++) ref_mem[i] = 32'h0;
endfunction
task run();
axil_transaction tr;
bit [31:0] expected_rdata;
repeat (num_transactions) begin
mon2scb.get(tr);
if (tr.trans_type == WRITE_TRANS) begin
if (tr.bresp == 2'b00) begin
ref_mem[tr.awaddr[6:2]] = tr.wdata;
pass_count++;
$display("[SCOREBOARD] PASS WRITE: Addr=0x%0h Data=0x%0h BRESP=%b",
tr.awaddr, tr.wdata, tr.bresp);
end else begin
fail_count++;
$display("[SCOREBOARD] FAIL WRITE: Unexpected Response BRESP=%b", tr.bresp);
end
end else begin
expected_rdata = ref_mem[tr.araddr[6:2]];
if ((tr.rdata == expected_rdata) && (tr.rresp == 2'b00)) begin
pass_count++;
$display("[SCOREBOARD] PASS READ : Addr=0x%0h EXPECTED=0x%0h
ACTUAL=0x%0h",
tr.araddr, expected_rdata, tr.rdata);
end else begin
fail_count++;
$display("[SCOREBOARD] FAIL READ : Addr=0x%0h EXPECTED=0x%0h
ACTUAL=0x%0h RRESP=%b",
tr.araddr, expected_rdata, tr.rdata, tr.rresp);
end
end
end
$display("==================================================");
$display("FINAL AXI-LITE SCOREBOARD REPORT");
$display("PASS COUNT = %0d", pass_count);
$display("FAIL COUNT = %0d", fail_count);
$display("==================================================");
endtask
endclass
// 8. COVERAGE CLASS
class axil_coverage;
mailbox #(axil_transaction) mon2cov;
int num_transactions;
trans_type_e trans_type_cp;
bit [31:0] awaddr_cp;
bit [31:0] araddr_cp;
bit [1:0] bresp_cp;
bit [1:0] rresp_cp;
covergroup axil_cg;
option.per_instance = 1;
cp_trans_type: coverpoint trans_type_cp {
bins write_op = {WRITE_TRANS};
bins read_op = {READ_TRANS};
}
cp_awaddr: coverpoint awaddr_cp {
bins low_addr = {[32'h00 : 32'h1C]};
bins high_addr = {[32'h20 : 32'h7C]};
}
cp_araddr: coverpoint araddr_cp {
bins low_addr = {[32'h00 : 32'h1C]};
bins high_addr = {[32'h20 : 32'h7C]};
}
cp_bresp: coverpoint bresp_cp {
bins okay = {2'b00};
bins slverr = {2'b10};
}
cp_rresp: coverpoint rresp_cp {
bins okay = {2'b00};
bins slverr = {2'b10};
}
trans_x_bresp: cross cp_trans_type, cp_bresp;
endgroup
function new(mailbox #(axil_transaction) mon2cov, int num_transactions);
this.mon2cov = mon2cov;
this.num_transactions = num_transactions;
axil_cg = new();
endfunction
task run();
axil_transaction tr;
repeat (num_transactions) begin
mon2cov.get(tr);
trans_type_cp = tr.trans_type;
awaddr_cp = tr.awaddr;
araddr_cp = tr.araddr;
bresp_cp = tr.bresp;
rresp_cp = tr.rresp;
axil_cg.sample();
end
$display("==================================================");
$display("FUNCTIONAL COVERAGE REPORT");
$display("Overall Coverage = %0.2f %%", axil_cg.get_coverage());
$display("==================================================");
endtask
endclass
// 9. ENVIRONMENT CLASS
class axil_environment;
axil_generator gen;
axil_driver drv;
axil_monitor mon;
axil_scoreboard scb;
axil_coverage cov;
mailbox #(axil_transaction) gen2drv;
mailbox #(axil_transaction) mon2scb;
mailbox #(axil_transaction) mon2cov;
virtual axil_if vif;
int num_transactions;
function new(virtual axil_if vif, int num_transactions);
this.vif = vif;
this.num_transactions = num_transactions;
gen2drv = new();
mon2scb = new();
mon2cov = new();
gen = new(gen2drv, num_transactions);
drv = new(vif, gen2drv, num_transactions);
mon = new(vif, mon2scb, mon2cov, num_transactions);
scb = new(mon2scb, num_transactions);
cov = new(mon2cov, num_transactions);
endfunction
task run();
fork
gen.run();
drv.run();
mon.run();
scb.run();
cov.run();
join
endtask
endclass
// 10. TOP MODULE
module tb_top;
logic ACLK;
int num_transactions;
axil_if trif(ACLK);
axi_slave_dut dut (
.ACLK (ACLK),
.ARESETn(trif.ARESETn),
.AWADDR (trif.AWADDR),
.AWVALID(trif.AWVALID),
.AWREADY(trif.AWREADY),
.WDATA (trif.WDATA),
.WVALID (trif.WVALID),
.WREADY (trif.WREADY),
.BRESP (trif.BRESP),
.BVALID (trif.BVALID),
.BREADY (trif.BREADY),
.ARADDR (trif.ARADDR),
.ARVALID(trif.ARVALID),
.ARREADY(trif.ARREADY),
.RDATA (trif.RDATA),
.RRESP (trif.RRESP),
.RVALID (trif.RVALID),
.RREADY (trif.RREADY)
);
axil_environment env;
initial begin
ACLK = 1'b0;
forever #5 ACLK = ~ACLK;
end
initial begin
trif.ARESETn <= 1'b0;
trif.AWVALID <= 1'b0;
trif.WVALID <= 1'b0;
trif.BREADY <= 1'b0;
trif.ARVALID <= 1'b0;
trif.RREADY <= 1'b0;
#20;
trif.ARESETn <= 1'b1;
end
initial begin
num_transactions = 50;
#25;
env = new(trif, num_transactions);
$display("==================================================");
$display(" AXI4-LITE INTERFACE VERIFICATION STARTED");
$display("==================================================");
env.run();
$display("==================================================");
$display(" AXI4-LITE INTERFACE VERIFICATION COMPLETED");
$display("==================================================");
#50;
$finish;
end
endmodule
