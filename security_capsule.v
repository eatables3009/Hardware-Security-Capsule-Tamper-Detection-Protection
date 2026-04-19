// Security Capsule Architecture
// Based on "Security Capsules: An Architecture for Post-Silicon Security Assertion Validation"
// This module implements the security capsule with dynamic trace buffer and controller

module security_capsule #(
    parameter TRACE_LENGTH = 8,      // L - Length of trace buffer
    parameter TRACE_WIDTH = 8,       // W - Width of trace buffer
    parameter NUM_GROUPS = 4,        // Number of signal groups
    parameter SIGNAL_WIDTH = 32      // Width of signals being monitored
)(
    input wire clk,
    input wire rst_n,
    
    // Signals from IP core to be traced (example signals)
    input wire [SIGNAL_WIDTH-1:0] ip_signal_1,
    input wire [SIGNAL_WIDTH-1:0] ip_signal_2,
    input wire [SIGNAL_WIDTH-1:0] ip_signal_3,
    input wire [SIGNAL_WIDTH-1:0] ip_signal_4,
    
    // Trace control signals
    input wire trace_enable,
    input wire trace_dump,
    input wire [$clog2(NUM_GROUPS)-1:0] group_select,
    
    // JTAG-like interface for trace dump
    output wire trace_valid,
    output wire [TRACE_WIDTH-1:0] trace_data_out,
    output wire trace_dump_done,
    
    // Assertion violation outputs
    output wire assertion_violation,
    output wire [3:0] violation_id
);

    // Internal trace buffer - organized as described in paper
    // Buffer stores W signals over L/b cycles (where b is bit-width)
    reg [TRACE_WIDTH-1:0] trace_buffer [0:TRACE_LENGTH-1];
    reg [$clog2(TRACE_LENGTH)-1:0] trace_ptr;
    reg [$clog2(TRACE_LENGTH)-1:0] dump_ptr;
    reg dump_active;
    
    // Signal group selection outputs from multiplexer
    wire [TRACE_WIDTH-1:0] selected_signals;
    
    // On-chip monitor signals
    wire [3:0] monitor_violations;
    
    // ===================================================================
    // Dynamic Trace Controller - Multiplexer for Signal Group Selection
    // ===================================================================
    // This implements the multiplexer structure shown in Fig. 3
    // Groups are formed based on Algorithm 1 from the paper
    
    wire [TRACE_WIDTH-1:0] group_0_signals;
    wire [TRACE_WIDTH-1:0] group_1_signals;
    wire [TRACE_WIDTH-1:0] group_2_signals;
    wire [TRACE_WIDTH-1:0] group_3_signals;
    
    // Example signal grouping (in practice, this comes from Algorithm 1)
    // Group 0: signals for assertion set A0
    assign group_0_signals = ip_signal_1[7:0];
    
    // Group 1: signals for assertion set A1
    assign group_1_signals = ip_signal_2[7:0];
    
    // Group 2: signals for assertion set A2
    assign group_2_signals = ip_signal_3[7:0];
    
    // Group 3: signals for assertion set A3
    assign group_3_signals = ip_signal_4[7:0];
    
    // Multiplexer for dynamic signal selection
    assign selected_signals = (group_select == 2'd0) ? group_0_signals :
                             (group_select == 2'd1) ? group_1_signals :
                             (group_select == 2'd2) ? group_2_signals :
                             group_3_signals;
    
    // ===================================================================
    // Trace Buffer Logic - Novel lengthwise storage as per Section III
    // ===================================================================
    // Multi-bit signals stored lengthwise: s[b-1:0] captured over L/b cycles
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trace_ptr <= 0;
            dump_ptr <= 0;
            dump_active <= 1'b0;
        end
        else begin
            if (trace_dump && !dump_active) begin
                // Start dump operation
                dump_active <= 1'b1;
                dump_ptr <= 0;
            end
            else if (dump_active) begin
                // Continue dumping
                if (dump_ptr < TRACE_LENGTH - 1) begin
                    dump_ptr <= dump_ptr + 1;
                end
                else begin
                    dump_active <= 1'b0;
                end
            end
            else if (trace_enable && !trace_dump) begin
                // Tracing enabled - FIFO operation
                // Most recent values retained, older values discarded
                trace_buffer[trace_ptr] <= selected_signals;
                
                if (trace_ptr < TRACE_LENGTH - 1) begin
                    trace_ptr <= trace_ptr + 1;
                end
                else begin
                    trace_ptr <= 0; // Wrap around (FIFO)
                end
            end
        end
    end
    
    // ===================================================================
    // Trace Data Output via JTAG-like interface
    // ===================================================================
    
    assign trace_valid = dump_active;
    assign trace_data_out = dump_active ? trace_buffer[dump_ptr] : 8'h00;
    assign trace_dump_done = dump_active && (dump_ptr == TRACE_LENGTH - 1);
    
    // ===================================================================
    // On-Chip Runtime Monitors (Critical Assertions)
    // ===================================================================
    // These are assertion monitors that cannot be moved off-chip
    // Non-critical assertions are evaluated off-chip using trace data
    
    // Example Monitor 1: Check for illegal state transitions
    runtime_monitor #(.MONITOR_ID(4'd1)) monitor_1 (
        .clk(clk),
        .rst_n(rst_n),
        .signal_in(ip_signal_1),
        .violation(monitor_violations[0])
    );
    
    // Example Monitor 2: Check for security property violation
    runtime_monitor #(.MONITOR_ID(4'd2)) monitor_2 (
        .clk(clk),
        .rst_n(rst_n),
        .signal_in(ip_signal_2),
        .violation(monitor_violations[1])
    );
    
    // Example Monitor 3: Data integrity check
    runtime_monitor #(.MONITOR_ID(4'd3)) monitor_3 (
        .clk(clk),
        .rst_n(rst_n),
        .signal_in(ip_signal_3),
        .violation(monitor_violations[2])
    );
    
    // Example Monitor 4: Access control violation
    runtime_monitor #(.MONITOR_ID(4'd4)) monitor_4 (
        .clk(clk),
        .rst_n(rst_n),
        .signal_in(ip_signal_4),
        .violation(monitor_violations[3])
    );
    
    // Aggregate violation signals
    assign assertion_violation = |monitor_violations;
    
    // Priority encoder for violation ID
    assign violation_id = monitor_violations[0] ? 4'd1 :
                         monitor_violations[1] ? 4'd2 :
                         monitor_violations[2] ? 4'd3 :
                         monitor_violations[3] ? 4'd4 : 4'd0;

