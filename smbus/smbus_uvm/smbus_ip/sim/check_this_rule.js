// Strict verification of Coding Rule 11.3 (this. keyword usage)
const fs = require('fs');
const path = require('path');

const projectRoot = path.resolve(__dirname, '..', '..');

console.log('======================================================================');
console.log('       CODING RULE 11.3 (this. PREFIX) STRICT VERIFICATION CHECK       ');
console.log('======================================================================');

function getAllFiles(dir, exts, fileList = []) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory()) {
            if (file !== 'log' && file !== 'work' && file !== '.git') {
                getAllFiles(fullPath, exts, fileList);
            }
        } else {
            const ext = path.extname(file);
            if (exts.includes(ext) || ext === '.pkg') {
                fileList.push(fullPath);
            }
        }
    }
    return fileList;
}

const files = getAllFiles(projectRoot, ['.sv']);
let totalViolations = 0;

files.forEach(filePath => {
    if (filePath.includes('slave_model') || filePath.includes('hdl_top') || filePath.includes('hvl_top') || filePath.includes('smbus_if') || filePath.includes('smbus.if')) {
        return; // modules/interfaces are not classes
    }

    const relPath = path.relative(projectRoot, filePath);
    const content = fs.readFileSync(filePath, 'utf-8');

    const lines = content.split('\n');
    const memberVars = new Set();

    let inMethod = false;
    lines.forEach(line => {
        const trimmed = line.trim();
        if (trimmed.startsWith('function ') || trimmed.startsWith('task ')) inMethod = true;
        if (trimmed.startsWith('endfunction') || trimmed.startsWith('endtask')) inMethod = false;

        if (!inMethod) {
            const matches = trimmed.match(/\b(m_[a-z0-9_]+)\b/g);
            if (matches) {
                matches.forEach(m => {
                    if (!trimmed.startsWith('`uvm_field') && !trimmed.startsWith('constraint')) {
                        memberVars.add(m);
                    }
                });
            }
        }
    });

    inMethod = false;

    lines.forEach((line, idx) => {
        let code = line.replace(/\/\/.*$/, '').replace(/"(?:\\.|[^"\\])*"/g, '""');
        const trimmed = code.trim();

        if (trimmed.startsWith('function ') || trimmed.startsWith('task ')) {
            inMethod = true;
        }
        if (trimmed.startsWith('endfunction') || trimmed.startsWith('endtask')) {
            inMethod = false;
        }

        if (inMethod) {
            memberVars.forEach(mVar => {
                // If mVar is bare (not preceded by '.', and not preceded by '::')
                const regex = new RegExp(`(?<!\\.)(?<!::)\\b${mVar}\\b`, 'g');
                let match;
                while ((match = regex.exec(code)) !== null) {
                    if (!trimmed.startsWith('super.new') && !trimmed.startsWith('`uvm_') && !trimmed.includes('::type_id::create')) {
                        console.error(`[VIOLATION] ${relPath}:${idx+1} Member variable '${mVar}' bare access without 'this.' -> "${line.trim()}"`);
                        totalViolations++;
                    }
                }
            });
        }
    });
});

console.log('======================================================================');
console.log(`Coding Rule 11.3 Violations: ${totalViolations}`);
if (totalViolations === 0) {
    console.log('RESULT: 100% COMPLIANT WITH this. KEYWORD CODING RULE!');
} else {
    console.log('RESULT: FAILED CODING RULE 11.3');
}
console.log('======================================================================');

process.exit(totalViolations === 0 ? 0 : 1);
