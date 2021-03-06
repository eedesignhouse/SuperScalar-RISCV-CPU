/////////////////////////////////////////////////////////////////////////////////////
//
//Copyright 2019  Li Xinbing
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.
//
/////////////////////////////////////////////////////////////////////////////////////

`include "define.v"
module instrman
#(
    parameter START_ADDR = 'h200
)
(   
    input                           clk,
	input                           rst,

    output                          imem_req,
	output `N(`XLEN)                imem_addr,
	input  `N(`BUS_WID)             imem_rdata,
	input                           imem_resp,
	input                           imem_err,

	input                           sysjmp_vld,
	input  `N(`XLEN)                sysjmp_pc,
	input                           alujmp_vld,
	input  `N(`XLEN)                alujmp_pc,
	
	input                           buffer_free,	
	output                          jump_vld,
	output reg `N(`XLEN)            jump_pc,
	output                          line_vld,
	output `N(`BUS_WID)             line_data,
	output                          line_err

);

//---------------------------------------------------------------------------
//signal defination
//---------------------------------------------------------------------------

    reg             reset_state;
	reg `N(`XLEN)   pc;
	reg             bus_keep_err;	
	reg             req_sent;
	reg             line_requested;	
	
	wire `N(`XLEN)  fetch_addr;
	
//---------------------------------------------------------------------------
//statements area
//---------------------------------------------------------------------------
	
	//initial jump
	`FFx(reset_state,1'b1)
	reset_state <= 1'b0;

    assign jump_vld = reset_state|sysjmp_vld|alujmp_vld;
	
	always@* begin
        if ( reset_state )
	        jump_pc = START_ADDR;
	    else if ( sysjmp_vld )
	        jump_pc = sysjmp_pc;
        else
            jump_pc = alujmp_pc;	
	    jump_pc[0] = 1'b0;
	end	
	
	//imem_addr
	`FFx(pc,0)
	if ( imem_req )
	    pc <= fetch_addr + 4*`BUS_LEN;
	else if ( jump_vld )
	    pc <= jump_pc;
	else;	

	assign fetch_addr = jump_vld ? jump_pc : pc;

	assign imem_addr = fetch_addr & `PC_ALIGN;		
	
	//imem_req
	
	wire bus_initial_err = line_requested & imem_resp & imem_err;
	
	`FFx(bus_keep_err,0)
	if ( jump_vld )
	    bus_keep_err <= 1'b0;
	else if ( bus_initial_err )
	    bus_keep_err <= 1'b1;
	else;
	
	wire bus_is_err = bus_initial_err|bus_keep_err;
	
	wire request_go = (buffer_free & ~bus_is_err)|jump_vld;
	
	//if req_sent is 0, request_go can be asserted any time, if it is 1, only when imem_resp is OK.
	`FFx(req_sent,1'b0)
	if ( ~req_sent|imem_resp )
	    req_sent <= request_go;
	else;
	
	assign imem_req = request_go & ( ~req_sent|imem_resp );	
	
	//rdata could be cancelled by "jump_vld"
	`FFx(line_requested,1'b0)
	if ( imem_req )
	    line_requested <= 1'b1;
	else if ( jump_vld|imem_resp )
	    line_requested <= 1'b0;
	else;
	
	assign line_vld = line_requested & imem_resp;
	
	assign line_data = imem_rdata;
	
	assign line_err = imem_err;

endmodule
