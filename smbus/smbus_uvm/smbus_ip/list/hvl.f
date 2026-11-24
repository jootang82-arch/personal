// HVL File List for SMBus UVM IP Verification Environment
+incdir+../misc
+incdir+../../vip/smbus/hvl/env
+incdir+../../vip/smbus/hvl/seq
+incdir+../hvl/env_ip
+incdir+../hvl/seq_ip
+incdir+../tests
+incdir+../hvl/top

// 1. Misc Package (IP)
../misc/smbus_ip_misc.pkg.sv

// 2-7. SMBus VIP Package (Transaction, Sequencers, Drivers, Monitor, Agents, Sequences)
../../vip/smbus/hvl/env/smbus_pkg.sv

// 8. IP Environment Package (Scoreboard, Env)
../hvl/env_ip/smbus_ip_env.pkg.sv

// 9. IP Sequence Package (Sequences)
../hvl/seq_ip/smbus_ip_seq.pkg.sv

// 10. Test Base and Test Package
../tests/tests.pkg.sv

// 11. HVL Top Module
../hvl/top/hvl_top.sv
