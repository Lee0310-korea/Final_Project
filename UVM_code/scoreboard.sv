`uvm_analysis_imp_decl(_in)
`uvm_analysis_imp_decl(_out)

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp_in #(mon_pkt_c, scoreboard) in_imp_port;
    uvm_analysis_imp_out #(mon_pkt_c, scoreboard) out_imp_port;

    typedef struct {
        bit [3:0] r;
        bit [3:0] g;
        bit [3:0] b;
    } rgb444_t;

    protected rgb444_t expected_q[$];
    protected int match_cnt = 0;
    protected int mismatch_cnt = 0;
    protected int total_count = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        in_imp_port  = new("in_imp_port", this);
        out_imp_port = new("out_imp_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual function void write_in(mon_pkt_c pkt);
        rgb444_t exp_data;
        bit [15:0] p;

        p = pkt.data;
        
        exp_data.r = p[15:12];
        exp_data.g = p[10:7];
        exp_data.b = p[4:1];

        expected_q.push_back(exp_data);
    endfunction

    virtual function void write_out(mon_pkt_c pkt);
        rgb444_t golden;
        bit [11:0] exp_val;
        bit [11:0] act_val;

        if (expected_q.size() == 0) return;

        golden = expected_q.pop_front();
        total_count++;

        exp_val = {golden.r, golden.g, golden.b};
        act_val = {pkt.r_port[3:0], pkt.g_port[3:0], pkt.b_port[3:0]};

        if (act_val === exp_val) begin
            match_cnt++;
            // `uvm_info("SB_MATCH", $sformatf("Idx: %0d | Exp: %h | Act: %h", total_count, exp_val, act_val), UVM_LOW)
        end else begin
            // if (mismatch_cnt < 100) begin
            //     `uvm_error("SB_MISMATCH", $sformatf("Idx: %0d | Exp: %h | Act: %h", total_count, exp_val, act_val))
            // end
            mismatch_cnt++;
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        // `uvm_info("SCB_RESULT", $sformatf("Total: %0d, Match: %0d, Mismatch: %0d", 
        //           total_count, match_cnt, mismatch_cnt), UVM_LOW)
    endfunction
endclass