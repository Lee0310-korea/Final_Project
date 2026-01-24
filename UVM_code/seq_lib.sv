class user_seq_c extends uvm_sequence #(drv_pkt_c);
    `uvm_object_utils(user_seq_c)

    protected drv_pkt_c             rnd_item;
    protected logic          [15:0] frame             [240][320];
    protected virtual dut_if        vif;

    protected int                   h_back_porch                  = 48;
    protected int                   h_front_porch                 = 16;
    protected int                   total_clk_per_line            = 704;

    function new(string name = "user_seq_c");
        super.new(name);
    endfunction

    virtual function void generate_frame();
        for (int y = 0; y < 240; y++) begin
            for (int x = 0; x < 320; x++) begin
                frame[y][x] = 16'h07ff;
                
                if (y >= 150 && y <= 156 && x >= 150 && x <= 156) begin
                    frame[y][x] = 16'hf800; 
                end
            end
        end
    endfunction

    virtual task body();
        if (starting_phase != null) starting_phase.raise_objection(this);

        if (!uvm_config_db#(virtual dut_if)::get(
                null, get_full_name(), "vif", vif
            ))
            `uvm_fatal("SEQ", "Virtual interface not found")

        wait (vif.reset === 0);
        repeat (10) @(posedge vif.clk);

        rnd_item = drv_pkt_c::type_id::create("rnd_item");
        repeat (10) begin
            generate_frame();
            vtiming();
        end

        if (starting_phase != null) starting_phase.drop_objection(this);
    endtask

    virtual task vtiming();
        rnd_item.vsync = 0;
        rnd_item.href = 0;
        rnd_item.stm_trigger = 0;
        rnd_item.data = 8'h00;

        repeat (10) cam_clk_toggle();
        rnd_item.stm_trigger = 1;
        rnd_item.vsync = 1;
        repeat (33) h_blank_only();
        rnd_item.stm_trigger = 0;
        rnd_item.vsync = 0;
        for (int row = 0; row < 240; row++) begin
            htiming(row);
        end

        repeat (10) h_blank_only();
        rnd_item.vsync = 1;
        cam_clk_toggle();
    endtask

    virtual task htiming(int row_idx);
        rnd_item.href = 0;
        repeat (h_back_porch) cam_clk_toggle();

        rnd_item.href = 1;
        for (int col = 0; col < 320; col++) begin
            logic [15:0] pix = frame[row_idx][col];
            rnd_item.data = pix[15:8];
            cam_clk_toggle();
            rnd_item.data = pix[7:0];
            cam_clk_toggle();
        end

        rnd_item.href = 0;
        repeat (h_front_porch) cam_clk_toggle();
    endtask

    virtual task h_blank_only();
        rnd_item.href = 0;
        repeat (total_clk_per_line) cam_clk_toggle();
    endtask

    virtual task cam_clk_toggle();
        start_item(rnd_item);
        finish_item(rnd_item);
    endtask
endclass