endmodule


// ===================================================================
// Runtime Monitor Module
// ===================================================================
// Synthesizable assertion monitor for critical security properties
// This represents on-chip monitors that couldn't be moved off-chip

module runtime_monitor #(
    parameter MONITOR_ID = 4'd0,
    parameter SIGNAL_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire [SIGNAL_WIDTH-1:0] signal_in,
    output reg violation
);

    reg [SIGNAL_WIDTH-1:0] prev_signal;
    reg [SIGNAL_WIDTH-1:0] prev_prev_signal;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_signal <= 0;
            prev_prev_signal <= 0;
            violation <= 1'b0;
        end
        else begin
            prev_prev_signal <= prev_signal;
            prev_signal <= signal_in;
            
            // Example assertion checks based on MONITOR_ID
            case (MONITOR_ID)
                4'd1: begin
                    // Assertion 1: Signal should not have consecutive identical values
                    // when upper bits indicate active state
                    if (signal_in[31:28] == 4'hF && signal_in == prev_signal) begin
                        violation <= 1'b1;
                    end
                    else begin
                        violation <= 1'b0;
                    end
                end
                
                4'd2: begin
                    // Assertion 2: Privileged bits should not be set without enable
                    if (signal_in[31] == 1'b1 && signal_in[30] == 1'b0) begin
                        violation <= 1'b1;
                    end
                    else begin
                        violation <= 1'b0;
                    end
                end
                
                4'd3: begin
                    // Assertion 3: Detect sudden large changes (potential fault injection)
                    if ((signal_in > prev_signal + 32'h1000) || 
                        (prev_signal > signal_in + 32'h1000)) begin
                        violation <= 1'b1;
                    end
                    else begin
                        violation <= 1'b0;
                    end
                end
                
                4'd4: begin
                    // Assertion 4: Check for forbidden bit patterns (security)
                    if (signal_in[15:0] == 16'hDEAD || signal_in[15:0] == 16'hBEEF) begin
                        violation <= 1'b1;
                    end
                    else begin
                        violation <= 1'b0;
                    end
                end
                
                default: begin
                    violation <= 1'b0;
                end
            endcase
        end
    end

endmodule
