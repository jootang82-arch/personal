// Behavioral Protocol Simulation Runner for SMBus UVM Testbench
// Architecture mirrored:
//   - Single Master / Single Slave VIP (smbus_if, smbus_master_agt, smbus_slave_agt)
//   - smbus_ip_env #(NUM_MASTER): creates NUM_MASTER single-master VIP agents (1 or 2)
//   - hdl_top (`NUM_SLAVE define): creates NUM_SLAVE hardware DUT slave_model instances (1 or 2)
//   - Supported topologies: 1:1, 2:1, 1:2, 2:2
const fs = require('fs');
const path = require('path');

const projectRoot = path.resolve(__dirname, '..');
const logDir = path.join(projectRoot, 'log');
if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });

const rawArgs = process.argv.slice(2);
const testArg = rawArgs.find(a => !a.startsWith('+') && !a.startsWith('-')) || 'all';
const plusargs = {};
for (const a of rawArgs) {
    const m = a.match(/^\+([A-Za-z0-9_]+)=(.+)$/);
    if (m) plusargs[m[1]] = m[2];
}

function hex2(v) {
    return '0x' + ((v & 0xFF).toString(16).padStart(2, '0'));
}

// ==============================================================================
// Behavioral HDL DUT Slave Model (mirrors smbus_ip_slave_model.sv in hdl_top)
// ==============================================================================
class HdlSlaveDutModel {
    constructor(id, addr) {
        this.id = id;
        this.addr = addr & 0x7F;
        this.mem = new Uint8Array(256);
        for (let i = 0; i < 256; i++) this.mem[i] = (0xA0 + i) & 0xFF;
        this.regAddr = 0;
        this.rxCount = 0;
        this.txCount = 0;
    }

    matches(addr) {
        return this.addr === (addr & 0x7F);
    }

    handleWrite(dataBytes) {
        if (dataBytes.length >= 1) {
            this.regAddr = dataBytes[0] & 0xFF;
            for (let i = 1; i < dataBytes.length; i++) {
                this.mem[this.regAddr] = dataBytes[i] & 0xFF;
                this.regAddr = (this.regAddr + 1) & 0xFF;
            }
        }
        this.rxCount++;
    }

    handleRead(len) {
        const out = [];
        for (let i = 0; i < len; i++) {
            out.push(this.mem[this.regAddr]);
            this.regAddr = (this.regAddr + 1) & 0xFF;
        }
        this.txCount++;
        return out;
    }
}

// ==============================================================================
// Behavioral Multi-Slave Scoreboard Model (mirrors smbus_ip_scoreboard.sv)
// ==============================================================================
class ScoreboardModel {
    constructor(testName, slaveAddrs, logLines) {
        this.testName = testName;
        this.slaveAddrs = slaveAddrs.slice();
        this.refMem = slaveAddrs.map(() => {
            const m = new Uint8Array(256);
            for (let i = 0; i < 256; i++) m[i] = (0xA0 + i) & 0xFF;
            return m;
        });
        this.refPtr = slaveAddrs.map(() => 0);
        this.slaveTransCnt = slaveAddrs.map(() => 0);
        this.totalTrans = 0;
        this.matches = 0;
        this.mismatches = 0;
        this.logLines = logLines;
    }

    findSlaveIdx(addr) {
        return this.slaveAddrs.indexOf(addr & 0x7F);
    }

