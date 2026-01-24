class driver extends uvm_driver #(drv_pkt_c);
    `uvm_component_utils(driver)

    protected virtual dut_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual dut_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "Virtual interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        vif.cam_clk     <= 0;
        vif.href        <= 0;
        vif.vsync       <= 1;
        vif.data        <= 0;
        vif.stm_trigger <= 0;

        wait(vif.reset === 0);
        
        fork
            // Task 1: 독립적인 cam_clk 생성 (시뮬레이션 종료 시까지 무한 반복)
            forever begin
                repeat (2) @(posedge vif.clk);
                vif.cam_clk <= 1;
                repeat (2) @(posedge vif.clk);
                vif.cam_clk <= 0;
            end

            // Task 2: 데이터 구동 (cam_clk의 하강 엣지에 맞춰 데이터 업데이트)
            forever begin
                seq_item_port.get_next_item(req);
                
                @(negedge vif.cam_clk);
                vif.data        <= req.data;
                vif.href        <= req.href;
                vif.vsync       <= req.vsync;
                vif.stm_trigger <= req.stm_trigger;

                seq_item_port.item_done();
            end
        join_none
    endtask
endclass