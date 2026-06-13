RTL := ../rtl
TB  := ../rtl/tb
IV  := iverilog -g2012
CORE := $(RTL)/prbs_gen.sv $(RTL)/ber_counter.sv $(RTL)/eye_sampler.sv $(RTL)/axi_csr.sv

all: prbs ber eye axi stress top

prbs:
	$(IV) -o tb_prbs_gen $(RTL)/prbs_gen.sv $(TB)/tb_prbs_gen.sv && vvp tb_prbs_gen

ber:
	$(IV) -o tb_ber_counter $(RTL)/prbs_gen.sv $(RTL)/ber_counter.sv $(TB)/tb_ber_counter.sv && vvp tb_ber_counter

eye:
	$(IV) -o tb_eye_sampler $(RTL)/eye_sampler.sv $(TB)/tb_eye_sampler.sv && vvp tb_eye_sampler

axi:
	$(IV) -o tb_axi_csr $(RTL)/axi_csr.sv $(TB)/tb_axi_csr.sv && vvp tb_axi_csr

stress:
	$(IV) -o tb_stress $(RTL)/prbs_gen.sv $(RTL)/ber_counter.sv $(RTL)/eye_sampler.sv $(TB)/tb_stress.sv && vvp tb_stress

top:
	$(IV) -o tb_bert_top $(CORE) $(RTL)/bert_top.sv $(TB)/phy_bfm.sv $(TB)/tb_bert_top.sv && vvp tb_bert_top

lint:
	$(IV) -o lint_top $(CORE) $(RTL)/ip_stubs.sv $(RTL)/bert_top.sv -s bert_top

clean:
	rm -f tb_* lint_top *.vcd

.PHONY: all prbs ber eye axi stress top lint clean