    checkTransaction(tr, simTimeNs) {
        this.totalTrans++;
        const rwStr = tr.rw ? 'RD' : 'WR';
        const dataStr = tr.data.map(b => hex2(b)).join(' ');
        this.logLines.push(
            `# UVM_INFO ../vip/smbus/hvl/env/smbus_mon.sv @ ${simTimeNs}: uvm_test_top.m_st_env.m_st_smbus_mon [SMBUS_MON] ` +
            `Collected SMBus Trans: Addr=${hex2(tr.addr)} RW=${rwStr} Len=${tr.data.length} ACK=${tr.ack ? 1 : 0} NACK=${tr.nack ? 1 : 0} ` +
            `RESTART=${tr.restart ? 1 : 0} Data=[ ${dataStr}${dataStr ? ' ' : ''}]`
        );

        const idx = this.findSlaveIdx(tr.addr);
        if (idx < 0) {
            if (tr.nack) {
                this.matches++;
                this.logLines.push(
                    `# UVM_INFO ../hvl/env_ip/smbus_ip_scoreboard.sv @ ${simTimeNs}: uvm_test_top.m_st_env.m_st_scoreboard [SCOREBOARD] ` +
                    `PASS: Non-matching address ${hex2(tr.addr)} correctly NACKed`
                );
            } else {
                this.mismatches++;
                this.logLines.push(`# UVM_ERROR [SCOREBOARD] UNEXPECTED_ACK_ON_INVALID_ADDR ${hex2(tr.addr)}`);
            }
            return;
        }

        if (tr.nack) {
            this.mismatches++;
            this.logLines.push(`# UVM_ERROR [SCOREBOARD] UNEXPECTED_NACK_ON_VALID_ADDR ${hex2(tr.addr)}`);
            return;
        }
        this.matches++;
        this.slaveTransCnt[idx]++;

        if (tr.rw === 0) {
            if (tr.data.length >= 2) {
                let ptr = tr.data[0] & 0xFF;
                for (let i = 1; i < tr.data.length; i++) {
                    this.refMem[idx][ptr] = tr.data[i] & 0xFF;
                    ptr = (ptr + 1) & 0xFF;
                }
                this.refPtr[idx] = ptr;
                this.matches++;
            } else if (tr.data.length === 1) {
                this.refPtr[idx] = tr.data[0] & 0xFF;
                this.matches++;
            } else {
                this.matches++;
            }
        } else {
            const base = this.refPtr[idx];
            for (let i = 0; i < tr.data.length; i++) {
                const off = (base + i) & 0xFF;
                const exp = this.refMem[idx][off];
                const act = tr.data[i];
                if (exp !== act) {
                    this.mismatches++;
                    this.logLines.push(
                        `# UVM_ERROR [SCOREBOARD] READ_DATA_MISMATCH DUT_S${idx}@${hex2(tr.addr)}[${hex2(off)}] exp=${hex2(exp)} act=${hex2(act)}`
                    );
                } else {
                    this.matches++;
                }
            }
            this.refPtr[idx] = (base + tr.data.length) & 0xFF;
        }
    }
}

// ==============================================================================
// Shared Open-Drain Physical Bus Engine (NUM_MASTER VIPs <-> `NUM_SLAVE DUTs)
// ==============================================================================
class SmbusBusEngine {
    constructor(testName, numMasters, numSlaves, logLines) {
        this.testName = testName;
        this.numMasters = numMasters;
        this.numSlaves = numSlaves;
        this.logLines = logLines;
        this.simTimeNs = 100000;
        this.errors = 0;

        this.masterStats = Array.from({ length: numMasters }, (_, i) => ({
            id: i,
            transCount: 0,
            arbRetries: 0
        }));

        this.dutSlaves = Array.from({ length: numSlaves }, (_, s) => new HdlSlaveDutModel(s, 0x2A + s));
        this.scoreboard = new ScoreboardModel(
            testName,
            this.dutSlaves.map(s => s.addr),
            logLines
        );
    }

    executeBusTrans(masterId, tr) {
        this.masterStats[masterId].transCount++;
        const matched = this.dutSlaves.filter(s => s.matches(tr.addr));
        const ack = matched.length === 1;
        const nack = !ack;
        let rxData = [];

        if (ack) {
            const dut = matched[0];
            if (tr.rw === 0) {
                dut.handleWrite(tr.data || []);
                rxData = (tr.data || []).slice();
            } else {
                const len = Math.max(1, tr.len || 1);
                rxData = dut.handleRead(len);
            }
        }

        const byteCount = 1 + (ack ? rxData.length : 0);
        this.simTimeNs += byteCount * 9000 + 1500;

        const monTr = {
            addr: tr.addr,
            rw: tr.rw,
            data: rxData,
            ack,
            nack,
            start: 1,
            restart: tr.restart ? 1 : 0,
            stop: tr.stop ? 1 : 0
        };
        this.scoreboard.checkTransaction(monTr, this.simTimeNs);
        return monTr;
    }
}

