class test extends uvm_test;
    `uvm_component_utils(test)

    protected env e;
    protected user_seq_c seq;
    protected frame_t local_frame;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info("TEST", "build_phase: Creating env and sequence", UVM_LOW)
        
        e = env::type_id::create("e", this);
        seq = user_seq_c::type_id::create("seq");
        
        foreach (local_frame[i, j]) begin
            local_frame[i][j] = $urandom; 
        end

        `uvm_info("TEST", "build_phase: Setting shared_frame to config_db", UVM_LOW)
        uvm_config_db#(frame_t)::set(null, "*", "shared_frame", local_frame);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", "run_phase: Starting User Sequence", UVM_LOW)
        
        seq.start(e.a.sqr);
        
        #10000; 
        
        `uvm_info("TEST", "run_phase: Sequence finished", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass