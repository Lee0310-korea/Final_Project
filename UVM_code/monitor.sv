class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    protected virtual dut_if vif;
    uvm_analysis_port #(mon_pkt_c) in_data_port;
    uvm_analysis_port #(mon_pkt_c) out_data_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        in_data_port  = new("in_data_port", this);
        out_data_port = new("out_data_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual dut_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "vif not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        wait(vif.reset === 0);
        fork
            collect_input();
            collect_output();
        join_none
    endtask

    protected task collect_input();
        mon_pkt_c in_pkt;
        forever begin
            @(posedge vif.cam_clk);
            if (vif.we === 1'b1) begin
                in_pkt = mon_pkt_c::type_id::create("in_pkt");
                in_pkt.data = vif.wData; 
                in_data_port.write(in_pkt);
            end
        end
    endtask

    protected task collect_output();
        mon_pkt_c out_pkt;
        forever begin
            @(posedge vif.cam_clk);
            if (vif.debug_h_sync === 1'b0) begin 
                out_pkt = mon_pkt_c::type_id::create("out_pkt");
                out_pkt.r_port = vif.r_port;
                out_pkt.g_port = vif.g_port;
                out_pkt.b_port = vif.b_port;
                out_data_port.write(out_pkt);
            end
        end
    endtask
endclass