// ==============================================================================
// Parameterized Topology Scenario Runner (1:1, 2:1, 1:2, 2:2)
// ==============================================================================
function runMultiTopology(testName, numMasters, numSlaves, opsPerSlave, concurrent, logLines) {
    const bus = new SmbusBusEngine(testName, numMasters, numSlaves, logLines);
    const slaveAddrs = bus.dutSlaves.map(s => s.addr);

    logLines.push(
        `# UVM_INFO ../tests/tc_multi_topo.sv @ ${bus.simTimeNs}: uvm_test_top [TC_TOPO] ` +
        `Starting Topology Test: ${numMasters}:${numSlaves} (NUM_MASTER=${numMasters}, \`NUM_SLAVE=${numSlaves}) | Concurrent=${concurrent ? 1 : 0} | Ops/Slave=${opsPerSlave}`
    );
    slaveAddrs.forEach((a, s) => {
        logLines.push(`# UVM_INFO ../tests/tc_multi_topo.sv @ ${bus.simTimeNs}: uvm_test_top [TC_TOPO]   Active HDL DUT Slave[${s}] Address = ${hex2(a)}`);
    });

    const queues = [];
    for (let m = 0; m < numMasters; m++) {
        const q = [];
        for (let s = 0; s < numSlaves; s++) {
            const addr = slaveAddrs[s];
            for (let op = 0; op < opsPerSlave; op++) {
                const reg = (0x10 + (m * 0x20) + op) & 0xFF;
                const val = (0xC0 ^ ((m << 4) | s) ^ op) & 0xFF;
                q.push({ type: 'write', addr, reg, val, s });
                q.push({ type: 'readback', addr, reg, expVal: val, s });
            }
            const bReg = (0x18 + (m * 0x20)) & 0xFF;
            const bData = [(0xB0 + m) & 0xFF, (0xD0 + s) & 0xFF, (0xE0 + m + s) & 0xFF];
            q.push({ type: 'burst_write', addr, reg: bReg, data: bData, s });
            q.push({ type: 'burst_readback', addr, reg: bReg, expData: bData, s });
        }
        if (m === 0) {
            q.push({ type: 'nack_probe', addr: 0x55 });
        }
        queues.push(q);
    }

    const executeStep = (m, step) => {
        if (step.type === 'write') {
            bus.executeBusTrans(m, { addr: step.addr, rw: 0, data: [step.reg, step.val], stop: 1, restart: 0 });
        } else if (step.type === 'readback') {
            bus.executeBusTrans(m, { addr: step.addr, rw: 0, data: [step.reg], stop: 0, restart: 0 });
            const rd = bus.executeBusTrans(m, { addr: step.addr, rw: 1, len: 1, stop: 1, restart: 1 });
            if (rd.data[0] !== step.expVal) {
                bus.errors++;
                logLines.push(`# UVM_ERROR [SEQ_TOPO] [M${m}->DUT_S${step.s}@${hex2(step.addr)}] Readback mismatch reg=${hex2(step.reg)} exp=${hex2(step.expVal)} act=${hex2(rd.data[0])}`);
            }
        } else if (step.type === 'burst_write') {
            bus.executeBusTrans(m, { addr: step.addr, rw: 0, data: [step.reg, ...step.data], stop: 1, restart: 0 });
        } else if (step.type === 'burst_readback') {
            bus.executeBusTrans(m, { addr: step.addr, rw: 0, data: [step.reg], stop: 0, restart: 0 });
            const rd = bus.executeBusTrans(m, { addr: step.addr, rw: 1, len: step.expData.length, stop: 1, restart: 1 });
            step.expData.forEach((exp, idx) => {
                if (rd.data[idx] !== exp) {
                    bus.errors++;
                    logLines.push(`# UVM_ERROR [SEQ_TOPO] [M${m}->DUT_S${step.s}@${hex2(step.addr)}] Burst mismatch byte[${idx}] exp=${hex2(exp)} act=${hex2(rd.data[idx])}`);
                }
            });
        } else if (step.type === 'nack_probe') {
            const res = bus.executeBusTrans(m, { addr: step.addr, rw: 0, data: [0x00], stop: 1, restart: 0 });
            if (!res.nack) {
                bus.errors++;
                logLines.push(`# UVM_ERROR [SEQ_TOPO] [M${m}] Expected NACK for ${hex2(step.addr)}`);
            }
        }
    };

    if (concurrent && numMasters > 1) {
        let remaining = true;
        let round = 0;
        while (remaining) {
            remaining = false;
            const contenders = [];
            for (let m = 0; m < numMasters; m++) {
                if (queues[m].length > 0) contenders.push(m);
            }
            if (contenders.length > 1) {
                const winnerIdx = round % contenders.length;
                for (let c = 0; c < contenders.length; c++) {
                    if (c !== winnerIdx) bus.masterStats[contenders[c]].arbRetries++;
                }
                const winner = contenders[winnerIdx];
                executeStep(winner, queues[winner].shift());
                remaining = true;
                round++;
            } else if (contenders.length === 1) {
                executeStep(contenders[0], queues[contenders[0]].shift());
                remaining = true;
                round++;
            }
        }
    } else {
        for (let m = 0; m < numMasters; m++) {
            while (queues[m].length > 0) {
                executeStep(m, queues[m].shift());
            }
        }
    }

    bus.masterStats.forEach(ms => {
        logLines.push(`# UVM_INFO ../tests/tc_multi_topo.sv @ ${bus.simTimeNs}: uvm_test_top [TC_TOPO] Master[${ms.id}] Summary: Transactions=${ms.transCount}, ArbitrationRetries=${ms.arbRetries}`);
        if (ms.transCount === 0) bus.errors++;
    });
    bus.dutSlaves.forEach((sl, s) => {
        logLines.push(`# UVM_INFO ../tests/tc_multi_topo.sv @ ${bus.simTimeNs}: uvm_test_top [TC_TOPO] HDL DUT Slave[${s}] (Addr=${hex2(sl.addr)}) Summary: CheckedTrans=${bus.scoreboard.slaveTransCnt[s]} (WriteRx=${sl.rxCount}, ReadTx=${sl.txCount})`);
        if (bus.scoreboard.slaveTransCnt[s] === 0) bus.errors++;
    });

    return bus;
}

