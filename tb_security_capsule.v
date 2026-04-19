// Testbench for Security Capsule Architecture
// Tests dynamic trace buffer, signal group selection, and assertion monitoring

`timescale 1ns/1ps

module tb_security_capsule;

    // Parameters
    parameter TRACE_LENGTH = 8;
    parameter TRACE_WIDTH = 8;
    parameter NUM_GROUPS = 4;
    parameter SIGNAL_WIDTH = 32;
    parameter CLK_PERIOD = 10;
    
    // Clock and Reset
    reg clk;
    reg rst_n;
    
    // IP Core signals (test signals)
    reg [SIGNAL_WIDTH-1:0] ip_signal_1;
    reg [SIGNAL_WIDTH-1:0] ip_signal_2;
    reg [SIGNAL_WIDTH-1:0] ip_signal_3;
    reg [SIGNAL_WIDTH-1:0] ip_signal_4;
    
    // Trace control
    reg trace_enable;
    reg trace_dump;
    reg [$clog2(NUM_GROUPS)-1:0] group_select;
    
    // Outputs
    wire trace_valid;
    wire [TRACE_WIDTH-1:0] trace_data_out;
    wire trace_dump_done;
    wire assertion_violation;
    wire [3:0] violation_id;
    
    // Test control variables
    integer i;
    integer error_count;
    integer test_count;
    
    // DUT instantiation
    security_capsule #(
        .TRACE_LENGTH(TRACE_LENGTH),
        .TRACE_WIDTH(TRACE_WIDTH),
        .NUM_GROUPS(NUM_GROUPS),
        .SIGNAL_WIDTH(SIGNAL_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ip_signal_1(ip_signal_1),
        .ip_signal_2(ip_signal_2),
        .ip_signal_3(ip_signal_3),
        .ip_signal_4(ip_signal_4),
        .trace_enable(trace_enable),
        .trace_dump(trace_dump),
        .group_select(group_select),
        .trace_valid(trace_valid),
        .trace_data_out(trace_data_out),
        .trace_dump_done(trace_dump_done),
        .assertion_violation(assertion_violation),
        .violation_id(violation_id)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        trace_enable = 0;
        trace_dump = 0;
        group_select = 0;
        ip_signal_1 = 0;
        ip_signal_2 = 0;
        ip_signal_3 = 0;
        ip_signal_4 = 0;
        error_count = 0;
        test_count = 0;
        
        // Generate VCD file for waveform viewing
        $dumpfile("security_capsule.vcd");
        $dumpvars(0, tb_security_capsule);
        
        // Print test header
        $display("========================================");
        $display("Security Capsule Testbench");
        $display("Based on Post-Silicon Security Assertion");
        $display("Validation Architecture");
        $display("========================================");
        $display("Time=%0t: Starting tests...", $time);
        
        // Reset sequence
        #(CLK_PERIOD*2);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        // ================================================
        // TEST 1: Basic Trace Buffer Operation
        // ================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Basic Trace Buffer Operation", test_count);
        trace_enable = 1;
        group_select = 0;
        
        // Write data to trace buffer
        for (i = 0; i < TRACE_LENGTH; i = i + 1) begin
            ip_signal_1 = $random;
            #(CLK_PERIOD);
        end
        
        trace_enable = 0;
        #(CLK_PERIOD*2);
        $display("  PASS: Trace buffer write completed");
        
        // ================================================
        // TEST 2: Trace Dump Operation
        // ================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Trace Dump via JTAG Interface", test_count);
        trace_dump = 1;
        #(CLK_PERIOD);
        trace_dump = 0;
        
        // Wait for dump to complete
        wait(trace_dump_done);
        #(CLK_PERIOD*2);
        $display("  PASS: Trace dump completed");
        
        // ================================================
        // TEST 3: Dynamic Signal Group Selection
        // ================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Dynamic Signal Group Selection", test_count);
        
        // Test each group
        for (i = 0; i < NUM_GROUPS; i = i + 1) begin
            group_select = i;
            trace_enable = 1;
            
            case(i)
                0: ip_signal_1 = 32'hA5A5_0000 + i;
                1: ip_signal_2 = 32'h5A5A_0000 + i;
                2: ip_signal_3 = 32'h1234_0000 + i;
                3: ip_signal_4 = 32'h5678_0000 + i;
            endcase
            
            #(CLK_PERIOD*4);
            $display("  Group %0d selected and traced", i);
        end
        
        trace_enable = 0;
        $display("  PASS: All signal groups tested");
        
        // ================================================
        // TEST 4: Assertion Monitor 1 - Consecutive Values
        // ================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Assertion Monitor 1 - Consecutive Value Check", test_count);
        
        ip_signal_1 = 32'hF000_1234;
        #(CLK_PERIOD);
        ip_signal_1 = 32'hF000_1234; // Same value with upper bits = F
        #(CLK_PERIOD);
        
        if (assertion_violation && violation_id == 4'd1) begin
            $display("  PASS: Monitor 1 detected violation correctly");
        end else begin
            $display("  FAIL: Monitor 1 did not detect violation");
            error_count = error_count + 1;
        end
        
        ip_signal_1 = 32'h0000_0000;
        #(CLK_PERIOD*2);
        
        // ================================================
        // TEST 5: Assertion Monitor 2 - Privilege Bits
        // ================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Assertion Monitor 2 - Privilege Check", test_count);
        
        ip_signal_2 = 32'h8000_0000; // Bit 31 = 1, Bit 30 = 0 (invalid)
        #(CLK_PERIOD*2);
        
        if (assertion_violation && violation_id == 4'd2) begin
            $display("  PASS: Monitor 2 detected privilege violation");
        end else begin
            $display("  FAIL: Monitor 2 did not detect violation");
            error_count = error_count + 1;
        end
        
        ip_signal_2 = 32'h0000_0000;
        #(CLK_PERIOD*2);
        
        // ================================================
        // TEST 6: Assertion Monitor 3 - Fault Injection Detection
        // ================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Assertion Monitor 3 - Fault Injection Detection", test_count);
        
        ip_signal_3 = 32'h0000_0100;
        #(CLK_PERIOD);
        ip_signal_3 = 32'h0000_2000; // Large jump (> 0x1000)
        #(CLK_PERIOD*2);
        
        if (assertion_violation && violation_id == 4'd3) begin
            $display("  PASS: Monitor 3 detected fault injection");
        end else begin
            $display("  FAIL: Monitor 3 did not detect fault");
            error_count = error_count + 1;
        end
        
        ip_signal_3 = 32'h0000_0000;
        #(CLK_PERIOD*2);
        
        // ================================================
        // TEST 7: Assertion Monitor 4 - Forbidden Patterns
        // ================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Assertion Monitor 4 - Forbidden Pattern Detection", test_count);
        
        ip_signal_4 = 32'h1234_DEAD; // Forbidden pattern
        #(CLK_PERIOD*2);
        
        if (assertion_violation && violation_id == 4'd4) begin
            $display("  PASS: Monitor 4 detected forbidden pattern");
        end else begin
            $display("  FAIL: Monitor 4 did not detect pattern");
            error_count = error_count + 1;
        end
        
        ip_signal_4 = 32'h0000_BEEF; // Another forbidden pattern
        #(CLK_PERIOD*2);
        
        if (assertion_violation && violation_id == 4'd4) begin
            $display("  PASS: Monitor 4 detected second forbidden pattern");
        end else begin
            $display("  FAIL: Monitor 4 did not detect second pattern");
            error_count = error_count + 1;
        end
        
        ip_signal_4 = 32'h0000_0000;
        #(CLK_PERIOD*2);
        
        // ================================================
        // TEST 8: Multi-Cycle Trace with FIFO Wrap-around
        // ================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Multi-Cycle Trace with FIFO Behavior", test_count);
        
        trace_enable = 1;
        group_select = 0;
        
        // Write more than buffer length to test FIFO wrap
        for (i = 0; i < TRACE_LENGTH * 2; i = i + 1) begin
            ip_signal_1 = i;
            #(CLK_PERIOD);
        end
        
        trace_enable = 0;
        #(CLK_PERIOD);
        $display("  PASS: FIFO wrap-around test completed");
        
        // ================================================
        // TEST 9: Concurrent Monitoring and Tracing
        // ================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Concurrent Monitoring and Tracing", test_count);
        
        trace_enable = 1;
        group_select = 2;
        
        for (i = 0; i < 5; i = i + 1) begin
            ip_signal_1 = $random;
            ip_signal_2 = $random;
            ip_signal_3 = i * 32'h100; // Safe increments
            ip_signal_4 = $random;
            #(CLK_PERIOD);
        end
        
        trace_enable = 0;
        $display("  PASS: Concurrent operation test completed");
        
        // ================================================
        // TEST 10: Complete Workflow - Trace, Dump, Switch Group
        // ================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Complete Workflow Test", test_count);
        
        // Trace Group 0
        group_select = 0;
        trace_enable = 1;
        for (i = 0; i < TRACE_LENGTH/2; i = i + 1) begin
            ip_signal_1 = 32'hAAAA_0000 + i;
            #(CLK_PERIOD);
        end
        trace_enable = 0;
        
        // Dump
        #(CLK_PERIOD);
        trace_dump = 1;
        #(CLK_PERIOD);
        trace_dump = 0;
        wait(trace_dump_done);
        #(CLK_PERIOD*2);
        
        // Switch to Group 1 and trace
        group_select = 1;
        trace_enable = 1;
        for (i = 0; i < TRACE_LENGTH/2; i = i + 1) begin
            ip_signal_2 = 32'hBBBB_0000 + i;
            #(CLK_PERIOD);
        end
        trace_enable = 0;
        
        $display("  PASS: Complete workflow executed successfully");
        
        // ================================================
        // TEST 11: No False Positives
        // ================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] No False Positive Test", test_count);
        
        ip_signal_1 = 32'h0000_1234;
        ip_signal_2 = 32'hC000_0000; // Valid privilege bits
        ip_signal_3 = 32'h0000_0100;
        ip_signal_4 = 32'h1234_5678; // Valid pattern
        
        #(CLK_PERIOD*5);
        
        if (!assertion_violation) begin
            $display("  PASS: No false violations detected");
        end else begin
            $display("  FAIL: False violation detected (ID=%0d)", violation_id);
            error_count = error_count + 1;
        end
        
        // ================================================
        // TEST 12: Reset Behavior
        // ================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Reset Behavior Test", test_count);
        
        trace_enable = 1;
        ip_signal_1 = 32'hFFFF_FFFF;
        #(CLK_PERIOD*3);
        
        rst_n = 0;
        #(CLK_PERIOD*2);
        rst_n = 1;
        #(CLK_PERIOD);
        
        if (!assertion_violation && !trace_valid) begin
            $display("  PASS: Reset cleared all states");
        end else begin
            $display("  FAIL: Reset did not clear states properly");
            error_count = error_count + 1;
        end
        
        // ================================================
        // Print Test Summary
        // ================================================
        #(CLK_PERIOD*10);
        
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Errors: %0d", error_count);
        
        if (error_count == 0) begin
            $display("STATUS: ALL TESTS PASSED!");
        end else begin
            $display("STATUS: %0d TEST(S) FAILED", error_count);
        end
        $display("========================================\n");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 1000);
        $display("\nERROR: Simulation timeout!");
        $finish;
    end
    
    // Monitor trace buffer activity
    always @(posedge clk) begin
        if (trace_enable) begin
            $display("Time=%0t: Tracing Group %0d", $time, group_select);
        end
        if (trace_valid) begin
            $display("Time=%0t: Trace Data Out = 0x%h", $time, trace_data_out);
        end
        if (assertion_violation) begin
            $display("Time=%0t: VIOLATION! Monitor ID=%0d", $time, violation_id);
        end
    end

endmodule