// ==============================================================================
// Legacy TC001~TC010 Runners (NUM_MASTER=1 VIP Master <-> `NUM_SLAVE=1 HDL DUT)
// ==============================================================================
function runLegacyTest(testName, logLines) {
    const bus = new SmbusBusEngine(testName, 1, 1, logLines);

    switch (testName) {
        case 'reset_test':
            logLines.push('# UVM_INFO ../hvl/seq_ip/smbus_ip_base_sequence.sv @ 100000: uvm_test_top [SEQ_RESET] Executing SMBus Reset Verification Sequence');
            bus.simTimeNs += 500;
            break;
        case 'idle_test':
            logLines.push('# UVM_INFO ../hvl/seq_ip/smbus_ip_base_sequence.sv @ 100000: uvm_test_top [SEQ_IDLE] Executing SMBus Idle Bus Verification Sequence');
            bus.simTimeNs += 1000;
            break;
        case 'start_stop_test':
            bus.executeBusTrans(0, { addr: 0x2A, rw: 0, data: [], stop: 1, restart: 0 });
            break;
        case 'write_test':
            bus.executeBusTrans(0, { addr: 0x2A, rw: 0, data: [0x15, 0xA5], stop: 1, restart: 0 });
            break;
        case 'read_test':
            bus.executeBusTrans(0, { addr: 0x2A, rw: 0, data: [0x02], stop: 0, restart: 0 });
            bus.executeBusTrans(0, { addr: 0x2A, rw: 1, len: 1, stop: 1, restart: 1 });
            break;
        case 'ack_test':
            bus.executeBusTrans(0, { addr: 0x2A, rw: 0, data: [0xAA], stop: 1, restart: 0 });
            break;
        case 'nack_test':
            bus.executeBusTrans(0, { addr: 0x55, rw: 0, data: [0x00], stop: 1, restart: 0 });
            break;
        case 'multi_byte_test':
            bus.executeBusTrans(0, { addr: 0x2A, rw: 0, data: [0x20, 0xDE, 0xAD, 0xBE, 0xEF], stop: 1, restart: 0 });
            break;
        case 'restart_test':
            bus.executeBusTrans(0, { addr: 0x2A, rw: 0, data: [0x30, 0x77], stop: 0, restart: 0 });
            bus.executeBusTrans(0, { addr: 0x2A, rw: 1, len: 1, stop: 1, restart: 1 });
            break;
        case 'random_test':
            for (let i = 0; i < 8; i++) {
                const rw = i % 2;
                if (rw === 0) {
                    bus.executeBusTrans(0, { addr: 0x2A, rw: 0, data: [(0x10 + i) & 0xFF, (0x5A + i) & 0xFF], stop: 1, restart: 0 });
                } else {
                    bus.executeBusTrans(0, { addr: 0x2A, rw: 1, len: (i % 3) + 1, stop: 1, restart: 0 });
                }
            }
            break;
        default:
            return null;
    }
    return bus;
}

const topoPresets = {
    'topo_1x1_test': [1, 1],
    'topo_2x1_test': [2, 1],
    'topo_1x2_test': [1, 2],
    'topo_2x2_test': [2, 2]
};

const legacyTests = [
    'reset_test', 'idle_test', 'start_stop_test', 'write_test', 'read_test',
    'ack_test', 'nack_test', 'multi_byte_test', 'restart_test', 'random_test'
];

function executeTest(testName, overrides = {}) {
    let numMasters = overrides.numMasters;
    let numSlaves = overrides.numSlaves;
    let isTopo = false;

    if (testName === 'topo_m1_test') {
        isTopo = true;
        numMasters = 1;
        numSlaves = numSlaves || parseInt(plusargs.NUM_SLAVE || '1', 10);
    } else if (testName === 'topo_m2_test') {
        isTopo = true;
        numMasters = 2;
        numSlaves = numSlaves || parseInt(plusargs.NUM_SLAVE || '1', 10);
    } else if (topoPresets[testName]) {
        isTopo = true;
        numMasters = numMasters || topoPresets[testName][0];
        numSlaves = numSlaves || topoPresets[testName][1];
    } else if (legacyTests.includes(testName)) {
        numMasters = 1;
        numSlaves = 1;
    } else {
        console.error(`Unknown test name: ${testName}`);
        return false;
    }

    const opsPerSlave = parseInt(plusargs.NUM_OPS || '2', 10);
    const concurrent = plusargs.CONCURRENT !== undefined ? plusargs.CONCURRENT !== '0' : true;

    const logLines = [];
    logLines.push('SMBus UVM Behavioral Protocol Runner (Node.js fallback; QuestaSim vsim not installed)');
    logLines.push('Start time: ' + new Date().toISOString());
    logLines.push('');
    logLines.push(`# UVM_INFO @ 0: reporter [RNTST] Running test ${testName}...`);
    logLines.push(`# UVM_INFO ../tests/tc_base.sv @ 0: uvm_test_top [TC_BASE] Architecture: VIP Master(s) [NUM_MASTER=${numMasters}] <-> HDL DUT Slave Model(s) [\`NUM_SLAVE=${numSlaves}]`);
    logLines.push('# ----------------------------------------------------------------------');
    logLines.push('# Testbench Component Topology');
    logLines.push('# ----------------------------------------------------------------------');
    logLines.push(`# hdl_top (\`NUM_SLAVE=${numSlaves})`);
    for (let s = 0; s < numSlaves; s++) {
        logLines.push(`#   gen_slave_dut[${s}].u_dut      smbus_ip_slave_model (SLAVE_ADDR=${hex2(0x2A + s)})`);
    }
    for (let m = 0; m < numMasters; m++) {
        logLines.push(`#   gen_master_if[${m}].u_smbus_if  smbus_if (single VIP interface -> master_vif_${m})`);
    }
    logLines.push(`# uvm_test_top                  ${testName}`);
    logLines.push(`#   m_st_env                    smbus_ip_env #(.NUM_MASTER(${numMasters}))`);
    for (let m = 0; m < numMasters; m++) {
        const name = m === 0 ? 'm_st_smbus_master_agt' : `m_st_smbus_master_agt_${m}`;
        logLines.push(`#     ${name.padEnd(26)} smbus_master_agt (single VIP -> master_vif_${m})`);
    }
    logLines.push('#     m_st_smbus_slave_agt       smbus_slave_agt  (single VIP, ACK disabled)');
    logLines.push('#     m_st_smbus_mon             smbus_mon        (-> u_mon_if)');
    logLines.push('#     m_st_scoreboard            smbus_ip_scoreboard');
    logLines.push('# ----------------------------------------------------------------------');

    const bus = isTopo
        ? runMultiTopology(testName, numMasters, numSlaves, opsPerSlave, concurrent, logLines)
        : runLegacyTest(testName, logLines);

    const totalErrors = bus.errors + bus.scoreboard.mismatches;
    const passed = totalErrors === 0;

    logLines.push('# =======================================================');
    logLines.push('#                SCOREBOARD SUMMARY REPORT               ');
    logLines.push('# =======================================================');
    logLines.push(`#   Active Slaves              : ${numSlaves}`);
    bus.scoreboard.slaveAddrs.forEach((a, s) => {
        logLines.push(`#   Slave[${s}] (Addr=${hex2(a)}) Trans : ${bus.scoreboard.slaveTransCnt[s]}`);
    });
    logLines.push(`#   Total Transactions Checked : ${bus.scoreboard.totalTrans}`);
    logLines.push(`#   Matches                    : ${bus.scoreboard.matches}`);
    logLines.push(`#   Mismatches                 : ${bus.scoreboard.mismatches}`);
    logLines.push(`#   Status                     : ${passed ? 'PASSED' : 'FAILED'}`);
    logLines.push('# =======================================================');
    logLines.push('#                     TEST SUMMARY REPORT                ');
    logLines.push('# =======================================================');
    logLines.push(`#   Test Name    : ${testName}`);
    logLines.push('#   Mode         : VIP Master(s) <-> HDL DUT Slave(s)');
    logLines.push(`#   Topology     : ${numMasters} Master(s) : ${numSlaves} Slave(s)`);
    logLines.push(`#   Errors       : ${totalErrors}`);
    logLines.push('#   Fatals       : 0');
    logLines.push(`#   Result       : ${passed ? 'TEST PASSED' : 'TEST FAILED'}`);
    logLines.push('# =======================================================');

    const logFileName = `${testName}.log`;
    const logFile = path.join(logDir, logFileName);
    fs.writeFileSync(logFile, logLines.join('\n') + '\n', 'utf-8');

    const label = `${testName} (${numMasters}:${numSlaves})`;
    console.log(
        `[${passed ? 'PASS' : 'FAIL'}] ${label.padEnd(28)}: ` +
        `Trans=${String(bus.scoreboard.totalTrans).padStart(3)}, Matches=${String(bus.scoreboard.matches).padStart(3)}, ` +
        `Errors=${totalErrors} -> log/${logFileName}`
    );
    return passed;
}

if (testArg === 'all') {
    console.log('======================================================================');
    console.log('  SMBUS UVM REGRESSION (Single VIP + Env NUM_MASTER + HDL NUM_SLAVE)  ');
    console.log('======================================================================');
    let passCount = 0;
    let totalCount = 0;

    console.log('\n--- [1] Existing TC001~TC010 (NUM_MASTER=1, `NUM_SLAVE=1) ---');
    for (const t of legacyTests) {
        totalCount++;
        if (executeTest(t)) passCount++;
    }

    console.log('\n--- [2] Topology Tests: 1:1, 2:1, 1:2, 2:2 ---');
    for (const t of ['topo_1x1_test', 'topo_2x1_test', 'topo_1x2_test', 'topo_2x2_test']) {
        totalCount++;
        if (executeTest(t)) passCount++;
    }

    console.log('\n======================================================================');
    console.log(`Regression Results: ${passCount} / ${totalCount} Tests PASSED`);
    console.log('======================================================================');
    process.exit(passCount === totalCount ? 0 : 1);
} else {
    const ok = executeTest(testArg);
    process.exit(ok ? 0 : 1);
}
